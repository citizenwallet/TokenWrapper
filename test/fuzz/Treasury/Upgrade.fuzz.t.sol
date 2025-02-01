// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Treasury_Fuzz_Test} from "./_Treasury.fuzz.t.sol";

import {FixedPointMathLib} from "../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import {IERC20} from "../../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {ILocker} from "../../../src/lockers/interfaces/ILocker.sol";
import {TreasuryV1} from "../../../src/treasury/TreasuryV1.sol";
import {TreasuryV2Mock} from "../../utils/mocks/TreasuryV2Mock.sol";

/**
 * @notice Fuzz tests for the function "upgrade" of contract "Treasury".
 */
contract Upgrade_Treasury_Fuzz_Test is Treasury_Fuzz_Test {
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
    function testFuzz_Revert_upgrade() public {
        // Given : Deploy new Treasury logic
        TreasuryV2Mock treasuryV2 = new TreasuryV2Mock();

        // When : Calling upgrade from a non-owner
        // Then : It should revert
        vm.startPrank(users.unprivilegedAddress);
        bytes memory expectedError = abi.encodeWithSelector(TreasuryV1.OnlyOwner.selector);
        vm.expectRevert(expectedError);
        treasury.upgrade(address(treasuryV2));
        vm.stopPrank();
    }

    function testFuzz_Success_upgrade(address newOwner) public {
        // Given : Deploy new Treasury logic
        TreasuryV2Mock treasuryV2 = new TreasuryV2Mock();

        // When : Upgrading the current implementation
        vm.startPrank(users.dao);
        treasury.upgrade(address(treasuryV2));

        // And: Change storage state via new implementation.
        // On V1 implementation this function would revert (see extension).
        treasury.setNewOwner(newOwner);

        // Then: It should return the correct values.
        assertEq(treasury.owner(), newOwner);
        assertEq(treasury.getImplementation(), address(treasuryV2));

        vm.stopPrank();
    }
}
