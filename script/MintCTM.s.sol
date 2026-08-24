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

        string memory targetChainID = config.get("targetChainID").toString();
        string memory dao = config.get("dao").toString();
        string memory ve = config.get("ve").toString();

        uint256 veLock = config.get("veLock").toUint256();
        uint256 daoFloat = config.get("daoFloat").toUint256();

        vm.startBroadcast();
        ICTMMintable(ctm).mint(admin, veLock + daoFloat);
        ICTM(ctm).c3transfer(ve, veLock, targetChainID);
        ICTM(ctm).c3transfer(dao, daoFloat, targetChainID);
        vm.stopBroadcast();
    }
}
