// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Treasury_Fuzz_Test} from "./_Treasury.fuzz.t.sol";

import {FixedPointMathLib} from "../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import {IERC20} from "../../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {ILocker} from "../../../src/lockers/interfaces/ILocker.sol";
import {TreasuryV1} from "../../../src/treasury/TreasuryV1.sol";

/**
 * @notice Fuzz tests for the function "claimYield" of contract "Treasury".
 */
contract ClaimYield_Treasury_Fuzz_Test is Treasury_Fuzz_Test {
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
    function testFuzz_Revert_claimYield_NotOwner(address random, uint256 amount, address receiver) public {
        vm.assume(random != users.dao);

        vm.startPrank(random);
        bytes memory expectedError = abi.encodeWithSelector(TreasuryV1.OnlyOwner.selector);
        vm.expectRevert(expectedError);
        treasury.claimYield(amount, receiver);
        vm.stopPrank();
    }

    function testFuzz_Revert_claimYield_YieldTooLow(uint256 totalYield, uint256 amountToClaim, address receiver)
        public
    {
        // Given: availableYield is lower than yield to claim.
        vm.assume(amountToClaim > 1);
        totalYield = bound(totalYield, 0, amountToClaim - 1);

        // And: availableYield is set.
        treasury.setAvailableYield(totalYield);

        // When: Claiming yield it should revert.
        vm.startPrank(users.dao);
        vm.expectRevert(TreasuryV1.YieldTooLow.selector);
        treasury.claimYield(amountToClaim, receiver);
        vm.stopPrank();
    }

    function testFuzz_Success_claimYield(uint256 totalYield, uint256 amountToClaim, address receiver) public {
        // Given: availableYield is lower than yield to claim.
        // And: Amount to claim should not be equal to max type(uint256).max.
        vm.assume(amountToClaim > 0);
        vm.assume(amountToClaim < type(uint256).max - 2);
        totalYield = bound(totalYield, amountToClaim + 1, type(uint256).max - 1);

        // And: availableYield is set.
        treasury.setAvailableYield(totalYield);

        // And: Yield is available in the Treasury
        EURE.mint(address(treasury), totalYield);

        // When: Claiming yield
        vm.prank(users.dao);
        treasury.claimYield(amountToClaim, receiver);

        // Then: Yield should have been sent to receiver
        // And: Available yield should have been lowered.
        assertEq(EURE.balanceOf(receiver), amountToClaim);
        assertEq(EURE.balanceOf(address(treasury)), totalYield - amountToClaim);
        assertEq(treasury.availableYield(), totalYield - amountToClaim);
        assert(treasury.availableYield() > 0);
    }
}
