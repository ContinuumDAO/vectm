// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/utils/structs/Checkpoints.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

interface IVotingEscrow {
    function ownerOf(uint256 _tokenId) external view returns (address);
    function balanceOfNFT(uint256 _tokenId) external view returns (uint256);
    function clock() external view returns (uint48);
}

interface IRewards {
    function nodeRewardThreshold() external view returns (uint256);
}

contract NodeProperties {
    using Checkpoints for Checkpoints.Trace208;

    struct NodeInfo {
        string forumHandle;
        string email;
        uint8[4] ip;
        string vpsProvider;
        uint256 ramInstalled;
        uint256 cpuCores;
        string dIDType;
        string dID;
        bytes data;
    }

    address public gov;
    IRewards public rewards;
    IVotingEscrow public ve;

    mapping(uint256 => uint256) internal _attachedNodeId; // token ID => node ID
    mapping(uint256 => uint256) internal _attachedTokenId; // node ID => token ID
    mapping(uint256 => Checkpoints.Trace208) internal _nodeQualitiesOf; // token ID => ts checkpointed quality score
    mapping(uint256 => bool) internal _nodeValidated; // token ID => dID check
    mapping(uint256 => mapping(address => NodeInfo)) internal _nodeInfoOf; // token ID => address => node info
    mapping(uint256 => bool) internal _toBeRemoved;

    event Attachment(uint256 indexed _tokenId, uint256 indexed _nodeId);
    event Detachment(uint256 indexed _tokenId, uint256 indexed _nodeId);

    error NodeNotAttached(uint256 _tokenId);

    modifier onlyGov() {
        require(msg.sender == gov);
        _;
    }

    constructor(address _gov, address _ve) {
        gov = _gov;
        ve = IVotingEscrow(_ve);
    }

    // user adds their veCTM to a node, requirements: caller is owner of token ID, token ID/node ID are not
    // connected to another nodeID/token ID, veCTM voting power reaches the node reward threshold (attachment threshold)
    function attachNode(uint256 _tokenId, uint256 _nodeId, NodeInfo memory _nodeInfo) external {
        address _account = ve.ownerOf(_tokenId);
        require(msg.sender == _account);
        require(_attachedNodeId[_tokenId] == 0);
        require(_attachedTokenId[_nodeId] == 0);
        require(ve.balanceOfNFT(_tokenId) >= rewards.nodeRewardThreshold());
        require(_nodeId != 0);
        _nodeInfoOf[_tokenId][_account] = _nodeInfo;
        _attachedNodeId[_tokenId] = _nodeId;
        _attachedTokenId[_nodeId] = _tokenId;
        emit Attachment(_tokenId, _nodeId);
    }

    // governance removes given token IDs from their respective node IDs.
    function detachNode(uint256 _tokenId, uint256 _nodeId) external onlyGov {
        require(_attachedNodeId[_tokenId] != 0);
        require(_attachedTokenId[_nodeId] != 0);
        address _account = ve.ownerOf(_tokenId);
        _nodeInfoOf[_tokenId][_account] = NodeInfo("", "", [0,0,0,0], "", 0, 0, "", "", "");
        _attachedNodeId[_tokenId] = 0;
        _attachedTokenId[_nodeId] = 0;
        _nodeValidated[_tokenId] = false;
        _toBeRemoved[_tokenId] = false;
        emit Detachment(_tokenId, _nodeId);
    }

    // Set the node removal status to either true or false. This means it is flagged for detachment by governance vote.
    function setNodeRemovalStatus(uint256 _tokenId, bool _status) external {
        require(msg.sender == ve.ownerOf(_tokenId));
        _toBeRemoved[_tokenId] = _status;
    }

    // governance sets the quality of a node depending on a variety of performance factors.
    function setNodeQualityOf(uint256 _tokenId, uint256 _nodeQualityOf) external onlyGov {
        assert(_nodeQualityOf <= 10);
        if (_nodeQualityOf > 0 && _attachedNodeId[_tokenId] == 0) {
            revert NodeNotAttached(_tokenId);
        }
        uint208 _nodeQualityOf208 = SafeCast.toUint208(_nodeQualityOf);
        _nodeQualitiesOf[_tokenId].push(ve.clock(), _nodeQualityOf208);
    }

    function setRewards(address _rewards) external onlyGov {
        rewards = IRewards(_rewards);
    }

    function nodeInfo(uint256 _tokenId, address _account) external view returns (NodeInfo memory) {
        return _nodeInfoOf[_tokenId][_account];
    }

    function attachedNodeId(uint256 _tokenId) external view returns (uint256) {
        return _attachedNodeId[_tokenId];
    }

    function attachedTokenId(uint256 _nodeId) external view returns (uint256) {
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