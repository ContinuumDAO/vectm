// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/utils/structs/Checkpoints.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

interface IVotingEscrow {
    function ownerOf(uint256 _tokenId) external view returns (address);
    function balanceOfNFT(uint256 _tokenId) external view returns (uint256);
    function clock() external view returns (uint48);
}

contract NodeProperties {
    using Checkpoints for Checkpoints.Trace208;

    struct NodeInfo {
        string forumHandle;
        string enode;
        string ip;
        string port;
        string countryCode;
        string vpsProvider;
        uint256 ramInstalled;
        uint256 cpuCores;
        string dIDType;
        string dID;
        bytes data;
    }

    address public gov;
    address public committee; // for validating nodes' KYC
    IVotingEscrow public ve;

    mapping(uint256 => uint256) internal _attachedNodeId; // token ID => node ID
    mapping(uint256 => uint256) internal _attachedTokenId; // node ID => token ID
    mapping(uint256 => Checkpoints.Trace208) internal _nodeQualitiesOf; // token ID => ts checkpointed quality score
    mapping(uint256 => bool) internal _nodeValidated; // token ID => dID check
    mapping(uint256 => NodeInfo) internal _nodeInfoOf; // token ID => node info

    uint256 internal _attachmentThreshold;

    event Attachment(uint256 indexed _tokenId, uint256 indexed _nodeId);
    event Detachment(uint256 indexed _tokenId, uint256 indexed _nodeId);
    event ThresholdChanged(uint256 _oldThreshold, uint256 _newThreshold);

    modifier onlyGov() {
        require(msg.sender == gov);
        _;
    }

    modifier onlyCommittee {
        require(msg.sender == committee);
        _;
    }

    constructor(address _gov, address _committee, address _ve) { 
        gov = _gov;
        committee = _committee;
        ve = IVotingEscrow(_ve);
    }

    function setNodeInfo(uint256 _tokenId, NodeInfo memory _nodeInfo) external {
        require(ve.ownerOf(_tokenId) == msg.sender);
        _nodeInfoOf[_tokenId] = _nodeInfo;
    }

    function attachNode(uint256 _tokenId, uint256 _nodeId) external onlyGov {
        require(ve.balanceOfNFT(_tokenId) >= _attachmentThreshold);
        require(_attachedNodeId[_tokenId] == 0);
        require(_attachedTokenId[_nodeId] == 0);
        require(_nodeId != 0);
        _attachedNodeId[_tokenId] = _nodeId;
        _attachedTokenId[_nodeId] = _tokenId;
        emit Attachment(_tokenId, _nodeId);
    }

    function detachNode(uint256 _tokenId, uint256 _nodeId) external onlyGov {
        require(_attachedNodeId[_tokenId] != 0);
        require(_attachedTokenId[_nodeId] != 0);
        _attachedNodeId[_tokenId] = 0;
        _attachedTokenId[_nodeId] = 0;
        emit Detachment(_tokenId, _nodeId);
    }

    function setAttachmentThreshold(uint256 _newThreshold) external onlyGov {
        uint256 attachmentThreshold = _attachmentThreshold;
        _attachmentThreshold = _newThreshold;
        emit ThresholdChanged(attachmentThreshold, _newThreshold);
    }

    function setNodeQualityOf(uint256 _tokenId, uint208 _nodeQualityOf) external onlyGov {
        assert(_nodeQualityOf <= 10);
        _nodeQualitiesOf[_tokenId].push(ve.clock(), _nodeQualityOf);
    }

    function setCommittee(address _committee) external onlyGov {
        committee = _committee;
    }

    function setNodeValidations(uint256[] memory _tokenIds, bool[] memory _validated) external onlyCommittee {
        for (uint8 i = 0; i < _tokenIds.length; i++) {
            _nodeValidated[_tokenIds[i]] = _validated[i];
        }
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

    function nodeValidated(uint256 _tokenId) external view returns (bool) {
        return _nodeValidated[_tokenId];
    }
}