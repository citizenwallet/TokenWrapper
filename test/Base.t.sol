// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {CardFactoryMock} from "./utils/mocks/CardFactoryMock.sol";
import {EURB} from "../src/token/EURB.sol";
import {Test} from "../lib/forge-std/src/Test.sol";
import {Users} from "./utils/Types.sol";

/// @notice Base test contract with common logic needed by all tests.
abstract contract Base_Test is Test {
    /*//////////////////////////////////////////////////////////////////////////
                                  CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    // Define Admin Role.
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    // Define Minter Role.
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    // Define Burner Role.
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

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
            tokenHolder: createUser("tokenHolder"),
            minter: createUser("minter"),
            burner: createUser("burner")
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
