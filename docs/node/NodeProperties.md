# NodeProperties

## Overview

The NodeProperties contract manages the attachment of veCTM tokens to MPC node infrastructure for reward distribution. It allows veCTM token holders to attach their tokens to node infrastructure, enabling them to receive additional rewards based on node performance and quality metrics.

## Contract Details

- **Contract**: `NodeProperties.sol`
- **Inherits**: `INodeProperties`
- **License**: BSL-1.1
- **Solidity Version**: 0.8.27

## Data Structures

### `NodeInfo`
```solidity
struct NodeInfo {
    string forumHandle;
    string email;
    uint8[4] ipv4;
    uint16[8] ipv6;
    string vpsProvider;
    uint256 ramInstalled;
    uint256 cpuCores;
    string dIDType;
    string dID;
    bytes data;
}
```

Off-chain node metadata (attachment identity is the KeyGen `msg.sender`, not a field here):
- **forumHandle**: The forum handle/username of the node operator
- **email**: The email address of the node operator
- **ipv4** / **ipv6**: Node network addresses
- **vpsProvider**: The virtual private server provider name
- **ramInstalled**: The amount of RAM installed on the node (in MB/GB)
- **cpuCores**: The number of CPU cores available on the node
- **dIDType**: The type of decentralized identifier (e.g., "did:key", "did:web")
- **dID**: The decentralized identifier string
- **data**: Additional arbitrary data associated with the node

## State Variables

### Core Addresses
- `governor` (address): Address of the governance contract with administrative privileges
- `rewards` (address): Address of the rewards contract
- `ve` (address): Address of the voting escrow contract for token ownership verification

### Mappings
- `_attachedKeyGen` (mapping(uint256 => address)): Mapping from token ID to attached KeyGen address
- `_attachedTokenId` (mapping(address => uint256)): Mapping from KeyGen address to attached token ID
- `_nodeQualitiesOf` (mapping(uint256 => Checkpoints.Trace208)): Mapping from token ID to checkpointed node quality scores over time
- `_nodeValidated` (mapping(uint256 => bool)): Mapping from token ID to node validation status (dID verification)
- `_nodeInfoOf` (mapping(uint256 => mapping(address => NodeInfo))): Mapping from token ID and address to node information
- `_toBeRemoved` (mapping(uint256 => bool)): Mapping from token ID to removal request status

## Constructor

### `constructor(address _governor, address _ve)`

Initializes the NodeProperties contract with governance and voting escrow addresses.

**Parameters:**
- `_governor` (address): The address of the governance contract
- `_ve` (address): The address of the voting escrow contract

**Behavior:**
- Sets up the initial governance and voting escrow addresses
- Establishes the core contract relationships

## External Functions

### Node Management

#### `attachNode(uint256 _tokenId, NodeInfo memory _nodeInfo) external`

Attaches a veCTM token to a node for reward eligibility.

**Parameters:**
- `_tokenId` (uint256): The ID of the veCTM token to attach
- `_nodeInfo` (NodeInfo): The NodeInfo structure containing node details

**Behavior:**
- Allows token owners to attach their veCTM to a node
- Validates token ownership and attachment status
- Stores node information and establishes attachment mapping
- Locked-CTM / month-start VP bars are enforced by MultiSignAgentWallet, not here

**Requirements:**
- Caller must be the owner of the token ID (KeyGen holds the NFT)
- Token ID must not already be attached
- KeyGen address must not already be attached to another token

**Events Emitted:**
- `Attachment(uint256 _tokenId, address _keyGen)`: Emitted on successful attachment

**Access Control:**
- Requires caller to be the token owner

#### `detachNode(uint256 _tokenId) external`

Detaches a veCTM token from its associated node (governance only).

**Parameters:**
- `_tokenId` (uint256): The ID of the veCTM token to detach

**Behavior:**
- Allows governance to remove token-KeyGen attachments
- Clears node info, validation status, and removal flags
- Pushes a quality-0 checkpoint so node rewards stop accruing
- There is no owner self-detach and no automatic release at lock expiry

**Events Emitted:**
- `Detachment(uint256 _tokenId, address _keyGen)`: Emitted on successful detachment
- `NodeQualityUpdated` with quality 0

**Access Control:**
- Only governance can call this function

#### `setNodeRemovalStatus(uint256 _tokenId, bool _status) external`

Sets the node removal request status for a token.

**Parameters:**
- `_tokenId` (uint256): The ID of the veCTM token
- `_status` (bool): The removal request status (true = requesting removal, false = not requesting)

**Behavior:**
- Allows token owners to flag their node for detachment by governance vote
- Provides a mechanism for node operators to request removal from the network

**Access Control:**
- Requires caller to be the token owner

### Quality Management

#### `setNodeQualityOf(uint256 _tokenId, uint8 _nodeQualityOf) external`

Sets the quality score for a node (governance only).

**Parameters:**
- `_tokenId` (uint256): The ID of the veCTM token associated with the node
- `_nodeQualityOf` (uint8): The quality score to assign (0-10 scale)

