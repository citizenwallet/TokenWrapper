// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {EurB_Fuzz_Test} from "./_EurB.fuzz.t.sol";

import {EurB} from "../../../src/token/EurB.sol";
import {FixedPointMathLib} from "../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import {IERC20} from "../../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {ILocker} from "../../../src/lockers/interfaces/ILocker.sol";
import {Ownable} from "../../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @notice Fuzz tests for the function "setYieldInterval" of contract "EurB".
 */
contract SetYieldInterval_EurB_Fuzz_Test is EurB_Fuzz_Test {
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

    function testFuzz_Revert_SetYieldInterval_NotOwner(address random, uint256 yieldInterval) public {
        vm.assume(random != users.dao);

        vm.startPrank(random);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, random));
        EURB.setYieldInterval(yieldInterval);
        vm.stopPrank();
    }

    function testFuzz_Revert_setYieldInterval_MaxYieldInterval(uint256 yieldInterval) public {
        yieldInterval = bound(yieldInterval, 30 days + 1, type(uint256).max);

        // When: Calling setYieldInterval.
        // Then: It should revert.
        vm.startPrank(users.dao);
        vm.expectRevert(EurB.MaxYieldInterval.selector);
        EURB.setYieldInterval(yieldInterval);
        vm.stopPrank();
    }

    function testFuzz_Success_setWeights(uint256 yieldInterval) public {
        yieldInterval = bound(yieldInterval, 0, 30 days);

        // When: Calling setWeights.
        // Then: It should revert.
        vm.startPrank(users.dao);
        EURB.setYieldInterval(yieldInterval);
        vm.stopPrank();

        assertEq(EURB.yieldInterval(), yieldInterval);
    }
}
