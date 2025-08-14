# CTMDAOGovernor

## Overview

The CTMDAOGovernor contract implements the governance system for the Continuum DAO using veCTM voting power. It combines multiple OpenZeppelin Governor extensions to provide robust DAO governance capabilities with time-weighted voting using veCTM token voting power.

## Contract Details

- **Contract**: `CTMDAOGovernor.sol`
- **Inherits**: Multiple OpenZeppelin Governor extensions
- **License**: MIT
- **Solidity Version**: 0.8.27

## Constructor

### `constructor(address _token)`

Initializes the CTMDAOGovernor contract with the specified token and predefined governance parameters.

**Parameters:**
- `_token` (address): The address of the veCTM voting token

**Behavior:**
- Sets the governor name to "CTMDAOGovernor"
- Configures voting delay: 5 days (432,000 seconds)
- Configures voting period: 10 days (864,000 seconds)
- Sets proposal threshold: 1% of total voting power (1000 basis points)
- Sets quorum threshold: 20% of total voting power
- Configures late quorum extension: 2 days (172,800 seconds)
- Sets up the voting token (veCTM) for voting power calculations

**Governance Parameters:**
- **Voting Delay**: 5 days - Time between proposal creation and voting start
- **Voting Period**: 10 days - Duration of the voting phase
- **Proposal Threshold**: 1% - Minimum voting power required to create a proposal
- **Quorum Threshold**: 20% - Minimum voting power required for a proposal to pass
- **Late Quorum Extension**: 2 days - Additional time if quorum is reached late

## External Functions

### `execute(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash) public payable override returns (uint256)`

Executes a successful proposal that has been voted on and queued.

**Parameters:**
- `targets` (address[]): Array of target addresses for the proposal actions
- `values` (uint256[]): Array of ETH values to send with each action
- `calldatas` (bytes[]): Array of calldata for each action
- `descriptionHash` (bytes32): Hash of the proposal description

**Returns:**
- `uint256`: The proposal ID that was executed

**Behavior:**
- Executes a proposal that has been successfully voted on and queued
- Can only be called after the proposal has passed voting and been queued in the timelock contract
- Delegates to the parent Governor contract's execute function

**Access Control:**
- Public function - any address can execute successful proposals

**Events Emitted:**
- Inherited from OpenZeppelin Governor contract

### `proposalDeadline(uint256 proposalId) public view override returns (uint256)`

Gets the deadline for a proposal, which may be extended by the late quorum prevention mechanism.

**Parameters:**
- `proposalId` (uint256): The ID of the proposal

**Returns:**
- `uint256`: The deadline timestamp for the proposal

**Behavior:**
- Returns the deadline for a proposal
- The deadline may be extended by the late quorum prevention mechanism if the quorum is reached late in the voting period
- Delegates to the parent GovernorPreventLateQuorum contract

## Governance Features

### Multi-Option Proposals
The contract supports multiple-option (Delta) proposals through the inherited `GovernorCountingMultiple` extension:
- Proposals can have an arbitrary number of options
- Each option contains arbitrary operations to perform on-chain
- Top 'x' voted-for options are executed based on the number of winners specified
- Supports single-choice, approval, and weighted voting mechanisms

### Late Quorum Prevention
The contract implements late quorum prevention through the `GovernorPreventLateQuorum` extension:
- If quorum is reached late in the voting period, the voting deadline is extended
- Extension period: 2 days (172,800 seconds)
- Prevents proposals from failing due to late quorum achievement

### Time-Weighted Voting
The contract uses veCTM tokens for voting power:
- Voting power is based on locked CTM tokens and lock duration
- Power decays linearly over the lock duration
- Maximum lock duration: 4 years
- Supports delegation mechanisms

## Integration

### Voting Token Integration
- Integrates with the veCTM (VotingEscrow) contract for voting power calculations
- Uses the `IVotes` interface for voting power queries
- Supports historical voting power lookups for past proposals

### Timelock Integration
- Designed to work with a timelock contract for proposal execution
- Proposals must be queued in the timelock before execution
- Provides security through delayed execution of governance decisions

## Usage

The CTMDAOGovernor contract serves as the primary governance mechanism for the Continuum DAO:

1. **Proposal Creation**: Users with sufficient voting power can create proposals
2. **Voting**: veCTM token holders can vote on proposals using their voting power
3. **Execution**: Successful proposals are executed through the timelock system
4. **Multi-Option Support**: Complex proposals with multiple options are supported
5. **Late Quorum Protection**: Prevents proposal failures due to late quorum achievement

## Security Considerations

- Uses OpenZeppelin's battle-tested Governor implementation
- Implements late quorum prevention to avoid governance paralysis
- Requires timelock for proposal execution to prevent immediate changes
- Uses time-weighted voting power to prevent manipulation
- Supports delegation for improved governance participation
- Implements proper access controls and proposal thresholds
