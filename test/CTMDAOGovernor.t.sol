// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import {CTMDAOGovernor} from "../src/CTMDAOGovernor.sol";
import {IVotingEscrow, VotingEscrow} from "../src/VotingEscrow.sol";
import {VotingEscrowProxy} from "../src/VotingEscrowProxy.sol";
import {VotingEscrowV2} from "../src/VotingEscrowV2.sol";
import {CTM} from "../src/CTM.sol";
import {NodeProperties} from "../src/NodeProperties.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

interface IVotingEscrowUpgradable is IVotingEscrow {
    function upgradeToAndCall(address newImplementation, bytes memory data) external;
}

contract SetUp is Test {
    CTMDAOGovernor governor;
    CTM ctm;
    VotingEscrow veImplV1;
    VotingEscrowProxy veProxy;
    IVotingEscrowUpgradable ve;
    NodeProperties nodeProperties;
    string constant MNEMONIC = "test test test test test test test test test test test junk";
    string constant BASE_URI_V1 = "veCTM V1";
    address gov;
    address committee;
    address user;
    uint256 CTM_TS = 100_000_000 ether;
    uint256 initialBalGov = CTM_TS;
    uint256 initialBalUser = CTM_TS;
    uint256 constant MAXTIME = 4 * 365 * 86400;
    uint256 constant ONE_YEAR = 365 * 86400;
    uint256 constant WEEK = 1 weeks;

    function setUp() public virtual {
        uint256 privKey1 = vm.deriveKey(MNEMONIC, 1);
        committee = vm.addr(privKey1);
        uint256 privKey2 = vm.deriveKey(MNEMONIC, 2);
        user = vm.addr(privKey2);

        ctm = new CTM(gov);
        veImplV1 = new VotingEscrow();
        bytes memory initializerData = abi.encodeWithSignature(
            "initialize(address,string)",
            address(ctm),
            BASE_URI_V1
        );
        veProxy = new VotingEscrowProxy(address(veImplV1), initializerData);

        governor = new CTMDAOGovernor(IVotes(address(veProxy)));
        gov = address(governor);

        ve = IVotingEscrowUpgradable(address(veProxy));
        ctm.print(user, initialBalUser);
        vm.prank(user);
        ctm.approve(address(ve), initialBalUser);
        
        nodeProperties = new NodeProperties(gov, committee, address(ve));
        // ve.setNodeProperties(address(nodeProperties));
    }

    modifier prank(address _user) {
        vm.startPrank(_user);
        _;
        vm.stopPrank();
    }
}

contract GovernorBasic is SetUp {
    uint256 tokenId;

    // UTILS
    
    function setUp() public override {
        super.setUp();
        vm.prank(user);
        tokenId = ve.create_lock(1 ether, block.timestamp + MAXTIME);
        vm.warp(100);
    }

    function _proposeVote(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) internal returns (uint256) {
        return governor.propose(targets, values, calldatas, description);
    }

    function _castVote(uint256 proposalId, uint8 support) internal returns (uint256) {
        vm.warp(block.timestamp + 5 days);
        uint256 weight = governor.castVote(proposalId, support);
        return weight;
    }

    function _queueVote(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) internal returns (uint256) {
        vm.warp(block.timestamp + 10 days);
        uint256 proposalId = governor.queue(targets, values, calldatas, keccak256(bytes(description)));
        return proposalId;
    }

    function _executeVote(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) internal returns (uint256) {
        uint256 proposalId = governor.execute(targets, values, calldatas, keccak256(bytes(description)));
        return proposalId;
    }

    function test_InitialSettings() public prank(user) {
        vm.warp(block.timestamp + 1);
        uint256 totalPower = ve.getPastTotalSupply(block.timestamp - 1);
        uint256 votingDelay = governor.votingDelay();
        uint256 votingPeriod = governor.votingPeriod();
        uint256 proposalThreshold = governor.proposalThreshold();
        assertEq(votingDelay, 5 days);
        assertEq(votingPeriod, 10 days);
        assertEq(proposalThreshold, totalPower / 100);
    }

    function test_ProposeSetNodeProperties() public prank(user) {
        address[] memory targets = new address[](1);
        targets[0] = address(ve);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("setNodeProperties(address)", address(nodeProperties));

        _proposeVote(targets, values, calldatas, "Proposal #1: Set node properties address.");
    }
}