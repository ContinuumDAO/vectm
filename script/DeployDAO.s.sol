// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.27;

import {Script} from "forge-std/Script.sol";
import {Config} from "forge-std/Config.sol";
import {console} from "forge-std/console.sol";

import {IC3GovClient} from "@c3caller/gov/IC3GovClient.sol";
import {IC3GovernDApp} from "@c3caller/gov/IC3GovernDApp.sol";

import {NodeProperties} from "../build/node/NodeProperties.sol";
import {Rewards} from "../build/node/Rewards.sol";
import {VotingEscrow} from "../build/token/VotingEscrow.sol";
import {VotingEscrowProxy} from "../build/utils/VotingEscrowProxy.sol";
import {ContinuumDAO} from "../build/governance/ContinuumDAO.sol";
import {Distribution} from "../build/token/Distribution.sol";

contract DeployDAO is Script, Config {
    function run() public {
        _loadConfig("./config/deploy-dao.toml", false);

        address admin = config.get("admin").toAddress();
        address ctm = config.get("ctm").toAddress();
        address usdc = config.get("usdc").toAddress();
        address uuidKeeper = config.get("uuidKeeper").toAddress();
        address dappManager = config.get("dappManager").toAddress();
        address c3caller = config.get("c3caller").toAddress();
        address c3governor = config.get("c3governor").toAddress();
        uint256 totalClaimable = config.get("totalClaimable").toUint256();

        vm.startBroadcast();

        VotingEscrow veImpl = new VotingEscrow();
        bytes memory veInitData =
            abi.encodeWithSelector(VotingEscrow.initialize.selector, address(ctm), "https://app-api.continuumdao.org/");
        VotingEscrowProxy ve = new VotingEscrowProxy(address(veImpl), veInitData);

        ContinuumDAO dao = new ContinuumDAO(address(ve), admin);

        NodeProperties nodeProperties = new NodeProperties(admin, address(ve));

        Rewards rewards = new Rewards(
            1771459200, // _firstMidnight (19th Feb 2026 00:00:00 GMT)
            address(ve), // _ve
            admin, // _gov
            address(ctm), // _rewardToken
            usdc, // _usdc
            address(nodeProperties), // _nodeProperties
            0, // _baseEmissionRate
            1 ether / 1000, // _nodeEmissionRate
            5000 ether, // _nodeRewardThreshold
            0, // _feePerByteRewardToken (deprecated)
            0 // _feePerByteFeeToken     (deprecated)
        );

        nodeProperties.setRewards(address(rewards));

        VotingEscrow(address(ve)).initContracts(address(dao), address(nodeProperties), address(rewards), address(dao));

        Distribution dist = new Distribution(ctm, address(ve), address(dao), totalClaimable);

        IC3GovClient(uuidKeeper).changeGov(address(dao));
        IC3GovClient(dappManager).changeGov(address(dao));
        IC3GovClient(c3caller).changeGov(address(dao));

        IC3GovernDApp(c3governor).changeGov(address(dao));

        vm.stopBroadcast();

        console.log("VotingEscrow deployed to:", address(ve));
        console.log("ContinuumDAO deployed to:", address(dao));
        console.log("NodeProperties deployed to:", address(nodeProperties));
        console.log("Rewards deployed to:", address(rewards));
        console.log("Distributor deployed to: ", address(dist));
    }
}
