// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {AaveV3Locker} from "../src/lockers/AaveLocker.sol";
import {Addresses} from "./AddressesLib.sol";
import {CommissionModule} from "../src/modules/CommissionModule.sol";
import {console2} from "../lib/forge-std/src/console2.sol";
import {EURB} from "../src/token/EURB.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {Proxy} from "../src/treasury/Proxy.sol";
import {Script} from "../lib/forge-std/src/Script.sol";
import {TreasuryV1} from "../src/treasury/TreasuryV1.sol";

contract EuroBrusselsDeployScript is Script {
    // Define variables for the addresses and contract instances
    address public owner;

    address public EURE = Addresses.EURE;
    address public aEURE = Addresses.aEURE;
    address public aaveBasePool = Addresses.aaveBasePool;
    address public cardFactory = Addresses.cardFactory;

    uint256 public BIPS = 10_000;

    // Euro Brussels contract instances
    TreasuryV1 public treasury;
    AaveV3Locker public aaveLocker;
    CommissionModule public commissionModule;
    EURB public eurB;

    function run() public {
        // Set the owner and treasury addresses
        owner = vm.envAddress("OWNER_ADDRESS");

        // Prepare the deployment
        console2.log("Preparing unsigned transactions...");

        // Start broadcasting
        vm.startBroadcast(owner);

        // Deploy the Treasury contract.
        TreasuryV1 logic = new TreasuryV1();
        Proxy proxy = new Proxy(address(logic));
        treasury = TreasuryV1(address(proxy));
        treasury.initialize(EURE);

        // Deploy Commission Module
        commissionModule = new CommissionModule();
        // Note: the commission hook module should be added to the CardFactory contact.

        // Deploy EURB
        eurB = new EURB(cardFactory);

        // Deploy Aave Locker and add it to Treasury contract.
        aaveLocker = new AaveV3Locker(address(proxy), aEURE, aaveBasePool);
        treasury.addYieldLocker(address(aaveLocker));

        // Set locker weights
        uint256[] memory weights = new uint256[](1);
        weights[0] = 10_000;
        treasury.setWeights(weights);

        // Log deployed addresses
        console2.log("EURB:", address(eurB));
        console2.log("Treasury:", address(treasury));
        console2.log("AaveLocker:", address(aaveLocker));
        console2.log("CommissionModule", address(commissionModule));

        vm.stopBroadcast();
    }
}
