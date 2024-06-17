// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

interface IVotingEscrow {
    // struct Point {
    //     int128 bias;
    //     int128 slope;
    //     uint256 ts;
    //     uint256 blk;
    // }

    // struct CheckpointArray {
    //     uint256 _key;
    //     uint256[] _values;
    // }

    // events
    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId); // IERC721
    event Approval(address indexed _owner, address indexed _approved, uint256 indexed _tokenId); // IERC721
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved); // IERC721

    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate); // IVotes
    event DelegateVotesChanged(address indexed delegate, uint256 previousVotes, uint256 newVotes); // IVotes

    // errors
    error VotesExpiredSignature(uint256 _expiry); // IVotes

    // STORAGE
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
    // function user_point_history(uint256 tokenId) external view returns (Point[] memory);
    function user_point_epoch(uint256 _tokenId) external view returns (uint256);
    function slope_changes(uint256 _tokenId) external view returns (int128);
    function nonVoting(uint256 _tokenId) external view returns (bool);
    function version() external view returns (string memory);
    function decimals() external view returns (uint8);
    function LIQ_PENALTY_NUM() external view returns (uint256);
    function LIQ_PENALTY_DEN() external view returns (uint256);
    function liquidationsEnabled() external view returns (bool);

    // IERC165
    function supportsInterface(bytes4 _interfaceid) external view returns (bool); // IERC165

    // IERC6372
    function clock() external view returns (uint48); // IERC6372
    function CLOCK_MODE() external view returns (string memory); // IERC6372

    // IERC721
    function balanceOf(address _owner) external view returns (uint256); // IERC721
    function ownerOf(uint256 _tokenid) external view returns (address); // IERC721
    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes memory _data) external; // IERC721
    function safeTransferFrom(address _from, address _to, uint256 _tokenId) external; // IERC721
    function transferFrom(address _from, address _to, uint256 _tokenId) external; // IERC721
    function approve(address _to, uint256 _tokenId) external; // IERC721
    function setApprovalForAll(address _operator, bool _approved) external; // IERC721
    function getApproved(uint256 _tokenid) external view returns (address); // IERC721
    function isApprovedForAll(address _owner, address _operator) external view returns (bool); // IERC721

    // IERC721Metadata
    function name() external view returns (string memory); // IERC721Metadata
    function symbol() external view returns (string memory); // IERC721Metadata
    function tokenURI(uint256 _tokenid) external view returns (string memory); // IERC721Metadata

    // IERC721Enumerable
    function totalSupply() external view returns (uint256); // IERC721Enumerable
    function tokenOfOwnerByIndex(address _owner, uint256 _index) external view returns (uint256); // IERC721Enumerable
    function tokenByIndex(uint256 _index) external view returns (uint256); // IERC721Enumerable

    // IVotes
    function getVotes(address _account) external view returns (uint256); // IVotes
    function getPastVotes(address _account, uint256 _timepoint) external view returns (uint256); // IVotes
    function getPastTotalSupply(uint256 _timepoint) external view returns (uint256); // IVotes
    function delegates(address _account) external view returns (address); // IVotes
    function delegate(address _delegatee) external; // IVotes
    function delegateBySig(
        address _delegatee,
        uint256 _nonce,
        uint256 _expiry,
        uint8 _v,
        bytes32 _r,
        bytes32 _s)
    external; // IVotes

    // UUPSUpgradeable
    function initialize(address _token_addr, string memory _base_uri) external;

    // VotingEscrow Core
    function create_lock(uint256 _value, uint256 _lock_duration) external returns (uint256);
    function create_lock_for(uint256 _value, uint256 _lock_duration, address _to) external returns (uint256);
    function increase_amount(uint256 _tokenId, uint256 _value) external;
    function increase_unlock_time(uint256 _tokenId, uint256 _lock_duration) external;
    function withdraw(uint256 _tokenId) external;
    function deposit_for(uint256 _tokenId, uint256 _value) external;
    function checkpoint() external;
    //
    function balanceOfNFT(uint256 _tokenid) external view returns (uint256);
    function balanceOfNFTAt(uint256 _tokenid, uint256 _t) external view returns (uint256);
    function balanceOfAtNFT(uint256 _tokenid, uint256 _block) external view returns (uint256);
    function isApprovedOrOwner(address _spender, uint256 _tokenid) external view returns (bool);
    function get_last_user_slope(uint256 _tokenid) external view returns (int128);
    function user_point_history__ts(uint256 _tokenid, uint256 _idx) external view returns (uint256);
    function locked__end(uint256 _tokenid) external view returns (uint256);

    // ContinuumDAO Modifications
    function merge(uint256 _from, uint256 _to) external;
    function split(uint256 _tokenId, uint256 _extracted) external returns (uint256);
    function liquidate(uint256 _tokenId) external;
    function setUp(address _governor, address _nodeProperties, address _rewards, address _treasury) external;
    function setBaseURI(string memory _baseURI) external;
    function enableLiquidations() external;
    //
    function totalPower() external view returns (uint256);
    function totalPowerAtT(uint256 t) external view returns (uint256);
    function totalPowerAt(uint256 _block) external view returns (uint256);
    function tokenIdsDelegatedTo(address _account) external view returns (uint256[] memory);
    function tokenIdsDelegatedToAt(address _account, uint256 _timepoint) external view returns (uint256[] memory);
    // function checkpoints(address _account, uint256 _index) external view returns (CheckpointArray memory);
    function create_nonvoting_lock_for(uint256 _value, uint256 _lock_duration, address _to) external returns (uint256);
}