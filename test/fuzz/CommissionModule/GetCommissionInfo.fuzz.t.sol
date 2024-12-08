// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {CommissionModule} from "../../../src/modules/CommissionModule.sol";
import {CommissionModule_Fuzz_Test} from "./_CommissionModule.fuzz.t.sol";
import {Ownable} from "../../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @notice Fuzz tests for the function "getCommissionInfo" of contract "CommissionModule".
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

    function testFuzz_Success_GetCommissionInfo_CommissionNotActive() public {
        // Given: Set commission group info.
        address[] memory recipients = new address[](1);
        uint256[] memory rates = new uint256[](1);

        rates[0] = 1_000;
        recipients[0] = address(SAFE1);

        // And: Set commissioned info.
        address commissioned = address(SAFE3);
        uint128 groupId = 1;
        // And: Commission is inactive.
        uint128 validUntil = uint128(block.timestamp) - 1;

        vm.startPrank(users.dao);
        COMMISSION_MODULE.setCommissionGroupInfo(groupId, recipients, rates);
        COMMISSION_MODULE.setCommissionedInfo(commissioned, groupId, validUntil);

        // When: Calling getCommissionInfo().
        (address[] memory recipients_, uint256[] memory rates_) = COMMISSION_MODULE.getCommissionInfo(commissioned);
        vm.stopPrank();

        // Then: It should return the correct values.
        assertEq(recipients_.length, 0);
        assertEq(rates_.length, 0);
    }

    function testFuzz_Success_GetCommissionInfo_CommissionActive() public {
        // Given: Set commission group info.
        address[] memory recipients = new address[](1);
        uint256[] memory rates = new uint256[](1);

        rates[0] = 1_000;
        recipients[0] = address(SAFE1);

        // And: Set commissioned info.
        address commissioned = address(SAFE3);
        uint128 groupId = 1;
        // And: Commission is still active.
        uint128 validUntil = uint128(block.timestamp) + 1;

        vm.startPrank(users.dao);
        COMMISSION_MODULE.setCommissionGroupInfo(groupId, recipients, rates);
        COMMISSION_MODULE.setCommissionedInfo(commissioned, groupId, validUntil);

        // When: Calling getCommissionInfo().
        (address[] memory recipients_, uint256[] memory rates_) = COMMISSION_MODULE.getCommissionInfo(commissioned);
        vm.stopPrank();

        // Then: It should return the correct values.
        assertEq(recipients_[0], address(SAFE1));
        assertEq(rates_[0], 1_000);
    }
}
