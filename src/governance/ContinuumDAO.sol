// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

// Core
import {Governor} from "./oz/Governor.sol";

// Modules
import {GovernorCountingMultiple} from "./GovernorCountingMultiple.sol";
import {GovernorVotes} from "./oz/GovernorVotes.sol";
import {GovernorVotesQuorumFraction} from "./oz/GovernorVotesQuorumFraction.sol";
import {GovernorSuperQuorum} from "./oz/GovernorSuperQuorum.sol";
import {GovernorVotesSuperQuorumFraction} from "./oz/GovernorVotesSuperQuorumFraction.sol";

// Extensions
import {GovernorSettings} from "./oz/GovernorSettings.sol";
import {GovernorPreventLateQuorum} from "./oz/GovernorPreventLateQuorum.sol";
import {GovernorStorage} from "./oz/GovernorStorage.sol";
import {GovernorProposalGuardian} from "./oz/GovernorProposalGuardian.sol";

/**
 * @title ContinuumDAO
 * @author OpenZeppelin, modified by @patrickcure for ContinuumDAO
 * @notice Governance contract for the Continuum DAO using veCTM voting power
 * @dev This contract implements a comprehensive governance system that combines multiple
 * OpenZeppelin Governor extensions to provide robust DAO governance capabilities.
 *
 * Key features:
 * - Multi-signature proposal execution with customizable thresholds
 * - Time-weighted voting using veCTM token voting power
 * - Late quorum prevention mechanism
 * - Configurable proposal and voting periods
 * - Support for multiple proposal types and execution methods
 * - Integration with veCTM voting escrow system
 *
 * Governance parameters:
 * - Voting delay: 5 days (432,000 seconds)
 * - Voting period: 10 days (864,000 seconds)
 * - Proposal threshold: 1% of total voting power (1000 basis points)
 * - Quorum threshold: 20% of total voting power
 * - Late quorum extension: 2 days (172,800 seconds)
 *
 * The contract inherits from multiple OpenZeppelin Governor extensions to provide
 * a complete governance solution with advanced features like late quorum prevention
 * and multiple counting mechanisms.
 */
contract ContinuumDAO is
    GovernorCountingMultiple,
    GovernorSettings,
    GovernorVotesSuperQuorumFraction,
    GovernorPreventLateQuorum,
    GovernorProposalGuardian,
    GovernorStorage
{
    error GovernorInvalidProposalThreshold(uint256 _proposalThresholdNumerator, uint256 _proposalThresholdDenominator);

    uint256 public proposalThresholdNumerator;
    uint256 public proposalThresholdDenominator;

    /**
     * @notice Initializes the ContinuumDAO contract
     * @param _token The address of the veCTM voting token
     * @dev Sets up the governance contract with predefined parameters:
     * - Name: ContinuumDAO
     * - Voting delay: 5 days
     * - Voting period: 10 days
     * - Proposal threshold: 1% of total voting power (with a minimum of 1000 CTM @ 4 years)
     * - Quorum: 20% of total voting power
     * - Super Quorum: 80% of total voting power
     * - Late quorum extension: 2 days
     * - Proposal Guardian: proposers may cancel their proposal BEFORE snapshot, admin can cancel at any point
     */
    constructor(address _token, address _proposalGuardian)
        Governor("ContinuumDAO")
        GovernorSettings(5 days, 10 days, 1000 ether) // voting delay / voting period / minimum voting power threshold
        GovernorVotes(IVotes(_token))
        GovernorVotesQuorumFraction(20)
        GovernorVotesSuperQuorumFraction(80)
        GovernorPreventLateQuorum(2 days) // 2 days
        GovernorProposalGuardian()
    {
        _setProposalGuardian(_proposalGuardian);
        proposalThresholdNumerator = 1000;
        proposalThresholdDenominator = 100_000;
    }

    function queue(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public override(Governor, GovernorCountingMultiple) returns (uint256) {
        return super.queue(targets, values, calldatas, descriptionHash);
    }

    function execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public payable override(Governor, GovernorCountingMultiple) returns (uint256) {
        return super.execute(targets, values, calldatas, descriptionHash);
    }

    function proposalDeadline(uint256 proposalId)
        public
        view
        override(Governor, GovernorPreventLateQuorum)
        returns (uint256)
    {
        return super.proposalDeadline(proposalId);
    }

    function proposalThreshold() public view override(Governor, GovernorSettings) returns (uint256) {
        // proposal threshold is always a percentage of current total voting power, with a minimum constant value
        uint256 thresholdNum = proposalThresholdNumerator;
        uint256 thresholdDenom = proposalThresholdDenominator;
        uint256 totalVotingPower = token().getPastTotalSupply(clock() - 1) * thresholdNum / thresholdDenom;
        uint256 thresholdBase = super.proposalThreshold();
        if (totalVotingPower < thresholdBase) {
            totalVotingPower = thresholdBase;
        }
        return totalVotingPower;
    }

    function proposalVotes(uint256 proposalId)
        public
        view
        override
        returns (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes)
    {
        ProposalConfig memory proposalConfig = _proposalConfig[proposalId];
        ProposalVote storage proposalVote = _proposalVotes[proposalId];

        if (proposalConfig.nOptions == 0) {
            // INFO: Bravo voting
            againstVotes = proposalVote.votes[uint8(VoteTypeSimple.Against)];
            forVotes = proposalVote.votes[uint8(VoteTypeSimple.For)];
            abstainVotes = proposalVote.votes[uint8(VoteTypeSimple.Abstain)];
        } else {
            // INFO: Delta voting
            againstVotes = 0;
            forVotes = proposalVote.totalVotes;
            abstainVotes = 0;
        }
    }

    function state(uint256 proposalId)
        public
        view
        override(Governor, GovernorVotesSuperQuorumFraction)
        returns (ProposalState)
    {
        return super.state(proposalId);
    }

    function _propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        address proposer
    ) internal override(Governor, GovernorStorage, GovernorCountingMultiple) returns (uint256) {
        return super._propose(targets, values, calldatas, description, proposer);
    }

    function _tallyUpdated(uint256 proposalId) internal override(Governor, GovernorPreventLateQuorum) {
        super._tallyUpdated(proposalId);
    }

    function _validateCancel(uint256 proposalId, address caller)
        internal
        view
        override(Governor, GovernorProposalGuardian)
        returns (bool)
    {
        return super._validateCancel(proposalId, caller);
    }

    function updateProposalThresholdNumerator(uint256 _proposalThresholdNumerator) external onlyGovernance {
        if (_proposalThresholdNumerator > proposalThresholdDenominator) {
            revert GovernorInvalidProposalThreshold(_proposalThresholdNumerator, proposalThresholdDenominator);
        }
        proposalThresholdNumerator = _proposalThresholdNumerator;
    }

    function updateProposalThresholdDenominator(uint256 _proposalThresholdDenominator) external onlyGovernance {
        proposalThresholdDenominator = _proposalThresholdDenominator;
    }
}
