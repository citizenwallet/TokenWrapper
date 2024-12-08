// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {CommissionModule} from "../../../src/modules/CommissionModule.sol";
import {CommissionModule_Fuzz_Test} from "./_CommissionModule.fuzz.t.sol";
import {Ownable} from "../../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @notice Fuzz tests for the function "setCommissionGroupInfo" of contract "CommissionModule".
 */
contract SetCommissionGroupInfo_EurB_Fuzz_Test is CommissionModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        CommissionModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_SetCommissionGroupInfo_NotOwner(uint256 id, address random) public {
        address[] memory recipients = new address[](1);
        uint256[] memory rates = new uint256[](1);
        vm.assume(random != users.dao);

        vm.startPrank(random);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, random));
        COMMISSION_MODULE.setCommissionGroupInfo(id, recipients, rates);
        vm.stopPrank();
    }

    function testFuzz_Revert_SetCommissionGroupInfo_MaxRecipients(uint256 id) public {
        // Given: Recipients lenght is above max.
        uint256 length = COMMISSION_MODULE.MAX_RECIPIENTS();
        address[] memory recipients = new address[](length + 1);
        uint256[] memory rates = new uint256[](length + 1);
        // When: Calling setCommissionGroupInfo()
        // Then: It should revert.
        vm.startPrank(users.dao);
        vm.expectRevert(CommissionModule.MaxRecipients.selector);
        COMMISSION_MODULE.setCommissionGroupInfo(id, recipients, rates);
        vm.stopPrank();
    }

    function testFuzz_Revert_SetCommissionGroupInfo_LengthMismatch(uint256 id) public {
        // Given: Length is not the same.
        address[] memory recipients = new address[](1);
        uint256[] memory rates = new uint256[](2);
        // When: Calling setCommissionGroupInfo()
        // Then: It should revert.
        vm.startPrank(users.dao);
        vm.expectRevert(CommissionModule.LengthMismatch.selector);
        COMMISSION_MODULE.setCommissionGroupInfo(id, recipients, rates);
        vm.stopPrank();
    }

    function testFuzz_Revert_SetCommissionGroupInfo_MaxCommissionRate(uint256 id) public {
        // Given: Lengths are the same.
        address[] memory recipients = new address[](2);
        uint256[] memory rates = new uint256[](2);

        // And: Rate is too high.
        rates[0] = COMMISSION_MODULE.MAX_COMMISSION();
        rates[1] = 1;

        // When: Calling setCommissionGroupInfo()
        // Then: It should revert.
        vm.startPrank(users.dao);
        vm.expectRevert(CommissionModule.MaxCommissionRate.selector);
        COMMISSION_MODULE.setCommissionGroupInfo(id, recipients, rates);
        vm.stopPrank();
    }

    function testFuzz_Success_SetCommissionGroupInfo(uint256 id) public {
        // Given: Lengths are the same.
        address[] memory recipients = new address[](2);
        uint256[] memory rates = new uint256[](2);

        // And: Rate is within limits
        rates[0] = 1_000;
        rates[1] = 500;

        // And: Recipients are set.
        recipients[0] = address(SAFE1);
        recipients[1] = address(SAFE2);

        // When: Calling setCommissionGroupInfo()
        vm.startPrank(users.dao);
        COMMISSION_MODULE.setCommissionGroupInfo(id, recipients, rates);
        vm.stopPrank();

        // Then: The correct values should be set.
        (address[] memory recipients_, uint256[] memory rates_) = COMMISSION_MODULE.getCommissionGroupInfo(id);
        assertEq(recipients_[0], recipients[0]);
        assertEq(recipients_[1], recipients[1]);
        assertEq(rates_[0], rates[0]);
        assertEq(rates_[1], rates[1]);
    }
}
