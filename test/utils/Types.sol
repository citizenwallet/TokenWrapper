// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

struct Users {
    address payable dao;
    address payable treasury;
    address payable unprivilegedAddress;
    address payable tokenHolder;
    address payable minter;
    address payable burner;
}
