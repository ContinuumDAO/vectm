// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import {Governor} from "./oz/Governor.sol";

import {GovernorPreventLateQuorum} from "./oz/GovernorPreventLateQuorum.sol";
import {GovernorSettings} from "./oz/GovernorSettings.sol";
import {GovernorStorage} from "./oz/GovernorStorage.sol";
import {GovernorVotes} from "./oz/GovernorVotes.sol";
import {GovernorVotesQuorumFraction} from "./oz/GovernorVotesQuorumFraction.sol";
import {IVotes} from "./oz/IVotes.sol";

import {GovernorCountingMultiple} from "./GovernorCountingMultiple.sol";

/**
 * @title CTMDAOGovernor
 * @notice Governance contract for the Continuum DAO using veCTM voting power
 * @author OpenZeppelin, modified by @patrickcure for ContinuumDAO
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
contract CTMDAOGovernor is
    Governor,
    GovernorSettings,
    GovernorCountingMultiple,
    GovernorStorage,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorPreventLateQuorum
{
    /**
     * @notice Initializes the CTMDAOGovernor contract
     * @param _token The address of the veCTM voting token
     * @dev Sets up the governance contract with predefined parameters:
     * - Voting delay: 5 days
     * - Voting period: 10 days
     * - Proposal threshold: 1% of total voting power
     * - Quorum threshold: 20% of total voting power
     * - Late quorum extension: 2 days
     */
    constructor(address _token)
        Governor("CTMDAOGovernor")
        GovernorSettings(
            432_000,
            /* 5 days */
            864_000,
            /* 10 days */
            1000 /* 1000x % of total voting power: 1000 => 1% */
        )
        GovernorVotes(IVotes(_token))
        GovernorVotesQuorumFraction(20)
        GovernorPreventLateQuorum(172_800 /* 2 days */)
    {}

    /**
     * @notice Executes a successful proposal
     * @param targets Array of target addresses for the proposal actions
     * @param values Array of ETH values to send with each action
     * @param calldatas Array of calldata for each action
     * @param descriptionHash Hash of the proposal description
     * @return The proposal ID that was executed
     * @dev Executes a proposal that has been successfully voted on and queued.
     * This function can only be called after the proposal has passed voting and
     * been queued in the timelock contract.
     */
    function execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public payable override(GovernorCountingMultiple, Governor) returns (uint256) {
        return super.execute(targets, values, calldatas, descriptionHash);
    }

    /**
     * @notice Gets the deadline for a proposal
     * @param proposalId The ID of the proposal
     * @return The deadline timestamp for the proposal
     * @dev Returns the deadline for a proposal, which may be extended by the
     * late quorum prevention mechanism if the quorum is reached late in the voting period.
     */
    function proposalDeadline(uint256 proposalId)
        public
        view
        override(Governor, GovernorPreventLateQuorum)
        returns (uint256)
    {
        return super.proposalDeadline(proposalId);
    }

    /**
     * @notice Creates a new governance proposal
     * @param targets Array of target addresses for the proposal actions
     * @param values Array of ETH values to send with each action
     * @param calldatas Array of calldata for each action
     * @param description Human-readable description of the proposal
     * @return The ID of the newly created proposal
     * @dev Creates a new governance proposal that can be voted on by veCTM token holders.
     * The proposer must meet the minimum proposal threshold requirement.
     */
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public override(Governor, GovernorCountingMultiple) returns (uint256) {
        return super.propose(targets, values, calldatas, description);
    }

    /**
     * @notice Queues a successful proposal for execution
     * @param targets Array of target addresses for the proposal actions
     * @param values Array of ETH values to send with each action
     * @param calldatas Array of calldata for each action
     * @param descriptionHash Hash of the proposal description
     * @return The proposal ID that was queued
     * @dev Queues a proposal that has been successfully voted on for execution
     * in the timelock contract. This is required before the proposal can be executed.
     */
    function queue(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public override(GovernorCountingMultiple, Governor) returns (uint256) {
        return super.queue(targets, values, calldatas, descriptionHash);
    }

    /**
     * @notice Internal function to create a proposal
     * @param targets Array of target addresses for the proposal actions
     * @param values Array of ETH values to send with each action
     * @param calldatas Array of calldata for each action
     * @param description Human-readable description of the proposal
     * @param proposer The address of the proposal creator
     * @return The ID of the newly created proposal
     * @dev Internal function that handles the actual proposal creation logic.
     * This function is called by the public propose function after validation.
     */
    function _propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        address proposer
    ) internal override(Governor, GovernorStorage) returns (uint256) {
        return super._propose(targets, values, calldatas, description, proposer);
    }

    /**
     * @notice Updates the tally for a proposal when late quorum is reached
     * @param proposalId The ID of the proposal to update
     * @dev Internal function that handles late quorum prevention by extending
     * the voting deadline when quorum is reached late in the voting period.
     */
    function _tallyUpdated(uint256 proposalId) internal override(Governor, GovernorPreventLateQuorum) {
        super._tallyUpdated(proposalId);
    }

    /**
     * @notice Gets the current proposal threshold
     * @return The proposal threshold as a percentage of total voting power
     * @dev Returns the proposal threshold which is calculated as a percentage
     * of the total voting power at the time of proposal creation.
     * The threshold is set to 1% of total voting power (1000 basis points).
     *
     * This function ensures that the proposal threshold is always a meaningful
     * percentage of the current total voting power, preventing proposals from
     * being created when voting power is too low.
     */
    function proposalThreshold() public view override(Governor, GovernorSettings) returns (uint256) {
        // proposal threshold is always a percentage of current total voting power
        uint256 proposalThresholdTsPercentage = super.proposalThreshold();
        uint256 totalVotingPower = token().getPastTotalSupply(clock() - 1) * proposalThresholdTsPercentage / 100_000;
        assert(totalVotingPower > 0);
        return totalVotingPower;
    }
}
