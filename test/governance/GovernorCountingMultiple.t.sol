// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import {console} from "forge-std/console.sol";
import {GovernorHelpers} from "../helpers/GovernorHelpers.sol";
import {IVotingEscrow} from "../../src/token/IVotingEscrow.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {CallReceiverMock} from "../helpers/mocks/CallReceiverMock.sol";

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
        _advanceTime(2 * 1 weeks);
    }

    function test_DeploymentCheck() public {
        assertEq(continuumDAO.COUNTING_MODE(), "support=bravo&quorum=for,abstain;support=delta&quorum=for");
    }

    function test_NominalIsUnaffected() public {
        Operation[] memory options = new Operation[](1);
        options[0] =
            Operation(address(receiver), 1 ether, abi.encodeWithSelector(CallReceiverMock.mockFunction.selector));

        vm.prank(owner);
        payable(continuumDAO).transfer(1 ether);

        vm.prank(proposer);
        _propose(options, "<proposal description>");

        _waitForSnapshot();

        assertEq(uint8(continuumDAO.state(proposalId)), uint8(IGovernor.ProposalState.Active));

        _castVoteWithReason(voter1, FOR, "This is nice");
        _castVote(voter2, FOR);
        _castVote(voter3, AGAINST);
        _castVote(voter4, ABSTAIN);

        _waitForDeadline();

        assertEq(uint8(continuumDAO.state(proposalId)), uint8(IGovernor.ProposalState.Succeeded));

        vm.prank(proposer);
        vm.expectEmit(false, false, false, false);
        emit CallReceiverMock.MockFunctionCalled();
        _execute(options, "<proposal description>");

        assertEq(continuumDAO.hasVoted(proposalId, owner), false);
        assertEq(continuumDAO.hasVoted(proposalId, voter1), true);
        assertEq(continuumDAO.hasVoted(proposalId, voter2), true);
        assertEq(address(receiver).balance, 1 ether);
    }

    // ==========================================================
    // ========= MULTI-OPTION PROPOSING: SINGLE-OPTION ==========
    // ==========================================================

    function test_4Options1Winner_Propose() public {
        uint256 nOptions = 4;
        uint256 nWinners = 1;

        bytes memory metadata = _buildMetadata(nOptions, nWinners, 1);
        Operation[] memory options = _generateOptions(metadata, address(ve));

        vm.prank(proposer);
        _propose(options, "<proposal description>");

        (uint256 nOptionsSet, uint256 nWinnersSet) = _getProposalConfiguration();
        assertEq(nOptionsSet, nOptions);
        assertEq(nWinnersSet, nWinners);
    }

    function test_4Options1Winner_VoteSingleApprovalWeighted() public {}
}

// describe("multiple-option proposing and voting: single-operation", function () {
//   describe("proposal with 4 options, 1 winner", function () {
//     const nOptions = 4n; // number of options
//     const nWinners = 1n; // number of winners

//     it("create metadata and options, propose", async function () {
//       const metadata = buildMetadata(nOptions, nWinners, 1n); // 4 options, 1 winner
//       const options = generateOptions(metadata, this.receiver.target); // 4 single-operation options

//       this.proposal = this.helper.setProposal(options, "<proposal description>");
//       await this.helper.connect(this.proposer).propose();

//       const [nOptionsOutput, nWinnersOutput] = await this.mock.proposalConfiguration(this.helper.id);
//       expect(nOptionsOutput).to.equal(BigInt(nOptions));
//       expect(nWinnersOutput).to.equal(BigInt(nWinners));
//     });

//     it("vote for single, approval and weighted", async function () {
//       await proposeDelta(nOptions, nWinners, 1n, this);

//       // all voting power towards option 3
//       const paramsSingle = encodeSingleVote(nOptions, 2);
//       /* INFO: output:
    //        * 0: 0000000000000000000000000000000000000000000000000000000000000000
    //        * 1: 0000000000000000000000000000000000000000000000000000000000000000
    //        * 2: 0000000000000000000000000000000000000000000000000000000000000064
    //        * 3: 0000000000000000000000000000000000000000000000000000000000000000
    //        * for voter1, this should equal 10 MTKN of voting power to option 3
    //        */

//       // even voting power towards each option
//       const paramsApproval = encodeApprovalVote(nOptions);
//       /* INFO: output:
    //        * 0: 0000000000000000000000000000000000000000000000000000000000000064
    //        * 1: 0000000000000000000000000000000000000000000000000000000000000064
    //        * 2: 0000000000000000000000000000000000000000000000000000000000000064
    //        * 3: 0000000000000000000000000000000000000000000000000000000000000064
    //        * for voter2, this should equal 7/4 = 1.75 MTKN of voting power to each option
    //        */

//       // 50% voting power each towards options 1 & 3
//       const paramsWeighted = encodeWeightedVote(nOptions, [50n, 0, 50n, 0]);
//       /* INFO: output:
    //        * 0: 0000000000000000000000000000000000000000000000000000000000000032
    //        * 1: 0000000000000000000000000000000000000000000000000000000000000000
    //        * 2: 0000000000000000000000000000000000000000000000000000000000000032
    //        * 3: 0000000000000000000000000000000000000000000000000000000000000000
    //        * for voter3, this should equal 5/2 = 2.5 MTKN each to option 1 and option 3
    //        */

//       await this.helper.connect(this.voter1).vote({ support: 0, params: paramsSingle });
//       await this.helper.connect(this.voter2).vote({ support: 0, params: paramsApproval });
//       await this.helper.connect(this.voter3).vote({ support: 0, params: paramsWeighted });

//       const [optionVotesWei, totalVotesWei] = await this.mock.proposalVotes(this.helper.id);
//       const optionVotes = optionVotesWei.map(opt => ethers.formatUnits(opt, "ether"));
//       const totalVotes = ethers.formatUnits(totalVotesWei, "ether");

//       expect(totalVotes).to.equal("22.0");
//       // PASSED: 4.25 + 1.75 + 14.25 + 1.75 = 22.0 MTKN

//       expect(optionVotes[0]).to.equal("4.25"); // 1.75 + 2.5 = 4.25
//       expect(optionVotes[1]).to.equal("1.75"); // 1.75
//       expect(optionVotes[2]).to.equal("14.25"); // 10 + 1.75 + 2.5 = 14.25 winner
//       expect(optionVotes[3]).to.equal("1.75"); // 1.75
//     });