**Behavior:**
- Governance can set node quality scores based on performance metrics
- Quality scores are checkpointed with timestamps for historical tracking
- Quality scores range from 0-10, where 10 represents optimal performance
- Emits NodeQualityUpdated event

**Requirements:**
- Quality score must not exceed 10
- Token must be attached to a node if setting a positive quality score

**Access Control:**
- Only governance can call this function

### Contract Initialization

#### `setRewards(address _rewards) external`

Sets the rewards contract address (governance only).

**Parameters:**
- `_rewards` (address): The address of the rewards contract

**Behavior:**
- Sets up the rewards contract address for threshold checking
- Reverts if the rewards address is zero
- Emits RewardsUpdated event

**Access Control:**
- Only governance can call this function

### View Functions

#### `nodeInfo(uint256 _tokenId, address _account) external view returns (NodeInfo memory)`

Retrieves node information for a specific token and account.

**Parameters:**
- `_tokenId` (uint256): The ID of the veCTM token
- `_account` (address): The address of the account to get node info for

**Returns:**
- `NodeInfo`: The complete node information including technical specifications, operator details, and decentralized identifier information

#### `attachedKeyGen(uint256 _tokenId) external view returns (address)`

Gets the KeyGen address attached to a specific token.

**Parameters:**
- `_tokenId` (uint256): The ID of the veCTM token

**Returns:**
- `address`: The KeyGen address, or address(0) if not attached

#### `attachedTokenId(address _keyGen) external view returns (uint256)`

Gets the token ID attached to a specific KeyGen address.

**Parameters:**
- `_keyGen` (address): The KeyGen Ethereum address

**Returns:**
- `uint256`: The token ID, or 0 if not attached

#### `nodeQualityOf(uint256 _tokenId) external view returns (uint256)`

Gets the current quality score for a node.

**Parameters:**
- `_tokenId` (uint256): The ID of the veCTM token

**Returns:**
- `uint256`: The current node quality score (0-10 scale)

**Behavior:**
- Returns the most recent quality score for the node associated with the token
- Quality scores are used for reward calculations and performance evaluation

#### `nodeQualityOfAt(uint256 _tokenId, uint256 _timestamp) external view returns (uint256)`

Gets the quality score for a node at a specific timestamp.

**Parameters:**
- `_tokenId` (uint256): The ID of the veCTM token
- `_timestamp` (uint256): The timestamp to query the quality score for

**Returns:**
- `uint256`: The node quality score at the specified timestamp (0-10 scale)

**Behavior:**
- Uses checkpointed data to retrieve historical quality scores
- Useful for calculating rewards based on performance over time periods

#### `nodeRequestingDetachment(uint256 _tokenId) external view returns (bool)`

Checks if a node is requesting detachment.

**Parameters:**
- `_tokenId` (uint256): The ID of the veCTM token

**Returns:**
- `bool`: True if the node operator has requested removal, false otherwise

**Behavior:**
- Returns whether the node operator has flagged their node for removal through the governance process

## Modifiers

### `onlyGov()`

Restricts function access to governance only.

**Behavior:**
- Reverts with NodeProperties_OnlyAuthorized error if caller is not the governor
- Used for administrative functions like detaching nodes and setting quality scores

## Events

- `Attachment(uint256 indexed _tokenId, address indexed _keyGen)`: Emitted when a token is attached to a KeyGen
- `Detachment(uint256 indexed _tokenId, address indexed _keyGen)`: Emitted when a token is detached from a KeyGen

## Errors

- `NodeProperties_OnlyAuthorized(VotingEscrowErrorParam, VotingEscrowErrorParam)`: Unauthorized access
- `NodeProperties_TokenIDAlreadyAttached(uint256 _tokenId)`: Token is already attached
- `NodeProperties_KeyGenAlreadyAttached(address _keyGen)`: KeyGen is already attached to a token
- `NodeProperties_TokenIDNotAttached(uint256 _tokenId)`: Token is not attached
- `NodeProperties_InvalidNodeQualityOf(uint256 _nodeQualityOf)`: Quality score exceeds 10
- `NodeProperties_InvalidInitialization()`: Rewards address is already set

## Usage

The NodeProperties contract enables node infrastructure integration:

1. **Token-Node Attachment**: veCTM token holders can attach their tokens to MPC node infrastructure
2. **Quality Tracking**: Governance can track and update node quality scores over time
3. **Reward Eligibility**: Attached tokens become eligible for additional node-based rewards
4. **Performance Monitoring**: Historical quality scores enable performance-based reward calculations
5. **Node Management**: Governance can manage node attachments and removals

## Integration

The NodeProperties contract integrates with:

- **VotingEscrow**: For token ownership verification and voting power checks
- **Rewards**: For node reward distribution (`nodeRewardThreshold` is emission-only; attach bars live on MultiSignAgentWallet)
- **Governance**: For administrative functions and node quality management
- **Checkpoints**: For historical quality score tracking

## Security Considerations

- Uses governance-only access controls for administrative functions
- Validates token ownership before allowing attachments
- Implements proper threshold checking for node eligibility
- Uses checkpointed quality scores for historical tracking
- Prevents duplicate attachments and invalid node IDs
- Implements removal request mechanism for node operators 