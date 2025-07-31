// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

import {Governor} from "./oz/Governor.sol";
import {GovernorSettings} from "./oz/GovernorSettings.sol";
import {GovernorStorage} from "./oz/GovernorStorage.sol";
import {GovernorVotes} from "./oz/GovernorVotes.sol";
import {IVotes} from "./oz/IVotes.sol";
import {GovernorVotesQuorumFraction} from "./oz/GovernorVotesQuorumFraction.sol";
import {GovernorPreventLateQuorum} from "./oz/GovernorPreventLateQuorum.sol";

import {GovernorCountingMultiple} from "./GovernorCountingMultiple.sol";

contract CTMDAOGovernor is 
    Governor, 
    GovernorSettings, 
    GovernorCountingMultiple,
    GovernorStorage, 
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorPreventLateQuorum
{
    // NOTE: Actual deployment parameters
    // Governor("CTMDAOGovernor")
    // GovernorSettings(432000 /* 5 days */, 864000 /* 10 days */, 1000 /* 1000x % of total voting power: 1000 => 1% */)
    // GovernorVotes(IVotes(_token))
    // GovernorVotesQuorumFraction(20)
    // GovernorPreventLateQuorum(172800 /* 2 days */)

    // NOTE: Test parameters
    constructor(address _token)
        Governor("CTMDAOGovernor")
        GovernorSettings(300 /* 5 minutes */, 43200 /* 12 hours */, 1000 /* 1000x % of total voting power: 1000 => 1% */)
        GovernorVotes(IVotes(_token))
        GovernorVotesQuorumFraction(20)
        GovernorPreventLateQuorum(7200 /* 2 hours */)
    {}

    function execute(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash) public payable override(GovernorCountingMultiple, Governor) returns (uint256) {
        return super.execute(targets, values, calldatas, descriptionHash);
    }

    function proposalDeadline(uint256 proposalId) public view override(Governor, GovernorPreventLateQuorum) returns (uint256) {
        return super.proposalDeadline(proposalId);
    }

    function proposalThreshold() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.proposalThreshold();
    }

    function propose(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) public override(Governor, GovernorCountingMultiple) returns (uint256) {
        return super.propose(targets, values, calldatas, description);
    }

    function queue(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash) public override(GovernorCountingMultiple, Governor) returns (uint256) {
        return super.queue(targets, values, calldatas, descriptionHash);
    }

    function _propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        address proposer
    ) internal override(Governor, GovernorStorage) returns (uint256) {
        return super._propose(targets, values, calldatas, description, proposer);
    }

    function _tallyUpdated(uint256 proposalId) internal override(Governor, GovernorPreventLateQuorum) {
        super._tallyUpdated(proposalId);
    }
}
