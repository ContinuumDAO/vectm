// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.27;

import {Script} from "forge-std/Script.sol";
import {Config} from "forge-std/Config.sol";
import {console} from "forge-std/console.sol";

import {IC3GovClient} from "@c3caller/gov/IC3GovClient.sol";
import {IC3GovernDApp} from "@c3caller/gov/IC3GovernDApp.sol";

import {NodeProperties} from "../build/node/NodeProperties.sol";
import {Rewards} from "../build/node/Rewards.sol";
import {VotingEscrow, IVotingEscrow} from "../build/token/VotingEscrow.sol";
import {VotingEscrowProxy} from "../build/utils/VotingEscrowProxy.sol";
import {ContinuumDAO} from "../build/governance/ContinuumDAO.sol";
import {Distribution} from "../build/token/Distribution.sol";

import {Utils} from "../test/helpers/Utils.sol";

contract DeployDAO is Script, Config, Utils {
    error PredictedAddressMismatch(string name, address predicted, address actual);

    function run() public {
        _loadConfig("./config/deploy-dao.toml", false);

        address admin = config.get("admin").toAddress();
        address ctm = config.get("ctm").toAddress();
        address usdc = config.get("usdc").toAddress();
        address uuidKeeper = config.get("uuidKeeper").toAddress();
        address dappManager = config.get("dappManager").toAddress();
        address c3caller = config.get("c3caller").toAddress();
        address c3governor = config.get("c3governor").toAddress();
        address msaw = config.get("msaw").toAddress();
        uint256 totalClaimable = config.get("totalClaimable").toUint256();

        vm.startBroadcast();

        // Forge deploys this script contract first (CREATE from admin), then runs run(). The CREATEs
        // below (new VotingEscrow(), etc.) are therefore from the script contract with nonce 0, 1, 2, 3.
        uint256 initialNonce = 150;

        address _veImpl = vm.computeCreateAddress(admin, initialNonce);
        address _dao = vm.computeCreateAddress(admin, initialNonce + 2);
        address _nodeProperties = vm.computeCreateAddress(admin, initialNonce + 3);
        address _rewards = vm.computeCreateAddress(admin, initialNonce + 4);

        // nonce == 0
        VotingEscrow veImpl = new VotingEscrow();

        if (address(veImpl) != _veImpl) {
            revert PredictedAddressMismatch("Voting Escrow Implementation", address(veImpl), _veImpl);
        }

        bytes memory veInitData = abi.encodeWithSelector(
            VotingEscrow.initialize.selector,
            address(ctm),
            _dao,
            _nodeProperties,
            _rewards,
            "https://app-api.continuumdao.org/"
        );

        // nonce == 1
        VotingEscrowProxy ve = new VotingEscrowProxy(_veImpl, veInitData);
        address _ve = address(ve);

        // nonce == 2
        ContinuumDAO dao = new ContinuumDAO(_ve, admin);

        if (address(dao) != _dao) {
            revert PredictedAddressMismatch("DAO", address(dao), _dao);
        }

        // nonce == 3
        NodeProperties nodeProperties = new NodeProperties(_dao, _ve, msaw);

        if (address(nodeProperties) != _nodeProperties) {
            revert PredictedAddressMismatch("Node Properties", address(nodeProperties), _nodeProperties);
        }

        // nonce == 4
        Rewards rewards = new Rewards(
            1772064000, // _firstMidnight (26th Feb 2026 00:00:00 GMT)
            _ve, // _ve
            admin, // _gov
            address(ctm), // _rewardToken
            usdc, // _usdc
            _nodeProperties, // _nodeProperties
            0, // _baseEmissionRate
            1 ether / 1000, // _nodeEmissionRate
            5000 ether, // _nodeRewardThreshold
            0, // _feePerByteRewardToken (deprecated)
            0 // _feePerByteFeeToken    (deprecated)
        );

        if (address(rewards) != _rewards) {
            revert PredictedAddressMismatch("Rewards", address(rewards), _rewards);
        }

        Distribution dist = new Distribution(ctm, _ve, _dao, totalClaimable);

        address _dao_ve = IVotingEscrow(_ve).governor();
        if (_dao_ve != _dao) {
            revert PredictedAddressMismatch("ve.governor() != _dao", _dao_ve, _dao);
        }

        address _np_ve = IVotingEscrow(_ve).nodeProperties();
        if (_np_ve != _nodeProperties) {
            revert PredictedAddressMismatch("ve.nodeProperties() != _nodeProperties", _np_ve, _nodeProperties);
        }

        address _rewards_ve = IVotingEscrow(_ve).rewards();
        if (_rewards_ve != _rewards) {
            revert PredictedAddressMismatch("ve.rewards() != _rewards", _rewards_ve, _rewards);
        }

        address _treasury_ve = IVotingEscrow(_ve).treasury();
        if (_treasury_ve != _dao) {
            revert PredictedAddressMismatch("ve.treasury() != _treasury", _treasury_ve, _dao);
        }

        // IC3GovClient(uuidKeeper).changeGov(_dao);
        // IC3GovClient(dappManager).changeGov(_dao);
        // IC3GovClient(c3caller).changeGov(_dao);

        // DAO must now pass a proposal to applyGov itself on these 3 contracts, and set rewards in NodeProperties

        // IC3GovernDApp(c3governor).changeGov(_dao);
        // IC3GovernDApp(ctm).changeGov(_dao);

        vm.stopBroadcast();

        console.log("VotingEscrowImplementation deployed to:", _veImpl);
        console.log("VotingEscrow deployed to:", _ve);
        console.log("ContinuumDAO deployed to:", _dao);
        console.log("NodeProperties deployed to:", _nodeProperties);
        console.log("Rewards deployed to:", _rewards);
        console.log("Distributor deployed to: ", address(dist));
    }
}
