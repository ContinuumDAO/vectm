// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
import {IGovernor} from "build/CTMDAOGovernor.sol";
import {NodeProperties} from "build/NodeProperties.sol";

contract RedeployNodeProperties is Script {
    function run() external {
        uint256 senderPrivateKey = vm.envUint("PRIVATE_KEY");
        address sender = vm.addr(senderPrivateKey);

        address gov = 0x0c108b60BadD59EfdE68Dc4A0ADCE892b21B6050;
        address ve = 0x480E2Dd806129dc8d9ec8076Fdd47E99F956fcE6;
        address rewards = 0x4D616236Ad1a94437F864AcA3c5B2027E4648905;
        address currentNodeProperties = 0xd7257a9D8c44940AF7bD0Fcbd9874643d53A7719;

        IGovernor ctmDaoGovernor = IGovernor(gov);

        vm.startBroadcast(senderPrivateKey);

        // 1. Redploy new NodeProperties contract
        // 2. Set Rewards in NodeProperties
        // 3a. Update address in veCTM (governance vote)
        // 3b. Update address in Rewards (governance vote)

        // 1
        NodeProperties newNodeProperties = new NodeProperties(gov, ve);

        // 2
        newNodeProperties.setRewards(address(rewards));

        // 3
        address[] memory targets = new address[](2);
        uint256[] memory values = new uint256[](2);
        bytes[] memory calldatas = new bytes[](2);
        targets[0] = ve;
        targets[1] = rewards;
        values[0] = 0;
        values[1] = 0;
        calldatas[0] = abi.encodeWithSignature(
            "setup(address,address,address,address)",
            gov,
            address(newNodeProperties),
            rewards,
            sender
        );
        calldatas[1] = abi.encodeWithSignature(
            "setNodeProperties(address)",
            address(newNodeProperties)
        );

        string memory description = "Proposal #1: Redeploy NodeProperties contract and update in ve and rewards.";

        ctmDaoGovernor.propose(targets, values, calldatas, description);

        vm.stopBroadcast();

        console.log("Sender: ", sender);
        console.log("Current Node Properties: ", address(currentNodeProperties));
        console.log("New Node Properties: ", address(newNodeProperties));
    }
}