//     it("execute option with most votes", async function () {
//       await proposeDelta(nOptions, nWinners, 1n, this);
//       await castVoteDelta(nOptions, nWinners, { single: 2, weighted: [50n, 0, 50n, 0] }, this);
//       await expect(this.helper.execute()).to.emit(this.receiver, "MockFunctionCalledWithArgs").withArgs(3n, 1n); // 3rd option, 1st operation
//     });
//   });

//   describe("proposal with 8 options, 2 winners", function () {
//     const nOptions = 8n; // number of options
//     const nWinners = 2n; // number of winners

//     it("create metadata and options, propose", async function () {
//       const metadata = buildMetadata(nOptions, nWinners, 1n); // 8 options, 2 winners
//       const options = generateOptions(metadata, this.receiver.target); // 8 single-operation options

//       this.proposal = this.helper.setProposal(options, "<proposal description>");
//       await this.helper.connect(this.proposer).propose();

//       const [nOptionsOutput, nWinnersOutput] = await this.mock.proposalConfiguration(this.helper.id);
//       expect(nOptionsOutput).to.equal(BigInt(nOptions));
//       expect(nWinnersOutput).to.equal(BigInt(nWinners));
//     });

//     it("vote for single, approval and weighted", async function () {
//       await proposeDelta(nOptions, nWinners, 1n, this);

//       // all voting power towards option 5
//       const paramsSingle = encodeSingleVote(nOptions, 4);
//       /* INFO: output:
    //        * 0: 0000000000000000000000000000000000000000000000000000000000000000
    //        * 1: 0000000000000000000000000000000000000000000000000000000000000000
    //        * 2: 0000000000000000000000000000000000000000000000000000000000000000
    //        * 3: 0000000000000000000000000000000000000000000000000000000000000000
    //        * 4: 0000000000000000000000000000000000000000000000000000000000000064
    //        * 5: 0000000000000000000000000000000000000000000000000000000000000000
    //        * 6: 0000000000000000000000000000000000000000000000000000000000000000
    //        * 7: 0000000000000000000000000000000000000000000000000000000000000000
    //        * for voter1, this should equal 10 MTKN of voting power to option 5
    //        */

//       // even voting power towards each option
//       const paramsApproval = encodeApprovalVote(nOptions);
//       /* INFO: output:
    //        * 0: 0000000000000000000000000000000000000000000000000000000000000064
    //        * 1: 0000000000000000000000000000000000000000000000000000000000000064
    //        * 2: 0000000000000000000000000000000000000000000000000000000000000064
    //        * 3: 0000000000000000000000000000000000000000000000000000000000000064
    //        * 4: 0000000000000000000000000000000000000000000000000000000000000064
    //        * 5: 0000000000000000000000000000000000000000000000000000000000000064
    //        * 6: 0000000000000000000000000000000000000000000000000000000000000064
    //        * 7: 0000000000000000000000000000000000000000000000000000000000000064
    //        * for voter2, this should equal 7/8 = 0.875 MTKN of voting power to each option
    //        */

//       // 25% voting power each towards options 1, 3, 5, 7
//       const paramsWeighted = encodeWeightedVote(nOptions, [25n, 0, 25n, 0, 25n, 0, 25n, 0]);
//       /* INFO: output:
    //        * 0: 0000000000000000000000000000000000000000000000000000000000000032
    //        * 1: 0000000000000000000000000000000000000000000000000000000000000000
    //        * 2: 0000000000000000000000000000000000000000000000000000000000000032
    //        * 3: 0000000000000000000000000000000000000000000000000000000000000000
    //        * 4: 0000000000000000000000000000000000000000000000000000000000000032
    //        * 5: 0000000000000000000000000000000000000000000000000000000000000000
    //        * 6: 0000000000000000000000000000000000000000000000000000000000000032
    //        * 7: 0000000000000000000000000000000000000000000000000000000000000000
    //        * for voter3, this should equal 5/4 = 1.25 MTKN each to options 1, 3, 5, 7
    //        */

//       await this.helper.connect(this.voter1).vote({ support: 0, params: paramsSingle });
//       await this.helper.connect(this.voter2).vote({ support: 0, params: paramsApproval });
//       await this.helper.connect(this.voter3).vote({ support: 0, params: paramsWeighted });

//       const [optionVotesWei, totalVotesWei] = await this.mock.proposalVotes(this.helper.id);
//       const optionVotes = optionVotesWei.map(opt => ethers.formatUnits(opt, "ether"));
//       const totalVotes = ethers.formatUnits(totalVotesWei, "ether");

//       expect(totalVotes).to.equal("22.0");
//       // PASSED: 2.125 + 0.875 + 2.125 + 0.875 + 12.125 + 0.875 + 2.125 + 0.875  = 22.0 MTKN

//       expect(optionVotes[0]).to.equal("2.125"); // 0.875 + 1.25 = 2.125 winner2
//       expect(optionVotes[1]).to.equal("0.875"); // 0.875
//       expect(optionVotes[2]).to.equal("2.125"); // 0.875 + 1.25 = 2.125
//       expect(optionVotes[3]).to.equal("0.875"); // 0.875
//       expect(optionVotes[4]).to.equal("12.125"); // 10 + 0.875 + 1.25 = 12.125 winner1
//       expect(optionVotes[5]).to.equal("0.875"); // 0.875
//       expect(optionVotes[6]).to.equal("2.125"); // 0.875 + 1.25 = 2.125
//       expect(optionVotes[7]).to.equal("0.875"); // 0.875
//     });

//     it("execute option with most votes", async function () {
//       await proposeDelta(nOptions, nWinners, 1n, this);
//       await castVoteDelta(nOptions, nWinners, { single: 4, weighted: [25n, 0, 25n, 0, 25n, 0, 25n, 0] }, this);
//       await expect(this.helper.execute())
//         .to.emit(this.receiver, "MockFunctionCalledWithArgs")
//         .withArgs(5n, 1n) // 5th option, 1st operation
//         .and.to.emit(this.receiver, "MockFunctionCalledWithArgs")
//         .withArgs(1n, 1n); // 1st option, 1st operation
//     });
//   });

