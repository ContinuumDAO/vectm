// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import {Governor} from "./oz/Governor.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";

error GovernorDeltaInvalidProposal(uint256 nOptions, uint256 nWinners, bytes metadata);
error GovernorDeltaInvalidVoteParams(bytes params);
error GovernorNonIncrementingOptionIndices(uint256 nOptions, bytes metadata);
error GovernorDeltaOutOfBounds(uint256 limit, uint256 index);

/**
 * @title GovernorCountingMultiple
 * @author @patrickcure for ContinuumDAO
 * @dev Extension of {Governor} for multiple-option (Delta) proposals and voting configurations.
 * Proposals can have an arbitrary number of options, each containing arbitrary operations to perform on-chain.
 * These proposals are accompanied by a number of 'winners', meaning the top 'x' voted-for options are executed.
 * Voting for such proposals can vary based on the voter's wish:
 * - Single-choice: cast all available votes to a single option,
 * - Approval: cast available votes equally among all options, or
 * - Weighted: attribute 'weightings' to some or all of the options, with a proportion of available votes.
 *
 * This module was built following an initial design GovernorCountingMultipleV1, where the `support` parameter in
 * count vote was used as a bitmap with the options to vote for encoded in the 8-bit value. This limited the number
 * of options to 8.
 *
 * The difference between this module and GovernorCountingMultipleV1 is that it places no restriction
 * on the number of options or winners. This is achieved by:
 * 1. Specifying the proposal information (number of options and number of winners) in the first bytes value of the
 *    `calldatas` input to `propose`, `queue` and `execute`.
 * 2. The number of options and number of winners can be extracted from this, as well as the start indices of each
 *    option's on-chain operations.
 * 3. When voting, {Governor-castVoteWithParams} must be used (for multiple-option (Delta) voting). This `params` field
 * contains
 *    a non-zero value for each option that the voter wishes to vote for, along with weighting coefficients.
 * 4. If the `params` field is empty (or if {Governor-castVote} is used), the vote will be assumed to be Bravo.
 * 4. If the proposal's number of options is non-zero, the params field must be defined and populated with 32-byte
 *    weighting coefficients.
 *
 * @custom:security-considerations
 * 1. Weight Precision: When using weighted voting, there is (POTENTIAL) inherent precision loss due to integer
 * division.
 *    This loss of precision is negligible, but can be mitigated by using weightings the sum of which is a factor of
 *    the voter's total votes.
 * 2. Front-Running: In scenarios with high-value proposals, voters might observe others' votes and
 *    adjust their voting strategy accordingly, as votes are visible on-chain.
 * 3. Memory Usage: The contract assumes reasonable bounds for nOptions and nWinners (as well as the size of on-chain
 *    operations within each option) to prevent excessive memory usage. The upper bounds are not enforced in
 *    `_validateProposalConfiguration`.
 */
