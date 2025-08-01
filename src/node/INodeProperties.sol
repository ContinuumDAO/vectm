// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import { VotingEscrowErrorParam } from "../utils/VotingEscrowUtils.sol";

/**
 * @notice Interface for use with the Node Properties contract, where node runners can attach their veCTM to gain extra
 * rewards.
 */
interface INodeProperties {
    event Attachment(uint256 indexed _tokenId, bytes32 indexed _nodeId);
    event Detachment(uint256 indexed _tokenId, bytes32 indexed _nodeId);

    error NodeProperties_TokenIDNotAttached(uint256 _tokenId);
    error NodeProperties_NodeIDAlreadyAttached(bytes32 _nodeId);
    error NodeProperties_TokenIDAlreadyAttached(uint256 _tokenId);
    error NodeProperties_NodeRewardThresholdNotReached(uint256 _tokenId);
    error NodeProperties_InvalidNodeId(bytes32 _nodeId);
    error NodeProperties_InvalidNodeQualityOf(uint256 _nodeQualityOf);
    error NodeProperties_OnlyAuthorized(VotingEscrowErrorParam, VotingEscrowErrorParam);
    error NodeProperties_InvalidInitialization();

    function attachedNodeId(uint256 _tokenId) external view returns (bytes32);
    function nodeQualityOfAt(uint256 _tokenId, uint256 _timestamp) external view returns (uint256);
}
