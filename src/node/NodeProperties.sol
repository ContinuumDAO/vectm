// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import { IERC6372 } from "@openzeppelin/contracts/interfaces/IERC6372.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { Checkpoints } from "@openzeppelin/contracts/utils/structs/Checkpoints.sol";

import { IVotingEscrow } from "../token/IVotingEscrow.sol";

import { VotingEscrowErrorParam } from "../utils/VotingEscrowUtils.sol";
import { INodeProperties } from "./INodeProperties.sol";
import { IRewards } from "./IRewards.sol";

contract NodeProperties is INodeProperties {
    using Checkpoints for Checkpoints.Trace208;

    struct NodeInfo {
        string forumHandle;
        string email;
        bytes32 nodeId;
        uint8[4] ip;
        string vpsProvider;
        uint256 ramInstalled;
        uint256 cpuCores;
        string dIDType;
        string dID;
        bytes data;
    }

    address public governor;
    address public rewards;
    address public ve;

    mapping(uint256 => bytes32) internal _attachedNodeId; // token ID => node ID
    mapping(bytes32 => uint256) internal _attachedTokenId; // node ID => token ID
    mapping(uint256 => Checkpoints.Trace208) internal _nodeQualitiesOf; // token ID => ts checkpointed quality score
    mapping(uint256 => bool) internal _nodeValidated; // token ID => dID check
    mapping(uint256 => mapping(address => NodeInfo)) internal _nodeInfoOf; // token ID => address => node info
    mapping(uint256 => bool) internal _toBeRemoved;

    modifier onlyGov() {
        if (msg.sender != governor) {
            revert NodeProperties_OnlyAuthorized(VotingEscrowErrorParam.Sender, VotingEscrowErrorParam.Governor);
        }
        _;
    }

    constructor(address _governor, address _ve) {
        governor = _governor;
        ve = _ve;
    }

    // user adds their veCTM to a node, requirements: caller is owner of token ID, token ID/node ID are not
    // connected to another nodeID/token ID, veCTM voting power reaches the node reward threshold (attachment threshold)
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
        emit Attachment(_tokenId, _nodeId);
    }

    // governance removes given token IDs from their respective node IDs.
    function detachNode(uint256 _tokenId) external onlyGov {
        bytes32 _nodeId = _attachedNodeId[_tokenId];
        if (_nodeId == bytes32("")) {
            revert NodeProperties_TokenIDNotAttached(_tokenId);
        }
        address _account = IERC721(ve).ownerOf(_tokenId);
        _nodeInfoOf[_tokenId][_account] = NodeInfo("", "", bytes32(""), [0, 0, 0, 0], "", 0, 0, "", "", "");
        _attachedNodeId[_tokenId] = bytes32("");
        _attachedTokenId[_nodeId] = 0;
        _nodeValidated[_tokenId] = false;
        _toBeRemoved[_tokenId] = false;
        emit Detachment(_tokenId, _nodeId);
    }

    // Set the node removal status to either true or false. This means it is flagged for detachment by governance vote.
    function setNodeRemovalStatus(uint256 _tokenId, bool _status) external {
        if (msg.sender != IERC721(ve).ownerOf(_tokenId)) {
            revert NodeProperties_OnlyAuthorized(VotingEscrowErrorParam.Sender, VotingEscrowErrorParam.Owner);
        }
        _toBeRemoved[_tokenId] = _status;
    }

    // governance sets the quality of a node depending on a variety of performance factors.
    function setNodeQualityOf(uint256 _tokenId, uint256 _nodeQualityOf) external onlyGov {
        if (_nodeQualityOf > 10) {
            revert NodeProperties_InvalidNodeQualityOf(_nodeQualityOf);
        }
        if (_nodeQualityOf > 0 && _attachedNodeId[_tokenId] == bytes32("")) {
            revert NodeProperties_TokenIDNotAttached(_tokenId);
        }
        uint208 _nodeQualityOf208 = SafeCast.toUint208(_nodeQualityOf);
        _nodeQualitiesOf[_tokenId].push(IERC6372(ve).clock(), _nodeQualityOf208);
    }

    function initContracts(address _rewards) external {
        if (rewards != address(0)) {
            revert NodeProperties_InvalidInitialization();
        }
        rewards = _rewards;
    }

    function nodeInfo(uint256 _tokenId, address _account) external view returns (NodeInfo memory) {
        return _nodeInfoOf[_tokenId][_account];
    }

    function attachedNodeId(uint256 _tokenId) external view returns (bytes32) {
        return _attachedNodeId[_tokenId];
    }

    function attachedTokenId(bytes32 _nodeId) external view returns (uint256) {
        return _attachedTokenId[_nodeId];
    }

    function nodeQualityOf(uint256 _tokenId) external view returns (uint256) {
        return uint256(_nodeQualitiesOf[_tokenId].latest());
    }

    function nodeQualityOfAt(uint256 _tokenId, uint256 _timestamp) external view returns (uint256) {
        return _nodeQualitiesOf[_tokenId].upperLookupRecent(SafeCast.toUint48(_timestamp));
    }

    function nodeRequestingDetachment(uint256 _tokenId) external view returns (bool) {
        return _toBeRemoved[_tokenId];
    }
}
