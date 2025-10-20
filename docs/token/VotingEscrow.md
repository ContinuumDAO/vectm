# VotingEscrow

## Overview

The VotingEscrow contract implements a time-weighted voting escrow system for veCTM tokens. Users lock CTM tokens to receive veCTM NFTs with voting power that decays linearly over time. The system supports both voting and non-voting locks, delegation mechanisms, and integration with governance systems.

## Contract Details

- **Contract**: `VotingEscrow.sol`
- **Inherits**: `IVotingEscrow`, `IERC721`, `IERC5805`, `IERC721Receiver`, `UUPSUpgradeable`
- **License**: GPL-3.0-or-later
- **Solidity Version**: 0.8.27

## Data Structures

### `Point`
```solidity
struct Point {
    int128 bias;
    int128 slope; // # -dweight / dt
    uint256 ts;
    uint256 blk; // block
}
```
Represents a checkpoint point with bias, slope, timestamp, and block number.

### `LockedBalance`
```solidity
struct LockedBalance {
    int128 amount;
    uint256 end;
}
```
Represents the locked balance information for a token ID.

### `DepositType`
```solidity
enum DepositType {
    DEPOSIT_FOR_TYPE,
    CREATE_LOCK_TYPE,
    INCREASE_LOCK_AMOUNT,
    INCREASE_UNLOCK_TIME,
    MERGE_TYPE
}
```
Enumeration of different deposit types for tracking purposes.

## State Variables

### Core Addresses
- `token` (address): Address of the underlying CTM token
- `governor` (address): Address of the governance contract with administrative privileges
- `nodeProperties` (address): Address of the node properties contract for node integration
- `rewards` (address): Address of the rewards contract for reward integration
- `treasury` (address): Address of the treasury contract for penalty collection

### Global State
- `epoch` (uint256): Current epoch number for global checkpoint tracking
- `baseURI` (string): Base URI for NFT metadata
- `_entered_state` (uint8): Reentrancy guard state (1 = not entered, 2 = entered)
- `_supply` (uint256): Total locked token supply
- `tokenId` (uint256): Current token ID counter for NFT minting
- `_totalSupply` (uint256): Total number of NFTs minted

### Mappings
- `locked` (mapping(uint256 => LockedBalance)): Mapping from token ID to locked balance information
- `ownership_change` (mapping(uint256 => uint256)): Mapping from token ID to ownership change timestamp
- `point_history` (mapping(uint256 => Point)): Mapping from epoch to global checkpoint point
- `user_point_history` (mapping(uint256 => Point[1_000_000_000])): Mapping from token ID to user checkpoint history array
- `user_point_epoch` (mapping(uint256 => uint256)): Mapping from token ID to current user epoch
- `slope_changes` (mapping(uint256 => int128)): Mapping from timestamp to slope change for global supply calculations
- `nonVoting` (mapping(uint256 => bool)): Mapping from token ID to non-voting status

### ERC721 Mappings
- `idToOwner` (mapping(uint256 => address)): Mapping from NFT ID to owner address
- `idToApprovals` (mapping(uint256 => address)): Mapping from NFT ID to approved address for transfers
- `ownerToNFTokenCount` (mapping(address => uint256)): Mapping from owner address to token count
- `ownerToNFTokenIdList` (mapping(address => mapping(uint256 => uint256))): Mapping from owner address to index-to-tokenId mapping
- `tokenToOwnerIndex` (mapping(uint256 => uint256)): Mapping from NFT ID to owner's token index
- `ownerToOperators` (mapping(address => mapping(address => bool))): Mapping from owner address to operator approval status
- `supportedInterfaces` (mapping(bytes4 => bool)): Mapping from interface ID to support status for ERC165

### Delegation Mappings
- `_delegatee` (mapping(address => address)): Mapping from account address to delegatee address
- `_delegateCheckpoints` (mapping(address => ArrayCheckpoints.TraceArray)): Mapping from delegatee address to checkpointed token ID arrays
- `_nonces` (mapping(address => uint256)): Mapping from account address to nonce for signature verification

