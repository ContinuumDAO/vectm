// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC5805} from "@openzeppelin/contracts/interfaces/IERC5805.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {INodeProperties} from "../node/INodeProperties.sol";
import {IRewards} from "../node/IRewards.sol";
import {ArrayCheckpoints} from "../utils/ArrayCheckpoints.sol";
import {VotingEscrowErrorParam} from "../utils/VotingEscrowUtils.sol";
import {IVotingEscrow} from "./IVotingEscrow.sol";

/**
 * @title Voting Escrow
 * @author Curve Finance, Solidly, w/ OpenZeppelin contracts
 * @author Modified for ContinuumDAO by @patrickcure
 * @notice Time-weighted voting escrow system for veCTM tokens
 * @dev This contract implements a time-weighted voting escrow system where users lock CTM tokens
 * to receive veCTM NFTs with voting power that decays linearly over time. The system supports
 * both voting and non-voting locks, delegation mechanisms, and integration with governance systems.
 *
 * Key features:
 * - Time-weighted voting power that decays linearly over lock duration
 * - Maximum lock duration of 4 years (MAXTIME)
 * - Support for both voting and non-voting locks
 * - Delegation system with checkpointed voting power
 * - Integration with node properties and rewards systems
 * - UUPS upgradeable proxy pattern
 * - ERC721 NFT representation of locked positions
 * - ERC5805 delegation compliance
 *
 * Voting power calculation:
 * - Linear decay from lock amount to zero over lock duration
 * - Power = locked_amount * (end_time - current_time) / MAXTIME
 * - Weekly rounding for lock durations
 *
 * @dev The weight in this implementation is linear:
 *  w ^
 * 1 +        /
 *   |      /
 *   |    /
 *   |  /
 *   |/
 * 0 +--------+------> time
 *       maxtime (4 years)
 */
