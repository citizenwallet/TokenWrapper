// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {EurB_Fuzz_Test} from "./_EurB.fuzz.t.sol";

import {EurB} from "../../../src/token/EurB.sol";
import {FixedPointMathLib} from "../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import {IERC20} from "../../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {ILocker} from "../../../src/lockers/interfaces/ILocker.sol";

/**
 * @notice Fuzz tests for the function "syncAll" of contract "EurB".
 */
contract SyncAll_EurB_Fuzz_Test is EurB_Fuzz_Test {
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
    function testFuzz_Revert_syncAll_SyncIntervalNotMet(uint256 lastSyncTime) public {
        // Given: Sync interval has not passed.
        lastSyncTime = bound(lastSyncTime, block.timestamp - 1 days + 1, block.timestamp);

        EURB.setLastSyncTime(lastSyncTime);

        // When: Calling syncAll().
        // Then: It should revert.
        vm.expectRevert(EurB.SyncIntervalNotMet.selector);
        EURB.syncAll();
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

        uint256 idleBalancePreSync = EURE.balanceOf(address(EURB));
        uint256 totalBalance = totalInvested + idleBalancePreSync;

        // When: Calling syncAll().
        EURB.syncAll();

        // Then: Correct values should be set.
        uint256 totalBalanceInLockers = totalBalance.mulDivDown(BIPS - EURB.idleRatio(), BIPS);
        for (uint256 i; i < numberOfLockers_; ++i) {
            uint256 expectedBalanceInLocker = totalBalanceInLockers.mulDivDown(EURB.lockersWeights(i), BIPS);
            uint256 actualBalanceInLocker = ILocker(EURB.yieldLockers(i)).totalDeposited();
            assertEq(expectedBalanceInLocker, actualBalanceInLocker);
        }
    }
}
