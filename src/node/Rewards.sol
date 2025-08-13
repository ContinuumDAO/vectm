// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import { IERC6372 } from "@openzeppelin/contracts/interfaces/IERC6372.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { Checkpoints } from "@openzeppelin/contracts/utils/structs/Checkpoints.sol";

import { IVotingEscrow } from "../token/IVotingEscrow.sol";

import { VotingEscrowErrorParam } from "../utils/VotingEscrowUtils.sol";
import { INodeProperties } from "./INodeProperties.sol";
import { IRewards } from "./IRewards.sol";
import { ISwapRouter } from "./ISwapRouter.sol";

/**
 * @title Rewards
 * @notice Manages reward distribution for veCTM token holders and node operators
 * @author @patrickcure ContinuumDAO
 * @dev This contract handles the distribution of rewards to veCTM token holders based on their
 * voting power and node performance. It supports both base rewards for all token holders and
 * additional node rewards for those who have attached their tokens to MPC node infrastructure.
 * 
 * Key features:
 * - Daily reward calculations based on voting power
 * - Node quality-based bonus rewards
 * - Fee collection and token swapping
 * - Historical emission rate tracking with checkpoints
 * - Cross-chain fee integration
 * - Compound rewards back into voting escrow
 * 
 * Reward calculation considers:
 * - Base emission rate for all token holders
 * - Node emission rate for node operators
 * - Node quality scores (0-10 scale)
 * - Token voting power and lock duration
 */
