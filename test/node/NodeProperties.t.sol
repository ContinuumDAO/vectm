// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.27;

import {INodeProperties} from "../../src/node/INodeProperties.sol";
import {NodeProperties} from "../../src/node/NodeProperties.sol";
import {IVotingEscrow} from "../../src/token/IVotingEscrow.sol";
import {VotingEscrowErrorParam} from "../../src/utils/VotingEscrowUtils.sol";
import {Helpers} from "../helpers/Helpers.sol";

contract TestNodeProperties is Helpers {
    uint256 constant MAXTIME = 4 * 365 * 86_400;
    uint256 id1;
    uint256 id2;
    uint16 _0 = uint16(0);

    NodeProperties.NodeInfo submittedNodeInfo = INodeProperties.NodeInfo(
        // string forumHandle;
        "@myhandle",
        // string email
        "john.doe@mail.com",
        // uint8[4] ipv4;
        [0, 0, 0, 0],
        // uint16[8] ipv6
        [_0, _0, _0, _0, _0, _0, _0, _0],
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

    function _attachNodeFor(address _keyGen, uint256 _tokenId) internal {
        vm.prank(msaw);
        nodeProperties.attachNodeFor(_keyGen, _tokenId, submittedNodeInfo);
    }

    function test_AttachNode() public {
        vm.prank(user1);
        id1 = ve.create_lock(10_000 ether, MAXTIME);
        _attachNodeFor(user1, id1);
        assertEq(nodeProperties.attachedKeyGen(id1), user1);
        assertEq(nodeProperties.attachedTokenId(user1), id1);
    }

    function test_AttachNodeOnlyMSAW() public {
        vm.prank(user1);
        id1 = ve.create_lock(10_000 ether, MAXTIME);
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                INodeProperties.NodeProperties_OnlyAuthorized.selector,
                VotingEscrowErrorParam.Sender,
                VotingEscrowErrorParam.MSAW
            )
        );
        nodeProperties.attachNodeFor(user1, id1, submittedNodeInfo);
    }

    function test_AttachNodeKeyGenMustOwnToken() public {
        vm.prank(user1);
        id1 = ve.create_lock(10_000 ether, MAXTIME);
        vm.prank(msaw);
        vm.expectRevert(abi.encodeWithSelector(NodeProperties.NodeProperties_KeyGenMustOwnToken.selector, user2, user1));
        nodeProperties.attachNodeFor(user2, id1, submittedNodeInfo);
    }

    function test_AttachNodeSufficientVePower() public {
        vm.prank(user1);
        id1 = ve.create_lock(5000 ether, MAXTIME);
        skip(1);
        vm.prank(msaw);
        vm.expectRevert(
            abi.encodeWithSelector(INodeProperties.NodeProperties_NodeRewardThresholdNotReached.selector, id1)
        );
        nodeProperties.attachNodeFor(user1, id1, submittedNodeInfo);
        vm.prank(user1);
        ve.increase_amount(id1, 14 ether);
        _attachNodeFor(user1, id1);
    }

    function test_OnlyAttachOneTokenID() public {
        vm.startPrank(user1);
        id1 = ve.create_lock(5014 ether, MAXTIME);
        skip(1);
        id2 = ve.create_lock(5014 ether, MAXTIME);
        vm.stopPrank();
        _attachNodeFor(user1, id1);
        vm.prank(msaw);
        vm.expectRevert(abi.encodeWithSelector(INodeProperties.NodeProperties_TokenIDAlreadyAttached.selector, id1));
        nodeProperties.attachNodeFor(user1, id1, submittedNodeInfo);
        vm.prank(msaw);
        vm.expectRevert(abi.encodeWithSelector(INodeProperties.NodeProperties_KeyGenAlreadyAttached.selector, user1));
        nodeProperties.attachNodeFor(user1, id2, submittedNodeInfo);
    }

    function test_NodeDetachment() public {
        vm.prank(user1);
        id1 = ve.create_lock(5014 ether, MAXTIME);
        vm.prank(address(continuumDAO));
        vm.expectRevert(abi.encodeWithSelector(INodeProperties.NodeProperties_TokenIDNotAttached.selector, id1));
        nodeProperties.detachNode(id1);
    }

    function test_DetachZeroesQuality() public {
        vm.prank(user1);
        id1 = ve.create_lock(5014 ether, MAXTIME);
        _attachNodeFor(user1, id1);

        vm.startPrank(address(continuumDAO));
        nodeProperties.setNodeQualityOf(id1, 8);
        assertEq(nodeProperties.nodeQualityOf(id1), 8);
        nodeProperties.detachNode(id1);
        assertEq(nodeProperties.nodeQualityOf(id1), 0);
        assertEq(nodeProperties.attachedKeyGen(id1), address(0));
        vm.stopPrank();
    }

    function test_AttachingDisablesInteractions() public {
        vm.startPrank(user1);
        id1 = ve.create_lock(5014 ether, MAXTIME);
        skip(1);
        id2 = ve.create_lock(5014 ether, MAXTIME);
        vm.stopPrank();
        _attachNodeFor(user1, id1);
        skip(1);
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IVotingEscrow.VotingEscrow_NodeAttached.selector, id1));
        ve.liquidate(id1);
        vm.prank(address(continuumDAO));
        nodeProperties.detachNode(id1);
        vm.prank(user1);
        ve.liquidate(id1);
    }
}
