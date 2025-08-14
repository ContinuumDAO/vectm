# GovernorCountingMultiple

## Overview

The GovernorCountingMultiple contract extends the OpenZeppelin Governor system to support multiple-option (Delta) proposals and voting configurations. It allows proposals to have an arbitrary number of options, each containing arbitrary operations to perform on-chain, with the top voted-for options being executed.

## Contract Details

- **Contract**: `GovernorCountingMultiple.sol`
- **Inherits**: `Governor` from OpenZeppelin
- **License**: MIT
- **Solidity Version**: 0.8.27

## Data Structures

### `VoteTypeSimple`
```solidity
enum VoteTypeSimple {
    Against,
    For,
    Abstain
}
```
Enumeration for simple voting types used in Bravo proposals.

### `ProposalVote`
```solidity
struct ProposalVote {
    uint256 totalVotes; // Included for quorum validation
    mapping(uint256 option => uint256) votes;
    mapping(address voter => bool) hasVoted;
}
```
Stores voting data for each proposal, including total votes, option-specific votes, and voter tracking.

### `ProposalConfig`
```solidity
struct ProposalConfig {
    uint256 nOptions;
    uint256 nWinners;
}
```
Stores the configuration for each proposal, including number of options and winners.

### `Metadata`
```solidity
struct Metadata {
    uint256 nOptions;
    uint256 nWinners;
    uint256[] votes;
    uint256[] optionIndices;
    uint256[] winningIndices;
}
```
Contains metadata for Delta proposals, including option indices and winning indices.

### `Operations`
```solidity
struct Operations {
    address[] targets;
    uint256[] values;
    bytes[] calldatas;
}
```
Used to pass operations between functions for proposal execution.

## State Variables

### Mappings
- `_proposalVotes` (mapping(uint256 => ProposalVote)): Stores voting data for each proposal
- `_proposalConfig` (mapping(uint256 => ProposalConfig)): Stores configuration for each proposal

## External Functions

### `propose(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) public virtual override returns (uint256)`

Creates a new proposal with support for both Bravo and Delta voting mechanisms.

**Parameters:**
- `targets` (address[]): Array of target addresses for the proposal actions
- `values` (uint256[]): Array of ETH values to send with each action
- `calldatas` (bytes[]): Array of calldata for each action
- `description` (string): Description of the proposal

**Returns:**
- `uint256`: The proposal ID

**Behavior:**
- Validates proposer permissions and voting power threshold
- Extracts metadata from `calldatas[0]` for Delta proposals
- Validates proposal configuration (nOptions > 1, nWinners > 0, nWinners < nOptions)
- Ensures proposal dimensions are consistent
- Stores proposal configuration for voting tracking

**Delta Proposal Metadata Format:**
- `calldatas[0]` contains metadata in the following format:
  - First 32 bytes: number of options
  - Next 32 bytes: number of winners
  - Remaining bytes: starting indices for each option's data

**Access Control:**
- Requires proposer to meet voting power threshold
- Validates description restrictions

### `execute(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash) public payable virtual override returns (uint256)`

Executes a successful proposal, handling both Bravo and Delta proposals.

**Parameters:**
- `targets` (address[]): Array of target addresses for the proposal actions
- `values` (uint256[]): Array of ETH values to send with each action
- `calldatas` (bytes[]): Array of calldata for each action
- `descriptionHash` (bytes32): Hash of the proposal description

**Returns:**
- `uint256`: The proposal ID that was executed

**Behavior:**
- For Bravo proposals (nOptions = 0): delegates to parent Governor contract
- For Delta proposals: extracts metadata and determines winning options
- Builds operations array containing only winning option operations
- Executes winning operations through the parent Governor contract
- Handles governance call queue management for timelock integration

**Access Control:**
- Requires proposal to be in Succeeded or Queued state
- Public function - any address can execute successful proposals

### `queue(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash) public virtual override returns (uint256)`

Queues a successful proposal for execution, handling both Bravo and Delta proposals.

**Parameters:**
- `targets` (address[]): Array of target addresses for the proposal actions
- `values` (uint256[]): Array of ETH values to send with each action
- `calldatas` (bytes[]): Array of calldata for each action
- `descriptionHash` (bytes32): Hash of the proposal description

