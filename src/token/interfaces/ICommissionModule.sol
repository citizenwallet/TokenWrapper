// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface ICommissionModule {
    function getCommissionInfo(address commissioned)
        external
        returns (address[] memory commissioners, uint256[] memory rates);
}