### Constants
- `name` (string): "Voting Escrow Continuum"
- `symbol` (string): "veCTM"
- `version` (string): "1.0.0"
- `decimals` (uint8): 18
- `WEEK` (uint256): 7 * 86_400 (1 week in seconds)
- `MAXTIME` (uint256): 4 * 365 * 86_400 (4 years in seconds)
- `MULTIPLIER` (uint256): 1e18
- `iMAXTIME` (int128): 4 * 365 * 86_400
- `LIQ_PENALTY_NUM` (uint256): 50_000 (50% penalty numerator)
- `LIQ_PENALTY_DEN` (uint256): 100_000 (penalty denominator)
- `liquidationsEnabled` (bool): Flag to enable/disable liquidations

## Constructor

### `constructor()`

Initializes the VotingEscrow contract as a proxy implementation.

**Behavior:**
- Disables initializers for the implementation contract
- This is a proxy pattern contract where the implementation is deployed separately

## Initializer

### `initialize(address token_addr, string memory base_uri) external`

Initializes the VotingEscrow contract with the specified parameters.

**Parameters:**
- `token_addr` (address): The address of the underlying CTM token
- `base_uri` (string): Base URI for NFT metadata

**Behavior:**
- Initializes the UUPS upgradeable contract
- Sets the token address and base URI
- Initializes the global checkpoint with current block and timestamp
- Sets up supported interfaces for ERC165 compliance
- Sets the reentrancy guard state
- Emits initial transfer events

**Access Control:**
- Can only be called once during contract deployment (initializer modifier)

## External Functions

### Lock Management

#### `create_lock(uint256 _value, uint256 _lock_duration) external returns (uint256)`

Creates a voting lock for the caller.

**Parameters:**
- `_value` (uint256): Amount of CTM tokens to lock
- `_lock_duration` (uint256): Number of seconds to lock tokens for (rounded down to nearest week)

**Returns:**
- `tokenId` (uint256): The token ID of the created veCTM NFT

**Behavior:**
- Creates a new veCTM NFT with voting power that decays linearly over the lock duration
- Lock duration is rounded down to the nearest week
- Maximum lock duration is 4 years
- Transfers CTM tokens from caller to contract

**Access Control:**
- Public function - any address can call

#### `create_lock_for(uint256 _value, uint256 _lock_duration, address _to) external returns (uint256)`

Creates a voting lock for a specified address.

**Parameters:**
- `_value` (uint256): Amount of CTM tokens to lock
- `_lock_duration` (uint256): Number of seconds to lock tokens for (rounded down to nearest week)
- `_to` (address): Address to receive the veCTM NFT

**Returns:**
- `tokenId` (uint256): The token ID of the created veCTM NFT

**Behavior:**
- Creates a new veCTM NFT for the specified address with voting power that decays linearly
- Lock duration is rounded down to the nearest week
- Maximum lock duration is 4 years
- Transfers CTM tokens from caller to contract

**Access Control:**
- Public function - any address can call

#### `create_nonvoting_lock_for(uint256 _value, uint256 _lock_duration, address _to) public returns (uint256)`

Creates a non-voting lock for a specified address.

**Parameters:**
- `_value` (uint256): Amount of CTM tokens to lock
- `_lock_duration` (uint256): Number of seconds to lock tokens for (rounded down to nearest week)
- `_to` (address): Address to receive the veCTM NFT

**Returns:**
- `tokenId` (uint256): The token ID of the created veCTM NFT

**Behavior:**
- Creates a new veCTM NFT for the specified address without voting power
- Lock duration is rounded down to the nearest week
- Maximum lock duration is 4 years
- Transfers CTM tokens from caller to contract
- Uses nonreentrant modifier for security

**Access Control:**
- Public function - any address can call

#### `increase_amount(uint256 _tokenId, uint256 _value) external`

Increases the locked amount for an existing lock.

**Parameters:**
- `_tokenId` (uint256): The token ID to increase the lock amount for
- `_value` (uint256): Amount of additional CTM tokens to lock

