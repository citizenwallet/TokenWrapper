// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

contract Storage {
    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    uint256 internal constant BIPS = 10_000;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // Would work with a registry here to access hookModules (others added and change in logic)
    ICardFactory public cardFactory;
    address public treasury;
}
