// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Treasury_Fuzz_Test} from "./_Treasury.fuzz.t.sol";

import {FixedPointMathLib} from "../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import {IERC20} from "../../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {ILocker} from "../../../src/lockers/interfaces/ILocker.sol";
import {TreasuryV1} from "../../../src/treasury/TreasuryV1.sol";

/**
 * @notice Fuzz tests for the function "setYieldInterval" of contract "Treasury".
 */
contract SetYieldInterval_Treasury_Fuzz_Test is Treasury_Fuzz_Test {
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

    function testFuzz_Revert_SetYieldInterval_NotOwner(address random, uint256 yieldInterval) public {
        vm.assume(random != users.dao);

        vm.startPrank(random);
        bytes memory expectedError = abi.encodeWithSelector(TreasuryV1.OnlyOwner.selector);
        vm.expectRevert(expectedError);
        treasury.setYieldInterval(yieldInterval);
        vm.stopPrank();
    }

    function testFuzz_Revert_setYieldInterval_MaxYieldInterval(uint256 yieldInterval) public {
        yieldInterval = bound(yieldInterval, 30 days + 1, type(uint256).max);

        // When: Calling setYieldInterval.
        // Then: It should revert.
        vm.startPrank(users.dao);
        vm.expectRevert(TreasuryV1.MaxYieldInterval.selector);
        treasury.setYieldInterval(yieldInterval);
        vm.stopPrank();
    }

    function testFuzz_Success_setWeights(uint256 yieldInterval) public {
        yieldInterval = bound(yieldInterval, 0, 30 days);

        // When: Calling setWeights.
        // Then: It should revert.
        vm.startPrank(users.dao);
        treasury.setYieldInterval(yieldInterval);
        vm.stopPrank();

        assertEq(treasury.yieldInterval(), yieldInterval);
    }
}
