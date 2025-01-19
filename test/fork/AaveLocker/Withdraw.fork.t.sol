// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {AaveLocker_Fork_Test} from "./_AaveLocker.fork.t.sol";
import {IPool} from "../../utils/interfaces/aave/IPool.sol";

/**
 * @notice Fork tests for the function "withdraw" of contract "AaveLocker".
 */
contract Withdraw_AaveLocker_Fork_Test is AaveLocker_Fork_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AaveLocker_Fork_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFork_Success_withdraw(uint256 depositAmount, uint256 withdrawAmount) public {
        // Given: Deposit a certain amount.
        depositAmount = bound(depositAmount, 1e18, 10_000 * 1e18);
        vm.prank(EUREFund);
        EURE.transfer(address(TREASURY), depositAmount);

        vm.startPrank(address(TREASURY));
        EURE.approve(address(AAVE_LOCKER), depositAmount);
        AAVE_LOCKER.deposit(address(EURE), depositAmount);

        // And: Withdraw amount is max equal to deposit amount.
        withdrawAmount = bound(withdrawAmount, 1e18, depositAmount);
        // When: Withdrawing.
        AAVE_LOCKER.withdraw(address(EURE), withdrawAmount);

        // Then: Values should be updated.
        assertEq(AAVE_LOCKER.totalDeposited(), depositAmount - withdrawAmount);
        assertEq(EURE.balanceOf(address(TREASURY)), withdrawAmount);

        if (withdrawAmount != depositAmount) {
            assert(AAVE_LOCKER.ATOKEN().balanceOf(address(AAVE_LOCKER)) > 0);
        }

        vm.stopPrank();
    }
}
