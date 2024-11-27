// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Base_Test} from "../Base.t.sol";
import {CardFactoryMock} from "../utils/mocks/CardFactoryMock.sol";
import {CommissionModule} from "../../src/modules/CommissionModule.sol";
import {ERC20Mock} from "../utils/mocks/ERC20Mock.sol";
import {EurB} from "../../src/token/EurB.sol";
import {EurBExtension} from "../utils/extensions/EurBExtension.sol";
import {IERC20} from "../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {LockerMock} from "../utils/mocks/LockerMock.sol";
import {SafeMock} from "../utils/mocks/SafeMock.sol";

/**
 * @notice Common logic needed by all fuzz tests.
 */
abstract contract Fuzz_Test is Base_Test {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    uint256 public BIPS = 10_000;
    // Unix timestamps of 12 November 2024
    uint256 public DATE_12_NOV_24 = 1731418562;

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    CardFactoryMock public CARD_FACTORY;
    CommissionModule public COMMISSION_MODULE;
    ERC20Mock public EURE;
    EurBExtension public EURB;

    SafeMock public SAFE1;
    SafeMock public SAFE2;
    SafeMock public SAFE3;

    LockerMock[] public yieldLockers;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        Base_Test.setUp();

        // Warp to have a timestamp of at least two days old.
        vm.warp(DATE_12_NOV_24);

        // Deploy contracts.
        vm.startPrank(users.dao);
        COMMISSION_MODULE = new CommissionModule();
        CARD_FACTORY = new CardFactoryMock(address(COMMISSION_MODULE));
        CARD_FACTORY.setCommissionHookModule(address(COMMISSION_MODULE));
        EURE = new ERC20Mock("Monerium EUR", "EURE", 18);
        EURB = new EurBExtension(IERC20(address(EURE)), users.treasury, address(CARD_FACTORY));

        SAFE1 = new SafeMock();
        SAFE2 = new SafeMock();
        SAFE3 = new SafeMock();

        // Label the deployed tokens
        vm.label({account: address(COMMISSION_MODULE), newLabel: "CommissionModule"});
        vm.label({account: address(CARD_FACTORY), newLabel: "CardFactory"});
        vm.label({account: address(EURE), newLabel: "EURE"});
        vm.label({account: address(EURB), newLabel: "EURB"});
        vm.label({account: address(SAFE1), newLabel: "Safe 1"});
        vm.label({account: address(SAFE2), newLabel: "Safe 2"});
        vm.label({account: address(SAFE3), newLabel: "Safe 3"});
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    function setValidStateCommissionModule(
        uint256 numberOfRecipients,
        address[5] memory recipients,
        uint256[5] memory rates,
        uint128 id
    ) public returns (uint128 id_) {
        // Valid number of recipients
        numberOfRecipients = bound(numberOfRecipients, 1, COMMISSION_MODULE.MAX_RECIPIENTS());
        vm.assume(id > 0);

        // Set valid rates.
        address[] memory recipients_ = new address[](numberOfRecipients);
        uint256[] memory rates_ = new uint256[](numberOfRecipients);
        for (uint256 i; i < numberOfRecipients; ++i) {
            rates_[i] = bound(rates[i], 1, 400);
            vm.assume(recipients[i] != address(0));
            vm.assume(recipients[i] != address(SAFE1));
            vm.assume(recipients[i] != address(SAFE2));
            vm.assume(recipients[i] != address(SAFE3));
            recipients_[i] = recipients[i];
        }

        vm.prank(users.dao);
        COMMISSION_MODULE.setCommissionGroupInfo(id, recipients_, rates_);
        return id;
    }

    function setValidCommissionedInfo(address commissioned, uint128 groupId, bool valid) public {
        uint128 validUntil;
        if (valid) {
            validUntil = uint128(block.timestamp + 1);
        } else {
            validUntil = uint128(block.timestamp - 1);
        }
        vm.prank(users.dao);
        COMMISSION_MODULE.setCommissionedInfo(commissioned, groupId, validUntil);
    }
}
