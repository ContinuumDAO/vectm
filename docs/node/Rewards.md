# Rewards

## Overview

The Rewards contract manages reward distribution for veCTM token holders and node operators. It handles the distribution of rewards to veCTM token holders based on their voting power and node performance, supporting both base rewards for all token holders and additional node rewards for those who have attached their tokens to MPC node infrastructure.

## Contract Details

- **Contract**: `Rewards.sol`
- **Inherits**: `IRewards`
- **License**: BSL-1.1
- **Solidity Version**: 0.8.27

## Data Structures

### `Fee`
```solidity
struct Fee {
    address token;
    uint256 amount;
}
```

Structure for tracking fee receipts from different chains:
- **token**: The address of the token received
- **amount**: The amount of tokens received

## State Variables

### Constants
- `ONE_DAY` (uint48): Duration of one day in seconds (1 days)
- `MULTIPLIER` (uint256): Multiplier for precision in reward calculations (1 ether)

### Core Addresses
- `gov` (address): Address of the governance contract with administrative privileges
- `rewardToken` (address): Address of the reward token (CTM)
- `feeToken` (address): Address of the fee token (e.g., USDC)
- `swapRouter` (address): Address of the Uniswap V3 swap router
- `nodeProperties` (address): Address of the node properties contract
- `ve` (address): Address of the voting escrow contract
- `WETH` (address): Address of WETH for swap operations (immutable)

### Global State
- `latestMidnight` (uint48): The latest midnight timestamp that has been processed
- `genesis` (uint48): The genesis timestamp when rewards started
- `feePerByteRewardToken` (uint256): Fee per byte for reward token (CTM)
- `feePerByteFeeToken` (uint256): Fee per byte for fee token (USDC)
- `_swapEnabled` (bool): Flag to enable/disable swap functionality

### Checkpointed Data
- `_baseEmissionRates` (Checkpoints.Trace208): Checkpointed base emission rates over time (CTM per vePower)
- `_nodeEmissionRates` (Checkpoints.Trace208): Checkpointed node emission rates over time (CTM per vePower)
- `_nodeRewardThresholds` (Checkpoints.Trace208): Checkpointed minimum voting power thresholds for node rewards

### Mappings
- `_lastClaimOf` (mapping(uint256 => uint48)): Mapping from token ID to last claim timestamp (midnight)
- `_feeReceivedFromChainAt` (mapping(uint256 => mapping(uint48 => Fee))): Mapping from chain ID and timestamp to fee receipts

## Constructor

### `constructor(uint48 _firstMidnight, address _ve, address _gov, address _rewardToken, address _feeToken, address _swapRouter, address _nodeProperties, address _weth, uint256 _baseEmissionRate, uint256 _nodeEmissionRate, uint256 _nodeRewardThreshold, uint256 _feePerByteRewardToken, uint256 _feePerByteFeeToken)`

Initializes the Rewards contract with all required parameters.

**Parameters:**
- `_firstMidnight` (uint48): The genesis timestamp when rewards started
- `_ve` (address): The address of the voting escrow contract
- `_gov` (address): The address of the governance contract
- `_rewardToken` (address): The address of the reward token (CTM)
- `_feeToken` (address): The address of the fee token (e.g., USDC)
- `_swapRouter` (address): The address of the Uniswap V3 swap router
- `_nodeProperties` (address): The address of the node properties contract
- `_weth` (address): The address of WETH for swap operations
- `_baseEmissionRate` (uint256): The initial base emission rate
- `_nodeEmissionRate` (uint256): The initial node emission rate
- `_nodeRewardThreshold` (uint256): The initial minimum voting power threshold for node rewards
- `_feePerByteRewardToken` (uint256): The fee per byte for reward token
- `_feePerByteFeeToken` (uint256): The fee per byte for fee token

**Behavior:**
- Sets up all initial parameters and contract addresses
- Initializes checkpointed emission rates and thresholds
- Approves the voting escrow contract to spend reward tokens
- Establishes the genesis timestamp for reward calculations

## External Functions

### Governance Functions

#### `setBaseEmissionRate(uint256 _baseEmissionRate) external`

Sets the base emission rate for all token holders (governance only).

**Parameters:**
- `_baseEmissionRate` (uint256): The new base emission rate

**Behavior:**
- Updates the base emission rate with checkpointing for historical tracking
- The emission rate cannot exceed 1% of the multiplier to prevent excessive inflation

