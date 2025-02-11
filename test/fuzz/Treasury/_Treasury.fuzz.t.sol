// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {FixedPointMathLib} from "../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import {Fuzz_Test} from "../Fuzz.t.sol";
import {LockerMock} from "../../utils/mocks/LockerMock.sol";

/**
 * @notice Common logic needed by all "Treasury" fuzz tests.
 */
abstract contract Treasury_Fuzz_Test is Fuzz_Test {
    using FixedPointMathLib for uint256;
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    struct StateVars {
        uint256 idleRatio;
        uint256 idleBalance;
        uint256 lastSyncTime;
        uint256 lastYieldClaim;
        uint256 yieldInterval;
    }

    /* ///////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    function setStateOfLockers(
        uint256 numberOfLockers,
        uint256[5] memory lockerDeposits,
        uint256[5] memory lockerYields,
        uint256[5] memory lockerWeights
    ) public returns (uint256 totalDeposits, uint256 numberOfLockers_) {
        // Given: Deploy lockers and add them to Treasury.
        numberOfLockers = bound(numberOfLockers, 1, 5);
        numberOfLockers_ = numberOfLockers;

        uint256 sumOfLockerWeights;
        uint256[] memory lockerWeights_ = new uint256[](numberOfLockers);
        vm.startPrank(users.dao);
        for (uint256 i; i < numberOfLockers; ++i) {
            // Add locker to EURB.
            LockerMock newLocker = new LockerMock(address(treasury));
            treasury.addYieldLocker(address(newLocker));

            // Set weights.
            if (sumOfLockerWeights == BIPS) {
                lockerWeights_[i] = 0;
            } else {
                if (i == numberOfLockers - 1) {
                    lockerWeights_[i] = BIPS - sumOfLockerWeights;
                } else {
                    lockerWeights_[i] = bound(lockerWeights[i], 0, BIPS - sumOfLockerWeights);
                }
            }
            sumOfLockerWeights += lockerWeights_[i];

            // Deposit in lockers.
            lockerDeposits[i] = bound(lockerDeposits[i], 0, type(uint96).max);
            totalDeposits += lockerDeposits[i];
            // Mint to locker
            EURE.mint(address(newLocker), lockerDeposits[i]);
            // Increase locker deposit.
            newLocker.increaseDeposits(lockerDeposits[i]);
            // Send the yield to the locker.
            // Yield should be max 20 % of deposited value.
            lockerYields[i] = bound(lockerYields[i], 0, lockerDeposits[i].mulDivDown(2_000, BIPS));
            // Mint the yield to the locker.
            EURE.mint(address(newLocker), lockerYields[i]);
        }
        // Sum of weights should be equal to BIPS.
        assertEq(sumOfLockerWeights, BIPS);
        // Set weights.
        treasury.setWeights(lockerWeights_);
        vm.stopPrank();
    }

    function setStateVars(StateVars memory stateVars) public returns (StateVars memory) {
        vm.startPrank(users.dao);

        // Set idle ratio.
        stateVars.idleRatio = bound(stateVars.idleRatio, 0, BIPS);
        treasury.setIdleRatio(stateVars.idleRatio);

        // Set last sync time.
        stateVars.lastSyncTime = bound(stateVars.lastSyncTime, 0, block.timestamp - 1 days - 1);
        treasury.setLastSyncTime(stateVars.lastSyncTime);

        // Set last yield interval.
        stateVars.yieldInterval = bound(stateVars.yieldInterval, 0, 30 days);
        treasury.setYieldInterval(stateVars.yieldInterval);

        // Set last yield claim.
        stateVars.lastYieldClaim = bound(stateVars.lastYieldClaim, 0, block.timestamp - stateVars.yieldInterval - 1);
        treasury.setLastYieldClaim(stateVars.lastYieldClaim);

        // Set idle balance.
        stateVars.idleBalance = bound(stateVars.idleBalance, 0, type(uint96).max);
        EURE.mint(address(treasury), stateVars.idleBalance);

        vm.stopPrank();

        return stateVars;
    }

    function setStatePrivateLocker(uint256 depositAmount, uint256 yield) public {
        // Add locker to EURB.
        vm.startPrank(users.dao);
        LockerMock privateLocker = new LockerMock(address(treasury));
        treasury.addPrivateLocker(address(privateLocker));
        vm.stopPrank();

        // Positive deposit.
        depositAmount = bound(depositAmount, 1, type(uint96).max);

        // Deposit
        EURE.mint(address(treasury), depositAmount);
        vm.startPrank(users.dao);
        treasury.depositInPrivateLocker(address(privateLocker), depositAmount);
        vm.stopPrank();

        // Send yield to private Locker, is max 20% of deposited amount.
        yield = bound(yield, 0, depositAmount.mulDivDown(2_000, BIPS));
        EURE.mint(address(privateLocker), yield);
    }
}
