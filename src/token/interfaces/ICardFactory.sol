// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface ICardFactory {
    function COMMISSION_HOOK_MODULE() external returns (address);
}
