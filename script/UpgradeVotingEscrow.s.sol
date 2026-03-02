// SPDX-License-Identifier: Unlicensed

pragma solidity 0.8.27;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {VotingEscrow} from "../build/token/VotingEscrow.sol";

interface IUpgrade {
    function upgradeToAndCall(address newImplementation, bytes memory data) external;
}

contract UpgradeVotingEscrow is Script {
    address constant VE = 0xFA4DE6AF7EbaF304a20078115e75032Bc530B7dd;
    address constant GOV = 0x2be79060a0103F3c862f728e8ddc8bb198872D35;

    function run() public {
        // vm.startBroadcast();
        vm.createSelectFork(vm.rpcUrl("linea-rpc-url"));
        VotingEscrow ve_2 = new VotingEscrow();
        vm.prank(GOV);
        IUpgrade(VE).upgradeToAndCall(address(ve_2), "");
        // vm.stopBroadcast();
        console.log("VotingEscrow V2: ", address(ve_2));
    }
}