**Behavior:**
- Adds more tokens to an existing lock without changing the unlock time
- Requires the caller to be the owner or approved operator of the token
- Transfers additional CTM tokens from caller to contract

**Access Control:**
- Requires caller to be owner or approved operator of the token

#### `increase_unlock_time(uint256 _tokenId, uint256 _lock_duration) external`

Increases the unlock time for an existing lock.

**Parameters:**
- `_tokenId` (uint256): The token ID to increase the unlock time for
- `_lock_duration` (uint256): Additional number of seconds to extend the lock

**Behavior:**
- Extends the unlock time for an existing lock
- Requires the caller to be the owner or approved operator of the token
- Lock duration is rounded down to the nearest week
- Maximum total lock duration is 4 years

**Access Control:**
- Requires caller to be owner or approved operator of the token

#### `withdraw(uint256 _tokenId) external`

Withdraws tokens from an expired lock.

**Parameters:**
- `_tokenId` (uint256): The token ID to withdraw from

**Behavior:**
- Withdraws all locked tokens from an expired lock
- Burns the veCTM NFT
- Transfers CTM tokens back to the owner
- Requires the lock to be expired and not attached to a node

**Access Control:**
- Requires caller to be owner or approved operator of the token

#### `merge(uint256 _from, uint256 _to) external`

Merges two locks owned by the same address.

**Parameters:**
- `_from` (uint256): The token ID to merge from (will be burned)
- `_to` (uint256): The token ID to merge into (will receive the combined balance)

**Behavior:**
- Combines the locked amounts of two tokens
- Uses the later unlock time of the two tokens
- Burns the `_from` token
- Updates the `_to` token with combined balance and unlock time
- Both tokens must be owned by the same address
- Both tokens must be of the same type (voting or non-voting)

**Access Control:**
- Requires caller to be owner of both tokens

#### `split(uint256 _tokenId, uint256 _extraction) external returns (uint256)`

Splits a lock into two separate locks.

**Parameters:**
- `_tokenId` (uint256): The token ID to split
- `_extraction` (uint256): Amount to extract into a new lock

**Returns:**
- `extractionId` (uint256): The token ID of the newly created lock

**Behavior:**
- Creates a new lock with the extracted amount
- Reduces the original lock by the extracted amount
- Both locks maintain the same unlock time
- Creates a new veCTM NFT for the extracted amount

**Access Control:**
- Requires caller to be owner or approved operator of the token

#### `liquidate(uint256 _tokenId) external`

Liquidates an expired lock with a penalty.

**Parameters:**
- `_tokenId` (uint256): The token ID to liquidate

**Behavior:**
- Liquidates an expired lock with a 50% penalty
- Burns the veCTM NFT
- Transfers 50% of locked tokens to the owner
- Transfers 50% of locked tokens to the treasury
- Requires liquidations to be enabled

**Access Control:**
- Public function - any address can liquidate expired locks

#### `deposit_for(uint256 _tokenId, uint256 _value) external`

Deposits additional tokens for an existing lock.

**Parameters:**
- `_tokenId` (uint256): The token ID to deposit for
- `_value` (uint256): Amount of additional CTM tokens to deposit

**Behavior:**
- Adds more tokens to an existing lock
- Transfers CTM tokens from caller to contract
- Updates the lock balance and checkpoints

**Access Control:**
- Public function - any address can deposit for any lock

### ERC721 Functions

#### `transferFrom(address _from, address _to, uint256 _tokenId) external`

Transfers a veCTM NFT from one address to another.

**Parameters:**
- `_from` (address): The address to transfer from
- `_to` (address): The address to transfer to
- `_tokenId` (uint256): The token ID to transfer

**Behavior:**
- Transfers the NFT and updates delegation checkpoints
- Requires caller to be owner, approved, or approved operator

**Access Control:**
- Requires caller to be owner, approved, or approved operator

#### `approve(address _approved, uint256 _tokenId) external`

Approves an address to transfer a specific token.

**Parameters:**
- `_approved` (address): The address to approve
- `_tokenId` (uint256): The token ID to approve

