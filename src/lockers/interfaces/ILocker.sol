// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface ILocker {
    function totalDeposited() external returns (uint256);
    function deposit(address asset, uint256 amount) external;
    function withdraw(address asset, uint256 amount) external returns (uint256);
    function fullWithdraw(address asset) external returns (uint256, uint256);
    function collectYield(address asset) external returns (uint256);
    function getTotalValue(address asset) external returns (uint256);
}
