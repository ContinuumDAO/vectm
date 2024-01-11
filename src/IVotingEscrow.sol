// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

struct Point {
    int128 bias;
    int128 slope;
    uint256 ts;
    uint256 blk;
}

struct LockedBalance {
    int128 amount;
    uint256 end;
}

interface IVotingEscrow {
    // public state
    function token() external view returns (address);
    function supply() external view returns (uint256);
    function ownership_change(uint256 tokenId) external view returns (uint256);
    function epoch() external view returns (uint256);
    function slope_changes(uint256 time) external view returns (int128);
    // function name() external view returns (string memory);
    // function symbol() external view returns (string memory);
    function version() external view returns (string memory);
    function decimals() external view returns (uint8);
    function baseURI() external view returns (string memory);
    function governor() external view returns (address);
    // function locked(uint256 tokenId) external view returns (LockedBalance memory);
    // function point_history(uint256 epoch) external view returns (Point memory);
    // function user_point_history(uint256 tokenId) external view returns (Point[] memory);

    // PROXY
    function initialize(address token_addr, address _governor, string memory base_uri) external;

    /**
     * @notice ERC721 standard methods
     * function balanceOf(address _owner) external view returns (uint256);
     * function ownerOf(uint256 _tokenId) external view returns (address);
     * function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes memory _data) external;
     * function safeTransferFrom(address _from, address _to, uint256 _tokenId) external;
     * function transferFrom(address _from, address _to, uint256 _tokenId) external;
     * function approve(address _approved, uint256 _tokenId) external;
     * function setApprovalForAll(address _operator, bool _approved) external;
     * function getApproved(uint256 _tokenId) external view returns (address);
     * function isApprovedForAll(address _owner, address _operator) external view returns (bool);
     * function tokenURI(uint256 _tokenId) external view returns (string memory);
     * function supportsInterface(bytes4 _interfaceID) external view returns (bool);
     */

    /** 
     * @notice Votes standard methods
     * function getVotes(address _account) external view returns (uint256);
     * function getPastVotes(address _account, uint256 _timepoint) external view returns (uint256);
     * function getPastTotalSupply(uint256 _timepoint) external view returns (uint256);
     * function delegates(address _account) external view returns (address);
     * function delegate(address _delegatee) external;
     * function delegateBySig(address _delegatee, uint256 _nonce, uint256 _expiry, uint8 _v, bytes32 _r, bytes32 _s) external;
     */

    // create lock
    function create_lock_for(uint256 _value, uint256 _lock_duration, address _to) external returns (uint256);
    function create_lock(uint256 _value, uint256 _lock_duration) external returns (uint256);

    // increase lock
    function increase_amount(uint256 _tokenId, uint256 _value) external;
    function increase_unlock_time(uint256 _tokenId, uint256 _lock_duration) external;
    function deposit_for(uint256 _tokenId, uint256 _value) external;

    // lock interactions
    function merge(uint256 _from, uint256 _to) external;
    function withdraw(uint256 _tokenId) external;

    // random interactions
    function checkpoint() external;

    // view - nft util
    function tokenOfOwnerByIndex(address _owner, uint256 _tokenIndex) external view returns (uint256);
    function isApprovedOrOwner(address _spender, uint256 _tokenId) external view returns (bool);

    // view - balance of
    function balanceOfNFT(uint256 _tokenId) external view returns (uint256);
    function balanceOfNFTAt(uint256 _tokenId, uint256 _t) external view returns (uint256);
    function balanceOfAtNFT(uint256 _tokenId, uint256 _block) external view returns (uint256);

    // view - total supply
    function totalSupplyAtT(uint256 t) external view returns (uint256);
    function totalSupplyAt(uint256 _block) external view returns (uint256);

    // view - token id
    function locked__end(uint256 _tokenId) external view returns (uint256);
    function get_last_user_slope(uint256 _tokenId) external view returns (int128);
    function user_point_history__ts(uint256 _tokenId, uint256 _idx) external view returns (uint256);

    // view - global
    function block_number() external view returns (uint256);
}