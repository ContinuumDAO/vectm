// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.27;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {VotingEscrow} from "../src/token/VotingEscrow.sol";

contract DeployVotingEscrowImplementation is Script {
    function run() public {
        vm.startBroadcast();

        VotingEscrow veImpl = new VotingEscrow();

        vm.stopBroadcast();

        console.log("VotingEscrow Implementation:", address(veImpl));
    }
}
