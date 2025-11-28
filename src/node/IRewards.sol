// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

import {VotingEscrowErrorParam} from "../utils/VotingEscrowUtils.sol";

/**
 * @notice Interface for use with the Rewards contract, where node runners can claim their rewards.
 */
interface IRewards {
    enum Token {
        Fee,
        Reward
    }

    event Claim(uint256 indexed _tokenId, uint256 _claimedReward, address indexed _rewardToken);
    event Withdrawal(address indexed _token, address indexed _recipient, uint256 _amount);
    event FeesReceived(address indexed _token, uint256 _amount, uint256 indexed _fromChainId);

    event BaseEmissionRateUpdated(uint256 _oldBaseEmissionRate, uint256 _newBaseEmissionRate);
    event NodeEmissionRateUpdated(uint256 _oldNodeEmissionRate, uint256 _newNodeEmissionRate);
    event NodeRewardThresholdUpdated(uint256 _oldNodeRewardThreshold, uint256 _newNodeRewardThreshold);
    event TokenUpdated(Token indexed _tokenType, address _oldToken, address _newToken);
    event FeeUpdated(Token indexed _tokenType, uint256 oldFee, uint256 _fee);

    error Rewards_NoUnclaimedRewards();
    error Rewards_InsufficientContractBalance(uint256 _balance, uint256 _required);
    error Rewards_FeesAlreadyReceivedFromChain();
    error Rewards_OnlyAuthorized(VotingEscrowErrorParam, VotingEscrowErrorParam);
    error Rewards_EmissionRateChangeTooHigh();
    error Rewards_InvalidToken(address _token);

    function setBaseEmissionRate(uint256 _baseEmissionRate) external;
    function setNodeEmissionRate(uint256 _nodeEmissionRate) external;
    function setNodeRewardThreshold(uint256 _nodeRewardThreshold) external;
    function withdrawToken(address _token, address _recipient, uint256 _amount) external;
    function setFeeToken(address _feeToken, address _recipient) external;
    function setFeePerByteRewardToken(uint256 _fee) external;
    function setFeePerByteFeeToken(uint256 _fee) external;
    function setNodeProperties(address _nodeProperties) external;
    function receiveFees(address _token, uint256 _amount, uint256 _fromChainId) external;
    function updateLatestMidnight() external;
    function compoundLockRewards(uint256 _tokenId) external returns (uint256);
    function baseEmissionRate() external view returns (uint256);
    function nodeEmissionRate() external view returns (uint256);
    function nodeRewardThreshold() external view returns (uint256);
    function unclaimedRewards(uint256 _tokenId) external view returns (uint256);

    function latestMidnight() external view returns (uint48);
    function genesis() external view returns (uint48);
    function feePerByteRewardToken() external view returns (uint256);
    function feePerByteFeeToken() external view returns (uint256);
    function gov() external view returns (address);
    function rewardToken() external view returns (address);
    function feeToken() external view returns (address);
    function nodeProperties() external view returns (address);
    function ve() external view returns (address);

    function claimRewards(uint256 _tokenId, address _to) external returns (uint256);
    function baseEmissionRateAt(uint256 _timestamp) external view returns (uint256);
    function nodeEmissionRateAt(uint256 _timestamp) external view returns (uint256);
    function nodeRewardThresholdAt(uint256 _timestamp) external view returns (uint256);
}
