// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import {Test} from "forge-std/Test.sol";

import {TestERC20} from "../src/mocks/TestERC20.sol";
import {VotingEscrow} from "../src/token/VotingEscrow.sol";
import {VotingEscrowProxy} from "../src/utils/VotingEscrowProxy.sol";
import {CTMDAOGovernor} from "../src/gov/CTMDAOGovernor.sol";
import {NodeProperties} from "../src/node/NodeProperties.sol";
import {Rewards} from "../src/node/Rewards.sol";

contract StateTest is Test {
    TestERC20 ctm;
    TestERC20 usdc;
    VotingEscrow veImplementation;
    VotingEscrowProxy veProxy;
    VotingEscrow ve;
    CTMDAOGovernor ctmDaoGovernor;
    NodeProperties nodeProperties;
    Rewards rewards;
    address sender;
    address treasury;

    function setUp() public {
        // Deployments
        ctm = new TestERC20("Continuum", "CTM", 18);
        usdc = new TestERC20("USD Coin", "USDC", 6);
        veImplementation = new VotingEscrow();
        veProxy = new VotingEscrowProxy(
            address(veImplementation),
            abi.encodeWithSignature("initialize(address,string)", address(ctm), "Base URI")
        );
        ve = VotingEscrow(ve);
        nodeProperties = new NodeProperties(address(ctmDaoGovernor), address(veProxy));
        rewards = new Rewards(
            0, // _firstMidnight,
            address(ctmDaoGovernor), // _gov
            address(ctm), // _rewardToken
            address(usdc), // _feeToken
            address(0), // _swapRouter
            address(ve), // _ve
            address(nodeProperties), // _nodeProperties
            address(0), // _weth
            1 ether / 2000, // _baseEmissionRate
            1 ether / 1000, // _nodeEmissionRate
            5000 ether, // _nodeRewardThreshold
            7_812_500 gwei, // _feePerByteRewardToken
            3125 // _feePerByteFeeToken
        );


        sender = makeAddr("sender");
        treasury = makeAddr("treasury");
        ve.setUp(address(ctmDaoGovernor), address(nodeProperties), address(rewards), treasury);
    }

    function test_ReadStorage() public {
        assertEq(ve.token(), address(ctm));
        assertEq(ve.governor(), address(ctmDaoGovernor));
    }
}