**Returns:**
- `uint256`: The proposal ID that was queued

**Behavior:**
- For Bravo proposals (nOptions = 0): delegates to parent Governor contract
- For Delta proposals: extracts metadata and determines winning options
- Builds operations array containing only winning option operations
- Queues winning operations through the parent Governor contract
- Sets proposal execution timestamp

**Access Control:**
- Requires proposal to be in Succeeded state
- Public function - any address can queue successful proposals

### `hasVoted(uint256 proposalId, address account) public view virtual returns (bool)`

Checks if an account has voted on a specific proposal.

**Parameters:**
- `proposalId` (uint256): The proposal ID to check
- `account` (address): The account to check

**Returns:**
- `bool`: Whether the account has voted on the proposal

### `proposalVotes(uint256 proposalId) public view virtual returns (uint256[] memory, uint256)`

Gets the vote counts for each option in a proposal.

**Parameters:**
- `proposalId` (uint256): The proposal ID to query

**Returns:**
- `(uint256[], uint256)`: Array of vote counts for each option and total votes

### `COUNTING_MODE() public pure virtual override returns (string memory)`

Returns the counting mode for the governance system.

**Returns:**
- `string`: "support=bravo&quorum=for,abstain;support=delta&quorum=for"

**Behavior:**
- Indicates support for both Bravo (simple) and Delta (multiple-option) voting
- Bravo quorum includes For and Abstain votes
- Delta quorum includes only For votes

### `proposalConfiguration(uint256 proposalId) public view virtual returns (ProposalConfig memory)`

Gets the configuration for a specific proposal.

**Parameters:**
- `proposalId` (uint256): The proposal ID to query

**Returns:**
- `ProposalConfig`: The proposal configuration including number of options and winners

## Internal Functions

### `_countVote(uint256 proposalId, address account, uint8 support, uint256 totalWeight, bytes memory params) internal virtual override returns (uint256)`

Counts votes for both Bravo and Delta proposals.

**Parameters:**
- `proposalId` (uint256): The proposal ID
- `account` (address): The voting account
- `support` (uint8): Support value (for Bravo voting)
- `totalWeight` (uint256): Total voting weight of the account
- `params` (bytes): Voting parameters (for Delta voting)

**Returns:**
- `uint256`: The total weight counted

**Behavior:**
- For Bravo proposals (nOptions = 0): counts For, Against, or Abstain votes
- For Delta proposals: processes weighted voting across multiple options
- Validates that weights are provided for all options
- Applies weighted voting with precision loss mitigation
- Ensures total applied weight doesn't exceed voter's total weight

**Delta Voting Format:**
- `params` contains 32-byte weight values for each option
- Weights are used to distribute total voting power across options
- At least one non-zero weight must be provided

### `_quorumReached(uint256 proposalId) internal view virtual override returns (bool)`

Checks if quorum has been reached for a proposal.

**Parameters:**
- `proposalId` (uint256): The proposal ID to check

**Returns:**
- `bool`: Whether quorum has been reached

**Behavior:**
- Quorum is reached if total votes cast across all options surpass the quorum threshold
- Works for both Bravo and Delta proposals

### `_voteSucceeded(uint256 proposalId) internal view virtual override returns (bool)`

Determines if a proposal has succeeded.

**Parameters:**
- `proposalId` (uint256): The proposal ID to check

**Returns:**
- `bool`: Whether the proposal has succeeded

**Behavior:**
- For Bravo proposals: succeeds if For votes exceed Against votes
- For Delta proposals: succeeds if any votes have been cast (no clear-cut definition)

### `_getProposalVotes(uint256 proposalId, uint256 nOptions) internal view returns (uint256[] memory)`

Gets the vote counts for each option in a proposal.

**Parameters:**
- `proposalId` (uint256): The proposal ID
- `nOptions` (uint256): Number of options in the proposal

**Returns:**
- `uint256[]`: Array of vote counts for each option

### `_validateProposalDimensions(uint256 nTargets, uint256 nValues, uint256 nCalldatas) internal pure`

Validates that proposal arrays have consistent dimensions.

**Parameters:**
- `nTargets` (uint256): Number of targets
- `nValues` (uint256): Number of values
- `nCalldatas` (uint256): Number of calldatas

