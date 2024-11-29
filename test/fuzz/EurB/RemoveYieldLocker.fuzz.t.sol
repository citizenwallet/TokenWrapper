// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {EurB_Fuzz_Test} from "./_EurB.fuzz.t.sol";

import {EurB} from "../../../src/token/EurB.sol";
import {FixedPointMathLib} from "../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import {IERC20} from "../../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {ILocker} from "../../../src/lockers/interfaces/ILocker.sol";
import {Ownable} from "../../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @notice Fuzz tests for the function "removeYieldLocker" of contract "EurB".
 */
contract RemoveYieldLocker_EurB_Fuzz_Test is EurB_Fuzz_Test {
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
    function testFuzz_Revert_removeYieldLocker_NotOwner(address random, address locker) public {
        vm.assume(random != users.dao);

        vm.startPrank(random);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, random));
        EURB.removeYieldLocker(locker);
        vm.stopPrank();
    }

    function testFuzz_Revert_removeYieldLocker_LengthMismatch(address locker) public {
        // Given: Add an initial locker and no weights.
        vm.startPrank(users.dao);
        EURB.addYieldLocker(locker);

        // When: Calling removeYieldLocker().
        // Then: It should revert.
        vm.expectRevert(EurB.LengthMismatch.selector);
        EURB.removeYieldLocker(locker);
        vm.stopPrank();
    }

    function testFuzz_Revert_removeYieldLocker_IsNotALocker(address locker, address notLocker) public {
        // Given: notLocker is not equal to locker.
        vm.assume(notLocker != locker);

        // And: Add an initial locker.
        vm.startPrank(users.dao);
        EURB.addYieldLocker(locker);

        // And: An initial weight.
        uint256[] memory weights = new uint256[](1);
        weights[0] = BIPS;
        EURB.setWeights(weights);

        // When: Calling removeYieldLocker().
        // Then: It should revert.
        vm.expectRevert(EurB.IsNotALocker.selector);
        EURB.removeYieldLocker(notLocker);
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

        uint256 toWithdraw = ILocker(EURB.yieldLockers(index)).getTotalValue(address(EURB.underlying()));
        uint256 balancePreRemoval = EURE.balanceOf(address(EURB));

        vm.startPrank(users.dao);
        EURB.removeYieldLocker(EURB.yieldLockers(index));
        vm.stopPrank();

        uint256 balanceAfterRemoval = EURE.balanceOf(address(EURB));
        assertEq(balanceAfterRemoval, balancePreRemoval + toWithdraw);
        assertEq(EURB.getYieldLockersLength(), numberOfLockers_ - 1);
        assertEq(EURB.getWeightsLength(), numberOfLockers_ - 1);
    }
}