//   describe("proposal with 16 options, 4 winners", function () {
//     const nOptions = 16n; // number of options
//     const nWinners = 4n; // number of winners

//     it("create metadata and options, propose", async function () {
//       const metadata = buildMetadata(nOptions, nWinners, 1n); // 16 options, 4 winners
//       const options = generateOptions(metadata, this.receiver.target); // 16 single-operation options

//       this.proposal = this.helper.setProposal(options, "<proposal description>");
//       await this.helper.connect(this.proposer).propose();

//       const [nOptionsOutput, nWinnersOutput] = await this.mock.proposalConfiguration(this.helper.id);
//       expect(nOptionsOutput).to.equal(BigInt(nOptions));
//       expect(nWinnersOutput).to.equal(BigInt(nWinners));
//     });

//     it("vote for single, approval and weighted", async function () {
//       await proposeDelta(nOptions, nWinners, 1n, this);

//       // all voting power towards option 12
//       const paramsSingle = encodeSingleVote(nOptions, 11);
//       /* INFO: output:
    //        *  1: 0000000000000000000000000000000000000000000000000000000000000000
    //        *  2: 0000000000000000000000000000000000000000000000000000000000000000
    //        *  3: 0000000000000000000000000000000000000000000000000000000000000000
    //        *  4: 0000000000000000000000000000000000000000000000000000000000000000
    //        *  5: 0000000000000000000000000000000000000000000000000000000000000000
    //        *  6: 0000000000000000000000000000000000000000000000000000000000000000
    //        *  7: 0000000000000000000000000000000000000000000000000000000000000000
    //        *  8: 0000000000000000000000000000000000000000000000000000000000000000
    //        *  9: 0000000000000000000000000000000000000000000000000000000000000000
    //        * 10: 0000000000000000000000000000000000000000000000000000000000000000
    //        * 11: 0000000000000000000000000000000000000000000000000000000000000000
    //        * 12: 0000000000000000000000000000000000000000000000000000000000000064
    //        * 13: 0000000000000000000000000000000000000000000000000000000000000000
    //        * 14: 0000000000000000000000000000000000000000000000000000000000000000
    //        * 15: 0000000000000000000000000000000000000000000000000000000000000000
    //        * 16: 0000000000000000000000000000000000000000000000000000000000000000
    //        * for voter1, this should equal 10 MTKN of voting power to option 12
    //        */

//       // voting power distributed evenly towards each option
//       const paramsApproval = encodeApprovalVote(nOptions);
//       /* INFO: output:
    //        *  1: 0000000000000000000000000000000000000000000000000000000000000064
    //        *  2: 0000000000000000000000000000000000000000000000000000000000000064
    //        *  3: 0000000000000000000000000000000000000000000000000000000000000064
    //        *  4: 0000000000000000000000000000000000000000000000000000000000000064
    //        *  5: 0000000000000000000000000000000000000000000000000000000000000064
    //        *  6: 0000000000000000000000000000000000000000000000000000000000000064
    //        *  7: 0000000000000000000000000000000000000000000000000000000000000064
    //        *  8: 0000000000000000000000000000000000000000000000000000000000000064
    //        *  9: 0000000000000000000000000000000000000000000000000000000000000064
    //        * 10: 0000000000000000000000000000000000000000000000000000000000000064
    //        * 11: 0000000000000000000000000000000000000000000000000000000000000064
    //        * 12: 0000000000000000000000000000000000000000000000000000000000000064
    //        * 13: 0000000000000000000000000000000000000000000000000000000000000064
    //        * 14: 0000000000000000000000000000000000000000000000000000000000000064
    //        * 15: 0000000000000000000000000000000000000000000000000000000000000064
    //        * 16: 0000000000000000000000000000000000000000000000000000000000000064
    //        * for voter2, this should equal 7/16 = 0.4375 MTKN of voting power to each option
    //        */

//       // 12.5% voting power each towards options 1, 3, 5, 7, 9, 11, 13, 15
//       const paramsWeighted = encodeWeightedVote(nOptions, [
//         125n,
//         0n,
//         125n,
//         0n,
//         125n,
//         0n,
//         125n,
//         0n,
//         125n,
//         0n,
//         125n,
//         0n,
//         125n,
//         0n,
//         125n,
//         0n,
//       ]);
//       /* INFO: output:
    //        *  1: 000000000000000000000000000000000000000000000000000000000000007d
    //        *  2: 0000000000000000000000000000000000000000000000000000000000000000
    //        *  3: 000000000000000000000000000000000000000000000000000000000000007d
    //        *  4: 0000000000000000000000000000000000000000000000000000000000000000
    //        *  5: 000000000000000000000000000000000000000000000000000000000000007d
    //        *  6: 0000000000000000000000000000000000000000000000000000000000000000
    //        *  7: 000000000000000000000000000000000000000000000000000000000000007d
    //        *  8: 0000000000000000000000000000000000000000000000000000000000000000
    //        *  9: 000000000000000000000000000000000000000000000000000000000000007d
    //        * 10: 0000000000000000000000000000000000000000000000000000000000000000
    //        * 11: 000000000000000000000000000000000000000000000000000000000000007d
    //        * 12: 0000000000000000000000000000000000000000000000000000000000000000
    //        * 13: 000000000000000000000000000000000000000000000000000000000000007d
    //        * 14: 0000000000000000000000000000000000000000000000000000000000000000
    //        * 15: 000000000000000000000000000000000000000000000000000000000000007d
    //        * 16: 0000000000000000000000000000000000000000000000000000000000000000
    //        * for voter3, this should equal 5/8 = 0.625 MTKN each to options 1, 3, 5, 7, 9, 11, 13, 15
    //        */

//       await this.helper.connect(this.voter1).vote({ support: 0, params: paramsSingle });
//       await this.helper.connect(this.voter2).vote({ support: 0, params: paramsApproval });
//       await this.helper.connect(this.voter3).vote({ support: 0, params: paramsWeighted });

//       const [optionVotesWei, totalVotesWei] = await this.mock.proposalVotes(this.helper.id);
//       const optionVotes = optionVotesWei.map(opt => ethers.formatUnits(opt, "ether"));
//       const totalVotes = ethers.formatUnits(totalVotesWei, "ether");

