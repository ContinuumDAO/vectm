// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;
pragma abicoder v2;

import "@openzeppelin/contracts/utils/structs/Checkpoints.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC6372} from "@openzeppelin/contracts/interfaces/IERC6372.sol";

interface IVotingEscrow {
    function balanceOfNFTAt(uint256 _tokenId, uint256 _ts) external view returns (uint256);
}

interface ISwapRouter {
    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    function exactInput(ExactInputParams memory params) external returns (uint256 amountOut);
}


contract Rewards {
    using Checkpoints for Checkpoints.Trace208;

    struct Fee {
        address token;
        uint256 amount;
    }

    uint48 public constant ONE_DAY = 1 days;
    uint48 public latestMidnight;
    uint48 public genesis;

    address public gov; // for deciding on node quality scores
    address public committee; // for validating nodes' KYC
    address public rewardToken; // reward token
    address public feeToken; // eg. USDC
    address public swapRouter; // UniV3
    address public ve; // voting escrow

    address public immutable WETH; // for middle-man in swap

    bool internal _swapEnabled;

    Checkpoints.Trace208 internal _baseEmissionRates; // CTM / vePower
    Checkpoints.Trace208 internal _nodeEmissionRates; // CTM / vePower
    Checkpoints.Trace208 internal _nodeRewardThresholds; // minimum ve power threshold for node rewards

    mapping(uint256 => Checkpoints.Trace208) internal _nodeQualitiesOf; // token ID => ts checkpointed quality score
    mapping(uint256 => bool) internal _nodeValidated; // token ID => KYC check
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

    modifier onlyCommittee {
        require(msg.sender == committee);
        _;
    }

    constructor(
        uint48 _firstMidnight,
        address _gov,
        address _committee,
        address _rewardToken,
        address _feeToken,
        address _swapRouter,
        address _ve,
        address _weth
    ) {
        genesis = _firstMidnight;
        gov = _gov;
        committee = _committee;
        rewardToken = _rewardToken;
        feeToken = _feeToken;
        swapRouter = _swapRouter;
        ve = _ve;
        WETH = _weth;
    }



    // external mutable
    function setBaseEmissionRate(uint208 _baseEmissionRate) external onlyGov {
        uint208 _baseEmissionRate208 = SafeCast.toUint208(_baseEmissionRate);
        (uint256 _oldBaseEmissionRate, uint256 _newBaseEmissionRate) =
            _baseEmissionRates.push(clock(), _baseEmissionRate208);
        emit BaseEmissionRateChange(_oldBaseEmissionRate, _newBaseEmissionRate);
    }

    function setNodeEmissionRate(uint208 _nodeEmissionRate) external onlyGov {
        uint208 _nodeEmissionRate208 = SafeCast.toUint208(_nodeEmissionRate);
        (uint256 _oldNodeEmissionRate, uint256 _newNodeEmissionRate) =
            _nodeEmissionRates.push(clock(), _nodeEmissionRate208);
        emit NodeEmissionRateChange(_oldNodeEmissionRate, _newNodeEmissionRate);
    }

    function setNodeRewardThreshold(uint256 _nodeRewardThreshold) external onlyGov {
        uint208 _nodeRewardThreshold208 = SafeCast.toUint208(_nodeRewardThreshold);
        (uint256 _oldNodeRewardThreshold, uint256 _newNodeRewardThreshold) =
            _nodeRewardThresholds.push(clock(), _nodeRewardThreshold208);
        emit NodeRewardThresholdChange(_oldNodeRewardThreshold, _newNodeRewardThreshold);
    }

    function setNodeQualityOf(uint256 _tokenId, uint208 _nodeQualityOf) external onlyGov {
        assert(_nodeQualityOf <= 10);
        _nodeQualitiesOf[_tokenId].push(clock(), _nodeQualityOf);
    }

    function setNodeValidations(uint256[] memory _tokenIds, bool[] memory _validated) external onlyCommittee {
        for (uint8 i = 0; i < _tokenIds.length; i++) {
            _nodeValidated[_tokenIds[i]] = _validated[i];
        }
    }

    function setCommittee(address _committee) external onlyGov {
        committee = _committee;
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

    function setSwapEnabled(bool _enabled) external onlyGov {
        _swapEnabled = _enabled;
    }

    function receiveFees(address _token, uint256 _amount, uint256 _fromChainId) external {
        require(_token == feeToken || _token == rewardToken);

        if (_feeReceivedFromChainAt[_fromChainId][clock()].amount != 0) {
            revert FeesAlreadyReceivedFromChain();
        }

        require(IERC20(_token).transferFrom(msg.sender, address(this), _amount));

        _feeReceivedFromChainAt[_fromChainId][clock()] = Fee(_token, _amount);
        emit FeesReceived(_token, _amount, _fromChainId);
    }

    function claimRewards(uint256 _tokenId, address _to) external {
        require(IERC721(ve).ownerOf(_tokenId) == msg.sender);

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

        require(IERC20(_rewardToken).transfer(_to, _reward));

        emit Claim(_tokenId, _reward, _rewardToken);
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

    function nodeQualityOf(uint256 _tokenId) external view returns (uint256) {
        return uint256(_nodeQualitiesOf[_tokenId].latest());
    }

    function unclaimedRewards(uint256 _tokenId) external view returns (uint256) {
        uint48 _latestMidnight = _getLatestMidnight();
        return _calculateRewardsOf(_tokenId, _latestMidnight);
    }

    function nodeValidated(uint256 _tokenId) external view returns (bool) {
        return _nodeValidated[_tokenId];
    }



    // public view
    function clock() public view returns (uint48) {
        return uint48(block.timestamp);
    }

    function CLOCK_MODE() public view returns (string memory) {
        if (clock() != uint48(block.timestamp)) {
            revert ERC6372InconsistentClock();
        }
        return "mode=timestamp";
    }

    function baseEmissionRateAt(uint256 _timestamp) public view returns (uint256) {
        return _baseEmissionRates.upperLookupRecent(SafeCast.toUint48(_timestamp));
    }

    function nodeEmissionRateAt(uint256 _timestamp) public view returns (uint256) {
        return _nodeEmissionRates.upperLookupRecent(SafeCast.toUint48(_timestamp));
    }

    function nodeRewardThresholdAt(uint256 _timestamp) public view returns (uint256) {
        return _nodeRewardThresholds.upperLookupRecent(SafeCast.toUint48(_timestamp));
    }

    function nodeQualityOfAt(uint256 _tokenId, uint256 _timestamp) public view returns (uint256) {
        return _nodeQualitiesOf[_tokenId].upperLookupRecent(SafeCast.toUint48(_timestamp));
    }



    // internal mutable
    function _updateLatestMidnight(uint48 _latestMidnight) internal {
        latestMidnight = _latestMidnight;
    }

    function _withdrawToken(address _token, address _recipient, uint256 _amount) internal {
        require(IERC20(_token).transfer(_recipient, _amount));
    }



    // internal view
    function _getLatestMidnight() internal view returns (uint48) {
        uint48 _latestMidnight = latestMidnight;

        if ((clock() - _latestMidnight) < ONE_DAY) {
            return _latestMidnight;
        }

        while (_latestMidnight < (clock() - ONE_DAY)) {
            _latestMidnight += ONE_DAY;
        }

        return _latestMidnight;
    }

    // only call when assuming _latestMidnight is up-to-date
    function _calculateRewardsOf(uint256 _tokenId, uint48 _latestMidnight) internal view returns (uint256) {
        uint48 _lastClaimed = _lastClaimOf[_tokenId];

        if (_lastClaimed == 0) {
            _lastClaimed = genesis;
        }

        uint48 _daysUnclaimed = (_latestMidnight - _lastClaimed) / ONE_DAY;
        assert(_daysUnclaimed * ONE_DAY == (_latestMidnight - _lastClaimed));

        uint256 _reward;

        for (uint48 i = _lastClaimed + ONE_DAY; i <= _daysUnclaimed; i += ONE_DAY) {
            uint256 _vePower = IVotingEscrow(ve).balanceOfNFTAt(_tokenId, uint256(i));
            uint256 _nodeRewardThreshold = nodeRewardThresholdAt(i);
            uint256 _nodeQuality;

            if (_vePower >= _nodeRewardThreshold) {
                _nodeQuality = nodeQualityOfAt(_tokenId, i);
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
        return _votingPower * (_baseRewards + _quality * _nodeRewards) / 10;
    }
}