**Behavior:**
- Ensures all arrays have the same length
- Reverts if dimensions are inconsistent

### `_validateProposalConfiguration(uint256 nOptions, uint256 nWinners, bytes memory metadata) internal pure`

Validates the proposal configuration for Delta proposals.

**Parameters:**
- `nOptions` (uint256): Number of options
- `nWinners` (uint256): Number of winners
- `metadata` (bytes): Proposal metadata

**Behavior:**
- Ensures nOptions >= 2
- Ensures nWinners > 0
- Ensures nWinners < nOptions
- Reverts if configuration is invalid

### `_extractMetadata(bytes memory metadataBytes) internal pure returns (Metadata memory metadata)`

Extracts metadata from the proposal's calldata.

**Parameters:**
- `metadataBytes` (bytes): Raw metadata bytes

**Returns:**
- `Metadata`: Parsed metadata structure

**Behavior:**
- Extracts number of options and winners from first 64 bytes
- Parses option indices from remaining bytes
- Validates that indices are monotonically increasing
- Reverts if indices are not properly ordered

### `_getWinningIndices(uint256[] memory votes, uint256[] memory optionIndices, uint256 nWinners) internal pure returns (uint256[] memory winningIndices)`

Determines the winning option indices based on vote counts.

**Parameters:**
- `votes` (uint256[]): Vote counts for each option
- `optionIndices` (uint256[]): Starting indices for each option
- `nWinners` (uint256): Number of winners to select

**Returns:**
- `uint256[]`: Array of winning option indices

**Behavior:**
- Finds the top nWinners options by vote count
- Returns the starting indices of winning options
- Handles ties by selecting the first option encountered

### `_buildOperations(Operations memory allOps, Metadata memory metadata) internal pure returns (Operations memory winningOps)`

Builds operations array containing only winning option operations.

**Parameters:**
- `allOps` (Operations): All proposal operations
- `metadata` (Metadata): Proposal metadata with winning indices

**Returns:**
- `Operations`: Operations array containing only winning operations

**Behavior:**
- Extracts operations for winning options based on option indices
- Builds new arrays containing only winning operations
- Maintains operation order within each winning option

### `_countOperations(uint256 allOpsLength, Metadata memory metadata) internal pure returns (uint256 winningOpsLength)`

Calculates the total number of operations for winning options.

**Parameters:**
- `allOpsLength` (uint256): Total number of operations
- `metadata` (Metadata): Proposal metadata with winning indices

**Returns:**
- `uint256`: Number of operations for winning options

**Behavior:**
- Counts operations for each winning option
- Uses option indices to determine operation ranges
- Returns total count for array initialization

## Errors

- `GovernorDeltaInvalidProposal(uint256 nOptions, uint256 nWinners, bytes metadata)`: Invalid Delta proposal configuration
- `GovernorDeltaInvalidVoteParams(bytes params)`: Invalid voting parameters for Delta proposal
- `GovernorNonIncrementingOptionIndices(uint256 nOptions, bytes metadata)`: Non-incrementing option indices in metadata

## Voting Mechanisms

### Bravo Voting (Simple)
- Traditional For/Against/Abstain voting
- Used when nOptions = 0
- Success determined by For votes > Against votes
- Quorum includes For and Abstain votes

### Delta Voting (Multiple-Option)
- Supports arbitrary number of options
- Each option contains multiple on-chain operations
- Weighted voting across options
- Top nWinners options are executed
- Success determined by any votes cast
- Quorum includes only For votes

## Usage

The GovernorCountingMultiple contract enables advanced governance features:

1. **Simple Proposals**: Traditional For/Against voting for straightforward decisions
2. **Complex Proposals**: Multiple-option proposals for complex decisions
3. **Weighted Voting**: Voters can distribute their voting power across options
4. **Flexible Execution**: Only winning options are executed
5. **Backward Compatibility**: Maintains compatibility with standard Governor functionality

## Security Considerations

- Validates proposal configurations to prevent invalid states
- Ensures option indices are properly ordered
- Implements precision loss mitigation for weighted voting
- Maintains proper access controls inherited from Governor
- Validates proposal dimensions to prevent array mismatches
- Uses safe assembly for metadata parsing