//       expect(totalVotes).to.equal("22.0");
//       /* PASSED:
    //        *   (1.0625) + (0.4375) + (1.0625) + (0.4375)
    //        * + (1.0625) + (0.4375) + (1.0625) + (0.4375)
    //        * + (1.0625) + (0.4375) + (1.0625) + (10.4375)
    //        * + (1.0625) + (0.4375) + (1.0625) + (0.4375) = 22.0 MTKN
    //        */

//       expect(optionVotes[0]).to.equal("1.0625"); // 0.4375 + 0.625 = 1.0625  winner2
//       expect(optionVotes[1]).to.equal("0.4375"); // 0.4375
//       expect(optionVotes[2]).to.equal("1.0625"); // 0.4375 + 0.625 = 1.0625  winner3
//       expect(optionVotes[3]).to.equal("0.4375"); // 0.4375
//       expect(optionVotes[4]).to.equal("1.0625"); // 0.4375 + 0.625 = 1.0625  winner4
//       expect(optionVotes[5]).to.equal("0.4375"); // 0.4375
//       expect(optionVotes[6]).to.equal("1.0625"); // 0.4375 + 0.625 = 1.0625
//       expect(optionVotes[7]).to.equal("0.4375"); // 0.4375
//       expect(optionVotes[8]).to.equal("1.0625"); // 0.4375 + 0.625 = 1.0625
//       expect(optionVotes[9]).to.equal("0.4375"); // 0.4375
//       expect(optionVotes[10]).to.equal("1.0625"); // 0.4375 + 0.625 = 1.0625
//       expect(optionVotes[11]).to.equal("10.4375"); // 10 + 0.4375 = 10.4375    winner1
//       expect(optionVotes[12]).to.equal("1.0625"); // 0.4375 + 0.625 = 1.0625
//       expect(optionVotes[13]).to.equal("0.4375"); // 0.4375
//       expect(optionVotes[14]).to.equal("1.0625"); // 0.4375 + 0.625 = 1.0625
//       expect(optionVotes[15]).to.equal("0.4375"); // 0.4375
//     });

//     it("execute option with most votes", async function () {
//       await proposeDelta(nOptions, nWinners, 1n, this);
//       await castVoteDelta(
//         nOptions,
//         nWinners,
//         {
//           single: 11,
//           weighted: [125n, 0n, 125n, 0n, 125n, 0n, 125n, 0n, 125n, 0n, 125n, 0n, 125n, 0n, 125n, 0n],
//         },
//         this,
//       );
//       await expect(this.helper.execute())
//         .to.emit(this.receiver, "MockFunctionCalledWithArgs")
//         .withArgs(12n, 1n) // 12th option, 1st operation
//         .and.to.emit(this.receiver, "MockFunctionCalledWithArgs")
//         .withArgs(1n, 1n) // 1st option, 1st operation
//         .and.to.emit(this.receiver, "MockFunctionCalledWithArgs")
//         .withArgs(3n, 1n) // 3rd option, 1st operation
//         .and.to.emit(this.receiver, "MockFunctionCalledWithArgs")
//         .withArgs(5n, 1n); // 5th option, 1st operation
//     });
//   });
// });

// describe("multiple-option proposing and voting: multiple-operation", function () {
//   describe("proposal with 4 options, 1 winner, 1 operation per option", function () {
//     const nOptions = 4n;
//     const nWinners = 1n;
//     const nOperations = 1n;
//     /*
    //      * TEST: resulting metadata should be [4,1, 1,2,3,4]
    //      * resulting operations should be [metadata, opt1:op1, opt2:op1, opt3:op1, opt4:op1]
    //      */

//     it("create metadata and options, propose", async function () {
//       const metadata = buildMetadata(nOptions, nWinners, nOperations);
//       /*
    //        * INFO: output:
    //        * nOptions: 0000000000000000000000000000000000000000000000000000000000000004
    //        * nWinners: 0000000000000000000000000000000000000000000000000000000000000001
    //        * 0: 0000000000000000000000000000000000000000000000000000000000000001
    //        * 1: 0000000000000000000000000000000000000000000000000000000000000002
    //        * 2: 0000000000000000000000000000000000000000000000000000000000000003
    //        * 3: 0000000000000000000000000000000000000000000000000000000000000004
    //        */

//       const options = generateOptions(metadata, this.receiver.target); // 4 options with 1 operation each

//       this.proposal = this.helper.setProposal(options, "<proposal description>");
//       await this.helper.connect(this.proposer).propose();

//       const [nOptionsOutput, nWinnersOutput] = await this.mock.proposalConfiguration(this.helper.id);
//       expect(nOptionsOutput).to.equal(BigInt(nOptions));
//       expect(nWinnersOutput).to.equal(BigInt(nWinners));
//     });

//     it("vote for single, approval and weighted", async function () {
//       await proposeDelta(nOptions, nWinners, nOperations, this);

//       // all voting power towards option 3
//       const paramsSingle = encodeSingleVote(nOptions, 2);
//       /* INFO: output:
    //        * 0: 0000000000000000000000000000000000000000000000000000000000000000
    //        * 1: 0000000000000000000000000000000000000000000000000000000000000000
    //        * 2: 0000000000000000000000000000000000000000000000000000000000000064
    //        * 3: 0000000000000000000000000000000000000000000000000000000000000000
    //        * for voter1, this should equal 10 MTKN of voting power to option 3
    //        */

//       // even voting power towards each option
//       const paramsApproval = encodeApprovalVote(nOptions);
//       /* INFO: output:
    //        * 0: 0000000000000000000000000000000000000000000000000000000000000064
    //        * 1: 0000000000000000000000000000000000000000000000000000000000000064
    //        * 2: 0000000000000000000000000000000000000000000000000000000000000064
    //        * 3: 0000000000000000000000000000000000000000000000000000000000000064
    //        * for voter2, this should equal 7/4 = 1.75 MTKN of voting power to each option
    //        */

