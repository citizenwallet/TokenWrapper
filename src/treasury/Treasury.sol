// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {FixedPointMathLib} from "../../lib/solmate/src/utils/FixedPointMathLib.sol";
import {IERC20} from "../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {ILocker} from "../lockers/interfaces/ILocker.sol";
import {Ownable} from "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "../../lib/solmate/src/utils/ReentrancyGuard.sol";
import {SafeERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Storage} from "./Storage.sol";

contract Treasury is Ownable, Storage {
    using SafeERC20 for IERC20;
    using FixedPointMathLib for uint256;

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    error IsNotALocker();
    error IsActiveLocker();
    error LengthMismatch();
    error LockerNotPrivate();
    error MaxRatio();
    error MaxYieldInterval();
    error MaxYieldLockers();
    error RecoveryNotAllowed();
    error SyncIntervalNotMet();
    error WeightsNotValid();
    error YieldIntervalNotMet();

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    /* //////////////////////////////////////////////////////////////
                                MODIFIERS
    ////////////////////////////////////////////////////////////// */

    modifier nonReentrant() {
        require(locked == 1, "REENTRANCY");

        locked = 2;
        _;
        locked = 1;
    }

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    constructor(address eurE) Ownable(msg.sender) {
        EURE = eurE;
    }

    /* //////////////////////////////////////////////////////////////
                         YIELD LOCKERS LOGIC
    ////////////////////////////////////////////////////////////// */

    /**
     * @notice Synchronizes all yield lockers by adjusting balances based on weights and idle ratio.
     */
    function syncAll() external nonReentrant {
        if (block.timestamp < lastSyncTime + 1 days) revert SyncIntervalNotMet();
        lastSyncTime = block.timestamp;

        // Cache values.
        uint256 BIPS_ = BIPS;
        address[] memory lockers = yieldLockers;
        uint256[] memory weights = lockersWeights;

        uint256 totalInvested;
        uint256[] memory lockerBalances = new uint256[](weights.length);
        // We use weights.length as those should always sum to BIPS (see setWeights()).
        for (uint256 i; i < weights.length; ++i) {
            lockerBalances[i] = ILocker(lockers[i]).totalDeposited();
            totalInvested += lockerBalances[i];
        }

        // Calculate total supply excluding private funds and target values.
        uint256 currentIdle = IERC20(EURE).balanceOf(address(this));
        uint256 totalSupplyExclPrivate = currentIdle + totalInvested;
        uint256 totalToInvest = totalSupplyExclPrivate.mulDivDown(BIPS_ - idleRatio, BIPS_);

        // Step 1: Withdraw excess from overfunded lockers.
        for (uint256 i; i < weights.length; ++i) {
            uint256 targetBalance = totalToInvest.mulDivDown(weights[i], BIPS_);
            uint256 currentBalance = lockerBalances[i];

            if (currentBalance > targetBalance) {
                uint256 excess = currentBalance - targetBalance;
                try ILocker(lockers[i]).withdraw(EURE, excess) {
                    // Add withdrawn amount to idle balance.
                    currentIdle += excess;
                } catch {}
            }
        }

        // Step 2: Deposit idle funds into underfunded lockers.
        for (uint256 i; i < weights.length; ++i) {
            uint256 targetBalance = totalToInvest.mulDivDown(weights[i], BIPS_);
            address locker = lockers[i];
            uint256 currentBalance = ILocker(locker).totalDeposited();

            if (currentBalance < targetBalance) {
                uint256 toDeposit = targetBalance - currentBalance;
                uint256 depositAmount = currentIdle >= toDeposit ? toDeposit : currentIdle;

                if (depositAmount > 0) {
                    // Avoid redundant approvals.
                    if (IERC20(EURE).allowance(address(this), locker) < toDeposit) {
                        IERC20(EURE).approve(locker, type(uint256).max);
                    }
                    try ILocker(locker).deposit(EURE, depositAmount) {
                        currentIdle -= depositAmount;
                    } catch {}
                }
            }
        }
        // At this point, the idle balance should match the target idle balance.
    }

    /**
     * @notice Collects yield from all yield lockers and mints it to the treasury.
     * @return yield The total yield collected.
     */
    function collectYield() external returns (uint256 yield) {
        if (block.timestamp - lastYieldClaim < yieldInterval) revert YieldIntervalNotMet();

        // Get total balance before collecting yield.
        uint256 initBalance = IERC20(EURE).balanceOf(address(this));
        for (uint256 i; i < lockersWeights.length; ++i) {
            ILocker(yieldLockers[i]).collectYield(EURE);
        }
        // Calculate yield collected.
        uint256 newBalance = IERC20(EURE).balanceOf(address(this));

        yield = newBalance > initBalance ? newBalance - initBalance : 0;

        // Increase claimable yield.
        availableYield += yield;
    }

    /**
     * @notice Adds a new yield locker to the system.
     * @param locker The address of the locker to add.
     */
    function addYieldLocker(address locker) external onlyOwner {
        if (yieldLockers.length == MAX_YIELD_LOCKERS) revert MaxYieldLockers();
        yieldLockers.push(locker);
    }

    /**
     * @notice Removes a yield locker from the system, withdrawing its balance.
     * @param locker The address of the locker to remove.
     */
    function removeYieldLocker(address locker) external onlyOwner {
        // Cache values
        address[] memory yieldLockers_ = yieldLockers;
        if (yieldLockers_.length != lockersWeights.length) revert LengthMismatch();

        // Check if locker exists and get the index.
        uint256 index;
        bool isLocker;
        for (uint256 i; i < yieldLockers_.length; ++i) {
            if (yieldLockers[i] == locker) {
                index = i;
                isLocker = true;
            }
        }
        if (isLocker == false) revert IsNotALocker();

        // Ensure locker is empty before removal, if not do a fullWithdraw.
        if (ILocker(locker).getTotalValue(EURE) != 0) {
            (, uint256 yield) = ILocker(locker).fullWithdraw(EURE);
            // Yield collected is minted to the treasury.
            availableYield += yield;
        }

        // Replace the locker at index to remove by the locker at last position of array.
        if (index < yieldLockers_.length - 1) {
            yieldLockers[index] = yieldLockers[yieldLockers_.length - 1];
            lockersWeights[index] = lockersWeights[yieldLockers_.length - 1];
        }

        yieldLockers.pop();
        lockersWeights.pop();
    }

    /**
     * @notice Sets the weights for yield lockers.
     * @param newLockersWeights The new weights for each locker.
     */
    // Note : Double check no issue if idle set to max vs lockers
    function setWeights(uint256[] memory newLockersWeights) external onlyOwner {
        if (newLockersWeights.length != yieldLockers.length) revert LengthMismatch();
        uint256 totalLockerWeights;
        for (uint256 i; i < newLockersWeights.length; ++i) {
            totalLockerWeights += newLockersWeights[i];
        }
        if (totalLockerWeights != BIPS) revert WeightsNotValid();
        lockersWeights = newLockersWeights;
    }

    /**
     * @notice Sets a new idle ratio for the system.
     * @param newRatio The new idle ratio.
     */
    function setIdleRatio(uint256 newRatio) external onlyOwner {
        if (newRatio > BIPS) revert MaxRatio();
        idleRatio = newRatio;
    }

    /**
     * @notice Sets the interval for yield collection.
     * @param yieldInterval_ The new yield interval in seconds.
     */
    function setYieldInterval(uint256 yieldInterval_) external onlyOwner {
        if (yieldInterval_ > 30 days) revert MaxYieldInterval();
        yieldInterval = yieldInterval_;
    }

    /* //////////////////////////////////////////////////////////////
                    PRIVATE YIELD LOCKERS LOGIC
    ////////////////////////////////////////////////////////////// */

    /**
     * @notice Marks an address as a private locker.
     * @param locker The address of the locker to mark as private.
     */
    function addPrivateLocker(address locker) external onlyOwner {
        for (uint256 i; i < yieldLockers.length; ++i) {
            if (locker == yieldLockers[i]) revert IsActiveLocker();
        }
        isPrivateLocker[locker] = true;
    }

    /**
     * @notice Deposits an amount into a private locker.
     * @param locker The address of the private locker.
     * @param amount The amount to deposit.
     */
    function depositInPrivateLocker(address locker, uint256 amount) external onlyOwner {
        if (isPrivateLocker[locker] == false) revert LockerNotPrivate();

        privateLockersSupply += amount;

        IERC20(EURE).approve(locker, amount);
        ILocker(locker).deposit(EURE, amount);
    }

    /**
     * @notice Withdraws an amount from a private locker.
     * @param locker The address of the private locker.
     * @param amount The amount to withdraw.
     */
    function withdrawFromPrivateLocker(address locker, uint256 amount) external onlyOwner {
        if (isPrivateLocker[locker] == false) revert LockerNotPrivate();

        if (amount > privateLockersSupply) {
            privateLockersSupply = 0;
        } else {
            privateLockersSupply -= amount;
        }

        ILocker(locker).withdraw(EURE, amount);
    }

    /**
     * @notice Collects yield from a private locker.
     * @param locker The address of the private locker.
     */
    function collectYieldFromPrivateLocker(address locker) external onlyOwner returns (uint256 yield) {
        if (isPrivateLocker[locker] == false) revert LockerNotPrivate();

        // Get total balance before collecting yield.
        uint256 initBalance = IERC20(EURE).balanceOf(address(this));
        ILocker(locker).collectYield(EURE);
        // Calculate yield collected.
        uint256 newBalance = IERC20(EURE).balanceOf(address(this));

        yield = newBalance > initBalance ? newBalance - initBalance : 0;

        // Increase claimable yield.
        availableYield += yield;
    }

    /* //////////////////////////////////////////////////////////////
                           HELPER FUNCTIONS
    ////////////////////////////////////////////////////////////// */

    /**
     * @notice Function to recover ERC20 assets other than the underlying asset.
     * @param asset The address of the asset to recover.
     * @param amount The amount of asset to recover.
     */
    function recoverERC20(address asset, uint256 amount) external onlyOwner {
        if (asset == EURE) revert RecoveryNotAllowed();
        if (asset == address(this)) revert RecoveryNotAllowed();

        IERC20(asset).safeTransfer(msg.sender, amount);
    }
}
