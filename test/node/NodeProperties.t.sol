// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import { INodeProperties } from "../../src/node/INodeProperties.sol";
import { NodeProperties } from "../../src/node/NodeProperties.sol";
import { IVotingEscrow } from "../../src/token/IVotingEscrow.sol";
import { Helpers } from "../helpers/Helpers.sol";

contract TestNodeProperties is Helpers {
    uint256 constant MAXTIME = 4 * 365 * 86_400;
    uint256 id1;
    uint256 id2;

    NodeProperties.NodeInfo submittedNodeInfo = NodeProperties.NodeInfo(
        // string forumHandle;
        "@myhandle",
        // string email
        "john.doe@mail.com",
        // bytes32 nodeId
        keccak256(abi.encode("Example Node ID")),
        // uint8[4] ip;
        [0, 0, 0, 0],
        // string vpsProvider;
        "Contabo",
        // uint256 ramInstalled;
        16_000_000_000,
        // uint256 cpuCores;
        8,
        // string dIDType;
        "Galxe",
        // string dID;
        "123457890",
        // bytes data;
        ""
    );

    function setUp() public override {
        super.setUp();
    }

    modifier prank(address _user) {
        vm.startPrank(_user);
        _;
        vm.stopPrank();
    }

    function test_AttachNode() public {
        vm.startPrank(user1);
        id1 = ve.create_lock(10_000 ether, MAXTIME);
        nodeProperties.attachNode(id1, submittedNodeInfo);
        vm.stopPrank();
    }

    function test_AttachNodeSufficientVePower() public prank(user1) {
        id1 = ve.create_lock(5000 ether, MAXTIME);
        skip(1);
        vm.expectRevert(
            abi.encodeWithSelector(INodeProperties.NodeProperties_NodeRewardThresholdNotReached.selector, id1)
        );
        nodeProperties.attachNode(id1, submittedNodeInfo);
        ve.increase_amount(id1, 14 ether);
        nodeProperties.attachNode(id1, submittedNodeInfo);
    }

    function test_OnlyAttachOneTokenID() public prank(user1) {
        id1 = ve.create_lock(5014 ether, MAXTIME);
        skip(1);
        id2 = ve.create_lock(5014 ether, MAXTIME);
        nodeProperties.attachNode(id1, submittedNodeInfo);
        vm.expectRevert(abi.encodeWithSelector(INodeProperties.NodeProperties_TokenIDAlreadyAttached.selector, id1));
        nodeProperties.attachNode(id1, submittedNodeInfo);
        vm.expectRevert(
            abi.encodeWithSelector(
                INodeProperties.NodeProperties_NodeIDAlreadyAttached.selector, submittedNodeInfo.nodeId
            )
        );
        nodeProperties.attachNode(id2, submittedNodeInfo);
    }

    function test_NodeDetachment() public {
        vm.prank(user1);
        id1 = ve.create_lock(5014 ether, MAXTIME);
        vm.prank(address(ctmDaoGovernor));
        vm.expectRevert(abi.encodeWithSelector(INodeProperties.NodeProperties_TokenIDNotAttached.selector, id1));
        nodeProperties.detachNode(id1);
    }

    function test_AttachingDisablesInteractions() public {
        vm.startPrank(user1);
        id1 = ve.create_lock(5014 ether, MAXTIME);
        skip(1);
        id2 = ve.create_lock(5014 ether, MAXTIME);
        nodeProperties.attachNode(id1, submittedNodeInfo);
        skip(1);
        vm.expectRevert(abi.encodeWithSelector(IVotingEscrow.VotingEscrow_NodeAttached.selector, id1));
        ve.liquidate(id1);
        vm.stopPrank();
        vm.prank(address(ctmDaoGovernor));
        nodeProperties.detachNode(id1);
        vm.prank(user1);
        ve.liquidate(id1);
    }
}