contract Rewards is IRewards {
    using Checkpoints for Checkpoints.Trace208;

    /**
     * @notice Structure for tracking fee receipts from different chains
     * @param token The address of the token received
     * @param amount The amount of tokens received
     * @dev Used to track fees received from cross-chain transfers
     */
    struct Fee {
        address token;
        uint256 amount;
    }

    /// @notice Duration of one day in seconds
    uint48 public constant ONE_DAY = 1 days;
    
    /// @notice Multiplier for precision in reward calculations (1e18)
    uint256 public constant MULTIPLIER = 1 ether;
    
    /// @notice The latest midnight timestamp that has been processed
    uint48 public latestMidnight;
    
    /// @notice The genesis timestamp when rewards started
    uint48 public genesis;

    /// @notice Fee per byte for reward token (CTM)
    uint256 public feePerByteRewardToken;
    
    /// @notice Fee per byte for fee token (USDC)
    uint256 public feePerByteFeeToken;

    /// @notice Address of the governance contract with administrative privileges
    address public gov;
    
    /// @notice Address of the reward token (CTM)
    address public rewardToken;
    
    /// @notice Address of the fee token (e.g., USDC)
    address public feeToken;
    
    /// @notice Address of the Uniswap V3 swap router
    address public swapRouter;
    
    /// @notice Address of the node properties contract
    address public nodeProperties;
    
    /// @notice Address of the voting escrow contract
    address public ve;

    /// @notice Address of WETH for swap operations (immutable)
    address public immutable WETH;

    /// @notice Flag to enable/disable swap functionality
    bool internal _swapEnabled;

    /// @notice Checkpointed base emission rates over time (CTM per vePower)
    Checkpoints.Trace208 internal _baseEmissionRates;
    
    /// @notice Checkpointed node emission rates over time (CTM per vePower)
    Checkpoints.Trace208 internal _nodeEmissionRates;
    
    /// @notice Checkpointed minimum voting power thresholds for node rewards
    Checkpoints.Trace208 internal _nodeRewardThresholds;

    /// @notice Mapping from token ID to last claim timestamp (midnight)
    mapping(uint256 => uint48) internal _lastClaimOf;
    
    /// @notice Mapping from chain ID and timestamp to fee receipts
    mapping(uint256 => mapping(uint48 => Fee)) internal _feeReceivedFromChainAt;

    /**
     * @notice Modifier to restrict function access to governance only
     * @dev Reverts with Rewards_OnlyAuthorized error if caller is not the governor
     */
    modifier onlyGov() {
        if (msg.sender != gov) {
            revert Rewards_OnlyAuthorized(VotingEscrowErrorParam.Sender, VotingEscrowErrorParam.Governor);
        }
        _;
    }

    /**
     * @notice Initializes the Rewards contract with all required parameters
     * @param _firstMidnight The genesis timestamp when rewards started
     * @param _ve The address of the voting escrow contract
     * @param _gov The address of the governance contract
     * @param _rewardToken The address of the reward token (CTM)
     * @param _feeToken The address of the fee token (e.g., USDC)
     * @param _swapRouter The address of the Uniswap V3 swap router
     * @param _nodeProperties The address of the node properties contract
     * @param _weth The address of WETH for swap operations
     * @param _baseEmissionRate The initial base emission rate
     * @param _nodeEmissionRate The initial node emission rate
     * @param _nodeRewardThreshold The initial minimum voting power threshold for node rewards
     * @param _feePerByteRewardToken The fee per byte for reward token
     * @param _feePerByteFeeToken The fee per byte for fee token
     * @dev Sets up all initial parameters and approves the voting escrow contract to spend reward tokens
     */
    constructor(
        uint48 _firstMidnight,
        address _ve,
        address _gov,
        address _rewardToken,
        address _feeToken,
        address _swapRouter,
        address _nodeProperties,
        address _weth,
        uint256 _baseEmissionRate,
        uint256 _nodeEmissionRate,
        uint256 _nodeRewardThreshold,
        uint256 _feePerByteRewardToken,
        uint256 _feePerByteFeeToken
    ) {
        genesis = _firstMidnight;
        ve = _ve;
        gov = _gov;
        rewardToken = _rewardToken;
        feeToken = _feeToken;
        swapRouter = _swapRouter;
        nodeProperties = _nodeProperties;
        WETH = _weth;
        _setBaseEmissionRate(_baseEmissionRate);
        _setNodeEmissionRate(_nodeEmissionRate);
        _setNodeRewardThreshold(_nodeRewardThreshold);
        feePerByteRewardToken = _feePerByteRewardToken;
        feePerByteFeeToken = _feePerByteFeeToken;
        IERC20(_rewardToken).approve(_ve, type(uint256).max);
    }

    /**
     * @notice Sets the base emission rate for all token holders (governance only)
     * @param _baseEmissionRate The new base emission rate
     * @dev Updates the base emission rate with checkpointing for historical tracking.
     * The emission rate cannot exceed 1% of the multiplier to prevent excessive inflation.
     * 
     * @custom:error Rewards_EmissionRateChangeTooHigh When emission rate exceeds 1% of multiplier
     */
    function setBaseEmissionRate(uint256 _baseEmissionRate) external onlyGov {
        _setBaseEmissionRate(_baseEmissionRate);
    }

    /**
     * @notice Sets the node emission rate for node operators (governance only)
     * @param _nodeEmissionRate The new node emission rate
     * @dev Updates the node emission rate with checkpointing for historical tracking.
     * The emission rate cannot exceed 1% of the multiplier to prevent excessive inflation.
     * 
     * @custom:error Rewards_EmissionRateChangeTooHigh When emission rate exceeds 1% of multiplier
     */
    function setNodeEmissionRate(uint256 _nodeEmissionRate) external onlyGov {
        _setNodeEmissionRate(_nodeEmissionRate);
    }

    /**
     * @notice Sets the minimum voting power threshold for node rewards (governance only)
     * @param _nodeRewardThreshold The new minimum voting power threshold
     * @dev Updates the node reward threshold with checkpointing for historical tracking.
     * Only token holders with voting power above this threshold can receive node rewards.
     */
    function setNodeRewardThreshold(uint256 _nodeRewardThreshold) external onlyGov {
        _setNodeRewardThreshold(_nodeRewardThreshold);
    }

    /**
     * @notice Withdraws tokens from the contract to a recipient (governance only)
     * @param _token The address of the token to withdraw
     * @param _recipient The address to receive the tokens
     * @param _amount The amount of tokens to withdraw
     * @dev Allows governance to withdraw any tokens held by the contract.
     * 
     * Emits a Withdrawal event on successful withdrawal.
     * 
     * @custom:error Rewards_TransferFailed When token transfer fails
     */
    function withdrawToken(address _token, address _recipient, uint256 _amount) external onlyGov {
        _withdrawToken(_token, _recipient, _amount);
        emit Withdrawal(_token, _recipient, _amount);
    }

    /**
     * @notice Changes the reward token and handles old token withdrawal (governance only)
     * @param _rewardToken The new reward token address
     * @param _firstMidnight The new genesis timestamp
     * @param _recipient The address to receive old token balance
     * @dev Changes the reward token and withdraws any remaining balance of the old token.
     * Updates the genesis timestamp for the new reward token.
     * 
     * Emits a Withdrawal event for old token balance and a RewardTokenChange event.
     * 
     * @custom:error Rewards_TransferFailed When token transfer fails
     */
    function setRewardToken(address _rewardToken, uint48 _firstMidnight, address _recipient) external onlyGov {
        address _oldRewardToken = rewardToken;
        rewardToken = _rewardToken;
        genesis = _firstMidnight;
        uint256 _oldTokenContractBalance = IERC20(_oldRewardToken).balanceOf(address(this));

        if (_oldTokenContractBalance != 0) {
            _withdrawToken(_oldRewardToken, _recipient, _oldTokenContractBalance);
            emit Withdrawal(_oldRewardToken, _recipient, _oldTokenContractBalance);
        }

        emit RewardTokenChange(_oldRewardToken, _rewardToken);
    }

    /**
     * @notice Changes the fee token and handles old token withdrawal (governance only)
     * @param _feeToken The new fee token address
     * @param _recipient The address to receive old token balance
     * @dev Changes the fee token and withdraws any remaining balance of the old token.
     * 
     * Emits a Withdrawal event for old token balance and a FeeTokenChange event.
     * 
     * @custom:error Rewards_TransferFailed When token transfer fails
     */
    function setFeeToken(address _feeToken, address _recipient) external onlyGov {
        address _oldFeeToken = feeToken;
        feeToken = _feeToken;
        uint256 _oldTokenContractBalance = IERC20(_oldFeeToken).balanceOf(address(this));

        if (_oldTokenContractBalance != 0) {
            _withdrawToken(_oldFeeToken, _recipient, _oldTokenContractBalance);
            emit Withdrawal(_oldFeeToken, _recipient, _oldTokenContractBalance);
        }

        emit FeeTokenChange(_oldFeeToken, _feeToken);
    }

    /**
     * @notice Sets the fee per byte for reward token (governance only)
     * @param _fee The new fee per byte for reward token
     * @dev Updates the fee rate for reward token calculations.
     */
    function setFeePerByteRewardToken(uint256 _fee) external onlyGov {
        feePerByteRewardToken = _fee;
    }

    /**
     * @notice Sets the fee per byte for fee token (governance only)
     * @param _fee The new fee per byte for fee token
     * @dev Updates the fee rate for fee token calculations.
     */
    function setFeePerByteFeeToken(uint256 _fee) external onlyGov {
        feePerByteFeeToken = _fee;
    }

    /**
     * @notice Sets the node properties contract address (governance only)
     * @param _nodeProperties The new node properties contract address
     * @dev Updates the reference to the node properties contract for quality score queries.
     */
    function setNodeProperties(address _nodeProperties) external onlyGov {
        nodeProperties = _nodeProperties;
    }

    /**
     * @notice Enables or disables swap functionality (governance only)
     * @param _enabled True to enable swaps, false to disable
     * @dev Controls whether fee tokens can be swapped for reward tokens.
     */
    function setSwapEnabled(bool _enabled) external onlyGov {
        _swapEnabled = _enabled;
    }

    /**
     * @notice Receives fees from cross-chain transfers
     * @param _token The address of the token received
     * @param _amount The amount of tokens received
     * @param _fromChainId The ID of the source chain
     * @dev Allows the contract to receive fees from other chains.
     * Only accepts fee tokens or reward tokens.
     * Prevents duplicate fee receipts from the same chain at the same timestamp.
     * 
     * Emits a FeesReceived event on successful receipt.
     * 
     * @custom:error Rewards_InvalidToken When token is not fee token or reward token
     * @custom:error Rewards_FeesAlreadyReceivedFromChain When fees already received from this chain
     * @custom:error Rewards_TransferFailed When token transfer fails
     */
    function receiveFees(address _token, uint256 _amount, uint256 _fromChainId) external {
        if (_token != feeToken && _token != rewardToken) {
            revert Rewards_InvalidToken(_token);
        }

        if (_feeReceivedFromChainAt[_fromChainId][IERC6372(ve).clock()].amount != 0) {
            revert Rewards_FeesAlreadyReceivedFromChain();
        }

        if (!IERC20(_token).transferFrom(msg.sender, address(this), _amount)) {
            revert Rewards_TransferFailed();
        }

        _feeReceivedFromChainAt[_fromChainId][IERC6372(ve).clock()] = Fee(_token, _amount);
        emit FeesReceived(_token, _amount, _fromChainId);
    }

    /**
     * @notice Updates the latest midnight timestamp
     * @dev Calculates and updates the latest midnight timestamp for reward calculations.
     * This function should be called periodically to ensure accurate reward tracking.
     */
    function updateLatestMidnight() external {
        uint48 _latestMidnight = _getLatestMidnight();
        _updateLatestMidnight(_latestMidnight);
    }

    /**
     * @notice Swaps fee tokens for reward tokens using Uniswap V3. Can be called by anyone.
     * @param _amountIn The amount of fee tokens to swap
     * @param _uniFeeWETH The Uniswap fee tier for WETH pair
     * @param _uniFeeReward The Uniswap fee tier for reward token pair
     * @return _amountOut The amount of reward tokens received
     * @dev Performs a swap from fee tokens to reward tokens via WETH.
     * Uses the contract's balance if requested amount exceeds available balance.
     *
     * Emits a Swap event on successful swap.
     *
     * @custom:error Rewards_SwapDisabled When swap functionality is disabled
     */
    function swapFeeToReward(uint256 _amountIn, uint256 _uniFeeWETH, uint256 _uniFeeReward)
        external
        returns (uint256 _amountOut)
    {
        if (!_swapEnabled) {
            revert Rewards_SwapDisabled();
        }

        uint256 _contractBalance = IERC20(feeToken).balanceOf(address(this));

        if (_amountIn > _contractBalance) {
            _amountIn = _contractBalance;
        }

        IERC20(feeToken).approve(swapRouter, _amountIn);

        ISwapRouter.ExactInputParams memory params = ISwapRouter.ExactInputParams({
            path: abi.encodePacked(feeToken, _uniFeeWETH, WETH, _uniFeeReward, rewardToken),
            recipient: address(this),
            amountIn: _amountIn,
            amountOutMinimum: 0
        });

        _amountOut = ISwapRouter(swapRouter).exactInput(params);

        emit Swap(feeToken, rewardToken, _amountIn, _amountOut);
    }

    /**
     * @notice Compounds claimed rewards back into the voting escrow
     * @param _tokenId The ID of the veCTM token
     * @return The amount of rewards compounded
     * @dev Claims rewards for the token and immediately deposits them back into the voting escrow,
     * extending the lock duration and increasing voting power.
     * 
     * @custom:error Rewards_NoUnclaimedRewards When no rewards are available to claim
     */
    function compoundLockRewards(uint256 _tokenId) external returns (uint256) {
        uint256 _rewards = claimRewards(_tokenId, address(this));
        if (_rewards == 0) {
            revert Rewards_NoUnclaimedRewards();
        }
        IVotingEscrow(ve).deposit_for(_tokenId, _rewards);
        return _rewards;
    }

    /**
     * @notice Gets the current base emission rate
     * @return The current base emission rate
     * @dev Returns the most recent base emission rate from checkpoints.
     */
    function baseEmissionRate() external view returns (uint256) {
        return _baseEmissionRates.latest();
    }

    /**
     * @notice Gets the current node emission rate
     * @return The current node emission rate
     * @dev Returns the most recent node emission rate from checkpoints.
     */
    function nodeEmissionRate() external view returns (uint256) {
        return _nodeEmissionRates.latest();
    }

    /**
     * @notice Gets the current node reward threshold
     * @return The current minimum voting power threshold for node rewards
     * @dev Returns the most recent node reward threshold from checkpoints.
     */
    function nodeRewardThreshold() external view returns (uint256) {
        return _nodeRewardThresholds.latest();
    }

    /**
     * @notice Calculates unclaimed rewards for a token
     * @param _tokenId The ID of the veCTM token
     * @return The amount of unclaimed rewards
     * @dev Calculates rewards that have accrued since the last claim.
     * Considers base rewards, node rewards, and quality scores.
     */
    function unclaimedRewards(uint256 _tokenId) external view returns (uint256) {
        uint48 _latestMidnight = _getLatestMidnight();
        return _calculateRewardsOf(_tokenId, _latestMidnight);
    }

    /**
     * @notice Claims rewards for a token and sends them to a recipient
     * @param _tokenId The ID of the veCTM token
     * @param _to The address to receive the rewards
     * @return The amount of rewards claimed
     * @dev Claims all unclaimed rewards for the token and transfers them to the recipient.
     * Updates the last claim timestamp to prevent double-claiming.
     * 
     * Emits a Claim event on successful claim.
     * 
     * @custom:error Rewards_OnlyAuthorized When caller is not the token owner
     * @custom:error Rewards_NoUnclaimedRewards When no rewards are available to claim
     * @custom:error Rewards_InsufficientContractBalance When contract balance is insufficient
     * @custom:error Rewards_TransferFailed When token transfer fails
     */
    function claimRewards(uint256 _tokenId, address _to) public returns (uint256) {
        if (msg.sender != IERC721(ve).ownerOf(_tokenId)) {
            revert Rewards_OnlyAuthorized(VotingEscrowErrorParam.Sender, VotingEscrowErrorParam.Owner);
        }

        uint48 _latestMidnight = _getLatestMidnight();

        if (_latestMidnight == _lastClaimOf[_tokenId]) {
            revert Rewards_NoUnclaimedRewards();
        }

        _updateLatestMidnight(_latestMidnight);

        uint256 _reward = _calculateRewardsOf(_tokenId, _latestMidnight);

        address _rewardToken = rewardToken;
        uint256 _contractBalance = IERC20(_rewardToken).balanceOf(address(this));

        if (_contractBalance < _reward) {
            revert Rewards_InsufficientContractBalance(_contractBalance, _reward);
        }

        _lastClaimOf[_tokenId] = _latestMidnight;

        if (!IERC20(_rewardToken).transfer(_to, _reward)) {
            revert Rewards_TransferFailed();
        }

        emit Claim(_tokenId, _reward, _rewardToken);

        return _reward;
    }

    /**
     * @notice Gets the base emission rate at a specific timestamp
     * @param _timestamp The timestamp to query
     * @return The base emission rate at the specified timestamp
     * @dev Uses checkpointed data to retrieve historical base emission rates.
     */
    function baseEmissionRateAt(uint256 _timestamp) public view returns (uint256) {
        return _baseEmissionRates.upperLookupRecent(SafeCast.toUint48(_timestamp));
    }

    /**
     * @notice Gets the node emission rate at a specific timestamp
     * @param _timestamp The timestamp to query
     * @return The node emission rate at the specified timestamp
     * @dev Uses checkpointed data to retrieve historical node emission rates.
     */
    function nodeEmissionRateAt(uint256 _timestamp) public view returns (uint256) {
        return _nodeEmissionRates.upperLookupRecent(SafeCast.toUint48(_timestamp));
    }

    /**
     * @notice Gets the node reward threshold at a specific timestamp
     * @param _timestamp The timestamp to query
     * @return The node reward threshold at the specified timestamp
     * @dev Uses checkpointed data to retrieve historical node reward thresholds.
     */
    function nodeRewardThresholdAt(uint256 _timestamp) public view returns (uint256) {
        return _nodeRewardThresholds.upperLookupRecent(SafeCast.toUint48(_timestamp));
    }

    /**
     * @notice Updates the latest midnight timestamp
     * @param _latestMidnight The new latest midnight timestamp
     * @dev Internal function to update the latest midnight timestamp for reward calculations.
     */
    function _updateLatestMidnight(uint48 _latestMidnight) internal {
        latestMidnight = _latestMidnight;
    }

    /**
     * @notice Withdraws tokens to a recipient
     * @param _token The address of the token to withdraw
     * @param _recipient The address to receive the tokens
     * @param _amount The amount of tokens to withdraw
     * @dev Internal function to handle token withdrawals with error handling.
     * 
     * @custom:error Rewards_TransferFailed When token transfer fails
     */
    function _withdrawToken(address _token, address _recipient, uint256 _amount) internal {
        if (!IERC20(_token).transfer(_recipient, _amount)) {
            revert Rewards_TransferFailed();
        }
    }

    /**
     * @notice Sets the base emission rate with checkpointing
     * @param _baseEmissionRate The new base emission rate
     * @dev Internal function to update base emission rate with validation and checkpointing.
     * 
     * @custom:error Rewards_EmissionRateChangeTooHigh When emission rate exceeds 1% of multiplier
     */
    function _setBaseEmissionRate(uint256 _baseEmissionRate) internal {
        if (_baseEmissionRate > MULTIPLIER / 100) {
            revert Rewards_EmissionRateChangeTooHigh();
        }
        uint208 _baseEmissionRate208 = SafeCast.toUint208(_baseEmissionRate);
        (uint256 _oldBaseEmissionRate, uint256 _newBaseEmissionRate) =
            _baseEmissionRates.push(IERC6372(ve).clock(), _baseEmissionRate208);
        emit BaseEmissionRateChange(_oldBaseEmissionRate, _newBaseEmissionRate);
    }

    /**
     * @notice Sets the node emission rate with checkpointing
     * @param _nodeEmissionRate The new node emission rate
     * @dev Internal function to update node emission rate with validation and checkpointing.
     * 
     * @custom:error Rewards_EmissionRateChangeTooHigh When emission rate exceeds 1% of multiplier
     */
    function _setNodeEmissionRate(uint256 _nodeEmissionRate) internal {
        if (_nodeEmissionRate > MULTIPLIER / 100) {
            revert Rewards_EmissionRateChangeTooHigh();
        }
        uint208 _nodeEmissionRate208 = SafeCast.toUint208(_nodeEmissionRate);
        (uint256 _oldNodeEmissionRate, uint256 _newNodeEmissionRate) =
            _nodeEmissionRates.push(IERC6372(ve).clock(), _nodeEmissionRate208);
        emit NodeEmissionRateChange(_oldNodeEmissionRate, _newNodeEmissionRate);
    }

    /**
     * @notice Sets the node reward threshold with checkpointing
     * @param _nodeRewardThreshold The new node reward threshold
     * @dev Internal function to update node reward threshold with checkpointing.
     */
    function _setNodeRewardThreshold(uint256 _nodeRewardThreshold) internal {
        uint208 _nodeRewardThreshold208 = SafeCast.toUint208(_nodeRewardThreshold);
        (uint256 _oldNodeRewardThreshold, uint256 _newNodeRewardThreshold) =
            _nodeRewardThresholds.push(IERC6372(ve).clock(), _nodeRewardThreshold208);
        emit NodeRewardThresholdChange(_oldNodeRewardThreshold, _newNodeRewardThreshold);
    }

    /**
     * @notice Calculates the latest midnight timestamp
     * @return The latest midnight timestamp
     * @dev Calculates the most recent midnight timestamp based on the current clock.
     */
    function _getLatestMidnight() internal view returns (uint48) {
        return IERC6372(ve).clock() - (IERC6372(ve).clock() % ONE_DAY);
    }

    /**
     * @notice Calculates rewards for a token up to a specific midnight
     * @param _tokenId The ID of the veCTM token
     * @param _latestMidnight The midnight timestamp to calculate rewards up to
     * @return The total rewards calculated
     * @dev Calculates rewards day by day, considering:
     * - Base emission rates
     * - Node emission rates and quality scores
     * - Token voting power over time
     * - Token expiration and creation times
     * 
     * Assumes _latestMidnight is up-to-date.
     */
    function _calculateRewardsOf(uint256 _tokenId, uint48 _latestMidnight) internal view returns (uint256) {
        uint48 _lastClaimed = _lastClaimOf[_tokenId];

        // if they have never claimed, ensure their last claim is set to a midnight timestamp
        // Get the token's creation timestamp from the first point in user history
        if (_lastClaimed == 0) {
            // always greater than or equal to genesis
            uint256 _tokenCreationTime = IVotingEscrow(ve).user_point_history__ts(_tokenId, 1);
            if (_tokenCreationTime == 0) {
                return 0;
            }
            uint256 _tokenCreationTimeMidnight = _tokenCreationTime - (_tokenCreationTime % ONE_DAY);
            _lastClaimed = SafeCast.toUint48(_tokenCreationTimeMidnight);
        }

        // number of days between latest midnight and last claimed
        uint48 _daysUnclaimed = (_latestMidnight - _lastClaimed) / ONE_DAY;
        // ensure a midnight has passed since last claim
        assert(_daysUnclaimed * ONE_DAY == (_latestMidnight - _lastClaimed));

        uint256 _reward;
        uint256 _vePower;
        uint256 _prevDayVePower;

        // start at the midnight following their last claim, increment by one day at a time
        // continue until rewards counted for latest midnight
        for (uint48 i = _lastClaimed + ONE_DAY; i <= _lastClaimed + (_daysUnclaimed * ONE_DAY); i += ONE_DAY) {
            uint256 _time = uint256(i);
            _prevDayVePower = _vePower;
            _vePower = IVotingEscrow(ve).balanceOfNFTAt(_tokenId, _time);

            // EARLY EXIT: Get token's expiration time and cap the calculation period
            // (, uint256 _end) = IVotingEscrow(ve).locked(_tokenId);
            if (_time > _lastClaimed + (4 * 365 * ONE_DAY)) {
                break;
            }

            // check if ve power is zero (meaning the token ID didn't exist at this time).
            // previous day ve power is the ve power of the previous iteration of this loop, if it is zero then
            // the midnight in question is less than a day since the token ID was created. This means they don't
            // get rewards for this day, and their rewards instead start at the following midnight.
            // if (_vePower == 0 || _prevDayVePower == 0) {

            // if yesterday's ve power was non-zero and today's is zero, then the token ID has expired at this time.

            if (_vePower == 0 && _prevDayVePower != 0) {
                // case: the ve power was non-zero yesterday, but is zero today.
                // this means the token ID has expired at this time.
                break;
            }

            uint256 _nodeRewardThreshold = nodeRewardThresholdAt(i);
            uint256 _nodeQuality;

            if (_vePower >= _nodeRewardThreshold) {
                _nodeQuality = INodeProperties(nodeProperties).nodeQualityOfAt(_tokenId, _time);
            }

            uint256 _baseEmissionRate = baseEmissionRateAt(i);
            uint256 _nodeEmissionRate = nodeEmissionRateAt(i);

            _reward += _calculateRewards(_vePower, _baseEmissionRate, _nodeEmissionRate, _nodeQuality);
        }

        return _reward;
    }

    /**
     * @notice Calculates rewards for a given voting power and rates
     * @param _votingPower The voting power of the token
     * @param _baseRewards The base emission rate
     * @param _nodeRewards The node emission rate
     * @param _quality The node quality score (0-10)
     * @return The calculated reward amount
     * @dev Calculates rewards using the formula:
     * votingPower * (baseRewards + (quality * nodeRewards / 10)) / MULTIPLIER
     * 
     * The quality score acts as a multiplier for node rewards, with 10 being optimal performance.
     */
    function _calculateRewards(uint256 _votingPower, uint256 _baseRewards, uint256 _nodeRewards, uint256 _quality)
        internal
        pure
        returns (uint256)
    {
        // votingPower * (baseRewards + (quality * (nodeRewards / 10)))
        return _votingPower * (_baseRewards + (_quality * _nodeRewards / 10)) / MULTIPLIER;
    }
}
