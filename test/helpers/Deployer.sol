// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import { C3Caller } from "@c3caller/C3Caller.sol";
import { C3CallerUpgradeable } from "@c3caller/upgradeable/C3CallerUpgradeable.sol";
import { C3UUIDKeeperUpgradeable } from "@c3caller/upgradeable/uuid/C3UUIDKeeperUpgradeable.sol";
import { C3UUIDKeeper } from "@c3caller/uuid/C3UUIDKeeper.sol";

import { CTM } from "../../src/token/CTM.sol";
import { VotingEscrow } from "../../src/token/VotingEscrow.sol";
import { NodeProperties } from "../../src/node/NodeProperties.sol";
import { Rewards } from "../../src/node/Rewards.sol";
import { WETH } from "../../src/mocks/WETH.sol";
import { CTMDAOGovernor } from "../../src/gov/CTMDAOGovernor.sol";

import { Utils } from "./Utils.sol";

contract Deployer is Utils {
    C3UUIDKeeper c3UUIDKeeper;
    C3Caller c3caller;
    CTM ctm;
    VotingEscrow ve;
    CTMDAOGovernor ctmDaoGovernor;
    NodeProperties nodeProperties;
    Rewards rewards;
    WETH weth;
    address swapRouter;

    function _deployCTM(address _admin) internal {
        ctm = new CTM(_admin);
    }

    function _deployWETH() internal {
        weth = new WETH();
    }

    function _deployC3Caller() internal {
        address c3UUIDKeeperImpl = address(new C3UUIDKeeperUpgradeable());
        c3UUIDKeeper =
            C3UUIDKeeper(_deployProxy(c3UUIDKeeperImpl, abi.encodeCall(C3UUIDKeeperUpgradeable.initialize, ())));
        address c3callerImpl = address(new C3CallerUpgradeable());
        c3caller = C3Caller(
            _deployProxy(c3callerImpl, abi.encodeCall(C3CallerUpgradeable.initialize, (address(c3UUIDKeeper))))
        );
    }

    function _deployVotingEscrow(address _ctm) internal {
        VotingEscrow veImpl = new VotingEscrow();
        ve = VotingEscrow(_deployProxy(address(veImpl), abi.encodeCall(VotingEscrow.initialize, (address(_ctm), "Base URI"))));
        ve.enableLiquidations();
    }

    function _deployCTMDAOGovernor(address _ve) internal {
        ctmDaoGovernor = new CTMDAOGovernor(_ve);
    }

    function _deployNodeProperties(address _admin, address _ve) internal {
        nodeProperties = new NodeProperties(_admin, _ve);
    }

    function _deployRewards(address _usdc, address _treasury, address _admin) internal {
        rewards = new Rewards(
            uint48(0), // _firstMidnight,
            address(ve), // _ve
            address(ctmDaoGovernor), // _gov
            address(ctm), // _ctm
            address(_usdc), // _usdc
            address(swapRouter), // _swapRouter
            address(nodeProperties), // _nodeProperties
            address(weth), // _weth
            1000000000000000000, // _baseEmissionRate
            1000000000000000000, // _nodeEmissionRate
            1000000000000000000, // _nodeRewardThreshold
            1000000000000000000, // _feePerByteRewardToken
            1000000000000000000 // _feePerByteFeeToken
        );
        nodeProperties.setRewards(address(rewards));
        ve.setUp(_admin, address(nodeProperties), address(rewards), _treasury);
    }
}