// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Treasury_Fuzz_Test} from "./_Treasury.fuzz.t.sol";

import {FixedPointMathLib} from "../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import {IERC20} from "../../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {ILocker} from "../../../src/lockers/interfaces/ILocker.sol";
import {TreasuryV1} from "../../../src/treasury/TreasuryV1.sol";
import {TreasuryV1Extension} from "../../utils/extensions/TreasuryV1Extension.sol";

/**
 * @notice Fuzz tests for the function "initialize" of contract "Treasury".
 */
contract Initialize_Treasury_Fuzz_Test is Treasury_Fuzz_Test {
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
    function testFuzz_Revert_initialize_AlreadyInitialized() public {
        vm.expectRevert(TreasuryV1.AlreadyInitialized.selector);
        treasury.initialize(address(EURE));
    }

    function testFuzz_Success_initialize(address random) public {
        TreasuryV1Extension treasury_;
        vm.startPrank(random);
        treasury_ = new TreasuryV1Extension();
        treasury_.initialize(address(EURE));

        assertEq(treasury_.owner(), random);
        assertEq(treasury_.EURE(), address(EURE));
    }
}
