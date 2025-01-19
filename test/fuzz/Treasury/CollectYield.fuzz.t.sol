// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Treasury_Fuzz_Test} from "./_Treasury.fuzz.t.sol";

import {FixedPointMathLib} from "../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import {IERC20} from "../../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {ILocker} from "../../../src/lockers/interfaces/ILocker.sol";
import {TreasuryV1} from "../../../src/treasury/TreasuryV1.sol";

/**
 * @notice Fuzz tests for the function "collectYield" of contract "Treasury".
 */
contract CollectYield_Treasury_Fuzz_Test is Treasury_Fuzz_Test {
    using FixedPointMathLib for uint256;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Treasury_Fuzz_Test.setUp();
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
        treasury.setYieldInterval(yieldInterval);
        treasury.setLastYieldClaim(lastYieldClaim);
        vm.stopPrank();

        // When: Calling collectYield().
        // Then: It should revert.
        vm.expectRevert(TreasuryV1.YieldIntervalNotMet.selector);
        treasury.collectYield();
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
            address locker = treasury.yieldLockers(i);
            uint256 yield = EURE.balanceOf(locker) - ILocker(locker).totalDeposited();
            expectedCollectedYield += yield;
        }

        uint256 initBalance = EURE.balanceOf(address(treasury));

        // When: Calling collectYield().
        treasury.collectYield();

        // And: EURE yield should be sent to EURB.
        assertEq(EURE.balanceOf(address(treasury)), initBalance + expectedCollectedYield);

        // And: Remaining balance of locker = totalDeposited.
        for (uint256 i; i < numberOfLockers_; ++i) {
            address locker = treasury.yieldLockers(i);
            assertEq(EURE.balanceOf(locker), ILocker(locker).totalDeposited());
        }
    }
}