//       // 50% voting power each towards options 1 & 3
//       const paramsWeighted = encodeWeightedVote(nOptions, [50n, 0, 50n, 0]);
//       /* INFO: output:
    //        * 0: 0000000000000000000000000000000000000000000000000000000000000032
    //        * 1: 0000000000000000000000000000000000000000000000000000000000000000
    //        * 2: 0000000000000000000000000000000000000000000000000000000000000032
    //        * 3: 0000000000000000000000000000000000000000000000000000000000000000
    //        * for voter3, this should equal 5/2 = 2.5 MTKN each to option 1 and option 3
    //        */

//       await this.helper.connect(this.voter1).vote({ support: 0, params: paramsSingle });
//       await this.helper.connect(this.voter2).vote({ support: 0, params: paramsApproval });
//       await this.helper.connect(this.voter3).vote({ support: 0, params: paramsWeighted });

//       const [optionVotesWei, totalVotesWei] = await this.mock.proposalVotes(this.helper.id);
//       const optionVotes = optionVotesWei.map(opt => ethers.formatUnits(opt, "ether"));
//       const totalVotes = ethers.formatUnits(totalVotesWei, "ether");

//       expect(totalVotes).to.equal("22.0");
//       // PASSED: 4.25 + 1.75 + 14.25 + 1.75 = 22.0 MTKN

//       expect(optionVotes[0]).to.equal("4.25"); // 1.75 + 2.5 = 4.25
//       expect(optionVotes[1]).to.equal("1.75"); // 1.75
//       expect(optionVotes[2]).to.equal("14.25"); // 10 + 1.75 + 2.5 = 14.25 winner
//       expect(optionVotes[3]).to.equal("1.75"); // 1.75
//     });

//     it("execute option with most votes", async function () {
//       await proposeDelta(nOptions, nWinners, nOperations, this);
//       await castVoteDelta(nOptions, nWinners, { single: 2, weighted: [50n, 0, 50n, 0] }, this);
//       await expect(this.helper.execute()).to.emit(this.receiver, "MockFunctionCalledWithArgs").withArgs(3n, 1n); // 3rd option, 1st operation
//     });
//   });

//   describe("proposal with 2 options, 1 winner, 2 operations per option", function () {
//     const nOptions = 2n;
//     const nWinners = 1n;
//     const nOperations = 2n;
//     /*
    //      * TEST: resulting metadata should be [2,1, 1,3]
    //      * resulting operations should be [metadata, opt1:op1, opt1:op2, opt2:op1, opt2:op2]
    //      */

//     it("create metadata and options, propose", async function () {
//       const metadata = buildMetadata(nOptions, nWinners, nOperations);
//       /* INFO: output:
    //        * nOptions: 0000000000000000000000000000000000000000000000000000000000000002
    //        * nWinners: 0000000000000000000000000000000000000000000000000000000000000001
    //        * 1: 0000000000000000000000000000000000000000000000000000000000000001
    //        * 2: 0000000000000000000000000000000000000000000000000000000000000003
    //        */

//       const options = generateOptions(metadata, this.receiver.target); // 2 options with 2 operations each

//       this.proposal = this.helper.setProposal(options, "<proposal description>");
//       await this.helper.connect(this.proposer).propose();

//       const [nOptionsOutput, nWinnersOutput] = await this.mock.proposalConfiguration(this.helper.id);
//       expect(nOptionsOutput).to.equal(BigInt(nOptions));
//       expect(nWinnersOutput).to.equal(BigInt(nWinners));
//     });

//     it("vote for single, approval and weighted", async function () {
//       await proposeDelta(nOptions, nWinners, nOperations, this);

//       // all voting power towards option 2
//       const paramsSingle = encodeSingleVote(nOptions, 1);
//       /* INFO: output:
    //        * 0: 0000000000000000000000000000000000000000000000000000000000000000
    //        * 1: 0000000000000000000000000000000000000000000000000000000000000064
    //        * for voter1, this should equal 10 MTKN of voting power to option 2
    //        */

//       // even voting power towards each option
//       const paramsApproval = encodeApprovalVote(nOptions);
//       /* INFO: output:
    //        * 0: 0000000000000000000000000000000000000000000000000000000000000064
    //        * 1: 0000000000000000000000000000000000000000000000000000000000000064
    //        * for voter2, this should equal 7/2 = 3.5 MTKN of voting power to each option
    //        */

//       // 25% voting power towards option 1, 75% voting power towards option 2
//       const paramsWeighted = encodeWeightedVote(nOptions, [25n, 75]);
//       /* INFO: output:
    //        * 0: 0000000000000000000000000000000000000000000000000000000000000019
    //        * 1: 000000000000000000000000000000000000000000000000000000000000004b
    //        * for voter3, this should equal 5/4 = 1.25 MTKN to option 1, 5*3/4 = 3.75 MTKN to option 2
    //        */

//       await this.helper.connect(this.voter1).vote({ support: 0, params: paramsSingle });
//       await this.helper.connect(this.voter2).vote({ support: 0, params: paramsApproval });
//       await this.helper.connect(this.voter3).vote({ support: 0, params: paramsWeighted });

//       const [optionVotesWei, totalVotesWei] = await this.mock.proposalVotes(this.helper.id);
//       const optionVotes = optionVotesWei.map(opt => ethers.formatUnits(opt, "ether"));
//       const totalVotes = ethers.formatUnits(totalVotesWei, "ether");

//       expect(totalVotes).to.equal("22.0");
//       // PASSED: 4.75 + 17.25 = 22.0 MTKN

//       expect(optionVotes[0]).to.equal("4.75"); // 3.5 + 1.25 = 4.75
//       expect(optionVotes[1]).to.equal("17.25"); // 10 + 3.5 + 3.75 = 17.25 winner
//     });

//     it("execute option with most votes", async function () {
//       await proposeDelta(nOptions, nWinners, nOperations, this);
//       await castVoteDelta(nOptions, nWinners, { single: 1, weighted: [25n, 75n] }, this);
//       await expect(this.helper.execute())
//         .to.emit(this.receiver, "MockFunctionCalledWithArgs")
//         .withArgs(2n, 1n) // 2nd option, 1st operation
//         .and.to.emit(this.receiver, "MockFunctionCalledWithArgs")
//         .withArgs(2n, 2n); // 2nd option, 2nd operation
//     });
//   });

