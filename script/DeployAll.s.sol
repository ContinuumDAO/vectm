// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.27;

import {Script} from "forge-std/Script.sol";
import {Config} from "forge-std/Config.sol";
import {console} from "forge-std/console.sol";

import {NodeProperties} from "../build/node/NodeProperties.sol";
import {Rewards} from "../build/node/Rewards.sol";
import {VotingEscrow} from "../build/token/VotingEscrow.sol";
import {VotingEscrowProxy} from "../build/utils/VotingEscrowProxy.sol";
import {ContinuumDAO} from "../build/governance/ContinuumDAO.sol";

contract DeployAll is Script, Config {
    function run() public {
        _loadConfig("./deployments.toml", false);

        address admin = config.get("admin").toAddress();
        address ctm = config.get("ctm").toAddress();
        address feeToken = config.get("feeToken").toAddress();

        vm.startBroadcast();

        VotingEscrow veImpl = new VotingEscrow();
        bytes memory veInitData =
            abi.encodeWithSelector(VotingEscrow.initialize.selector, address(ctm), "https://app-api.continuumdao.org/");
        VotingEscrowProxy ve = new VotingEscrowProxy(address(veImpl), veInitData);
        console.log("VotingEscrow deployed at:", address(ve));

        ContinuumDAO dao = new ContinuumDAO(address(ve), admin);
        console.log("ContinuumDAO deployed at:", address(dao));

        NodeProperties nodeProperties = new NodeProperties(admin, address(ve));
        console.log("NodeProperties deployed to:", address(nodeProperties));

        Rewards rewards = new Rewards(
            1771113600, // _firstMidnight (15th Feb 2026 00:00:00 GMT)
            address(ve), // _ve
            admin, // _gov
            address(ctm), // _rewardToken
            feeToken, // _feeToken
            address(nodeProperties), // _nodeProperties
            1 ether / 2000, // _baseEmissionRate
            1 ether / 1000, // _nodeEmissionRate
            5000 ether, // _nodeRewardThreshold
            7_812_500 gwei, // _feePerByteRewardToken
            3125 // _feePerByteFeeToken
        );
        console.log("Rewards deployed to:", address(rewards));

        nodeProperties.setRewards(address(rewards));

        VotingEscrow(address(ve)).initContracts(address(dao), address(nodeProperties), address(rewards), address(dao));

        vm.stopBroadcast();
    }
}
