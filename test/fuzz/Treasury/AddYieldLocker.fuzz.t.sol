// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Treasury_Fuzz_Test} from "./_Treasury.fuzz.t.sol";

import {FixedPointMathLib} from "../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import {IERC20} from "../../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {ILocker} from "../../../src/lockers/interfaces/ILocker.sol";
import {TreasuryV1} from "../../../src/treasury/TreasuryV1.sol";

/**
 * @notice Fuzz tests for the function "addYieldLockers" of contract "Treasury".
 */
contract AddYieldLocker_Treasury_Fuzz_Test is Treasury_Fuzz_Test {
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
    function testFuzz_Revert_addYieldLocker_NotOwner(address random, address locker) public {
        vm.assume(random != users.dao);

        vm.startPrank(random);
        bytes memory expectedError = abi.encodeWithSelector(TreasuryV1.OnlyOwner.selector);
        vm.expectRevert(expectedError);
        treasury.addYieldLocker(locker);
        vm.stopPrank();
    }

    function testFuzz_Revert_addYieldLocker_MaxYieldLockers(address[6] memory lockers) public {
        for (uint256 i; i < 5; ++i) {
            vm.prank(users.dao);
            treasury.addYieldLocker(lockers[i]);
        }

        // When: adding a locker too much.
        // Then: It should revert.
        vm.startPrank(users.dao);
        vm.expectRevert(TreasuryV1.MaxYieldLockers.selector);
        treasury.addYieldLocker(lockers[5]);
        vm.stopPrank();
    }

    function testFuzz_Success_addYieldLocker(address locker) public {
        vm.startPrank(users.dao);
        treasury.addYieldLocker(locker);
        vm.stopPrank();

        assertEq(treasury.yieldLockers(0), locker);
    }
}
