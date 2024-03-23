// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import "forge-std/console.sol";
import {IVotingEscrow} from "../build/VotingEscrow.sol";

contract Read is Script {
    address veAddr = 0xAF0D3b20ac92e6825014549bB3FA937b3BF5731A;
    IVotingEscrow ve = IVotingEscrow(veAddr);

    function run() external {
        // address account = vm.addr(vm.envUint("PRIVATE_KEY"));
        uint256 votingPower = ve.getPastTotalSupply(block.timestamp - 1);
        console.log(votingPower);
    }
}