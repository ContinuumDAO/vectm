// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import {NodeProperties} from "../src/NodeProperties.sol";
import {VotingEscrowProxy} from "../src/VotingEscrowProxy.sol";
import {IVotingEscrow, VotingEscrow} from "../src/VotingEscrow.sol";
import {CTM} from "../src/CTM.sol";

contract TestNodeProperties is Test {
    CTM ctm;
    VotingEscrow veImpl;
    VotingEscrowProxy veProxy;
    IVotingEscrow ve;
    NodeProperties nodeProperties;
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
    uint8 constant DEFAULT = uint8(NodeProperties.NodeValidationStatus.Default);
    uint8 constant PENDING = uint8(NodeProperties.NodeValidationStatus.Pending);
    uint8 constant APPROVED = uint8(NodeProperties.NodeValidationStatus.Approved);

    function setUp() public virtual {
        uint256 privKey0 = vm.deriveKey(MNEMONIC, 0);
        gov = vm.addr(privKey0);
        uint256 privKey1 = vm.deriveKey(MNEMONIC, 1);
        committee = vm.addr(privKey1);
        uint256 privKey2 = vm.deriveKey(MNEMONIC, 2);
        treasury = vm.addr(privKey2);
        uint256 privKey3 = vm.deriveKey(MNEMONIC, 3);
        user = vm.addr(privKey3);

        ctm = new CTM(gov);
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
        
        nodeProperties = new NodeProperties(gov, committee, address(ve), 5000 ether);
        vm.startPrank(gov);
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

    function _getNodeValidationStatus(uint256 _tokenId) internal view returns (uint8) {
        return uint8(nodeProperties.nodeValidationStatus(_tokenId));
    }

    function test_SetNodeInfo() public {
        vm.startPrank(user);
        id1 = ve.create_lock(10000 ether, MAXTIME);
        NodeProperties.NodeInfo memory submittedNodeInfo = NodeProperties.NodeInfo(
            // string forumHandle;
            "@myhandle",
            // string enode;
            "enode://1.2.3.4",
            // string ip;
            "5.6.7.8",
            // string port;
            "8000",
            // string countryCode;
            "SH",
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

        uint8 status = _getNodeValidationStatus(id1);
        assertEq(status, DEFAULT);

        nodeProperties.setNodeInfo(id1, submittedNodeInfo);
        vm.stopPrank();

        status = _getNodeValidationStatus(id1);
        assertEq(status, PENDING);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = id1;
        bool[] memory validations = new bool[](1);
        validations[0] = true;

        vm.startPrank(committee);
        nodeProperties.setNodeValidations(tokenIds, validations);

        status = _getNodeValidationStatus(id1);
        assertEq(status, APPROVED);

        validations[0] = false;
        nodeProperties.setNodeValidations(tokenIds, validations);

        status = _getNodeValidationStatus(id1);
        assertEq(status, DEFAULT);
        vm.stopPrank();
    }

    function test_NodeAttachment() public {
        vm.prank(user);
        id1 = ve.create_lock(5000 ether, MAXTIME);
        skip(1);
        vm.prank(gov);
        vm.expectRevert();
        nodeProperties.attachNode(id1, 1);
        vm.prank(user);
        ve.increase_amount(id1, 14 ether);
        vm.prank(gov);
        nodeProperties.attachNode(id1, 1);
    }

    function test_OnlyAttachOneTokenID() public {
        vm.startPrank(user);
        id1 = ve.create_lock(5014 ether, MAXTIME);
        skip(1);
        id2 = ve.create_lock(5014 ether, MAXTIME);
        vm.stopPrank();
        vm.startPrank(gov);
        nodeProperties.attachNode(id1, 1);
        vm.expectRevert();
        nodeProperties.attachNode(id1, 2);
        vm.expectRevert();
        nodeProperties.attachNode(id2, 1);
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
        vm.stopPrank();
        vm.prank(gov);
        nodeProperties.attachNode(id1, 1);
        skip(1);
        vm.prank(user);
        vm.expectRevert();
        ve.liquidate(id1);
        vm.prank(gov);
        nodeProperties.detachNode(id1, 1);
        vm.prank(user);
        ve.liquidate(id1);
    }
}