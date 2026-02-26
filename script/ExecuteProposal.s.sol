// SPDX-License-Identifier: Unlicensed

pragma solidity 0.8.27;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

import {IC3DAppManager} from "@c3caller/dapp/IC3DAppManager.sol";

interface IExecute {
    function execute(uint256 _proposalId) external;
}

contract ExecuteProposal is Script {
    // address constant PRANK_ACCOUNT = 0x858B2D17cfF5FF5cf0ce8d56D98555D1a5c6d8F1;
    // address constant DAO = 0x335AE207E32Ff4bd40548d6b7F170EA8d135D722;
    // uint256 constant proposalId = 109467293630292771465198985023198568396949362917298562612258960266711669858198;

    // function run() public {
    //     vm.createSelectFork(vm.rpcUrl("linea-sepolia-rpc-url"));

    //     vm.prank(PRANK_ACCOUNT);
    //     IExecute(DAO).execute(proposalId);
    // }

    address constant VE = 0x91d60d72F801Fe05A3409601E3B7664905d2b75d;

    uint256 t_minus_1 = 1772121261;
    uint256 t = 1772121262;
    uint256 t_plus_1 = 1772121263;

    function run() public {
        vm.createSelectFork(vm.rpcUrl("linea-sepolia-rpc-url"));

        uint256 ts0 = IVotes(VE).getPastTotalSupply(t_minus_1);
        // uint256 ts1 = IVotes(VE).getPastTotalSupply(t);
        uint256 ts2 = IVotes(VE).getPastTotalSupply(t_plus_1);

        console.log("t minus 1:", ts0);
        // console.log("t:", ts1);
        console.log("t plus 1:", ts2);
    }
}
