// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {EurB_Fuzz_Test} from "./_EurB.fuzz.t.sol";

import {EurB} from "../../../src/token/EurB.sol";
import {FixedPointMathLib} from "../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import {IERC20} from "../../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {ILocker} from "../../../src/lockers/interfaces/ILocker.sol";
import {Ownable} from "../../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @notice Fuzz tests for the function "setIdleRatio" of contract "EurB".
 */
contract SetIdleRatio_EurB_Fuzz_Test is EurB_Fuzz_Test {
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
    function testFuzz_Revert_SetIdleRatio_NotOwner(address random, uint256 ratio) public {
        vm.assume(random != users.dao);

        vm.startPrank(random);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, random));
        EURB.setIdleRatio(ratio);
        vm.stopPrank();
    }

    function testFuzz_Success_SetIdleRatio(uint256 ratio) public {
        ratio = bound(ratio, 0, BIPS);

        vm.startPrank(users.dao);
        EURB.setIdleRatio(ratio);
        vm.stopPrank();

        assertEq(EURB.idleRatio(), ratio);
    }
}