//   describe("proposal with 16 options, 8 winners, 4 operations per option", function () {
//     const nOptions = 16n;
//     const nWinners = 8n;
//     const nOperations = 4n;
//     /*
    //      * TEST: resulting metadata should be [16,8, 1,5,9,13,17,21,25,29,33,37,41,45,49,53,57,61]
    //      * resulting operations should be [
    //      *   metadata,
    //      *   opt1:op1, opt1:op2, opt1:op3, opt1:op4,
    //      *   opt2:op1, opt2:op2, opt2:op3, opt2:op4,
    //      *   ... ,
    //      *   opt16op1, opt16op2, opt16op3, opt16:op4
    //      * ]
    //      */

//     it("create metadata and options, propose", async function () {
//       const metadata = buildMetadata(nOptions, nWinners, nOperations);
//       /* INFO: output:
    //        * nOptions: 0000000000000000000000000000000000000000000000000000000000000010
    //        * nWinners: 0000000000000000000000000000000000000000000000000000000000000008
    //        *  0: 0000000000000000000000000000000000000000000000000000000000000001
    //        *  1: 0000000000000000000000000000000000000000000000000000000000000002
    //        *  2: 0000000000000000000000000000000000000000000000000000000000000003
    //        *  3: 0000000000000000000000000000000000000000000000000000000000000004
    //        *  4: 0000000000000000000000000000000000000000000000000000000000000005
    //        *  5: 0000000000000000000000000000000000000000000000000000000000000006
    //        *  6: 0000000000000000000000000000000000000000000000000000000000000007
    //        *  7: 0000000000000000000000000000000000000000000000000000000000000008
    //        *  8: 0000000000000000000000000000000000000000000000000000000000000009
    //        *  9: 000000000000000000000000000000000000000000000000000000000000000a
    //        * 10: 000000000000000000000000000000000000000000000000000000000000000b
    //        * 11: 000000000000000000000000000000000000000000000000000000000000000c
    //        * 12: 000000000000000000000000000000000000000000000000000000000000000d
    //        * 13: 000000000000000000000000000000000000000000000000000000000000000e
    //        * 14: 000000000000000000000000000000000000000000000000000000000000000f
    //        * 15: 0000000000000000000000000000000000000000000000000000000000000010
    //        */
//       const options = generateOptions(metadata, this.receiver.target); // 16 options with 4 operations each

//       this.proposal = this.helper.setProposal(options, "<proposal description>");
//       await this.helper.connect(this.proposer).propose();

//       const [nOptionsOutput, nWinnersOutput] = await this.mock.proposalConfiguration(this.helper.id);
//       expect(nOptionsOutput).to.equal(BigInt(nOptions));
//       expect(nWinnersOutput).to.equal(BigInt(nWinners));
//     });

//     it("vote for single, approval and weighted", async function () {
//       await proposeDelta(nOptions, nWinners, nOperations, this);

//       // all voting power towards option 12
//       const paramsSingle = encodeSingleVote(nOptions, 11);
//       /* INFO: output:
    //        *  1: 0000000000000000000000000000000000000000000000000000000000000000
    //        *  2: 0000000000000000000000000000000000000000000000000000000000000000
    //        *  3: 0000000000000000000000000000000000000000000000000000000000000000
    //        *  4: 0000000000000000000000000000000000000000000000000000000000000000
    //        *  5: 0000000000000000000000000000000000000000000000000000000000000000
    //        *  6: 0000000000000000000000000000000000000000000000000000000000000000
    //        *  7: 0000000000000000000000000000000000000000000000000000000000000000
    //        *  8: 0000000000000000000000000000000000000000000000000000000000000000
    //        *  9: 0000000000000000000000000000000000000000000000000000000000000000
    //        * 10: 0000000000000000000000000000000000000000000000000000000000000000
    //        * 11: 0000000000000000000000000000000000000000000000000000000000000000
    //        * 12: 0000000000000000000000000000000000000000000000000000000000000064
    //        * 13: 0000000000000000000000000000000000000000000000000000000000000000
    //        * 14: 0000000000000000000000000000000000000000000000000000000000000000
    //        * 15: 0000000000000000000000000000000000000000000000000000000000000000
    //        * 16: 0000000000000000000000000000000000000000000000000000000000000000
    //        * for voter1, this should equal 10 MTKN of voting power to option 12
    //        */

//       // voting power distributed evenly towards each option
//       const paramsApproval = encodeApprovalVote(nOptions);
//       /* INFO: output:
    //        *  1: 0000000000000000000000000000000000000000000000000000000000000064
    //        *  2: 0000000000000000000000000000000000000000000000000000000000000064
    //        *  3: 0000000000000000000000000000000000000000000000000000000000000064
    //        *  4: 0000000000000000000000000000000000000000000000000000000000000064
    //        *  5: 0000000000000000000000000000000000000000000000000000000000000064
    //        *  6: 0000000000000000000000000000000000000000000000000000000000000064
    //        *  7: 0000000000000000000000000000000000000000000000000000000000000064
    //        *  8: 0000000000000000000000000000000000000000000000000000000000000064
    //        *  9: 0000000000000000000000000000000000000000000000000000000000000064
    //        * 10: 0000000000000000000000000000000000000000000000000000000000000064
    //        * 11: 0000000000000000000000000000000000000000000000000000000000000064
    //        * 12: 0000000000000000000000000000000000000000000000000000000000000064
    //        * 13: 0000000000000000000000000000000000000000000000000000000000000064
    //        * 14: 0000000000000000000000000000000000000000000000000000000000000064
    //        * 15: 0000000000000000000000000000000000000000000000000000000000000064
    //        * 16: 0000000000000000000000000000000000000000000000000000000000000064
    //        * for voter2, this should equal 7/16 = 0.4375 MTKN of voting power to each option
    //        */