**Access Control:**
- Only governance can call this function

#### `setNodeEmissionRate(uint256 _nodeEmissionRate) external`

Sets the node emission rate for node operators (governance only).

**Parameters:**
- `_nodeEmissionRate` (uint256): The new node emission rate

**Behavior:**
- Updates the node emission rate with checkpointing for historical tracking
- The emission rate cannot exceed 1% of the multiplier to prevent excessive inflation

**Access Control:**
- Only governance can call this function

#### `setNodeRewardThreshold(uint256 _nodeRewardThreshold) external`

Sets the minimum voting power threshold for node rewards (governance only).

**Parameters:**
- `_nodeRewardThreshold` (uint256): The new minimum voting power threshold

**Behavior:**
- Updates the node reward threshold with checkpointing for historical tracking
- Only token holders with voting power above this threshold can receive node rewards

**Access Control:**
- Only governance can call this function

#### `withdrawToken(address _token, address _recipient, uint256 _amount) external`

Withdraws tokens from the contract to a recipient (governance only).

**Parameters:**
- `_token` (address): The address of the token to withdraw
- `_recipient` (address): The address to receive the tokens
- `_amount` (uint256): The amount of tokens to withdraw

**Behavior:**
- Allows governance to withdraw any tokens held by the contract
- Emits a Withdrawal event on successful withdrawal

**Access Control:**
- Only governance can call this function

#### `setRewardToken(address _rewardToken, uint48 _firstMidnight, address _recipient) external`

Changes the reward token and handles old token withdrawal (governance only).

**Parameters:**
- `_rewardToken` (address): The new reward token address
- `_firstMidnight` (uint48): The new genesis timestamp
- `_recipient` (address): The address to receive old token balance

**Behavior:**
- Changes the reward token and withdraws any remaining balance of the old token
- Updates the genesis timestamp for the new reward token
- Emits Withdrawal and RewardTokenChange events

**Access Control:**
- Only governance can call this function

#### `setFeeToken(address _feeToken, address _recipient) external`

Changes the fee token and handles old token withdrawal (governance only).

**Parameters:**
- `_feeToken` (address): The new fee token address
- `_recipient` (address): The address to receive old token balance

**Behavior:**
- Changes the fee token and withdraws any remaining balance of the old token
- Emits Withdrawal and FeeTokenChange events

**Access Control:**
- Only governance can call this function

#### `setFeePerByteRewardToken(uint256 _fee) external`

Sets the fee per byte for reward token (governance only).

**Parameters:**
- `_fee` (uint256): The new fee per byte for reward token

**Behavior:**
- Updates the fee rate for reward token calculations

**Access Control:**
- Only governance can call this function

#### `setFeePerByteFeeToken(uint256 _fee) external`

Sets the fee per byte for fee token (governance only).

**Parameters:**
- `_fee` (uint256): The new fee per byte for fee token

**Behavior:**
- Updates the fee rate for fee token calculations

**Access Control:**
- Only governance can call this function

#### `setNodeProperties(address _nodeProperties) external`

Sets the node properties contract address (governance only).

**Parameters:**
- `_nodeProperties` (address): The new node properties contract address

**Behavior:**
- Updates the reference to the node properties contract for quality score queries

**Access Control:**
- Only governance can call this function

#### `setSwapEnabled(bool _enabled) external`

Enables or disables swap functionality (governance only).

**Parameters:**
- `_enabled` (bool): True to enable swaps, false to disable

**Behavior:**
- Controls whether fee tokens can be swapped for reward tokens

**Access Control:**
- Only governance can call this function

### Fee Management

#### `receiveFees(address _token, uint256 _amount, uint256 _fromChainId) external`

Receives fees from cross-chain transfers.

**Parameters:**
- `_token` (address): The address of the token received
- `_amount` (uint256): The amount of tokens received
- `_fromChainId` (uint256): The ID of the source chain

**Behavior:**
- Allows the contract to receive fees from other chains
- Only accepts fee tokens or reward tokens
- Prevents duplicate fee receipts from the same chain at the same timestamp
- Emits a FeesReceived event on successful receipt

**Access Control:**
- Public function - any address can call

#### `updateLatestMidnight() external`

Updates the latest midnight timestamp.

