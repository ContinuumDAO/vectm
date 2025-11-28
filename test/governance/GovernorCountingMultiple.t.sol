// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

import {console} from "forge-std/console.sol";
import {GovernorHelpers} from "../helpers/GovernorHelpers.sol";
import {IVotingEscrow} from "../../src/token/IVotingEscrow.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {CallReceiverMock} from "../helpers/mocks/CallReceiverMock.sol";
import {
    GovernorDeltaInvalidVoteParams,
    GovernorDeltaInvalidProposal,
    GovernorNonIncrementingOptionIndices
} from "../../src/governance/GovernorCountingMultiple.sol";

contract TestGovernorCountingMultiple is GovernorHelpers {
    uint48 votingDelay = 4;
    uint32 votingPeriod = 16;

    function setUp() public override {
        super.setUp();
        vm.startPrank(address(continuumDAO));
        continuumDAO.setProposalThreshold(1);
        continuumDAO.setVotingDelay(votingDelay);
        continuumDAO.setVotingPeriod(votingPeriod);
        continuumDAO.updateQuorumNumerator(0);
        vm.stopPrank();
        _create_voting_locks();
        _advanceTime(1 weeks);
    }

    function test_DeploymentCheck() public view {
        assertEq(continuumDAO.COUNTING_MODE(), "support=bravo&quorum=for,abstain;support=delta&quorum=for");
    }

    function test_NominalIsUnaffected() public {
        Operation[] memory allOperations = new Operation[](1);
        allOperations[0] =
            Operation(address(receiver), 1 ether, abi.encodeWithSelector(CallReceiverMock.mockFunction.selector));

        vm.prank(owner);
        payable(continuumDAO).transfer(1 ether);

        uint256 _proposalId = _propose(proposer, allOperations, "<proposal description>");

        _waitForSnapshot(_proposalId);

        assertEq(uint8(continuumDAO.state(_proposalId)), uint8(IGovernor.ProposalState.Active));

        _castVoteWithReason(_proposalId, voter1, FOR, "This is nice");
        _castVote(_proposalId, voter2, FOR);
        _castVote(_proposalId, voter3, AGAINST);
        _castVote(_proposalId, voter4, ABSTAIN);

        _waitForDeadline(_proposalId);

        assertEq(uint8(continuumDAO.state(_proposalId)), uint8(IGovernor.ProposalState.Succeeded));

        vm.expectEmit(false, false, false, false);
        emit CallReceiverMock.MockFunctionCalled();
        _execute(proposer, allOperations, "<proposal description>");

        assertEq(continuumDAO.hasVoted(_proposalId, owner), false);
        assertEq(continuumDAO.hasVoted(_proposalId, voter1), true);
        assertEq(continuumDAO.hasVoted(_proposalId, voter2), true);
        assertEq(address(receiver).balance, 1 ether);
    }

    // ===========================================================
    // ======== MULTI-OPTION PROPOSING: SINGLE-OPERATION =========
    // ===========================================================

    function test_4Options1Winner_Propose() public {
        uint256 nOptions = 4;
        uint256 nWinners = 1;
        uint256 nOperations = 1;

        bytes memory metadata = _buildMetadata(nOptions, nWinners, nOperations);
        Operation[] memory allOperations = _generateOptions(metadata);

        uint256 _proposalId = _propose(proposer, allOperations, "<proposal description>");

        (uint256 nOptionsSet, uint256 nWinnersSet) = _getProposalConfiguration(_proposalId);
        assertEq(nOptionsSet, nOptions);
        assertEq(nWinnersSet, nWinners);
    }

    function test_4Options1Winner_VoteAllTypes() public {
        uint256 nOptions = 4;
        uint256 nWinners = 1;
        uint256 nOperations = 1;
        _proposeDelta(nOptions, nWinners, nOperations, "<proposal description>");

        // all voting power towards option 3
        bytes memory paramsSingle = _encodeSingleVote(nOptions, 2);
        // INFO: output:
        // 0: 0000000000000000000000000000000000000000000000000000000000000000
        // 1: 0000000000000000000000000000000000000000000000000000000000000000
        // 2: 0000000000000000000000000000000000000000000000000000000000000064
        // 3: 0000000000000000000000000000000000000000000000000000000000000000
        // for voter1, this should equal 10 CTM of voting power to option 3

        // even voting power towards each option
        bytes memory paramsApproval = _encodeApprovalVote(nOptions);
        // INFO: output:
        // 0: 0000000000000000000000000000000000000000000000000000000000000064
        // 1: 0000000000000000000000000000000000000000000000000000000000000064
        // 2: 0000000000000000000000000000000000000000000000000000000000000064
        // 3: 0000000000000000000000000000000000000000000000000000000000000064
        // for voter2, this should equal 7/4 = 1.75 CTM of voting power to each option

        uint256[] memory weights = new uint256[](4);
        weights[0] = 50;
        weights[2] = 50;
        // 50% voting power each towards options 1 & 3
        bytes memory paramsWeighted = _encodeWeightedVote(nOptions, weights);
        // INFO: output:
        // 0: 0000000000000000000000000000000000000000000000000000000000000032
        // 1: 0000000000000000000000000000000000000000000000000000000000000000
        // 2: 0000000000000000000000000000000000000000000000000000000000000032
        // 3: 0000000000000000000000000000000000000000000000000000000000000000
        // for voter3, this should equal 5/2 = 2.5 CTM each to option 1 and option 3

        _castVoteWithReasonAndParams(proposalIdDelta, voter1, AGAINST, "I like the this option", paramsSingle);
        _castVoteWithReasonAndParams(
            proposalIdDelta, voter2, AGAINST, "I want to distribute votes among all options", paramsApproval
        );
        _castVoteWithReasonAndParams(proposalIdDelta, voter3, AGAINST, "I like these options only", paramsWeighted);

        (uint256[] memory optionVotes, uint256 totalVotes) = _getProposalVotesDelta(proposalIdDelta);

        assertApproxEqRel(totalVotes, 22 ether, 0.1 ether);
        // PASSED: 4.25 + 1.75 + 14.25 + 1.75 = 22.0 CTM

        assertApproxEqRel(optionVotes[0], 4.25 ether, 0.1 ether); // 1.75 + 2.5 = 4.25
        assertApproxEqRel(optionVotes[1], 1.75 ether, 0.1 ether); // 1.75
        assertApproxEqRel(optionVotes[2], 14.25 ether, 0.1 ether); // 10 + 1.75 + 2.5 = 14.25 winner
        assertApproxEqRel(optionVotes[3], 1.75 ether, 0.1 ether); // 1.75
    }

    function test_4Options1Winner_ExecuteWinner() public {
        uint256 nOptions = 4;
        uint256 nWinners = 1;
        uint256 nOperations = 1;

        uint256 supportSingle = 2;
        uint256[] memory weights = new uint256[](4);
        weights[0] = 50;
        weights[2] = 50;
        _proposeDelta(nOptions, nWinners, nOperations, "<proposal description>");
        _castVoteDelta(supportSingle, weights);
        vm.expectEmit(false, false, false, true);
        emit CallReceiverMock.MockFunctionCalledWithArgs(3, 1); // 3rd option, 1st operation
        _executeDelta();
    }

    function test_4Options1Winner_ExecuteById() public {
        uint256 nOptions = 4;
        uint256 nWinners = 1;
        uint256 nOperations = 1;

        uint256 supportSingle = 2;
        uint256[] memory weights = new uint256[](4);
        weights[0] = 50;
        weights[2] = 50;
        _proposeDelta(nOptions, nWinners, nOperations, "<proposal description>");
        _castVoteDelta(supportSingle, weights);
        vm.expectEmit(false, false, false, true);
        emit CallReceiverMock.MockFunctionCalledWithArgs(3, 1); // 3rd option, 1st operation
        _executeById(owner, proposalIdDelta);
    }

    function test_8Options2Winners_Propose() public {
        uint256 nOptions = 8;
        uint256 nWinners = 2;
        uint256 nOperations = 1;

        bytes memory metadata = _buildMetadata(nOptions, nWinners, nOperations);
        Operation[] memory allOperations = _generateOptions(metadata);

        uint256 _proposalId = _propose(proposer, allOperations, "<proposal description>");

        (uint256 nOptionsSet, uint256 nWinnersSet) = _getProposalConfiguration(_proposalId);
        assertEq(nOptionsSet, nOptions);
        assertEq(nWinnersSet, nWinners);
    }

    function test_8Options2Winners_VoteAllTypes() public {
        uint256 nOptions = 8;
        uint256 nWinners = 2;
        uint256 nOperations = 1;
        _proposeDelta(nOptions, nWinners, nOperations, "<proposal description>");

        // all voting power towards option 5
        bytes memory paramsSingle = _encodeSingleVote(nOptions, 4);
        // INFO: output:
        // 0: 0000000000000000000000000000000000000000000000000000000000000000
        // 1: 0000000000000000000000000000000000000000000000000000000000000000
        // 2: 0000000000000000000000000000000000000000000000000000000000000000
        // 3: 0000000000000000000000000000000000000000000000000000000000000000
        // 4: 0000000000000000000000000000000000000000000000000000000000000064
        // 5: 0000000000000000000000000000000000000000000000000000000000000000
        // 6: 0000000000000000000000000000000000000000000000000000000000000000
        // 7: 0000000000000000000000000000000000000000000000000000000000000000
        // for voter1, this should equal 10 CTM of voting power to option 5

        // even voting power towards each option
        bytes memory paramsApproval = _encodeApprovalVote(nOptions);
        // INFO: output:
        // 0: 0000000000000000000000000000000000000000000000000000000000000064
        // 1: 0000000000000000000000000000000000000000000000000000000000000064
        // 2: 0000000000000000000000000000000000000000000000000000000000000064
        // 3: 0000000000000000000000000000000000000000000000000000000000000064
        // 4: 0000000000000000000000000000000000000000000000000000000000000064
        // 5: 0000000000000000000000000000000000000000000000000000000000000064
        // 6: 0000000000000000000000000000000000000000000000000000000000000064
        // 7: 0000000000000000000000000000000000000000000000000000000000000064
        // for voter2, this should equal 7/8 = 0.875 CTM of voting power to each option

        uint256[] memory weights = new uint256[](8);
        weights[0] = 25;
        weights[2] = 25;
        weights[4] = 25;
        weights[6] = 25;
        // 25% voting power each towards options 1, 3, 5, 7
        bytes memory paramsWeighted = _encodeWeightedVote(nOptions, weights);
        // INFO: output:
        // 0: 0000000000000000000000000000000000000000000000000000000000000032
        // 1: 0000000000000000000000000000000000000000000000000000000000000000
        // 2: 0000000000000000000000000000000000000000000000000000000000000032
        // 3: 0000000000000000000000000000000000000000000000000000000000000000
        // 4: 0000000000000000000000000000000000000000000000000000000000000032
        // 5: 0000000000000000000000000000000000000000000000000000000000000000
        // 6: 0000000000000000000000000000000000000000000000000000000000000032
        // 7: 0000000000000000000000000000000000000000000000000000000000000000
        // for voter3, this should equal 5/4 = 1.25 CTM each to options 1, 3, 5, 7

        _castVoteWithReasonAndParams(proposalIdDelta, voter1, AGAINST, "I like the this option", paramsSingle);
        _castVoteWithReasonAndParams(
            proposalIdDelta, voter2, AGAINST, "I want to distribute votes among all options", paramsApproval
        );
        _castVoteWithReasonAndParams(proposalIdDelta, voter3, AGAINST, "I like these options only", paramsWeighted);

        (uint256[] memory optionVotes, uint256 totalVotes) = _getProposalVotesDelta(proposalIdDelta);

        assertApproxEqRel(totalVotes, 22 ether, 0.1 ether);
        // PASSED: 2.125 + 0.875 + 2.125 + 0.875 + 12.125 + 0.875 + 2.125 + 0.875  = 22.0 CTM

        assertApproxEqRel(optionVotes[0], 2.125 ether, 0.1 ether); // 0.875 + 1.25 = 2.125 winner2
        assertApproxEqRel(optionVotes[1], 0.875 ether, 0.1 ether); // 0.875
        assertApproxEqRel(optionVotes[2], 2.125 ether, 0.1 ether); // 0.875 + 1.25 = 2.125
        assertApproxEqRel(optionVotes[3], 0.875 ether, 0.1 ether); // 0.875
        assertApproxEqRel(optionVotes[4], 12.125 ether, 0.1 ether); // 10 + 0.875 + 1.25 = 12.125 winner1
        assertApproxEqRel(optionVotes[5], 0.875 ether, 0.1 ether); // 0.875
        assertApproxEqRel(optionVotes[6], 2.125 ether, 0.1 ether); // 0.875 + 1.25 = 2.125
        assertApproxEqRel(optionVotes[7], 0.875 ether, 0.1 ether); // 0.875
    }

    function test_8Options2Winners_ExecuteWinner() public {
        uint256 nOptions = 8;
        uint256 nWinners = 2;
        uint256 nOperations = 1;

        uint256 supportSingle = 4;
        uint256[] memory weights = new uint256[](8);
        weights[0] = 25;
        weights[2] = 25;
        weights[4] = 25;
        weights[6] = 25;
        _proposeDelta(nOptions, nWinners, nOperations, "<proposal description>");
        _castVoteDelta(supportSingle, weights);
        vm.expectEmit(false, false, false, true);
        emit CallReceiverMock.MockFunctionCalledWithArgs(5, 1); // 5th option, 1st operation
        vm.expectEmit(false, false, false, true);
        emit CallReceiverMock.MockFunctionCalledWithArgs(1, 1); // 1st option, 1st operation
        _executeDelta();
    }

    function test_16Options4Winners_Propose() public {
        uint256 nOptions = 16;
        uint256 nWinners = 4;
        uint256 nOperations = 1;

        bytes memory metadata = _buildMetadata(nOptions, nWinners, nOperations);
        Operation[] memory allOperations = _generateOptions(metadata);

        uint256 _proposalId = _propose(proposer, allOperations, "<proposal description>");

        (uint256 nOptionsSet, uint256 nWinnersSet) = _getProposalConfiguration(_proposalId);
        assertEq(nOptionsSet, nOptions);
        assertEq(nWinnersSet, nWinners);
    }

    function test_16Options4Winners_VoteAllTypes() public {
        uint256 nOptions = 16;
        uint256 nWinners = 4;
        uint256 nOperations = 1;

        _proposeDelta(nOptions, nWinners, nOperations, "<proposal description>");

        // all voting power towards option 12
        bytes memory paramsSingle = _encodeSingleVote(nOptions, 11);
        // INFO: output:
        //  0: 0000000000000000000000000000000000000000000000000000000000000000
        //  1: 0000000000000000000000000000000000000000000000000000000000000000
        //  2: 0000000000000000000000000000000000000000000000000000000000000000
        //  3: 0000000000000000000000000000000000000000000000000000000000000000
        //  4: 0000000000000000000000000000000000000000000000000000000000000000
        //  5: 0000000000000000000000000000000000000000000000000000000000000000
        //  6: 0000000000000000000000000000000000000000000000000000000000000000
        //  7: 0000000000000000000000000000000000000000000000000000000000000000
        //  8: 0000000000000000000000000000000000000000000000000000000000000000
        //  9: 0000000000000000000000000000000000000000000000000000000000000000
        // 10: 0000000000000000000000000000000000000000000000000000000000000000
        // 11: 0000000000000000000000000000000000000000000000000000000000000064
        // 12: 0000000000000000000000000000000000000000000000000000000000000000
        // 13: 0000000000000000000000000000000000000000000000000000000000000000
        // 14: 0000000000000000000000000000000000000000000000000000000000000000
        // 15: 0000000000000000000000000000000000000000000000000000000000000000
        // for voter1, this should equal 10 CTM of voting power to option 12

        // voting power distributed evenly towards each option
        bytes memory paramsApproval = _encodeApprovalVote(nOptions);
        //  INFO: output:
        //  0: 0000000000000000000000000000000000000000000000000000000000000064
        //  1: 0000000000000000000000000000000000000000000000000000000000000064
        //  2: 0000000000000000000000000000000000000000000000000000000000000064
        //  3: 0000000000000000000000000000000000000000000000000000000000000064
        //  4: 0000000000000000000000000000000000000000000000000000000000000064
        //  5: 0000000000000000000000000000000000000000000000000000000000000064
        //  6: 0000000000000000000000000000000000000000000000000000000000000064
        //  7: 0000000000000000000000000000000000000000000000000000000000000064
        //  8: 0000000000000000000000000000000000000000000000000000000000000064
        //  9: 0000000000000000000000000000000000000000000000000000000000000064
        // 10: 0000000000000000000000000000000000000000000000000000000000000064
        // 11: 0000000000000000000000000000000000000000000000000000000000000064
        // 12: 0000000000000000000000000000000000000000000000000000000000000064
        // 13: 0000000000000000000000000000000000000000000000000000000000000064
        // 14: 0000000000000000000000000000000000000000000000000000000000000064
        // 15: 0000000000000000000000000000000000000000000000000000000000000064
        // for voter2, this should equal 7/16 = 0.4375 CTM of voting power to each option

        // 12.5% voting power each towards options 1, 3, 5, 7, 9, 11, 13, 15
        uint256[] memory weights = new uint256[](16);
        weights[0] = 125000;
        weights[2] = 125000;
        weights[4] = 125000;
        weights[6] = 125000;
        weights[8] = 125000;
        weights[10] = 125000;
        weights[12] = 125000;
        weights[14] = 125000;
        bytes memory paramsWeighted = _encodeWeightedVote(nOptions, weights);
        // INFO: output:
        //  0: 000000000000000000000000000000000000000000000000000000000000007d
        //  1: 0000000000000000000000000000000000000000000000000000000000000000
        //  2: 000000000000000000000000000000000000000000000000000000000000007d
        //  3: 0000000000000000000000000000000000000000000000000000000000000000
        //  4: 000000000000000000000000000000000000000000000000000000000000007d
        //  5: 0000000000000000000000000000000000000000000000000000000000000000
        //  6: 000000000000000000000000000000000000000000000000000000000000007d
        //  7: 0000000000000000000000000000000000000000000000000000000000000000
        //  8: 000000000000000000000000000000000000000000000000000000000000007d
        //  9: 0000000000000000000000000000000000000000000000000000000000000000
        // 10: 000000000000000000000000000000000000000000000000000000000000007d
        // 11: 0000000000000000000000000000000000000000000000000000000000000000
        // 12: 000000000000000000000000000000000000000000000000000000000000007d
        // 13: 0000000000000000000000000000000000000000000000000000000000000000
        // 14: 000000000000000000000000000000000000000000000000000000000000007d
        // 15: 0000000000000000000000000000000000000000000000000000000000000000
        // for voter3, this should equal 5/8 = 0.625 CTM each to options 1, 3, 5, 7, 9, 11, 13, 15

        _castVoteWithReasonAndParams(proposalIdDelta, voter1, AGAINST, "I like the this option", paramsSingle);
        _castVoteWithReasonAndParams(
            proposalIdDelta, voter2, AGAINST, "I want to distribute votes among all options", paramsApproval
        );
        _castVoteWithReasonAndParams(proposalIdDelta, voter3, AGAINST, "I like these options only", paramsWeighted);

        (uint256[] memory optionVotes, uint256 totalVotes) = _getProposalVotesDelta(proposalIdDelta);

        assertApproxEqRel(totalVotes, 22 ether, 0.1 ether);
        // PASSED:
        //   (1.0625) + (0.4375) + (1.0625) + (0.4375)
        // + (1.0625) + (0.4375) + (1.0625) + (0.4375)
        // + (1.0625) + (0.4375) + (1.0625) + (10.4375)
        // + (1.0625) + (0.4375) + (1.0625) + (0.4375) = 22.0 CTM

        assertApproxEqRel(optionVotes[0], 1.0625 ether, 0.1 ether); // 0.4375 + 0.625 = 1.0625  winner2
        assertApproxEqRel(optionVotes[1], 0.4375 ether, 0.1 ether); // 0.4375
        assertApproxEqRel(optionVotes[2], 1.0625 ether, 0.1 ether); // 0.4375 + 0.625 = 1.0625  winner3
        assertApproxEqRel(optionVotes[3], 0.4375 ether, 0.1 ether); // 0.4375
        assertApproxEqRel(optionVotes[4], 1.0625 ether, 0.1 ether); // 0.4375 + 0.625 = 1.0625  winner4
        assertApproxEqRel(optionVotes[5], 0.4375 ether, 0.1 ether); // 0.4375
        assertApproxEqRel(optionVotes[6], 1.0625 ether, 0.1 ether); // 0.4375 + 0.625 = 1.0625
        assertApproxEqRel(optionVotes[7], 0.4375 ether, 0.1 ether); // 0.4375
        assertApproxEqRel(optionVotes[8], 1.0625 ether, 0.1 ether); // 0.4375 + 0.625 = 1.0625
        assertApproxEqRel(optionVotes[9], 0.4375 ether, 0.1 ether); // 0.4375
        assertApproxEqRel(optionVotes[10], 1.0625 ether, 0.1 ether); // 0.4375 + 0.625 = 1.0625
        assertApproxEqRel(optionVotes[11], 10.4375 ether, 0.1 ether); // 10 + 0.4375 = 10.4375    winner1
        assertApproxEqRel(optionVotes[12], 1.0625 ether, 0.1 ether); // 0.4375 + 0.625 = 1.0625
        assertApproxEqRel(optionVotes[13], 0.4375 ether, 0.1 ether); // 0.4375
        assertApproxEqRel(optionVotes[14], 1.0625 ether, 0.1 ether); // 0.4375 + 0.625 = 1.0625
        assertApproxEqRel(optionVotes[15], 0.4375 ether, 0.1 ether); // 0.4375
    }

    function test_16Options4Winners_ExecuteWinner() public {
        uint256 nOptions = 16;
        uint256 nWinners = 4;
        uint256 nOperations = 1;

        uint256 supportSingle = 11;
        uint256[] memory weights = new uint256[](16);
        weights[0] = 125000;
        weights[2] = 125000;
        weights[4] = 125000;
        weights[6] = 125000;
        weights[8] = 125000;
        weights[10] = 125000;
        weights[12] = 125000;
        weights[14] = 125000;
        _proposeDelta(nOptions, nWinners, nOperations, "<proposal description>");
        _castVoteDelta(supportSingle, weights);

        vm.expectEmit(false, false, false, true);
        emit CallReceiverMock.MockFunctionCalledWithArgs(12, 1); // 12th option, 1st operation
        vm.expectEmit(false, false, false, true);
        emit CallReceiverMock.MockFunctionCalledWithArgs(1, 1); // 1st option, 1st operation
        vm.expectEmit(false, false, false, true);
        emit CallReceiverMock.MockFunctionCalledWithArgs(3, 1); // 3rd option, 1st operation
        vm.expectEmit(false, false, false, true);
        emit CallReceiverMock.MockFunctionCalledWithArgs(5, 1); // 5th option, 1st operation

        _executeDelta();
    }

    // ============================================================
    // ======== MULTI-OPTION PROPOSING: MULTIPLE-OPERATION ========
    // ============================================================

    function test_2Options1Winner2Operations_Propose() public {
        uint256 nOptions = 2;
        uint256 nWinners = 1;
        uint256 nOperations = 2;

        bytes memory metadata = _buildMetadata(nOptions, nWinners, nOperations);
        Operation[] memory allOperations = _generateOptions(metadata);

        uint256 _proposalId = _propose(proposer, allOperations, "<proposal description>");

        (uint256 nOptionsSet, uint256 nWinnersSet) = _getProposalConfiguration(_proposalId);
        assertEq(nOptionsSet, nOptions);
        assertEq(nWinnersSet, nWinners);
    }

    function test_2Options1Winner2Operations_VoteAllTypes() public {
        uint256 nOptions = 2;
        uint256 nWinners = 1;
        uint256 nOperations = 2;
        _proposeDelta(nOptions, nWinners, nOperations, "<proposal description>");

        // all voting power towards option 2
        bytes memory paramsSingle = _encodeSingleVote(nOptions, 1);
        // INFO: output:
        // 0: 0000000000000000000000000000000000000000000000000000000000000000
        // 1: 0000000000000000000000000000000000000000000000000000000000000064
        // for voter1, this should equal 10 CTM of voting power to option 2

        // even voting power towards each option
        bytes memory paramsApproval = _encodeApprovalVote(nOptions);
        // INFO: output:
        // 0: 0000000000000000000000000000000000000000000000000000000000000064
        // 1: 0000000000000000000000000000000000000000000000000000000000000064
        // for voter2, this should equal 7/2 = 3.5 CTM of voting power to each option

        // 25% voting power towards option 1, 75% voting power towards option 2
        uint256[] memory weights = new uint256[](2);
        weights[0] = 25;
        weights[1] = 75;
        bytes memory paramsWeighted = _encodeWeightedVote(nOptions, weights);
        // INFO: output:
        // 0: 0000000000000000000000000000000000000000000000000000000000000019
        // 1: 000000000000000000000000000000000000000000000000000000000000004b
        // for voter3, this should equal 5/4 = 1.25 CTM to option 1, 5*3/4 = 3.75 CTM to option 2

        _castVoteWithReasonAndParams(proposalIdDelta, voter1, AGAINST, "I like the this option", paramsSingle);
        _castVoteWithReasonAndParams(
            proposalIdDelta, voter2, AGAINST, "I want to distribute votes among all options", paramsApproval
        );
        _castVoteWithReasonAndParams(proposalIdDelta, voter3, AGAINST, "I like these options only", paramsWeighted);

        (uint256[] memory optionVotes, uint256 totalVotes) = _getProposalVotesDelta(proposalIdDelta);

        assertApproxEqRel(totalVotes, 22 ether, 0.1 ether);
        // PASSED: 4.75 + 17.25 = 22.0 CTM

        assertApproxEqRel(optionVotes[0], 4.75 ether, 0.1 ether); // 3.5 + 1.25 = 4.75
        assertApproxEqRel(optionVotes[1], 17.25 ether, 0.1 ether); // 10 + 3.5 + 3.75 = 17.25 winner
    }

    function test_2Options1Winner2Operations_ExecuteWinner() public {
        uint256 nOptions = 2;
        uint256 nWinners = 1;
        uint256 nOperations = 2;

        uint256 supportSingle = 1;
        uint256[] memory weights = new uint256[](2);
        weights[0] = 25;
        weights[1] = 75;
        _proposeDelta(nOptions, nWinners, nOperations, "<proposal description>");
        _castVoteDelta(supportSingle, weights);
        vm.expectEmit(false, false, false, true);
        emit CallReceiverMock.MockFunctionCalledWithArgs(2, 1); // 2nd option, 1st operation
        vm.expectEmit(false, false, false, true);
        emit CallReceiverMock.MockFunctionCalledWithArgs(2, 2); // 2nd option, 2nd operation
        _executeDelta();
    }

    function test_16Options8Winners4Operations_Propose() public {
        uint256 nOptions = 16;
        uint256 nWinners = 8;
        uint256 nOperations = 4;

        bytes memory metadata = _buildMetadata(nOptions, nWinners, nOperations);
        Operation[] memory allOperations = _generateOptions(metadata);

        uint256 _proposalId = _propose(proposer, allOperations, "<proposal description>");

        (uint256 nOptionsSet, uint256 nWinnersSet) = _getProposalConfiguration(_proposalId);
        assertEq(nOptionsSet, nOptions);
        assertEq(nWinnersSet, nWinners);
    }

    function test_16Options8Winners4Operations_VoteAllTypes() public {
        uint256 nOptions = 16;
        uint256 nWinners = 8;
        uint256 nOperations = 4;

        _proposeDelta(nOptions, nWinners, nOperations, "<proposal description>");

        // all voting power towards option 12
        bytes memory paramsSingle = _encodeSingleVote(nOptions, 11);
        // INFO: output:
        //  1: 0000000000000000000000000000000000000000000000000000000000000000
        //  2: 0000000000000000000000000000000000000000000000000000000000000000
        //  3: 0000000000000000000000000000000000000000000000000000000000000000
        //  4: 0000000000000000000000000000000000000000000000000000000000000000
        //  5: 0000000000000000000000000000000000000000000000000000000000000000
        //  6: 0000000000000000000000000000000000000000000000000000000000000000
        //  7: 0000000000000000000000000000000000000000000000000000000000000000
        //  8: 0000000000000000000000000000000000000000000000000000000000000000
        //  9: 0000000000000000000000000000000000000000000000000000000000000000
        // 10: 0000000000000000000000000000000000000000000000000000000000000000
        // 11: 0000000000000000000000000000000000000000000000000000000000000000
        // 12: 0000000000000000000000000000000000000000000000000000000000000064
        // 13: 0000000000000000000000000000000000000000000000000000000000000000
        // 14: 0000000000000000000000000000000000000000000000000000000000000000
        // 15: 0000000000000000000000000000000000000000000000000000000000000000
        // 16: 0000000000000000000000000000000000000000000000000000000000000000
        // for voter1, this should equal 10 CTM of voting power to option 12

        // voting power distributed evenly towards each option
        bytes memory paramsApproval = _encodeApprovalVote(nOptions);
        //  INFO: output:
        //  1: 0000000000000000000000000000000000000000000000000000000000000064
        //  2: 0000000000000000000000000000000000000000000000000000000000000064
        //  3: 0000000000000000000000000000000000000000000000000000000000000064
        //  4: 0000000000000000000000000000000000000000000000000000000000000064
        //  5: 0000000000000000000000000000000000000000000000000000000000000064
        //  6: 0000000000000000000000000000000000000000000000000000000000000064
        //  7: 0000000000000000000000000000000000000000000000000000000000000064
        //  8: 0000000000000000000000000000000000000000000000000000000000000064
        //  9: 0000000000000000000000000000000000000000000000000000000000000064
        // 10: 0000000000000000000000000000000000000000000000000000000000000064
        // 11: 0000000000000000000000000000000000000000000000000000000000000064
        // 12: 0000000000000000000000000000000000000000000000000000000000000064
        // 13: 0000000000000000000000000000000000000000000000000000000000000064
        // 14: 0000000000000000000000000000000000000000000000000000000000000064
        // 15: 0000000000000000000000000000000000000000000000000000000000000064
        // 16: 0000000000000000000000000000000000000000000000000000000000000064
        // for voter2, this should equal 7/16 = 0.4375 CTM of voting power to each option

        // 12.5% voting power each towards options 1, 3, 5, 7, 9, 11, 13, 15
        uint256[] memory weights = new uint256[](16);
        weights[0] = 125;
        weights[2] = 125;
        weights[4] = 125;
        weights[6] = 125;
        weights[8] = 125;
        weights[10] = 125;
        weights[12] = 125;
        weights[14] = 125;
        bytes memory paramsWeighted = _encodeWeightedVote(nOptions, weights);
        // INFO: output:
        //  1: 000000000000000000000000000000000000000000000000000000000000007d
        //  2: 0000000000000000000000000000000000000000000000000000000000000000
        //  3: 000000000000000000000000000000000000000000000000000000000000007d
        //  4: 0000000000000000000000000000000000000000000000000000000000000000
        //  5: 000000000000000000000000000000000000000000000000000000000000007d
        //  6: 0000000000000000000000000000000000000000000000000000000000000000
        //  7: 000000000000000000000000000000000000000000000000000000000000007d
        //  8: 0000000000000000000000000000000000000000000000000000000000000000
        //  9: 000000000000000000000000000000000000000000000000000000000000007d
        // 10: 0000000000000000000000000000000000000000000000000000000000000000
        // 11: 000000000000000000000000000000000000000000000000000000000000007d
        // 12: 0000000000000000000000000000000000000000000000000000000000000000
        // 13: 000000000000000000000000000000000000000000000000000000000000007d
        // 14: 0000000000000000000000000000000000000000000000000000000000000000
        // 15: 000000000000000000000000000000000000000000000000000000000000007d
        // 16: 0000000000000000000000000000000000000000000000000000000000000000
        // for voter3, this should equal 5/8 = 0.625 CTM each to options 1, 3, 5, 7, 9, 11, 13, 15

        _castVoteWithReasonAndParams(proposalIdDelta, voter1, AGAINST, "I like the this option", paramsSingle);
        _castVoteWithReasonAndParams(
            proposalIdDelta, voter2, AGAINST, "I want to distribute votes among all options", paramsApproval
        );
        _castVoteWithReasonAndParams(proposalIdDelta, voter3, AGAINST, "I like these options only", paramsWeighted);

        (uint256[] memory optionVotes, uint256 totalVotes) = _getProposalVotesDelta(proposalIdDelta);

        assertApproxEqRel(totalVotes, 22 ether, 0.1 ether);
        /* PASSED:
         *   (1.0625) + (0.4375) + (1.0625) + (0.4375)
         * + (1.0625) + (0.4375) + (1.0625) + (0.4375)
         * + (1.0625) + (0.4375) + (1.0625) + (10.4375)
         * + (1.0625) + (0.4375) + (1.0625) + (0.4375) = 22.0 CTM
         */

        assertApproxEqRel(optionVotes[0], 1.0625 ether, 0.1 ether); // 0.4375 + 0.625 = 1.0625  winner2
        assertApproxEqRel(optionVotes[1], 0.4375 ether, 0.1 ether); // 0.4375
        assertApproxEqRel(optionVotes[2], 1.0625 ether, 0.1 ether); // 0.4375 + 0.625 = 1.0625  winner3
        assertApproxEqRel(optionVotes[3], 0.4375 ether, 0.1 ether); // 0.4375
        assertApproxEqRel(optionVotes[4], 1.0625 ether, 0.1 ether); // 0.4375 + 0.625 = 1.0625  winner4
        assertApproxEqRel(optionVotes[5], 0.4375 ether, 0.1 ether); // 0.4375
        assertApproxEqRel(optionVotes[6], 1.0625 ether, 0.1 ether); // 0.4375 + 0.625 = 1.0625  winner5
        assertApproxEqRel(optionVotes[7], 0.4375 ether, 0.1 ether); // 0.4375
        assertApproxEqRel(optionVotes[8], 1.0625 ether, 0.1 ether); // 0.4375 + 0.625 = 1.0625  winner6
        assertApproxEqRel(optionVotes[9], 0.4375 ether, 0.1 ether); // 0.4375
        assertApproxEqRel(optionVotes[10], 1.0625 ether, 0.1 ether); // 0.4375 + 0.625 = 1.0625  winner7
        assertApproxEqRel(optionVotes[11], 10.4375 ether, 0.1 ether); // 10 + 0.4375 = 10.4375    winner1
        assertApproxEqRel(optionVotes[12], 1.0625 ether, 0.1 ether); // 0.4375 + 0.625 = 1.0625  winner8
        assertApproxEqRel(optionVotes[13], 0.4375 ether, 0.1 ether); // 0.4375
        assertApproxEqRel(optionVotes[14], 1.0625 ether, 0.1 ether); // 0.4375 + 0.625 = 1.0625
        assertApproxEqRel(optionVotes[15], 0.4375 ether, 0.1 ether); // 0.4375
    }

    function test_16Options8Winners4Operations_ExecuteWinner() public {
        uint256 nOptions = 16;
        uint256 nWinners = 8;
        uint256 nOperations = 4;

        uint256 supportSingle = 11;
        uint256[] memory weights = new uint256[](16);
        weights[0] = 125;
        weights[2] = 125;
        weights[4] = 125;
        weights[6] = 125;
        weights[8] = 125;
        weights[10] = 125;
        weights[12] = 125;
        weights[14] = 125;
        _proposeDelta(nOptions, nWinners, nOperations, "<proposal description>");
        _castVoteDelta(supportSingle, weights);

        vm.expectEmit(false, false, false, true);
        emit CallReceiverMock.MockFunctionCalledWithArgs(12, 1);
        vm.expectEmit(false, false, false, true);
        emit CallReceiverMock.MockFunctionCalledWithArgs(12, 2);
        vm.expectEmit(false, false, false, true);
        emit CallReceiverMock.MockFunctionCalledWithArgs(12, 3);
        vm.expectEmit(false, false, false, true);
        emit CallReceiverMock.MockFunctionCalledWithArgs(12, 4);
        vm.expectEmit(false, false, false, true);
        emit CallReceiverMock.MockFunctionCalledWithArgs(1, 1);
        vm.expectEmit(false, false, false, true);
        emit CallReceiverMock.MockFunctionCalledWithArgs(1, 2);
        vm.expectEmit(false, false, false, true);
        emit CallReceiverMock.MockFunctionCalledWithArgs(1, 3);
        vm.expectEmit(false, false, false, true);
        emit CallReceiverMock.MockFunctionCalledWithArgs(1, 4);
        vm.expectEmit(false, false, false, true);
        emit CallReceiverMock.MockFunctionCalledWithArgs(3, 1);
        vm.expectEmit(false, false, false, true);
        emit CallReceiverMock.MockFunctionCalledWithArgs(3, 2);
        vm.expectEmit(false, false, false, true);
        emit CallReceiverMock.MockFunctionCalledWithArgs(3, 3);
        vm.expectEmit(false, false, false, true);
        emit CallReceiverMock.MockFunctionCalledWithArgs(3, 4);
        vm.expectEmit(false, false, false, true);
        emit CallReceiverMock.MockFunctionCalledWithArgs(5, 1);
        vm.expectEmit(false, false, false, true);
        emit CallReceiverMock.MockFunctionCalledWithArgs(5, 2);
        vm.expectEmit(false, false, false, true);
        emit CallReceiverMock.MockFunctionCalledWithArgs(5, 3);
        vm.expectEmit(false, false, false, true);
        emit CallReceiverMock.MockFunctionCalledWithArgs(5, 4);
        vm.expectEmit(false, false, false, true);
        emit CallReceiverMock.MockFunctionCalledWithArgs(7, 1);
        vm.expectEmit(false, false, false, true);
        emit CallReceiverMock.MockFunctionCalledWithArgs(7, 2);
        vm.expectEmit(false, false, false, true);
        emit CallReceiverMock.MockFunctionCalledWithArgs(7, 3);
        vm.expectEmit(false, false, false, true);
        emit CallReceiverMock.MockFunctionCalledWithArgs(7, 4);
        vm.expectEmit(false, false, false, true);
        emit CallReceiverMock.MockFunctionCalledWithArgs(9, 1);
        vm.expectEmit(false, false, false, true);
        emit CallReceiverMock.MockFunctionCalledWithArgs(9, 2);
        vm.expectEmit(false, false, false, true);
        emit CallReceiverMock.MockFunctionCalledWithArgs(9, 3);
        vm.expectEmit(false, false, false, true);
        emit CallReceiverMock.MockFunctionCalledWithArgs(9, 4);
        vm.expectEmit(false, false, false, true);
        emit CallReceiverMock.MockFunctionCalledWithArgs(11, 1);
        vm.expectEmit(false, false, false, true);
        emit CallReceiverMock.MockFunctionCalledWithArgs(11, 2);
        vm.expectEmit(false, false, false, true);
        emit CallReceiverMock.MockFunctionCalledWithArgs(11, 3);
        vm.expectEmit(false, false, false, true);
        emit CallReceiverMock.MockFunctionCalledWithArgs(11, 4);
        vm.expectEmit(false, false, false, true);
        emit CallReceiverMock.MockFunctionCalledWithArgs(13, 1);
        vm.expectEmit(false, false, false, true);
        emit CallReceiverMock.MockFunctionCalledWithArgs(13, 2);
        vm.expectEmit(false, false, false, true);
        emit CallReceiverMock.MockFunctionCalledWithArgs(13, 3);
        vm.expectEmit(false, false, false, true);
        emit CallReceiverMock.MockFunctionCalledWithArgs(13, 4);

        _executeDelta();
    }

    // ========================================================
    // ======== INVALID PROPOSAL/VOTING CONFIGURATIONS ========
    // ========================================================

    function test_SupportForBravoVoteIsNotAgainstForAbstain() public {
        Operation[] memory allOperations = new Operation[](1);
        allOperations[0] =
            Operation(address(receiver), 1 ether, abi.encodeWithSelector(CallReceiverMock.mockFunction.selector));

        vm.prank(owner);
        payable(continuumDAO).transfer(1 ether);

        uint256 _proposalId = _propose(proposer, allOperations, "<proposal description>");
        _waitForSnapshot(_proposalId);

        vm.prank(voter1);
        vm.expectRevert();
        continuumDAO.castVote(_proposalId, 3);
    }

    function test_NoWeightingsAreProvidedForDeltaProposal() public {
        _proposeDelta(2, 1, 1, "<proposal description>");

        vm.prank(voter1);
        vm.expectRevert(abi.encodeWithSelector(GovernorDeltaInvalidVoteParams.selector, hex"00"));
        continuumDAO.castVoteWithReasonAndParams(proposalIdDelta, uint8(AGAINST), "", hex"00");
    }

    function test_CastVoteWithoutParamsOnADeltaProposal() public {
        _proposeDelta(4, 2, 1, "<proposal description>");

        vm.prank(voter1);
        vm.expectRevert(abi.encodeWithSelector(GovernorDeltaInvalidVoteParams.selector, hex""));
        continuumDAO.castVote(proposalIdDelta, uint8(AGAINST));
    }

    function test_NOptionsIsLessThanTwo() public {
        bytes memory metadataZeroOptions = _buildMetadata(0, 1, 1);
        Operation[] memory allOperations = new Operation[](2);
        allOperations[0].target = address(0);
        allOperations[0].val = 0;
        allOperations[0].data = metadataZeroOptions;
        allOperations[1].target = address(receiver);
        allOperations[1].val = 0;
        allOperations[1].data = abi.encodeWithSelector(CallReceiverMock.mockFunction.selector);

        vm.expectRevert(abi.encodeWithSelector(GovernorDeltaInvalidProposal.selector, 0, 1, metadataZeroOptions));
        _propose(proposer, allOperations, "<proposal description>");
    }

    function test_NWinnersIsZero() public {
        bytes memory metadata = _buildMetadata(2, 0, 1);
        Operation[] memory options = _generateOptions(metadata);

        vm.expectRevert(abi.encodeWithSelector(GovernorDeltaInvalidProposal.selector, 2, 0, metadata));
        _propose(proposer, options, "<proposal description>");
    }

    function test_NWinnersIsGreaterThanOrEqualToNOptions() public {
        bytes memory metadataEqual = _buildMetadata(4, 4, 1);
        Operation[] memory optionsEqual = _generateOptions(metadataEqual);

        bytes memory metadataGreaterThan = _buildMetadata(4, 5, 1);
        Operation[] memory optionsGreaterThan = _generateOptions(metadataGreaterThan);

        vm.expectRevert(abi.encodeWithSelector(GovernorDeltaInvalidProposal.selector, 4, 4, metadataEqual));
        _propose(proposer, optionsEqual, "<proposal description>");

        vm.expectRevert(abi.encodeWithSelector(GovernorDeltaInvalidProposal.selector, 4, 5, metadataGreaterThan));
        _propose(proposer, optionsGreaterThan, "<proposal description>");
    }

    function test_NonIncrementingOptionIndices() public {
        // Create metadata with non-incrementing option indices
        // Correct layout for 2 options, 1 winner would be [2, 1, 1, 3]
        // But we'll create [2, 1, 4, 2] which has decrementing indices
        bytes memory metadata = new bytes(4 * 32);
        assembly {
            let metadataPtr := add(metadata, 0x20)
            mstore(metadataPtr, 2) // nOptions = 2
            mstore(add(metadataPtr, 0x20), 1) // nWinners = 1
            mstore(add(metadataPtr, 0x40), 4) // option 0 index = 4 (should be 1)
            mstore(add(metadataPtr, 0x60), 2) // option 1 index = 2 (should be 3, but 2 < 4)
        }

        Operation[] memory options = _generateOptions(metadata);

        vm.expectRevert(abi.encodeWithSelector(GovernorNonIncrementingOptionIndices.selector, 2, metadata));
        _propose(proposer, options, "<proposal description>");
    }
}
