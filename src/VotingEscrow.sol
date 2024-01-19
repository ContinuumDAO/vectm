// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC6372} from "@openzeppelin/contracts/interfaces/IERC6372.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";


interface IVotingEscrow {
    function version() external view returns (string memory);
    function decimals() external view returns (uint8);
    function token() external view returns (address);
    function governor() external view returns (address);
    function epoch() external view returns (uint256);
    function baseURI() external view returns (string memory);
    // function locked(uint256 tokenId) external view returns (LockedBalance);
    function ownership_change(uint256 tokenId) external view returns (uint256);
    // function point_history(uint256 tokenId) external view returns (Point);
    // function user_point_history(uint256 tokenId) external view returns (Point[1000000000]);
    function user_point_epoch(uint256 tokenId) external view returns (uint256);
    function slope_changes(uint256 tokenId) external view returns (int128);

    function initialize(address token_addr, address _governor, string memory base_uri) external;
    function create_lock(uint256 _value, uint256 _lock_duration) external returns (uint256);
    function create_lock_for(uint256 _value, uint256 _lock_duration, address _to) external returns (uint256);
    function increase_amount(uint256 _tokenId, uint256 _value) external;
    function increase_unlock_time(uint256 _tokenId, uint256 _lock_duration) external;
    function withdraw(uint256 _tokenId) external;
    function merge(uint256 _from, uint256 _to) external;
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

