// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/governance/Governor.sol";

/**
 * @dev Extension of {Governor} for simple, 3 options, vote counting.
 */
abstract contract GovernorCountingAdvanced is Governor {
    /**
     * @dev Supported vote types. Matches Governor Bravo ordering.
     */
    enum VoteType {
        Against,
        For,
        Abstain
    }

    enum ProposalType {
        Basic,
        SingleChoice,
        Approval,
        Weighted
    }

    struct ProposalVote {
        uint256 againstVotes;
        uint256 forVotes;
        uint256 abstainVotes;
        mapping(address voter => bool) hasVoted;
    }

    struct GroupVote {
        mapping(address voter => uint8) voteWeightAllocated;
        mapping(address voter => bool) hasVoted;
    }

    error InvalidVoteWeightPercentage();

    mapping(uint256 proposalId => ProposalVote) private _proposalVotes;
    mapping(uint256 groupId => GroupVote) private _groupVotes;

    mapping(uint256 proposalId => uint256 groupId) internal _proposalGroupId;
    mapping(uint256 groupId => ProposalType) internal _groupType;

    mapping(uint256 groupId => uint256[]) internal _groupProposals;

    /**
     * @dev See {IGovernor-COUNTING_MODE}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function COUNTING_MODE() public pure virtual override returns (string memory) {
        return "support=bravo&quorum=for,abstain";
    }

    /**
     * @dev See {IGovernor-hasVoted}.
     */
    function hasVoted(uint256 proposalId, address account) public view virtual returns (bool) {
        return _proposalVotes[proposalId].hasVoted[account];
    }

    /**
     * @notice GovernorCountingAdvanced
     */
    function hasVotedGroup(uint256 groupId, address account) public view returns (bool) {
        return _groupVotes[groupId].hasVoted[account];
    }

    /**
     * @notice GovernorCountingAdvanced
     */
    function remainingVoteWeight(uint256 groupId, address account) public view returns (uint256) {
        return 100 - _groupVotes[groupId].voteWeightAllocated[account];
    }

    /**
     * @notice GovernorCountingAdvanced
     */
    function groupProposals(uint256 groupId) public view returns (uint256[] memory) {
        return _groupProposals[groupId];
    }

    /**
     * @dev Accessor to the internal vote counts.
     */
    function proposalVotes(
        uint256 proposalId
    ) public view virtual returns (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) {
        ProposalVote storage proposalVote = _proposalVotes[proposalId];
        return (proposalVote.againstVotes, proposalVote.forVotes, proposalVote.abstainVotes);
    }

    /**
     * @dev See {Governor-_quorumReached}.
     */
    function _quorumReached(uint256 proposalId) internal view virtual override returns (bool) {
        ProposalVote storage proposalVote = _proposalVotes[proposalId];

        return quorum(proposalSnapshot(proposalId)) <= proposalVote.forVotes + proposalVote.abstainVotes;
    }

    /**
     * @dev See {Governor-_voteSucceeded}. In this module, the forVotes must be strictly over the againstVotes.
     */
    function _voteSucceeded(uint256 proposalId) internal view virtual override returns (bool) {
        ProposalVote storage proposalVote = _proposalVotes[proposalId];

        return proposalVote.forVotes > proposalVote.againstVotes;
    }

    function _basicVote(
        uint256 proposalId,
        address account,
        uint8 support,
        uint256 weight
    ) internal virtual {
        ProposalVote storage proposalVote = _proposalVotes[proposalId];

        if (proposalVote.hasVoted[account]) {
            revert GovernorAlreadyCastVote(account);
        }
        proposalVote.hasVoted[account] = true;

        if (support == uint8(VoteType.Against)) {
            proposalVote.againstVotes += weight;
        } else if (support == uint8(VoteType.For)) {
            proposalVote.forVotes += weight;
        } else if (support == uint8(VoteType.Abstain)) {
            proposalVote.abstainVotes += weight;
        } else {
            revert GovernorInvalidVoteType();
        }
    }

    function _weightedVote(
        uint256 proposalId,
        address account,
        uint8 support,
        uint256 weight,
        uint8 allocated
    ) internal virtual {
        if (allocated + support > 100 || allocated >= 100) {
            revert InvalidVoteWeightPercentage();
        }
        allocated += support;

        uint256 voteWeight = support * weight * 1 ether / 100 ether;

        _basicVote(proposalId, account, uint8(VoteType.For), voteWeight);
    }

    function _countVote(
        uint256 proposalId,
        address account,
        uint8 support,
        uint256 weight,
        bytes memory // params
    ) internal virtual override {
        uint256 groupId = _proposalGroupId[proposalId];
        ProposalType proposalType = _groupType[groupId];
        GroupVote storage groupVote = _groupVotes[groupId];

        if (proposalType == ProposalType.Basic || proposalType == ProposalType.Approval) {
            _basicVote(proposalId, account, support, weight);
        } else if (proposalType == ProposalType.SingleChoice) {
            if (groupVote.hasVoted[account]) {
                revert GovernorAlreadyCastVote(account);
            }
            _basicVote(proposalId, account, support, weight);
        } else if (proposalType == ProposalType.Weighted) {
            uint8 allocated = groupVote.voteWeightAllocated[account];
            _weightedVote(proposalId, account, support, weight, allocated);
            groupVote.voteWeightAllocated[account] += support;
        } else {
            revert GovernorInvalidVoteType();
        }
        
        // else if (proposalType == ProposalType.Ranked) {
        // }

        groupVote.hasVoted[account] = true;
    }
}