//       // 12.5% voting power each towards options 1, 3, 5, 7, 9, 11, 13, 15
//       const paramsWeighted = encodeWeightedVote(nOptions, [
//         125n,
//         0n,
//         125n,
//         0n,
//         125n,
//         0n,
//         125n,
//         0n,
//         125n,
//         0n,
//         125n,
//         0n,
//         125n,
//         0n,
//         125n,
//         0n,
//       ]);
//       /* INFO: output:
    //        *  1: 000000000000000000000000000000000000000000000000000000000000007d
    //        *  2: 0000000000000000000000000000000000000000000000000000000000000000
    //        *  3: 000000000000000000000000000000000000000000000000000000000000007d
    //        *  4: 0000000000000000000000000000000000000000000000000000000000000000
    //        *  5: 000000000000000000000000000000000000000000000000000000000000007d
    //        *  6: 0000000000000000000000000000000000000000000000000000000000000000
    //        *  7: 000000000000000000000000000000000000000000000000000000000000007d
    //        *  8: 0000000000000000000000000000000000000000000000000000000000000000
    //        *  9: 000000000000000000000000000000000000000000000000000000000000007d
    //        * 10: 0000000000000000000000000000000000000000000000000000000000000000
    //        * 11: 000000000000000000000000000000000000000000000000000000000000007d
    //        * 12: 0000000000000000000000000000000000000000000000000000000000000000
    //        * 13: 000000000000000000000000000000000000000000000000000000000000007d
    //        * 14: 0000000000000000000000000000000000000000000000000000000000000000
    //        * 15: 000000000000000000000000000000000000000000000000000000000000007d
    //        * 16: 0000000000000000000000000000000000000000000000000000000000000000
    //        * for voter3, this should equal 5/8 = 0.625 MTKN each to options 1, 3, 5, 7, 9, 11, 13, 15
    //        */

//       await this.helper.connect(this.voter1).vote({ support: 0, params: paramsSingle });
//       await this.helper.connect(this.voter2).vote({ support: 0, params: paramsApproval });
//       await this.helper.connect(this.voter3).vote({ support: 0, params: paramsWeighted });

//       const [optionVotesWei, totalVotesWei] = await this.mock.proposalVotes(this.helper.id);
//       const optionVotes = optionVotesWei.map(opt => ethers.formatUnits(opt, "ether"));
//       const totalVotes = ethers.formatUnits(totalVotesWei, "ether");

//       expect(totalVotes).to.equal("22.0");
//       /* PASSED:
    //        *   (1.0625) + (0.4375) + (1.0625) + (0.4375)
    //        * + (1.0625) + (0.4375) + (1.0625) + (0.4375)
    //        * + (1.0625) + (0.4375) + (1.0625) + (10.4375)
    //        * + (1.0625) + (0.4375) + (1.0625) + (0.4375) = 22.0 MTKN
    //        */

//       expect(optionVotes[0]).to.equal("1.0625"); // 0.4375 + 0.625 = 1.0625  winner2
//       expect(optionVotes[1]).to.equal("0.4375"); // 0.4375
//       expect(optionVotes[2]).to.equal("1.0625"); // 0.4375 + 0.625 = 1.0625  winner3
//       expect(optionVotes[3]).to.equal("0.4375"); // 0.4375
//       expect(optionVotes[4]).to.equal("1.0625"); // 0.4375 + 0.625 = 1.0625  winner4
//       expect(optionVotes[5]).to.equal("0.4375"); // 0.4375
//       expect(optionVotes[6]).to.equal("1.0625"); // 0.4375 + 0.625 = 1.0625  winner5
//       expect(optionVotes[7]).to.equal("0.4375"); // 0.4375
//       expect(optionVotes[8]).to.equal("1.0625"); // 0.4375 + 0.625 = 1.0625  winner6
//       expect(optionVotes[9]).to.equal("0.4375"); // 0.4375
//       expect(optionVotes[10]).to.equal("1.0625"); // 0.4375 + 0.625 = 1.0625  winner7
//       expect(optionVotes[11]).to.equal("10.4375"); // 10 + 0.4375 = 10.4375    winner1
//       expect(optionVotes[12]).to.equal("1.0625"); // 0.4375 + 0.625 = 1.0625  winner8
//       expect(optionVotes[13]).to.equal("0.4375"); // 0.4375
//       expect(optionVotes[14]).to.equal("1.0625"); // 0.4375 + 0.625 = 1.0625
//       expect(optionVotes[15]).to.equal("0.4375"); // 0.4375
//     });

//     it("execute option with most votes", async function () {
//       await proposeDelta(nOptions, nWinners, nOperations, this);
//       await castVoteDelta(
//         nOptions,
//         nWinners,
//         {
//           single: 11,
//           weighted: [125n, 0n, 125n, 0n, 125n, 0n, 125n, 0n, 125n, 0n, 125n, 0n, 125n, 0n, 125n, 0n],
//         },
//         this,
//       );
//       await expect(this.helper.execute())
//         .to.emit(this.receiver, "MockFunctionCalledWithArgs")
//         .withArgs(12n, 1n)
//         .and.to.emit(this.receiver, "MockFunctionCalledWithArgs")
//         .withArgs(12n, 2n)
//         .and.to.emit(this.receiver, "MockFunctionCalledWithArgs")
//         .withArgs(12n, 3n)
//         .and.to.emit(this.receiver, "MockFunctionCalledWithArgs")
//         .withArgs(12n, 4n)
//         .and.to.emit(this.receiver, "MockFunctionCalledWithArgs")
//         .withArgs(1n, 1n)
//         .and.to.emit(this.receiver, "MockFunctionCalledWithArgs")
//         .withArgs(1n, 2n)
//         .and.to.emit(this.receiver, "MockFunctionCalledWithArgs")
//         .withArgs(1n, 3n)
//         .and.to.emit(this.receiver, "MockFunctionCalledWithArgs")
//         .withArgs(1n, 4n)
//         .and.to.emit(this.receiver, "MockFunctionCalledWithArgs")
//         .withArgs(3n, 1n)
//         .and.to.emit(this.receiver, "MockFunctionCalledWithArgs")
//         .withArgs(3n, 2n)
//         .and.to.emit(this.receiver, "MockFunctionCalledWithArgs")
//         .withArgs(3n, 3n)
//         .and.to.emit(this.receiver, "MockFunctionCalledWithArgs")
//         .withArgs(3n, 4n)
//         .and.to.emit(this.receiver, "MockFunctionCalledWithArgs")
//         .withArgs(5n, 1n)
//         .and.to.emit(this.receiver, "MockFunctionCalledWithArgs")
//         .withArgs(5n, 2n)
//         .and.to.emit(this.receiver, "MockFunctionCalledWithArgs")
//         .withArgs(5n, 3n)
//         .and.to.emit(this.receiver, "MockFunctionCalledWithArgs")
//         .withArgs(5n, 4n)
//         .and.to.emit(this.receiver, "MockFunctionCalledWithArgs")
//         .withArgs(7n, 1n)
//         .and.to.emit(this.receiver, "MockFunctionCalledWithArgs")
//         .withArgs(7n, 2n)
//         .and.to.emit(this.receiver, "MockFunctionCalledWithArgs")
//         .withArgs(7n, 3n)
//         .and.to.emit(this.receiver, "MockFunctionCalledWithArgs")
//         .withArgs(7n, 4n)
//         .and.to.emit(this.receiver, "MockFunctionCalledWithArgs")
//         .withArgs(9n, 1n)
//         .and.to.emit(this.receiver, "MockFunctionCalledWithArgs")
//         .withArgs(9n, 2n)
//         .and.to.emit(this.receiver, "MockFunctionCalledWithArgs")
//         .withArgs(9n, 3n)
//         .and.to.emit(this.receiver, "MockFunctionCalledWithArgs")
//         .withArgs(9n, 4n)
//         .and.to.emit(this.receiver, "MockFunctionCalledWithArgs")
//         .withArgs(11n, 1n)
//         .and.to.emit(this.receiver, "MockFunctionCalledWithArgs")
//         .withArgs(11n, 2n)
//         .and.to.emit(this.receiver, "MockFunctionCalledWithArgs")
//         .withArgs(11n, 3n)
//         .and.to.emit(this.receiver, "MockFunctionCalledWithArgs")
//         .withArgs(11n, 4n)
//         .and.to.emit(this.receiver, "MockFunctionCalledWithArgs")
//         .withArgs(13n, 1n)
//         .and.to.emit(this.receiver, "MockFunctionCalledWithArgs")
//         .withArgs(13n, 2n)
//         .and.to.emit(this.receiver, "MockFunctionCalledWithArgs")
//         .withArgs(13n, 3n)
//         .and.to.emit(this.receiver, "MockFunctionCalledWithArgs")
//         .withArgs(13n, 4n);
//     });
//   });
// });

