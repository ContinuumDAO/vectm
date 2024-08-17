// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import "./GovernorCountingAdvanced.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorStorage.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorPreventLateQuorum.sol";



contract CTMDAOGovernor is 
    Governor, 
    GovernorSettings, 
    GovernorCountingAdvanced,
    GovernorStorage, 
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorPreventLateQuorum
{
    struct Proposal {
        address[] targets;
        uint256[] values;
        bytes[] calldatas;
        string description;
    }

    error GroupExceedsSizeLimit();

    // Governor("CTMDAOGovernor")
    // GovernorSettings(432000 /* 5 days */, 864000 /* 10 days */, 1000 /* 1000x % of total voting power: 1000 => 1% */)
    // GovernorVotes(IVotes(_token))
    // GovernorVotesQuorumFraction(20)
    // GovernorPreventLateQuorum(172800 /* 2 days */)

    constructor(address _token)
        Governor("CTMDAOGovernor")
        GovernorSettings(300 /* 5 minutes */, 43200 /* 12 hours */, 1000 /* 1000x % of total voting power: 1000 => 1% */)
        GovernorVotes(IVotes(_token))
        GovernorVotesQuorumFraction(20)
        GovernorPreventLateQuorum(7200 /* 2 hours */)
    {}

    // The following functions are overrides required by Solidity.

    function votingDelay()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.votingDelay();
    }

    function votingPeriod()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.votingPeriod();
    }

    function quorum(uint256 timepoint)
        public
        view
        override(Governor, GovernorVotesQuorumFraction)
        returns (uint256)
    {
        return super.quorum(timepoint);
    }

    function proposalThreshold()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        // proposal threshold is always a percentage of current total voting power
        uint256 proposalThresholdTsPercentage = super.proposalThreshold();
        uint256 totalVotingPower = token().getPastTotalSupply(clock() - 1) * proposalThresholdTsPercentage / 100000;
        assert(totalVotingPower > 0);
        return totalVotingPower;
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

    function _castVote(
        uint256 proposalId,
        address account,
        uint8 support,
        string memory reason,
        bytes memory params
    ) internal virtual override(Governor, GovernorPreventLateQuorum) returns (uint256) {
        return super._castVote(proposalId, account, support, reason, params);
    }

    function proposalDeadline(
        uint256 proposalId
    ) public view virtual override(Governor, GovernorPreventLateQuorum) returns (uint256) {
        return super.proposalDeadline(proposalId);
    }

    function proposeAdvanced(
        GovernorCountingAdvanced.ProposalType proposalType,
        Proposal[] memory proposals,
        string memory description
    ) public returns (uint256[] memory proposalIds) {
        address proposer = _msgSender();

        if (proposals.length > 256) {
            revert GroupExceedsSizeLimit();
        }

        uint256 groupId = uint256(keccak256(abi.encode(proposals, description)));

        // check description restriction
        for (uint8 i = 0; i < proposals.length; i++) {
            Proposal memory p = proposals[i];
            if (!_isValidDescriptionForProposer(proposer, p.description)) {
                revert GovernorRestrictedProposer(proposer);
            }

            // check proposal threshold
            uint256 proposerVotes = getVotes(proposer, clock() - 1);
            uint256 votesThreshold = proposalThreshold();
            if (proposerVotes < votesThreshold) {
                revert GovernorInsufficientProposerVotes(proposer, proposerVotes, votesThreshold);
            }

            uint256 proposalId = _propose(p.targets, p.values, p.calldatas, p.description, proposer);
            GovernorCountingAdvanced._proposalGroupId[proposalId] = groupId;
            GovernorCountingAdvanced._groupProposals[groupId].push(proposalId);

            proposalIds[i] = proposalId;
        }
        
        GovernorCountingAdvanced._groupType[groupId] = proposalType;
    }
}
