// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface ISafe {
    function isModuleEnabled(address module) external view returns (bool);
}
