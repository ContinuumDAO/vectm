// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

import {IERC6372} from "@openzeppelin/contracts/interfaces/IERC6372.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Checkpoints} from "@openzeppelin/contracts/utils/structs/Checkpoints.sol";

import {VotingEscrowErrorParam} from "../utils/VotingEscrowUtils.sol";
import {INodeProperties} from "./INodeProperties.sol";

/**
 * @title NodeProperties
 * @notice Manages the attachment of veCTM tokens to node operator addresses for reward distribution
 * @author @patrickcure ContinuumDAO
 * @dev Attachment is relayed by MultiSignAgentWallet: only `msaw` may call `attachNodeFor`, passing the
 * withdraw-authority address that must own the veCTM NFT. That address is stored as the attach key and
 * indexed by `attachedTokenId` for fee-waiver lookups on the wallet.
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

    /// @dev Reverts when `attachNodeFor` is called with a key that does not own the veCTM NFT.
    error NodeProperties_KeyGenMustOwnToken(address _keyGen, address _owner);

    /// @notice Address of the governance contract with administrative privileges
    address public gov;

    /// @notice Address of the rewards contract
    address public rewards;

    /// @notice Address of the voting escrow contract for token ownership verification
    address public ve;

    /// @notice Address of the MultiSignAgentWallet fee contract
    address public msaw;

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
     * @notice Modifier to restrict function access to multi-sign agent wallet only
     * @dev Reverts with NodeProperties_OnlyAuthorized error if caller is not the msaw
     */
    modifier onlyMSAW() {
        if (msg.sender != msaw) {
            revert NodeProperties_OnlyAuthorized(VotingEscrowErrorParam.Sender, VotingEscrowErrorParam.MSAW);
        }
        _;
    }

    /**
     * @notice Initializes the NodeProperties contract
     * @param _gov The address of the governance contract
     * @dev `rewards` is wired separately via `setProtocolContracts` before attach is enabled.
     */
    constructor(address _gov) {
        if (_gov == address(0)) {
            revert NodeProperties_IsZeroAddress(VotingEscrowErrorParam.Gov);
        }
        gov = _gov;
    }

    /**
     * @notice Attaches a veCTM token to a node operator address for reward eligibility
     * @param _keyGen The withdraw-authority address that owns the veCTM NFT (passed through by `msaw`)
     * @param _tokenId The ID of the veCTM token to attach
     * @param _nodeInfo Off-chain node metadata forwarded from MultiSignAgentWallet
     * @dev Only MultiSignAgentWallet may call. Requirements:
     * - `rewards` must be configured
     * - `_keyGen` must own `_tokenId`
     * - Token ID must not already be attached
     * - `_keyGen` must not already be attached to another token
     * Locked-CTM / month-start VP bars live on MultiSignAgentWallet (`veCtmThresholdPower`),
     * not here — `rewards.nodeRewardThreshold()` is for Rewards emission only.
     */
    function attachNodeFor(address _keyGen, uint256 _tokenId, NodeInfo memory _nodeInfo) external onlyMSAW {
        if (rewards == address(0)) {
            revert NodeProperties_IsZeroAddress(VotingEscrowErrorParam.Rewards);
        }
        address _owner = IERC721(ve).ownerOf(_tokenId);
        if (_keyGen != _owner) {
            revert NodeProperties_KeyGenMustOwnToken(_keyGen, _owner);
        }
        if (_attachedKeyGen[_tokenId] != address(0)) {
            revert NodeProperties_TokenIDAlreadyAttached(_tokenId);
        }
        if (_attachedTokenId[_keyGen] != 0) {
            revert NodeProperties_KeyGenAlreadyAttached(_keyGen);
        }
        _nodeInfoOf[_tokenId][_owner] = _nodeInfo;
        _attachedKeyGen[_tokenId] = _keyGen;
        _attachedTokenId[_keyGen] = _tokenId;
        _nodeValidated[_tokenId] = true;
        emit Attachment(_tokenId, _keyGen);
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
     * @notice Sets the protocol contract addresses.
     * @param _gov The new gov address.
     * @param _ve The new voting escrow address.
     * @param _rewards The new rewards address.
     * @param _msaw The new MultiSignAgentWallet proxy address.
     * @dev Only governance. Required before `attachNodeFor` can succeed.
     */
    function setProtocolContracts(address _gov, address _ve, address _rewards, address _msaw) external onlyGov {
        if (_gov == address(0)) {
            revert NodeProperties_IsZeroAddress(VotingEscrowErrorParam.Gov);
        }
        if (_ve == address(0)) {
            revert NodeProperties_IsZeroAddress(VotingEscrowErrorParam.VotingEscrow);
        }
        if (_rewards == address(0)) {
            revert NodeProperties_IsZeroAddress(VotingEscrowErrorParam.Rewards);
        }
        if (_msaw == address(0)) {
            revert NodeProperties_IsZeroAddress(VotingEscrowErrorParam.MSAW);
        }
        gov = _gov;
        ve = _ve;
        rewards = _rewards;
        msaw = _msaw;
        emit ProtocolContractsUpdated(_gov, _ve, _rewards, _msaw);
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
