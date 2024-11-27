// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {ERC20Wrapper} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Wrapper.sol";
import {FixedPointMathLib} from "../../lib/solmate/src/utils/FixedPointMathLib.sol";
import {ICardFactory} from "./interfaces/ICardFactory.sol";
import {ICommissionModule} from "./interfaces/ICommissionModule.sol";
import {IERC20} from "../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {ISafe} from "./interfaces/ISafe.sol";
import {ILocker} from "../lockers/interfaces/ILocker.sol";
import {Ownable} from "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "../../lib/solmate/src/utils/ReentrancyGuard.sol";
import {SafeERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Storage} from "./Storage.sol";

contract EurB is ERC20Wrapper, Ownable, Storage {
    using SafeERC20 for IERC20;
    using FixedPointMathLib for uint256;

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    error IsNotALocker();
    error IsActiveLocker();
    error LengthMismatch();
    error LockerNotPrivate();
    error MaxCommissionsDepth();
    error MaxRatio();
    error MaxYieldInterval();
    error MaxYieldLockers();
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

    constructor(IERC20 underlyingToken, address treasury_, address cardFactory_)
        ERC20Wrapper(underlyingToken)
        ERC20("EuroBrussels", "EURB")
        Ownable(msg.sender)
    {
        treasury = treasury_;
        cardFactory = ICardFactory(cardFactory_);
    }

    /* //////////////////////////////////////////////////////////////
                         ERC20 LOGIC
    ////////////////////////////////////////////////////////////// */

    /**
     * @notice Moves an amount of tokens from the caller's account to "to".
     * @param to The address the tokens are sent to.
     * @param amount The amount of tokens transferred.
     * @return success A boolean value indicating wether the operation succeeded.
     */
    function transfer(address to, uint256 amount) public override returns (bool success) {
        // Do initial transfer for full amount.
        _transfer(msg.sender, to, amount);

        // Check if commission has to be paid on transfer, use try-catch pattern to not block transfers in case
        // logic fails in the Card Factory or Commission Hook Module.
        try cardFactory.COMMISSION_HOOK_MODULE() returns (address commissionModule) {
            if (commissionModule != address(0)) _processCommissions(commissionModule, to, amount, 0);
        } catch {}

        return true;
    }

    /* //////////////////////////////////////////////////////////////
                         COMMISSION LOGIC
    ////////////////////////////////////////////////////////////// */

    /**
     * @notice This function will check for a receiving Safe if it has the commission module active.
     * If this is the case, we get the commissionned addresses and rates from the commission module and do the appropriate transfers.
     * @param commissionModule The address of the Commission Module.
     * @param commissioned The address receiving a token transfer and potentially having to pay a commission.
     * @param amount The full amount of the previous transfer to "commissioned".
     * @param depth Tracks the number of recursive calls to _processCommissions, will revert after MAX_COMMISSIONS_DEPTH.
     */
    function _processCommissions(address commissionModule, address commissioned, uint256 amount, uint256 depth)
        internal
    {
        if (depth > MAX_COMMISSIONS_DEPTH) revert MaxCommissionsDepth();

        // Skip if the address is not a contract
        if (commissioned.code.length == 0) {
            return;
        }

        // If CommissionHookModule is enabled on potential commissioned address(receiver of last token transfer),
        // get recipients and rates and transfer corresponding amount from receiver to commission beneficiary.
        // Todo: validate no malicious contract that could return true for isModuleEnabled and where getCommissionInfo would not fail.
        try ISafe(commissioned).isModuleEnabled(commissionModule) returns (bool enabled) {
            if (enabled == true) {
                (address[] memory recipients, uint256[] memory rates) =
                    ICommissionModule(commissionModule).getCommissionInfo(commissioned);
                for (uint256 i; i < recipients.length; ++i) {
                    // Recipient can't be equal to commissioned.
                    if (commissioned == recipients[i]) continue;
                    uint256 commission = amount.mulDivDown(rates[i], BIPS);
                    // Do the transfer of the commission.
                    _transfer(commissioned, recipients[i], commission);
                    // The recipient becomes the potential commissioned now.
                    _processCommissions(commissionModule, recipients[i], commission, depth + 1);
                }
            }
        } catch {}
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
        address underlying_ = address(underlying());

        uint256 totalInvested;
        uint256[] memory lockerBalances = new uint256[](weights.length);
        // We use weights.length as those should always sum to BIPS (see setWeights()).
        for (uint256 i; i < weights.length; ++i) {
            lockerBalances[i] = ILocker(lockers[i]).totalDeposited();
            totalInvested += lockerBalances[i];
        }

        // Calculate total supply excluding private funds and target values.
        uint256 currentIdle = IERC20(underlying_).balanceOf(address(this));
        uint256 totalSupplyExclPrivate = currentIdle + totalInvested;
        uint256 totalToInvest = totalSupplyExclPrivate.mulDivDown(BIPS_ - idleRatio, BIPS_);

        // Step 1: Withdraw excess from overfunded lockers.
        for (uint256 i; i < weights.length; ++i) {
            uint256 targetBalance = totalToInvest.mulDivDown(weights[i], BIPS_);
            uint256 currentBalance = lockerBalances[i];

            if (currentBalance > targetBalance) {
                uint256 excess = currentBalance - targetBalance;
                try ILocker(lockers[i]).withdraw(underlying_, excess) {
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
                    if (IERC20(underlying_).allowance(address(this), locker) < toDeposit) {
                        IERC20(underlying_).approve(locker, type(uint256).max);
                    }
                    try ILocker(locker).deposit(underlying_, depositAmount) {
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

        // Cache value
        address underlying_ = address(underlying());
        // Get total balance before collecting yield.
        uint256 initBalance = IERC20(underlying_).balanceOf(address(this));
        for (uint256 i; i < lockersWeights.length; ++i) {
            ILocker(yieldLockers[i]).collectYield(underlying_);
        }
        // Calculate yield collected.
        uint256 newBalance = IERC20(underlying_).balanceOf(address(this));

        yield = newBalance > initBalance ? newBalance - initBalance : 0;
        if (yield > 0) {
            // Mint the yield generated to the treasury.
            _mint(treasury, yield);
        }
    }

    /**
     * @notice Will set a new treasury.
     * @param treasury_ The new treasury address.
     */
    function setTreasury(address treasury_) external onlyOwner {
        treasury = treasury_;
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
        address underlying_ = address(underlying());
        if (ILocker(locker).getTotalValue(underlying_) != 0) {
            (, uint256 yield) = ILocker(locker).fullWithdraw(underlying_);
            // Yield collected is minted to the treasury.
            _mint(treasury, yield);
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

        underlying().approve(locker, amount);
        ILocker(locker).deposit(address(underlying()), amount);
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

        ILocker(locker).withdraw(address(underlying()), amount);
    }

    /**
     * @notice Collects yield from a private locker.
     * @param locker The address of the private locker.
     */
    function collectYieldFromPrivateLocker(address locker) external onlyOwner returns (uint256 yield) {
        if (isPrivateLocker[locker] == false) revert LockerNotPrivate();

        // Cache value
        address underlying_ = address(underlying());
        // Get total balance before collecting yield.
        uint256 initBalance = IERC20(underlying_).balanceOf(address(this));
        ILocker(locker).collectYield(underlying_);
        // Calculate yield collected.
        uint256 newBalance = IERC20(underlying_).balanceOf(address(this));

        yield = newBalance > initBalance ? newBalance - initBalance : 0;
        if (yield > 0) {
            // Mint the yield generated to the treasury.
            _mint(treasury, yield);
        }
    }
    // Note : Do we put a recover function (yes with limited withdrawable assets) ?
}
