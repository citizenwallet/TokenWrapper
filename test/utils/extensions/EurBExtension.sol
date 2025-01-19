// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {EURB} from "../../../src/token/EURB.sol";
import {IERC20} from "../../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";

contract EurBExtension is EURB {
    constructor(address cardFactory_) EURB(cardFactory_) {}

    function processCommissions(address commissionModule, address commissioned, uint256 amount, uint256 depth) public {
        _processCommissions(commissionModule, commissioned, amount, depth);
    }

    function getCardFactory() external view returns (address _cardFactory) {
        _cardFactory = address(cardFactory);
    }
}
