// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

import {console} from "forge-std/console.sol";
import {GovernorHelpers} from "../helpers/GovernorHelpers.sol";
import {IVotingEscrow} from "../../src/token/IVotingEscrow.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {CallReceiverMock} from "../helpers/mocks/CallReceiverMock.sol";
import {GovernorCountingMultiple} from "../../src/governance/GovernorCountingMultiple.sol";

contract TestGovernorProposalGuardian is GovernorHelpers {
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

    function test_ProposalGuardian_State() public view {
        address guardian = continuumDAO.proposalGuardian();
        assertEq(guardian, admin);
    }

    function test_ProposalGuardian_CancelPendingAdmin() public {
        Operation[] memory operations = new Operation[](1);
        operations[0].target = address(receiver);
        operations[0].val = 1 ether;
        operations[0].data = abi.encodeWithSelector(CallReceiverMock.mockFunction.selector);
        string memory description = "<proposal description>";
        bytes32 descriptionHash = keccak256(bytes(description));
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) = _operationsToArrays(operations);

        vm.prank(owner);
        payable(continuumDAO).transfer(1 ether);

        uint256 _proposalId = _propose(owner, operations, description);

        assertEq(uint8(continuumDAO.state(_proposalId)), uint8(IGovernor.ProposalState.Pending));

        // INFO: admin can cancel during pending state
        vm.prank(admin);
        continuumDAO.cancel(targets, values, calldatas, descriptionHash);

        assertEq(uint8(continuumDAO.state(_proposalId)), uint8(IGovernor.ProposalState.Canceled));
    }

    function test_ProposalGuardian_CancelActiveAdmin() public {
        Operation[] memory operations = new Operation[](1);
        operations[0].target = address(receiver);
        operations[0].val = 1 ether;
        operations[0].data = abi.encodeWithSelector(CallReceiverMock.mockFunction.selector);
        string memory description = "<proposal description>";
        bytes32 descriptionHash = keccak256(bytes(description));
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) = _operationsToArrays(operations);

        vm.prank(owner);
        payable(continuumDAO).transfer(1 ether);

        uint256 _proposalId = _propose(owner, operations, description);

        _waitForSnapshot(_proposalId);

        assertEq(uint8(continuumDAO.state(_proposalId)), uint8(IGovernor.ProposalState.Active));

        // INFO: admin can cancel during active state
        vm.prank(admin);
        continuumDAO.cancel(targets, values, calldatas, descriptionHash);

        assertEq(uint8(continuumDAO.state(_proposalId)), uint8(IGovernor.ProposalState.Canceled));
    }

    function test_ProposalGuardian_CancelSucceededAdmin() public {
        Operation[] memory operations = new Operation[](1);
        operations[0].target = address(receiver);
        operations[0].val = 1 ether;
        operations[0].data = abi.encodeWithSelector(CallReceiverMock.mockFunction.selector);
        string memory description = "<proposal description>";
        bytes32 descriptionHash = keccak256(bytes(description));
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) = _operationsToArrays(operations);

        vm.prank(owner);
        payable(continuumDAO).transfer(1 ether);

        uint256 _proposalId = _propose(owner, operations, description);

        _waitForSnapshot(_proposalId);

        _castVote(_proposalId, owner, GovernorCountingMultiple.VoteTypeSimple.For);

        _waitForDeadline(_proposalId);

        assertEq(uint8(continuumDAO.state(_proposalId)), uint8(IGovernor.ProposalState.Succeeded));

        // INFO: admin can cancel during succeeded state
        vm.prank(admin);
        continuumDAO.cancel(targets, values, calldatas, descriptionHash);

        assertEq(uint8(continuumDAO.state(_proposalId)), uint8(IGovernor.ProposalState.Canceled));
    }

    function test_ProposalGuardian_CancelPendingProposer() public {
        Operation[] memory operations = new Operation[](1);
        operations[0].target = address(receiver);
        operations[0].val = 1 ether;
        operations[0].data = abi.encodeWithSelector(CallReceiverMock.mockFunction.selector);
        string memory description = "<proposal description>";
        bytes32 descriptionHash = keccak256(bytes(description));
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) = _operationsToArrays(operations);

        vm.prank(owner);
        payable(continuumDAO).transfer(1 ether);

        uint256 _proposalId = _propose(owner, operations, description);

        assertEq(uint8(continuumDAO.state(_proposalId)), uint8(IGovernor.ProposalState.Pending));

        // INFO: proposer can cancel during pending state
        vm.prank(owner);
        continuumDAO.cancel(targets, values, calldatas, descriptionHash);

        assertEq(uint8(continuumDAO.state(_proposalId)), uint8(IGovernor.ProposalState.Canceled));
    }

    function test_ProposalGuardian_CancelActiveProposer() public {
        Operation[] memory operations = new Operation[](1);
        operations[0].target = address(receiver);
        operations[0].val = 1 ether;
        operations[0].data = abi.encodeWithSelector(CallReceiverMock.mockFunction.selector);
        string memory description = "<proposal description>";
        bytes32 descriptionHash = keccak256(bytes(description));
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) = _operationsToArrays(operations);

        vm.prank(owner);
        payable(continuumDAO).transfer(1 ether);

        uint256 _proposalId = _propose(owner, operations, description);

        _waitForSnapshot(_proposalId);

        assertEq(uint8(continuumDAO.state(_proposalId)), uint8(IGovernor.ProposalState.Active));

        // INFO: proposer can cancel during active state
        vm.prank(owner);
        continuumDAO.cancel(targets, values, calldatas, descriptionHash);

        assertEq(uint8(continuumDAO.state(_proposalId)), uint8(IGovernor.ProposalState.Canceled));
    }

    function test_ProposalGuardian_CancelSucceededProposer() public {
        Operation[] memory operations = new Operation[](1);
        operations[0].target = address(receiver);
        operations[0].val = 1 ether;
        operations[0].data = abi.encodeWithSelector(CallReceiverMock.mockFunction.selector);
        string memory description = "<proposal description>";
        bytes32 descriptionHash = keccak256(bytes(description));
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) = _operationsToArrays(operations);

        vm.prank(owner);
        payable(continuumDAO).transfer(1 ether);

        uint256 _proposalId = _propose(owner, operations, description);

        _waitForSnapshot(_proposalId);

        _castVote(_proposalId, owner, GovernorCountingMultiple.VoteTypeSimple.For);

        _waitForDeadline(_proposalId);

        assertEq(uint8(continuumDAO.state(_proposalId)), uint8(IGovernor.ProposalState.Succeeded));

        // INFO: proposer can cancel during succeeded state
        vm.prank(owner);
        continuumDAO.cancel(targets, values, calldatas, descriptionHash);

        assertEq(uint8(continuumDAO.state(_proposalId)), uint8(IGovernor.ProposalState.Canceled));
    }
}