    // ERC721 + Metadata + ERC165 + Votes
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


library ArrayCheckpoints {
    /**
     * @dev A value was attempted to be inserted on a past checkpoint.
     */
    error CheckpointUnorderedInsertion();

    /**
     * @dev Trace where checkpoints can be stored.
     */
    struct TraceArray {
        CheckpointArray[] _checkpoints;
    }

    /**
     * @dev Checkpoint that tracks a `_key` which is associated with an array of `_values`.
     */
    struct CheckpointArray {
        uint256 _key;
        uint256[] _values;
    }

    /**
     * @dev Pushes a (`key`, `values`) pair into a Trace so that it is stored as the checkpoint.
     *
     * Returns previous values array length and new values array length.
     *
     * IMPORTANT: Never accept `key` as a user input, since an arbitrary `type(uint256).max` key set will disable the
     * library.
     */
    function push(TraceArray storage self, uint256 key, uint256[] memory values) internal returns (uint256, uint256) {
        return _insert(self._checkpoints, key, values);
    }

    /**
     * @dev Returns the values array in the first (oldest) checkpoint with key greater or equal than the search key, or an
     * empty array if there is none.
     */
    function lowerLookup(TraceArray storage self, uint256 key) internal view returns (uint256[] memory) {
        uint256 len = self._checkpoints.length;
        uint256 pos = _lowerBinaryLookup(self._checkpoints, key, 0, len);
        return pos == len ? new uint256[](0) : _unsafeAccess(self._checkpoints, pos)._values;
    }

    /**
     * @dev Returns the value in the last (most recent) checkpoint with key lower or equal than the search key, or zero
     * if there is none.
     */
    function upperLookup(TraceArray storage self, uint256 key) internal view returns (uint256[] memory) {
        uint256 len = self._checkpoints.length;
        uint256 pos = _upperBinaryLookup(self._checkpoints, key, 0, len);
        return pos == 0 ? new uint256[](0) : _unsafeAccess(self._checkpoints, pos - 1)._values;
    }

    /**
     * @dev Returns the value in the last (most recent) checkpoint with key lower or equal than the search key, or zero
     * if there is none.
     *
     * NOTE: This is a variant of {upperLookup} that is optimised to find "recent" checkpoint (checkpoints with high
     * keys).
     */
    function upperLookupRecent(TraceArray storage self, uint256 key) internal view returns (uint256[] memory) {
        uint256 len = self._checkpoints.length;

        uint256 low = 0;
        uint256 high = len;

        if (len > 5) {
            uint256 mid = len - Math.sqrt(len);
            if (key < _unsafeAccess(self._checkpoints, mid)._key) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }

        uint256 pos = _upperBinaryLookup(self._checkpoints, key, low, high);

        return pos == 0 ? new uint256[](0) : _unsafeAccess(self._checkpoints, pos - 1)._values;
    }

    /**
     * @dev Returns the value in the most recent checkpoint, or zero if there are no checkpoints.
     */
    function latest(TraceArray storage self) internal view returns (uint256[] memory) {
        uint256 pos = self._checkpoints.length;
        return pos == 0 ? new uint256[](0) : _unsafeAccess(self._checkpoints, pos - 1)._values;
    }

    /**
     * @dev Returns whether there is a checkpoint in the structure (i.e. it is not empty), and if so the key and values
     * in the most recent checkpoint.
     */
    function latestCheckpoint(TraceArray storage self) internal view returns (bool exists, uint256 _key, uint256[] memory _values) {
        uint256 pos = self._checkpoints.length;
        if (pos == 0) {
            return (false, 0, new uint256[](0));
        } else {
            CheckpointArray memory ckpt = _unsafeAccess(self._checkpoints, pos - 1);
            return (true, ckpt._key, ckpt._values);
        }
    }

    /**
     * @dev Returns the number of checkpoints.
     */
    function length(TraceArray storage self) internal view returns (uint256) {
        return self._checkpoints.length;
    }

    /**
     * @dev Returns checkpoint at given position.
     */
    function at(TraceArray storage self, uint32 pos) internal view returns (CheckpointArray memory) {
        return self._checkpoints[pos];
    }

    /**
     * @dev Pushes a (`key`, `values`) pair into an ordered list of checkpoints, either by inserting a new checkpoint,
     * or by updating the last one.
     */
    function _insert(CheckpointArray[] storage self, uint256 key, uint256[] memory values) private returns (uint256, uint256) {
        uint256 pos = self.length;

        if (pos > 0) {
            // Copying to memory is important here.
            CheckpointArray memory last = _unsafeAccess(self, pos - 1);

            // Checkpoint keys must be non-decreasing.
            if (last._key > key) {
                revert CheckpointUnorderedInsertion();
            }

            // Update or push new checkpoint
            if (last._key == key) {
                _unsafeAccess(self, pos - 1)._values = values;
            } else {
                self.push(CheckpointArray({_key: key, _values: values}));
            }
            return (last._values.length, values.length);
        } else {
            self.push(CheckpointArray({_key: key, _values: values}));
            return (0, values.length);
        }
    }

    /**
     * @dev Return the index of the last (most recent) checkpoint with key lower or equal than the search key, or `high`
     * if there is none. `low` and `high` define a section where to do the search, with inclusive `low` and exclusive
     * `high`.
     *
     * WARNING: `high` should not be greater than the array's length.
     */
    function _upperBinaryLookup(
        CheckpointArray[] storage self,
        uint256 key,
        uint256 low,
        uint256 high
    ) private view returns (uint256) {
        while (low < high) {
            uint256 mid = Math.average(low, high);
            if (_unsafeAccess(self, mid)._key > key) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }
        return high;
    }

    /**
     * @dev Return the index of the first (oldest) checkpoint with key is greater or equal than the search key, or
     * `high` if there is none. `low` and `high` define a section where to do the search, with inclusive `low` and
     * exclusive `high`.
     *
     * WARNING: `high` should not be greater than the array's length.
     */
    function _lowerBinaryLookup(
        CheckpointArray[] storage self,
        uint256 key,
        uint256 low,
        uint256 high
    ) private view returns (uint256) {
        while (low < high) {
            uint256 mid = Math.average(low, high);
            if (_unsafeAccess(self, mid)._key < key) {
                low = mid + 1;
            } else {
                high = mid;
            }
        }
        return high;
    }

    /**
     * @dev Access an element of the array without performing bounds check. The position is assumed to be within bounds.
     */
    function _unsafeAccess(
        CheckpointArray[] storage self,
        uint256 pos
    ) private pure returns (CheckpointArray storage result) {
        assembly {
            mstore(0, self.slot)
            result.slot := add(keccak256(0, 0x20), pos)
        }
    }
}


contract VotingEscrow is UUPSUpgradeable, IERC721Metadata, IVotingEscrow, IVotes {
    using ArrayCheckpoints for ArrayCheckpoints.TraceArray;

    // Type declarations
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

    enum DepositType {
        DEPOSIT_FOR_TYPE,
        CREATE_LOCK_TYPE,
        INCREASE_LOCK_AMOUNT,
        INCREASE_UNLOCK_TIME,
        MERGE_TYPE
    }

    // State variables
    address public token;
    address public governor;
    uint256 public epoch;
    string public baseURI;
    uint8 internal _entered_state;
    uint256 internal _supply;
    uint256 internal tokenId;
    uint256 internal _totalSupply;

    mapping(uint256 => LockedBalance) public locked;
    mapping(uint256 => uint256) public ownership_change;
    mapping(uint256 => Point) public point_history;
    mapping(uint256 => Point[1000000000]) public user_point_history;
    mapping(uint256 => uint256) public user_point_epoch;
    mapping(uint256 => int128) public slope_changes;
    mapping(uint256 => address) internal idToOwner;
    mapping(uint256 => address) internal idToApprovals;
    mapping(address => uint256) internal ownerToNFTokenCount;
    mapping(address => mapping(uint256 => uint256)) internal ownerToNFTokenIdList;
    mapping(uint256 => uint256) internal tokenToOwnerIndex;
    mapping(address => mapping(address => bool)) internal ownerToOperators;
    mapping(bytes4 => bool) internal supportedInterfaces;
 
    // delegated addresses
    mapping(address => address) internal _delegatee;
    // address delegatee => [ {timestamp 1, [1, 2, 3]}, {timestamp 2, [1, 2, 3, 5]}, {timestamp 3, [1, 2, 5]} ]
    mapping(address => ArrayCheckpoints.TraceArray) internal _delegateCheckpoints;
    // tracking a signature's account nonce, incremented when delegateBySig is called
    mapping(address => uint256) internal _nonces;

    string public constant name = "Voting Escrow Continuum";
    string public constant symbol = "veCTM";
    string public constant version = "1.0.0";
    bytes16 internal constant HEX_DIGITS = "0123456789abcdef";
    uint256 internal constant WEEK = 1 weeks;
    uint256 internal constant MAXTIME = 4 * 365 * 86400;
    uint256 internal constant MULTIPLIER = 1 ether;
    int128 internal constant iMAXTIME = 4 * 365 * 86400;
    uint8 public constant decimals = 18;
    bytes4 internal constant ERC165_INTERFACE_ID = 0x01ffc9a7;
    bytes4 internal constant ERC721_INTERFACE_ID = 0x80ac58cd;
    bytes4 internal constant ERC721_METADATA_INTERFACE_ID = 0x5b5e139f;
    bytes4 internal constant VOTES_INTERFACE_ID = 0xe90fb3f6;
    bytes4 internal constant ERC6372_INTERFACE_ID = 0xda287a1d;
    uint8 internal constant NOT_ENTERED = 1;
    uint8 internal constant ENTERED = 2;
    bytes32 private constant TYPE_HASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private constant DELEGATION_TYPEHASH =
        keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    // Events
    event Deposit(
        address indexed provider,
        uint256 tokenId,
        uint256 value,
        uint256 indexed locktime,
        DepositType deposit_type,
        uint256 ts
    );
    event Withdraw(address indexed provider, uint256 tokenId, uint256 value, uint256 ts);
    event Supply(uint256 prevSupply, uint256 supply);

    // Errors
    error ERC6372InconsistentClock();
    error ERC5805FutureLookup(uint256 timepoint, uint48 clock);
    error InvalidAccountNonce(address account, uint256 currentNonce);

    // Modifiers
    modifier nonreentrant() {
        require(_entered_state == NOT_ENTERED);
        _entered_state = ENTERED;
        _;
        _entered_state = NOT_ENTERED;
    }

    // Functions
    constructor() {
        _disableInitializers();
    }

    // External mutable
    function initialize(address token_addr, address _governor, string memory base_uri) external initializer {
        token = token_addr;
        governor = _governor;
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

    function create_lock(uint256 _value, uint256 _lock_duration) external nonreentrant returns (uint256) {
        return _create_lock(_value, _lock_duration, msg.sender);
    }

    function create_lock_for(uint256 _value, uint256 _lock_duration, address _to)
        external
        nonreentrant
        returns (uint256)
    {
        return _create_lock(_value, _lock_duration, _to);
    }

    function increase_amount(uint256 _tokenId, uint256 _value) external nonreentrant {
        assert(_isApprovedOrOwner(msg.sender, _tokenId));

        LockedBalance memory _locked = locked[_tokenId];

        assert(_value > 0);
        require(_locked.amount > 0, "No existing lock found");
        require(_locked.end > block.timestamp, "Cannot add to expired lock. Withdraw");

        _deposit_for(_tokenId, _value, 0, _locked, DepositType.INCREASE_LOCK_AMOUNT);
    }

    function increase_unlock_time(uint256 _tokenId, uint256 _lock_duration) external nonreentrant {
        assert(_isApprovedOrOwner(msg.sender, _tokenId));

        LockedBalance memory _locked = locked[_tokenId];
        uint256 unlock_time = ((block.timestamp + _lock_duration) / WEEK) * WEEK;

        require(_locked.end > block.timestamp, "Lock expired");
        require(_locked.amount > 0, "Nothing is locked");
        require(unlock_time > _locked.end, "Can only increase lock duration");
        require(unlock_time <= block.timestamp + MAXTIME, "Voting lock can be 4 years max");

        _deposit_for(_tokenId, 0, unlock_time, _locked, DepositType.INCREASE_UNLOCK_TIME);
    }

    function withdraw(uint256 _tokenId) external nonreentrant {
        assert(_isApprovedOrOwner(msg.sender, _tokenId));
        // CHECK ATTACHMENT AND VOTING RESTRICTIONS

        LockedBalance memory _locked = locked[_tokenId];
        require(block.timestamp >= _locked.end, "The lock didn't expire");
        uint256 value = uint256(int256(_locked.amount));

        locked[_tokenId] = LockedBalance(0, 0);
        uint256 supply_before = _supply;
        _supply = supply_before - value;

        _checkpoint(_tokenId, _locked, LockedBalance(0, 0));

        assert(IERC20(token).transfer(msg.sender, value));

        _burn(_tokenId);

        emit Withdraw(msg.sender, _tokenId, value, block.timestamp);
        emit Supply(supply_before, supply_before - value);
    }

    function merge(uint256 _from, uint256 _to) external {
        // CHECK ATTACHMENT AND VOTING RESTRICTIONS
        require(_from != _to);
        require(_isApprovedOrOwner(msg.sender, _from));
        require(_isApprovedOrOwner(msg.sender, _to));

        LockedBalance memory _locked0 = locked[_from];
        LockedBalance memory _locked1 = locked[_to];
        uint256 value0 = uint256(int256(_locked0.amount));
        uint256 end = _locked0.end >= _locked1.end ? _locked0.end : _locked1.end;

        locked[_from] = LockedBalance(0, 0);
        _checkpoint(_from, _locked0, LockedBalance(0, 0));
        _burn(_from);
        _deposit_for(_to, value0, end, _locked1, DepositType.MERGE_TYPE);
    }

    function deposit_for(uint256 _tokenId, uint256 _value) external nonreentrant {
        LockedBalance memory _locked = locked[_tokenId];

        require(_value > 0);
        require(_locked.amount > 0, "No existing lock found");
        require(_locked.end > block.timestamp, "Cannot add to expired lock. Withdraw");
        _deposit_for(_tokenId, _value, 0, _locked, DepositType.DEPOSIT_FOR_TYPE);
    }

    function transferFrom(address _from, address _to, uint256 _tokenId) external {
        _transferFrom(_from, _to, _tokenId, msg.sender);
    }

    function approve(address _approved, uint256 _tokenId) external {
        _approve(_approved, _tokenId);
    }

    function setApprovalForAll(address _operator, bool _approved) external {
        assert(_operator != msg.sender);
        ownerToOperators[msg.sender][_operator] = _approved;
        emit ApprovalForAll(msg.sender, _operator, _approved);
    }

    function delegate(address delegatee) external {
        address account = msg_sender();
        _delegate(account, delegatee);
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

    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes memory _data) external {
        _safeTransferFrom(_from, _to, _tokenId, _data);
    }

    function safeTransferFrom(address _from, address _to, uint256 _tokenId) external {
        _safeTransferFrom(_from, _to, _tokenId, "");
    }

    function checkpoint() external {
        _checkpoint(0, LockedBalance(0, 0), LockedBalance(0, 0));
    }

    // External view
    function balanceOf(address _owner) external view returns (uint256) {
        return _balance(_owner);
    }

    function balanceOfNFT(uint256 _tokenId) external view returns (uint256) {
        if (ownership_change[_tokenId] == block.number) return 0;
        return _balanceOfNFT(_tokenId, block.timestamp);
    }

    function balanceOfNFTAt(uint256 _tokenId, uint256 _t) external view returns (uint256) {
        return _balanceOfNFT(_tokenId, _t);
    }

    function balanceOfAtNFT(uint256 _tokenId, uint256 _block) external view returns (uint256) {
        return _balanceOfAtNFT(_tokenId, _block);
    }

    function ownerOf(uint256 _tokenId) external view returns (address) {
        return idToOwner[_tokenId];
    }

    // return the total number of NFTs
    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function totalPower() external view returns (uint256) {
        return _totalPowerAtT(block.timestamp);
    }

    function totalPowerAtT(uint256 t) external view returns (uint256) {
        return _totalPowerAtT(t);
    }

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
        return _supply_at(point, point.ts + dt);
    }

    function getApproved(uint256 _tokenId) external view returns (address) {
        return idToApprovals[_tokenId];
    }

    function isApprovedForAll(address _owner, address _operator) external view returns (bool) {
        return (ownerToOperators[_owner])[_operator];
    }

    function isApprovedOrOwner(address _spender, uint256 _tokenId) external view returns (bool) {
        return _isApprovedOrOwner(_spender, _tokenId);
    }

    function tokenOfOwnerByIndex(address _owner, uint256 _tokenIndex) external view returns (uint256) {
        return ownerToNFTokenIdList[_owner][_tokenIndex];
    }

    function getVotes(address account) external view returns (uint256) {
        uint256[] memory delegateTokenIdsCurrent = _delegateCheckpoints[account].latest();
        return _calculateCumulativeVotingPower(delegateTokenIdsCurrent, clock());
    }

    function getPastVotes(address account, uint256 timepoint) external view returns (uint256) {
        uint48 currentTimepoint = clock();
        if (timepoint >= currentTimepoint) {
            revert ERC5805FutureLookup(timepoint, currentTimepoint);
        }
        uint256[] memory delegateTokenIdsAt = _delegateCheckpoints[account].upperLookupRecent(uint256(timepoint));
        return _calculateCumulativeVotingPower(delegateTokenIdsAt, timepoint);
    }

    /**
     * @dev The name `getPastTotalSupply` is maintained to keep in-line with IVotes interface, but it actually returns
     * total vote power. For current total supply of NFTs, call `totalSupply`.
     */
    function getPastTotalSupply(uint256 timepoint) external view returns (uint256) {
        uint48 currentTimepoint = clock();
        if (timepoint >= currentTimepoint) {
            revert ERC5805FutureLookup(timepoint, currentTimepoint);
        }
        return _totalPowerAtT(timepoint);
    }

    function delegates(address account) external view returns (address) {
        return _delegatee[account];
    }

    function get_last_user_slope(uint256 _tokenId) external view returns (int128) {
        uint256 uepoch = user_point_epoch[_tokenId];
        return user_point_history[_tokenId][uepoch].slope;
    }

    function user_point_history__ts(uint256 _tokenId, uint256 _idx) external view returns (uint256) {
        return user_point_history[_tokenId][_idx].ts;
    }

    function locked__end(uint256 _tokenId) external view returns (uint256) {
        return locked[_tokenId].end;
    }

    function tokenURI(uint256 _tokenId) external view returns (string memory) {
        require(idToOwner[_tokenId] != address(0), "Query for nonexistent token");
        string memory _baseURI = baseURI;
        return bytes(_baseURI).length > 0 ? string(abi.encodePacked(_baseURI, toString(_tokenId))) : "";
    }

    function supportsInterface(bytes4 _interfaceID) external view returns (bool) {
        return supportedInterfaces[_interfaceID];
    }

    function checkpoints(address account, uint32 pos) external view returns (ArrayCheckpoints.CheckpointArray memory) {
        return _delegateCheckpoints[account].at(pos);
    }

    // Public view
    function clock() public view returns (uint48) {
        return uint48(block.timestamp);
    }

    function CLOCK_MODE() public view returns (string memory) {
        if (clock() != uint48(block.timestamp)) {
            revert ERC6372InconsistentClock();
        }
        return "mode=timestamp";
    }

    // Internal mutable
    function _create_lock(uint256 _value, uint256 _lock_duration, address _to) internal returns (uint256) {
        uint256 unlock_time = ((block.timestamp + _lock_duration) / WEEK) * WEEK;

        require(_value > 0);
        require(unlock_time > block.timestamp, "Can only lock until time in the future");
        require(unlock_time <= block.timestamp + MAXTIME, "Voting lock can be 4 years max");

        ++tokenId;
        uint256 _tokenId = tokenId;
        _mint(_to, _tokenId);

        _deposit_for(_tokenId, _value, unlock_time, locked[_tokenId], DepositType.CREATE_LOCK_TYPE);
        return _tokenId;
    }

    function _deposit_for(
        uint256 _tokenId,
        uint256 _value,
        uint256 unlock_time,
        LockedBalance memory locked_balance,
        DepositType deposit_type
    ) internal {
        LockedBalance memory _locked = locked_balance;
        uint256 supply_before = _supply;

        _supply = supply_before + _value;
        LockedBalance memory old_locked;
        (old_locked.amount, old_locked.end) = (_locked.amount, _locked.end);
        _locked.amount += int128(int256(_value));
        if (unlock_time != 0) {
            _locked.end = unlock_time;
        }
        locked[_tokenId] = _locked;

        _checkpoint(_tokenId, old_locked, _locked);

        address from = msg.sender;
        if (_value != 0 && deposit_type != DepositType.MERGE_TYPE) {
            assert(IERC20(token).transferFrom(from, address(this), _value));
        }

        emit Deposit(from, _tokenId, _value, _locked.end, deposit_type, block.timestamp);
        emit Supply(supply_before, supply_before + _value);
    }

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

    function _transferFrom(address _from, address _to, uint256 _tokenId, address _sender) internal {
        require(_isApprovedOrOwner(_sender, _tokenId));
        _clearApproval(_from, _tokenId);
        _removeTokenFrom(_from, _tokenId);
        _addTokenTo(_to, _tokenId);
        ownership_change[_tokenId] = block.number;
        emit Transfer(_from, _to, _tokenId);
    }

    function _approve(address _approved, uint256 _tokenId) internal {
        address owner = idToOwner[_tokenId];
        require(owner != address(0));
        require(_approved != owner);
        bool senderIsOwner = (idToOwner[_tokenId] == msg.sender);
        bool senderIsApprovedForAll = (ownerToOperators[owner])[msg.sender];
        require(senderIsOwner || senderIsApprovedForAll);
        idToApprovals[_tokenId] = _approved;
        emit Approval(owner, _approved, _tokenId);
    }

    function _clearApproval(address _owner, uint256 _tokenId) internal {
        assert(idToOwner[_tokenId] == _owner);
        if (idToApprovals[_tokenId] != address(0)) {
            idToApprovals[_tokenId] = address(0);
        }
    }

    function _addTokenToOwnerList(address _to, uint256 _tokenId) internal {
        uint256 current_count = _balance(_to);

        ownerToNFTokenIdList[_to][current_count] = _tokenId;
        tokenToOwnerIndex[_tokenId] = current_count;
    }

    function _removeTokenFromOwnerList(address _from, uint256 _tokenId) internal {
        uint256 current_count = _balance(_from) - 1;
        uint256 current_index = tokenToOwnerIndex[_tokenId];

        if (current_count == current_index) {
            ownerToNFTokenIdList[_from][current_count] = 0;
            tokenToOwnerIndex[_tokenId] = 0;
        } else {
            uint256 lastTokenId = ownerToNFTokenIdList[_from][current_count];

            ownerToNFTokenIdList[_from][current_index] = lastTokenId;
            tokenToOwnerIndex[lastTokenId] = current_index;

            ownerToNFTokenIdList[_from][current_count] = 0;
            tokenToOwnerIndex[_tokenId] = 0;
        }
    }

    function _addTokenTo(address _to, uint256 _tokenId) internal {
        assert(idToOwner[_tokenId] == address(0));
        idToOwner[_tokenId] = _to;
        _addTokenToOwnerList(_to, _tokenId);
        ownerToNFTokenCount[_to] += 1;
    }

    function _removeTokenFrom(address _from, uint256 _tokenId) internal {
        assert(idToOwner[_tokenId] == _from);
        idToOwner[_tokenId] = address(0);
        _removeTokenFromOwnerList(_from, _tokenId);
        ownerToNFTokenCount[_from] -= 1;
    }

    function _mint(address _to, uint256 _tokenId) internal returns (bool) {
        assert(_to != address(0));
        _addTokenTo(_to, _tokenId);
        _totalSupply++;
        emit Transfer(address(0), _to, _tokenId);
        return true;
    }

    function _burn(uint256 _tokenId) internal {
        require(_isApprovedOrOwner(msg.sender, _tokenId), "caller is not owner nor approved");

        address owner = idToOwner[_tokenId];

        _approve(address(0), _tokenId);
        _removeTokenFrom(msg.sender, _tokenId);
        _totalSupply--;
        emit Transfer(owner, address(0), _tokenId);
    }

    function _safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes memory _data) internal {
        _transferFrom(_from, _to, _tokenId, msg.sender);

        if (_isContract(_to)) {
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

    function _checkpoint(uint256 _tokenId, LockedBalance memory old_locked, LockedBalance memory new_locked) internal {
        Point memory u_old;
        Point memory u_new;
        int128 old_dslope = 0;
        int128 new_dslope = 0;
        uint256 _epoch = epoch;

        if (_tokenId != 0) {
            if (old_locked.end > block.timestamp && old_locked.amount > 0) {
                u_old.slope = old_locked.amount / iMAXTIME;
                u_old.bias = u_old.slope * int128(int256(old_locked.end - block.timestamp));
            }
            if (new_locked.end > block.timestamp && new_locked.amount > 0) {
                u_new.slope = new_locked.amount / iMAXTIME;
                u_new.bias = u_new.slope * int128(int256(new_locked.end - block.timestamp));
            }

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
        Point memory initial_last_point = last_point;
        uint256 block_slope = 0;
        if (block.timestamp > last_point.ts) {
            block_slope = (MULTIPLIER * (block.number - last_point.blk)) / (block.timestamp - last_point.ts);
        }

        {
            uint256 t_i = (last_checkpoint / WEEK) * WEEK;
            for (uint256 i = 0; i < 255; ++i) {
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
                    last_point.bias = 0;
                }
                if (last_point.slope < 0) {
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

        if (_tokenId != 0) {
            last_point.slope += (u_new.slope - u_old.slope);
            last_point.bias += (u_new.bias - u_old.bias);
            if (last_point.slope < 0) {
                last_point.slope = 0;
            }
            if (last_point.bias < 0) {
                last_point.bias = 0;
            }
        }

        point_history[_epoch] = last_point;

        if (_tokenId != 0) {
            if (old_locked.end > block.timestamp) {
                old_dslope += u_old.slope;
                if (new_locked.end == old_locked.end) {
                    old_dslope -= u_new.slope;
                }
                slope_changes[old_locked.end] = old_dslope;
            }

            if (new_locked.end > block.timestamp) {
                if (new_locked.end > old_locked.end) {
                    new_dslope -= u_new.slope;
                    slope_changes[new_locked.end] = new_dslope;
                }
            }
            uint256 user_epoch = user_point_epoch[_tokenId] + 1;

            user_point_epoch[_tokenId] = user_epoch;
            u_new.ts = block.timestamp;
            u_new.blk = block.number;
            user_point_history[_tokenId][user_epoch] = u_new;
        }
    }

    // Internal view
    function _balance(address _owner) internal view returns (uint256) {
        return ownerToNFTokenCount[_owner];
    }

    function _balanceOfNFT(uint256 _tokenId, uint256 _t) internal view returns (uint256) {
        uint256 _epoch = user_point_epoch[_tokenId];
        if (_epoch == 0) {
            return 0;
        } else {
            Point memory last_point = user_point_history[_tokenId][_epoch];
            last_point.bias -= last_point.slope * int128(int256(_t) - int256(last_point.ts));
            if (last_point.bias < 0) {
                last_point.bias = 0;
            }
            return uint256(int256(last_point.bias));
        }
    }

    function _balanceOfAtNFT(uint256 _tokenId, uint256 _block) internal view returns (uint256) {
        assert(_block <= block.number);

        uint256 _min = 0;
        uint256 _max = user_point_epoch[_tokenId];
        for (uint256 i = 0; i < 128; ++i) {
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

    function _totalPowerAtT(uint256 t) internal view returns (uint256) {
        uint256 _epoch = epoch;
        Point memory last_point = point_history[_epoch];
        return _supply_at(last_point, t);
    }

    function _isApprovedOrOwner(address _spender, uint256 _tokenId) internal view returns (bool) {
        address owner = idToOwner[_tokenId];
        bool spenderIsOwner = owner == _spender;
        bool spenderIsApproved = _spender == idToApprovals[_tokenId];
        bool spenderIsApprovedForAll = (ownerToOperators[owner])[_spender];
        return spenderIsOwner || spenderIsApproved || spenderIsApprovedForAll;
    }

    function _authorizeUpgrade(address newImplementation) internal view override {
        require(newImplementation != address(0), "New implementation cannot be zero address");
        require(msg.sender == governor, "Only Governor is allowed to make upgrades");
    }

    function _find_block_epoch(uint256 _block, uint256 max_epoch) internal view returns (uint256) {
        uint256 _min = 0;
        uint256 _max = max_epoch;
        for (uint256 i = 0; i < 128; ++i) {
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

    function _numCheckpoints(address account) internal view returns (uint32) {
        return uint32(_delegateCheckpoints[account].length());
    }

    function _calculateCumulativeVotingPower(uint256[] memory _tokenIds, uint256 _t) internal pure returns (uint256) {
        uint256 cumulativeVotingPower;
        for (uint8 i = 0; i < _tokenIds.length; i++) {
            // change below line to increment cumulativeVePower by the voting power of each token ID at time _t
            cumulativeVotingPower += _tokenIds[i] + _t;
        }
        return cumulativeVotingPower;
    }

    function _isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

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

    function toString(uint256 value) internal pure returns (string memory) {
        unchecked {
            uint256 length = Math.log10(value) + 1;
            string memory buffer = new string(length);
            uint256 ptr;
            /// @solidity memory-safe-assembly
            assembly {
                ptr := add(buffer, add(32, length))
            }
            while (true) {
                ptr--;
                /// @solidity memory-safe-assembly
                assembly {
                    mstore8(ptr, byte(mod(value, 10), HEX_DIGITS))
                }
                value /= 10;
                if (value == 0) break;
            }
            return buffer;
        }
    }

    function _add(uint256[] memory current, uint256[] memory addIDs) internal pure returns (uint256[] memory) {
        uint256[] memory updated;
        uint256 updatedLength;
        for (uint256 i = 0; i < addIDs.length; i++) {
            current[updatedLength] = addIDs[i];
            updatedLength++;
        }
        return updated;
    }

    function _remove(uint256[] memory current, uint256[] memory removeIDs) internal pure returns (uint256[] memory) {
        uint256[] memory updated;
        uint256 updatedLength;
        for (uint256 i = 0; i < removeIDs.length; i++) {
            for (uint256 j = 0; j < current.length; j++) {
                if (current[j] != removeIDs[i]) {
                    updated[updatedLength] = current[j];
                    updatedLength++;
                }
            }
        }

        return updated;
    }

    // Private mutable
    function _push(
        ArrayCheckpoints.TraceArray storage store,
        function(uint256[] memory, uint256[] memory) view returns (uint256[] memory) op,
        uint256[] memory deltaTokenIDs
    ) private returns (uint256, uint256) {
        return store.push(clock(), op(store.latest(), deltaTokenIDs));
    }
}