**Behavior:**
- Approves the specified address to transfer the token
- Clears any previous approval for the token

**Access Control:**
- Requires caller to be owner or approved operator

#### `setApprovalForAll(address _operator, bool _approved) external`

Approves or revokes approval for an operator to manage all tokens.

**Parameters:**
- `_operator` (address): The operator address
- `_approved` (bool): Whether to approve or revoke approval

**Behavior:**
- Sets or clears approval for an operator to manage all tokens of the caller

**Access Control:**
- Public function - any address can set approval for operators

#### `safeTransferFrom(address _from, address _to, uint256 _tokenId) external`

Safely transfers a token with additional safety checks.

**Parameters:**
- `_from` (address): The address to transfer from
- `_to` (address): The address to transfer to
- `_tokenId` (uint256): The token ID to transfer

**Behavior:**
- Transfers the token with additional safety checks
- Requires caller to be owner, approved, or approved operator

**Access Control:**
- Requires caller to be owner, approved, or approved operator

#### `safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes memory _data) external`

Safely transfers a token with data.

**Parameters:**
- `_from` (address): The address to transfer from
- `_to` (address): The address to transfer to
- `_tokenId` (uint256): The token ID to transfer
- `_data` (bytes): Additional data to pass to the recipient

**Behavior:**
- Transfers the token with additional safety checks and data
- Requires caller to be owner, approved, or approved operator

**Access Control:**
- Requires caller to be owner, approved, or approved operator

### Delegation Functions

#### `delegate(address delegatee) external`

Delegates voting power to another address.

**Parameters:**
- `delegatee` (address): The address to delegate voting power to

**Behavior:**
- Delegates all voting power from caller's tokens to the specified address
- Updates delegation checkpoints
- Clears any previous delegation

**Access Control:**
- Public function - any address can delegate their voting power

#### `delegateBySig(address delegatee, uint256 nonce, uint256 expiry, uint8 v, bytes32 r, bytes32 s) external`

Delegates voting power using a signature.

**Parameters:**
- `delegatee` (address): The address to delegate voting power to
- `nonce` (uint256): The nonce for signature verification
- `expiry` (uint256): The expiry timestamp for the signature
- `v` (uint8): The v component of the signature
- `r` (bytes32): The r component of the signature
- `s` (bytes32): The s component of the signature

**Behavior:**
- Delegates voting power using a signed message
- Verifies the signature and nonce
- Updates delegation checkpoints

**Access Control:**
- Public function - any address can delegate using a valid signature

### Governance Functions

#### `checkpoint() external`

Records global data to checkpoint.

**Behavior:**
- Updates the global checkpoint with current block and timestamp data
- Used to maintain accurate voting power calculations

**Access Control:**
- Public function - any address can trigger a checkpoint

#### `initContracts(address _governor, address _nodeProperties, address _rewards, address _treasury) external`

Initializes contract addresses for integration.

**Parameters:**
- `_governor` (address): The governance contract address
- `_nodeProperties` (address): The node properties contract address
- `_rewards` (address): The rewards contract address
- `_treasury` (address): The treasury contract address

**Behavior:**
- Sets up integration contract addresses
- Can only be called once
- Reverts with InvalidInitialization if governor is already set

**Access Control:**
- Public function - can only be called once

#### `setBaseURI(string memory _baseURI) external`

Sets the base URI for NFT metadata.

**Parameters:**
- `_baseURI` (string): The new base URI

**Behavior:**
- Updates the base URI used for NFT metadata

**Access Control:**
- Only governance can call this function

#### `setLiquidationsEnabled(bool _liquidationsEnabled) external`

Enables or disables liquidations.

**Parameters:**
- `_liquidationsEnabled` (bool): Whether to enable liquidations

**Behavior:**
- Sets the liquidation flag
- Controls whether expired locks can be liquidated

**Access Control:**
- Only governance can call this function

### View Functions

#### `balanceOf(address _owner) external view returns (uint256)`

Gets the number of tokens owned by an address.

