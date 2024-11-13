// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface IAaveToken {
    function balanceOf(address account) external view returns (uint256 balance);
    function scaledBalanceOf(address account) external view returns (uint256 balance);
}
