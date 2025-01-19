// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Treasury_Fuzz_Test} from "./_Treasury.fuzz.t.sol";

import {FixedPointMathLib} from "../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import {IERC20} from "../../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {ILocker} from "../../../src/lockers/interfaces/ILocker.sol";
import {TreasuryV1} from "../../../src/treasury/TreasuryV1.sol";

/**
 * @notice Fuzz tests for the function "removeYieldLocker" of contract "Treasury".
 */
contract RemoveYieldLocker_Treasury_Fuzz_Test is Treasury_Fuzz_Test {
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
    function testFuzz_Revert_removeYieldLocker_NotOwner(address random, address locker) public {
        vm.assume(random != users.dao);

        vm.startPrank(random);
        bytes memory expectedError = abi.encodeWithSelector(TreasuryV1.OnlyOwner.selector);
        vm.expectRevert(expectedError);
        treasury.removeYieldLocker(locker);
        vm.stopPrank();
    }

    function testFuzz_Revert_removeYieldLocker_LengthMismatch(address locker) public {
        // Given: Add an initial locker and no weights.
        vm.startPrank(users.dao);
        treasury.addYieldLocker(locker);

        // When: Calling removeYieldLocker().
        // Then: It should revert.
        vm.expectRevert(TreasuryV1.LengthMismatch.selector);
        treasury.removeYieldLocker(locker);
        vm.stopPrank();
    }

    function testFuzz_Revert_removeYieldLocker_IsNotALocker(address locker, address notLocker) public {
        // Given: notLocker is not equal to locker.
        vm.assume(notLocker != locker);

        // And: Add an initial locker.
        vm.startPrank(users.dao);
        treasury.addYieldLocker(locker);

        // And: An initial weight.
        uint256[] memory weights = new uint256[](1);
        weights[0] = BIPS;
        treasury.setWeights(weights);

        // When: Calling removeYieldLocker().
        // Then: It should revert.
        vm.expectRevert(TreasuryV1.IsNotALocker.selector);
        treasury.removeYieldLocker(notLocker);
        vm.stopPrank();
    }

    function testFuzz_Success_removeYieldLocker(
        uint256 numberOfLockers,
        uint256[5] memory lockerDeposits,
        uint256[5] memory lockerYields,
        uint256[5] memory lockerWeights,
        StateVars memory stateVars,
        uint256 index
    ) public {
        // Given: Set valid state.
        (, uint256 numberOfLockers_) = setStateOfLockers(numberOfLockers, lockerDeposits, lockerYields, lockerWeights);
        stateVars = setStateVars(stateVars);

        index = bound(index, 0, numberOfLockers_ - 1);

        uint256 toWithdraw = ILocker(treasury.yieldLockers(index)).getTotalValue(treasury.EURE());
        uint256 balancePreRemoval = EURE.balanceOf(address(treasury));

        vm.startPrank(users.dao);
        treasury.removeYieldLocker(treasury.yieldLockers(index));
        vm.stopPrank();

        uint256 balanceAfterRemoval = EURE.balanceOf(address(treasury));
        assertEq(balanceAfterRemoval, balancePreRemoval + toWithdraw);
        assertEq(treasury.getYieldLockersLength(), numberOfLockers_ - 1);
        assertEq(treasury.getWeightsLength(), numberOfLockers_ - 1);
    }
}
