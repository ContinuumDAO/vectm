// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import {NodeProperties} from "../src/NodeProperties.sol";
import {VotingEscrowProxy} from "../src/VotingEscrowProxy.sol";
import {IVotingEscrow, VotingEscrow} from "../src/VotingEscrow.sol";
import {Rewards} from "../src/Rewards.sol";
import {TestERC20} from "../src/TestERC20.sol";

contract TestNodeProperties is Test {
    TestERC20 ctm;
    TestERC20 usdc;
    VotingEscrow veImpl;
    VotingEscrowProxy veProxy;
    IVotingEscrow ve;
    NodeProperties nodeProperties;
    Rewards rewards;
    string constant MNEMONIC = "test test test test test test test test test test test junk";
    string constant BASE_URI_V1 = "veCTM V1";
    address gov;
    address committee;
    address treasury;
    address user;
    uint256 CTM_TS = 100_000_000 ether;
    uint256 initialBalGov = CTM_TS;
    uint256 initialBalUser = CTM_TS;
    uint256 constant MAXTIME = 4 * 365 * 86400;
    uint256 constant ONE_YEAR = 365 * 86400;
    uint256 constant WEEK = 1 weeks;
    uint256 id1;
    uint256 id2;

    NodeProperties.NodeInfo submittedNodeInfo = NodeProperties.NodeInfo(
        // string forumHandle;
        "@myhandle",
        // string email
        "john.doe@mail.com",
        // uint8[4] ip;
        [0,0,0,0],
        // string vpsProvider;
        "Contabo",
        // uint256 ramInstalled;
        16000000000,
        // uint256 cpuCores;
        8,
        // string dIDType;
        "Galxe",
        // string dID;
        "123457890",
        // bytes data;
        ""
    );


    function setUp() public virtual {
        uint256 privKey0 = vm.deriveKey(MNEMONIC, 0);
        gov = vm.addr(privKey0);
        uint256 privKey1 = vm.deriveKey(MNEMONIC, 1);
        committee = vm.addr(privKey1);
        uint256 privKey2 = vm.deriveKey(MNEMONIC, 2);
        treasury = vm.addr(privKey2);
        uint256 privKey3 = vm.deriveKey(MNEMONIC, 3);
        user = vm.addr(privKey3);

        ctm = new TestERC20(18);
        usdc = new TestERC20(6);
        veImpl = new VotingEscrow();
        bytes memory initializerData = abi.encodeWithSignature(
            "initialize(address,string)",
            address(ctm),
            BASE_URI_V1
        );
        veProxy = new VotingEscrowProxy(address(veImpl), initializerData);

        ve = IVotingEscrow(address(veProxy));
        ve.setGovernor(gov);
        ctm.print(user, initialBalUser);
        vm.prank(user);
        ctm.approve(address(ve), initialBalUser);

        rewards = new Rewards(
            0,
            gov,
            address(ctm),
            address(usdc),
            address(0),
            address(ve),
            address(nodeProperties),
            address(0)
        );
        
        nodeProperties = new NodeProperties(gov, address(ve));
        vm.startPrank(gov);
        nodeProperties.setRewards(address(rewards));
        rewards.setNodeRewardThreshold(5000 ether);
        ve.setTreasury(treasury);
        ve.setNodeProperties(address(nodeProperties));
        ve.enableLiquidations();
        vm.stopPrank();
    }

    modifier prank(address _user) {
        vm.startPrank(_user);
        _;
        vm.stopPrank();
    }

    function test_AttachNode() public {
        vm.startPrank(user);
        id1 = ve.create_lock(10000 ether, MAXTIME);
        nodeProperties.attachNode(id1, 1, submittedNodeInfo);
        vm.stopPrank();
    }

    function test_AttachNodeSufficientVePower() public prank(user) {
        id1 = ve.create_lock(5000 ether, MAXTIME);
        skip(1);
        vm.expectRevert();
        nodeProperties.attachNode(id1, 1, submittedNodeInfo);
        ve.increase_amount(id1, 14 ether);
        nodeProperties.attachNode(id1, 1, submittedNodeInfo);
    }

    function test_OnlyAttachOneTokenID() public prank(user) {
        id1 = ve.create_lock(5014 ether, MAXTIME);
        skip(1);
        id2 = ve.create_lock(5014 ether, MAXTIME);
        nodeProperties.attachNode(id1, 1, submittedNodeInfo);
        vm.expectRevert();
        nodeProperties.attachNode(id1, 2, submittedNodeInfo);
        vm.expectRevert();
        nodeProperties.attachNode(id2, 1, submittedNodeInfo);
    }

    function test_NodeDetachment() public {
        vm.prank(user);
        id1 = ve.create_lock(5014 ether, MAXTIME);
        vm.prank(gov);
        vm.expectRevert();
        nodeProperties.detachNode(id1, 1);
    }

    function test_AttachingDisablesInteractions() public {
        vm.startPrank(user);
        id1 = ve.create_lock(5014 ether, MAXTIME);
        skip(1);
        id2 = ve.create_lock(5014 ether, MAXTIME);
        nodeProperties.attachNode(id1, 1, submittedNodeInfo);
        skip(1);
        vm.expectRevert();
        ve.liquidate(id1);
        vm.stopPrank();
        vm.prank(gov);
        nodeProperties.detachNode(id1, 1);
        vm.prank(user);
        ve.liquidate(id1);
    }
}