// SPDX-License-Identifier: Unlicensed

pragma solidity 0.8.27;

import {Script} from "forge-std/Script.sol";
import {Config} from "forge-std/Config.sol";
import {console} from "forge-std/console.sol";

import {IC3Caller} from "@c3caller/IC3Caller.sol";

contract MPCSigners is Script, Config {
    function run() public {
        _loadConfig("./config/deployments.toml", false);

        address c3caller = config.get("c3caller").toAddress();

        address[] memory signers = IC3Caller(c3caller).getAllMPCAddrs();

        for (uint256 i = 0; i < signers.length; i++) {
            console.log(string.concat("Signer ", vm.toString(i), ":"));
            console.log(signers[i]);
        }
    }
}
