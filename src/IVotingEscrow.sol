// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

interface IVotingEscrow is IERC721Metadata, IVotes {
    function version() external view returns (string memory);
    function decimals() external view returns (uint8);
    function token() external view returns (address);
    function governor() external view returns (address);
    function treasury() external view returns (address);
    function nodeProperties() external view returns (address);
    function epoch() external view returns (uint256);
    function baseURI() external view returns (string memory);
    function locked(uint256 tokenId) external view returns (int128, uint256);
    function ownership_change(uint256 tokenId) external view returns (uint256);
    function point_history(uint256 tokenId) external view returns (int128, int128, uint256, uint256);
    // function user_point_history(uint256 tokenId) external view returns (VotingEscrow.Point[] memory);
    function user_point_epoch(uint256 tokenId) external view returns (uint256);
    function slope_changes(uint256 tokenId) external view returns (int128);

    function initialize(address token_addr, string memory base_uri) external;
    function create_lock(uint256 _value, uint256 _lock_duration) external returns (uint256);
    function create_lock_for(uint256 _value, uint256 _lock_duration, address _to) external returns (uint256);
    function create_nonvoting_lock_for(uint256 _value, uint256 _lock_duration, address _to) external returns (uint256);
    function increase_amount(uint256 _tokenId, uint256 _value) external;
    function increase_unlock_time(uint256 _tokenId, uint256 _lock_duration) external;
    function withdraw(uint256 _tokenId) external;
    function merge(uint256 _from, uint256 _to) external;
    function split(uint256 _tokenId, uint256 _extracted) external returns (uint256);
    function liquidate(uint256 _tokenId) external;
    function deposit_for(uint256 _tokenId, uint256 _value) external;
    function checkpoint() external;

    function balanceOfNFT(uint256 _tokenId) external view returns (uint256);
    function balanceOfNFTAt(uint256 _tokenId, uint256 _t) external view returns (uint256);
    function balanceOfAtNFT(uint256 _tokenId, uint256 _block) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function totalPower() external view returns (uint256);
    function totalPowerAtT(uint256 t) external view returns (uint256);
    function totalPowerAt(uint256 _block) external view returns (uint256);
    function isApprovedOrOwner(address _spender, uint256 _tokenId) external view returns (bool);
    function tokenOfOwnerByIndex(address _owner, uint256 _tokenIndex) external view returns (uint256);
    function get_last_user_slope(uint256 _tokenId) external view returns (int128);
    function user_point_history__ts(uint256 _tokenId, uint256 _idx) external view returns (uint256);
    function locked__end(uint256 _tokenId) external view returns (uint256);

    function setup(address _governor, address _nodeProperties, address _rewards, address _treasury) external;
    function enableLiquidations() external;

    function nonVoting(uint256 _tokenId) external view returns (bool);
    function tokenIdsDelegatedTo(address account) external view returns (uint256[] memory);
    function tokenIdsDelegatedToAt(address account, uint256 timepoint) external view returns (uint256[] memory);
    function liquidationsEnabled() external view returns (bool);

    // dummy
    //

    // ERC721 + Metadata + ERC165 + Votes
    //
    // name
    // symbol
    // transferFrom
    // approve
    // setApprovalForAll
    // safeTransferFrom (w/ data)
    // safeTransferFrom
    // balanceOf
    // ownerOf
    // getApproved
    // getApprovedForAll
    // tokenURI
    // supportsInterface
    // delegate
    // delegateBySig
    // getVotes
    // getPastVotes
    // getPastTotalSupply
    // delegates
}