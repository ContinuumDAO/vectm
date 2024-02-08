// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorStorage.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorPreventLateQuorum.sol";

contract CTMDAOGovernor is 
    Governor, 
    GovernorSettings, 
    GovernorCountingSimple, 
    GovernorStorage, 
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorPreventLateQuorum
{
    constructor(IVotes _token)
        Governor("CTMDAOGovernor")
        GovernorSettings(432000 /* 5 days */, 864000 /* 10 days */, 1000 /* 1000x % of total voting power: 1000 => 1% */)
        GovernorVotes(_token)
        GovernorVotesQuorumFraction(20)
        GovernorPreventLateQuorum(172800 /* 2 days */)
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
        return  totalVotingPower;
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
}
