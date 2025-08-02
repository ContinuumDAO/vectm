// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import { C3Caller } from "@c3caller/C3Caller.sol";
import { C3CallerUpgradeable } from "@c3caller/upgradeable/C3CallerUpgradeable.sol";
import { C3UUIDKeeperUpgradeable } from "@c3caller/upgradeable/uuid/C3UUIDKeeperUpgradeable.sol";
import { C3UUIDKeeper } from "@c3caller/uuid/C3UUIDKeeper.sol";

import { CTMDAOGovernor } from "../../src/gov/CTMDAOGovernor.sol";
import { NodeProperties } from "../../src/node/NodeProperties.sol";
import { Rewards } from "../../src/node/Rewards.sol";
import { CTM } from "../../src/token/CTM.sol";
import { VotingEscrow } from "../../src/token/VotingEscrow.sol";
import { TestERC20 } from "./mocks/TestERC20.sol";

import { WETH } from "./mocks/WETH.sol";

import { Utils } from "./Utils.sol";
import { MockSwapRouter } from "./mocks/MockSwapRouter.sol";

contract Deployer is Utils {
    C3UUIDKeeper c3UUIDKeeper;
    C3Caller c3caller;
    TestERC20 usdc;
    CTM ctm;
    VotingEscrow ve;
    CTMDAOGovernor ctmDaoGovernor;
    NodeProperties nodeProperties;
    Rewards rewards;
    WETH weth;
    MockSwapRouter swapRouter;

    function _deployCTM(address _admin) internal {
        ctm = new CTM(_admin);
    }

    function _deployUSDC() internal {
        usdc = new TestERC20("Circle USD", "USDC", 6);
    }

    function _deployWETH() internal {
        weth = new WETH();
    }

    function _deploySwapRouter() internal {
        swapRouter = new MockSwapRouter();
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

    function _deployVotingEscrow() internal {
        VotingEscrow veImpl = new VotingEscrow();
        ve = VotingEscrow(
            _deployProxy(address(veImpl), abi.encodeCall(VotingEscrow.initialize, (address(ctm), "Base URI")))
        );
    }

    function _deployCTMDAOGovernor() internal {
        ctmDaoGovernor = new CTMDAOGovernor(address(ve));
    }

    function _deployNodeProperties() internal {
        nodeProperties = new NodeProperties(address(ctmDaoGovernor), address(ve));
    }

    function _deployRewards() internal {
        rewards = new Rewards(
            0, // _firstMidnight,
            address(ve), // _ve
            address(ctmDaoGovernor), // _gov
            address(ctm), // _rewardToken
            address(usdc), // _feeToken
            address(swapRouter), // _swapRouter
            address(nodeProperties), // _nodeProperties
            address(weth), // _weth
            1 ether / 2000, // _baseEmissionRate
            1 ether / 1000, // _nodeEmissionRate
            5000 ether, // _nodeRewardThreshold
            7_812_500 gwei, // _feePerByteRewardToken
            3125 // _feePerByteFeeToken
        );
    }

    function _initContracts(address _treasury) internal {
        nodeProperties.initContracts(address(rewards));
        ve.initContracts(address(ctmDaoGovernor), address(nodeProperties), address(rewards), _treasury);
        vm.prank(address(ctmDaoGovernor));
        ve.setLiquidationsEnabled(true);
    }

    function _fundRewards() internal {
        deal(address(ctm), address(this), 100_000_000 ether, true);
        ctm.approve(address(rewards), 100_000_000 ether);
        rewards.receiveFees(address(ctm), 100_000_000 ether, 1);
    }
}
