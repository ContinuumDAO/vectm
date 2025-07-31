// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

import {ArrayCheckpoints} from "../utils/ArrayCheckpoints.sol";

interface IVotingEscrow {
    /// @notice Type declarations
    struct Point {
        int128 bias;
        int128 slope; // # -dweight / dt
        uint256 ts;
        uint256 blk; // block
    }

    struct LockedBalance {
        int128 amount;
        uint256 end;
    }

    enum DepositType {
        DEPOSIT_FOR_TYPE,
        CREATE_LOCK_TYPE,
        INCREASE_LOCK_AMOUNT,
        INCREASE_UNLOCK_TIME,
        MERGE_TYPE
    }

    /// @notice Events
    event Deposit(
        address indexed _provider,
        uint256 _tokenId,
        uint256 _value,
        uint256 indexed _locktime,
        DepositType _deposit_type,
        uint256 _ts
    );
    event Withdraw(address indexed _provider, uint256 _tokenId, uint256 _value, uint256 _ts);
    event Supply(uint256 _prevSupply, uint256 _supply);
    event Merge(uint256 indexed _fromId, uint256 indexed _toId);
    event Split(uint256 indexed _tokenId, uint256 indexed _extractionId, uint256 _extractionValue);
    event Liquidate(uint256 indexed _tokenId, uint256 _value, uint256 _penalty);

    /// @notice Errors
    error ERC6372InconsistentClock();
    error ERC5805FutureLookup(uint256 _timepoint, uint48 _clock);
    error InvalidAccountNonce(address _account, uint256 _currentNonce);
    error SameTimestamp();
    error NotApproved(address _spender, uint256 _tokenId);

    /// @notice Storage
    function token() external view returns (address);
    function governor() external view returns (address);
    function nodeProperties() external view returns (address);
    function rewards() external view returns (address);
    function treasury() external view returns (address);
    function epoch() external view returns (uint256);
    function baseURI() external view returns (string memory);
    function locked(uint256 _tokenId) external view returns (int128, uint256);
    function ownership_change(uint256 _tokenId) external view returns (uint256);
    function point_history(uint256 _tokenId) external view returns (int128, int128, uint256, uint256);
    function user_point_epoch(uint256 _tokenId) external view returns (uint256);
    function slope_changes(uint256 _tokenId) external view returns (int128);
    function nonVoting(uint256 _tokenId) external view returns (bool);
    function version() external view returns (string memory);
    function decimals() external view returns (uint8);
    function LIQ_PENALTY_NUM() external view returns (uint256);
    function LIQ_PENALTY_DEN() external view returns (uint256);
    function liquidationsEnabled() external view returns (bool);

    /// @notice IERC721Metadata
    function name() external view returns (string memory); // IERC721Metadata
    function symbol() external view returns (string memory); // IERC721Metadata
    function tokenURI(uint256 _tokenid) external view returns (string memory); // IERC721Metadata

    /// @notice IERC721Enumerable
    function totalSupply() external view returns (uint256); // IERC721Enumerable
    function tokenOfOwnerByIndex(address _owner, uint256 _index) external view returns (uint256); // IERC721Enumerable
    function tokenByIndex(uint256 _index) external view returns (uint256); // IERC721Enumerable

    /// @notice UUPSUpgradeable
    function initialize(address _token_addr, string memory _base_uri) external;

    /// @notice VotingEscrow Core
    function create_lock(uint256 _value, uint256 _lock_duration) external returns (uint256);
    function create_lock_for(uint256 _value, uint256 _lock_duration, address _to) external returns (uint256);
    function create_nonvoting_lock_for(uint256 _value, uint256 _lock_duration, address _to) external returns (uint256);
    function increase_amount(uint256 _tokenId, uint256 _value) external;
    function increase_unlock_time(uint256 _tokenId, uint256 _lock_duration) external;
    function withdraw(uint256 _tokenId) external;
    function deposit_for(uint256 _tokenId, uint256 _value) external;
    function checkpoint() external;

    function balanceOfNFT(uint256 _tokenid) external view returns (uint256);
    function balanceOfNFTAt(uint256 _tokenid, uint256 _t) external view returns (uint256);
    function balanceOfAtNFT(uint256 _tokenid, uint256 _block) external view returns (uint256);
    function isApprovedOrOwner(address _spender, uint256 _tokenid) external view returns (bool);
    function get_last_user_slope(uint256 _tokenid) external view returns (int128);
    function user_point_history__ts(uint256 _tokenid, uint256 _idx) external view returns (uint256);
    function locked__end(uint256 _tokenid) external view returns (uint256);

    /// @notice ContinuumDAO Modifications
    function merge(uint256 _from, uint256 _to) external;
    function split(uint256 _tokenId, uint256 _extracted) external returns (uint256);
    function liquidate(uint256 _tokenId) external;
    function setUp(address _governor, address _nodeProperties, address _rewards, address _treasury) external;
    function setBaseURI(string memory _baseURI) external;
    function enableLiquidations() external;

    function totalPower() external view returns (uint256);
    function totalPowerAtT(uint256 t) external view returns (uint256);
    function totalPowerAt(uint256 _block) external view returns (uint256);
    function tokenIdsDelegatedTo(address _account) external view returns (uint256[] memory);
    function tokenIdsDelegatedToAt(address _account, uint256 _timepoint) external view returns (uint256[] memory);
    function checkpoints(address _account, uint256 _index) external view returns (ArrayCheckpoints.CheckpointArray memory);
}
