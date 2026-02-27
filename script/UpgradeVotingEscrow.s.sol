// SPDX-License-Identifier: Unlicensed

pragma solidity 0.8.27;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {VotingEscrow} from "../build/token/VotingEscrow.sol";

// interface IUpgrade {
//     function upgradeToAndCall(address newImplementation, bytes memory data) external;
// }

contract UpgradeVotingEscrow is Script {
    address constant VE = 0x91d60d72F801Fe05A3409601E3B7664905d2b75d;
    // address constant GOV = 0x335AE207E32Ff4bd40548d6b7F170EA8d135D722;

    function run() public {
        vm.startBroadcast();
        // vm.createSelectFork(vm.rpcUrl("linea-sepolia-rpc-url"));
        VotingEscrow ve_2 = new VotingEscrow();
        // vm.prank(GOV);
        // IUpgrade(VE).upgradeToAndCall(address(ve_2), "");
        vm.stopBroadcast();
        console.log("VotingEscrow V2: ", address(ve_2));
    }
}