abstract contract GovernorCountingMultiple is Governor {
    enum VoteTypeSimple {
        Against,
        For,
        Abstain
    }

    /// @notice Proposal data stored for every proposal
    struct ProposalVote {
        uint256 totalVotes; // INFO: this is included for quorum validation
        mapping(uint256 option => uint256) votes;
        mapping(address voter => bool) hasVoted;
    }

    /// @notice Metadata describing the number of options and number of winners, stored for multiple-option proposals
    struct ProposalConfig {
        uint256 nOptions;
        uint256 nWinners;
    }

    /**
     * @notice Data structure used in memory to describe proposal data between operations
     * @dev `optionIndices` contains the starting index of each option's data in the overall targets/values/calldatas
     * arrays. winningIndices contains the top nWinners by vote option starting indices.
     */
    struct Metadata {
        uint256 nOptions;
        uint256 nWinners;
        uint256[] votes;
        uint256[] optionIndices;
        uint256[] winningIndices;
    }

    /// @notice Data structure used in memory to communicate operations efficiently between functions
    struct Operations {
        address[] targets;
        uint256[] values;
        bytes[] calldatas;
    }

    /// @notice Mapping of proposal ID => Proposal Vote (proposal voting data)
    mapping(uint256 => ProposalVote) private _proposalVotes;
    /// @notice Mapping of proposal ID => Proposal Configuration (nOptions, nWinners)
    mapping(uint256 => ProposalConfig) private _proposalConfig;

    /**
     * @notice Override of {Governor-propose} to incorporate multiple-option (Delta) proposals.
     * @param targets Target addresses for every possible outcome. targets[0] should be address(0) if using Delta.
     * @param values Values (ETH) attached for every possible outcome. values[0] should be 0 if using Delta.
     * @param calldatas Calldatas to execute for every possible outcome. In the case of Delta proposals, calldatas[0]
     * should be reserved to store the number of options and number of winners (execute top x of n).
     * @param description The string description for the proposal, eg. for first proposal "#1: Do XYZ."
     * @dev In multiple-option (Delta) voting, each option has its own set of on-chain operations
     * (targets/values/calldatas). Proposal metadata (calldatas[0]) standard introduced:
     * The first bytes32 is used to store the number of options.
     * The second bytes32 is used to store the number of winning options.
     * The subsequent elements contain the starting indices of the option data in the `targets`, `values` and
     * `calldatas` arrays.
     * @return The proposal ID.
     */
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public virtual override returns (uint256) {
        address proposer = _msgSender();

        // check description restriction
        if (!_isValidDescriptionForProposer(proposer, description)) {
            revert GovernorRestrictedProposer(proposer);
        }

        // check proposal threshold
        uint256 votesThreshold = proposalThreshold();
        if (votesThreshold > 0) {
            uint256 proposerVotes = getVotes(proposer, clock() - 1);
            if (proposerVotes < votesThreshold) {
                revert GovernorInsufficientProposerVotes(proposer, proposerVotes, votesThreshold);
            }
        }

        uint256 proposalId = _propose(targets, values, calldatas, description, proposer);

        uint256 nOptions = 0;
        uint256 nWinners = 0;

        // This verifies that the proposal type follows the multiple-option (Delta) pattern.
        // Metadata (options, winners, indices) is stored in the first index of `calldatas`.
        // Without this condition, Delta proposals are not possible.
        if (targets[0] == address(0) && calldatas.length != 0) {
            Metadata memory metadata = _extractMetadata(calldatas[0]);
            (nOptions, nWinners) = (metadata.nOptions, metadata.nWinners);
            // Ensures the proposal configuration is valid
            _validateProposalConfiguration(nOptions, nWinners, calldatas[0]);
            // Ensures none of the indices reference an array location out of bounds
            for (uint8 i = 0; i < metadata.nOptions; i++) {
                if (metadata.optionIndices[i] >= targets.length) {
                    revert GovernorDeltaOutOfBounds(targets.length, metadata.optionIndices[i]);
                }
            }
        }

        // Ensures each option's targets/values/calldatas are equisized
        _validateProposalDimensions(targets.length, values.length, calldatas.length);

        // store proposal vote configuration
        _proposalConfig[proposalId] = ProposalConfig(nOptions, nWinners);

        return proposalId;
    }

    /**
     * @notice Override of {Governor-execute} to include Delta proposal execution.
     * @param targets Target addresses for every possible outcome. targets[0] should be address(0) if using Delta.
     * @param values Values (ETH) attached for every possible outcome. values[0] should be 0 if using Delta.
     * @param calldatas Calldatas to execute for every possible outcome. In the case of Delta proposals, calldatas[0]
     * should be reserved to store the number of options and number of winners (execute top x of n).
     * @param descriptionHash The keccak256 hash of the description hash.
     * @return The proposal ID.
     */
    function execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public payable virtual override returns (uint256) {
        uint256 proposalId = hashProposal(targets, values, calldatas, descriptionHash);

        // Bravo proposal (referencing _proposalConfig because metadata is not yet defined)
        if (_proposalConfig[proposalId].nOptions == 0) {
            return super.execute(targets, values, calldatas, descriptionHash);
        }

        _validateStateBitmap(
            proposalId, _encodeStateBitmap(ProposalState.Succeeded) | _encodeStateBitmap(ProposalState.Queued)
        );

        // mark as executed before calls to avoid reentrancy
        // @dev See additions to {Governor}:
        // this does the following: _proposals[proposalId].executed = true;
        _setProposalExecuted(proposalId);

        Metadata memory metadata = _extractMetadata(calldatas[0]);

        uint256[] memory votes = _getProposalVotes(proposalId, metadata.nOptions);
        metadata.winningIndices = _getWinningIndices(votes, metadata.optionIndices, metadata.nWinners);

        Operations memory allExecOps = Operations(targets, values, calldatas);
        Operations memory winningExecOps = _buildOperations(allExecOps, metadata);

        // before execute: register governance call in queue.
        if (_executor() != address(this)) {
            for (uint256 i = 0; i < winningExecOps.targets.length; ++i) {
                if (winningExecOps.targets[i] == address(this)) {
                    // see additions to {Governor}:
                    // this does the following: _governanceCall.pushBack(keccak256(calldatas[i]));
                    _governanceCallPushBack(keccak256(winningExecOps.calldatas[i]));
                }
            }
        }

        _executeOperations(
            proposalId, winningExecOps.targets, winningExecOps.values, winningExecOps.calldatas, descriptionHash
        );

        // after execute: cleanup governance call queue.
        // NOTE: See additions to {Governor} relating to `_governanceCallEmpty` and `_governanceCallClear`.
        if (_executor() != address(this) && !_governanceCallEmpty()) {
            // this does the following: _governanceCall.clear();
            _governanceCallClear();
        }

        emit ProposalExecuted(proposalId);

        return proposalId;
    }

    /**
     * @notice Override of {Governor-queue} to include Delta proposal queueing.
     * @param targets Target addresses for every possible outcome. targets[0] should be address(0) if using Delta.
     * @param values Values (ETH) attached for every possible outcome. values[0] should be 0 if using Delta.
     * @param calldatas Calldatas to execute for every possible outcome. In the case of Delta proposals, calldatas[0]
     * should be reserved to store the number of options and number of winners (execute top x of n).
     * @param descriptionHash The keccak256 hash of the description hash.
     * @return The proposal ID.
     */
    function queue(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public virtual override returns (uint256) {
        uint256 proposalId = hashProposal(targets, values, calldatas, descriptionHash);

        // Bravo proposal (referencing _proposalConfig because metadata is not yet defined)
        if (_proposalConfig[proposalId].nOptions == 0) {
            return super.queue(targets, values, calldatas, descriptionHash);
        }

        // ensure proposal has succeeded
        _validateStateBitmap(proposalId, _encodeStateBitmap(ProposalState.Succeeded));

        Metadata memory metadata = _extractMetadata(calldatas[0]);

        // only want to queue the successful operations
        uint256[] memory votes = _getProposalVotes(proposalId, metadata.nOptions);
        metadata.winningIndices = _getWinningIndices(votes, metadata.optionIndices, metadata.nWinners);

        Operations memory allQueueOps = Operations(targets, values, calldatas);
        Operations memory winningQueueOps = _buildOperations(allQueueOps, metadata);

        uint48 etaSeconds = _queueOperations(
            proposalId, winningQueueOps.targets, winningQueueOps.values, winningQueueOps.calldatas, descriptionHash
        );

        if (etaSeconds != 0) {
            // See additions to {Governor}:
            // this does the following: _proposals[proposalId].etaSeconds = etaSeconds;
            _setProposalEtaSeconds(proposalId, etaSeconds);
            emit ProposalQueued(proposalId, etaSeconds);
        } else {
            revert GovernorQueueNotImplemented();
        }

        return proposalId;
    }

    /// @inheritdoc IGovernor
    function hasVoted(uint256 proposalId, address account) public view virtual returns (bool) {
        return _proposalVotes[proposalId].hasVoted[account];
    }

    /**
     * @notice Accessor to the internal vote counts.
     * @param proposalId The proposal ID in question.
     * @return The number of votes cast for each option and the total number of votes for the proposal.
     */
    function proposalVotes(uint256 proposalId) public view virtual returns (uint256[] memory, uint256) {
        ProposalVote storage proposalVote = _proposalVotes[proposalId];
        uint256 totalVotes = proposalVote.totalVotes;
        uint256[] memory votes = _getProposalVotes(proposalId, _proposalConfig[proposalId].nOptions);
        return (votes, totalVotes);
    }

    /// @inheritdoc IGovernor
    // solhint-disable-next-line func-name-mixedcase
    function COUNTING_MODE() public pure virtual override returns (string memory) {
        return "support=bravo&quorum=for,abstain;support=delta&quorum=for";
    }

    /**
     * @notice Number of options and number of winning options in a proposal.
     * @param proposalId The proposal ID in question.
     * @return The number of options and number of top options that will be executed for a proposal.
     */
    function proposalConfiguration(uint256 proposalId) public view virtual returns (ProposalConfig memory) {
        return _proposalConfig[proposalId];
    }

    /**
     * @notice Override of the {Governor-_countVote} to handle voting on Delta proposals.
     * @param proposalId The proposal ID in question.
     * @param account The address of the voter.
     * @param support Redundant for Delta voting, as it is already encoded in the params field.
     * Support is still used for Bravo-type voting.
     * @param totalWeight The total weight of the voter, used as the denominator when using Delta-type voting.
     * @param params In Delta-type voting, `params` serves as the numerators (coefficients) to cast for each option.
     * The params bytes string should be passed in as ABI-encoded uint256 values.
     * @dev When using weighted voting, there may be minor precision loss due to integer division in the weight calculation
     * (totalWeight * weights[i] / weightDenominator). This can be mitigated by selecting weightings whose denominator
     * add up to a factor of `totalWeight`.
     * @return The total weight cast during this operation
     */
    function _countVote(uint256 proposalId, address account, uint8 support, uint256 totalWeight, bytes memory params)
        internal
        virtual
        override
        returns (uint256)
    {
        ProposalVote storage proposalVote = _proposalVotes[proposalId];
        ProposalConfig memory proposalConfig = _proposalConfig[proposalId];

        if (proposalVote.hasVoted[account]) {
            revert GovernorAlreadyCastVote(account);
        }
        proposalVote.hasVoted[account] = true;

        if (proposalConfig.nOptions == 0) {
            // Bravo voting
            if (support == uint8(VoteTypeSimple.Against)) {
                proposalVote.votes[uint8(VoteTypeSimple.Against)] += totalWeight;
            } else if (support == uint8(VoteTypeSimple.For)) {
                proposalVote.votes[uint8(VoteTypeSimple.For)] += totalWeight;
                proposalVote.totalVotes += totalWeight;
            } else if (support == uint8(VoteTypeSimple.Abstain)) {
                proposalVote.votes[uint8(VoteTypeSimple.Abstain)] += totalWeight;
                proposalVote.totalVotes += totalWeight;
            } else {
                revert GovernorInvalidVoteType();
            }
        } else {
            // a weighting must be provided for every option, even if it is zero
            if (params.length / 32 != proposalConfig.nOptions) {
                revert GovernorDeltaInvalidVoteParams(params);
            }

            uint256 weightDenominator = 0;
            uint256[] memory weights = new uint256[](proposalConfig.nOptions);

            for (uint256 i = 0; i < proposalConfig.nOptions; i++) {
                uint256 weight;
                assembly ("memory-safe") {
                    // load weight data - add 0x20 to skip length prefix of bytes array
                    let pos := add(add(params, 0x20), mul(i, 0x20)) // offset by full 32-byte slots
                    weight := mload(pos)
                }
                weightDenominator += weight;
                weights[i] = weight;
            }

            // Ensure at least one non-zero weight was provided
            if (weightDenominator == 0) {
                revert GovernorDeltaInvalidVoteParams(params);
            }

            uint256 totalAppliedWeight = 0;

            // Iterate through each supported option and apply the specified weight to totalWeight
            for (uint256 i = 0; i < proposalConfig.nOptions; i++) {
                if (weights[i] != 0) {
                    // Applied weight = totalWeight * weight_i / sum(weight_i)
                    uint256 appliedWeight = (totalWeight * weights[i]) / weightDenominator;
                    proposalVote.votes[i] += appliedWeight;
                    totalAppliedWeight += appliedWeight;
                }
            }

            // Ensure the total vote weights applied are not greater than the voter's total weight
            assert(totalAppliedWeight <= totalWeight);

            // Increment totalVotes by totalAppliedWeight to take into account possible precision loss
            proposalVote.totalVotes += totalAppliedWeight;
        }

        return totalWeight;
    }

    /**
     * @inheritdoc Governor
     * @dev In this module, quorum is considered to be reached if the total votes cast across every option on the
     * proposal surpass the quorum at snapshot.
     */
    function _quorumReached(uint256 proposalId) internal view virtual override returns (bool) {
        ProposalVote storage proposalVote = _proposalVotes[proposalId];

        return quorum(proposalSnapshot(proposalId)) <= proposalVote.totalVotes;
    }

    /**
     * @notice Determines whether a vote has succeeded.
     * @param proposalId The proposal ID in question.
     * @dev See {Governor-_voteSucceeded}. This module is a superset of {GovernorCountingSimple}, with
     * multiple-option (Delta) proposals not having such a clear-cut definition of 'success'. Therefore, any Delta
     * proposal that votes have been cast on at all is deemed 'successful'. Bravo proposals are successful if the 'for'
     * votes exceed the 'against' votes.
     * @return True if the proposal has succeeded, false otherwise.
     */
    function _voteSucceeded(uint256 proposalId) internal view virtual override returns (bool) {
        ProposalVote storage proposalVote = _proposalVotes[proposalId];
        if (_proposalConfig[proposalId].nOptions == 0) {
            return
                bool(proposalVote.votes[uint8(VoteTypeSimple.For)] > proposalVote.votes[uint8(VoteTypeSimple.Against)]);
        } else {
            return bool(proposalVote.totalVotes > 0);
        }
    }

    /**
     * @notice Loads the vote count for each option into memory
     * @param proposalId The proposal ID in question.
     * @param nOptions The number of options in the proposal.
     * @return The number of votes cast for each option in the proposal.
     */
    function _getProposalVotes(uint256 proposalId, uint256 nOptions) internal view returns (uint256[] memory) {
        ProposalVote storage proposalVote = _proposalVotes[proposalId];
        uint256[] memory votes = new uint256[](nOptions);

        for (uint256 i = 0; i < nOptions; i++) {
            votes[i] = proposalVote.votes[i];
        }

        return votes;
    }

    /**
     * @notice Validates the dimensions of the proposal's execution data.
     * @param nTargets The number of target addresses for every option in the proposal.
     * @param nValues The number of values attached for every option in the proposal.
     * @param nCalldatas The number of calldatas executable for every option in the proposal.
     */
    function _validateProposalDimensions(uint256 nTargets, uint256 nValues, uint256 nCalldatas) internal pure {
        if (nTargets != nValues || nValues != nCalldatas) {
            revert GovernorInvalidProposalLength(nTargets, nCalldatas, nValues);
        }
    }

    /**
     * @notice Validates the proposal's configuration, regarding number of options and number of winners.
     * @param nOptions The number of options in the proposal.
     * @param nWinners The number of winners in the proposal.
     * @param metadata This is included here because it is useful for debugging.
     * @dev The following cases must be true: nOptions > 1, nWinners > 0, nWinners < nOptions.
     * @dev No upper limit is imposed on the number of options or winners.
     */
    function _validateProposalConfiguration(uint256 nOptions, uint256 nWinners, bytes memory metadata) internal pure {
        if (nOptions < 2 || nWinners == 0 || nWinners >= nOptions) {
            revert GovernorDeltaInvalidProposal(nOptions, nWinners, metadata);
        }
    }

    /**
     * @notice Deconstruct the incoming `calldatas[0]` bytes string into a metadata object.
     * @param metadataBytes The bytes string encoded with number of options, number of winners and location indices.
     * @return metadata The decoded metadata object.
     */
    function _extractMetadata(bytes memory metadataBytes) internal pure returns (Metadata memory metadata) {
        // extract first 32 bytes for nOptions and next 32 bytes for nWinners
        bytes32 nOptionsBytes;
        bytes32 nWinnersBytes;
        assembly ("memory-safe") {
            nOptionsBytes := mload(add(metadataBytes, 0x20)) // skip length prefix
            nWinnersBytes := mload(add(metadataBytes, 0x40))
        }

        metadata.nOptions = uint256(nOptionsBytes);
        metadata.nWinners = uint256(nWinnersBytes);

        // Initialize array for option indices
        metadata.optionIndices = new uint256[](metadata.nOptions);

        // Read indices in remainder of metadataBytes
        //   0 = length prefix
        //  32 = nOptions
        //  64 = nWinners
        //  96 = index of option 0
        // 128 = index of option 1
        // ...
        // 96+(n*32) = index of option n
        for (uint256 i = 0; i < metadata.nOptions; i++) {
            uint256 offset = 96 + (i * 32);
            bytes32 optionIndexBytes;
            assembly ("memory-safe") {
                optionIndexBytes := mload(add(metadataBytes, offset))
            }
            metadata.optionIndices[i] = uint256(optionIndexBytes);

            // Validate that indices are monotonically increasing
            if (i > 0) {
                if (metadata.optionIndices[i] <= metadata.optionIndices[i - 1]) {
                    revert GovernorNonIncrementingOptionIndices(metadata.nOptions, metadataBytes);
                }
            }
        }
    }

    /**
     * @notice Get the top `nWinners` option indices, ordered by the number of votes each option obtained.
     * @param votes The array of amount of votes cast for each option
     * @param optionIndices The index of each option as it is structured in the (targets/values/calldatas) arrays.
     * @param nWinners The number of winners declarable for this proposal.
     * @return winningIndices The indices of the winning options for this proposal.
     */
    function _getWinningIndices(uint256[] memory votes, uint256[] memory optionIndices, uint256 nWinners)
        internal
        pure
        returns (uint256[] memory winningIndices)
    {
        winningIndices = new uint256[](nWinners);

        // Searches for the location of option with highest votes, sets it to zero, repeats up to nWinners
        for (uint256 i = 0; i < nWinners; i++) {
            uint256 maxVotes = 0;
            uint256 maxIndex = 0;
            for (uint256 j = 0; j < votes.length; j++) {
                if (votes[j] > maxVotes) {
                    maxVotes = votes[j];
                    maxIndex = j;
                }
            }
            winningIndices[i] = optionIndices[maxIndex];
            votes[maxIndex] = 0;
        }
    }

    /**
     * @notice Using the winning indices, extract the corresponding members of the targets/values/calldatas arrays and
     * prepare them for queueing/execution.
     * @param allOps The total list of all operations that were presented for this proposal, made up of constituent
     * (targets/values/calldatas) arrays.
     * @param metadata The object with proposal metadata (nOptions/nWinners) decoded from the metadata bytes string.
     * @return winningOps The extracted list of `nWinners` operations that were successful and eligible for execution.
     */
    function _buildOperations(Operations memory allOps, Metadata memory metadata)
        internal
        pure
        returns (Operations memory winningOps)
    {
        // First, calculate the total length needed
        uint256 winningOpsLength = _countOperations(allOps.targets.length, metadata);

        // Initialize arrays with correct length
        winningOps.targets = new address[](winningOpsLength);
        winningOps.values = new uint256[](winningOpsLength);
        winningOps.calldatas = new bytes[](winningOpsLength);

        // Populate the execution arrays
        uint256 execIndex = 0;
        for (uint256 i = 0; i < metadata.nWinners; i++) {
            // solhint-disable-next-line var-name-mixedcase
            uint256 winningIndex_i = metadata.winningIndices[i];
            for (uint256 j = 0; j < metadata.nOptions; j++) {
                uint256 lower = metadata.optionIndices[j];
                if (lower == winningIndex_i) {
                    uint256 upper = j == metadata.nOptions - 1 ? allOps.targets.length : metadata.optionIndices[j + 1];
                    for (uint256 k = lower; k < upper; k++) {
                        winningOps.targets[execIndex] = allOps.targets[k];
                        winningOps.values[execIndex] = allOps.values[k];
                        winningOps.calldatas[execIndex] = allOps.calldatas[k];
                        execIndex++;
                    }
                }
            }
        }
    }

    /**
     * @notice Finds the length of the successful on-chain operations.
     * @param allOpsLength The total list of operations combined across all proposal options.
     * @param metadata The object with proposal metadata (nOptions/nWinners) decoded from the metadata bytes string.
     * @return winningOpsLength The total number of operations that were successful in the
     * voting round and are eligible for execution.
     * @dev This is required to enable building of the executable operations.
     */
    function _countOperations(uint256 allOpsLength, Metadata memory metadata)
        internal
        pure
        returns (uint256 winningOpsLength)
    {
        for (uint256 i = 0; i < metadata.nWinners; i++) {
            // solhint-disable-next-line var-name-mixedcase
            uint256 winningIndex_i = metadata.winningIndices[i];
            for (uint256 j = 0; j < metadata.nOptions; j++) {
                uint256 lower = metadata.optionIndices[j];
                if (lower == winningIndex_i) {
                    uint256 upper = j == metadata.nOptions - 1 ? allOpsLength : metadata.optionIndices[j + 1];
                    winningOpsLength += (upper - lower);
                    break; // Found the matching option, no need to continue inner loop
                }
            }
        }
    }
}
