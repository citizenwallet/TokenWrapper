// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Treasury_Fuzz_Test} from "./_Treasury.fuzz.t.sol";

import {FixedPointMathLib} from "../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import {IERC20} from "../../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {ILocker} from "../../../src/lockers/interfaces/ILocker.sol";
import {Ownable} from "../../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {TreasuryV1} from "../../../src/treasury/TreasuryV1.sol";

/**
 * @notice Fuzz tests for the function "setWeights" of contract "Treasury".
 */
contract SetWeights_Treasury_Fuzz_Test is Treasury_Fuzz_Test {
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

    function testFuzz_Revert_SetWeigths_NotOwner(address random) public {
        vm.assume(random != users.dao);

        uint256[] memory weights = new uint256[](1);
        weights[0] = 1000;

        vm.startPrank(random);
        bytes memory expectedError = abi.encodeWithSelector(TreasuryV1.OnlyOwner.selector);
        vm.expectRevert(expectedError);
        treasury.setWeights(weights);
        vm.stopPrank();
    }

    function testFuzz_Revert_setWeights_LengthMismatch(address[2] memory lockers) public {
        // Add 2 lockers
        for (uint256 i; i < 2; ++i) {
            vm.prank(users.dao);
            treasury.addYieldLocker(lockers[i]);
        }

        // Set weights with length of 1.
        uint256[] memory weights = new uint256[](1);
        weights[0] = 1000;

        // When: Calling setWeights.
        // Then: It should revert.
        vm.startPrank(users.dao);
        vm.expectRevert(TreasuryV1.LengthMismatch.selector);
        treasury.setWeights(weights);
        vm.stopPrank();
    }

    function testFuzz_Revert_setWeights_WeightsNotValid(address[2] memory lockers) public {
        // Add 2 lockers
        for (uint256 i; i < 2; ++i) {
            vm.prank(users.dao);
            treasury.addYieldLocker(lockers[i]);
        }

        // Set weights with length of 2.
        uint256[] memory weights = new uint256[](2);
        weights[0] = 1000;
        weights[1] = 5000;

        // When: Calling setWeights.
        // Then: It should revert.
        vm.startPrank(users.dao);
        vm.expectRevert(TreasuryV1.WeightsNotValid.selector);
        treasury.setWeights(weights);
        vm.stopPrank();
    }

    function testFuzz_Success_setWeights(address[2] memory lockers) public {
        // Add 2 lockers
        for (uint256 i; i < 2; ++i) {
            vm.prank(users.dao);
            treasury.addYieldLocker(lockers[i]);
        }

        // Set weights with length of 2.
        uint256[] memory weights = new uint256[](2);
        weights[0] = 6000;
        weights[1] = 4000;

        // When: Calling setWeights.
        // Then: It should revert.
        vm.startPrank(users.dao);
        treasury.setWeights(weights);
        vm.stopPrank();

        assertEq(treasury.lockersWeights(0), 6000);
        assertEq(treasury.lockersWeights(1), 4000);
    }
}
