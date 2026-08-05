// SPDX-License-Identifier: MIT

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
 * @notice Manages the attachment of veCTM tokens to node KeyGen addresses for reward distribution
 * @author @patrickcure ContinuumDAO
 * @dev Attachment identity is the KeyGen Ethereum address (`msg.sender`), which must own the veCTM NFT.
 * Attachment freezes transfer/merge/split/withdraw/liquidate on VotingEscrow until governance `detachNode`.
 * There is no owner-initiated detach and no automatic release at lock expiry; `setNodeRemovalStatus` is advisory only.
 *
 * Key features:
 * - Token-to-KeyGen attachment/detachment management
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

    /// @notice Mapping from token ID to attached KeyGen address
    mapping(uint256 => address) internal _attachedKeyGen;

    /// @notice Mapping from KeyGen address to attached token ID
    mapping(address => uint256) internal _attachedTokenId;

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
     * @notice Attaches a veCTM token to the caller's KeyGen address for reward eligibility
     * @param _tokenId The ID of the veCTM token to attach
     * @param _nodeInfo The NodeInfo structure containing off-chain node metadata
     * @dev Requirements:
     * - Caller must be the owner of the token ID (KeyGen holds the NFT)
     * - Token ID must not already be attached
     * - KeyGen address must not already be attached to another token
     * - Token's voting power must meet the node reward threshold
     */
    function attachNode(uint256 _tokenId, NodeInfo memory _nodeInfo) external {
        address _owner = IERC721(ve).ownerOf(_tokenId);
        if (msg.sender != _owner) {
            revert NodeProperties_OnlyAuthorized(VotingEscrowErrorParam.Sender, VotingEscrowErrorParam.Owner);
        }
        if (_attachedKeyGen[_tokenId] != address(0)) {
            revert NodeProperties_TokenIDAlreadyAttached(_tokenId);
        }
        if (_attachedTokenId[msg.sender] != 0) {
            revert NodeProperties_KeyGenAlreadyAttached(msg.sender);
        }
        if (IVotingEscrow(ve).balanceOfNFT(_tokenId) < IRewards(rewards).nodeRewardThreshold()) {
            revert NodeProperties_NodeRewardThresholdNotReached(_tokenId);
        }
        _nodeInfoOf[_tokenId][_owner] = _nodeInfo;
        _attachedKeyGen[_tokenId] = msg.sender;
        _attachedTokenId[msg.sender] = _tokenId;
        _nodeValidated[_tokenId] = true;
        emit Attachment(_tokenId, msg.sender);
    }

    /**
     * @notice Detaches a veCTM token from its KeyGen (governance only)
     * @param _tokenId The ID of the veCTM token to detach
     * @dev Clears attachment, node info, validation, and removal flags, and zeroes the quality checkpoint
     * so rewards stop accruing node quality. Only governance can detach — owners cannot self-detach, and
     * attachment does not expire with the lock.
     */
    function detachNode(uint256 _tokenId) external onlyGov {
        address _keyGen = _attachedKeyGen[_tokenId];
        if (_keyGen == address(0)) {
            revert NodeProperties_TokenIDNotAttached(_tokenId);
        }
        address _account = IERC721(ve).ownerOf(_tokenId);
        uint16 _0 = uint16(0);
        _nodeInfoOf[_tokenId][_account] =
            NodeInfo("", "", [0, 0, 0, 0], [_0, _0, _0, _0, _0, _0, _0, _0], "", 0, 0, "", "", "");
        _attachedKeyGen[_tokenId] = address(0);
        _attachedTokenId[_keyGen] = 0;
        _nodeValidated[_tokenId] = false;
        _toBeRemoved[_tokenId] = false;

        uint256 oldQuality = nodeQualityOf(_tokenId);
        _nodeQualitiesOf[_tokenId].push(IERC6372(ve).clock(), uint208(0));
        emit NodeQualityUpdated(_tokenId, _keyGen, oldQuality, 0);
        emit Detachment(_tokenId, _keyGen);
    }

    /**
     * @notice Sets the node removal request status for a token
     * @param _tokenId The ID of the veCTM token
     * @param _status The removal request status (true = requesting removal, false = not requesting)
     * @dev Advisory only — does not detach. Governance must call `detachNode` to clear attachment.
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
        address keyGen = _attachedKeyGen[_tokenId];
        if (_nodeQualityOf > 0 && keyGen == address(0)) {
            revert NodeProperties_TokenIDNotAttached(_tokenId);
        }
        uint256 oldQuality = nodeQualityOf(_tokenId);
        _nodeQualitiesOf[_tokenId].push(IERC6372(ve).clock(), uint208(_nodeQualityOf));
        emit NodeQualityUpdated(_tokenId, keyGen, oldQuality, _nodeQualityOf);
    }

    /**
     * @notice Initializes the rewards contract address
     * @param _rewards The address of the rewards contract
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
     */
    function nodeInfo(uint256 _tokenId, address _account) external view returns (NodeInfo memory) {
        return _nodeInfoOf[_tokenId][_account];
    }

    /**
     * @notice Gets the KeyGen address attached to a specific token
     * @param _tokenId The ID of the veCTM token
     * @return The KeyGen address, or address(0) if not attached
     */
    function attachedKeyGen(uint256 _tokenId) external view returns (address) {
        return _attachedKeyGen[_tokenId];
    }

    /**
     * @notice Gets the token ID attached to a specific KeyGen address
     * @param _keyGen The KeyGen Ethereum address
     * @return The token ID, or 0 if not attached
     */
    function attachedTokenId(address _keyGen) external view returns (uint256) {
        return _attachedTokenId[_keyGen];
    }

    /**
     * @notice Gets the current quality score for a node
     * @param _tokenId The ID of the veCTM token
     * @return The current node quality score (0-10 scale)
     */
    function nodeQualityOf(uint256 _tokenId) public view returns (uint256) {
        return uint256(_nodeQualitiesOf[_tokenId].latest());
    }

    /**
     * @notice Gets the quality score for a node at a specific timestamp
     * @param _tokenId The ID of the veCTM token
     * @param _timestamp The timestamp to query the quality score for
     * @return The node quality score at the specified timestamp (0-10 scale)
     */
    function nodeQualityOfAt(uint256 _tokenId, uint256 _timestamp) external view returns (uint256) {
        return _nodeQualitiesOf[_tokenId].upperLookupRecent(SafeCast.toUint48(_timestamp));
    }

    /**
     * @notice Checks if a node is requesting detachment
     * @param _tokenId The ID of the veCTM token
     * @return True if the node operator has requested removal, false otherwise
     */
    function nodeRequestingDetachment(uint256 _tokenId) external view returns (bool) {
        return _toBeRemoved[_tokenId];
    }
}
