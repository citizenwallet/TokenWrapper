// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {CardFactoryMock} from "./utils/mocks/CardFactoryMock.sol";
import {EurB} from "../src/token/EurB.sol";
import {Test} from "../lib/forge-std/src/Test.sol";
import {Users} from "./utils/Types.sol";

/// @notice Base test contract with common logic needed by all tests.
abstract contract Base_Test is Test {
    /*//////////////////////////////////////////////////////////////////////////
                                  CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    Users internal users;

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    constructor() {}

    function setUp() public virtual {
        // Create users for testing.
        users = Users({
            dao: createUser("dao"),
            treasury: createUser("treasury"),
            unprivilegedAddress: createUser("unprivilegedAddress"),
            tokenHolder: createUser("tokenHolder")
        });
    }

    /*//////////////////////////////////////////////////////////////////////////
                                HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Generates a user, labels its address, and funds it with test assets.
    function createUser(string memory name) internal returns (address payable) {
        address payable user = payable(makeAddr(name));
        vm.deal({account: user, newBalance: 100 ether});
        return user;
    }
}
