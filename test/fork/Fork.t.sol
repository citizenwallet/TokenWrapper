// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Base_Test} from "../Base.t.sol";
import {CardFactoryMock} from "../utils/mocks/CardFactoryMock.sol";
import {CommissionModule} from "../../src/modules/CommissionModule.sol";
import {ERC20Mock} from "../utils/mocks/ERC20Mock.sol";
import {EurB} from "../../src/token/EurB.sol";
import {EurBExtension} from "../utils/extensions/EurBExtension.sol";
import {IERC20} from "../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {SafeMock} from "../utils/mocks/SafeMock.sol";

/**
 * @notice Common logic needed by all fork tests.
 */
abstract contract Fork_Test is Base_Test {
    /*//////////////////////////////////////////////////////////////////////////
                                     CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    IERC20 public EURE = IERC20(0xcB444e90D8198415266c6a2724b7900fb12FC56E);
    IERC20 public USDC = IERC20(0xDDAfbb505ad214D7b80b1f830fcCc89B60fb7A83);

    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    uint256 public BIPS = 10_000;
    string internal RPC_URL = vm.envString("RPC_URL");
    uint256 internal fork;

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    EurBExtension public EURB;
    CardFactoryMock public CARD_FACTORY;
    CommissionModule public COMMISSION_MODULE;
    SafeMock public SAFE;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        fork = vm.createFork(RPC_URL);
        vm.selectFork(fork);

        Base_Test.setUp();
        assertEq(block.chainid, 100, "Chain ID does not match Mainnet");

        // Deploy contracts.
        vm.startPrank(users.dao);
        COMMISSION_MODULE = new CommissionModule();
        CARD_FACTORY = new CardFactoryMock(address(COMMISSION_MODULE));
        EURB = new EurBExtension(EURE, users.treasury, address(CARD_FACTORY));
        SAFE = new SafeMock();

        // Label the deployed tokens
        vm.label({account: address(COMMISSION_MODULE), newLabel: "CommissionModule"});
        vm.label({account: address(CARD_FACTORY), newLabel: "CardFactory"});
        vm.label({account: address(EURE), newLabel: "EURE"});
        vm.label({account: address(EURB), newLabel: "EURB"});
        vm.label({account: address(SAFE), newLabel: "Safe"});
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      HELPERS
    //////////////////////////////////////////////////////////////////////////*/
}
