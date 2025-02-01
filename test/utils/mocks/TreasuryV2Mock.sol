// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {FixedPointMathLib} from "../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import {IERC20} from "../../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {ILocker} from "../../../src/lockers/interfaces/ILocker.sol";
import {ReentrancyGuard} from "../../../lib/solmate/src/utils/ReentrancyGuard.sol";
import {SafeERC20} from "../../../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {StorageV1} from "../../../src/treasury/StorageV1.sol";

contract TreasuryV2Mock is StorageV1 {
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

    /* //////////////////////////////////////////////////////////////
                    PRIVATE YIELD LOCKERS LOGIC
    ////////////////////////////////////////////////////////////// */

    /* ///////////////////////////////////////////////////////////////
                          PROXY MANAGEMENT
    /////////////////////////////////////////////////////////////// */

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
        if (asset == address(this)) revert RecoveryNotAllowed();

        IERC20(asset).safeTransfer(msg.sender, amount);
    }

    /**
     * @notice New function added to for testing.
     * @param newOwner The new owner address.
     */
    function setNewOwner(address newOwner) external {
        owner = newOwner;
    }
}
