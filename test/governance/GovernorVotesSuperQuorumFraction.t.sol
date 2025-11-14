// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {GovernorCountingMultiple} from "../../src/governance/GovernorCountingMultiple.sol";
import {GovernorHelpers} from "../helpers/GovernorHelpers.sol";
import {CallReceiverMock} from "../helpers/mocks/CallReceiverMock.sol";

contract TestGovernorVotesSuperQuorumFraction is GovernorHelpers {
    uint48 votingDelay = 4;
    uint32 votingPeriod = 16;

    function setUp() public override {
        super.setUp();
        vm.startPrank(address(continuumDAO));
        continuumDAO.setProposalThreshold(1);
        continuumDAO.setVotingDelay(votingDelay);
        continuumDAO.setVotingPeriod(votingPeriod);
        // continuumDAO.updateQuorumNumerator(20);
        vm.stopPrank();
        _create_voting_locks();
        _advanceTime(1 weeks);
    }

    function test_GovernorVotesSuperQuorumFraction_Quorums() public {
        Operation[] memory operations = new Operation[](1);
        operations[0].target = address(receiver);
        operations[0].val = 1 ether;
        operations[0].data = abi.encodeWithSelector(CallReceiverMock.mockFunction.selector);
        vm.prank(owner);
        payable(continuumDAO).transfer(1 ether);

        uint256 totalPower = ve.totalPower();
        _propose(proposer, operations, "<proposal description>");
        uint256 quorum = continuumDAO.quorum(block.timestamp - 1);
        uint256 superQuorum = continuumDAO.superQuorum(block.timestamp - 1);

        // INFO: Asserting with 0.1% wiggle room to account for voting escrow decay
        assertApproxEqRel(quorum, totalPower * 20 / 100, 0.001 ether);
        assertApproxEqRel(superQuorum, totalPower * 80 / 100, 0.001 ether);
    }

    function test_GovernorVotesSuperQuorumFraction_MultipleOptionQuorum() public {
        vm.prank(address(continuumDAO));
        continuumDAO.updateQuorumNumerator(7); // set quorum to 7% so that proposer can hit quorum with 1.5m votes

        bytes memory metadata = _buildMetadata(2, 1, 1);
        Operation[] memory allOperations = _generateOptions(metadata);

        uint256 _proposalId = _propose(proposer, allOperations, "<proposal description>");
        _waitForSnapshot(_proposalId);
        bytes memory params = _encodeSingleVote(2, 0);

        assertEq(uint8(continuumDAO.state(_proposalId)), uint8(IGovernor.ProposalState.Active));

        _castVoteWithReasonAndParams(_proposalId, proposer, GovernorCountingMultiple.VoteTypeSimple.For, "op1", params);

        // INFO: at this point, the quorum should be reached
        assertEq(uint8(continuumDAO.state(_proposalId)), uint8(IGovernor.ProposalState.Active));

        _waitForDeadline(_proposalId);

        assertEq(uint8(continuumDAO.state(_proposalId)), uint8(IGovernor.ProposalState.Succeeded));
    }

    function test_GovernorVotesSuperQuorumFraction_MultipleOptionSuperQuorum() public {
        bytes memory metadata = _buildMetadata(2, 1, 1);
        Operation[] memory allOperations = _generateOptions(metadata);

        uint256 _proposalId = _propose(proposer, allOperations, "<proposal description>");
        _waitForSnapshot(_proposalId);
        bytes memory params = _encodeSingleVote(2, 0);

        assertEq(uint8(continuumDAO.state(_proposalId)), uint8(IGovernor.ProposalState.Active));

        _castVoteWithReasonAndParams(_proposalId, owner, GovernorCountingMultiple.VoteTypeSimple.For, "op1", params);

        // INFO: at this point, the super quorum should be reached
        assertEq(uint8(continuumDAO.state(_proposalId)), uint8(IGovernor.ProposalState.Succeeded));

        // assertEq(uint8(continuumDAO.state(_proposalId)), uint8(IGovernor.ProposalState.Active));

        // _waitForDeadline(_proposalId);
    }

    // function test_GovernorVotesSuperQuorumFraction_() public {}

    // function test_GovernorVotesSuperQuorumFraction_() public {}

    // function test_GovernorVotesSuperQuorumFraction_() public {}

    // function test_GovernorVotesSuperQuorumFraction_() public {}

    // function test_GovernorVotesSuperQuorumFraction_() public {}
}
