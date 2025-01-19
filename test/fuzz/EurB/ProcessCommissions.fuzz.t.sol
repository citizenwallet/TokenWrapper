// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {EurB_Fuzz_Test} from "./_EurB.fuzz.t.sol";

import {EURB} from "../../../src/token/EURB.sol";
import {FixedPointMathLib} from "../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import {IERC20} from "../../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {ILocker} from "../../../src/lockers/interfaces/ILocker.sol";

/**
 * @notice Fuzz tests for the function "processCommissions" of contract "EurB".
 */
contract ProcessCommissions_EurB_Fuzz_Test is EurB_Fuzz_Test {
    using FixedPointMathLib for uint256;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        EurB_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_ProcessCommissions_MaxCommissionsDepth(uint256 depth, address random, uint256 amount)
        public
    {
        // Given: Depth is > max depth
        depth = bound(depth, 6, type(uint256).max);

        // When: Calling processCommissions.
        // Then: It should revert.
        vm.expectRevert(EURB.MaxCommissionsDepth.selector);
        EURB_.processCommissions(address(COMMISSION_MODULE), random, amount, depth);
    }

    function testFuzz_Success_ProcessCommissions(
        uint128 amount,
        uint256 numberOfRecipients,
        address[5] memory recipients,
        uint256[5] memory rates,
        uint128 id
    ) public {
        // Given: Amount is positive.
        amount = uint128(bound(amount, 1e18, type(uint128).max));

        // And: Commission module is set.
        address commissionModule = address(COMMISSION_MODULE);
        SAFE1.setModule(commissionModule);
        assertEq(SAFE1.isModuleEnabled(commissionModule), true);

        // And: Valid state in the Commission Module.
        id = setValidStateCommissionModule(numberOfRecipients, recipients, rates, id);
        setValidCommissionedInfo(address(SAFE1), id, true);

        // When: Calling processCommissions.
        vm.prank(users.minter);
        EURB_.mint(address(SAFE1), amount);
        EURB_.processCommissions(address(COMMISSION_MODULE), address(SAFE1), uint256(amount), 0);

        // Then: The commissions should have been paid.
        (address[] memory recipients_, uint256[] memory rates_) = COMMISSION_MODULE.getCommissionInfo(address(SAFE1));
        for (uint256 i; i < recipients_.length; ++i) {
            uint256 expectedCommission = uint256(amount).mulDivDown(rates_[i], BIPS);
            assertEq(expectedCommission, EURB_.balanceOf(recipients_[i]));
        }
    }

    function testFuzz_Success_ProcessCommissions_OneLevelDepth(uint128 amount) public {
        // Given: Amount is positive.
        amount = uint128(bound(amount, 1e18, type(uint128).max));

        // And: Safe 2 is recipients of ID 1, and Safe3 of id 2
        address[] memory recipients = new address[](1);
        uint256[] memory rates = new uint256[](1);
        recipients[0] = address(SAFE2);
        rates[0] = 2000;
        vm.prank(users.dao);
        COMMISSION_MODULE.setCommissionGroupInfo(1, recipients, rates);

        recipients[0] = address(SAFE3);
        vm.prank(users.dao);
        COMMISSION_MODULE.setCommissionGroupInfo(2, recipients, rates);

        // And: Commission module is set.
        address commissionModule = address(COMMISSION_MODULE);
        SAFE1.setModule(commissionModule);
        assertEq(SAFE1.isModuleEnabled(commissionModule), true);
        SAFE2.setModule(commissionModule);
        assertEq(SAFE2.isModuleEnabled(commissionModule), true);

        // And: Safe1 and Safe2 are both commissioned for group 1 and 2 respectively.
        vm.startPrank(users.dao);
        COMMISSION_MODULE.setCommissionedInfo(address(SAFE1), 1, uint128(block.timestamp + 1));
        COMMISSION_MODULE.setCommissionedInfo(address(SAFE2), 2, uint128(block.timestamp + 1));
        vm.stopPrank();

        // When: Calling processCommissions.
        vm.prank(users.minter);
        EURB_.mint(address(SAFE1), amount);
        EURB_.processCommissions(address(COMMISSION_MODULE), address(SAFE1), uint256(amount), 0);

        // Then: The commissions should have been paid.
        uint256 expectedCommission = uint256(amount).mulDivDown(rates[0], BIPS);
        uint256 secondCommission = expectedCommission.mulDivDown(rates[0], BIPS);

        assertEq(EURB_.balanceOf(address(SAFE3)), secondCommission);
        assertEq(EURB_.balanceOf(address(SAFE2)), expectedCommission - secondCommission);
    }

    function testFuzz_Success_ProcessCommissions_OneLevelDepth_CommissionedIsRecipient(uint128 amount) public {
        // Given: Amount is positive.
        amount = uint128(bound(amount, 1e18, type(uint128).max));

        // And: Safe 2 is recipient of group1 but is also commissioned.
        address[] memory recipients = new address[](1);
        uint256[] memory rates = new uint256[](1);
        recipients[0] = address(SAFE2);
        rates[0] = 2000;
        vm.prank(users.dao);
        COMMISSION_MODULE.setCommissionGroupInfo(1, recipients, rates);

        // And: Commission module is set.
        address commissionModule = address(COMMISSION_MODULE);
        SAFE1.setModule(commissionModule);
        assertEq(SAFE1.isModuleEnabled(commissionModule), true);
        SAFE2.setModule(commissionModule);
        assertEq(SAFE2.isModuleEnabled(commissionModule), true);

        // And: Safe1 and Safe2 are both commissioned.
        vm.startPrank(users.dao);
        COMMISSION_MODULE.setCommissionedInfo(address(SAFE1), 1, uint128(block.timestamp + 1));
        COMMISSION_MODULE.setCommissionedInfo(address(SAFE2), 1, uint128(block.timestamp + 1));
        vm.stopPrank();

        // When: Calling processCommissions.
        vm.prank(users.minter);
        EURB_.mint(address(SAFE1), amount);
        EURB_.processCommissions(address(COMMISSION_MODULE), address(SAFE1), uint256(amount), 0);

        // Then: The commissions should have been paid.
        (address[] memory recipients_, uint256[] memory rates_) = COMMISSION_MODULE.getCommissionInfo(address(SAFE1));
        for (uint256 i; i < recipients_.length; ++i) {
            uint256 expectedCommission = uint256(amount).mulDivDown(rates_[i], BIPS);
            assertEq(expectedCommission, EURB_.balanceOf(recipients_[i]));
        }
    }

    function testFuzz_Success_ProcessCommissions_CommissionedIsAContractButNotASafe(uint128 amount) public {
        // Given: Amount is positive.
        amount = uint128(bound(amount, 1e18, type(uint128).max));

        // When: Calling processCommissions.
        EURB_.processCommissions(address(COMMISSION_MODULE), address(EURE), uint256(amount), 0);
    }
}