**Parameters:**
- `_owner` (address): The address to query

**Returns:**
- `uint256`: The number of tokens owned by the address

#### `balanceOfNFT(uint256 _tokenId) external view returns (uint256)`

Gets the voting power of a specific token.

**Parameters:**
- `_tokenId` (uint256): The token ID to query

**Returns:**
- `uint256`: The voting power of the token

#### `balanceOfNFTAt(uint256 _tokenId, uint256 _t) external view returns (uint256)`

Gets the voting power of a specific token at a given time.

**Parameters:**
- `_tokenId` (uint256): The token ID to query
- `_t` (uint256): The timestamp to query at

**Returns:**
- `uint256`: The voting power of the token at the specified time

#### `ownerOf(uint256 _tokenId) external view returns (address)`

Gets the owner of a specific token.

**Parameters:**
- `_tokenId` (uint256): The token ID to query

**Returns:**
- `address`: The owner of the token

#### `totalSupply() external view returns (uint256)`

Gets the total number of tokens minted.

**Returns:**
- `uint256`: The total number of tokens minted

#### `totalPower() external view returns (uint256)`

Gets the total voting power across all tokens.

**Returns:**
- `uint256`: The total voting power

#### `totalPowerAtT(uint256 t) external view returns (uint256)`

Gets the total voting power at a specific time.

**Parameters:**
- `t` (uint256): The timestamp to query at

**Returns:**
- `uint256`: The total voting power at the specified time

#### `getApproved(uint256 _tokenId) external view returns (address)`

Gets the approved address for a specific token.

**Parameters:**
- `_tokenId` (uint256): The token ID to query

**Returns:**
- `address`: The approved address for the token

#### `isApprovedForAll(address _owner, address _operator) external view returns (bool)`

Checks if an operator is approved for all tokens of an owner.

**Parameters:**
- `_owner` (address): The owner address
- `_operator` (address): The operator address

**Returns:**
- `bool`: Whether the operator is approved for all tokens

#### `isApprovedOrOwner(address _spender, uint256 _tokenId) external view returns (bool)`

Checks if a spender is approved or the owner of a token.

**Parameters:**
- `_spender` (address): The spender address
- `_tokenId` (uint256): The token ID to check

**Returns:**
- `bool`: Whether the spender is approved or the owner

#### `tokenOfOwnerByIndex(address _owner, uint256 _tokenIndex) external view returns (uint256)`

Gets the token ID at a specific index for an owner.

**Parameters:**
- `_owner` (address): The owner address
- `_tokenIndex` (uint256): The index to query

**Returns:**
- `uint256`: The token ID at the specified index

#### `tokenByIndex(uint256 _index) external view returns (uint256)`

Gets the token ID at a specific global index.

**Parameters:**
- `_index` (uint256): The global index to query

**Returns:**
- `uint256`: The token ID at the specified global index

### Voting Functions

#### `getVotes(address account) external view returns (uint256)`

Gets the current voting power of an account.

**Parameters:**
- `account` (address): The account to query

**Returns:**
- `uint256`: The current voting power of the account

#### `getPastVotes(address account, uint256 timepoint) external view returns (uint256)`

Gets the voting power of an account at a past timepoint.

**Parameters:**
- `account` (address): The account to query
- `timepoint` (uint256): The timepoint to query at

**Returns:**
- `uint256`: The voting power of the account at the specified timepoint

#### `getPastTotalSupply(uint256 timepoint) external view returns (uint256)`

Gets the total voting power at a past timepoint.

**Parameters:**
- `timepoint` (uint256): The timepoint to query at

**Returns:**
- `uint256`: The total voting power at the specified timepoint

#### `delegates(address account) external view returns (address)`

Gets the delegatee of an account.

**Parameters:**
- `account` (address): The account to query

**Returns:**
- `address`: The delegatee of the account

#### `tokenIdsDelegatedTo(address account) external view returns (uint256[] memory)`

Gets the token IDs delegated to an account.

**Parameters:**
- `account` (address): The account to query

