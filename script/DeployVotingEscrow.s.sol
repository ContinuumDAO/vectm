// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

import { CTM } from "../build/token/CTM.sol";
import { VotingEscrow, IVotingEscrow } from "../build/token/VotingEscrow.sol";
import { VotingEscrowProxy } from "../build/utils/VotingEscrowProxy.sol";
import { CTMDAOGovernor } from "../build/gov/CTMDAOGovernor.sol";
import { NodeProperties, INodeProperties } from "../build/node/NodeProperties.sol";
import { Rewards } from "../build/node/Rewards.sol";

contract DeployVotingEscrow is Script {
    address feeToken;
    address swapRouter;
    address weth;
    address treasury;

    string feeTokenKey = string.concat("FEE_TOKEN_", vm.toString(block.chainid));
    string swapRouterKey = string.concat("SWAP_ROUTER_", vm.toString(block.chainid));
    string wethKey = string.concat("WETH_", vm.toString(block.chainid));
    string treasuryKey = string.concat("TREASURY_", vm.toString(block.chainid));

    function run() public {
        try vm.envAddress(feeTokenKey) returns (address _feeToken) {
            feeToken = _feeToken;
        } catch {
            revert(string.concat(feeTokenKey, " not defined"));
        }

        try vm.envAddress(swapRouterKey) returns (address _swapRouter) {
            swapRouter = _swapRouter;
        } catch {
            revert(string.concat(swapRouterKey, " not defined"));
        }

        try vm.envAddress(wethKey) returns (address _weth) {
            weth = _weth;
        } catch {
            revert(string.concat(wethKey, " not defined"));
        }

        try vm.envAddress(treasuryKey) returns (address _treasury) {
            treasury = _treasury;
        } catch {
            revert(string.concat(treasuryKey, " not defined"));
        }

        vm.startBroadcast();

        console.log("Deploying CTM Token...");

        CTM ctm = new CTM(treasury);
        console.log("CTM Token deployed at:", address(ctm));

        VotingEscrow votingEscrowImpl = new VotingEscrow();
        bytes memory votingEscrowInitData = abi.encodeWithSelector(VotingEscrow.initialize.selector, address(ctm), "https://api.continuumdao.org/voting-escrow/");
        address votingEscrow = address(new VotingEscrowProxy(address(votingEscrowImpl), votingEscrowInitData));

        console.log("VotingEscrow deployed at:", address(votingEscrow));

        CTMDAOGovernor ctmDAOGovernor = new CTMDAOGovernor(address(votingEscrow));
        console.log("CTMDAOGovernor deployed at:", address(ctmDAOGovernor));

        NodeProperties nodeProperties = new NodeProperties(address(ctmDAOGovernor), address(votingEscrow));
        console.log("NodeProperties deployed at:", address(nodeProperties));

        Rewards rewards = new Rewards(
            1755043200,                 // _firstMidnight,
            address(votingEscrow),      // _ve
            address(ctmDAOGovernor),    // _gov
            address(ctm),               // _rewardToken
            feeToken,                   // _feeToken
            swapRouter,                 // _swapRouter
            address(nodeProperties),    // _nodeProperties
            weth,                       // _weth
            1 ether / 2000,             // _baseEmissionRate
            1 ether / 1000,             // _nodeEmissionRate
            5000 ether,                 // _nodeRewardThreshold
            7_812_500 gwei,             // _feePerByteRewardToken
            3125                        // _feePerByteFeeToken
        );
        console.log("Rewards deployed at:", address(rewards));


        INodeProperties(nodeProperties).initContracts(address(rewards));
        IVotingEscrow(votingEscrow).initContracts(address(ctmDAOGovernor), address(nodeProperties), address(rewards), treasury);

        vm.stopBroadcast();
    }
}
