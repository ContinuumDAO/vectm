// SPDX-License-Identifier: Unlicensed

pragma solidity 0.8.27;

import {Script} from "forge-std/Script.sol";
import {Config} from "forge-std/Config.sol";

interface ICTMDistribution {
    function setCTMDue(address _account, uint256 _amount) external;
}

contract Distribute is Script, Config {
    function run() public {
        _loadConfig("./deployments.toml", false);

        address dist = config.get("dist").toAddress();

        uint256 n = config.get("distribution_count").toUint256();

        vm.startBroadcast();
        for (uint256 i = 0; i < n; i++) {
            string memory keyAddr = string.concat("distribution_", vm.toString(i), "_address");
            string memory keyAmt = string.concat("distribution_", vm.toString(i), "_amount");
            address a = config.get(keyAddr).toAddress();
            uint256 amt = config.get(keyAmt).toUint256();
            ICTMDistribution(dist).setCTMDue(a, amt);
        }
        vm.stopBroadcast();
    }
}
