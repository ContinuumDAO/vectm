// SPDX-License-Identifier: Unlicensed

pragma solidity 0.8.27;

import {Script} from "forge-std/Script.sol";
import {Config} from "forge-std/Config.sol";
import {console} from "forge-std/console.sol";

import {IC3GovClient} from "@c3caller/gov/IC3GovClient.sol";
import {IC3GovernDApp} from "@c3caller/gov/IC3GovernDApp.sol";

import {IVotingEscrow} from "../../build/token/VotingEscrow.sol";
import {INodeProperties} from "../../build/node/NodeProperties.sol";
import {IRewards} from "../../build/node/Rewards.sol";

contract GovernanceSettings is Script, Config {
    mapping(address => string) private _governanceLabels;

    function run() public {
        _loadConfig("./config/deployments.toml", false);

        address admin = config.get("admin").toAddress();
        address uuidKeeper = config.get("uuidKeeper").toAddress();
        address dappManager = config.get("dappManager").toAddress();
        address c3caller = config.get("c3caller").toAddress();
        address c3governor = config.get("c3governor").toAddress();
        address ctm = config.get("ctm").toAddress();

        _governanceLabels[c3governor] = string.concat("C3Governor_", vm.toString(block.chainid));
        _governanceLabels[admin] = "Admin";

        address uuidKeeperGov = IC3GovClient(uuidKeeper).gov();
        address dappManagerGov = IC3GovClient(dappManager).gov();
        address c3callerGov = IC3GovClient(c3caller).gov();
        address c3governorGov = IC3GovernDApp(c3governor).gov();
        address ctmGov = IC3GovernDApp(ctm).gov();

        console.log("UUID Keeper Gov:", _governanceLabels[uuidKeeperGov]);
        console.log("DApp Manager Gov:", _governanceLabels[dappManagerGov]);
        console.log("C3Caller Gov:", _governanceLabels[c3callerGov]);
        console.log("C3Governor Gov:", _governanceLabels[c3governorGov]);
        console.log("CTM Gov:", _governanceLabels[ctmGov]);

        if (block.chainid == 59144) {
            address dao = config.get("dao").toAddress();

            _governanceLabels[dao] = "ContinuumDAO";

            address ve = config.get("ve").toAddress();
            address nodeProperties = config.get("nodeProperties").toAddress();
            address rewards = config.get("rewards").toAddress();

            address veGov = IVotingEscrow(ve).governor();
            address nodePropertiesGov = INodeProperties(nodeProperties).gov();
            address rewardsGov = IRewards(rewards).gov();

            console.log("VE Gov:", _governanceLabels[veGov]);
            console.log("Node Properties Gov:", _governanceLabels[nodePropertiesGov]);
            console.log("Rewards Gov:", _governanceLabels[rewardsGov]);
        }
    }
}
