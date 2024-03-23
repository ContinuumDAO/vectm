// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import {CTMDAOGovernor} from "../src/CTMDAOGovernor.sol";
import {IVotingEscrow, VotingEscrow} from "../src/VotingEscrow.sol";
import {VotingEscrowProxy} from "../src/VotingEscrowProxy.sol";
import {VotingEscrowV2} from "../src/VotingEscrowV2.sol";
import {TestERC20} from "../src/TestERC20.sol";
import {NodeProperties} from "../src/NodeProperties.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

interface IVotingEscrowUpgradable is IVotingEscrow {
    function upgradeToAndCall(address newImplementation, bytes memory data) external;
}

contract SetUp is Test {
    CTMDAOGovernor governor;
    TestERC20 ctm;
    VotingEscrow veImplV1;
    VotingEscrowProxy veProxy;
    IVotingEscrowUpgradable ve;
    NodeProperties nodeProperties;
    string constant MNEMONIC = "test test test test test test test test test test test junk";
    string constant BASE_URI_V1 = "veCTM V1";
    address gov;
    address committee;
    address user;
    address user2;
    uint256 CTM_TS = 100_000_000 ether;
    uint256 initialBalGov = CTM_TS;
    uint256 initialBalUser = CTM_TS;
    uint256 constant MAXTIME = 4 * 365 * 86400;
    uint256 constant ONE_YEAR = 365 * 86400;
    uint256 constant WEEK = 1 weeks;

    enum VoteType {
        Against,
        For,
        Abstain
    }

    function setUp() public virtual {
        uint256 privKey1 = vm.deriveKey(MNEMONIC, 1);
        committee = vm.addr(privKey1);
        uint256 privKey2 = vm.deriveKey(MNEMONIC, 2);
        user = vm.addr(privKey2);
        uint256 privKey3 = vm.deriveKey(MNEMONIC, 3);
        user2 = vm.addr(privKey3);

        ctm = new TestERC20(18);
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
        ve.setGovernor(gov);
        ctm.print(user, initialBalUser);
        vm.prank(user);
        ctm.approve(address(ve), initialBalUser);
        
        nodeProperties = new NodeProperties(gov, address(ve));
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

    // proposal details
    uint256 proposalId;
    address[] targets;
    uint256[] values;
    bytes[] calldatas;
    bytes32 descriptionHash;

    // UTILS
    
    function setUp() public override {
        super.setUp();
        vm.prank(user);
        tokenId = ve.create_lock(1 ether, block.timestamp + MAXTIME);
        vm.warp(100);
    }

    function _proposeVote(
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        string memory description
    ) internal returns (uint256) {
        return governor.propose(_targets, _values, _calldatas, description);
    }

    function _castVote(uint256 _proposalId, uint8 support) internal returns (uint256) {
        vm.warp(block.timestamp + 5 days + 1);
        uint256 weight = governor.castVote(_proposalId, support);
        return weight;
    }

    function _queueVote(
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        string memory description
    ) internal returns (uint256) {
        // vm.warp(block.timestamp + 10 days + 1);
        uint256 _proposalId = governor.queue(_targets, _values, _calldatas, keccak256(bytes(description)));
        return _proposalId;
    }

    function _executeVote(
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        string memory description
    ) internal returns (uint256) {
        vm.warp(block.timestamp + 10 days + 1);
        uint256 _proposalId = governor.execute(_targets, _values, _calldatas, keccak256(bytes(description)));
        return _proposalId;
    }

    function test_InitialSettings() public prank(user) {
        vm.warp(block.timestamp + 1);
        uint256 totalPower = ve.getPastTotalSupply(block.timestamp - 1);
        uint256 votingDelay = governor.votingDelay();
        uint256 votingPeriod = governor.votingPeriod();
        uint256 proposalThreshold = governor.proposalThreshold();
        uint256 quorum = governor.quorumNumerator(block.timestamp);
        assertEq(votingDelay, 5 days);
        assertEq(votingPeriod, 10 days);
        assertEq(proposalThreshold, totalPower / 100);
        assertEq(quorum, 20); // 20%
    }

    function test_VoteCallContractFunction() public prank(user) {
        address[] memory _targets = new address[](3);
        _targets[0] = address(ve);
        _targets[1] = address(ve);
        _targets[2] = address(ve);
        uint256[] memory _values = new uint256[](3);
        bytes[] memory _calldatas = new bytes[](3);
        _calldatas[0] = abi.encodeWithSignature("setNodeProperties(address)", address(nodeProperties));
        _calldatas[1] = abi.encodeWithSignature("setTreasury(address)", address(user2));
        _calldatas[2] = abi.encodeWithSignature("enableLiquidations()");
        string memory _description = "Proposal #1: Set node properties address.";

        _proposeVote(_targets, _values, _calldatas, _description);

        (proposalId, targets, values, calldatas, descriptionHash) = governor.proposalDetailsAt(0);

        _castVote(proposalId, uint8(VoteType.For));

        _executeVote(_targets, _values, _calldatas, _description);

        address nodePropertiesSet = ve.nodeProperties();
        bool liquidationsEnabled = ve.liquidationsEnabled();
        address treasury = ve.treasury();

        assertEq(nodePropertiesSet, address(nodeProperties));
        assertEq(liquidationsEnabled, true);
        assertEq(treasury, user2);
    }

    function test_ProposalThresholdChanges() public prank(user) {
        uint256 totalVotePowerBefore = ve.getPastTotalSupply(block.timestamp - 1);
        uint256 thresholdBefore = governor.proposalThreshold();
        ve.create_lock(1 ether, block.timestamp + MAXTIME);
        vm.warp(block.timestamp + 1);
        uint256 totalVotePowerAfter = ve.getPastTotalSupply(block.timestamp - 1);
        uint256 thresholdAfter = governor.proposalThreshold();
        assertEq(thresholdBefore, totalVotePowerBefore / 100);
        assertEq(thresholdAfter, totalVotePowerAfter / 100);
    }

    function test_VoteTransferETH() public prank(user) {
        vm.deal(gov, 2000 ether);

        address[] memory _targets = new address[](1);
        _targets[0] = user2;
        uint256[] memory _values = new uint256[](1);
        _values[0] = 10 ether;
        bytes[] memory _calldatas = new bytes[](1);
        string memory _description = "Proposal #2: Transfer 10 ether to user2.";

        uint256 bal2Before = user2.balance;
        uint256 balGovBefore = gov.balance;

        _proposeVote(_targets, _values, _calldatas, _description);
        (proposalId, targets, values, calldatas, descriptionHash) = governor.proposalDetailsAt(0);
        _castVote(proposalId, uint8(VoteType.For));
        _executeVote(_targets, _values, _calldatas, _description);

        uint256 bal2After = user2.balance;
        uint256 balGovAfter = gov.balance;

        assertEq(bal2After, bal2Before + 10 ether);
        assertEq(balGovAfter, balGovBefore - 10 ether);
    }
}