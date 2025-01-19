// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {EurB_Fuzz_Test} from "./_EurB.fuzz.t.sol";

import {EurBExtension} from "../../utils/extensions/EurBExtension.sol";
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
    function testFuzz_Success_deployment() public {
        // When: Deploying EURB.
        vm.prank(users.dao);
        EurBExtension eurB_ = new EurBExtension(address(CARD_FACTORY));

        // Then: Correct variables should be set.
        assertEq(eurB_.name(), "EuroBrussels");
        assertEq(eurB_.symbol(), "EURB");
        assertEq(address(eurB_.getCardFactory()), address(CARD_FACTORY));
    }
}
