// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import {console} from "forge-std/console.sol";

import {ContinuumDAO} from "../../src/governance/ContinuumDAO.sol";

import {NodeProperties} from "../../src/node/NodeProperties.sol";
import {IVotingEscrow, VotingEscrow} from "../../src/token/VotingEscrow.sol";
import {VotingEscrowProxy} from "../../src/utils/VotingEscrowProxy.sol";
import {Helpers} from "../helpers/Helpers.sol";

enum VoteType {
    Against,
    For,
    Abstain
}

contract TestContinuumDAO is Helpers {
    uint256 constant ONE_YEAR = 365 * 86_400;
    uint256 currentTime = block.timestamp;

    modifier prank(address _user) {
        vm.startPrank(_user);
        _;
        vm.stopPrank();
    }

    uint256 tokenId;
    uint256 proposalId;
    address[] targets;
    uint256[] values;
    bytes[] calldatas;
    bytes32 descriptionHash;

    function setUp() public override {
        super.setUp();
        vm.prank(user1);
        uint256 WEEK_4_YEARS = _weekTsInXYears(4);
        ve.create_lock(10_000 ether, WEEK_4_YEARS);
        skip(2 * 1 weeks);
        currentTime += 2 * 1 weeks;
    }

    function _weekTsInXYears(uint256 _years) internal pure returns (uint256) {
        return (_years * ONE_YEAR) / 1 weeks * 1 weeks;
    }

    function _proposeVote(
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        string memory description
    ) internal returns (uint256) {
        return continuumDAO.propose(_targets, _values, _calldatas, description);
    }

    function _castVote(uint256 _proposalId, uint8 support) internal returns (uint256) {
        skip(5 days + 1);
        // skip(5 minutes + 1);
        uint256 weight = continuumDAO.castVote(_proposalId, support);
        return weight;
    }

    function _queueVote(
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        string memory description
    ) internal returns (uint256) {
        // skip(12 hours + 1);
        uint256 _proposalId = continuumDAO.queue(_targets, _values, _calldatas, keccak256(bytes(description)));
        return _proposalId;
    }

    function _executeVote(
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        string memory description
    ) internal returns (uint256) {
        skip(10 days + 1);
        uint256 _proposalId = continuumDAO.execute(_targets, _values, _calldatas, keccak256(bytes(description)));
        return _proposalId;
    }

    function test_InitialSettings() public prank(user1) {
        skip(1);
        uint256 votingDelay = continuumDAO.votingDelay();
        uint256 votingPeriod = continuumDAO.votingPeriod();
        uint256 proposalThreshold = continuumDAO.proposalThreshold();
        uint256 quorum = continuumDAO.quorumNumerator(block.timestamp);
        assertEq(votingDelay, 5 days);
        assertEq(votingPeriod, 10 days);
        assertEq(proposalThreshold, 1000 ether);
        assertEq(quorum, 20); // 20%
    }

    function test_VoteCallContractFunction() public prank(user1) {
        address[] memory _targets = new address[](1);
        _targets[0] = address(ve);
        uint256[] memory _values = new uint256[](1);
        bytes[] memory _calldatas = new bytes[](1);
        _calldatas[0] = abi.encodeWithSignature("setBaseURI(string)", "Updated URI veCTM");
        string memory _description = "Proposal #1: Set base URI in veCTM.";

        _proposeVote(_targets, _values, _calldatas, _description);

        (proposalId, targets, values, calldatas, descriptionHash) = continuumDAO.proposalDetailsAt(0);

        _castVote(proposalId, uint8(VoteType.For));

        _executeVote(_targets, _values, _calldatas, _description);

        string memory baseURI = ve.baseURI();
        assertEq(baseURI, "Updated URI veCTM");
    }

    function test_ProposalThresholdChanges() public prank(user1) {
        uint256 WEEK_4_YEARS = _weekTsInXYears(4);
        ve.create_lock(110_000 ether, WEEK_4_YEARS);
        skip(1);
        currentTime += 1;
        uint256 totalVotePowerBefore = ve.getPastTotalSupply(currentTime - 1);
        uint256 thresholdBefore = continuumDAO.proposalThreshold();

        skip(4 * 1 weeks);
        currentTime += 4 * 1 weeks;
        ve.checkpoint();
        skip(4 * 1 weeks);
        currentTime += 4 * 1 weeks;

        uint256 totalVotePowerAfter = ve.getPastTotalSupply(currentTime - 1);
        uint256 thresholdAfter = continuumDAO.proposalThreshold();
        assertEq(thresholdBefore, totalVotePowerBefore / 100);
        assertEq(thresholdAfter, totalVotePowerAfter / 100);
    }

    function test_VoteTransferETH() public prank(user1) {
        vm.deal(address(continuumDAO), 2000 ether);

        address[] memory _targets = new address[](1);
        _targets[0] = user2;
        uint256[] memory _values = new uint256[](1);
        _values[0] = 10 ether;
        bytes[] memory _calldatas = new bytes[](1);
        string memory _description = "Proposal #2: Transfer 10 ether to user2.";

        uint256 bal2Before = user2.balance;
        uint256 balGovBefore = address(continuumDAO).balance;

        _proposeVote(_targets, _values, _calldatas, _description);
        (proposalId, targets, values, calldatas, descriptionHash) = continuumDAO.proposalDetailsAt(0);
        _castVote(proposalId, uint8(VoteType.For));
        _executeVote(_targets, _values, _calldatas, _description);

        uint256 bal2After = user2.balance;
        uint256 balGovAfter = address(continuumDAO).balance;

        assertEq(bal2After, bal2Before + 10 ether);
        assertEq(balGovAfter, balGovBefore - 10 ether);
    }
}
