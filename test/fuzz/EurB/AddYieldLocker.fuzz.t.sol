// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {EurB_Fuzz_Test} from "./_EurB.fuzz.t.sol";

import {EurB} from "../../../src/token/EurB.sol";
import {FixedPointMathLib} from "../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import {IERC20} from "../../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {ILocker} from "../../../src/lockers/interfaces/ILocker.sol";
import {Ownable} from "../../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @notice Fuzz tests for the function "addYieldLockers" of contract "EurB".
 */
contract AddYieldLocker_EurB_Fuzz_Test is EurB_Fuzz_Test {
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
    function testFuzz_Revert_addYieldLocker_NotOwner(address random, address locker) public {
        vm.assume(random != users.dao);

        vm.startPrank(random);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, random));
        EURB.addYieldLocker(locker);
        vm.stopPrank();
    }

    function testFuzz_Revert_addYieldLocker_MaxYieldLockers(address[6] memory lockers) public {
        for (uint256 i; i < 5; ++i) {
            vm.prank(users.dao);
            EURB.addYieldLocker(lockers[i]);
        }

        // When: adding a locker too much.
        // Then: It should revert.
        vm.startPrank(users.dao);
        vm.expectRevert(EurB.MaxYieldLockers.selector);
        EURB.addYieldLocker(lockers[5]);
        vm.stopPrank();
    }

    function testFuzz_Success_addYieldLocker(address locker) public {
        vm.startPrank(users.dao);
        EURB.addYieldLocker(locker);
        vm.stopPrank();

        assertEq(EURB.yieldLockers(0), locker);
    }
}
