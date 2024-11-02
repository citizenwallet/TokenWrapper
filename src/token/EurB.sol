// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {ERC20Wrapper} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Wrapper.sol";
import {FixedPointMathLib} from "../../lib/solmate/src/utils/FixedPointMathLib.sol";
import {ICardFactory} from "./interfaces/ICardFactory.sol";
import {ICommissionModule} from "./interfaces/ICommissionModule.sol";
import {IERC20} from "../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {ISafe} from "./interfaces/ISafe.sol";
import {Ownable} from "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {Storage} from "./Storage.sol";

contract EurB is ERC20Wrapper, Ownable, Storage {
    using FixedPointMathLib for uint256;

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    error MaxCommissionsDepth();

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
                                LOGIC
    ////////////////////////////////////////////////////////////// */

    // Note: overwrite depositFor function and add a syncInterest/collateral

    /**
     * @notice Will set a new treasury.
     * @param treasury_ The new treasury address.
     */
    function setTreasury(address treasury_) external onlyOwner {
        treasury = treasury_;
    }

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

    /**
     * @notice This function will check for a receiving Safe if it has the commission module active.
     * If this is the case, we get the commissionned addresses and rates from the commission module and do the appropriate transfers.
     * @param commissionModule The address of the Commission Module.
     * @param commissioner The address receiving a token transfer and potentially having to pay a commission.
     * @param amount The full amount of the previous transfer to "commissioner".
     * @param depth Tracks the number of recursive calls to _processCommissions, will revert after MAX_COMMISSIONS_DEPTH.
     */
    function _processCommissions(address commissionModule, address commissioner, uint256 amount, uint256 depth)
        internal
    {
        if (depth > MAX_COMMISSIONS_DEPTH) revert MaxCommissionsDepth();

        // If CommissionHookModule is enabled on potential commissioner (receiver of last token transfer),
        // get recipients and rates and transfer corresponding amount from receiver to commission beneficiary.
        // Todo: validate no malicious contract that could return true for isModuleEnabled and where getCommissionInfo would not fail.
        try ISafe(commissioner).isModuleEnabled(commissionModule) returns (bool enabled) {
            if (enabled == true) {
                (address[] memory recipients, uint256[] memory rates) =
                    ICommissionModule(commissionModule).getCommissionInfo(commissioner);
                for (uint256 i; i < recipients.length; ++i) {
                    uint256 commission = amount.mulDivDown(rates[i], BIPS);
                    // Do the transfer of the commission.
                    _transfer(commissioner, recipients[i], commission);
                    // The recipient becomes the potential commissioner now.
                    _processCommissions(commissionModule, recipients[i], commission, depth + 1);
                }
            }
        } catch {}
    }
}
