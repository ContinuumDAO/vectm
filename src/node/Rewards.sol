// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import {Checkpoints} from "@openzeppelin/contracts/utils/structs/Checkpoints.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC6372} from "@openzeppelin/contracts/interfaces/IERC6372.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {IVotingEscrow} from "../token/IVotingEscrow.sol";
import {INodeProperties} from "./INodeProperties.sol";
import {ISwapRouter} from "./ISwapRouter.sol";

contract Rewards {
    using Checkpoints for Checkpoints.Trace208;

    struct Fee {
        address token;
        uint256 amount;
    }

    uint48 public constant ONE_DAY = 1 days;
    uint256 public constant MULTIPLIER = 1 ether;
    uint48 public latestMidnight;
    uint48 public genesis;

    uint256 public feePerByteRewardToken; // CTM
    uint256 public feePerByteFeeToken; // USDC

    address public gov; // for deciding on node quality scores
    address public rewardToken; // reward token
    address public feeToken; // eg. USDC
    address public swapRouter; // UniV3
    address public nodeProperties; // node info storage
    address public ve; // voting escrow

    address public immutable WETH; // for middle-man in swap

    bool internal _swapEnabled;

    Checkpoints.Trace208 internal _baseEmissionRates; // CTM / vePower
    Checkpoints.Trace208 internal _nodeEmissionRates; // CTM / vePower
    Checkpoints.Trace208 internal _nodeRewardThresholds; // minimum ve power threshold for node rewards

    mapping(uint256 => uint48) internal _lastClaimOf; // token ID => midnight ts starting last day they claimed
    mapping(uint256 => mapping(uint48 => Fee)) internal _feeReceivedFromChainAt;

    // events
    event BaseEmissionRateChange(uint256 _oldBaseEmissionRate, uint256 _newBaseEmissionRate);
    event NodeEmissionRateChange(uint256 _oldNodeEmissionRate, uint256 _newNodeEmissionRate);
    event NodeRewardThresholdChange(uint256 _oldMinimumThreshold, uint256 _newMinimumThreshold);
    event RewardTokenChange(address indexed _oldRewardToken, address indexed _newRewardToken);
    event FeeTokenChange(address indexed _oldFeeToken, address indexed _newFeeToken);
    event Claim(uint256 indexed _tokenId, uint256 _claimedReward, address indexed _rewardToken);
    event Withdrawal(address indexed _token, address indexed _recipient, uint256 _amount);
    event FeesReceived(address indexed _token, uint256 _amount, uint256 indexed _fromChainId);
    event Swap(address indexed _feeToken, address indexed _rewardToken, uint256 _amountIn, uint256 _amountOut);

    // errors
    error ERC6372InconsistentClock();
    error NoUnclaimedRewards();
    error InsufficientContractBalance(uint256 _balance, uint256 _required);
    error FeesAlreadyReceivedFromChain();

    modifier onlyGov() {
        require(msg.sender == gov);
        _;
    }

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



    // external mutable
    function setBaseEmissionRate(uint256 _baseEmissionRate) external onlyGov {
        _setBaseEmissionRate(_baseEmissionRate);
    }

    function setNodeEmissionRate(uint256 _nodeEmissionRate) external onlyGov {
        _setNodeEmissionRate(_nodeEmissionRate);
    }

    function setNodeRewardThreshold(uint256 _nodeRewardThreshold) external onlyGov {
        _setNodeRewardThreshold(_nodeRewardThreshold);
    }

    function withdrawToken(address _token, address _recipient, uint256 _amount) external onlyGov {
        _withdrawToken(_token, _recipient, _amount);
        emit Withdrawal(_token, _recipient, _amount);
    }

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

    function setFeePerByteRewardToken(uint256 _fee) external onlyGov {
        feePerByteRewardToken = _fee;
    }

    function setFeePerByteFeeToken(uint256 _fee) external onlyGov {
        feePerByteFeeToken = _fee;
    }

    function setNodeProperties(address _nodeProperties) external onlyGov {
        nodeProperties = _nodeProperties;
    }

    function setSwapEnabled(bool _enabled) external onlyGov {
        _swapEnabled = _enabled;
    }

    function receiveFees(address _token, uint256 _amount, uint256 _fromChainId) external {
        require(_token == feeToken || _token == rewardToken);

        if (_feeReceivedFromChainAt[_fromChainId][IERC6372(ve).clock()].amount != 0) {
            revert FeesAlreadyReceivedFromChain();
        }

        require(IERC20(_token).transferFrom(msg.sender, address(this), _amount));

        _feeReceivedFromChainAt[_fromChainId][IERC6372(ve).clock()] = Fee(_token, _amount);
        emit FeesReceived(_token, _amount, _fromChainId);
    }

    function updateLatestMidnight() external {
        uint48 _latestMidnight = _getLatestMidnight();
        _updateLatestMidnight(_latestMidnight);
    }

    function swapFeeToReward(
        uint256 _amountIn,
        uint256 _deadline,
        uint256 _uniFeeWETH,
        uint256 _uniFeeReward
    ) external returns (uint256 _amountOut) {
        require(_swapEnabled);
        uint256 _contractBalance = IERC20(feeToken).balanceOf(address(this));

        if (_amountIn > _contractBalance) {
            _amountIn = _contractBalance;
        }

        IERC20(feeToken).approve(swapRouter, _amountIn);

        ISwapRouter.ExactInputParams memory params = ISwapRouter.ExactInputParams({
            path: abi.encodePacked(feeToken, _uniFeeWETH, WETH, _uniFeeReward, rewardToken),
            recipient: address(this),
            deadline: _deadline,
            amountIn: _amountIn,
            amountOutMinimum: 0
        });

        _amountOut = ISwapRouter(swapRouter).exactInput(params);

        emit Swap(feeToken, rewardToken, _amountIn, _amountOut);
    }

    function compoundLockRewards(uint256 _tokenId) external returns (uint256) {
        uint256 _rewards = claimRewards(_tokenId, address(this));
        IVotingEscrow(ve).deposit_for(_tokenId, _rewards);
        return _rewards;
    }



    // external view
    function baseEmissionRate() external view returns (uint256) {
        return _baseEmissionRates.latest();
    }

    function nodeEmissionRate() external view returns (uint256) {
        return _nodeEmissionRates.latest();
    }

    function nodeRewardThreshold() external view returns (uint256) {
        return _nodeRewardThresholds.latest();
    }

    function unclaimedRewards(uint256 _tokenId) external view returns (uint256) {
        uint48 _latestMidnight = _getLatestMidnight();
        return _calculateRewardsOf(_tokenId, _latestMidnight);
    }



    // public mutable
    function claimRewards(uint256 _tokenId, address _to) public returns (uint256) {
        require(IERC721(ve).ownerOf(_tokenId) == msg.sender, "Only owner of token ID can claim rewards.");

        uint48 _latestMidnight = _getLatestMidnight();

        if (_latestMidnight == _lastClaimOf[_tokenId]) {
            revert NoUnclaimedRewards();
        }

        _updateLatestMidnight(_latestMidnight);

        uint256 _reward = _calculateRewardsOf(_tokenId, _latestMidnight);

        address _rewardToken = rewardToken;
        uint256 _contractBalance = IERC20(_rewardToken).balanceOf(address(this));

        if (_contractBalance < _reward) {
            revert InsufficientContractBalance(_contractBalance, _reward);
        }

        _lastClaimOf[_tokenId] = _latestMidnight;

        require(IERC20(_rewardToken).transfer(_to, _reward));

        emit Claim(_tokenId, _reward, _rewardToken);

        return _reward;
    }



    // public view
    function baseEmissionRateAt(uint256 _timestamp) public view returns (uint256) {
        return _baseEmissionRates.upperLookupRecent(SafeCast.toUint48(_timestamp));
    }

    function nodeEmissionRateAt(uint256 _timestamp) public view returns (uint256) {
        return _nodeEmissionRates.upperLookupRecent(SafeCast.toUint48(_timestamp));
    }

    function nodeRewardThresholdAt(uint256 _timestamp) public view returns (uint256) {
        return _nodeRewardThresholds.upperLookupRecent(SafeCast.toUint48(_timestamp));
    }



    // internal mutable
    function _updateLatestMidnight(uint48 _latestMidnight) internal {
        latestMidnight = _latestMidnight;
    }

    function _withdrawToken(address _token, address _recipient, uint256 _amount) internal {
        require(IERC20(_token).transfer(_recipient, _amount));
    }

    function _setBaseEmissionRate(uint256 _baseEmissionRate) internal {
        require(_baseEmissionRate <= MULTIPLIER / 100, "Cannot set base rewards per vepower-day higher than 1%.");
        uint208 _baseEmissionRate208 = SafeCast.toUint208(_baseEmissionRate);
        (uint256 _oldBaseEmissionRate, uint256 _newBaseEmissionRate) =
            _baseEmissionRates.push(IERC6372(ve).clock(), _baseEmissionRate208);
        emit BaseEmissionRateChange(_oldBaseEmissionRate, _newBaseEmissionRate);
    }

    function _setNodeEmissionRate(uint256 _nodeEmissionRate) internal {
        require(_nodeEmissionRate <= MULTIPLIER / 100, "Cannot set node rewards per vepower-day higher than 1%.");
        uint208 _nodeEmissionRate208 = SafeCast.toUint208(_nodeEmissionRate);
        (uint256 _oldNodeEmissionRate, uint256 _newNodeEmissionRate) =
            _nodeEmissionRates.push(IERC6372(ve).clock(), _nodeEmissionRate208);
        emit NodeEmissionRateChange(_oldNodeEmissionRate, _newNodeEmissionRate);
    }

    function _setNodeRewardThreshold(uint256 _nodeRewardThreshold) internal {
        uint208 _nodeRewardThreshold208 = SafeCast.toUint208(_nodeRewardThreshold);
        (uint256 _oldNodeRewardThreshold, uint256 _newNodeRewardThreshold) =
            _nodeRewardThresholds.push(IERC6372(ve).clock(), _nodeRewardThreshold208);
        emit NodeRewardThresholdChange(_oldNodeRewardThreshold, _newNodeRewardThreshold);
    }



    // internal view
    function _getLatestMidnight() internal view returns (uint48) {
        uint48 _latestMidnight = latestMidnight;
        uint48 _time = IERC6372(ve).clock();

        if ((_time - _latestMidnight) < ONE_DAY) {
            return _latestMidnight;
        }

        while (_latestMidnight < (_time - ONE_DAY)) {
            _latestMidnight += ONE_DAY;
        }

        return _latestMidnight;
    }

    // only call when assuming _latestMidnight is up-to-date
    function _calculateRewardsOf(uint256 _tokenId, uint48 _latestMidnight) internal view returns (uint256) {
        uint48 _lastClaimed = _lastClaimOf[_tokenId];

        // if they have never claimed, ensure their last claim is set to a midnight timestamp
        if (_lastClaimed == 0) {
            _lastClaimed = genesis;
        }

        // number of days between latest midnight and last claimed
        uint48 _daysUnclaimed = (_latestMidnight - _lastClaimed) / ONE_DAY;
        // ensure a midnight has passed since last claim
        assert(_daysUnclaimed * ONE_DAY == (_latestMidnight - _lastClaimed));

        uint256 _reward;
        uint256 _prevDayVePower;

        // start at the midnight following their last claim, increment by one day at a time
        // continue until rewards counted for latest midnight
        for (uint48 i = _lastClaimed + ONE_DAY; i <= _lastClaimed + (_daysUnclaimed * ONE_DAY); i += ONE_DAY) {
            uint256 _time = uint256(i);
            uint256 _vePower = IVotingEscrow(ve).balanceOfNFTAt(_tokenId, _time);

            // check if ve power is zero (meaning the token ID didn't exist at this time).
            // previous day ve power is the ve power of the previous iteration of this loop, if it is zero then
            // the midnight in question is less than a day since the token ID was created. This means they don't
            // get rewards for this day, and their rewards instead start at the following midnight.
            if (_vePower == 0 || _prevDayVePower == 0) {
                _prevDayVePower = _vePower;
                continue;
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



    // internal pure
    function _calculateRewards(
        uint256 _votingPower,
        uint256 _baseRewards,
        uint256 _nodeRewards,
        uint256 _quality
    ) internal pure returns (uint256) {
        // votingPower * (baseRewards + (quality * (nodeRewards / 10)))
        return _votingPower * (_baseRewards + (_quality * _nodeRewards / 10)) / MULTIPLIER;
    }
}
