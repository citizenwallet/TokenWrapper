// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {AaveLocker_Fork_Test} from "./_AaveLocker.fork.t.sol";
import {IPool} from "../../utils/interfaces/aave/IPool.sol";

/**
 * @notice Fork tests for the function "getTotalValue" of contract "AaveLocker".
 */
contract GetTotalValue_AaveLocker_Fork_Test is AaveLocker_Fork_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AaveLocker_Fork_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFork_Success_getTotalValue(uint256 depositAmount) public {
        // Given: Deposit a certain amount.
        depositAmount = bound(depositAmount, 1e18, 10_000 * 1e18);
        vm.prank(EUREFund);
        EURE.transfer(address(TREASURY), depositAmount);

        vm.startPrank(address(TREASURY));
        EURE.approve(address(AAVE_LOCKER), depositAmount);
        AAVE_LOCKER.deposit(address(EURE), depositAmount);

        vm.warp(block.timestamp + 365 days);
        AAVE_LOCKER.withdraw(address(EURE), 1);
        vm.stopPrank();

        // When: Calling getTotalValue.
        uint256 totalValue = AAVE_LOCKER.getTotalValue(address(EURE));

        // Then: It should have accrued interest.
        assert(totalValue > depositAmount);
        // Should not exceed 10 % in a year (usually).
        assert(totalValue < (depositAmount * 11_000) / 10_000);
    }
}
