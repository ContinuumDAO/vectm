// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC6372} from "@openzeppelin/contracts/interfaces/IERC6372.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {INodeProperties} from "../node/INodeProperties.sol";
import {IRewards} from "../node/IRewards.sol";
import {IVotingEscrow} from "./IVotingEscrow.sol";
import {ArrayCheckpoints} from "../utils/ArrayCheckpoints.sol";

/**
 * @title Voting Escrow
 * @author Curve Finance, Solidly, w/ OpenZeppelin contracts
 * @author Modified for ContinuumDAO by @patrickcure
 * @notice Votes have a weight depending on time, so that users are
 * committed to the future of (whatever they are voting for)
 * @notice Compatible with UUPS proxy pattern, OpenZeppelin Governor Votes
 * @dev Vote weight decays linearly over time. Lock time cannot be
 * more than `MAXTIME` (4 years).
 * Voting escrow to have time-weighted votes
 * Votes have a weight depending on time, so that users are committed
 * to the future of (whatever they are voting for).
 * The weight in this implementation is linear, and lock cannot be more than maxtime:
 *  w ^
 * 1 +        /
 *   |      /
 *   |    /
 *   |  /
 *   |/
 * 0 +--------+------> time
 *       maxtime (4 years?)
 */
contract VotingEscrow is IVotingEscrow, IERC721, IERC6372, IERC721Receiver, IVotes, UUPSUpgradeable {
    using ArrayCheckpoints for ArrayCheckpoints.TraceArray;

    /// @notice State variables
    ///
    address public token;
    address public governor;
    address public nodeProperties;
    address public rewards;
    address public treasury;
    uint256 public epoch;
    string public baseURI;
    uint8 internal _entered_state;
    uint256 internal _supply;
    uint256 internal tokenId; // current count of token
    uint256 internal _totalSupply; // total # of NFTs

    mapping(uint256 => LockedBalance) public locked;
    mapping(uint256 => uint256) public ownership_change; // prevent flash NFT
    mapping(uint256 => Point) public point_history; // epoch -> unsigned point
    mapping(uint256 => Point[1_000_000_000]) private user_point_history; // user -> Point[user_epoch]
    mapping(uint256 => uint256) public user_point_epoch;
    mapping(uint256 => int128) public slope_changes; // time -> signed slope change
    mapping(uint256 => address) internal idToOwner; // mapping from NFT ID to the address that owns it.
    mapping(uint256 => address) internal idToApprovals; // mapping from NFT ID to approved address.
    mapping(address => uint256) internal ownerToNFTokenCount; // mapping from owner address to count of his tokens.
    mapping(address => mapping(uint256 => uint256)) internal ownerToNFTokenIdList; // mapping from owner address to mapping of index to tokenIds
    mapping(uint256 => uint256) internal tokenToOwnerIndex; // mapping from NFT ID to index of owner
    mapping(address => mapping(address => bool)) internal ownerToOperators; // mapping from owner address to mapping of operator addresses.
    mapping(bytes4 => bool) internal supportedInterfaces; // mapping of interface id to bool about whether or not it's supported
    mapping(uint256 => bool) public nonVoting; // token ID -> whether the veCTM is voting or non-voting
 
    mapping(address => address) internal _delegatee; // delegated addresses
    /** 
        Example of delegated checkpoints of an address
        [ {timestamp 1, [1, 2, 3]}, {timestamp 2, [1, 2, 3, 5]}, {timestamp 3, [1, 2, 5]} ]
    */ 
    mapping(address => ArrayCheckpoints.TraceArray) internal _delegateCheckpoints; // address delegatee -> array checkpoints
    mapping(address => uint256) internal _nonces; // tracking a signature's account nonce, incremented when delegateBySig is called

    string public constant name = "Voting Escrow Continuum";
    string public constant symbol = "veCTM";
    string public constant version = "1.0.0";
    uint8 public constant decimals = 18;
    bytes16 internal constant HEX_DIGITS = "0123456789abcdef";
    uint256 internal constant WEEK = 7 * 86400;
    uint256 internal constant MAXTIME = 4 * 365 * 86400;
    uint256 internal constant MULTIPLIER = 1e18;
    int128 internal constant iMAXTIME = 4 * 365 * 86400;

    uint256 public constant LIQ_PENALTY_NUM = 50_000; // penalty for liquidating veCTM before maturity date. 50,000 / 100,000  =  50%
    uint256 public constant LIQ_PENALTY_DEN = 100_000;
    bool public liquidationsEnabled;

    // ERC165 interface ID of ERC165
    bytes4 internal constant ERC165_INTERFACE_ID = 0x01ffc9a7;
    // ERC165 interface ID of ERC721
    bytes4 internal constant ERC721_INTERFACE_ID = 0x80ac58cd;
    // ERC165 interface ID of ERC721Metadata
    bytes4 internal constant ERC721_METADATA_INTERFACE_ID = 0x5b5e139f;
    // ERC165 interface ID of Votes
    bytes4 internal constant VOTES_INTERFACE_ID = 0xe90fb3f6;
    // ERC165 interface ID of ERC6372
    bytes4 internal constant ERC6372_INTERFACE_ID = 0xda287a1d;

    // reentrancy guard
    uint8 internal constant NOT_ENTERED = 1;
    uint8 internal constant ENTERED = 2;

    bytes32 private constant TYPE_HASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private constant DELEGATION_TYPEHASH =
        keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    /// @notice Modifiers
    ///
    modifier nonreentrant() {
        require(_entered_state == NOT_ENTERED);
        _entered_state = ENTERED;
        _;
        _entered_state = NOT_ENTERED;
    }

    modifier onlyGov() {
        require(msg.sender == governor, "ContinuumDAO: Only Governor can perform this operation.");
        _;
    }

    modifier checkNotAttached(uint256 _tokenId) {
        require(
            INodeProperties(nodeProperties).attachedNodeId(_tokenId) == bytes32(""),
            "Detach node before interacting with token ID."
        );
        _;
    }

    modifier checkNoRewards(uint256 _tokenId) {
        require(IRewards(rewards).unclaimedRewards(_tokenId) == 0, "Claim rewards before interacting with token ID.");
        _;
    }

    /// @notice Contract constructor
    /// @dev Proxy pattern contract - disable initializers for implementation on deployment
    constructor() {
        _disableInitializers();
    }

    /// @notice External mutable
    ///
    /// @notice Contract initializer
    /// @param token_addr `ERC20CRV` token address
    /// @param base_uri Base URI for token ID images
    function initialize(address token_addr, string memory base_uri) external initializer {
        __UUPSUpgradeable_init();
        token = token_addr;
        baseURI = base_uri;
        point_history[0].blk = block.number;
        point_history[0].ts = block.timestamp;

        supportedInterfaces[ERC165_INTERFACE_ID] = true;
        supportedInterfaces[ERC721_INTERFACE_ID] = true;
        supportedInterfaces[ERC721_METADATA_INTERFACE_ID] = true;
        supportedInterfaces[VOTES_INTERFACE_ID] = true;
        supportedInterfaces[ERC6372_INTERFACE_ID] = true;

        _entered_state = 1;

        emit Transfer(address(0), address(this), tokenId);
        emit Transfer(address(this), address(0), tokenId);
    }

    /// @notice Deposit `_value` tokens for `msg.sender` and lock for `_lock_duration`
    /// @param _value Amount to deposit
    /// @param _lock_duration Number of seconds to lock tokens for (rounded down to nearest week)
    function create_lock(uint256 _value, uint256 _lock_duration) external nonreentrant returns (uint256) {
        return _create_lock(_value, _lock_duration, msg.sender);
    }

    /// @notice Deposit `_value` tokens for `_to` and lock for `_lock_duration`
    /// @param _value Amount to deposit
    /// @param _lock_duration Number of seconds to lock tokens for (rounded down to nearest week)
    /// @param _to Address to deposit
    function create_lock_for(uint256 _value, uint256 _lock_duration, address _to)
        external
        nonreentrant
        returns (uint256)
    {
        return _create_lock(_value, _lock_duration, _to);
    }

    /// @notice Deposit `_value` additional tokens for `_tokenId` without modifying the unlock time
    /// @param _value Amount of tokens to deposit and add to the lock
    function increase_amount(uint256 _tokenId, uint256 _value) external nonreentrant {
        _checkApprovedOrOwner(msg.sender, _tokenId);

        LockedBalance memory _locked = locked[_tokenId];

        require(_value > 0); // dev: need non-zero value
        require(_locked.amount > 0, "No existing lock found");
        require(_locked.end > block.timestamp, "Cannot add to expired lock. Withdraw");

        _deposit_for(_tokenId, _value, 0, _locked, DepositType.INCREASE_LOCK_AMOUNT);
    }

    /// @notice Extend the unlock time for `_tokenId`
    /// @param _lock_duration New number of seconds until tokens unlock
    function increase_unlock_time(uint256 _tokenId, uint256 _lock_duration) external nonreentrant {
        _checkApprovedOrOwner(msg.sender, _tokenId);

        LockedBalance memory _locked = locked[_tokenId];
        uint256 unlock_time = ((block.timestamp + _lock_duration) / WEEK) * WEEK; // Locktime is rounded down to weeks

        require(_locked.end > block.timestamp, "Lock expired");
        require(_locked.amount > 0, "Nothing is locked");
        require(unlock_time > _locked.end, "Can only increase lock duration");
        require(unlock_time <= block.timestamp + MAXTIME, "Voting lock can be 4 years max");

        _deposit_for(_tokenId, 0, unlock_time, _locked, DepositType.INCREASE_UNLOCK_TIME);
    }

    /// @notice Withdraw all tokens for `_tokenId`
    /// @dev Only possible if the lock has expired
    function withdraw(uint256 _tokenId) external nonreentrant checkNotAttached(_tokenId) checkNoRewards(_tokenId) {
        _withdraw(_tokenId);
    }

    /// @notice Merge two token IDs and combine their underlying values.
    /// @dev End timestamp of merge is value-weighted based on composite tokens.
    /// @param _from The token ID that gets burned.
    /// @param _to The token ID that burned token gets merged into.
    function merge(uint256 _from, uint256 _to) external checkNotAttached(_from) checkNotAttached(_to) checkNoRewards(_from) checkNoRewards(_to) {
        require(
            (!nonVoting[_from] && !nonVoting[_to]) || (nonVoting[_from] && nonVoting[_to]),
            "veCTM: Merging between voting and non-voting token ID not allowed"
        );

        require(_from != _to);
        _checkApprovedOrOwner(msg.sender, _from);
        _checkApprovedOrOwner(msg.sender, _to);

        if (ownership_change[_from] == clock() || ownership_change[_to] == clock()) {
            revert SameTimestamp();
        }

        address ownerFrom = idToOwner[_from];
        address ownerTo = idToOwner[_from];
        require(ownerFrom == ownerTo);

        uint256 supply_before = _supply;
        LockedBalance memory _locked0 = locked[_from];
        LockedBalance memory _locked1 = locked[_to];
        uint256 value0 = uint256(int256(_locked0.amount));
        uint256 value1 = uint256(int256(_locked1.amount));
        // value-weighted end timestamp
        uint256 weightedEnd = (value0 * _locked0.end + value1 * _locked1.end) / (value0 + value1);
        // round down to week and then add one week to prevent rounding down exploit
        // uint256 unlock_time = (((block.timestamp + weightedEnd) / WEEK) * WEEK) + WEEK; // Incorrect
        uint256 unlock_time = ((weightedEnd / WEEK) * WEEK) + WEEK;

        // checkpoint the _from lock to zero (_from gets burned)
        locked[_from] = LockedBalance(0, 0);
        _checkpoint(_from, _locked0, LockedBalance(0, 0));
        // checkpoint the owner's balance to remove _from ID
        uint256[] memory _votingUnit = new uint256[](1);
        _votingUnit[0] = _from;
        _moveDelegateVotes(ownerFrom, address(0), _votingUnit);
        _burn(_from);

        // add _from lock value to _to lock, using the value-weighted and rounded unlock time
        _deposit_for(_to, value0, unlock_time, _locked1, DepositType.MERGE_TYPE);
        // we need to decrease the supply by value0 because _deposit_for adds it again, when in reality
        // _supply doesn't change in this operation
        _supply -= value0;
        assert(_supply == supply_before);

        emit Merge(_from, _to);
    }

    /// @notice Split into two NFTs, with a new one created with an extracted value.
    /// @param _tokenId The token ID to be split.
    /// @param _extraction The underlying value to be used to make a new NFT.
    function split(uint256 _tokenId, uint256 _extraction) external checkNotAttached(_tokenId) checkNoRewards(_tokenId) returns (uint256) {
        _checkApprovedOrOwner(msg.sender, _tokenId);

        address owner = idToOwner[_tokenId];
        LockedBalance memory _locked = locked[_tokenId];
        require(block.timestamp < _locked.end);
        // uint256 remaining_time = _locked.end - block.timestamp;
        // require(remaining_time > WEEK, "Cannot split for lock with under one week left");
        int128 value = _locked.amount;
        int128 extraction = SafeCast.toInt128(SafeCast.toInt256(_extraction));
        require(extraction < value);
        int128 remainder = value - extraction;
        uint256 supply_before = _supply;

        locked[_tokenId] = LockedBalance(remainder, _locked.end);
        _checkpoint(_tokenId, _locked, LockedBalance(remainder, _locked.end));

        uint256 extractionId;
        if (nonVoting[_tokenId]) {
            // create another non-voting lock
            // adding a week to lock duration to prevent rounding down exploit
            extractionId = create_nonvoting_lock_for(_extraction, (_locked.end - block.timestamp) + WEEK, owner);
        } else {
            // create another voting lock
            // adding a week to lock duration to prevent rounding down exploit
            extractionId = _create_lock(_extraction, (_locked.end - block.timestamp) + WEEK, owner);
        }

        // we need to decrease the supply by _extraction because _deposit_for adds it again, when in reality
        // _supply doesn't change in this operation
        _supply -= _extraction;
        assert(_supply == supply_before);

        emit Split(_tokenId, extractionId, _extraction);

        return extractionId;
    }

    /// @notice Opt-out mechanism for users to liquidate their veCTM anytime before end timestamp, incurring a penalty.
    /// @dev User is penalized 50% of their remaining voting power in underlying tokens, transferred to the DAO treasury.
    /// e.g. Unlock at 4 years before end => user is penalized 50% of tokens
    ///      Unlock at 3 years before end => user is penalized 37.5% of tokens
    ///      Unlock at 2 years before end => user is penalized 25% of tokens
    ///      Unlock at 1 year before end => user is penalized 12.5% of tokens
    ///      Unlock on/after end => user is not penalized.
    /// @dev Minimum value to withdraw is 100 gwei, to prevent liquidation of low voting power, as this can
    ///      potentially lead to zero penalty.
    function liquidate(uint256 _tokenId) external nonreentrant checkNotAttached(_tokenId) checkNoRewards(_tokenId) {
        require(liquidationsEnabled);
        _checkApprovedOrOwner(msg.sender, _tokenId);
        address owner = idToOwner[_tokenId];
        LockedBalance memory _locked = locked[_tokenId];
        if (block.timestamp >= _locked.end) {
            _withdraw(_tokenId);
            return;
        }
        uint256 value = uint256(int256(_locked.amount));
        require(value > 100 gwei);
        uint256 vePower = _balanceOfNFT(_tokenId, block.timestamp);
        uint256 penalty = vePower * LIQ_PENALTY_NUM / LIQ_PENALTY_DEN;
        assert(penalty != 0);

        locked[_tokenId] = LockedBalance(0, 0);
        uint256 supply_before = _supply;
        _supply = supply_before - value;

        _checkpoint(_tokenId, _locked, LockedBalance(0, 0));

        assert(IERC20(token).transfer(owner, value - penalty));
        assert(IERC20(token).transfer(treasury, penalty));

        // checkpoint the owner's balance to remove _from ID
        uint256[] memory _votingUnit = new uint256[](1);
        _votingUnit[0] = _tokenId;
        _moveDelegateVotes(owner, address(0), _votingUnit);

        // Burn the NFT
        _burn(_tokenId);

        emit Liquidate(_tokenId, value, penalty);
    }

    /// @notice Deposit `_value` tokens for `_tokenId` and add to the lock
    /// @dev Anyone (even a smart contract) can deposit for someone else, but
    ///      cannot extend their locktime and deposit for a brand new user
    /// @param _tokenId lock NFT
    /// @param _value Amount to add to user's lock
    function deposit_for(uint256 _tokenId, uint256 _value) external nonreentrant {
        LockedBalance memory _locked = locked[_tokenId];

        require(_value > 0); // dev: need non-zero value
        require(_locked.amount > 0, "No existing lock found");
        require(_locked.end > block.timestamp, "Cannot add to expired lock. Withdraw");
        _deposit_for(_tokenId, _value, 0, _locked, DepositType.DEPOSIT_FOR_TYPE);
    }

    /// @dev Throws unless `msg.sender` is the current owner, an authorized operator, or the approved address for this NFT.
    ///      Throws if `_from` is not the current owner.
    ///      Throws if `_to` is the zero address.
    ///      Throws if `_tokenId` is not a valid NFT.
    /// @notice The caller is responsible to confirm that `_to` is capable of receiving NFTs or else
    ///        they maybe be permanently lost.
    /// @param _from The current owner of the NFT.
    /// @param _to The new owner.
    /// @param _tokenId The NFT to transfer.
    function transferFrom(address _from, address _to, uint256 _tokenId) external {
        _transferFrom(_from, _to, _tokenId, msg.sender);
    }

    function approve(address _approved, uint256 _tokenId) external {
        _approve(_approved, _tokenId);
    }

    /// @dev Enables or disables approval for a third party ("operator") to manage all of
    ///      `msg.sender`'s assets. It also emits the ApprovalForAll event.
    ///      Throws if `_operator` is the `msg.sender`. (NOTE: This is not written the EIP)
    /// @notice This works even if sender doesn't own any tokens at the time.
    /// @param _operator Address to add to the set of authorized operators.
    /// @param _approved True if the operators is approved, false to revoke approval.
    function setApprovalForAll(address _operator, bool _approved) external {
        // Throws if `_operator` is the `msg.sender`
        assert(_operator != msg.sender);
        ownerToOperators[msg.sender][_operator] = _approved;
        emit ApprovalForAll(msg.sender, _operator, _approved);
    }

    /// @notice Delegate all voting power for your balance of token IDs to an address.
    /// @param delegatee The address to cast your total voting power.
    function delegate(address delegatee) external {
        address account = msg_sender();
        _delegate(account, delegatee);
    }

    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes memory _data) external {
        _safeTransferFrom(_from, _to, _tokenId, _data);
    }

    /// @dev Transfers the ownership of an NFT from one address to another address.
    ///      Throws unless `msg.sender` is the current owner, an authorized operator, or the
    ///      approved address for this NFT.
    ///      Throws if `_from` is not the current owner.
    ///      Throws if `_to` is the zero address.
    ///      Throws if `_tokenId` is not a valid NFT.
    ///      If `_to` is a smart contract, it calls `onERC721Received` on `_to` and throws if
    ///      the return value is not `bytes4(keccak256("onERC721Received(address,address,uint,bytes)"))`.
    /// @param _from The current owner of the NFT.
    /// @param _to The new owner.
    /// @param _tokenId The NFT to transfer.
    function safeTransferFrom(address _from, address _to, uint256 _tokenId) external {
        _safeTransferFrom(_from, _to, _tokenId, "");
    }

    /// @notice Record global data to checkpoint
    function checkpoint() external {
        _checkpoint(0, LockedBalance(0, 0), LockedBalance(0, 0));
    }

    /// @notice Because Voting Escrow is deployed before other contracts, we need a setup function.
    function setUp(address _governor, address _nodeProperties, address _rewards, address _treasury) external {
        require(governor == address(0) || msg.sender == governor);
        governor = _governor == address(0) ? governor : _governor;
        nodeProperties = _nodeProperties == address(0) ? nodeProperties : _nodeProperties;
        rewards = _rewards == address(0) ? rewards : _rewards;
        treasury = _treasury == address(0) ? treasury : _treasury;
    }

    function setBaseURI(string memory _baseURI) external onlyGov {
        baseURI = _baseURI;
    }

    /// @notice One time use flag to enable liquidations.
    function enableLiquidations() external onlyGov {
        require(treasury != address(0));
        liquidationsEnabled = true;
    }

    /// @notice External view
    ///
    /// @dev Returns the number of NFTs owned by `_owner`.
    ///      Throws if `_owner` is the zero address. NFTs assigned to the zero address are considered invalid.
    /// @param _owner Address for whom to query the balance.
    function balanceOf(address _owner) external view returns (uint256) {
        return _balance(_owner);
    }

    function balanceOfNFT(uint256 _tokenId) external view returns (uint256) {
        if (ownership_change[_tokenId] == clock()) return 0;
        return _balanceOfNFT(_tokenId, block.timestamp);
    }

    function balanceOfNFTAt(uint256 _tokenId, uint256 _t) external view returns (uint256) {
        return _balanceOfNFT(_tokenId, _t);
    }

    function balanceOfAtNFT(uint256 _tokenId, uint256 _block) external view returns (uint256) {
        return _balanceOfAtNFT(_tokenId, _block);
    }

    /// @dev Returns the address of the owner of the NFT.
    /// @param _tokenId The identifier for an NFT.
    function ownerOf(uint256 _tokenId) external view returns (address) {
        return idToOwner[_tokenId];
    }

    /// @notice Return the total number of NFTs.
    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    /// @notice Return the current total vote power.
    function totalPower() external view returns (uint256) {
        return _totalPowerAtT(block.timestamp);
    }

    /// @notice Calculate total voting power
    /// @dev Adheres to the ERC20 `totalSupply` interface for Aragon compatibility
    /// @return Total voting power
    function totalPowerAtT(uint256 t) external view returns (uint256) {
        return _totalPowerAtT(t);
    }

    /// @notice Calculate total voting power at some point in the past
    /// @param _block Block to calculate the total voting power at
    /// @return Total voting power at `_block`
    function totalPowerAt(uint256 _block) external view returns (uint256) {
        assert(_block <= block.number);
        uint256 _epoch = epoch;
        uint256 target_epoch = _find_block_epoch(_block, _epoch);

        Point memory point = point_history[target_epoch];
        uint256 dt = 0;
        if (target_epoch < _epoch) {
            Point memory point_next = point_history[target_epoch + 1];
            if (point.blk != point_next.blk) {
                dt = ((_block - point.blk) * (point_next.ts - point.ts)) / (point_next.blk - point.blk);
            }
        } else {
            if (point.blk != block.number) {
                dt = ((_block - point.blk) * (block.timestamp - point.ts)) / (block.number - point.blk);
            }
        }
        // Now dt contains info on how far are we beyond point
        return _supply_at(point, point.ts + dt);
    }

    /// @dev Get the approved address for a single NFT.
    /// @param _tokenId ID of the NFT to query the approval of.
    function getApproved(uint256 _tokenId) external view returns (address) {
        return idToApprovals[_tokenId];
    }

    /// @dev Checks if `_operator` is an approved operator for `_owner`.
    /// @param _owner The address that owns the NFTs.
    /// @param _operator The address that acts on behalf of the owner.
    function isApprovedForAll(address _owner, address _operator) external view returns (bool) {
        return (ownerToOperators[_owner])[_operator];
    }

    function isApprovedOrOwner(address _spender, uint256 _tokenId) external view returns (bool) {
        return _isApprovedOrOwner(_spender, _tokenId);
    }

    /// @dev Get token by index
    function tokenOfOwnerByIndex(address _owner, uint256 _tokenIndex) external view returns (uint256) {
        return ownerToNFTokenIdList[_owner][_tokenIndex];
    }

    /// @dev Get token as a global index
    function tokenByIndex(uint256 _index) external view returns (uint256) {
        if (_index < _totalSupply) {
            return _index + 1;
        } else {
            return 0;
        }
    }

    /// @notice Governor compliant method for counting current voting power of an address.
    function getVotes(address account) external view returns (uint256) {
        uint256[] memory delegateTokenIdsCurrent = _delegateCheckpoints[account].latest();
        return _calculateCumulativeVotingPower(delegateTokenIdsCurrent, clock());
    }

    /// @notice Governor compliant method for counting voting power of an address at a historic timestamp, by getting
    ///         their balance of token IDs at that timestamp and the corresponding vote power of each one at that time.
    /// @param account The address to get votes for.
    /// @param timepoint The timestamp to get votes for.
    /// @dev The votes are calculated at the upper checkpoint of a binary search on that user's delegation history.
    function getPastVotes(address account, uint256 timepoint) external view returns (uint256) {
        uint48 timepoint48 = SafeCast.toUint48(timepoint);
        uint48 currentTimepoint = clock();
        if (timepoint48 >= currentTimepoint) {
            revert ERC5805FutureLookup(timepoint, currentTimepoint);
        }
        uint256[] memory delegateTokenIdsAt = _delegateCheckpoints[account].upperLookupRecent(timepoint48);
        return _calculateCumulativeVotingPower(delegateTokenIdsAt, timepoint48);
    }

    /**
     * @notice The total voting power at a historic timestamp.
     * @dev The name `getPastTotalSupply` is maintained to keep in-line with IVotes interface, but it actually returns
     *      total vote power. For current total supply of NFTs, call `totalSupply`.
     */
    function getPastTotalSupply(uint256 timepoint) external view returns (uint256) {
        uint48 timepoint48 = SafeCast.toUint48(timepoint);
        uint48 currentTimepoint = clock();
        if (timepoint48 >= currentTimepoint) {
            revert ERC5805FutureLookup(timepoint, currentTimepoint);
        }
        return _totalPowerAtT(timepoint);
    }

    /// @notice Check the current delegated address for `account`.
    function delegates(address account) external view returns (address) {
        return _delegatee[account];
    }

    /// @notice Get the list of token IDs that are currently delegated to `account`.
    function tokenIdsDelegatedTo(address account) external view returns (uint256[] memory) {
        return _delegateCheckpoints[account].latest();
    }

    /// @notice Get the list of token IDs that were delegated to `account` at historic timestamp.
    function tokenIdsDelegatedToAt(address account, uint256 timepoint) external view returns (uint256[] memory) {
        return _delegateCheckpoints[account].upperLookupRecent(timepoint);
    }

    /// @notice Get the most recently recorded rate of voting power decrease for `_tokenId`
    /// @param _tokenId token of the NFT
    /// @return Value of the slope
    function get_last_user_slope(uint256 _tokenId) external view returns (int128) {
        uint256 uepoch = user_point_epoch[_tokenId];
        return user_point_history[_tokenId][uepoch].slope;
    }

    /// @notice Get the timestamp for checkpoint `_idx` for `_tokenId`
    /// @param _tokenId token of the NFT
    /// @param _idx User epoch number
    /// @return Epoch time of the checkpoint
    function user_point_history__ts(uint256 _tokenId, uint256 _idx) external view returns (uint256) {
        return user_point_history[_tokenId][_idx].ts;
    }

    /// @notice Get timestamp when `_tokenId`'s lock finishes
    /// @param _tokenId User NFT
    /// @return Epoch time of the lock end
    function locked__end(uint256 _tokenId) external view returns (uint256) {
        return locked[_tokenId].end;
    }

    /// @dev Returns current token URI metadata
    /// @param _tokenId Token ID to fetch URI for.
    function tokenURI(uint256 _tokenId) external view returns (string memory) {
        require(idToOwner[_tokenId] != address(0), "Query for nonexistent token");
        string memory _baseURI = baseURI;
        return bytes(_baseURI).length > 0 ? string(abi.encodePacked(_baseURI, toString(_tokenId))) : "";
    }

    /// @notice ERC165 compliant method for checking supported interfaces.
    function supportsInterface(bytes4 _interfaceID) external view returns (bool) {
        return supportedInterfaces[_interfaceID];
    }

    /// @notice Get the checkpoint (including timestamp and list of delegated token IDs) at position `_index` in the
    ///         delegated checkpoint array of address `account`.
    function checkpoints(address _account, uint256 _index) external view returns (ArrayCheckpoints.CheckpointArray memory) {
        uint32 _index32 = SafeCast.toUint32(_index);
        return _delegateCheckpoints[_account].at(_index32);
    }

    /// @notice Public mutable
    ///
    /// @notice Create a lock that has voting power, but that the delegatee cannot use to cast votes.
    function create_nonvoting_lock_for(uint256 _value, uint256 _lock_duration, address _to)
        public
        nonreentrant
        returns (uint256)
    {
        uint256 _tokenId = _create_lock(_value, _lock_duration, _to);
        nonVoting[_tokenId] = true;
        return _tokenId;
    }

    function delegateBySig(
        address delegatee,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        if (block.timestamp > expiry) {
            revert VotesExpiredSignature(expiry);
        }

        bytes32 domainSeparator = keccak256(abi.encode(TYPE_HASH, name, version, block.chainid, address(this)));
        bytes32 structHash = keccak256(abi.encode(DELEGATION_TYPEHASH, delegatee, nonce, expiry));
        bytes32 digest;

        assembly {
            let ptr := mload(0x40)
            mstore(ptr, hex"19_01")
            mstore(add(ptr, 0x02), domainSeparator)
            mstore(add(ptr, 0x22), structHash)
            digest := keccak256(ptr, 0x42)
        }

        address signer = ECDSA.recover(digest, v, r, s);

        unchecked {
            uint256 current = _nonces[signer]++;
            if (nonce != current) revert InvalidAccountNonce(signer, current);
        }

        _delegate(signer, delegatee);
    }


    /// @notice Public view
    ///
    /// @notice ERC6372
    function clock() public view returns (uint48) {
        return uint48(block.timestamp);
    }

    /// @notice ERC6372
    function CLOCK_MODE() public view returns (string memory) {
        if (clock() != uint48(block.timestamp)) {
            revert ERC6372InconsistentClock();
        }
        return "mode=timestamp";
    }

    /// @notice Internal mutable
    ///
    /// @dev Set or reaffirm the approved address for an NFT. The zero address indicates there is no approved address.
    ///      Throws unless `msg.sender` is the current NFT owner, or an authorized operator of the current owner.
    ///      Throws if `_tokenId` is not a valid NFT. (NOTE: This is not written the EIP)
    ///      Throws if `_approved` is the current owner. (NOTE: This is not written the EIP)
    /// @param _approved Address to be approved for the given NFT ID.
    /// @param _tokenId ID of the token to be approved.
    function _approve(address _approved, uint256 _tokenId) internal {
        address owner = idToOwner[_tokenId];
        // Throws if `_tokenId` is not a valid NFT
        require(owner != address(0));
        // Throws if `_approved` is the current owner
        require(_approved != owner);
        // Check requirements
        bool senderIsOwner = (idToOwner[_tokenId] == msg.sender);
        bool senderIsApprovedForAll = (ownerToOperators[owner])[msg.sender];
        require(senderIsOwner || senderIsApprovedForAll);
        // Set the approval
        idToApprovals[_tokenId] = _approved;
        emit Approval(owner, _approved, _tokenId);
    }

    /// @notice Deposit `_value` tokens for `_to` and lock for `_lock_duration`
    /// @param _value Amount to deposit
    /// @param _lock_duration Number of seconds to lock tokens for (rounded down to nearest week)
    /// @param _to Address to deposit
    /// @dev If the receiver does not have a delegatee, then automatically delegate receiver.
    ///      Otherwise, checkpoint the receiver's delegatee's balance with the new token ID.
    function _create_lock(uint256 _value, uint256 _lock_duration, address _to) internal returns (uint256) {
        uint256 unlock_time = ((block.timestamp + _lock_duration) / WEEK) * WEEK; // Locktime is rounded down to weeks

        require(_value > 0); // dev: need non-zero value
        require(unlock_time > block.timestamp, "Can only lock until time in the future");

        ++tokenId;
        uint256 _tokenId = tokenId;
        _mint(_to, _tokenId);

        _deposit_for(_tokenId, _value, unlock_time, locked[_tokenId], DepositType.CREATE_LOCK_TYPE);
 
        // move delegated votes to the receiver upon deposit
        // doesn't matter if it's for a non-voting token as that gets checked when `getVotes` is called
        address owner = idToOwner[_tokenId];
        if (_delegatee[owner] == address(0)) {
            _delegate(owner, owner);
        } else {
            uint256[] memory _votingUnit = new uint256[](1);
            _votingUnit[0] = _tokenId;
            _moveDelegateVotes(address(0), _delegatee[owner], _votingUnit);
        }

        return _tokenId;
    }

    /// @notice Deposit and lock tokens for a user
    /// @param _tokenId NFT that holds lock
    /// @param _value Amount to deposit
    /// @param unlock_time New time when to unlock the tokens, or 0 if unchanged
    /// @param locked_balance Previous locked amount / timestamp
    /// @param deposit_type The type of deposit
    function _deposit_for(
        uint256 _tokenId,
        uint256 _value,
        uint256 unlock_time,
        LockedBalance memory locked_balance,
        DepositType deposit_type
    ) internal {
        // if locktime is less than a week over max time then subtract one week
        if (unlock_time > block.timestamp + MAXTIME && unlock_time - (block.timestamp + MAXTIME) <= WEEK) {
            unlock_time -= WEEK;
        }

        require(unlock_time <= block.timestamp + MAXTIME, "Voting lock can be 4 years max");

        LockedBalance memory _locked = locked_balance;
        uint256 supply_before = _supply;

        _supply = supply_before + _value;
        LockedBalance memory old_locked;
        (old_locked.amount, old_locked.end) = (_locked.amount, _locked.end);
        // Adding to existing lock, or if a lock is expired - creating a new one
        _locked.amount += SafeCast.toInt128(SafeCast.toInt256(_value));
        if (unlock_time != 0) {
            _locked.end = unlock_time;
        }
        locked[_tokenId] = _locked;

        // Possibilities:
        // Both old_locked.end could be current or expired (>/< block.timestamp)
        // value == 0 (extend lock) or value > 0 (add to lock or extend lock)
        // _locked.end > block.timestamp (always)
        _checkpoint(_tokenId, old_locked, _locked);

        address from = msg.sender;
        if (_value != 0 && deposit_type != DepositType.MERGE_TYPE) {
            assert(IERC20(token).transferFrom(from, address(this), _value));
        }

        emit Deposit(from, _tokenId, _value, _locked.end, deposit_type, block.timestamp);
        emit Supply(supply_before, supply_before + _value);
    }

    /// @notice Change the delegatee of `account` to `delegatee` including all currently delegated token IDs.
    function _delegate(address account, address delegatee) internal {
        address oldDelegate = _delegatee[account];
        _delegatee[account] = delegatee;

        emit DelegateChanged(account, oldDelegate, delegatee);
        _moveDelegateVotes(oldDelegate, delegatee, _getVotingUnits(account));
    }

    /**
     * @dev Remove a specific amount of token IDs from the delegated balance of `from` and move them to `to`.
     * Checkpoint both delegatees. 
     */
    function _moveDelegateVotes(address from, address to, uint256[] memory deltaTokenIDs) private {
        if (from != to) {
            if (from != address(0)) {
                (uint256 oldBalance, uint256 newBalance) = _push(
                    _delegateCheckpoints[from],
                    _remove,
                    deltaTokenIDs
                );
                emit DelegateVotesChanged(from, oldBalance, newBalance);
            }
            if (to != address(0)) {
                (uint256 oldBalance, uint256 newBalance) = _push(
                    _delegateCheckpoints[to],
                    _add,
                    deltaTokenIDs
                );
                emit DelegateVotesChanged(to, oldBalance, newBalance);
            }
        }
    }

    /// @dev Exeute transfer of a NFT.
    ///      Throws unless `msg.sender` is the current owner, an authorized operator, or the approved
    ///      address for this NFT. (NOTE: `msg.sender` not allowed in internal function so pass `_sender`.)
    ///      Throws if `_to` is the zero address.
    ///      Throws if `_from` is not the current owner.
    ///      Throws if `_tokenId` is not a valid NFT.
    function _transferFrom(
        address _from,
        address _to,
        uint256 _tokenId,
        address _sender
    ) internal checkNotAttached(_tokenId) {
        // Check requirements
        _checkApprovedOrOwner(_sender, _tokenId);

        // move delegated votes
        uint256[] memory _votingUnit = new uint256[](1);
        _votingUnit[0] = _tokenId;
        if (ownership_change[_tokenId] == clock()) {
            revert SameTimestamp();
        }
        _moveDelegateVotes(_delegatee[_from], _delegatee[_to], _votingUnit);

        // Clear approval. Throws if `_from` is not the current owner
        _clearApproval(_from, _tokenId);
        // Remove NFT. Throws if `_tokenId` is not a valid NFT
        _removeTokenFrom(_from, _tokenId);
        // Add NFT
        _addTokenTo(_to, _tokenId);
        // Set the block of ownership transfer (for Flash NFT protection)
        ownership_change[_tokenId] = clock();
        // Log the transfer
        emit Transfer(_from, _to, _tokenId);
    }

    function _withdraw(uint256 _tokenId) internal {
        _checkApprovedOrOwner(msg.sender, _tokenId);

        LockedBalance memory _locked = locked[_tokenId];
        require(block.timestamp >= _locked.end, "The lock didn't expire");
        uint256 value = uint256(int256(_locked.amount));
        address owner = idToOwner[_tokenId];

        locked[_tokenId] = LockedBalance(0, 0);
        uint256 supply_before = _supply;
        _supply = supply_before - value;

        // old_locked can have either expired <= timestamp or zero end
        // _locked has only 0 end
        // Both can have >= 0 amount
        _checkpoint(_tokenId, _locked, LockedBalance(0, 0));

        assert(IERC20(token).transfer(owner, value));

        // checkpoint the owner's balance to remove _from ID
        uint256[] memory _votingUnit = new uint256[](1);
        _votingUnit[0] = _tokenId;
        _moveDelegateVotes(owner, address(0), _votingUnit);

        // Burn the NFT
        _burn(_tokenId);

        emit Withdraw(owner, _tokenId, value, block.timestamp);
        emit Supply(supply_before, supply_before - value);
    }

    /// @dev Clear an approval of a given address
    ///      Throws if `_owner` is not the current owner.
    function _clearApproval(address _owner, uint256 _tokenId) internal {
        // Throws if `_owner` is not the current owner
        assert(idToOwner[_tokenId] == _owner);
        if (idToApprovals[_tokenId] != address(0)) {
            // Reset approvals
            idToApprovals[_tokenId] = address(0);
        }
    }

    /// @dev Add a NFT to an index mapping to a given address
    /// @param _to address of the receiver
    /// @param _tokenId uint ID Of the token to be added
    function _addTokenToOwnerList(address _to, uint256 _tokenId) internal {
        uint256 current_count = _balance(_to);

        ownerToNFTokenIdList[_to][current_count] = _tokenId;
        tokenToOwnerIndex[_tokenId] = current_count;
    }

    /// @dev Remove a NFT from an index mapping to a given address
    /// @param _from address of the sender
    /// @param _tokenId uint ID Of the token to be removed
    function _removeTokenFromOwnerList(address _from, uint256 _tokenId) internal {
        // Delete
        uint256 current_count = _balance(_from) - 1;
        uint256 current_index = tokenToOwnerIndex[_tokenId];

        if (current_count == current_index) {
            // update ownerToNFTokenIdList
            ownerToNFTokenIdList[_from][current_count] = 0;
            // update tokenToOwnerIndex
            tokenToOwnerIndex[_tokenId] = 0;
        } else {
            uint256 lastTokenId = ownerToNFTokenIdList[_from][current_count];

            // Add
            // update ownerToNFTokenIdList
            ownerToNFTokenIdList[_from][current_index] = lastTokenId;
            // update tokenToOwnerIndex
            tokenToOwnerIndex[lastTokenId] = current_index;

            // Delete
            // update ownerToNFTokenIdList
            ownerToNFTokenIdList[_from][current_count] = 0;
            // update tokenToOwnerIndex
            tokenToOwnerIndex[_tokenId] = 0;
        }
    }

    /// @dev Add a NFT to a given address
    ///      Throws if `_tokenId` is owned by someone.
    function _addTokenTo(address _to, uint256 _tokenId) internal {
        // Throws if `_tokenId` is owned by someone
        assert(idToOwner[_tokenId] == address(0));
        // Change the owner
        idToOwner[_tokenId] = _to;
        // Update owner token index tracking
        _addTokenToOwnerList(_to, _tokenId);
        // Change count tracking
        ownerToNFTokenCount[_to] += 1;
    }

    /// @dev Remove a NFT from a given address
    ///      Throws if `_from` is not the current owner.
    function _removeTokenFrom(address _from, uint256 _tokenId) internal {
        // Throws if `_from` is not the current owner
        assert(idToOwner[_tokenId] == _from);
        // Change the owner
        idToOwner[_tokenId] = address(0);
        // Update owner token index tracking
        _removeTokenFromOwnerList(_from, _tokenId);
        // Change count tracking
        ownerToNFTokenCount[_from] -= 1;
    }

    /// @dev Function to mint tokens
    ///      Throws if `_to` is zero address.
    ///      Throws if `_tokenId` is owned by someone.
    /// @param _to The address that will receive the minted tokens.
    /// @param _tokenId The token id to mint.
    /// @return A boolean that indicates if the operation was successful.
    function _mint(address _to, uint256 _tokenId) internal returns (bool) {
        // Throws if `_to` is zero address
        assert(_to != address(0));
        // Add NFT. Throws if `_tokenId` is owned by someone
        _addTokenTo(_to, _tokenId);
        _totalSupply++;
        emit Transfer(address(0), _to, _tokenId);
        return true;
    }

    function _burn(uint256 _tokenId) internal {
        _checkApprovedOrOwner(msg.sender, _tokenId);

        address owner = idToOwner[_tokenId];

        // Clear approval
        _approve(address(0), _tokenId);
        // Remove token
        _removeTokenFrom(owner, _tokenId);
        _totalSupply--;
        emit Transfer(owner, address(0), _tokenId);
    }

    /// @dev Transfers the ownership of an NFT from one address to another address.
    ///      Throws unless `msg.sender` is the current owner, an authorized operator, or the
    ///      approved address for this NFT.
    ///      Throws if `_from` is not the current owner.
    ///      Throws if `_to` is the zero address.
    ///      Throws if `_tokenId` is not a valid NFT.
    ///      If `_to` is a smart contract, it calls `onERC721Received` on `_to` and throws if
    ///      the return value is not `bytes4(keccak256("onERC721Received(address,address,uint,bytes)"))`.
    /// @param _from The current owner of the NFT.
    /// @param _to The new owner.
    /// @param _tokenId The NFT to transfer.
    /// @param _data Additional data with no specified format, sent in call to `_to`.
    function _safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes memory _data) internal {
        _transferFrom(_from, _to, _tokenId, msg.sender);

        if (_isContract(_to)) {
            // Throws if transfer destination is a contract which does not implement 'onERC721Received'
            try IERC721Receiver(_to).onERC721Received(msg.sender, _from, _tokenId, _data) returns (bytes4) {}
            catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        }
    }

    /// @notice Record global and per-user data to checkpoint
    /// @param _tokenId NFT token ID. No user checkpoint if 0
    /// @param old_locked Pevious locked amount / end lock time for the user
    /// @param new_locked New locked amount / end lock time for the user
    function _checkpoint(uint256 _tokenId, LockedBalance memory old_locked, LockedBalance memory new_locked) internal {
        Point memory u_old;
        Point memory u_new;
        int128 old_dslope = 0;
        int128 new_dslope = 0;
        uint256 _epoch = epoch;

        if (_tokenId != 0) {
            // Calculate slopes and biases
            // Kept at zero when they have to
            if (old_locked.end > block.timestamp && old_locked.amount > 0) {
                u_old.slope = old_locked.amount / iMAXTIME;
                u_old.bias = u_old.slope * int128(int256(old_locked.end - block.timestamp));
            }
            if (new_locked.end > block.timestamp && new_locked.amount > 0) {
                u_new.slope = new_locked.amount / iMAXTIME;
                u_new.bias = u_new.slope * int128(int256(new_locked.end - block.timestamp));
            }

            // Read values of scheduled changes in the slope
            // old_locked.end can be in the past and in the future
            // new_locked.end can ONLY by in the FUTURE unless everything expired: than zeros
            old_dslope = slope_changes[old_locked.end];
            if (new_locked.end != 0) {
                if (new_locked.end == old_locked.end) {
                    new_dslope = old_dslope;
                } else {
                    new_dslope = slope_changes[new_locked.end];
                }
            }
        }

        Point memory last_point = Point({bias: 0, slope: 0, ts: block.timestamp, blk: block.number});
        if (_epoch > 0) {
            last_point = point_history[_epoch];
        }
        uint256 last_checkpoint = last_point.ts;
        // initial_last_point is used for extrapolation to calculate block number
        // (approximately, for *At methods) and save them
        // as we cannot figure that out exactly from inside the contract
        Point memory initial_last_point = last_point;
        uint256 block_slope = 0; // dblock/dt
        if (block.timestamp > last_point.ts) {
            block_slope = (MULTIPLIER * (block.number - last_point.blk)) / (block.timestamp - last_point.ts);
        }
        // If last point is already recorded in this block, slope=0
        // But that's ok b/c we know the block in such case

        // Go over weeks to fill history and calculate what the current point is
        {
            uint256 t_i = (last_checkpoint / WEEK) * WEEK;
            for (uint256 i = 0; i < 255; ++i) {
                // Hopefully it won't happen that this won't get used in 5 years!
                // If it does, users will be able to withdraw but vote weight will be broken
                t_i += WEEK;
                int128 d_slope = 0;
                if (t_i > block.timestamp) {
                    t_i = block.timestamp;
                } else {
                    d_slope = slope_changes[t_i];
                }
                last_point.bias -= last_point.slope * int128(int256(t_i - last_checkpoint));
                last_point.slope += d_slope;
                if (last_point.bias < 0) {
                    // This can happen
                    last_point.bias = 0;
                }
                if (last_point.slope < 0) {
                    // This cannot happen - just in case
                    last_point.slope = 0;
                }
                last_checkpoint = t_i;
                last_point.ts = t_i;
                last_point.blk = initial_last_point.blk + (block_slope * (t_i - initial_last_point.ts)) / MULTIPLIER;
                _epoch += 1;
                if (t_i == block.timestamp) {
                    last_point.blk = block.number;
                    break;
                } else {
                    point_history[_epoch] = last_point;
                }
            }
        }

        epoch = _epoch;
        // Now point_history is filled until t=now

        if (_tokenId != 0) {
            // If last point was in this block, the slope change has been applied already
            // But in such case we have 0 slope(s)
            last_point.slope += (u_new.slope - u_old.slope);
            last_point.bias += (u_new.bias - u_old.bias);
            if (last_point.slope < 0) {
                last_point.slope = 0;
            }
            if (last_point.bias < 0) {
                last_point.bias = 0;
            }
        }

        // Record the changed point into history
        point_history[_epoch] = last_point;

        if (_tokenId != 0) {
            // Schedule the slope changes (slope is going down)
            // We subtract new_user_slope from [new_locked.end]
            // and add old_user_slope to [old_locked.end]
            if (old_locked.end > block.timestamp) {
                // old_dslope was <something> - u_old.slope, so we cancel that
                old_dslope += u_old.slope;
                if (new_locked.end == old_locked.end) {
                    old_dslope -= u_new.slope; // It was a new deposit, not extension
                }
                slope_changes[old_locked.end] = old_dslope;
            }

            if (new_locked.end > block.timestamp) {
                if (new_locked.end > old_locked.end) {
                    new_dslope -= u_new.slope; // old slope disappeared at this point
                    slope_changes[new_locked.end] = new_dslope;
                }
                // else: we recorded it already in old_dslope
            }
            // Now handle user history
            uint256 user_epoch = user_point_epoch[_tokenId] + 1;

            user_point_epoch[_tokenId] = user_epoch;
            u_new.ts = block.timestamp;
            u_new.blk = block.number;
            user_point_history[_tokenId][user_epoch] = u_new;
        }
    }

    // The following ERC20/minime-compatible methods are not real balanceOf and supply!
    // They measure the weights for the purpose of voting, so they don't represent
    // real coins.

    /// @notice Internal view
    ///
    /// @dev Returns the number of NFTs owned by `_owner`.
    ///      Throws if `_owner` is the zero address. NFTs assigned to the zero address are considered invalid.
    /// @param _owner Address for whom to query the balance.
    function _balance(address _owner) internal view returns (uint256) {
        return ownerToNFTokenCount[_owner];
    }

    /// @notice Get the current voting power for `_tokenId`
    /// @dev Adheres to the ERC20 `balanceOf` interface for Aragon compatibility
    /// @param _tokenId NFT for lock
    /// @param _t Epoch time to return voting power at
    /// @return User voting power
    function _balanceOfNFT(uint256 _tokenId, uint256 _t) internal view returns (uint256) {
        uint256 _epoch = user_point_epoch[_tokenId];
        if (_epoch == 0) {
            return 0;
        } else {
            Point memory last_point = user_point_history[_tokenId][_epoch];
            last_point.bias -= last_point.slope * int128(SafeCast.toInt256(_t) - int256(last_point.ts));
            if (last_point.bias < 0) {
                last_point.bias = 0;
            }
            return uint256(int256(last_point.bias));
        }
    }

    /// @notice Measure voting power of `_tokenId` at block height `_block`
    /// @dev Adheres to MiniMe `balanceOfAt` interface: https://github.com/Giveth/minime
    /// @param _tokenId User's wallet NFT
    /// @param _block Block to calculate the voting power at
    /// @return Voting power
    function _balanceOfAtNFT(uint256 _tokenId, uint256 _block) internal view returns (uint256) {
        // Copying and pasting totalSupply code because Vyper cannot pass by
        // reference yet
        assert(_block <= block.number);

        // Binary search
        uint256 _min = 0;
        uint256 _max = user_point_epoch[_tokenId];
        for (uint256 i = 0; i < 128; ++i) {
            // Will be always enough for 128-bit numbers
            if (_min >= _max) {
                break;
            }
            uint256 _mid = (_min + _max + 1) / 2;
            if (user_point_history[_tokenId][_mid].blk <= _block) {
                _min = _mid;
            } else {
                _max = _mid - 1;
            }
        }

        Point memory upoint = user_point_history[_tokenId][_min];

        uint256 max_epoch = epoch;
        uint256 _epoch = _find_block_epoch(_block, max_epoch);
        Point memory point_0 = point_history[_epoch];
        uint256 d_block = 0;
        uint256 d_t = 0;
        if (_epoch < max_epoch) {
            Point memory point_1 = point_history[_epoch + 1];
            d_block = point_1.blk - point_0.blk;
            d_t = point_1.ts - point_0.ts;
        } else {
            d_block = block.number - point_0.blk;
            d_t = block.timestamp - point_0.ts;
        }
        uint256 block_time = point_0.ts;
        if (d_block != 0) {
            block_time += (d_t * (_block - point_0.blk)) / d_block;
        }

        upoint.bias -= upoint.slope * int128(int256(block_time - upoint.ts));
        if (upoint.bias >= 0) {
            return uint256(uint128(upoint.bias));
        } else {
            return 0;
        }
    }

    /// @notice Calculate total voting power at some point in the past
    /// @param point The point (bias/slope) to start search from
    /// @param t Time to calculate the total voting power at
    /// @return Total voting power at that time
    function _supply_at(Point memory point, uint256 t) internal view returns (uint256) {
        Point memory last_point = point;
        uint256 t_i = (last_point.ts / WEEK) * WEEK;
        for (uint256 i = 0; i < 255; ++i) {
            t_i += WEEK;
            int128 d_slope = 0;
            if (t_i > t) {
                t_i = t;
            } else {
                d_slope = slope_changes[t_i];
            }
            last_point.bias -= last_point.slope * int128(int256(t_i - last_point.ts));
            if (t_i == t) {
                break;
            }
            last_point.slope += d_slope;
            last_point.ts = t_i;
        }

        if (last_point.bias < 0) {
            last_point.bias = 0;
        }
        return uint256(uint128(last_point.bias));
    }

    /// @notice Return the total voting power at timestamp `t`.
    function _totalPowerAtT(uint256 t) internal view returns (uint256) {
        uint256 _epoch = epoch;
        Point memory last_point = point_history[_epoch];
        return _supply_at(last_point, t);
    }

    /// @dev Returns whether the given spender can transfer a given token ID
    /// @param _spender address of the spender to query
    /// @param _tokenId uint ID of the token to be transferred
    /// @return bool whether the msg.sender is approved for the given token ID, is an operator of the owner, or is the
    /// owner of the token
    function _isApprovedOrOwner(address _spender, uint256 _tokenId) internal view returns (bool) {
        address owner = idToOwner[_tokenId];
        bool spenderIsOwner = owner == _spender;
        bool spenderIsApproved = _spender == idToApprovals[_tokenId];
        bool spenderIsApprovedForAll = (ownerToOperators[owner])[_spender];
        return spenderIsOwner || spenderIsApproved || spenderIsApprovedForAll;
    }

    function _checkApprovedOrOwner(address _spender, uint256 _tokenId) internal view {
        if (!_isApprovedOrOwner(_spender, _tokenId)) {
            revert NotApproved(_spender, _tokenId);
        }
    }

    /// @notice Conditions for upgrading the implementation.
    function _authorizeUpgrade(address newImplementation) internal view override onlyGov {
        require(newImplementation != address(0), "New implementation cannot be zero address");
    }

    /// @notice Binary search to estimate timestamp for block number
    /// @param _block Block to find
    /// @param max_epoch Don't go beyond this epoch
    /// @return Approximate timestamp for block
    function _find_block_epoch(uint256 _block, uint256 max_epoch) internal view returns (uint256) {
        // Binary search
        uint256 _min = 0;
        uint256 _max = max_epoch;
        for (uint256 i = 0; i < 128; ++i) {
            // Will be always enough for 128-bit numbers
            if (_min >= _max) {
                break;
            }
            uint256 _mid = (_min + _max + 1) / 2;
            if (point_history[_mid].blk <= _block) {
                _min = _mid;
            } else {
                _max = _mid - 1;
            }
        }
        return _min;
    }

    /// @notice The number of NFT balance checkpoints there are for address `account`.
    function _numCheckpoints(address account) internal view returns (uint32) {
        return uint32(_delegateCheckpoints[account].length());
    }

    /// @notice Calculate the voting power of a given list of token IDs at timestamp `_t`.
    ///         Does not count non-voting token IDs.
    function _calculateCumulativeVotingPower(uint256[] memory _tokenIds, uint256 _t) internal view returns (uint256) {
        uint256 cumulativeVotingPower;
        for (uint8 i = 0; i < _tokenIds.length; i++) {
            // increment cumulativeVePower by the voting power of each token ID at time _t
            if (nonVoting[_tokenIds[i]]) {
                continue;
            }
            cumulativeVotingPower += _balanceOfNFT(_tokenIds[i], _t);
        }
        return cumulativeVotingPower;
    }

    function _isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    /// @notice Return the list of token IDs currently owned by address `account`.
    /// @dev This does not count token IDs delegated to `account`, only tokens they own.
    function _getVotingUnits(address account) internal view returns (uint256[] memory tokenList) {
        uint256 tokenCount = _balance(account);
        tokenList = new uint256[](tokenCount);
        for (uint256 i = 0; i < tokenCount; i++) {
            tokenList[i] = ownerToNFTokenIdList[account][i];
        }
    }

    function msg_sender() internal view returns (address) {
        return msg.sender;
    }

    function block_number() internal view returns (uint256) {
        return block.number;
    }

    /// @notice Internal pure
    function toString(uint256 value) internal pure returns (string memory) {
        unchecked {
            uint256 length = Math.log10(value) + 1;
            string memory buffer = new string(length);
            uint256 ptr;
            assembly {
                ptr := add(buffer, add(32, length))
            }
            while (true) {
                ptr--;
                assembly {
                    mstore8(ptr, byte(mod(value, 10), HEX_DIGITS))
                }
                value /= 10;
                if (value == 0) break;
            }
            return buffer;
        }
    }

    /// @notice Concatenate an array of token IDs to a given array of token IDs.
    ///         Removes duplicates.
    function _add(uint256[] memory current, uint256[] memory addIDs) internal pure returns (uint256[] memory) {
        uint256 _currentLength = current.length;
        uint256[] memory updated = new uint256[](_currentLength + addIDs.length);
        for (uint256 i = 0; i < _currentLength; i++) {
            updated[i] = current[i];
        }

        for (uint256 i = 0; i < addIDs.length; i++) {
            updated[_currentLength + i] = addIDs[i];
        }

        return updated;
    }

    /// @notice Remove an array of token IDs from a given array of token IDs.
    function _remove(uint256[] memory current, uint256[] memory removeIDs) internal pure returns (uint256[] memory) {
        uint256 _excess = current.length - removeIDs.length;
        bool[] memory _ignore = new bool[](current.length);
        uint256[] memory _updated = new uint256[](_excess);
        uint256 _updatedLength;

        // mark whether the token ID exists on the removal array
        for (uint256 i = 0; i < removeIDs.length; i++) {
            for (uint256 j = 0; j < current.length; j++) {
                if (removeIDs[i] == current[j]) {
                    _ignore[j] = true;
                }
            }
        }

        // populate a new array, ignoring the token IDs to be removed
        for (uint256 i = 0; i < _ignore.length; i++) {
            if (!_ignore[i]) {
                _updated[_updatedLength++] = current[i];
            }
        }

        return _updated;
    }

    /// @notice Private mutable
    ///
    /// @notice Create a new checkpoint which either adds to or removes from the latest checkpoint, a given array of token IDs.
    /// @param store The checkpoint array to be operated on.
    /// @param op The operation to perform - can be `_add` or `_subtract`.
    /// @param deltaTokenIDs The array of token IDs that are to be added or removed from `store`.
    function _push(
        ArrayCheckpoints.TraceArray storage store,
        function(uint256[] memory, uint256[] memory) view returns (uint256[] memory) op,
        uint256[] memory deltaTokenIDs
    ) private returns (uint256, uint256) {
        (, uint256 _key,) = store.latestCheckpoint();
        if (_key == block.timestamp) {
            revert SameTimestamp();
        }
        (uint256 oldLength, uint256 newLength) = store.push(uint256(clock()), op(store.latest(), deltaTokenIDs));
        return (oldLength, newLength);
    }

    function onERC721Received(address, address, uint256, bytes memory) public pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
