// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {CTM} from "../src/token/CTM.sol";
import {VotingEscrow, IVotingEscrow} from "../src/token/VotingEscrow.sol";
import {VotingEscrowProxy} from "../src/utils/VotingEscrowProxy.sol";
import {ContinuumDAO} from "../src/governance/ContinuumDAO.sol";
import {NodeProperties} from "../src/node/NodeProperties.sol";
import {INodeProperties} from "../src/node/INodeProperties.sol";
import {Rewards} from "../src/node/Rewards.sol";

contract DeployVotingEscrow is Script {
    address deployer;
    address feeToken;
    address treasury;

    string feeTokenKey = string.concat("FEE_TOKEN_", vm.toString(block.chainid));
    string treasuryKey = string.concat("TREASURY_", vm.toString(block.chainid));

    function run() public {
        try vm.envAddress("DEPLOYER") returns (address _deployer) {
            deployer = _deployer;
        } catch {
            revert("DEPLOYER not defined");
        }

        try vm.envAddress(feeTokenKey) returns (address _feeToken) {
            feeToken = _feeToken;
        } catch {
            revert(string.concat(feeTokenKey, " not defined"));
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
        bytes memory votingEscrowInitData = abi.encodeWithSelector(
            VotingEscrow.initialize.selector, address(ctm), "https://api.continuumdao.org/voting-escrow/"
        );
        address votingEscrow = address(new VotingEscrowProxy(address(votingEscrowImpl), votingEscrowInitData));

        console.log("VotingEscrow deployed at:", address(votingEscrow));

        ContinuumDAO ctmDAOGovernor = new ContinuumDAO(address(votingEscrow), deployer);
        console.log("ContinuumDAO deployed at:", address(ctmDAOGovernor));

        NodeProperties nodeProperties = new NodeProperties(address(ctmDAOGovernor), address(votingEscrow));
        console.log("NodeProperties deployed at:", address(nodeProperties));

        Rewards rewards = new Rewards(
            1755043200, // _firstMidnight,
            address(votingEscrow), // _ve
            address(ctmDAOGovernor), // _gov
            address(ctm), // _rewardToken
            feeToken, // _feeToken
            address(nodeProperties), // _nodeProperties
            1 ether / 2000, // _baseEmissionRate
            1 ether / 1000, // _nodeEmissionRate
            5000 ether, // _nodeRewardThreshold
            7_812_500 gwei, // _feePerByteRewardToken
            3125 // _feePerByteFeeToken
        );
        console.log("Rewards deployed at:", address(rewards));

        INodeProperties(nodeProperties).setRewards(address(rewards));
        IVotingEscrow(votingEscrow)
            .initContracts(address(ctmDAOGovernor), address(nodeProperties), address(rewards), treasury);

        vm.stopBroadcast();
    }
}
