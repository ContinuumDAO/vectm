// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import "forge-std/console.sol";
import {IVotingEscrow} from "../ignoreSrc/src/IVotingEscrow.sol";

contract Merge is Script {
    // // address governorAddr = 0x1271D5C10663a0e34aFD1Ae5362EB9E29b1E3d97;
    // IGovernor governor = IGovernor(governorAddr);

    address veAddr = 0xAF0D3b20ac92e6825014549bB3FA937b3BF5731A;


    function run() external {
        IVotingEscrow ve = IVotingEscrow(veAddr);

        uint256 senderPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(senderPrivateKey);

        ve.merge(1, 3);

        vm.stopBroadcast();
    }
}