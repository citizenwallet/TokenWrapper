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
import {Storage} from "./Storage.sol";

contract EurB is ERC20Wrapper, Ownable, Storage {
    using FixedPointMathLib for uint256;

    // note : yield

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    error LengthMismatch();
    error MaxCommissionsDepth();
    error MaxRatio();
    error MaxYieldLockers();
    error TimeNotElapsed();
    error WeightsNotValid();

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    /* //////////////////////////////////////////////////////////////
                                MODIFIERS
    ////////////////////////////////////////////////////////////// */

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

    // Note: overwrite depositFor function and add a syncInterest/collateral

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

        // If CommissionHookModule is enabled on potential commissioned address(receiver of last token transfer),
        // get recipients and rates and transfer corresponding amount from receiver to commission beneficiary.
        // Todo: validate no malicious contract that could return true for isModuleEnabled and where getCommissionInfo would not fail.
        try ISafe(commissioned).isModuleEnabled(commissionModule) returns (bool enabled) {
            if (enabled == true) {
                (address[] memory recipients, uint256[] memory rates) =
                    ICommissionModule(commissionModule).getCommissionInfo(commissioned);
                for (uint256 i; i < recipients.length; ++i) {
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

    function syncAll() external {
        if (block.timestamp < lastSyncTime + 1 days) revert TimeNotElapsed();

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

        // Check if current idle balance meets target idle balance.
        uint256 currentIdle = IERC20(underlying_).balanceOf(address(this));
        uint256 targetIdle = totalSupply() - totalInvested;

        // If not, withdraw from lockers according to weigths.
        if (currentIdle < targetIdle) {
            uint256 toWithdraw = targetIdle - currentIdle;

            // Withdraw from lockers according to weights to meet idle requirement.
            for (uint256 i; i < weights.length; i++) {
                uint256 proportionalAmount = toWithdraw.mulDivDown(weights[i], BIPS_);
                // If locker has not enough balance, withdraw max possible.
                lockerBalances[i] >= proportionalAmount
                    ? ILocker(lockers[i]).withdraw(underlying_, proportionalAmount)
                    : ILocker(lockers[i]).withdraw(underlying_, lockerBalances[i]);
            }
        }

        // Get total amount that should be deposited in lockers (non-idle).
        // Note : adapt formula for private locker that will have impact on total invested.
        // Note : check if ok to keep same totalSupply here (think should be ok)
        uint256 totalToInvest = totalSupply().mulDivDown(BIPS_ - idleRatio, BIPS_);

        // We use weights.length as those should always sum to BIPS (see setWeights()).
        for (uint256 i; i < weights.length; ++i) {
            uint256 targetBalance = totalToInvest.mulDivDown(weights[i], BIPS_);
            uint256 currentBalance = ILocker(lockers[i]).totalDeposited();

            if (currentBalance < targetBalance) {
                // Note : use batchApprove.
                uint256 toDeposit = targetBalance - currentBalance;
                IERC20(underlying_).approve(lockers[i], toDeposit);
                // Don't revert if the call fails, continue.
                try ILocker(lockers[i]).deposit(underlying_, toDeposit) {}
                catch {
                    continue;
                }
            } else if (currentBalance > targetBalance) {
                uint256 toWithdraw = currentBalance - targetBalance;
                // Don't revert if the call fails, continue.
                try ILocker(lockers[i]).withdraw(underlying_, toWithdraw) {} catch {}
            }
        }
    }

    // Note : It should mint the yield in underlying token and distribute to treasury
    function collectYield() external {}

    /**
     * @notice Will set a new treasury.
     * @param treasury_ The new treasury address.
     */
    function setTreasury(address treasury_) external onlyOwner {
        treasury = treasury_;
    }

    function addYieldLocker(address locker) external onlyOwner {
        if (yieldLockers.length == MAX_YIELD_LOCKERS) revert MaxYieldLockers();
        yieldLockers.push(locker);
    }

    function addPrivateLocker(address locker) external onlyOwner {}

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

    function setIdleRatio(uint256 newRatio) external onlyOwner {
        if (newRatio > BIPS) revert MaxRatio();
        idleRatio = newRatio;
    }

    // Note : add a function to remove a locker.
    // Note : Do we put a recover function ?
}
