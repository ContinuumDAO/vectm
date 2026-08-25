// SPDX-License-Identifier: Unlicensed

pragma solidity 0.8.27;

import {Script} from "forge-std/Script.sol";
import {Config} from "forge-std/Config.sol";
import {console} from "forge-std/console.sol";

import {INodeProperties} from "../build/node/NodeProperties.sol";
import {IRewards} from "../build/node/Rewards.sol";

interface IMSAW {
    function setVeCtmContracts(address _nodeProperties, address _rewards) external;
    function setCtm(address _ctm) external;
}

contract InitializeDAO is Script, Config {
    function run() public {
        _loadConfig("./config/deployments.toml", false);

        address nodeProperties = config.get("nodeProperties").toAddress();
        address rewards = config.get("rewards").toAddress();
        address admin = config.get("admin").toAddress();
        address ve = config.get("ve").toAddress();
        address msaw = config.get("msaw").toAddress();
        address ctm = config.get("ctm").toAddress();

        vm.startBroadcast();
        INodeProperties(nodeProperties).setProtocolContracts(admin, ve, rewards, msaw);
        IRewards(rewards).setProtocolContracts(admin, ve, nodeProperties);
        IMSAW(msaw).setVeCtmContracts(nodeProperties, rewards);
        IMSAW(msaw).setCtm(ctm);
        vm.stopBroadcast();
    }
}