// describe("invalid proposal/voting configurations", function () {
//   it("support for bravo vote is not Against/For/Abstain", async function () {
//     await this.helper.connect(this.proposer).propose();
//     await this.helper.waitForSnapshot();

//     await expect(this.helper.connect(this.voter1).vote({ support: 3 })).to.be.revertedWithCustomError(
//       this.mock,
//       "GovernorInvalidVoteType",
//     );
//   });

//   it("no weightings are provided for delta proposal", async function () {
//     await proposeDelta(2n, 1n, 1n, this);

//     await expect(
//       this.helper.connect(this.voter1).vote({ support: 0, params: "0x00" }),
//     ).to.be.revertedWithCustomError(this.mock, "GovernorDeltaInvalidVoteParams");
//   });

//   it("castVote without params on a delta proposal", async function () {
//     await proposeDelta(4n, 2n, 1n, this);

//     await expect(this.helper.connect(this.voter1).vote({ support: 0 })).to.be.revertedWithCustomError(
//       this.mock,
//       "GovernorDeltaInvalidVoteParams",
//     );
//   });

//   it("nOptions is less than two", async function () {
//     const metadataZeroOptions = buildMetadata(0n, 1n, 1n);
//     const options0 = generateOptions(metadataZeroOptions, this.receiver.target);

//     const metadataOneOption = buildMetadata(1n, 1n, 1n);
//     const options1 = generateOptions(metadataOneOption, this.receiver.target);

//     this.proposal = this.helper.setProposal(options0, "<proposal description>");
//     await expect(this.helper.connect(this.proposer).propose()).to.be.revertedWithCustomError(
//       this.mock,
//       "GovernorDeltaInvalidProposal",
//     );

//     this.proposal = this.helper.setProposal(options1, "<proposal description>");
//     await expect(this.helper.connect(this.proposer).propose()).to.be.revertedWithCustomError(
//       this.mock,
//       "GovernorDeltaInvalidProposal",
//     );
//   });

//   it("nWinners is zero", async function () {
//     const metadata = buildMetadata(2n, 0n, 1n);
//     const options = generateOptions(metadata, this.receiver.target);

//     this.proposal = this.helper.setProposal(options, "<proposal description>");
//     await expect(this.helper.connect(this.proposer).propose()).to.be.revertedWithCustomError(
//       this.mock,
//       "GovernorDeltaInvalidProposal",
//     );
//   });

//   it("nWinners is greater than or equal to nOptions", async function () {
//     const metadataEqual = buildMetadata(4n, 4n, 1n);
//     const optionsEqual = generateOptions(metadataEqual, this.receiver.target);

//     const metadataGreaterThan = buildMetadata(4n, 5n, 1n);
//     const optionsGreaterThan = generateOptions(metadataGreaterThan, this.receiver.target);

//     this.proposal = this.helper.setProposal(optionsEqual, "<proposal description>");
//     await expect(this.helper.connect(this.proposer).propose()).to.be.revertedWithCustomError(
//       this.mock,
//       "GovernorDeltaInvalidProposal",
//     );

//     this.proposal = this.helper.setProposal(optionsGreaterThan, "<proposal description>");
//     await expect(this.helper.connect(this.proposer).propose()).to.be.revertedWithCustomError(
//       this.mock,
//       "GovernorDeltaInvalidProposal",
//     );
//   });

//   it("non-incrementing option indices", async function () {
//     const types = Array.from({ length: 4 }, () => "uint256");
//     const lengths = [2, 1]; // 2 options, 1 winner (not relevant here)
//     const indices = [4, 2]; // decrementing option indices - correct layout is [2, 4]
//     const abiCoder = new ethers.AbiCoder();
//     const metadataDecrementing = abiCoder.encode(types, lengths.concat(indices));

//     const optionsDecrementing = generateOptions(metadataDecrementing, this.receiver.target);

//     this.proposal = this.helper.setProposal(optionsDecrementing, "<proposal description>");
//     await expect(this.helper.connect(this.proposer).propose()).to.be.revertedWithCustomError(
//       this.mock,
//       "GovernorNonIncrementingOptionIndices",
//     );
//   });
// });
