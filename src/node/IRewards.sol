// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

/** */
interface IRewards {
    function unclaimedRewards(uint256 _tokenId) external view returns (uint256);
    function nodeRewardThreshold() external view returns (uint256);
}
