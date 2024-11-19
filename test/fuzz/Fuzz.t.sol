// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Base_Test} from "../Base.t.sol";
import {CardFactoryMock} from "../utils/mocks/CardFactoryMock.sol";
import {CommissionModule} from "../../src/modules/CommissionModule.sol";
import {ERC20Mock} from "../utils/mocks/ERC20Mock.sol";
import {EurB} from "../../src/token/EurB.sol";
import {IERC20} from "../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {SafeMock} from "../utils/mocks/SafeMock.sol";

/**
 * @notice Common logic needed by all fuzz tests.
 */
abstract contract Fuzz_Test is Base_Test {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    CardFactoryMock public CARD_FACTORY;
    CommissionModule public COMMISSION_MODULE;
    ERC20Mock public EURE;
    EurB public EURB;

    SafeMock public SAFE1;
    SafeMock public SAFE2;
    SafeMock public SAFE3;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        Base_Test.setUp();

        // Warp to have a timestamp of at least two days old.
        vm.warp(2 days);

        // Deploy contracts.
        vm.startPrank(users.dao);
        COMMISSION_MODULE = new CommissionModule();
        CARD_FACTORY = new CardFactoryMock(address(COMMISSION_MODULE));
        EURE = new ERC20Mock("Monerium EUR", "EURE", 18);
        EURB = new EurB(IERC20(address(EURE)), users.treasury, address(CARD_FACTORY));

        SAFE1 = new SafeMock();
        SAFE2 = new SafeMock();
        SAFE3 = new SafeMock();
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      HELPERS
    //////////////////////////////////////////////////////////////////////////*/
}
