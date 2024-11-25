// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {EurB_Fuzz_Test} from "./_EurB.fuzz.t.sol";

import {EurB} from "../../../src/token/EurB.sol";
import {FixedPointMathLib} from "../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import {IERC20} from "../../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {ILocker} from "../../../src/lockers/interfaces/ILocker.sol";

/**
 * @notice Fuzz tests for the function "collectYield" of contract "EurB".
 */
contract CollectYield_EurB_Fuzz_Test is EurB_Fuzz_Test {
    using FixedPointMathLib for uint256;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        EurB_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_collectYield_YieldIntervalNotMet(uint256 lastYieldClaim, uint256 yieldInterval) public {
        // Given: yieldInterval is > block.timestamp - lastYieldClaim
        lastYieldClaim = bound(lastYieldClaim, block.timestamp - type(uint16).max, block.timestamp);
        yieldInterval = bound(
            yieldInterval, block.timestamp - lastYieldClaim + 1, block.timestamp - lastYieldClaim + 1 + type(uint16).max
        );

        vm.startPrank(users.dao);
        EURB.setYieldInterval(yieldInterval);
        EURB.setLastYieldClaim(lastYieldClaim);
        vm.stopPrank();

        // When: Calling collectYield().
        // Then: It should revert.
        vm.expectRevert(EurB.YieldIntervalNotMet.selector);
        EURB.collectYield();
    }

    function testFuzz_success_collectYield(
        uint256 numberOfLockers,
        uint256[5] memory lockerDeposits,
        uint256[5] memory lockerYields,
        uint256[5] memory lockerWeights,
        StateVars memory stateVars
    ) public {
        // Given: Set valid state.
        (, uint256 numberOfLockers_) = setStateOfLockers(numberOfLockers, lockerDeposits, lockerYields, lockerWeights);
        stateVars = setStateVars(stateVars);

        // And: yieldInterval is 0 (yield can always be claimed).
        uint256 expectedCollectedYield;
        for (uint256 i; i < numberOfLockers_; ++i) {
            address locker = EURB.yieldLockers(i);
            uint256 yield = EURE.balanceOf(locker) - ILocker(locker).totalDeposited();
            expectedCollectedYield += yield;
        }

        uint256 initBalance = EURE.balanceOf(address(EURB));

        // When: Calling collectYield().
        EURB.collectYield();

        // Then: Yield should have been minted to the treasury.
        assertEq(EURB.balanceOf(users.treasury), expectedCollectedYield);
        // And: EURE yield should be sent to EURB.
        assertEq(EURE.balanceOf(address(EURB)), initBalance + expectedCollectedYield);

        // And: Remaining balance of locker = totalDeposited.
        for (uint256 i; i < numberOfLockers_; ++i) {
            address locker = EURB.yieldLockers(i);
            assertEq(EURE.balanceOf(locker), ILocker(locker).totalDeposited());
        }
    }
}
