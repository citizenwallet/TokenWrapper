// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ILocker} from "./interfaces/ILocker.sol";
import {Ownable} from "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

abstract contract AbstractLocker is ILocker, Ownable {
    // Note : add skim function
    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    uint256 public totalDeposited;

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    event Deposited(uint256 amount);
    event FeesCollected(uint256 amount);
    event Withdrawed(uint256 amount);

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    /* //////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    constructor(address owner_) Ownable(owner_) {}

    /* //////////////////////////////////////////////////////////////
                        ASSET MANAGEMENT
    ////////////////////////////////////////////////////////////// */

    function getTotalValue(address asset) public view virtual returns (uint256 value) {}

    /* //////////////////////////////////////////////////////////////
                         DEPOSIT / WITHDRAW
    ////////////////////////////////////////////////////////////// */

    function deposit(address asset, uint256 amount) external virtual onlyOwner {}

    function withdraw(address asset, uint256 amount) external virtual onlyOwner {}

    function fullWithdraw(address asset) external virtual onlyOwner returns (uint256 principal, uint256 yield) {}

    // Note: add a function that enables to withdraw all extra rewards that could have been accumulated.

    /* //////////////////////////////////////////////////////////////
                         FEES MANAGEMENT
    ////////////////////////////////////////////////////////////// */

    function collectYield(address asset) external virtual onlyOwner returns (uint256 yield) {}
}
