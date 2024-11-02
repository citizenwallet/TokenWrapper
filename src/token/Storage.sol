// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ICardFactory} from "./interfaces/ICardFactory.sol";

contract Storage {
    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    // 1 BIPS = 0,01%
    uint256 internal constant BIPS = 10_000;
    // Max number of recursive calls for commissions.
    uint256 internal constant MAX_COMMISSIONS_DEPTH = 5;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // Would work with a registry here to access hookModules (others added and change in logic)
    ICardFactory public cardFactory;
    // The address of the treasury
    address public treasury;
}