**Behavior:**
- Calculates and updates the latest midnight timestamp for reward calculations
- This function should be called periodically to ensure accurate reward tracking

**Access Control:**
- Public function - any address can call

### Swap Functions

#### `swapFeeToReward(uint256 _amountIn, uint256 _uniFeeWETH, uint256 _uniFeeReward) external returns (uint256 _amountOut)`

Swaps fee tokens for reward tokens using Uniswap V3.

**Parameters:**
- `_amountIn` (uint256): The amount of fee tokens to swap
- `_uniFeeWETH` (uint256): The Uniswap fee tier for WETH pair
- `_uniFeeReward` (uint256): The Uniswap fee tier for reward token pair

**Returns:**
- `_amountOut` (uint256): The amount of reward tokens received

**Behavior:**
- Performs a swap from fee tokens to reward tokens via WETH
- Uses the contract's balance if requested amount exceeds available balance
- Emits a Swap event on successful swap

**Access Control:**
- Public function - any address can call

### Reward Functions

#### `compoundLockRewards(uint256 _tokenId) external returns (uint256)`

Compounds claimed rewards back into the voting escrow.

**Parameters:**
- `_tokenId` (uint256): The ID of the veCTM token

**Returns:**
- `uint256`: The amount of rewards compounded

**Behavior:**
- Claims rewards for the token and immediately deposits them back into the voting escrow
- Extends the lock duration and increases voting power

**Access Control:**
- Public function - any address can call

#### `claimRewards(uint256 _tokenId, address _to) public returns (uint256)`

Claims rewards for a token and sends them to a recipient.

**Parameters:**
- `_tokenId` (uint256): The ID of the veCTM token
- `_to` (address): The address to receive the rewards

**Returns:**
- `uint256`: The amount of rewards claimed

**Behavior:**
- Claims all unclaimed rewards for the token and transfers them to the recipient
- Updates the last claim timestamp to prevent double-claiming
- Emits a Claim event on successful claim

**Access Control:**
- Requires caller to be the token owner

### View Functions

#### `baseEmissionRate() external view returns (uint256)`

Gets the current base emission rate.

**Returns:**
- `uint256`: The current base emission rate

**Behavior:**
- Returns the most recent base emission rate from checkpoints

#### `nodeEmissionRate() external view returns (uint256)`

Gets the current node emission rate.

**Returns:**
- `uint256`: The current node emission rate

**Behavior:**
- Returns the most recent node emission rate from checkpoints

#### `nodeRewardThreshold() external view returns (uint256)`

Gets the current node reward threshold.

**Returns:**
- `uint256`: The current minimum voting power threshold for node rewards

**Behavior:**
- Returns the most recent node reward threshold from checkpoints

#### `unclaimedRewards(uint256 _tokenId) external view returns (uint256)`

Calculates unclaimed rewards for a token.

**Parameters:**
- `_tokenId` (uint256): The ID of the veCTM token

**Returns:**
- `uint256`: The amount of unclaimed rewards

**Behavior:**
- Calculates rewards that have accrued since the last claim
- Considers base rewards, node rewards, and quality scores

#### `baseEmissionRateAt(uint256 _timestamp) public view returns (uint256)`

Gets the base emission rate at a specific timestamp.

**Parameters:**
- `_timestamp` (uint256): The timestamp to query

**Returns:**
- `uint256`: The base emission rate at the specified timestamp

**Behavior:**
- Uses checkpointed data to retrieve historical base emission rates

#### `nodeEmissionRateAt(uint256 _timestamp) public view returns (uint256)`

Gets the node emission rate at a specific timestamp.

**Parameters:**
- `_timestamp` (uint256): The timestamp to query

**Returns:**
- `uint256`: The node emission rate at the specified timestamp

**Behavior:**
- Uses checkpointed data to retrieve historical node emission rates

#### `nodeRewardThresholdAt(uint256 _timestamp) public view returns (uint256)`

Gets the node reward threshold at a specific timestamp.

**Parameters:**
- `_timestamp` (uint256): The timestamp to query

**Returns:**
- `uint256`: The node reward threshold at the specified timestamp

**Behavior:**
- Uses checkpointed data to retrieve historical node reward thresholds

## Internal Functions

### `_setBaseEmissionRate(uint256 _baseEmissionRate) internal`

Sets the base emission rate internally.

**Parameters:**
- `_baseEmissionRate` (uint256): The new base emission rate

