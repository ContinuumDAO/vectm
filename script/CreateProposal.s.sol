// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import { Script } from "forge-std/Script.sol";
import "forge-std/console.sol";
import { IGovernor } from "build/CTMDAOGovernor.sol";

contract CreateProposal is Script {
    address governorAddr = 0x1271D5C10663a0e34aFD1Ae5362EB9E29b1E3d97;
    IGovernor governor = IGovernor(governorAddr);

    function run() external {
        uint256 proposerPrivateKey = vm.envUint("PRIVATE_KEY");
        address proposer = vm.addr(proposerPrivateKey);

        vm.startBroadcast(proposerPrivateKey);

        uint256 txCount = 3; // this is the number of transactions that will be carried out by the proposal

        address[] memory targets = new address[](txCount);
        uint256[] memory values = new uint256[](txCount);
        bytes[] memory calldatas = new bytes[](txCount);

        // Transction X
        // targets[X] = ... (add a target address to be called here)
        // values[X] = ... (add a value of ETH to be transferred with the transaction here)
        // calldatas[X] = ... (add the data with which to call the target address, such as a function call, here)

        // Transaction 0
        address ctmAddr = 0xADeE65208A9fd9d6d47AD2D8A53D7E019955d1Db;
        targets[0] = ctmAddr;
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("transfer(address,uint256)", proposer, 1 ether);

        // Transction 1
        targets[1] = proposer;
        values[1] = 1 ether;
        calldatas[1] = bytes("");

        // Transaction 2
        targets[2] = ctmAddr;
        values[2] = 0;
        calldatas[2] = abi.encodeWithSignature("approve(address,uint256)", proposer, 10 ether);

        string memory description = 
            "Proposal #1:Transfer 1 CTM from treasury to proposer, send 1 ETH to proposer, approve proposer to spend 10 CTM from the treasury";

        console.log("Creating proposal with ", txCount, " transaction(s)...");

        console.log("Proposal Data:");
        for (uint256 i = 0; i < txCount; i++) {
            console.log("Transaction ", i + 1);
            console.log(targets[i]);
            console.log(values[i]);
            console.logBytes(calldatas[i]);
            console.log("\n");
        }

        governor.propose(targets, values, calldatas, description);

        vm.stopBroadcast();
    }
}