// SPDX-License-Identifier: Unlicensed

pragma solidity 0.8.27;

import {Script} from "forge-std/Script.sol";
import {Config} from "forge-std/Config.sol";

import {IC3GovernDApp} from "@c3caller/gov/IC3GovernDApp.sol";

import {ICTMMintable, ICTM} from "../build/token/ctm/CTMMintable.sol";

contract MintCTM is Script, Config {
    function run() public {
        _loadConfig("./config/mint.toml", false);

        address ctm = config.get("ctm").toAddress();
        address admin = config.get("admin").toAddress();
        string memory distribution = config.get("dist").toString();
        string memory targetChainID = config.get("targetChainID").toString();
        uint256 initialMint = config.get("initialMint").toUint256();

        vm.startBroadcast();
        ICTMMintable(ctm).mint(admin, initialMint);
        ICTM(ctm).c3transfer(distribution, initialMint, targetChainID);
        vm.stopBroadcast();
    }
}
