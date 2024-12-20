// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {FixedPointMathLib} from "../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import {Fuzz_Test} from "../Fuzz.t.sol";
import {LockerMock} from "../../utils/mocks/LockerMock.sol";

/**
 * @notice Common logic needed by all "EurB" fuzz tests.
 */
abstract contract EurB_Fuzz_Test is Fuzz_Test {
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
        // Given: Deploy lockers and add them to EurB.
        numberOfLockers = bound(numberOfLockers, 1, 5);
        numberOfLockers_ = numberOfLockers;

        uint256 sumOfLockerWeights;
        uint256[] memory lockerWeights_ = new uint256[](numberOfLockers);
        vm.startPrank(users.dao);
        for (uint256 i; i < numberOfLockers; ++i) {
            // Add locker to EURB.
            LockerMock newLocker = new LockerMock(address(EURB));
            EURB.addYieldLocker(address(newLocker));

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
            // Mint to locker and dao.
            EURE.mint(address(newLocker), lockerDeposits[i]);
            EURB.mint(users.dao, lockerDeposits[i]);
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
        EURB.setWeights(lockerWeights_);
        vm.stopPrank();
    }

    function setStateVars(StateVars memory stateVars) public returns (StateVars memory) {
        vm.startPrank(users.dao);

        // Set idle ratio.
        stateVars.idleRatio = bound(stateVars.idleRatio, 0, BIPS);
        EURB.setIdleRatio(stateVars.idleRatio);

        // Set last sync time.
        stateVars.lastSyncTime = bound(stateVars.lastSyncTime, 0, block.timestamp - 1 days - 1);
        EURB.setLastSyncTime(stateVars.lastSyncTime);

        // Set last yield interval.
        stateVars.yieldInterval = bound(stateVars.yieldInterval, 0, 30 days);
        EURB.setYieldInterval(stateVars.yieldInterval);

        // Set last yield claim.
        stateVars.lastYieldClaim = bound(stateVars.lastYieldClaim, 0, block.timestamp - stateVars.yieldInterval - 1);
        EURB.setLastYieldClaim(stateVars.lastYieldClaim);

        // Set idle balance.
        stateVars.idleBalance = bound(stateVars.idleBalance, 0, type(uint96).max);
        EURE.mint(users.tokenHolder, stateVars.idleBalance);
        vm.startPrank(users.tokenHolder);
        EURE.approve(address(EURB), stateVars.idleBalance);
        EURB.depositFor(users.tokenHolder, stateVars.idleBalance);

        vm.stopPrank();

        return stateVars;
    }

    function setStatePrivateLocker(uint256 depositAmount, uint256 yield) public {
        // Add locker to EURB.
        vm.startPrank(users.dao);
        LockerMock privateLocker = new LockerMock(address(EURB));
        EURB.addPrivateLocker(address(privateLocker));
        vm.stopPrank();

        // Positive deposit.
        depositAmount = bound(depositAmount, 1, type(uint96).max);

        // Deposit
        EURE.mint(users.tokenHolder, depositAmount);
        vm.startPrank(users.tokenHolder);
        EURE.approve(address(EURB), depositAmount);
        EURB.depositFor(users.tokenHolder, depositAmount);

        vm.startPrank(users.dao);
        EURB.depositInPrivateLocker(address(privateLocker), depositAmount);
        vm.stopPrank();

        // Send yield to private Locker, is max 20% of deposited amount.
        yield = bound(yield, 0, depositAmount.mulDivDown(2_000, BIPS));
        EURE.mint(address(privateLocker), yield);
    }
}
