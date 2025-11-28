// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

import {C3Caller} from "@c3caller/C3Caller.sol";
import {C3CallerUpgradeable} from "@c3caller/upgradeable/C3CallerUpgradeable.sol";
import {C3UUIDKeeperUpgradeable} from "@c3caller/upgradeable/uuid/C3UUIDKeeperUpgradeable.sol";
import {C3UUIDKeeper} from "@c3caller/uuid/C3UUIDKeeper.sol";
import {C3DAppManagerUpgradeable} from "@c3caller/upgradeable/dapp/C3DAppManagerUpgradeable.sol";
import {C3DAppManager} from "@c3caller/dapp/C3DAppManager.sol";

import {ContinuumDAO} from "../../src/governance/ContinuumDAO.sol";
import {NodeProperties} from "../../src/node/NodeProperties.sol";
import {Rewards} from "../../src/node/Rewards.sol";
import {CTM} from "../../src/token/CTM.sol";
import {VotingEscrow} from "../../src/token/VotingEscrow.sol";
import {TestERC20} from "./mocks/TestERC20.sol";

import {Utils} from "./Utils.sol";

contract Deployer is Utils {
    C3UUIDKeeper uuidKeeper;
    C3DAppManager dappManager;
    C3Caller c3caller;
    TestERC20 usdc;
    CTM ctm;
    VotingEscrow ve;
    ContinuumDAO continuumDAO;
    NodeProperties nodeProperties;
    Rewards rewards;

    function _deployCTM(address _admin) internal {
        ctm = new CTM(_admin);
    }

    function _deployUSDC() internal {
        usdc = new TestERC20("Circle USD", "USDC", 6);
    }

    function _deployC3Caller() internal {
        address uuidKeeperImpl = address(new C3UUIDKeeperUpgradeable());
        uuidKeeper = C3UUIDKeeper(_deployProxy(uuidKeeperImpl, abi.encodeCall(C3UUIDKeeperUpgradeable.initialize, ())));
        address dappManagerImpl = address(new C3DAppManagerUpgradeable());
        dappManager =
            C3DAppManager(_deployProxy(dappManagerImpl, abi.encodeCall(C3DAppManagerUpgradeable.initialize, ())));
        address c3callerImpl = address(new C3CallerUpgradeable());
        c3caller = C3Caller(
            _deployProxy(
                c3callerImpl,
                abi.encodeCall(C3CallerUpgradeable.initialize, (address(uuidKeeper), address(dappManager)))
            )
        );
        uuidKeeper.setC3Caller(address(c3caller));
        dappManager.setC3Caller(address(c3caller));
    }

    function _deployVotingEscrow() internal {
        VotingEscrow veImpl = new VotingEscrow();
        ve = VotingEscrow(
            _deployProxy(address(veImpl), abi.encodeCall(VotingEscrow.initialize, (address(ctm), "Base URI")))
        );
    }

    function _deployCTMDAOGovernor(address _proposalGuardian) internal {
        continuumDAO = new ContinuumDAO(address(ve), _proposalGuardian);
    }

    function _deployNodeProperties() internal {
        nodeProperties = new NodeProperties(address(continuumDAO), address(ve));
    }

    function _deployRewards() internal {
        rewards = new Rewards(
            0, // _firstMidnight,
            address(ve), // _ve
            address(continuumDAO), // _gov
            address(ctm), // _rewardToken
            address(usdc), // _feeToken
            address(nodeProperties), // _nodeProperties
            1 ether / 2000, // _baseEmissionRate
            1 ether / 1000, // _nodeEmissionRate
            5000 ether, // _nodeRewardThreshold
            7_812_500 gwei, // _feePerByteRewardToken
            3125 // _feePerByteFeeToken
        );
    }

    function _initContracts(address _treasury) internal {
        vm.startPrank(address(continuumDAO));
        nodeProperties.setRewards(address(rewards));
        ve.initContracts(address(continuumDAO), address(nodeProperties), address(rewards), _treasury);
        ve.setLiquidationsEnabled(true);
        vm.stopPrank();
    }

    function _fundRewards() internal {
        deal(address(ctm), address(this), 100_000_000 ether, true);
        ctm.approve(address(rewards), 100_000_000 ether);
        rewards.receiveFees(address(ctm), 100_000_000 ether, 1);
    }
}