**Returns:**
- `uint256[]`: Array of token IDs delegated to the account

#### `tokenIdsDelegatedToAt(address account, uint256 timepoint) external view returns (uint256[] memory)`

Gets the token IDs delegated to an account at a past timepoint.

**Parameters:**
- `account` (address): The account to query
- `timepoint` (uint256): The timepoint to query at

**Returns:**
- `uint256[]`: Array of token IDs delegated to the account at the specified timepoint

### Utility Functions

#### `get_last_user_slope(uint256 _tokenId) external view returns (int128)`

Gets the last slope of a user's lock.

**Parameters:**
- `_tokenId` (uint256): The token ID to query

**Returns:**
- `int128`: The last slope of the user's lock

#### `user_point_history__ts(uint256 _tokenId, uint256 _idx) external view returns (uint256)`

Gets the timestamp for a specific checkpoint of a token.

**Parameters:**
- `_tokenId` (uint256): The token ID to query
- `_idx` (uint256): The checkpoint index

**Returns:**
- `uint256`: The timestamp of the checkpoint

#### `locked__end(uint256 _tokenId) external view returns (uint256)`

Gets the end time of a lock.

**Parameters:**
- `_tokenId` (uint256): The token ID to query

**Returns:**
- `uint256`: The end time of the lock

#### `tokenURI(uint256 _tokenId) external view returns (string memory)`

Gets the URI for a token's metadata.

**Parameters:**
- `_tokenId` (uint256): The token ID to query

**Returns:**
- `string`: The URI for the token's metadata

#### `supportsInterface(bytes4 _interfaceID) external view returns (bool)`

Checks if the contract supports a specific interface.

**Parameters:**
- `_interfaceID` (bytes4): The interface ID to check

**Returns:**
- `bool`: Whether the contract supports the interface

#### `checkpoints(address _account, uint256 _index) external view returns (ArrayCheckpoints.CheckpointArray memory)`

Gets a specific checkpoint for an account.

**Parameters:**
- `_account` (address): The account to query
- `_index` (uint256): The checkpoint index

**Returns:**
- `ArrayCheckpoints.CheckpointArray`: The checkpoint data

#### `clock() public view returns (uint48)`

Gets the current timestamp.

**Returns:**
- `uint48`: The current timestamp

#### `CLOCK_MODE() public pure returns (string memory)`

Gets the clock mode.

**Returns:**
- `string`: The clock mode ("mode=timestamp")

## Internal Functions

### `_create_lock(uint256 _value, uint256 _lock_duration, address _to) internal returns (uint256)`

Creates a new lock internally.

**Parameters:**
- `_value` (uint256): Amount of CTM tokens to lock
- `_lock_duration` (uint256): Number of seconds to lock tokens for
- `_to` (address): Address to receive the veCTM NFT

**Returns:**
- `uint256`: The token ID of the created veCTM NFT

### `_deposit_for(uint256 _tokenId, uint256 _value, uint256 _lock_duration, LockedBalance memory locked_balance, DepositType _deposit_type) internal`

Deposits tokens for a lock internally.

**Parameters:**
- `_tokenId` (uint256): The token ID to deposit for
- `_value` (uint256): Amount of CTM tokens to deposit
- `_lock_duration` (uint256): Lock duration (0 for existing locks)
- `locked_balance` (LockedBalance): Current locked balance
- `_deposit_type` (DepositType): Type of deposit

### `_delegate(address account, address delegatee) internal`

Delegates voting power internally.

**Parameters:**
- `account` (address): The account to delegate from
- `delegatee` (address): The account to delegate to

### `_moveDelegateVotes(address from, address to, uint256[] memory deltaTokenIDs) private`

Moves delegated votes between addresses.

**Parameters:**
- `from` (address): The address to move votes from
- `to` (address): The address to move votes to
- `deltaTokenIDs` (uint256[]): Array of token IDs to move

### `_transferFrom(address _from, address _to, uint256 _tokenId, address _sender) internal`

Transfers a token internally.

