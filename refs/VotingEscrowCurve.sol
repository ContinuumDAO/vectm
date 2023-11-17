// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IERC20 {
    function decimals() external view returns (uint256);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address spender, address to, uint256 amount) external returns (bool);
}

interface SmartWalletChecker {
    function check(address addr) external returns (bool);
}

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

enum LockType {
    DEPOSIT_FOR_TYPE,
    CREATE_LOCK_TYPE,
    INCREASE_LOCK_AMOUNT,
    INCREASE_UNLOCK_TIME
}

contract VotingEscrowCurve {
    event CommitOwnership(address admin);
    event ApplyOwnership(address admin);
    event Deposit(address indexed provider, uint256 value, uint256 indexed locktime, LockType _type, uint256 ts);
    event Withdraw(address indexed provider, uint256 value, uint256 ts);
    event Supply(uint256 prevSupply, uint256 supply);

    uint256 constant WEEK = 7 * 86400;
    uint256 constant MAXTIME = 4 * 365 * 86400;
    uint256 constant MULTIPLIER = 10 ** 18;

    address public token;
    uint256 public supply;

    mapping(address => LockedBalance) public locked;

    uint256 public epoch;
    Point[] public pointHistory;
    mapping(address => Point[]) public userPointHistory;
    mapping(address => uint256) public userPointEpoch;
    mapping(uint256 => int128) public slopeChanges;

    address public controller;
    bool public transfersEnabled;

    string public name;
    string public symbol;
    string public version;
    uint256 public decimals;

    address public futureSmartWalletChecker;
    address public smartWalletChecker;

    address public admin;
    address public futureAdmin;

    uint8 private _lock = 0;

    modifier nonReentrant() {
        require(_lock == 0);
        _lock = 1;
        _;
        _lock = 0;
    }

    constructor(address tokenAddr, string memory _name, string memory _symbol, string memory _version) {
        admin = msg.sender;
        token = tokenAddr;
        pointHistory[0].blk = block.number;
        pointHistory[0].ts = block.timestamp;
        controller = msg.sender;
        transfersEnabled = true;

        uint256 _decimals = IERC20(tokenAddr).decimals();
        assert(_decimals <= 255);
        decimals = _decimals;

        name = _name;
        symbol = _symbol;
        version = _version;
    }

    function commitTransferOwnership(address addr) external {
        require(msg.sender == admin);
        futureAdmin = addr;
        emit CommitOwnership(addr);
    }

    function applyTransferOwnership() external {
        require(msg.sender == admin);
        address _admin = futureAdmin;
        require(_admin != address(0));
        admin = _admin;
        emit ApplyOwnership(_admin);
    }

    function commitSmartWalletChecker(address addr) external {
        require(msg.sender == admin);
        futureSmartWalletChecker = addr;
    }

    function applySmartWalletChecker() external {
        require(msg.sender == admin);
        smartWalletChecker = futureSmartWalletChecker;
    }

    function assertNotContract(address addr) internal {
        if (addr != tx.origin) {
            address checker = smartWalletChecker;

            if (checker != address(0)) {
                if (SmartWalletChecker(checker).check(addr)) {
                    return;
                }
            }

            revert("Smart contract depositors not allowed");
        }
    }

    function getLastUserSlope(address addr) external view returns (int128) {
        uint256 uEpoch = userPointEpoch[addr];
        return userPointHistory[addr][uEpoch].slope;
    }

    function userPointHistoryTs(address _addr, uint256 _idx) external view returns (uint256) {
        return userPointHistory[_addr][_idx].ts;
    }

    function lockedEnd(address _addr) external view returns (uint256) {
        return locked[_addr].end;
    }

    function _checkpoint(address addr, LockedBalance memory oldLocked, LockedBalance memory newLocked) internal {
        Point memory uOld = Point(0, 0, 0, 0);
        Point memory uNew = Point(0, 0, 0, 0);
        int128 oldDSlope = 0;
        int128 newDSlope = 0;
        uint256 _epoch = epoch;

        if (addr != address(0)) {
            if (oldLocked.end > block.timestamp && oldLocked.amount > 0) {
                uOld.slope = int128(oldLocked.amount / int128(uint128(MAXTIME)));
                uOld.bias = uOld.slope * int128(uint128(oldLocked.end - block.timestamp));
            }

            if (newLocked.end > block.timestamp && newLocked.amount > 0) {
                uNew.slope = newLocked.amount / int128(uint128(MAXTIME));
                uNew.bias = uNew.slope * int128(uint128(newLocked.end - block.timestamp));
            }

            oldDSlope = slopeChanges[oldLocked.end];

            if (newLocked.end != 0) {
                if (newLocked.end == oldLocked.end) {
                    newDSlope = oldDSlope;
                } else {
                    newDSlope = slopeChanges[newLocked.end];
                }
            }
        }

        Point memory lastPoint = Point({bias: 0, slope: 0, ts: block.timestamp, blk: block.number});

        if (_epoch > 0) {
            lastPoint = pointHistory[_epoch];
        }

        uint256 lastCheckpoint = lastPoint.ts;
        Point memory initialLastPoint = lastPoint;
        uint256 blockSlope = 0;

        if (block.timestamp > lastPoint.ts) {
            blockSlope = MULTIPLIER * (block.number - lastPoint.blk) / (block.timestamp - lastPoint.ts);
        }

        uint256 tI = (lastCheckpoint / WEEK) * WEEK;

        for (uint8 i = 0; i < 255; i++) {
            tI += WEEK;
            int128 dSlope = 0;

            if (tI > block.timestamp) {
                tI = block.timestamp;
            } else {
                dSlope = slopeChanges[tI];
            }

            lastPoint.bias -= lastPoint.slope * int128(uint128(tI - lastCheckpoint));
            lastPoint.slope += dSlope;

            if (lastPoint.bias < 0) {
                lastPoint.bias = 0;
            }

            if (lastPoint.slope < 0) {
                lastPoint.slope = 0;
            }

            lastCheckpoint = tI;
            lastPoint.ts = tI;
            lastPoint.blk = initialLastPoint.blk + blockSlope * (tI - initialLastPoint.ts) / MULTIPLIER;
            _epoch += 1;

            if (tI == block.timestamp) {
                lastPoint.blk = block.number;
                break;
            } else {
                pointHistory[_epoch] = lastPoint;
            }
        }

        epoch = _epoch;

        if (addr != address(0)) {
            lastPoint.slope += (uNew.slope - uOld.slope);
            lastPoint.bias += (uNew.bias - uOld.bias);

            if (lastPoint.slope < 0) {
                lastPoint.slope = 0;
            }

            if (lastPoint.bias < 0) {
                lastPoint.bias = 0;
            }
        }

        pointHistory[_epoch] = lastPoint;

        if (addr != address(0)) {
            if (oldLocked.end > block.timestamp) {
                oldDSlope += uOld.slope;

                if (newLocked.end == oldLocked.end) {
                    oldDSlope -= uNew.slope;
                }

                slopeChanges[oldLocked.end] = oldDSlope;
            }

            if (newLocked.end > block.timestamp) {
                if (newLocked.end > oldLocked.end) {
                    newDSlope -= uNew.slope;
                    slopeChanges[newLocked.end] = newDSlope;
                }
            }

            uint256 userEpoch = userPointEpoch[addr] + 1;

            userPointEpoch[addr] = userEpoch;
            uNew.ts = block.timestamp;
            uNew.blk = block.number;
            userPointHistory[addr][userEpoch] = uNew;
        }
    }

    function _depositFor(
        address _addr,
        uint256 _value,
        uint256 unlockTime,
        LockedBalance memory lockedBalance,
        LockType lockType
    ) internal {
        LockedBalance memory _locked = lockedBalance;
        uint256 supplyBefore = supply;

        supply = supplyBefore + _value;
        LockedBalance memory oldLocked = _locked;
        _locked.amount += int128(uint128(_value));

        if (unlockTime != 0) {
            _locked.end = unlockTime;
        }

        locked[_addr] = _locked;

        _checkpoint(_addr, oldLocked, _locked);

        if (_value != 0) {
            require(IERC20(token).transferFrom(_addr, address(this), _value));
        }

        emit Deposit(_addr, _value, _locked.end, lockType, block.timestamp);
        emit Supply(supplyBefore, supplyBefore + _value);
    }

    function checkpoint() external {
        _checkpoint(address(0), LockedBalance(0, 0), LockedBalance(0, 0));
    }

    function depositFor(address _addr, uint256 _value) external nonReentrant {
        LockedBalance memory _locked = locked[_addr];

        require(_value > 0);
        require(_locked.amount > 0, "No existing lock found");
        require(_locked.end > block.timestamp, "Cannot add to expired lock. Withdraw");

        _depositFor(_addr, _value, 0, locked[_addr], LockType.DEPOSIT_FOR_TYPE);
    }

    function createLock(uint256 _value, uint256 _unlockTime) external nonReentrant {
        assertNotContract(msg.sender);
        uint256 unlockTime = (_unlockTime / WEEK) * WEEK;
        LockedBalance memory _locked = locked[msg.sender];

        require(_value > 0);
        require(_locked.amount == 0, "Withdraw old tokens first");
        require(unlockTime > block.timestamp, "Can only lock until time in the future");
        require(unlockTime <= block.timestamp + MAXTIME, "Voting lock can be 4 years max");

        _depositFor(msg.sender, _value, unlockTime, _locked, LockType.CREATE_LOCK_TYPE);
    }

    function increaseAmount(uint256 _value) external nonReentrant {
        assertNotContract(msg.sender);
        LockedBalance memory _locked = locked[msg.sender];

        require(_value > 0);
        require(_locked.amount > 0, "No existing lock found");
        require(_locked.end > block.timestamp, "Cannot add to expired lock. Withdraw");

        _depositFor(msg.sender, _value, 0, _locked, LockType.INCREASE_LOCK_AMOUNT);
    }

    function increaseUnlockTime(uint256 _unlockTime) external nonReentrant {
        assertNotContract(msg.sender);
        LockedBalance memory _locked = locked[msg.sender];
        uint256 unlockTime = (_unlockTime / WEEK) * WEEK;

        require(_locked.end > block.timestamp, "Lock expired");
        require(_locked.amount > 0, "Nothing is locked");
        require(unlockTime > _locked.end, "Can only increase lock duration");
        require(unlockTime <= block.timestamp + MAXTIME, "Voting lock can be 4 years max");

        _depositFor(msg.sender, 0, unlockTime, _locked, LockType.INCREASE_UNLOCK_TIME);
    }

    function withdraw() external nonReentrant {
        LockedBalance memory _locked = locked[msg.sender];
        require(block.timestamp >= _locked.end, "The lock didn't expire");
        uint256 value = uint256(uint128(_locked.amount));

        LockedBalance memory oldLocked = _locked;
        _locked.end = 0;
        _locked.amount = 0;
        locked[msg.sender] = _locked;
        uint256 supplyBefore = supply;
        supply = supplyBefore - value;

        _checkpoint(msg.sender, oldLocked, _locked);

        require(IERC20(token).transfer(msg.sender, value));

        emit Withdraw(msg.sender, value, block.timestamp);
        emit Supply(supplyBefore, supplyBefore - value);
    }

    function findBlockEpoch(uint256 _block, uint256 maxEpoch) internal view returns (uint256) {
        uint256 _min = 0;
        uint256 _max = maxEpoch;

        for (uint8 i = 0; i < 128; i++) {
            if (_min >= _max) {
                break;
            }

            uint256 _mid = (_min + _max + 1) / 2;

            if (pointHistory[_mid].blk <= _block) {
                _min = _mid;
            } else {
                _max = _mid - 1;
            }
        }

        return _min;
    }

    function balanceOf(address addr, uint256 _t) external view returns (uint256) {
        uint256 _epoch = userPointEpoch[addr];

        if (_epoch == 0) {
            return 0;
        } else {
            Point memory lastPoint = userPointHistory[addr][_epoch];
            lastPoint.bias -= lastPoint.slope * int128(uint128(_t - lastPoint.ts));

            if (lastPoint.bias < 0) {
                lastPoint.bias = 0;
            }

            return uint256(uint128(lastPoint.bias));
        }
    }

    function balanceOfAt(address addr, uint256 _block) external view returns (uint256) {
        require(_block <= block.number);

        uint256 _min = 0;
        uint256 _max = userPointEpoch[addr];

        for (uint8 i = 0; i < 128; i++) {
            if (_min > _max) {
                break;
            }

            uint256 _mid = (_min + _max + 1) / 2;

            if (userPointHistory[addr][_mid].blk <= _block) {
                _min = _mid;
            } else {
                _max = _mid - 1;
            }
        }

        Point memory uPoint = userPointHistory[addr][_min];

        uint256 maxEpoch = epoch;
        uint256 _epoch = findBlockEpoch(_block, maxEpoch);
        Point memory point0 = pointHistory[_epoch];
        uint256 dBlock = 0;
        uint256 dT = 0;

        if (_epoch < maxEpoch) {
            Point memory point1 = pointHistory[_epoch + 1];
            dBlock = point1.blk - point0.blk;
            dT = point1.ts - point0.ts;
        } else {
            dBlock = block.number - point0.blk;
            dT = block.timestamp - point0.ts;
        }

        uint256 blockTime = point0.ts;

        if (dBlock != 0) {
            blockTime += dT * (_block - point0.blk) / dBlock;
        }

        uPoint.bias -= uPoint.slope * int128(uint128(blockTime - uPoint.ts));

        if (uPoint.bias >= 0) {
            return uint256(uint128(uPoint.bias));
        } else {
            return 0;
        }
    }

    function supplyAt(Point memory point, uint256 t) internal view returns (uint256) {
        Point memory lastPoint = point;
        uint256 tI = (lastPoint.ts / WEEK) * WEEK;

        for (uint8 i = 0; i < 255; i++) {
            tI += WEEK;
            int128 dSlope = 0;

            if (tI > t) {
                tI = t;
            } else {
                dSlope = slopeChanges[tI];
            }

            lastPoint.bias -= lastPoint.slope * int128(uint128(tI - lastPoint.ts));

            if (tI == t) {
                break;
            }

            lastPoint.slope += dSlope;
            lastPoint.ts = tI;
        }

        if (lastPoint.bias < 0) {
            lastPoint.bias = 0;
        }

        return uint256(uint128(lastPoint.bias));
    }

    function totalSupply(uint256 t) external view returns (uint256) {
        uint256 _epoch = epoch;
        Point memory lastPoint = pointHistory[_epoch];
        return supplyAt(lastPoint, t);
    }

    function totalSupplyAt(uint256 _block) external view returns (uint256) {
        require(_block <= block.number);
        uint256 _epoch = epoch;
        uint256 targetEpoch = findBlockEpoch(_block, _epoch);

        Point memory point = pointHistory[targetEpoch];
        uint256 dT = 0;

        if (targetEpoch < _epoch) {
            Point memory pointNext = pointHistory[targetEpoch + 1];

            if (point.blk != pointNext.blk) {
                dT = (_block - point.blk) * (pointNext.ts - point.ts) / (pointNext.blk - point.blk);
            }
        } else {
            if (point.blk != block.number) {
                dT = (_block - point.blk) * (block.timestamp - point.ts) / (block.number - point.blk);
            }
        }

        return supplyAt(point, point.ts + dT);
    }

    function changeController(address _newController) external {
        require(msg.sender == controller);
        controller = _newController;
    }
}
