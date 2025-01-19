// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Treasury_Fuzz_Test} from "./_Treasury.fuzz.t.sol";

import {FixedPointMathLib} from "../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import {IERC20} from "../../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {ILocker} from "../../../src/lockers/interfaces/ILocker.sol";
import {TreasuryV1} from "../../../src/treasury/TreasuryV1.sol";

/**
 * @notice Fuzz tests for the function "syncAll" of contract "Treasury".
 */
contract SyncAll_Treasury_Fuzz_Test is Treasury_Fuzz_Test {
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
    function testFuzz_Revert_syncAll_SyncIntervalNotMet(uint256 lastSyncTime) public {
        // Given: Sync interval has not passed.
        lastSyncTime = bound(lastSyncTime, block.timestamp - 1 days + 1, block.timestamp);

        treasury.setLastSyncTime(lastSyncTime);

        // When: Calling syncAll().
        // Then: It should revert.
        vm.expectRevert(TreasuryV1.SyncIntervalNotMet.selector);
        treasury.syncAll();
    }

    function testFuzz_success_syncAll_NoPrivateLocker(
        uint256 numberOfLockers,
        uint256[5] memory lockerDeposits,
        uint256[5] memory lockerYields,
        uint256[5] memory lockerWeights,
        StateVars memory stateVars
    ) public {
        // Given: Set valid state.
        (uint256 totalInvested, uint256 numberOfLockers_) =
            setStateOfLockers(numberOfLockers, lockerDeposits, lockerYields, lockerWeights);
        stateVars = setStateVars(stateVars);

        uint256 idleBalancePreSync = EURE.balanceOf(address(treasury));
        uint256 totalBalance = totalInvested + idleBalancePreSync;

        // When: Calling syncAll().
        treasury.syncAll();

        // Then: Correct values should be set.
        uint256 idleRatio = treasury.idleRatio();
        uint256 totalBalanceInLockers = totalBalance.mulDivDown(BIPS - idleRatio, BIPS);
        uint256 expectedIdle = totalBalance.mulDivDown(idleRatio, BIPS);
        assertApproxEqAbs(expectedIdle, EURE.balanceOf(address(treasury)), 5);
        for (uint256 i; i < numberOfLockers_; ++i) {
            uint256 expectedBalanceInLocker = totalBalanceInLockers.mulDivDown(treasury.lockersWeights(i), BIPS);
            uint256 actualBalanceInLocker = ILocker(treasury.yieldLockers(i)).totalDeposited();
            assertEq(expectedBalanceInLocker, actualBalanceInLocker);
        }
    }

    function testFuzz_success_syncAll_WithPrivateLocker(
        uint256 numberOfLockers,
        uint256[5] memory lockerDeposits,
        uint256[5] memory lockerYields,
        uint256[5] memory lockerWeights,
        StateVars memory stateVars,
        uint256 privateLockerDepositAmount,
        uint256 privateLockerYield
    ) public {
        // Given: Set valid state.
        (uint256 totalInvested, uint256 numberOfLockers_) =
            setStateOfLockers(numberOfLockers, lockerDeposits, lockerYields, lockerWeights);
        stateVars = setStateVars(stateVars);
        setStatePrivateLocker(privateLockerDepositAmount, privateLockerYield);

        uint256 idleBalancePreSync = EURE.balanceOf(address(treasury));
        uint256 totalBalance = totalInvested + idleBalancePreSync;

        // When: Calling syncAll().
        treasury.syncAll();

        // Then: Correct values should be set.
        uint256 idleRatio = treasury.idleRatio();
        uint256 totalBalanceInLockers = totalBalance.mulDivDown(BIPS - idleRatio, BIPS);
        uint256 expectedIdle = totalBalance.mulDivDown(idleRatio, BIPS);
        assertApproxEqAbs(expectedIdle, EURE.balanceOf(address(treasury)), 5);
        for (uint256 i; i < numberOfLockers_; ++i) {
            uint256 expectedBalanceInLocker = totalBalanceInLockers.mulDivDown(treasury.lockersWeights(i), BIPS);
            uint256 actualBalanceInLocker = ILocker(treasury.yieldLockers(i)).totalDeposited();
            assertEq(expectedBalanceInLocker, actualBalanceInLocker);
        }
    }
}
