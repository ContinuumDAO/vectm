// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import "forge-std/console.sol";
import {IGovernor} from "../build/CTMDAOGovernor.sol";

contract SetGov is Script {
    address ve = 0xAF0D3b20ac92e6825014549bB3FA937b3BF5731A;
    address newGovernor = 0x44ac22015f33bD6e47cee1b6d9aae4604edC2EC6;
    IGovernor governor = IGovernor(0x1271D5C10663a0e34aFD1Ae5362EB9E29b1E3d97);

    function run() external {
        uint256 senderPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(senderPrivateKey);

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        string memory description = "Proposal #7: Change the governor contract in veCTM (retry)";

        targets[0] = ve;
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature(
            "setGovernor(address)",
            newGovernor
        );

        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        console.log(proposalId);

        vm.stopBroadcast();
    }
}