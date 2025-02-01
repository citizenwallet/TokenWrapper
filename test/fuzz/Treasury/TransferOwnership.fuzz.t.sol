// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Treasury_Fuzz_Test} from "./_Treasury.fuzz.t.sol";

import {FixedPointMathLib} from "../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import {IERC20} from "../../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {ILocker} from "../../../src/lockers/interfaces/ILocker.sol";
import {TreasuryV1} from "../../../src/treasury/TreasuryV1.sol";
import {TreasuryV2Mock} from "../../utils/mocks/TreasuryV2Mock.sol";

/**
 * @notice Fuzz tests for the function "transferOwnership" of contract "Treasury".
 */
contract TransferOwnership_Treasury_Fuzz_Test is Treasury_Fuzz_Test {
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
    function testFuzz_Revert_transferOwnership_NotOwner(address newOwner) public {
        // When : Calling transferOwnership from a non-owner
        // Then : It should revert
        vm.startPrank(users.unprivilegedAddress);
        bytes memory expectedError = abi.encodeWithSelector(TreasuryV1.OnlyOwner.selector);
        vm.expectRevert(expectedError);
        treasury.transferOwnership(newOwner);
        vm.stopPrank();
    }

    function testFuzz_Success_transferOwnership(address newOwner) public {
        // Given : New owner is not equal to current owner.
        vm.assume(newOwner != users.dao);

        // When : Calling transferOwnership.
        vm.prank(users.dao);
        treasury.transferOwnership(newOwner);

        // Then : A new owner should be set.
        assertEq(treasury.owner(), newOwner);
    }
}
