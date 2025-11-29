// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.27;

import {console} from "forge-std/console.sol";
import {GovernorHelpers} from "../helpers/GovernorHelpers.sol";
import {IVotingEscrow} from "../../src/token/IVotingEscrow.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {CallReceiverMock} from "../helpers/mocks/CallReceiverMock.sol";
import {GovernorCountingMultiple} from "../../src/governance/GovernorCountingMultiple.sol";

contract TestGovernorPreventLateQuorum is GovernorHelpers {
    uint48 votingDelay = 4;
    uint32 votingPeriod = 16;

    function setUp() public override {
        super.setUp();
        vm.startPrank(address(continuumDAO));
        continuumDAO.setProposalThreshold(1);
        continuumDAO.setVotingDelay(votingDelay);
        continuumDAO.setVotingPeriod(votingPeriod);
        continuumDAO.updateQuorumNumerator(5); // set quorum to 5% of total supply
        continuumDAO.updateSuperQuorumNumerator(10); // set super quorum to 10% of total supply
        continuumDAO.setLateQuorumVoteExtension(5);
        vm.stopPrank();
        _create_voting_locks();
        _advanceTime(1 weeks);
    }

    function _setProposal() internal returns (uint256) {
        Operation[] memory operations = new Operation[](1);
        operations[0].target = address(receiver);
        operations[0].val = 1 ether;
        operations[0].data = abi.encodeWithSelector(CallReceiverMock.mockFunction.selector);

        vm.prank(owner);
        payable(continuumDAO).transfer(1 ether);

        uint256 _proposalId = _propose(owner, operations, "<proposal description>");
        _waitForSnapshot(_proposalId);
        return _proposalId;
    }

    function test_PreventLateQuorum_LateQuorumExtension() public view {
        uint256 lateQuorumVoteExtension = continuumDAO.lateQuorumVoteExtension();
        assertEq(lateQuorumVoteExtension, 5);
    }

    function test_PreventLateQuorum_ProposalDeadlineLateQuorum() public {
        uint256 _proposalId = _setProposal();

        uint256 proposalDeadlineInitial = continuumDAO.proposalDeadline(_proposalId);

        // INFO: skip to 1 second after the 2 days window in which quorum being reached will bump the deadline
        vm.warp(proposalDeadlineInitial - (continuumDAO.lateQuorumVoteExtension() - 1));

        assertEq(uint8(IGovernor.ProposalState.Active), uint8(continuumDAO.state(_proposalId)));

        _castVote(_proposalId, proposer, GovernorCountingMultiple.VoteTypeSimple.For);
        uint256 proposalDeadlineExtended = continuumDAO.proposalDeadline(_proposalId);

        assertGt(proposalDeadlineExtended, proposalDeadlineInitial);
    }

    function test_PreventLateQuorum_SuperQuorumOverrulesLateQuorumExtension() public {
        uint256 _proposalId = _setProposal();
        uint256 proposalDeadlineInitial = continuumDAO.proposalDeadline(_proposalId);
        vm.warp(proposalDeadlineInitial - (continuumDAO.lateQuorumVoteExtension() - 1));

        // INFO: Late quorum extension is triggered; super quorum should still nullify deadline
        _castVote(_proposalId, proposer, GovernorCountingMultiple.VoteTypeSimple.For);

        assertEq(uint8(IGovernor.ProposalState.Active), uint8(continuumDAO.state(_proposalId)));

        // INFO: deadline should still be extended
        uint256 proposalDeadlineExtended = continuumDAO.proposalDeadline(_proposalId);
        assertGt(proposalDeadlineExtended, proposalDeadlineInitial);

        // INFO: invoke super quorum
        _castVote(_proposalId, owner, GovernorCountingMultiple.VoteTypeSimple.For);

        // INFO: proposal should now be accelerated to deadline
        assertEq(uint8(IGovernor.ProposalState.Succeeded), uint8(continuumDAO.state(_proposalId)));
    }

    function test_PreventLateQuorum_Delta() public {}
}
