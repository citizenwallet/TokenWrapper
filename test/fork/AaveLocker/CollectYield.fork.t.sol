// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {AaveLocker_Fork_Test} from "./_AaveLocker.fork.t.sol";
import {IPool} from "../../utils/interfaces/aave/IPool.sol";

/**
 * @notice Fork tests for the function "collectYield" of contract "AaveLocker".
 */
contract CollectYield_AaveLocker_Fork_Test is AaveLocker_Fork_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AaveLocker_Fork_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFork_Success_collectYield(uint256 depositAmount) public {
        // Given: Deposit a certain amount.
        depositAmount = bound(depositAmount, 1e18, 10_000 * 1e18);
        vm.prank(EUREFund);
        EURE.transfer(address(TREASURY), depositAmount);

        vm.startPrank(address(TREASURY));
        EURE.approve(address(AAVE_LOCKER), depositAmount);
        AAVE_LOCKER.deposit(address(EURE), depositAmount);

        vm.warp(block.timestamp + 365 days);
        uint256 initTotalValue = AAVE_LOCKER.getTotalValue(address(EURE));

        // When: Calling collectYield.
        uint256 yield = AAVE_LOCKER.collectYield(address(EURE));
        uint256 expectedYield = initTotalValue - depositAmount;
        assertEq(expectedYield, yield);
        assertEq(EURE.balanceOf(address(TREASURY)), yield);

        vm.stopPrank();
    }
}