contract VotingEscrow is IVotingEscrow, IERC721, IERC5805, IERC721Receiver, UUPSUpgradeable {
    using ArrayCheckpoints for ArrayCheckpoints.TraceArray;
    using Strings for uint256;

    /// @notice Address of the underlying CTM token
    address public token;
    /// @notice Address of the governance contract with administrative privileges
    address public governor;
    /// @notice Address of the node properties contract for node integration
    address public nodeProperties;
    /// @notice Address of the rewards contract for reward integration
    address public rewards;
    /// @notice Address of the treasury contract for penalty collection
    address public treasury;
    /// @notice Current epoch number for global checkpoint tracking
    uint256 public epoch;
    /// @notice Base URI for NFT metadata
    string public baseURI;
    /// @notice Minimum amount of CTM lockable (default 1 ether)
    uint256 public minimumLock;
    /// @notice Reentrancy guard state (1 = not entered, 2 = entered)
    uint8 internal _entered_state;
    /// @notice Total locked token supply
    uint256 internal _supply;
    /// @notice Current token ID counter for NFT minting
    uint256 internal tokenId;
    /// @notice Total number of NFTs minted
    uint256 internal _totalSupply;

    /// @notice Mapping from token ID to locked balance information
    mapping(uint256 => LockedBalance) public locked;
    /// @notice Mapping from token ID to ownership change timestamp (prevents flash NFT attacks)
    mapping(uint256 => uint256) public ownership_change;
    /// @notice Mapping from epoch to global checkpoint point
    mapping(uint256 => Point) public point_history;
    /// @notice Mapping from token ID to user checkpoint history array
    mapping(uint256 => Point[1_000_000_000]) private user_point_history;
    /// @notice Mapping from token ID to current user epoch
    mapping(uint256 => uint256) public user_point_epoch;
    /// @notice Mapping from timestamp to slope change for global supply calculations
    mapping(uint256 => int128) public slope_changes;
    /// @notice Mapping from NFT ID to owner address
    mapping(uint256 => address) internal idToOwner;
    /// @notice Mapping from NFT ID to approved address for transfers
    mapping(uint256 => address) internal idToApprovals;
    /// @notice Mapping from owner address to token count
    mapping(address => uint256) internal ownerToNFTokenCount;
    /// @notice Mapping from owner address to index-to-tokenId mapping
    mapping(address => mapping(uint256 => uint256)) internal ownerToNFTokenIdList;
    /// @notice Mapping from owner address to array of tokenIds
    mapping(address => uint256[]) internal ownerToAllNFTokenIds; // ISSUE: #14
    /// @notice Mapping from NFT ID to owner's token index
    mapping(uint256 => uint256) internal tokenToOwnerIndex;
    /// @notice Mapping from owner address to operator approval status
    mapping(address => mapping(address => bool)) internal ownerToOperators;
    /// @notice Mapping from interface ID to support status for ERC165
    mapping(bytes4 => bool) internal supportedInterfaces;
    /// @notice Mapping from token ID to non-voting status (true = non-voting, false = voting)
    mapping(uint256 => bool) public nonVoting;

    /// @notice Mapping from account address to delegatee address
    mapping(address => address) internal _delegatee;
    /// @notice Mapping from delegatee address to checkpointed token ID arrays
    mapping(address => ArrayCheckpoints.TraceArray) internal _delegateCheckpoints;
    /// @notice Mapping from account address to nonce for signature verification
    mapping(address => uint256) internal _nonces;

    /// @notice Token name for ERC721 metadata
    string public constant name = "Voting Escrow Continuum";
    /// @notice Token symbol for ERC721 metadata
    string public constant symbol = "veCTM";
    /// @notice Contract version
    string public constant version = "1.0.0";
    /// @notice Token decimals (18 for compatibility with ERC20)
    uint8 public constant decimals = 18;
    /// @notice Hexadecimal digits for string conversion
    bytes16 internal constant HEX_DIGITS = "0123456789abcdef";
    /// @notice Duration of one week in seconds
    uint256 internal constant WEEK = 7 * 86_400;
    /// @notice Maximum lock duration in seconds (4 years)
    uint256 internal constant MAXTIME = 4 * 365 * 86_400;
    /// @notice Multiplier for precision in calculations (1e18)
    uint256 internal constant MULTIPLIER = 1e18;
    /// @notice Maximum lock duration as int128 for calculations
    int128 internal constant iMAXTIME = 4 * 365 * 86_400;

    /// @notice Liquidation penalty numerator (50,000 / 100,000 = 50%)
    uint256 public constant LIQ_PENALTY_NUM = 50_000;
    /// @notice Liquidation penalty denominator
    uint256 public constant LIQ_PENALTY_DEN = 100_000;
    /// @notice Flag to enable/disable liquidations
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

    modifier nonreentrant() {
        if (_entered_state != NOT_ENTERED) {
            revert VotingEscrow_Reentrant();
        }
        _entered_state = ENTERED;
        _;
        _entered_state = NOT_ENTERED;
    }

    modifier nonflash(uint256 _tokenId) {
        if (ownership_change[_tokenId] == clock()) {
            revert VotingEscrow_FlashProtection();
        }
        _;
        ownership_change[_tokenId] = clock();
    }

    modifier onlyGov() {
        if (msg.sender != governor) {
            revert VotingEscrow_OnlyAuthorized(VotingEscrowErrorParam.Sender, VotingEscrowErrorParam.Gov);
        }
        _;
    }

    modifier checkNotAttached(uint256 _tokenId) {
        if (INodeProperties(nodeProperties).attachedNodeId(_tokenId) != bytes32("")) {
            revert VotingEscrow_NodeAttached(_tokenId);
        }
        _;
    }

    modifier checkNoRewards(uint256 _tokenId) {
        if (IRewards(rewards).unclaimedRewards(_tokenId) != 0) {
            revert VotingEscrow_UnclaimedRewards(_tokenId);
        }
        _;
    }

    /// @dev Proxy pattern contract - disable initializers for implementation on deployment
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the VotingEscrow contract
     * @param token_addr The address of the underlying CTM token
     * @param base_uri Base URI for NFT metadata
     * @dev Sets up the initial state including token address, base URI, and supported interfaces.
     * This function can only be called once during contract deployment.
     */
    function initialize(address token_addr, string memory base_uri) external initializer {
        __UUPSUpgradeable_init();
        token = token_addr;
        baseURI = base_uri;
        point_history[0].blk = block.number;
        point_history[0].ts = block.timestamp;
        minimumLock = 1 ether;

        supportedInterfaces[ERC165_INTERFACE_ID] = true;
        supportedInterfaces[ERC721_INTERFACE_ID] = true;
        supportedInterfaces[ERC721_METADATA_INTERFACE_ID] = true;
        supportedInterfaces[VOTES_INTERFACE_ID] = true;
        supportedInterfaces[ERC6372_INTERFACE_ID] = true;

        _entered_state = 1;

        emit Transfer(address(0), address(this), tokenId);
        emit Transfer(address(this), address(0), tokenId);
    }

    /**
     * @notice Creates a voting lock for the caller
     * @param _value Amount of CTM tokens to lock
     * @param _lock_duration Number of seconds to lock tokens for (rounded down to nearest week)
     * @return tokenId The token ID of the created veCTM NFT
     * @dev Creates a new veCTM NFT with voting power that decays linearly over the lock duration.
     * Lock duration is rounded down to the nearest week. Maximum lock duration is 4 years.
     */
    function create_lock(uint256 _value, uint256 _lock_duration) external nonreentrant returns (uint256) {
        return _create_lock(_value, _lock_duration, msg.sender, DepositType.CREATE_LOCK_TYPE);
    }

    /**
     * @notice Creates a voting lock for a specified address
     * @param _value Amount of CTM tokens to lock
     * @param _lock_duration Number of seconds to lock tokens for (rounded down to nearest week)
     * @param _to Address to receive the veCTM NFT
     * @return The token ID of the created veCTM NFT
     * @dev Creates a new veCTM NFT for the specified address with voting power that decays linearly.
     * Lock duration is rounded down to the nearest week. Maximum lock duration is 4 years.
     */
    function create_lock_for(uint256 _value, uint256 _lock_duration, address _to)
        external
        nonreentrant
        returns (uint256)
    {
        return _create_lock(_value, _lock_duration, _to, DepositType.CREATE_LOCK_TYPE);
    }

    /**
     * @notice Increases the locked amount for an existing lock
     * @param _tokenId The token ID to increase the lock amount for
     * @param _value Amount of additional CTM tokens to lock
     * @dev Adds more tokens to an existing lock without changing the unlock time.
     * Requires the caller to be the owner or approved operator of the token.
     */
    function increase_amount(uint256 _tokenId, uint256 _value) external nonreentrant checkNoRewards(_tokenId) {
        _checkApprovedOrOwner(msg.sender, _tokenId);

        LockedBalance memory _locked = locked[_tokenId];

        if (_value == 0) {
            revert VotingEscrow_IsZero(VotingEscrowErrorParam.Value);
        }
        if (_locked.amount == 0) {
            revert VotingEscrow_NoExistingLock();
        }
        if (_locked.end <= block.timestamp) {
            revert VotingEscrow_LockExpired(_locked.end);
        }

        _deposit_for(_tokenId, _value, 0, _locked, DepositType.INCREASE_LOCK_AMOUNT);
    }

    /**
     * @notice Extends the unlock time for an existing lock
     * @param _tokenId The token ID to extend the lock time for
     * @param _lock_duration New number of seconds to add to the lock duration
     * @dev Extends the unlock time for an existing lock. Lock duration is rounded down to the nearest week.
     * Requires the caller to be the owner or approved operator of the token.
     */
    function increase_unlock_time(uint256 _tokenId, uint256 _lock_duration)
        external
        nonreentrant
        checkNoRewards(_tokenId)
    {
        _checkApprovedOrOwner(msg.sender, _tokenId);

        LockedBalance memory _locked = locked[_tokenId];
        uint256 unlock_time = ((block.timestamp + _lock_duration) / WEEK) * WEEK; // Locktime is rounded down to weeks

        if (_locked.end <= block.timestamp) {
            revert VotingEscrow_LockExpired(_locked.end);
        }
        if (_locked.amount == 0) {
            revert VotingEscrow_NoExistingLock();
        }
        if (unlock_time <= _locked.end) {
            revert VotingEscrow_InvalidUnlockTime(unlock_time, _locked.end);
        }
        if (unlock_time > block.timestamp + MAXTIME) {
            revert VotingEscrow_InvalidUnlockTime(unlock_time, block.timestamp + MAXTIME);
        }

        _deposit_for(_tokenId, 0, unlock_time, _locked, DepositType.INCREASE_UNLOCK_TIME);
    }

    /**
     * @notice Withdraws all tokens from an expired lock
     * @param _tokenId The token ID to withdraw from
     * @dev Only possible if the lock has expired. Burns the NFT and returns the underlying CTM tokens.
     * Requires the caller to be the owner or approved operator of the token.
     */
    function withdraw(uint256 _tokenId) external nonreentrant checkNotAttached(_tokenId) checkNoRewards(_tokenId) {
        _withdraw(_tokenId);
    }

    /**
     * @notice Merges two token IDs and combines their underlying values
     * @param _from The token ID that gets burned
     * @param _to The token ID that the burned token gets merged into
     * @dev Merges two locks into one. The end timestamp is value-weighted based on the composite tokens.
     * Both tokens must be owned by the same address and have the same voting status.
     */
    function merge(uint256 _from, uint256 _to)
        external
        nonflash(_from)
        nonflash(_to)
        checkNotAttached(_from)
        checkNotAttached(_to)
        checkNoRewards(_from)
        checkNoRewards(_to)
    {
        if (nonVoting[_from] != nonVoting[_to]) {
            revert VotingEscrow_VotingAndNonVotingMerge(_from, _to);
        }

        if (_from == _to) {
            revert VotingEscrow_SameToken(_from, _to);
        }
        _checkApprovedOrOwner(msg.sender, _from);
        _checkApprovedOrOwner(msg.sender, _to);

        address ownerFrom = idToOwner[_from];
        address ownerTo = idToOwner[_to];
        if (ownerFrom != ownerTo) {
            revert VotingEscrow_DifferentOwners(_from, _to);
        }

        uint256 supply_before = _supply;
        LockedBalance memory _locked0 = locked[_from];
        LockedBalance memory _locked1 = locked[_to];
        uint256 value0 = uint256(int256(_locked0.amount));
        uint256 value1 = uint256(int256(_locked1.amount));

        // value-weighted end timestamp
        uint256 weightedEnd = (value0 * _locked0.end + value1 * _locked1.end) / (value0 + value1);
        // round down to week and then add one week to prevent rounding down exploit
        uint256 unlock_time = ((weightedEnd / WEEK) * WEEK) + WEEK;
        // uint256 unlock_time = _locked1.end; // default to current _to end
        // ISSUE: #15
        // if (ceilWeighted > unlock_time) {
        //     unlock_time = ceilWeighted;
        // }

        // checkpoint the _from lock to zero (_from gets burned)
        locked[_from] = LockedBalance(0, 0);
        _checkpoint(_from, _locked0, LockedBalance(0, 0));
        // checkpoint the owner's balance to remove _from ID
        uint256[] memory _votingUnit = new uint256[](1);
        _votingUnit[0] = _from;
        _moveDelegateVotes(_getDelegatee(ownerFrom), address(0), _votingUnit);

        // Burn the NFT
        _burn(_from);

        // add _from lock value to _to lock, using the value-weighted and rounded unlock time
        _deposit_for(_to, value0, unlock_time, _locked1, DepositType.MERGE_TYPE);
        // we need to decrease the supply by value0 because _deposit_for adds it again, when in reality
        // _supply doesn't change in this operation
        _supply -= value0;
        assert(_supply == supply_before);

        emit Merge(_from, _to);
    }

    /**
     * @notice Splits a token into two NFTs with extracted value
     * @param _tokenId The token ID to be split
     * @param _extraction The underlying value to be used to make a new NFT
     * @return The token ID of the newly created NFT
     * @dev Splits an existing lock into two separate locks. The original lock is reduced by the extraction amount,
     * and a new lock is created with the extracted value. Both locks maintain the parent end time.
     */
    function split(uint256 _tokenId, uint256 _extraction)
        external
        nonflash(_tokenId)
        checkNotAttached(_tokenId)
        checkNoRewards(_tokenId)
        returns (uint256)
    {
        _checkApprovedOrOwner(msg.sender, _tokenId);

        address owner = idToOwner[_tokenId];
        LockedBalance memory _locked = locked[_tokenId];
        if (block.timestamp >= _locked.end) {
            revert VotingEscrow_LockExpired(_locked.end);
        }
        int128 value = _locked.amount;
        int128 extraction = SafeCast.toInt128(SafeCast.toInt256(_extraction));
        int128 remainder = value - extraction;
        assert(remainder > 0);
        assert(extraction + remainder <= value);

        uint256 supply_before = _supply;

        locked[_tokenId] = LockedBalance(remainder, _locked.end);
        _checkpoint(_tokenId, _locked, LockedBalance(remainder, _locked.end));

        uint256 extractionId;

        uint256 lock_duration = (_locked.end - block.timestamp);
        if (((block.timestamp + lock_duration) / WEEK) * WEEK < _locked.end) {
            lock_duration = (_locked.end - block.timestamp) + WEEK;
        }

        if (nonVoting[_tokenId]) {
            // create another non-voting lock
            // adding a week to lock duration to prevent rounding down exploit
            extractionId = _create_nonvoting_lock_for(_extraction, lock_duration, owner, DepositType.SPLIT_TYPE);
        } else {
            // create another voting lock
            // adding a week to lock duration to prevent rounding down exploit
            extractionId = _create_lock(_extraction, lock_duration, owner, DepositType.SPLIT_TYPE);
        }

        ownership_change[extractionId] = clock();

        // we need to decrease the supply by _extraction because _deposit_for adds it again, when in reality
        // _supply doesn't change in this operation
        _supply -= _extraction;
        assert(_supply == supply_before);

        emit Split(_tokenId, extractionId, _extraction);

        return extractionId;
    }

    /**
     * @notice Liquidates a veCTM token before maturity with penalty
     * @param _tokenId The token ID to liquidate
     * @dev Allows users to withdraw their locked tokens before the lock expires, but with a penalty.
     * The penalty is 50% of the remaining voting power in underlying tokens, transferred to the DAO treasury.
     *
     * Penalty examples:
     * - Unlock at 4 years before end => 50% penalty
     * - Unlock at 3 years before end => 37.5% penalty
     * - Unlock at 2 years before end => 25% penalty
     * - Unlock at 1 year before end => 12.5% penalty
     * - Unlock on/after end => no penalty
     *
     * Minimum value to withdraw is 100 gwei to prevent liquidation of low voting power.
     */
    function liquidate(uint256 _tokenId) external nonreentrant checkNotAttached(_tokenId) checkNoRewards(_tokenId) {
        if (!liquidationsEnabled) {
            revert VotingEscrow_LiquidationsDisabled();
        }
        _checkApprovedOrOwner(msg.sender, _tokenId);
        address owner = idToOwner[_tokenId];
        LockedBalance memory _locked = locked[_tokenId];
        if (block.timestamp >= _locked.end) {
            _withdraw(_tokenId);
            return;
        }
        uint256 value = uint256(int256(_locked.amount));
        if (value <= 100 gwei) {
            revert VotingEscrow_InvalidValue();
        }
        uint256 vePower = _balanceOfNFT(_tokenId, block.timestamp);
        uint256 penalty = vePower * LIQ_PENALTY_NUM / LIQ_PENALTY_DEN;
        assert(penalty != 0);

        locked[_tokenId] = LockedBalance(0, 0);
        uint256 supply_before = _supply;
        _supply = supply_before - value;

        _checkpoint(_tokenId, _locked, LockedBalance(0, 0));

        if (!IERC20(token).transfer(owner, value - penalty)) {
            revert VotingEscrow_TransferFailed();
        }
        if (!IERC20(token).transfer(treasury, penalty)) {
            revert VotingEscrow_TransferFailed();
        }

        // checkpoint the owner's balance to remove _from ID
        uint256[] memory _votingUnit = new uint256[](1);
        _votingUnit[0] = _tokenId;
        _moveDelegateVotes(_getDelegatee(owner), address(0), _votingUnit);

        // Burn the NFT
        _burn(_tokenId);

        emit Liquidate(_tokenId, value, penalty);
    }

    /**
     * @notice Deposits additional tokens for an existing lock
     * @param _tokenId The token ID to add tokens to
     * @param _value Amount of additional CTM tokens to lock
     * @dev Anyone can deposit additional tokens for an existing lock, but cannot extend the lock time
     * or create a new lock for a user. This allows for external contracts to add to user locks.
     */
    function deposit_for(uint256 _tokenId, uint256 _value) external nonreentrant {
        LockedBalance memory _locked = locked[_tokenId];

        if (_value == 0) {
            revert VotingEscrow_IsZero(VotingEscrowErrorParam.Value);
        }
        if (_locked.amount == 0) {
            revert VotingEscrow_NoExistingLock();
        }
        if (_locked.end <= block.timestamp) {
            revert VotingEscrow_LockExpired(_locked.end);
        }
        _deposit_for(_tokenId, _value, 0, _locked, DepositType.DEPOSIT_FOR_TYPE);
    }

    /**
     * @notice Throws unless `msg.sender` is the current owner, an authorized operator, or the
     * approved address for this NFT.
     * @param _from The current owner of the NFT.
     * @param _to The new owner.
     * @param _tokenId The NFT to transfer.
     * @dev Throws if `_from` is not the current owner, `_to` is the zero address, or `_tokenId` is not a valid NFT.
     * @dev The caller is responsible to confirm that `_to` is capable of receiving
     * NFTs or else they maybe be permanently lost.
     */
    function transferFrom(address _from, address _to, uint256 _tokenId) external {
        _transferFrom(_from, _to, _tokenId, msg.sender);
    }

    /**
     * @notice Approve `_approved` to spend `_tokenId`.
     * @param _approved The address to approve for spending.
     * @param _tokenId The token ID to approve.
     */
    function approve(address _approved, uint256 _tokenId) external {
        _approve(_approved, _tokenId);
    }

    /**
     * @notice Enables or disables approval for a third party ("operator") to manage all of
     * `msg.sender`'s assets. It also emits the ApprovalForAll event.
     * Throws if `_operator` is the `msg.sender`. (This is not written the EIP)
     * @param _operator Address to add to the set of authorized operators.
     * @param _approved True if the operators is approved, false to revoke approval.
     * @dev This works even if sender doesn't own any tokens at the time.
     */
    function setApprovalForAll(address _operator, bool _approved) external {
        // Throws if `_operator` is the `msg.sender`
        assert(_operator != msg.sender);
        ownerToOperators[msg.sender][_operator] = _approved;
        emit ApprovalForAll(msg.sender, _operator, _approved);
    }

    /**
     * @notice Delegates all voting power to an address
     * @param delegatee The address to delegate voting power to
     * @dev Delegates all voting power from the caller's token IDs to the specified address.
     * @dev The delegatee can then use this voting power for governance decisions.
     */
    function delegate(address delegatee) external {
        address account = msg.sender;
        _delegate(account, delegatee);
    }

    /**
     * @dev Transfers the ownership of an NFT from one address to another address.
     * @param _from The current owner of the NFT.
     * @param _to The new owner.
     * @param _tokenId The NFT to transfer.
     * @dev Throws unless `msg.sender` is the current owner, an authorized operator, or the
     * approved address for this NFT. Throws if `_from` is not the current owner, `_to` is the zero address,
     * `_tokenId` is not a valid NFT.
     * @dev If `_to` is a smart contract, it calls `onERC721Received` on `_to` and throws if
     * the return value is not `bytes4(keccak256("onERC721Received(address,address,uint,bytes)"))`.
     */
    function safeTransferFrom(address _from, address _to, uint256 _tokenId) external {
        safeTransferFrom(_from, _to, _tokenId, "");
    }

    /**
     * @notice Records global data to checkpoint
     * @dev Updates the global checkpoint with current block and timestamp data.
     * This function can be called by anyone to ensure the global state is up to date.
     */
    function checkpoint() external {
        _checkpoint(0, LockedBalance(0, 0), LockedBalance(0, 0));
    }

    /**
     * @notice Initializes contract addresses after deployment
     * @param _governor The address of the governance contract
     * @param _nodeProperties The address of the node properties contract
     * @param _rewards The address of the rewards contract
     * @param _treasury The address of the treasury contract
     * @dev Sets up the contract addresses for integration with other system contracts.
     * @dev This function can only be called once and is needed because VotingEscrow is deployed before other contracts.
     */
    function initContracts(address _governor, address _nodeProperties, address _rewards, address _treasury) external {
        if (governor != address(0)) {
            revert InvalidInitialization();
        }
        governor = _governor;
        nodeProperties = _nodeProperties;
        rewards = _rewards;
        treasury = _treasury;
    }

    /**
     * @notice Sets the base URI for NFT metadata.
     * @param _baseURI The base URI string.
     */
    function setBaseURI(string memory _baseURI) external onlyGov {
        baseURI = _baseURI;
    }

    /**
     * @notice Sets a minimum CTM lock amount.
     * @param _min The minimum amount of CTM lockable.
     * @dev This is to prevent the creation of locks that are used solely for DoS attacks.
     */
    function setMinimumLock(uint256 _min) external onlyGov {
        if (_min == 0) {
            revert VotingEscrow_IsZero(VotingEscrowErrorParam.MinLock);
        }
        minimumLock = _min;
    }

    /**
     * @notice Switch to enable liquidations.
     * @param _liquidationsEnabled Whether to enable or suspend liquidations.
     * @dev Only governance can decide to enable/suspend liquidations.
     */
    function setLiquidationsEnabled(bool _liquidationsEnabled) external onlyGov {
        if (_liquidationsEnabled && treasury == address(0)) {
            revert VotingEscrow_IsZeroAddress(VotingEscrowErrorParam.Treasury);
        }
        liquidationsEnabled = _liquidationsEnabled;
    }

    /**
     * @notice Returns the number of NFTs owned by `_owner`.
     * @param _owner Address for whom to query the balance.
     * @dev Throws if `_owner` is the zero address. NFTs assigned to the zero address are considered invalid.
     * @return The number of NFTs owned.
     */
    function balanceOf(address _owner) external view returns (uint256) {
        return _balance(_owner);
    }

    /**
     * @notice Get the current voting power of `_tokenId`.
     * @param _tokenId The tokenId for which to check voting power.
     * @return The current voting power of the given token ID.
     */
    function balanceOfNFT(uint256 _tokenId) external view returns (uint256) {
        if (ownership_change[_tokenId] == clock()) {
            return 0;
        }
        return _balanceOfNFT(_tokenId, block.timestamp);
    }

    /**
     * @notice Get the voting power of `_tokenId` at a given timestamp.
     * @param _tokenId The token ID for which to check voting power
     * @param _t The timestamp the voting power will be calculated at.
     * @return The voting power of the given token ID at the given timestamp.
     */
    function balanceOfNFTAt(uint256 _tokenId, uint256 _t) external view returns (uint256) {
        return _balanceOfNFT(_tokenId, _t);
    }

    /**
     * @dev Returns the address of the owner of the NFT.
     * @param _tokenId The identifier for an NFT.
     * @return The address that owns the given token ID.
     */
    function ownerOf(uint256 _tokenId) external view returns (address) {
        return idToOwner[_tokenId];
    }

    /**
     * @notice Returns the total number of NFTs minted
     * @return The total number of veCTM NFTs that have been minted
     */
    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    /**
     * @notice Returns the current total voting power
     * @return The total voting power at the current timestamp
     */
    function totalPower() external view returns (uint256) {
        return _totalPowerAtT(block.timestamp);
    }

    /**
     * @notice Calculates total voting power at a specific timestamp
     * @param t The timestamp to calculate voting power at
     * @return The total voting power at the specified timestamp
     * @dev Adheres to the ERC20 `totalSupply` interface for Aragon compatibility
     */
    function totalPowerAtT(uint256 t) external view returns (uint256) {
        return _totalPowerAtT(t);
    }

    /**
     * @dev Get the approved address for a single NFT.
     * @param _tokenId ID of the NFT to query the approval of.
     * @return The address that is approved for the given token ID.
     */
    function getApproved(uint256 _tokenId) external view returns (address) {
        return idToApprovals[_tokenId];
    }

    /**
     * @notice Checks if `_operator` is an approved operator for `_owner`.
     * @param _owner The address that owns the NFTs.
     * @param _operator The address that acts on behalf of the owner.
     * @return True if the given address is an operator for owner, false otherwise.
     */
    function isApprovedForAll(address _owner, address _operator) external view returns (bool) {
        return (ownerToOperators[_owner])[_operator];
    }

    /**
     * @notice Checks if `_spender` is an approved to spend `_tokenId`.
     * @param _spender The address whose status for the token ID will be checked.
     * @param _tokenId The token ID for which to check the status of the spender.
     * @return True if the spender is approved for the token ID, false otherwise.
     */
    function isApprovedOrOwner(address _spender, uint256 _tokenId) external view returns (bool) {
        return _isApprovedOrOwner(_spender, _tokenId);
    }

    /**
     * @notice Get token ID by index of the owner's token list.
     * @param _owner The owner's address to be checked.
     * @param _tokenIndex The index of the owner's token list.
     * @return The token ID corresponding to the given owner and token index.
     */
    function tokenOfOwnerByIndex(address _owner, uint256 _tokenIndex) external view returns (uint256) {
        return ownerToNFTokenIdList[_owner][_tokenIndex];
    }

    /**
     * @notice Get token as a global index.
     * @param _index The index as it is recorded across all balances and users.
     * @return The token ID corresponding to the given global index.
     */
    function tokenByIndex(uint256 _index) external view returns (uint256) {
        if (_index < _totalSupply) {
            return _index + 1;
        } else {
            return 0;
        }
    }

    /**
     * @notice Gets the current voting power of an address
     * @param account The address to get votes for
     * @return The current voting power of the address
     * @dev Governor compliant method for counting current voting power. Only counts voting tokens, not non-voting tokens.
     */
    function getVotes(address account) external view returns (uint256) {
        uint256[] memory delegateTokenIdsCurrent = _delegateCheckpoints[account].latest();
        return _calculateCumulativeVotingPower(delegateTokenIdsCurrent, clock());
    }

    /**
     * @notice Gets the voting power of an address at a historic timestamp
     * @param account The address to get votes for
     * @param timepoint The timestamp to get votes for
     * @return The voting power of the address at the specified timestamp
     * @dev Governor compliant method for counting voting power at a historic timestamp.
     * The votes are calculated at the upper checkpoint of a binary search on that user's delegation history.
     * @dev Example of delegated checkpoints of an address:
     * [ {timestamp 0, [1, 2, 3]}, {timestamp 1, [1, 2, 3, 5]}, {timestamp 2, [1, 2, 5]} ]
     */
    function getPastVotes(address account, uint256 timepoint) external view returns (uint256) {
        uint48 timepoint48 = SafeCast.toUint48(timepoint);
        uint48 currentTimepoint = clock();
        if (timepoint48 >= currentTimepoint) {
            revert VotingEscrow_FutureLookup(timepoint, currentTimepoint);
        }
        uint256[] memory delegateTokenIdsAt = _delegateCheckpoints[account].upperLookupRecent(timepoint48);
        return _calculateCumulativeVotingPower(delegateTokenIdsAt, timepoint48);
    }

    /**
     * @notice The total voting power at a historic timestamp.
     * @param timepoint The timestamp to check total supply at
     * @dev The name `getPastTotalSupply` is maintained to keep in-line with IVotes interface, but it actually returns
     * total vote power. For current total supply of NFTs, call `totalSupply`.
     */
    function getPastTotalSupply(uint256 timepoint) external view returns (uint256) {
        uint48 timepoint48 = SafeCast.toUint48(timepoint);
        uint48 currentTimepoint = clock();
        if (timepoint48 >= currentTimepoint) {
            revert VotingEscrow_FutureLookup(timepoint, currentTimepoint);
        }
        return _totalPowerAtT(timepoint);
    }

    /**
     * @notice Check the current delegated address for `account` (if set).
     * @param account The address to check delegatee for.
     * @return The address of the delegatee if they have set it, otherwise their own address (`account`).
     */
    function _getDelegatee(address account) internal view returns (address) {
        return _delegatee[account] == address(0) ? account : _delegatee[account];
    }

    /**
     * @notice Check the current delegated address for `account`.
     * @param account The address to check delegatee for.
     * @return The address of the delegatee if they have set it, otherwise their own address (`account`).
     */
    function delegates(address account) external view returns (address) {
        return _getDelegatee(account);
    }

    /**
     * @notice Get the list of token IDs that are currently delegated to `account`.
     * @param account The account to which delegated token IDs are checked.
     * @return The list of token IDs that are delegated to the given address.
     */
    function tokenIdsDelegatedTo(address account) external view returns (uint256[] memory) {
        return _delegateCheckpoints[account].latest();
    }

    /**
     * @notice Get the list of token IDs that were delegated to `account` at historic timestamp.
     * @param account The account to which delegated token IDs are checked at the given time.
     * @param timepoint The timestamp to check delegated token IDs to the given address.
     * @return The list of the token IDs that were delegated to the given account at the provided timepoint.
     */
    function tokenIdsDelegatedToAt(address account, uint256 timepoint) external view returns (uint256[] memory) {
        return _delegateCheckpoints[account].upperLookupRecent(timepoint);
    }

    /**
     * @notice Get the most recently recorded rate of voting power decrease for `_tokenId`.
     * @param _tokenId The token ID to check.
     * @return The value of the slope.
     */
    function get_last_user_slope(uint256 _tokenId) external view returns (int128) {
        uint256 uepoch = user_point_epoch[_tokenId];
        return user_point_history[_tokenId][uepoch].slope;
    }

    /**
     * @notice Get the timestamp for checkpoint `_idx` for `_tokenId`
     * @param _tokenId The token ID to check.
     * @param _idx User epoch number.
     * @return Epoch time of the checkpoint.
     */
    function user_point_history__ts(uint256 _tokenId, uint256 _idx) external view returns (uint256) {
        return user_point_history[_tokenId][_idx].ts;
    }

    /**
     * @notice Get timestamp when `_tokenId`'s lock finishes
     * @param _tokenId The token ID to check.
     * @return Epoch time of the lock end.
     */
    function locked__end(uint256 _tokenId) external view returns (uint256) {
        return locked[_tokenId].end;
    }

    /**
     * @notice Returns current token URI metadata.
     * @param _tokenId Token ID to fetch URI for.
     * @return The whole URI (baseURI + token ID)
     */
    function tokenURI(uint256 _tokenId) external view returns (string memory) {
        if (idToOwner[_tokenId] == address(0)) {
            revert VotingEscrow_IsZeroAddress(VotingEscrowErrorParam.Owner);
        }
        string memory _baseURI = baseURI;
        return bytes(_baseURI).length > 0 ? string(abi.encodePacked(_baseURI, _tokenId.toString())) : "";
    }

    /**
     * @notice ERC165 compliant method for checking supported interfaces.
     * @param _interfaceID The interface ID to check validity
     * @return True if the interface ID is supported, false otherwise.
     */
    function supportsInterface(bytes4 _interfaceID) external view returns (bool) {
        return supportedInterfaces[_interfaceID];
    }

    /**
     * @notice Get the checkpoint (including timestamp and list of delegated token IDs) at position `_index` in the
     * delegated checkpoint array of address `account`.
     * @param _account The account for which to check checkpoints
     * @param _index The index of the user's delegation state as recorded in checkpoints
     * @return The token IDs delegated to `_account` at the `_index` state in their history
     */
    function checkpoints(address _account, uint256 _index)
        external
        view
        returns (ArrayCheckpoints.CheckpointArray memory)
    {
        uint32 _index32 = SafeCast.toUint32(_index);
        return _delegateCheckpoints[_account].at(_index32);
    }

    /**
     * @notice Create a lock that has voting power, but that the delegatee cannot use to cast votes.
     * @param _value The underlying CTM in the lock.
     * @param _lock_duration The total lock duration of the token (may be rounded down 1 week).
     * @param _to The receiver address of this token ID.
     * @return The token ID of the non-voting lock.
     */
    function create_nonvoting_lock_for(uint256 _value, uint256 _lock_duration, address _to)
        public
        nonreentrant
        returns (uint256)
    {
        return _create_nonvoting_lock_for(_value, _lock_duration, _to, DepositType.CREATE_LOCK_TYPE);
    }

    /**
     * @notice Create a lock that has voting power, but that the delegatee cannot use to cast votes.
     * @param _value The underlying CTM in the lock.
     * @param _lock_duration The total lock duration of the token (may be rounded down 1 week).
     * @param _to The receiver address of this token ID.
     * @param deposit_type The deposit type in question. This affects whether CTM will be charged from the sender or
     * whether that has been accounted for (in the case of a SPLIT or MERGE).
     * @return The token ID of the non-voting lock.
     */
    function _create_nonvoting_lock_for(uint256 _value, uint256 _lock_duration, address _to, DepositType deposit_type)
        internal
        returns (uint256)
    {
        uint256 _tokenId = _create_lock(_value, _lock_duration, _to, deposit_type);
        nonVoting[_tokenId] = true;
        return _tokenId;
    }

    /**
     * @notice Delegate voting power to another address by off-chain signature.
     * @param delegatee The address to delegate to.
     * @param nonce The account nonce of the signer.
     * @param expiry The timestamp at which the transaction will no longer be allowed to be executed.
     * @param v Signature v
     * @param r Signature r
     * @param s Signature s
     */
    function delegateBySig(address delegatee, uint256 nonce, uint256 expiry, uint8 v, bytes32 r, bytes32 s) public {
        if (block.timestamp > expiry) {
            revert VotesExpiredSignature(expiry);
        }

        bytes32 domainSeparator = keccak256(abi.encode(TYPE_HASH, name, version, block.chainid, address(this)));
        bytes32 structHash = keccak256(abi.encode(DELEGATION_TYPEHASH, delegatee, nonce, expiry));
        bytes32 digest;

        assembly {
            let ptr := mload(0x40)
            mstore(ptr, hex"1901")
            mstore(add(ptr, 0x02), domainSeparator)
            mstore(add(ptr, 0x22), structHash)
            digest := keccak256(ptr, 0x42)
        }

        address signer = ECDSA.recover(digest, v, r, s);

        unchecked {
            uint256 current = _nonces[signer]++;
            if (nonce != current) {
                revert VotingEscrow_InvalidAccountNonce(signer, current);
            }
        }

        _delegate(signer, delegatee);
    }

    /**
     * @notice ERC6372 implementation
     * @return Block timestamp
     */
    function clock() public view returns (uint48) {
        return uint48(block.timestamp);
    }

    /**
     * @notice ERC6372 implementation
     * @return "mode=timestamp"
     */
    function CLOCK_MODE() public pure returns (string memory) {
        return "mode=timestamp";
    }

    /**
     * @notice Set or reaffirm the approved address for an NFT. The zero address indicates there is no approved address.
     * @param _approved Address to be approved for the given NFT ID.
     * @param _tokenId ID of the token to be approved.
     * @dev Throws unless `msg.sender` is the current NFT owner, or an authorized operator of the current owner.
     * @dev Throws if `_tokenId` is not a valid NFT. (This is not written the EIP)
     * @dev Throws if `_approved` is the current owner. (This is not written the EIP)
     */
    function _approve(address _approved, uint256 _tokenId) internal {
        address owner = idToOwner[_tokenId];
        // Throws if `_tokenId` is not a valid NFT
        if (owner == address(0)) {
            revert VotingEscrow_IsZeroAddress(VotingEscrowErrorParam.Owner);
        }
        // Throws if `_approved` is the current owner
        if (_approved == owner) {
            revert VotingEscrow_Unauthorized(VotingEscrowErrorParam.Approved, VotingEscrowErrorParam.Owner);
        }
        // Check requirements
        bool senderIsOwner = (idToOwner[_tokenId] == msg.sender);
        bool senderIsApprovedForAll = (ownerToOperators[owner])[msg.sender];
        if (!senderIsOwner && !senderIsApprovedForAll) {
            revert VotingEscrow_OnlyAuthorized(VotingEscrowErrorParam.Sender, VotingEscrowErrorParam.ApprovedOrOwner);
        }
        // Set the approval
        idToApprovals[_tokenId] = _approved;
        emit Approval(owner, _approved, _tokenId);
    }

    /**
     * @notice Deposit `_value` tokens for `_to` and lock for `_lock_duration`
     * @param _value Amount to deposit
     * @param _lock_duration Number of seconds to lock tokens for (rounded down to nearest week)
     * @param _to Address to deposit
     * @dev Weekly reset falls every Thursday at 00:00:00 GMT
     * @dev If the receiver does not have a delegatee, then automatically delegate receiver.
     * Otherwise, checkpoint the receiver's delegatee's balance with the new token ID.
     */
    function _create_lock(uint256 _value, uint256 _lock_duration, address _to, DepositType deposit_type)
        internal
        returns (uint256)
    {
        // Locktime is floored to nearest whole week since UNIX epoch
        uint256 unlock_time = ((block.timestamp + _lock_duration) / WEEK) * WEEK;

        // ISSUE: #14: setting minimum lock amount to prevent DoS attacks
        if (_value < minimumLock) {
            revert VotingEscrow_LockBelowMin(_value);
        }
        if (unlock_time <= block.timestamp) {
            revert VotingEscrow_InvalidUnlockTime(unlock_time, block.timestamp);
        }

        ++tokenId;
        uint256 _tokenId = tokenId;
        _mint(_to, _tokenId);

        _deposit_for(_tokenId, _value, unlock_time, locked[_tokenId], deposit_type);

        // move delegated votes to the receiver upon deposit
        // doesn't matter if it's for a non-voting token as that gets checked when `getVotes` is called
        uint256[] memory _votingUnit = new uint256[](1);
        _votingUnit[0] = _tokenId;
        _moveDelegateVotes(address(0), _getDelegatee(_to), _votingUnit);

        return _tokenId;
    }

    /**
     * @notice Deposit and lock tokens for a user
     * @param _tokenId NFT that holds lock
     * @param _value Amount to deposit
     * @param unlock_time New time when to unlock the tokens, or 0 if unchanged
     * @param locked_balance Previous locked amount & timestamp
     * @param deposit_type The type of deposit (DEPOSIT, CREATE, INCREASE_LOCK, INCREASE_TIME, MERGE, SPLIT)
     */
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

        if (unlock_time > block.timestamp + MAXTIME) {
            revert VotingEscrow_InvalidUnlockTime(unlock_time, block.timestamp + MAXTIME);
        }

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

        if (_value != 0 && deposit_type != DepositType.MERGE_TYPE && deposit_type != DepositType.SPLIT_TYPE) {
            assert(IERC20(token).transferFrom(from, address(this), _value));
        }

        emit Deposit(from, _tokenId, _value, _locked.end, deposit_type, block.timestamp);
        emit Supply(supply_before, supply_before + _value);
    }

    /**
     * @notice Change the delegatee of `account` to `delegatee` including all currently delegated token IDs.
     * @param account The address of the owner of the token IDs that are delegated
     * @param delegatee The address of the target delegatee that the token IDs will be delegated to
     */
    function _delegate(address account, address delegatee) internal {
        if (delegatee == address(0)) delegatee = account;
        address oldDelegate = _getDelegatee(account);
        _delegatee[account] = delegatee;

        emit DelegateChanged(account, oldDelegate, delegatee);
        _moveDelegateVotes(oldDelegate, delegatee, _getVotingUnits(account));
    }

    /**
     * @notice Remove a specific amount of token IDs from the delegated balance of `from` and move them to `to`.
     * Checkpoint both delegatees.
     * @param from The address that owns the token IDs in question
     * @param to The address to move the voting power of the token IDs to
     * @param deltaTokenIDs The array of token IDs to add/remove (depending on the operation)
     */
    function _moveDelegateVotes(address from, address to, uint256[] memory deltaTokenIDs) private {
        if (from != to) {
            if (from != address(0)) {
                (uint256 oldBalance, uint256 newBalance) = _push(_delegateCheckpoints[from], _remove, deltaTokenIDs);
                emit DelegateVotesChanged(from, oldBalance, newBalance);
            }
            if (to != address(0)) {
                (uint256 oldBalance, uint256 newBalance) = _push(_delegateCheckpoints[to], _add, deltaTokenIDs);
                emit DelegateVotesChanged(to, oldBalance, newBalance);
            }
        }
    }

    /**
     * @notice Exeute transfer of an NFT.
     * @dev Throws unless `msg.sender` is the current owner, an authorized operator, or the approved
     * address for this NFT. (`msg.sender` not allowed in internal function so pass `_sender`.)
     * @dev Throws if `_to` is the zero address.
     * @dev Throws if `_from` is not the current owner.
     * @dev Throws if `_tokenId` is not a valid NFT.
     */
    function _transferFrom(address _from, address _to, uint256 _tokenId, address _sender)
        internal
        checkNotAttached(_tokenId)
        nonflash(_tokenId)
    {
        // Check requirements
        _checkApprovedOrOwner(_sender, _tokenId);

        // move delegated votes
        uint256[] memory _votingUnit = new uint256[](1);
        _votingUnit[0] = _tokenId;
        _moveDelegateVotes(_getDelegatee(_from), _getDelegatee(_to), _votingUnit);

        // Clear approval. Throws if `_from` is not the current owner
        _clearApproval(_from, _tokenId);
        // Remove NFT. Throws if `_tokenId` is not a valid NFT
        _removeTokenFrom(_from, _tokenId);
        // Add NFT
        _addTokenTo(_to, _tokenId);
        // Log the transfer
        emit Transfer(_from, _to, _tokenId);
    }

    /**
     * @notice Withdraws all tokens from an expired lock
     * @param _tokenId The token ID to withdraw from
     * @dev Only possible if the lock has expired. Burns the NFT and returns the underlying CTM tokens.
     * Requires the caller to be the owner or approved operator of the token.
     */
    function _withdraw(uint256 _tokenId) internal {
        _checkApprovedOrOwner(msg.sender, _tokenId);

        LockedBalance memory _locked = locked[_tokenId];
        if (block.timestamp < _locked.end) {
            revert VotingEscrow_LockNotExpired(_locked.end);
        }
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
        _moveDelegateVotes(_getDelegatee(owner), address(0), _votingUnit);

        // Burn the NFT
        _burn(_tokenId);

        emit Withdraw(owner, _tokenId, value, block.timestamp);
        emit Supply(supply_before, supply_before - value);
    }

    /**
     * @notice Clear an approval of a given address
     * @param _owner The owner of the token(s).
     * @param _tokenId The token ID for which to remove approval for any address other than owner.
     * @dev Throws if `_owner` is not the current owner.
     */
    function _clearApproval(address _owner, uint256 _tokenId) internal {
        // Throws if `_owner` is not the current owner
        assert(idToOwner[_tokenId] == _owner);
        if (idToApprovals[_tokenId] != address(0)) {
            // Reset approvals
            idToApprovals[_tokenId] = address(0);
        }
    }

    /**
     * @notice Add an NFT to an index mapping to a given address
     * @param _to address of the receiver
     * @param _tokenId uint ID Of the token to be added
     */
    function _addTokenToOwnerList(address _to, uint256 _tokenId) internal {
        uint256 current_count = _balance(_to);

        ownerToNFTokenIdList[_to][current_count] = _tokenId;
        ownerToAllNFTokenIds[_to].push(_tokenId); // ISSUE: #14
        tokenToOwnerIndex[_tokenId] = current_count;
    }

    /**
     * @notice Remove an NFT from an index mapping to a given address
     * @param _from address of the sender
     * @param _tokenId uint ID Of the token to be removed
     */
    function _removeTokenFromOwnerList(address _from, uint256 _tokenId) internal {
        // Delete
        uint256 current_count = _balance(_from) - 1;
        uint256 current_index = tokenToOwnerIndex[_tokenId];

        if (current_count == current_index) {
            // update ownerToNFTokenIdList
            ownerToNFTokenIdList[_from][current_count] = 0;
            ownerToAllNFTokenIds[_from].pop(); // ISSUE: #14
            // update tokenToOwnerIndex
            tokenToOwnerIndex[_tokenId] = 0;
        } else {
            uint256 lastTokenId = ownerToNFTokenIdList[_from][current_count];

            // Add
            // update ownerToNFTokenIdList
            ownerToNFTokenIdList[_from][current_index] = lastTokenId;
            ownerToAllNFTokenIds[_from][current_index] = lastTokenId; // ISSUE: #14
            // update tokenToOwnerIndex
            tokenToOwnerIndex[lastTokenId] = current_index;

            // Delete
            // update ownerToNFTokenIdList
            ownerToNFTokenIdList[_from][current_count] = 0;
            ownerToAllNFTokenIds[_from].pop(); // ISSUE: #14
            // update tokenToOwnerIndex
            tokenToOwnerIndex[_tokenId] = 0;
        }
    }

    /**
     * @notice Add an NFT to a given address.
     * @param _to The address whose balance `_tokenId` will be added to.
     * @param _tokenId The token ID to move to the balance of `_to`.
     * @dev Throws if `_tokenId` is owned by someone.
     */
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

    /**
     * @notice Remove an NFT from a given address.
     * @param _from The address whose balance `_tokenId` will be removed from.
     * @param _tokenId The token ID to move from the balance of `_from`.
     * @dev Throws if `_from` is not the current owner.
     */
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

    /**
     * @notice Mint tokens.
     * @param _to The address that will receive the minted tokens.
     * @param _tokenId The token ID to mint.
     * @return A boolean that indicates whether the operation was successful.
     * @dev Throws if `_to` is zero address or if `_tokenId` is owned by someone.
     */
    function _mint(address _to, uint256 _tokenId) internal returns (bool) {
        // Throws if `_to` is zero address
        assert(_to != address(0));
        // Add NFT. Throws if `_tokenId` is owned by someone
        _addTokenTo(_to, _tokenId);
        _totalSupply++;
        emit Transfer(address(0), _to, _tokenId);
        return true;
    }

    /**
     * @notice Burn tokens.
     * @param _tokenId The token ID to burn.
     * @dev Throws if the sender is not approved for or owner of `_tokenId`.
     */
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

    /**
     * @notice Transfers the ownership of an NFT from one address to another address.
     * @dev Throws unless `msg.sender` is the current owner, an authorized operator, or the
     * approved address for this NFT.
     * @param _from The current owner of the NFT.
     * @param _to The new owner.
     * @param _tokenId The NFT to transfer.
     * @param _data Additional data with no specified format, sent in call to `_to`.
     * @dev Throws if `_from` is not the current owner.
     * @dev Throws if `_to` is the zero address.
     * @dev Throws if `_tokenId` is not a valid NFT.
     * @dev If `_to` is a smart contract, it calls `onERC721Received` on `_to` and throws if
     * the return value is not `bytes4(keccak256("onERC721Received(address,address,uint,bytes)"))`.
     */
    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes memory _data) public {
        _transferFrom(_from, _to, _tokenId, msg.sender);

        if (_isContract(_to)) {
            // Throws if transfer destination is a contract which does not implement 'onERC721Received'
            try IERC721Receiver(_to).onERC721Received(msg.sender, _from, _tokenId, _data) returns (bytes4) {}
            catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert VotingEscrow_NonERC721Receiver();
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        }
    }

    /**
     * @notice Record global and per-user data to checkpoint
     * @param _tokenId NFT token ID. No user checkpoint if 0
     * @param old_locked Pevious locked amount/end lock time for the user
     * @param new_locked New locked amount/end lock time for the user
     */
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

    /// @notice The following ERC20/minime-compatible methods are not real balanceOf and supply!
    /// They measure the weights for the purpose of voting, so they don't represent
    /// real coins.

    /**
     * @notice Returns the number of NFTs owned by `_owner`.
     * @param _owner Address for whom to query the balance.
     * @dev Throws if `_owner` is the zero address. NFTs assigned to the zero address are considered invalid.
     */
    function _balance(address _owner) internal view returns (uint256) {
        return ownerToNFTokenCount[_owner];
    }

    /**
     * @notice Get the current voting power for `_tokenId`
     * @param _tokenId NFT for lock
     * @param _t Epoch time to return voting power at
     * @return User voting power
     * @dev Adheres to the ERC20 `balanceOf` interface for Aragon compatibility
     */
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

    /**
     * @notice Calculate total voting power at some point in the past
     * @param point The point (bias/slope) to start search from
     * @param t Time to calculate the total voting power at
     * @return Total voting power at that time
     */
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

    /**
     * @notice Return the total voting power at timestamp `t`.
     * @param t The time at which to obtain total voting power.
     * @return The total voting power at time `t`.
     */
    function _totalPowerAtT(uint256 t) internal view returns (uint256) {
        uint256 _epoch = epoch;
        Point memory last_point = point_history[_epoch];
        return _supply_at(last_point, t);
    }

    /**
     * @notice Returns whether the given spender can transfer a given token ID
     * @param _spender address of the spender to query
     * @param _tokenId uint ID of the token to be transferred
     * @return True if the msg.sender is approved for the given token ID, is an operator of the owner, or is the
     * owner of the token
     */
    function _isApprovedOrOwner(address _spender, uint256 _tokenId) internal view returns (bool) {
        address owner = idToOwner[_tokenId];
        bool spenderIsOwner = owner == _spender;
        bool spenderIsApproved = _spender == idToApprovals[_tokenId];
        bool spenderIsApprovedForAll = (ownerToOperators[owner])[_spender];
        return spenderIsOwner || spenderIsApproved || spenderIsApprovedForAll;
    }

    /**
     * @notice Reverts if `_spender` is not approved for or owner of `_tokenId`.
     * @param _spender The address to check approved or owner status of
     * @param _tokenId The token ID for which check spending rights
     */
    function _checkApprovedOrOwner(address _spender, uint256 _tokenId) internal view {
        if (!_isApprovedOrOwner(_spender, _tokenId)) {
            revert VotingEscrow_OnlyAuthorized(VotingEscrowErrorParam.Sender, VotingEscrowErrorParam.ApprovedOrOwner);
        }
    }

    /**
     * @notice Conditions for upgrading the implementation. This adheres to the UUPS and ERC1967 standard.
     * @param newImplementation The address of the new VotingEscrow implementation (logic).
     * @dev Only governance vote can perform this operation.
     */
    function _authorizeUpgrade(address newImplementation) internal view override onlyGov {
        if (newImplementation == address(0)) {
            revert VotingEscrow_IsZeroAddress(VotingEscrowErrorParam.Implementation);
        }
    }

    /**
     * @notice Binary search to estimate timestamp for block number
     * @param _block Block to find
     * @param max_epoch Don't go beyond this epoch
     * @return Approximate timestamp for block
     */
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

    /**
     * @notice The number of NFT delegation checkpoints there are for address `account`.
     * @param account The account for which to check number of NFT delegation checkpoints.
     * @return The number of delegation checkpoints `account` has.
     */
    function _numCheckpoints(address account) internal view returns (uint32) {
        return uint32(_delegateCheckpoints[account].length());
    }

    /**
     * @notice Calculate the voting power of a given list of token IDs at timestamp `_t`.
     * @param _tokenIds The array of token IDs for which to check total voting power.
     * @param _t The timestamp at which to calculate total voting power of `_tokenIds`.
     * @return The sum of the voting power of the list token IDs.
     * @dev Does not count non-voting token IDs.
     */
    function _calculateCumulativeVotingPower(uint256[] memory _tokenIds, uint256 _t) internal view returns (uint256) {
        uint256 cumulativeVotingPower;
        // ISSUE: #14: change loop iterations from uint8 to uint256
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            // increment cumulativeVePower by the voting power of each token ID at time _t
            if (nonVoting[_tokenIds[i]]) {
                continue;
            }
            cumulativeVotingPower += _balanceOfNFT(_tokenIds[i], _t);
        }
        return cumulativeVotingPower;
    }

    /**
     * @notice Checks whether `account` is a contract or not.
     * @return True if the address is a contract, false if it is an EOA.
     * @dev This method relies on extcodesize, which returns 0 for contracts in construction, since the code
     * is only stored at the end of the constructor execution.
     */
    function _isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    /**
     * @notice Gets the list of token IDs currently owned by address `account`.
     * @return tokenList The list of token IDs owned by `account`.
     * @dev This does not count token IDs delegated to `account`, only tokens they own.
     */
    function _getVotingUnits(address account) internal view returns (uint256[] memory tokenList) {
        // uint256 tokenCount = _balance(account);
        // tokenList = new uint256[](tokenCount);
        // for (uint256 i = 0; i < tokenCount; i++) {
        //     tokenList[i] = ownerToNFTokenIdList[account][i];
        // }
        return ownerToAllNFTokenIds[account]; // ISSUE: #14
    }

    /**
     * @notice Concatenate two given separate arrays of token IDs.
     * @param current The list of token IDs as it exists initially.
     * @param addIDs The list of token IDs to add to the current list.
     * @return The single concatenation of the two given arrays.
     * @dev Removes duplicates.
     */
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

    /**
     * @notice Remove an array of token IDs from a given array of token IDs.
     * @param current The list of token IDs as it exists initially.
     * @param removeIDs The list of token IDs to remove from the current list.
     * @return The array resulting from the removal.
     */
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

    /**
     * @notice Create a new checkpoint which either adds to or removes from the latest checkpoint a given array of
     * token IDs.
     * @param store The checkpoint array to be operated on.
     * @param op The operation to perform - can be `_add` or `_subtract`.
     * @param deltaTokenIDs The array of token IDs that are to be added or removed from `store`.
     * @return The length of the checkpoint array before and after the change
     */
    function _push(
        ArrayCheckpoints.TraceArray storage store,
        function(uint256[] memory, uint256[] memory) view returns (uint256[] memory) op,
        uint256[] memory deltaTokenIDs
    ) private returns (uint256, uint256) {
        (, uint256 _key,) = store.latestCheckpoint();
        if (_key == block.timestamp) {
            revert VotingEscrow_FlashProtection();
        }
        (uint256 oldLength, uint256 newLength) = store.push(uint256(clock()), op(store.latest(), deltaTokenIDs));
        return (oldLength, newLength);
    }

    /**
     * @notice Hook that is called in some implementations of NFT transfer.
     * @return The selector of this function, onERC721Received.selector.
     * @dev Must return the selector of this function to be deemed a valid transfer.
     */
    function onERC721Received(address, address, uint256, bytes memory) public pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
