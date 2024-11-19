// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

contract CardFactoryMock {
    address public COMMISSION_HOOK_MODULE;

    constructor(address commissionHookModule) {
        COMMISSION_HOOK_MODULE = commissionHookModule;
    }

    function setCommissionHookModule(address commissionHookModule) public {
        COMMISSION_HOOK_MODULE = commissionHookModule;
    }
}
