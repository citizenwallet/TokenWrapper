// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {CommissionModule} from "../../../src/modules/CommissionModule.sol";
import {CommissionModule_Fuzz_Test} from "./_CommissionModule.fuzz.t.sol";
import {Ownable} from "../../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @notice Fuzz tests for the function "setCommissionedInfo" of contract "CommissionModule".
 */
contract SetCommissionedInfo_EurB_Fuzz_Test is CommissionModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        CommissionModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_SetCommissionedInfo_NotOwner(address random) public {
        address[] memory commissioned = new address[](1);
        uint128[] memory groupId = new uint128[](1);
        uint128[] memory validUntil = new uint128[](1);

        vm.assume(random != users.dao);

        vm.startPrank(random);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, random));
        COMMISSION_MODULE.setCommissionedInfo(commissioned, groupId, validUntil);
        vm.stopPrank();
    }

    function testFuzz_Revert_SetCommissionedInfo_LengthMismatch_GroupId() public {
        // Given: groupId length is not the same.
        uint256 length = 1;

        address[] memory commissioned = new address[](length);
        uint128[] memory groupId = new uint128[](length + 1);
        uint128[] memory validUntil = new uint128[](length);

        // When: Calling setCommissionedInfo()
        // Then: It should revert.
        vm.startPrank(users.dao);
        vm.expectRevert(CommissionModule.LengthMismatch.selector);
        COMMISSION_MODULE.setCommissionedInfo(commissioned, groupId, validUntil);
        vm.stopPrank();
    }

    function testFuzz_Revert_SetCommissionedInfo_LengthMismatch_ValidUntil() public {
        // Given: validUntil length is not the same.
        uint256 length = 1;

        address[] memory commissioned = new address[](length);
        uint128[] memory groupId = new uint128[](length);
        uint128[] memory validUntil = new uint128[](length + 1);

        // When: Calling setCommissionedInfo().
        // Then: It should revert.
        vm.startPrank(users.dao);
        vm.expectRevert(CommissionModule.LengthMismatch.selector);
        COMMISSION_MODULE.setCommissionedInfo(commissioned, groupId, validUntil);
        vm.stopPrank();
    }

    function testFuzz_Success_SetCommissionedInfo() public {
        // Given: length is the same.
        uint256 length = 2;

        address[] memory commissioned = new address[](length);
        uint128[] memory groupId = new uint128[](length);
        uint128[] memory validUntil = new uint128[](length);

        commissioned[0] = address(SAFE1);
        commissioned[1] = address(SAFE2);
        groupId[0] = 1;
        groupId[1] = 200;
        validUntil[0] = uint128(block.timestamp);
        validUntil[1] = uint128(block.timestamp + 365 days);

        // When: Calling setCommissionedInfo().
        vm.startPrank(users.dao);
        COMMISSION_MODULE.setCommissionedInfo(commissioned, groupId, validUntil);
        vm.stopPrank();

        // Then: Correct values should be set.
        (uint128 groupId_, uint128 validUntil_) = COMMISSION_MODULE.commissionedInfo(address(SAFE1));
        assertEq(groupId_, groupId[0]);
        assertEq(validUntil_, validUntil[0]);

        (groupId_, validUntil_) = COMMISSION_MODULE.commissionedInfo(address(SAFE2));
        assertEq(groupId_, groupId[1]);
        assertEq(validUntil_, validUntil[1]);
    }
}
