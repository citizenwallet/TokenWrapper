// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {EurB_Fuzz_Test} from "./_EurB.fuzz.t.sol";

import {EurB} from "../../../src/token/EurB.sol";
import {IERC20} from "../../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";

/**
 * @notice Fuzz tests for the function "constructor" of contract "EurB".
 */
contract Constructor_EurB_Fuzz_Test is EurB_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        EurB_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_deployment(address treasury) public {
        // When: Deploying EURB.
        vm.prank(users.dao);
        EurB eurB = new EurB(IERC20(address(EURE)), treasury, address(CARD_FACTORY));

        // Then: Correct variables should be set.
        assertEq(address(eurB.underlying()), address(EURE));
        assertEq(eurB.treasury(), treasury);
        assertEq(eurB.owner(), users.dao);
        assertEq(eurB.name(), "EuroBrussels");
        assertEq(eurB.symbol(), "EURB");
        assertEq(address(eurB.cardFactory()), address(CARD_FACTORY));
    }
}
