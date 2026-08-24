// SPDX-License-Identifier: Unlicensed

pragma solidity 0.8.27;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {VotingEscrow} from "../build/token/VotingEscrow.sol";

interface IUpgrade {
    function upgradeToAndCall(address newImplementation, bytes memory data) external;
}

contract UpgradeVotingEscrow is Script {
    address constant VE = 0x221EC90B3B083A8501A37bdeb7035CeaedF3C31f;
    address constant GOV = 0x4800F9f1dC1b6daCA841B71E0531F547D374168E;

    function run() public {
        vm.startBroadcast();
        // vm.createSelectFork(vm.rpcUrl("linea-rpc-url"));
        VotingEscrow ve_2 = new VotingEscrow();
        IUpgrade(VE).upgradeToAndCall(address(ve_2), "");
        vm.stopBroadcast();
        console.log("VotingEscrow V2: ", address(ve_2));
    }
}
