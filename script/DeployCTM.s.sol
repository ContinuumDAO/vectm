// SPDX-License-Identifier: Unlicensed

pragma solidity 0.8.27;

import {Script} from "forge-std/Script.sol";
import {Config} from "forge-std/Config.sol";
import {console} from "forge-std/console.sol";

import {IC3DAppManager} from "@c3caller/dapp/IC3DAppManager.sol";

import {CTMMintable} from "../build/token/ctm/CTMMintable.sol";
import {CTM} from "../build/token/ctm/CTM.sol";

contract DeployCTM is Script, Config {
    function run() public {
        _loadConfig("./config/deployments.toml", false);

        bool mintable = vm.envOr("MINTABLE", false);

        address admin = config.get("admin").toAddress();
        address c3caller = config.get("c3caller").toAddress();
        address dappManager = config.get("dappManager").toAddress();
        // string memory dappKey_ctm = config.get("dappKey_ctm").toString();
        uint256 dappID_ctm = config.get("dappId_ctm").toUint256();

        // uint256 dappID_ctm = IC3DAppManager(dappManager).deriveDAppID(admin, dappKey_ctm);

        address _ctm;

        vm.startBroadcast();

        if (mintable) {
            CTMMintable ctmMintable = new CTMMintable(admin, c3caller, dappManager, dappID_ctm);
            _ctm = address(ctmMintable);
            console.log("CTMMintable deployed to: ", _ctm);
        } else {
            CTM ctm = new CTM(admin, c3caller, dappManager, dappID_ctm);
            _ctm = address(ctm);
            console.log("CTM deployed to: ", _ctm);
        }

        vm.stopBroadcast();
    }
}
