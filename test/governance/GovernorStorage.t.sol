// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.27;

import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {GovernorCountingMultiple} from "../../src/governance/GovernorCountingMultiple.sol";
import {GovernorHelpers} from "../helpers/GovernorHelpers.sol";
import {CallReceiverMock} from "../helpers/mocks/CallReceiverMock.sol";

contract TestGovernorStorage is GovernorHelpers {
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

    function test_Storage_State() public {
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

        uint256 proposalCount = continuumDAO.proposalCount();
        assertEq(proposalCount, 1);

        (
            address[] memory targetsSet,
            uint256[] memory valuesSet,
            bytes[] memory calldatasSet,
            bytes32 descriptionHashSet
        ) = continuumDAO.proposalDetails(_proposalId);

        assertEq(targetsSet.length, 1);
        assertEq(valuesSet.length, 1);
        assertEq(calldatasSet.length, 1);
        assertEq(targetsSet[0], targets[0]);
        assertEq(valuesSet[0], values[0]);
        assertEq(calldatasSet[0], calldatas[0]);
        assertEq(descriptionHashSet, descriptionHash);

        (
            uint256 proposalId0,
            address[] memory targetsSet0,
            uint256[] memory valuesSet0,
            bytes[] memory calldatasSet0,
            bytes32 descriptionHashSet0
        ) = continuumDAO.proposalDetailsAt(0);

        assertEq(proposalId0, _proposalId);
        assertEq(targetsSet0.length, 1);
        assertEq(valuesSet0.length, 1);
        assertEq(calldatasSet0.length, 1);
        assertEq(targetsSet0[0], targets[0]);
        assertEq(valuesSet0[0], values[0]);
        assertEq(calldatasSet0[0], calldatas[0]);
        assertEq(descriptionHashSet0, descriptionHash);
    }

    function test_Storage_ExecuteById() public {
        Operation[] memory operations = new Operation[](1);
        operations[0].target = address(receiver);
        operations[0].val = 1 ether;
        operations[0].data = abi.encodeWithSelector(CallReceiverMock.mockFunction.selector);
        string memory description = "<proposal description>";

        vm.prank(owner);
        payable(continuumDAO).transfer(1 ether);

        uint256 _proposalId = _propose(proposer, operations, description);

        assertEq(uint8(continuumDAO.state(_proposalId)), uint8(IGovernor.ProposalState.Pending));

        _waitForSnapshot(_proposalId);

        assertEq(uint8(continuumDAO.state(_proposalId)), uint8(IGovernor.ProposalState.Active));

        _castVote(_proposalId, owner, GovernorCountingMultiple.VoteTypeSimple.For);

        assertEq(uint8(continuumDAO.state(_proposalId)), uint8(IGovernor.ProposalState.Succeeded));

        _waitForDeadline(_proposalId);

        _executeById(owner, _proposalId);
    }

    function test_Storage_CancelById() public {
        Operation[] memory operations = new Operation[](1);
        operations[0].target = address(receiver);
        operations[0].val = 1 ether;
        operations[0].data = abi.encodeWithSelector(CallReceiverMock.mockFunction.selector);
        string memory description = "<proposal description>";

        vm.prank(owner);
        payable(continuumDAO).transfer(1 ether);

        uint256 _proposalId = _propose(proposer, operations, description);

        assertEq(uint8(continuumDAO.state(_proposalId)), uint8(IGovernor.ProposalState.Pending));

        vm.prank(admin);
        continuumDAO.cancel(_proposalId);

        assertEq(uint8(continuumDAO.state(_proposalId)), uint8(IGovernor.ProposalState.Canceled));
    }
}
