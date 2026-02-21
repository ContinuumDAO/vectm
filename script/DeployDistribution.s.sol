// SPDX-License-Identifier: Unlicensed

pragma solidity 0.8.27;

import {Script} from "forge-std/Script.sol";
import {Config} from "forge-std/Config.sol";
import {console} from "forge-std/console.sol";
import {Distribution} from "../src/token/Distribution.sol";

contract DeployDistribution is Script, Config {
    function run() public {
        _loadConfig("./deployments.toml", false);

        address ctm = config.get("ctm").toAddress();
        address ve = config.get("ve").toAddress();
        address dao = config.get("dao").toAddress();

        uint256 totalClaimable = config.get("totalClaimable").toUint256();

        vm.startBroadcast();
        Distribution dist = new Distribution(ctm, ve, dao, totalClaimable);
        vm.stopBroadcast();

        console.log("Distributor deployed to: ");
        console.log(address(dist));
    }
}
