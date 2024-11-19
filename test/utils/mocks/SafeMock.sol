// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

contract SafeMock {
    mapping(address module => bool enabled) public moduleEnabled;

    function setModule(address module) external {
        moduleEnabled[module] = true;
    }

    function removeModule(address module) external {
        moduleEnabled[module] = false;
    }

    function isModuleEnabled(address module) external view returns (bool enabled) {
        enabled = moduleEnabled[module];
    }
}
