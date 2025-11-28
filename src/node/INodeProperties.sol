// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

import {VotingEscrowErrorParam} from "../utils/VotingEscrowUtils.sol";

/**
 * @notice Interface for use with the Node Properties contract, where node runners can attach their veCTM to gain extra
 * rewards.
 */
interface INodeProperties {
    /**
     * @notice Structure containing comprehensive node information
     * @param forumHandle The forum handle/username of the node operator
     * @param email The email address of the node operator
     * @param nodeId The unique identifier for the node (bytes32)
     * @param ip The IP address of the node as a 4-byte array [octet1, octet2, octet3, octet4]
     * @param vpsProvider The virtual private server provider name
     * @param ramInstalled The amount of RAM installed on the node (in MB/GB)
     * @param cpuCores The number of CPU cores available on the node
     * @param dIDType The type of decentralized identifier (e.g., "did:key", "did:web")
     * @param dID The decentralized identifier string
     * @param data Additional arbitrary data associated with the node
     */
    struct NodeInfo {
        string forumHandle;
        string email;
        bytes32 nodeId;
        uint8[4] ipv4;
        uint16[8] ipv6;
        string vpsProvider;
        uint256 ramInstalled;
        uint256 cpuCores;
        string dIDType;
        string dID;
        bytes data;
    }

    event Attachment(uint256 indexed _tokenId, bytes32 indexed _nodeId);
    event Detachment(uint256 indexed _tokenId, bytes32 indexed _nodeId);
    event NodeRemovalStatusUpdated(uint256 indexed _tokenId, bool _oldStatus, bool _newStatus, address indexed _sender);
    event NodeQualityUpdated(
        uint256 indexed _tokenId, bytes32 indexed _nodeId, uint256 _oldQuality, uint256 _newQuality
    );
    event RewardsUpdated(address _oldRewards, address _newRewards);

    error NodeProperties_TokenIDNotAttached(uint256 _tokenId);
    error NodeProperties_NodeIDAlreadyAttached(bytes32 _nodeId);
    error NodeProperties_TokenIDAlreadyAttached(uint256 _tokenId);
    error NodeProperties_NodeRewardThresholdNotReached(uint256 _tokenId);
    error NodeProperties_InvalidNodeId(bytes32 _nodeId);
    error NodeProperties_InvalidNodeQualityOf(uint256 _nodeQualityOf);
    error NodeProperties_OnlyAuthorized(VotingEscrowErrorParam, VotingEscrowErrorParam);
    error NodeProperties_InvalidInitialization();

    function gov() external view returns (address);
    function rewards() external view returns (address);
    function ve() external view returns (address);

    function attachNode(uint256 _tokenId, NodeInfo memory _nodeInfo) external;
    function detachNode(uint256 _tokenId) external;
    function setNodeRemovalStatus(uint256 _tokenId, bool _status) external;
    function setNodeQualityOf(uint256 _tokenId, uint8 _nodeQualityOf) external;
    function setRewards(address _rewards) external;
    function nodeInfo(uint256 _tokenId, address _account) external view returns (NodeInfo memory);
    function attachedNodeId(uint256 _tokenId) external view returns (bytes32);
    function attachedTokenId(bytes32 _nodeId) external view returns (uint256);
    function nodeQualityOf(uint256 _tokenId) external view returns (uint256);
    function nodeQualityOfAt(uint256 _tokenId, uint256 _timestamp) external view returns (uint256);
    function nodeRequestingDetachment(uint256 _tokenId) external view returns (bool);
}
