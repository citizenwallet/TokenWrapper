// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface ILocker {
    function totalSupply() external returns (uint256);
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function fullWithdraw() external;
    function collectFees() external returns (uint256 fees);
    function compoundFees() external;
    function getTotalValue() external returns (uint256 value);
}
