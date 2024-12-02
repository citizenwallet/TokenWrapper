// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {AaveLocker_Fork_Test} from "./_AaveLocker.fork.t.sol";
import {IPool} from "../../utils/interfaces/aave/IPool.sol";

/**
 * @notice Fork tests for the function "deposit" of contract "AaveLocker".
 */
contract Deposit_AaveLocker_Fork_Test is AaveLocker_Fork_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AaveLocker_Fork_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFork_Success_deposit(uint256 amount) public {
        // Given: Give EURE balance to owner
        amount = bound(amount, 1e18, 10_000 * 1e18);
        vm.prank(EUREFund);
        EURE.transfer(address(EURB), amount);

        vm.startPrank(address(EURB));
        // And: Owner approves Locker contract.
        EURE.approve(address(AAVE_LOCKER), amount);
        // When: Owner deposits inside EURE contract.
        AAVE_LOCKER.deposit(address(EURE), amount);
        vm.stopPrank();

        // Then: It should return correct values.
        assertEq(AAVE_LOCKER.totalDeposited(), amount);
        assert(AAVE_LOCKER.ATOKEN().balanceOf(address(AAVE_LOCKER)) > 0);
    }
}
