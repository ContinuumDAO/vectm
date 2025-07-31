// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

/**
 * @notice Interface for use with the Node Properties contract, where node runners can attach their veCTM to gain extra
 * rewards.
 */
interface INodeProperties {
    function attachedNodeId(uint256 _tokenId) external view returns (bytes32);
    function nodeQualityOfAt(uint256 _tokenId, uint256 _timestamp) external view returns (uint256);
}
