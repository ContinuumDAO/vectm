// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import {IERC6372} from "@openzeppelin/contracts/interfaces/IERC6372.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Checkpoints} from "@openzeppelin/contracts/utils/structs/Checkpoints.sol";

import {IVotingEscrow} from "../token/IVotingEscrow.sol";

import {VotingEscrowErrorParam} from "../utils/VotingEscrowUtils.sol";
import {INodeProperties} from "./INodeProperties.sol";
import {IRewards} from "./IRewards.sol";

/**
 * @title NodeProperties
 * @notice Manages the attachment of veCTM tokens to node infrastructure for reward distribution
 * @author @patrickcure ContinuumDAO
 * @dev This contract allows veCTM token holders to attach their tokens to MPC node infrastructure,
 * enabling them to receive additional rewards based on node performance and quality metrics.
 * The contract maintains mappings between token IDs and node IDs, tracks node quality scores
 * over time using checkpoints, and manages node validation status.
 *
 * Key features:
 * - Token-to-node attachment/detachment management
 * - Node quality scoring with historical tracking
 * - Node information storage and retrieval
 * - Governance-controlled node removal
 * - Integration with voting escrow and rewards systems
 */
contract NodeProperties is INodeProperties {
    using Checkpoints for Checkpoints.Trace208;

    /// @notice Address of the governance contract with administrative privileges
    address public gov;

    /// @notice Address of the rewards contract for threshold checking
    address public rewards;

    /// @notice Address of the voting escrow contract for token ownership verification
    address public ve;

    /// @notice Mapping from token ID to attached node ID
    mapping(uint256 => bytes32) internal _attachedNodeId;

    /// @notice Mapping from node ID to attached token ID
    mapping(bytes32 => uint256) internal _attachedTokenId;

    /// @notice Mapping from token ID to checkpointed node quality scores over time
    mapping(uint256 => Checkpoints.Trace208) internal _nodeQualitiesOf;

    /// @notice Mapping from token ID to node validation status (dID verification)
    mapping(uint256 => bool) internal _nodeValidated;

    /// @notice Mapping from token ID and address to node information
    mapping(uint256 => mapping(address => NodeInfo)) internal _nodeInfoOf;

    /// @notice Mapping from token ID to removal request status
    mapping(uint256 => bool) internal _toBeRemoved;

    /**
     * @notice Modifier to restrict function access to governance only
     * @dev Reverts with NodeProperties_OnlyAuthorized error if caller is not the gov
     */
    modifier onlyGov() {
        if (msg.sender != gov) {
            revert NodeProperties_OnlyAuthorized(VotingEscrowErrorParam.Sender, VotingEscrowErrorParam.Gov);
        }
        _;
    }

    /**
     * @notice Initializes the NodeProperties contract
     * @param _gov The address of the governance contract
     * @param _ve The address of the voting escrow contract
     * @dev Sets up the initial governance and voting escrow addresses
     */
    constructor(address _gov, address _ve) {
        gov = _gov;
        ve = _ve;
    }

    /**
     * @notice Attaches a veCTM token to a node for reward eligibility
     * @param _tokenId The ID of the veCTM token to attach
     * @param _nodeInfo The NodeInfo structure containing node details
     * @dev This function allows token owners to attach their veCTM to a node.
     * Requirements:
     * - Caller must be the owner of the token ID
     * - Token ID must not already be attached to another node
     * - Node ID must not already be attached to another token
     * - Token's voting power must meet the node reward threshold
     * - Node ID must not be empty
     */
    function attachNode(uint256 _tokenId, NodeInfo memory _nodeInfo) external {
        address _owner = IERC721(ve).ownerOf(_tokenId);
        bytes32 _nodeId = _nodeInfo.nodeId;
        if (msg.sender != _owner) {
            revert NodeProperties_OnlyAuthorized(VotingEscrowErrorParam.Sender, VotingEscrowErrorParam.Owner);
        }
        if (_attachedNodeId[_tokenId] != bytes32("")) {
            revert NodeProperties_TokenIDAlreadyAttached(_tokenId);
        }
        if (_attachedTokenId[_nodeId] != 0) {
            revert NodeProperties_NodeIDAlreadyAttached(_nodeId);
        }
        if (IVotingEscrow(ve).balanceOfNFT(_tokenId) < IRewards(rewards).nodeRewardThreshold()) {
            revert NodeProperties_NodeRewardThresholdNotReached(_tokenId);
        }
        if (_nodeId == bytes32("")) {
            revert NodeProperties_InvalidNodeId(_nodeId);
        }
        _nodeInfoOf[_tokenId][_owner] = _nodeInfo;
        _attachedNodeId[_tokenId] = _nodeId;
        _attachedTokenId[_nodeId] = _tokenId;
        _nodeValidated[_tokenId] = true;
        emit Attachment(_tokenId, _nodeId);
    }

    /**
     * @notice Detaches a veCTM token from its associated node (governance only)
     * @param _tokenId The ID of the veCTM token to detach
     * @dev This function allows governance to remove token-node attachments.
     * Clears all associated data including node info, validation status, and removal flags.
     * @dev Governance has unconditional authority over over node attachment status, due to the role's sensitive nature
     * in the ecosystem. If a node is attached to a token lock, this prevents the token undergoing actions such as
     * transfer, merge, split, withdraw and liquidate.
     */
    function detachNode(uint256 _tokenId) external onlyGov {
        bytes32 _nodeId = _attachedNodeId[_tokenId];
        if (_nodeId == bytes32("")) {
            revert NodeProperties_TokenIDNotAttached(_tokenId);
        }
        address _account = IERC721(ve).ownerOf(_tokenId);
        uint16 _0 = uint16(0);
        _nodeInfoOf[_tokenId][_account] =
            NodeInfo("", "", bytes32(""), [0, 0, 0, 0], [_0, _0, _0, _0, _0, _0, _0, _0], "", 0, 0, "", "", "");
        _attachedNodeId[_tokenId] = bytes32("");
        _attachedTokenId[_nodeId] = 0;
        _nodeValidated[_tokenId] = false;
        _toBeRemoved[_tokenId] = false;
        emit Detachment(_tokenId, _nodeId);
    }

    /**
     * @notice Sets the node removal request status for a token
     * @param _tokenId The ID of the veCTM token
     * @param _status The removal request status (true = requesting removal, false = not requesting)
     * @dev Allows token owners to flag their node for detachment by governance vote.
     * This provides a mechanism for node operators to request removal from the network.
     */
    function setNodeRemovalStatus(uint256 _tokenId, bool _status) external {
        if (msg.sender != IERC721(ve).ownerOf(_tokenId)) {
            revert NodeProperties_OnlyAuthorized(VotingEscrowErrorParam.Sender, VotingEscrowErrorParam.Owner);
        }
        bool oldStatus = _toBeRemoved[_tokenId];
        _toBeRemoved[_tokenId] = _status;
        emit NodeRemovalStatusUpdated(_tokenId, oldStatus, _status, msg.sender);
    }

    /**
     * @notice Sets the quality score for a node (governance only)
     * @param _tokenId The ID of the veCTM token associated with the node
     * @param _nodeQualityOf The quality score to assign (0-10 scale)
     * @dev Governance can set node quality scores based on performance metrics.
     * Quality scores are checkpointed with timestamps for historical tracking.
     * Quality scores range from 0-10, where 10 represents optimal performance.
     */
    function setNodeQualityOf(uint256 _tokenId, uint8 _nodeQualityOf) external onlyGov {
        if (_nodeQualityOf > 10) {
            revert NodeProperties_InvalidNodeQualityOf(_nodeQualityOf);
        }
        bytes32 nodeId = _attachedNodeId[_tokenId];
        if (_nodeQualityOf > 0 && _attachedNodeId[_tokenId] == bytes32("")) {
            revert NodeProperties_TokenIDNotAttached(_tokenId);
        }
        uint256 oldQuality = nodeQualityOf(_tokenId);
        _nodeQualitiesOf[_tokenId].push(IERC6372(ve).clock(), uint208(_nodeQualityOf));
        emit NodeQualityUpdated(_tokenId, nodeId, oldQuality, _nodeQualityOf);
    }

    /**
     * @notice Initializes the rewards contract address
     * @param _rewards The address of the rewards contract
     * @dev This function can only be called once to set the rewards contract address.
     * The rewards contract is used for checking node reward thresholds.
     */
    function setRewards(address _rewards) external onlyGov {
        if (_rewards == address(0)) {
            revert NodeProperties_InvalidInitialization();
        }
        address oldRewards = rewards;
        rewards = _rewards;
        emit RewardsUpdated(oldRewards, _rewards);
    }

    /**
     * @notice Retrieves node information for a specific token and account
     * @param _tokenId The ID of the veCTM token
     * @param _account The address of the account to get node info for
     * @return The NodeInfo structure containing node details
     * @dev Returns the complete node information including technical specifications,
     * operator details, and decentralized identifier information.
     */
    function nodeInfo(uint256 _tokenId, address _account) external view returns (NodeInfo memory) {
        return _nodeInfoOf[_tokenId][_account];
    }

    /**
     * @notice Gets the node ID attached to a specific token
     * @param _tokenId The ID of the veCTM token
     * @return The bytes32 node ID, or empty bytes32 if not attached
     * @dev Returns the unique node identifier associated with the given token ID.
     */
    function attachedNodeId(uint256 _tokenId) external view returns (bytes32) {
        return _attachedNodeId[_tokenId];
    }

    /**
     * @notice Gets the token ID attached to a specific node
     * @param _nodeId The bytes32 node ID
     * @return The token ID, or 0 if not attached
     * @dev Returns the veCTM token ID associated with the given node ID.
     */
    function attachedTokenId(bytes32 _nodeId) external view returns (uint256) {
        return _attachedTokenId[_nodeId];
    }

    /**
     * @notice Gets the current quality score for a node
     * @param _tokenId The ID of the veCTM token
     * @return The current node quality score (0-10 scale)
     * @dev Returns the most recent quality score for the node associated with the token.
     * Quality scores are used for reward calculations and performance evaluation.
     */
    function nodeQualityOf(uint256 _tokenId) public view returns (uint256) {
        return uint256(_nodeQualitiesOf[_tokenId].latest());
    }

    /**
     * @notice Gets the quality score for a node at a specific timestamp
     * @param _tokenId The ID of the veCTM token
     * @param _timestamp The timestamp to query the quality score for
     * @return The node quality score at the specified timestamp (0-10 scale)
     * @dev Uses checkpointed data to retrieve historical quality scores.
     * Useful for calculating rewards based on performance over time periods.
     */
    function nodeQualityOfAt(uint256 _tokenId, uint256 _timestamp) external view returns (uint256) {
        return _nodeQualitiesOf[_tokenId].upperLookupRecent(SafeCast.toUint48(_timestamp));
    }

    /**
     * @notice Checks if a node is requesting detachment
     * @param _tokenId The ID of the veCTM token
     * @return True if the node operator has requested removal, false otherwise
     * @dev Returns whether the node operator has flagged their node for removal
     * through the governance process.
     */
    function nodeRequestingDetachment(uint256 _tokenId) external view returns (bool) {
        return _toBeRemoved[_tokenId];
    }
}
