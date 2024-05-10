// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/**
 * @notice Interface for use with the Node Properties contract, where node runners can attach their veCTM to gain extra
 * rewards.
 */
interface INodeProperties {
    function attachedNodeId(uint256 _tokenId) external view returns (bytes32);
}