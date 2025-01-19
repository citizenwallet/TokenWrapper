// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {AccessControl} from "../../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import {ERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {FixedPointMathLib} from "../../lib/solmate/src/utils/FixedPointMathLib.sol";
import {ICardFactory} from "./interfaces/ICardFactory.sol";
import {ICommissionModule} from "./interfaces/ICommissionModule.sol";
import {IERC20} from "../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {ISafe} from "./interfaces/ISafe.sol";
import {ReentrancyGuard} from "../../lib/solmate/src/utils/ReentrancyGuard.sol";
import {SafeERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract EurB is ERC20, AccessControl {
    using SafeERC20 for IERC20;
    using FixedPointMathLib for uint256;

    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    // Define Admin Role.
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    // Define Minter Role.
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    // Define Burner Role.
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    // Max number of recursive calls for commissions.
    uint256 internal constant MAX_COMMISSIONS_DEPTH = 5;
    // 1 BIPS = 0,01%
    uint256 internal constant BIPS = 10_000;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // The address of the Card Factory.
    ICardFactory internal cardFactory;

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    error LengthMismatch();
    error MaxCommissionsDepth();
    error RecoveryNotAllowed();

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    /* //////////////////////////////////////////////////////////////
                                MODIFIERS
    ////////////////////////////////////////////////////////////// */

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    constructor(address cardFactory_) ERC20("EuroBrussels", "EURB") {
        _grantRole(ADMIN_ROLE, msg.sender);
        cardFactory = ICardFactory(cardFactory_);
    }

    /* //////////////////////////////////////////////////////////////
                         ERC20 LOGIC
    ////////////////////////////////////////////////////////////// */

    /**
     * @notice Mints an amount of tokens to a specific address.
     * @param to The address the tokens are minted for.
     * @param amount The amount of tokens to mint.
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyRole(BURNER_ROLE) {
        _burn(from, amount);
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
                         ADMIN FUNCTIONS
    ////////////////////////////////////////////////////////////// */

    /**
     * @notice This function will update the cardFactory address.
     * @param cardFactory_ The address of the new cardFactory.
     */
    function setCardFactory(address cardFactory_) external onlyOwner {
        cardFactory = ICardFactory(cardFactory_);
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
        if (asset == address(this)) revert RecoveryNotAllowed();

        IERC20(asset).safeTransfer(msg.sender, amount);
    }
}