### `_setNodeEmissionRate(uint256 _nodeEmissionRate) internal`

Sets the node emission rate internally.

**Parameters:**
- `_nodeEmissionRate` (uint256): The new node emission rate

### `_setNodeRewardThreshold(uint256 _nodeRewardThreshold) internal`

Sets the node reward threshold internally.

**Parameters:**
- `_nodeRewardThreshold` (uint256): The new node reward threshold

### `_withdrawToken(address _token, address _recipient, uint256 _amount) internal`

Withdraws tokens internally.

**Parameters:**
- `_token` (address): The token to withdraw
- `_recipient` (address): The recipient address
- `_amount` (uint256): The amount to withdraw

### `_calculateRewardsOf(uint256 _tokenId, uint48 _latestMidnight) internal view returns (uint256)`

Calculates rewards for a token.

**Parameters:**
- `_tokenId` (uint256): The token ID
- `_latestMidnight` (uint48): The latest midnight timestamp

**Returns:**
- `uint256`: The calculated rewards

### `_getLatestMidnight() internal view returns (uint48)`

Gets the latest midnight timestamp.

**Returns:**
- `uint48`: The latest midnight timestamp

### `_updateLatestMidnight(uint48 _latestMidnight) internal`

Updates the latest midnight timestamp.

**Parameters:**
- `_latestMidnight` (uint48): The new latest midnight timestamp

## Modifiers

### `onlyGov()`

Restricts function access to governance only.

**Behavior:**
- Reverts with Rewards_OnlyAuthorized error if caller is not the governor
- Used for administrative functions

## Events

- `Withdrawal(address indexed _token, address indexed _recipient, uint256 _amount)`: Emitted when tokens are withdrawn
- `RewardTokenChange(address indexed _oldToken, address indexed _newToken)`: Emitted when reward token is changed
- `FeeTokenChange(address indexed _oldToken, address indexed _newToken)`: Emitted when fee token is changed
- `FeesReceived(address indexed _token, uint256 _amount, uint256 indexed _fromChainId)`: Emitted when fees are received
- `Swap(address indexed _tokenIn, address indexed _tokenOut, uint256 _amountIn, uint256 _amountOut)`: Emitted when tokens are swapped
- `Claim(uint256 indexed _tokenId, uint256 _amount, address indexed _token)`: Emitted when rewards are claimed

## Errors

- `Rewards_OnlyAuthorized(VotingEscrowErrorParam, VotingEscrowErrorParam)`: Unauthorized access
- `Rewards_EmissionRateChangeTooHigh(uint256 _emissionRate)`: Emission rate exceeds 1% of multiplier
- `Rewards_TransferFailed()`: Token transfer failed
- `Rewards_InvalidToken(address _token)`: Invalid token for fee receipt
- `Rewards_FeesAlreadyReceivedFromChain()`: Fees already received from this chain
- `Rewards_SwapDisabled()`: Swap functionality is disabled
- `Rewards_NoUnclaimedRewards()`: No rewards are available to claim
- `Rewards_InsufficientContractBalance(uint256 _contractBalance, uint256 _reward)`: Contract balance is insufficient

## Usage

The Rewards contract enables comprehensive reward distribution:

1. **Base Rewards**: All veCTM token holders receive base rewards based on voting power
2. **Node Rewards**: Token holders with attached nodes receive additional rewards
3. **Quality-Based Rewards**: Node rewards are scaled by node quality scores (0-10)
4. **Cross-Chain Fees**: Supports fee collection from multiple chains
5. **Token Swapping**: Converts fee tokens to reward tokens via Uniswap V3
6. **Reward Compounding**: Allows rewards to be compounded back into voting escrow

## Integration

The Rewards contract integrates with:

- **VotingEscrow**: For voting power calculations and reward deposits
- **NodeProperties**: For node quality scores and attachment status
- **Uniswap V3**: For token swapping functionality
- **Cross-Chain Infrastructure**: For fee collection from multiple chains
- **Governance**: For parameter management and administrative functions

## Security Considerations

- Uses governance-only access controls for administrative functions
- Implements emission rate caps to prevent excessive inflation
- Uses checkpointed data for historical tracking and calculations
- Prevents double-claiming through timestamp tracking
- Implements proper token transfer validation
- Uses safe casting for timestamp operations
- Implements swap functionality with proper approvals 