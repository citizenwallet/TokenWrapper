// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {FixedPointMathLib} from "../../lib/solmate/src/utils/FixedPointMathLib.sol";
import {IERC20} from "../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {ILocker} from "../lockers/interfaces/ILocker.sol";
import {ReentrancyGuard} from "../../lib/solmate/src/utils/ReentrancyGuard.sol";
import {SafeERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {StorageV1} from "./StorageV1.sol";

contract TreasuryV1 is StorageV1 {
    using SafeERC20 for IERC20;
    using FixedPointMathLib for uint256;

    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    // Storage slot with the address of the current implementation.
    // This is the hardcoded keccak-256 hash of: "eip1967.proxy.implementation" subtracted by 1.
    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    // Storage slot for the Liquidation implementation, a struct to avoid storage conflict when dealing with upgradeable contracts.
    struct AddressSlot {
        address value;
    }

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    error AlreadyInitialized();
    error IsNotALocker();
    error IsActiveLocker();
    error LengthMismatch();
    error LockerNotPrivate();
    error MaxRatio();
    error MaxYieldInterval();
    error MaxYieldLockers();
    error OnlyOwner();
    error RecoveryNotAllowed();
    error SyncIntervalNotMet();
    error WeightsNotValid();
    error YieldIntervalNotMet();
    error YieldTooLow();

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

    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    constructor() {}

    /* //////////////////////////////////////////////////////////////
                         YIELD LOCKERS LOGIC
    ////////////////////////////////////////////////////////////// */

    /**
     * @notice Claims an amount of yield from the treasury.
     * @param amount The amount of yield to claim.
     * @param receiver The address receiving the yield.
     * @dev If amount provided is equal to type(uint256).max, it will claim the full available yield balance.
     */
    function claimYield(uint256 amount, address receiver) external onlyOwner {
        if (amount > availableYield) revert YieldTooLow();

        availableYield -= amount;
        IERC20(EURE).safeTransfer(receiver, amount);
    }

    /**
     * @notice Synchronizes all yield lockers by adjusting balances based on weights and idle ratio.
     */
    function syncAll() external nonReentrant {
        if (msg.sender != owner) {
            if (block.timestamp < lastSyncTime + 1 days) revert SyncIntervalNotMet();
        }
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
                try ILocker(lockers[i]).withdraw(EURE, excess) returns (uint256 withdrawn) {
                    // Add withdrawn amount to idle balance.
                    currentIdle += withdrawn;
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
            // Increment yield available
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

        uint256 withdrawn = ILocker(locker).withdraw(EURE, amount);

        if (withdrawn > privateLockersSupply) {
            privateLockersSupply = 0;
        } else {
            privateLockersSupply -= withdrawn;
        }
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

    /* ///////////////////////////////////////////////////////////////
                          PROXY MANAGEMENT
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Initiates the Treasury contract.
     */
    function initialize(address eurE) external {
        if (EURE != address(0)) revert AlreadyInitialized();
        locked = 1;
        owner = msg.sender;
        EURE = eurE;
    }

    /**
     * @notice Upgrades the Liquidation version and stores a new address in the EIP1967 implementation slot.
     * @param newImplementation The new contract address of the Liquidation implementation.
     * @dev This function MUST be added to new Liquidation implementations.
     */
    function upgrade(address newImplementation) external onlyOwner {
        // Store new parameters.
        _getAddressSlot(IMPLEMENTATION_SLOT).value = newImplementation;
    }

    /**
     * @notice Returns the "AddressSlot" with member "value" located at "slot".
     * @param slot The slot where the address of the Logic contract is stored.
     * @return r The address stored in slot.
     */
    function _getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        assembly {
            r.slot := slot
        }
    }

    /**
     * @notice Returns the current implementation address stored in the EIP-1967 slot.
     * @return implementation The address of the current implementation.
     */
    function getImplementation() external view returns (address implementation) {
        return _getAddressSlot(IMPLEMENTATION_SLOT).value;
    }

    /* ///////////////////////////////////////////////////////////////
                        OWNERSHIP MANAGEMENT
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Transfers ownership of the contract to a new address.
     * @param owner_ The new owner address.
     */
    function transferOwnership(address owner_) external onlyOwner {
        owner = owner_;
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

        IERC20(asset).safeTransfer(msg.sender, amount);
    }
}