**Parameters:**
- `_from` (address): The address to transfer from
- `_to` (address): The address to transfer to
- `_tokenId` (uint256): The token ID to transfer
- `_sender` (address): The sender address

### `_withdraw(uint256 _tokenId) internal`

Withdraws tokens internally.

**Parameters:**
- `_tokenId` (uint256): The token ID to withdraw from

### `_checkpoint(uint256 _tokenId, LockedBalance memory old_locked, LockedBalance memory new_locked) internal`

Records a checkpoint for a token.

**Parameters:**
- `_tokenId` (uint256): The token ID to checkpoint
- `old_locked` (LockedBalance): The old locked balance
- `new_locked` (LockedBalance): The new locked balance

### `_balanceOfNFT(uint256 _tokenId, uint256 _t) internal view returns (uint256)`

Gets the voting power of a token at a specific time internally.

**Parameters:**
- `_tokenId` (uint256): The token ID to query
- `_t` (uint256): The timestamp to query at

**Returns:**
- `uint256`: The voting power of the token at the specified time

### `_totalPowerAtT(uint256 t) internal view returns (uint256)`

Gets the total voting power at a specific time internally.

**Parameters:**
- `t` (uint256): The timestamp to query at

**Returns:**
- `uint256`: The total voting power at the specified time

### `_isApprovedOrOwner(address _spender, uint256 _tokenId) internal view returns (bool)`

Checks if a spender is approved or the owner internally.

**Parameters:**
- `_spender` (address): The spender address
- `_tokenId` (uint256): The token ID to check

**Returns:**
- `bool`: Whether the spender is approved or the owner

### `_checkApprovedOrOwner(address _spender, uint256 _tokenId) internal view`

Reverts if a spender is not approved or the owner.

**Parameters:**
- `_spender` (address): The spender address
- `_tokenId` (uint256): The token ID to check

### `_authorizeUpgrade(address newImplementation) internal view override`

Authorizes contract upgrades.

**Parameters:**
- `newImplementation` (address): The new implementation address

**Access Control:**
- Only governance can authorize upgrades

### `_calculateCumulativeVotingPower(uint256[] memory _tokenIds, uint256 _t) internal view returns (uint256)`

Calculates the cumulative voting power of multiple tokens.

**Parameters:**
- `_tokenIds` (uint256[]): Array of token IDs
- `_t` (uint256): The timestamp to calculate at

**Returns:**
- `uint256`: The cumulative voting power

### `_getVotingUnits(address account) internal view returns (uint256[] memory)`

Gets the voting units for an account.

**Parameters:**
- `account` (address): The account to query

**Returns:**
- `uint256[]`: Array of voting units (token IDs)

### `_add(uint256[] memory current, uint256[] memory addIDs) internal pure returns (uint256[] memory)`

Adds token IDs to an array.

**Parameters:**
- `current` (uint256[]): The current array
- `addIDs` (uint256[]): The token IDs to add

**Returns:**
- `uint256[]`: The combined array

### `_remove(uint256[] memory current, uint256[] memory removeIDs) internal pure returns (uint256[] memory)`

Removes token IDs from an array.

**Parameters:**
- `current` (uint256[]): The current array
- `removeIDs` (uint256[]): The token IDs to remove

**Returns:**
- `uint256[]`: The filtered array

### `_push(mapping(address => ArrayCheckpoints.TraceArray) storage self, function(uint256[] memory, uint256[] memory) internal pure returns (uint256[] memory) op, uint256[] memory deltaTokenIDs) internal returns (uint256, uint256)`

Pushes a checkpoint update.

**Parameters:**
- `self` (mapping): The checkpoint mapping
- `op` (function): The operation function
- `deltaTokenIDs` (uint256[]): The token IDs to update

**Returns:**
- `(uint256, uint256)`: The old and new balance lengths

## Events

