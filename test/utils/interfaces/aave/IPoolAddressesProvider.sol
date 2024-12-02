// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface IPoolAddressesProvider {
    function getPool() external returns (address);
}
