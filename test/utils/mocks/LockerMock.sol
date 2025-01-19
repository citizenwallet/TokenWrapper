// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {AbstractLocker} from "../../../src/lockers/AbstractLocker.sol";
import {IERC20} from "../../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";

contract LockerMock is AbstractLocker {
    constructor(address owner_) AbstractLocker(owner_) {}

    function getTotalValue(address asset) public view override returns (uint256 value) {
        value = IERC20(asset).balanceOf(address(this));
    }

    function deposit(address asset, uint256 amount) external override onlyOwner {
        // Increase amount deposited.
        totalDeposited += amount;

        // Deposit asset in pool.
        IERC20(asset).transferFrom(msg.sender, address(this), amount);
    }

    function withdraw(address asset, uint256 amount) external override onlyOwner returns (uint256 withdrawn) {
        // Decrease amount deposited.
        totalDeposited -= amount;

        withdrawn = amount;

        // Withdraw asset from pool to the owner.
        IERC20(asset).transfer(msg.sender, amount);
    }

    function collectYield(address asset) external override onlyOwner returns (uint256 yield) {
        // Calculate current value of position in underlying token.
        uint256 withdrawableBalance = getTotalValue(asset);

        // The yield is the difference between current claimable balance and total deposited.
        // Cache value
        uint256 totalDeposited_ = totalDeposited;
        yield = withdrawableBalance > totalDeposited_ ? withdrawableBalance - totalDeposited_ : 0;

        // Withdraw asset from pool to the owner.
        // Withdraw asset from pool to the owner.
        IERC20(asset).transfer(msg.sender, yield);
    }

    function fullWithdraw(address asset) external override onlyOwner returns (uint256 principal, uint256 yield) {
        // Calculate current value of position in underlying token.
        uint256 withdrawableBalance = getTotalValue(asset);

        // The yield is the difference between current claimable balance and total deposited.
        // Cache value
        uint256 totalDeposited_ = totalDeposited;
        yield = withdrawableBalance > totalDeposited_ ? withdrawableBalance - totalDeposited_ : 0;

        totalDeposited = 0;
        principal = withdrawableBalance - yield;
        IERC20(asset).transfer(msg.sender, withdrawableBalance);
    }

    /* ///////////////////////////////////////////////////////////////
                            EXTENSION FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    function increaseDeposits(uint256 amount) public {
        totalDeposited += amount;
    }
}