- `Deposit(address indexed _provider, uint256 _tokenId, uint256 _value, uint256 indexed _locktime, DepositType _deposit_type, uint256 _ts)`: Emitted when tokens are deposited
- `Withdraw(address indexed _provider, uint256 _tokenId, uint256 _value, uint256 _ts)`: Emitted when tokens are withdrawn
- `Supply(uint256 _prevSupply, uint256 _supply)`: Emitted when supply changes
- `Merge(uint256 indexed _fromId, uint256 indexed _toId)`: Emitted when locks are merged
- `Split(uint256 indexed _tokenId, uint256 indexed _extractionId, uint256 _extractionValue)`: Emitted when a lock is split
- `Liquidate(uint256 indexed _tokenId, uint256 _value, uint256 _penalty)`: Emitted when a lock is liquidated

## Errors

- `VotingEscrow_Reentrant()`: Reentrancy detected
- `VotingEscrow_OnlyAuthorized(VotingEscrowErrorParam, VotingEscrowErrorParam)`: Unauthorized access
- `VotingEscrow_NodeAttached(uint256 _tokenId)`: Token is attached to a node
- `VotingEscrow_UnclaimedRewards(uint256 _tokenId)`: Token has unclaimed rewards
- `VotingEscrow_NoExistingLock()`: No existing lock found
- `VotingEscrow_InvalidUnlockTime(uint256 _unlockTime, uint256 _maxTime)`: Invalid unlock time
- `VotingEscrow_LockExpired(uint256 _end)`: Lock has expired
- `VotingEscrow_InvalidMerge(uint256 _from, uint256 _to)`: Invalid merge operation
- `VotingEscrow_VotingAndNonVotingMerge(uint256 _from, uint256 _to)`: Cannot merge voting and non-voting locks
- `VotingEscrow_SameToken(uint256 _from, uint256 _to)`: Cannot merge same token
- `VotingEscrow_DifferentOwners(uint256 _from, uint256 _to)`: Tokens have different owners
- `VotingEscrow_FlashProtection()`: Flash protection triggered
- `VotingEscrow_InvalidValue()`: Invalid value provided
- `VotingEscrow_TransferFailed()`: Transfer operation failed
- `VotingEscrow_LiquidationsDisabled()`: Liquidations are disabled
- `VotingEscrow_LockNotExpired(uint256 _end)`: Lock has not expired
- `VotingEscrow_IsZero(VotingEscrowErrorParam _account)`: Zero value provided
- `VotingEscrow_Unauthorized(VotingEscrowErrorParam _account, VotingEscrowErrorParam _authorized)`: Unauthorized operation
- `VotingEscrow_IsZeroAddress(VotingEscrowErrorParam _account)`: Zero address provided
- `VotingEscrow_FutureLookup(uint256 _timepoint, uint256 _currentTimepoint)`: Future timepoint lookup
- `VotingEscrow_InvalidAccountNonce(address _account, uint256 _currentNonce)`: Invalid account nonce
- `VotingEscrow_NonERC721Receiver()`: Non-ERC721 receiver

## Modifiers

- `nonreentrant()`: Prevents reentrancy attacks
- `nonflash(uint256 _tokenId)`: Prevents flash NFT attacks
- `onlyGov()`: Restricts access to governance only
- `checkNotAttached(uint256 _tokenId)`: Ensures token is not attached to a node
- `checkNoRewards(uint256 _tokenId)`: Ensures token has no unclaimed rewards

## Usage

The VotingEscrow contract is the core component of the ContinuumDAO governance system:

1. **Token Locking**: Users lock CTM tokens to receive veCTM NFTs with voting power
2. **Voting Power**: Voting power decays linearly over the lock duration
3. **Delegation**: Users can delegate their voting power to other addresses
4. **Governance Integration**: The contract integrates with the governance system
5. **Node Integration**: Tokens can be attached to node infrastructure for additional rewards
6. **Reward Distribution**: The contract integrates with the rewards system

## Security Considerations

- Uses reentrancy guards to prevent reentrancy attacks
- Implements flash protection to prevent flash NFT attacks
- Uses UUPS upgradeable pattern for future upgrades
- Implements proper access controls for administrative functions
- Uses checkpoints for accurate historical voting power calculations
- Implements proper delegation mechanisms with checkpointing
