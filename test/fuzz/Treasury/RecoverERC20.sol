// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Treasury_Fuzz_Test} from "./_Treasury.fuzz.t.sol";

import {ERC20Mock} from "../../utils/mocks/ERC20Mock.sol";
import {FixedPointMathLib} from "../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import {IERC20} from "../../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {ILocker} from "../../../src/lockers/interfaces/ILocker.sol";
import {TreasuryV1} from "../../../src/treasury/TreasuryV1.sol";

/**
 * @notice Fuzz tests for the function "recoverERC20" of contract "Treasury".
 */
contract RecoverERC20_Treasury_Fuzz_Test is Treasury_Fuzz_Test {
    using FixedPointMathLib for uint256;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Treasury_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_recoverERC20_NotOwner(address asset, uint256 amount) public {
        // When : Calling recoverERC20 from a non-owner
        // Then : It should revert
        vm.startPrank(users.unprivilegedAddress);
        bytes memory expectedError = abi.encodeWithSelector(TreasuryV1.OnlyOwner.selector);
        vm.expectRevert(expectedError);
        treasury.recoverERC20(asset, amount);
        vm.stopPrank();
    }

    function testFuzz_Revert_recoverERC20_EURE(uint256 amount) public {
        // Given : asset to recover is EURE
        address asset = address(EURE);

        // When : Calling recoverERC20 with EURE as asset
        // Then : It should revert
        vm.startPrank(users.dao);
        bytes memory expectedError = abi.encodeWithSelector(TreasuryV1.RecoveryNotAllowed.selector);
        vm.expectRevert(expectedError);
        treasury.recoverERC20(asset, amount);
        vm.stopPrank();
    }

    function testFuzz_success_recoverERC20(uint256 amountToRecover) public {
        // Given: A random ERC20 is minted to the Treasury.
        ERC20Mock asset = new ERC20Mock("random", "rdm", 18);
        asset.mint(address(treasury), amountToRecover);

        // When: Calling recoverERC20()
        vm.prank(users.dao);
        treasury.recoverERC20(address(asset), amountToRecover);

        // Then: It should send the amount of assets to the owner.
        assertEq(asset.balanceOf(users.dao), amountToRecover);
        assertEq(asset.balanceOf(address(treasury)), 0);
    }
}
