// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {VotingEscrowErrorParam} from "../utils/VotingEscrowUtils.sol";

/**
 * @notice Interface for use with the Rewards contract, where node runners can claim their rewards.
 */
interface IRewards {
    event BaseEmissionRateChange(uint256 _oldBaseEmissionRate, uint256 _newBaseEmissionRate);
    event NodeEmissionRateChange(uint256 _oldNodeEmissionRate, uint256 _newNodeEmissionRate);
    event NodeRewardThresholdChange(uint256 _oldMinimumThreshold, uint256 _newMinimumThreshold);
    event RewardTokenChange(address indexed _oldRewardToken, address indexed _newRewardToken);
    event FeeTokenChange(address indexed _oldFeeToken, address indexed _newFeeToken);
    event Claim(uint256 indexed _tokenId, uint256 _claimedReward, address indexed _rewardToken);
    event Withdrawal(address indexed _token, address indexed _recipient, uint256 _amount);
    event FeesReceived(address indexed _token, uint256 _amount, uint256 indexed _fromChainId);
    event Swap(address indexed _feeToken, address indexed _rewardToken, uint256 _amountIn, uint256 _amountOut);

    error Rewards_NoUnclaimedRewards();
    error Rewards_InsufficientContractBalance(uint256 _balance, uint256 _required);
    error Rewards_FeesAlreadyReceivedFromChain();
    error Rewards_OnlyAuthorized(VotingEscrowErrorParam, VotingEscrowErrorParam);
    error Rewards_EmissionRateChangeTooHigh();
    error Rewards_InvalidToken(address _token);
    error Rewards_SwapDisabled();
    error Rewards_TransferFailed();

    function unclaimedRewards(uint256 _tokenId) external view returns (uint256);
    function nodeRewardThreshold() external view returns (uint256);
    function updateLatestMidnight() external;
}
