// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.27;

import {Script} from "forge-std/Script.sol";
import {Config} from "forge-std/Config.sol";
import {console} from "forge-std/console.sol";

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {CTM} from "../src/token/ctm/CTM.sol";

contract DeployCTM is Script, Config {
    using Strings for address;

    function run() public {
        _loadConfig("./deployments.toml", false);

        address c3caller = config.get("c3caller").toAddress();
        address dappManager = config.get("dappManager").toAddress();
        uint256 ctmDAppID = config.get("ctmDAppID").toUint256();

        vm.startBroadcast();

        console.log("Deploying CTM Token...");

        CTM ctm = new CTM(c3caller, ctmDAppID, dappManager);

        console.log("CTM Token deployed at:", address(ctm));

        console.log("Settings peers for mainnet...");
        ctm.setPeer("1", address(ctm).toHexString());

        console.log("Setting peers for arbitrum...");
        ctm.setPeer("42161", address(ctm).toHexString());

        vm.stopBroadcast();
    }
}
