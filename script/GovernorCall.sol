// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import "forge-std/console.sol";
import {IGovernor} from "build/CTMDAOGovernor.sol";

contract GovernorCall is Script {
    address governorAddr = 0x1271D5C10663a0e34aFD1Ae5362EB9E29b1E3d97;
    IGovernor governor = IGovernor(governorAddr);

    address rewards = 0x84762a8296c968b395ba92e34a3E0243DcDed2B8;

    function run() external {

        uint256 senderPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(senderPrivateKey);

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        targets[0] = rewards;
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature(
            "setNodeProperties(address)",
            0x90577Cf026931edF7180fB78E0dc569079bd4015
        );
        string memory description = "Proposal #6: Update address of node properties in rewards contract (retry).";

        // console.logBytes(calldatas[0]);
        // console.log(description);

        governor.propose(targets, values, calldatas, description);

        vm.stopBroadcast();
    }
}