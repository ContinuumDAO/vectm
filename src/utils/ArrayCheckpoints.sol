// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @notice Modified version of OpenZeppelin's Checkpoints library that tracks arrays instead of single values.
 * @author OpenZeppelin, modified for arrays by @patrickcure
 * @dev While the original library contained some assembly which allows `_unsafeAccess` of a checkpoint array, here it
 * is removed because it causes problems when the checkpoints contain dynamic sized arrays.
 */
library ArrayCheckpoints {
    /**
     * @notice An array was attempted to be inserted on a past checkpoint.
     */
    error CheckpointUnorderedInsertion();

    /**
     * @notice Trace where checkpoints can be stored.
     */
    struct TraceArray {
        CheckpointArray[] _checkpoints;
    }

    /**
     * @notice Checkpoint that tracks a `_key` which is associated with an array of `_values`.
     */
    struct CheckpointArray {
        uint256 _key;
        uint256[] _values;
    }

    /**
     * @notice Pushes a (`key`, `values`) pair into a Trace so that it is stored as the checkpoint.
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
     * @notice Returns the values array in the first (oldest) checkpoint with key greater or equal than the search key, or
     * an
     * empty array if there is none.
     */
    function lowerLookup(TraceArray storage self, uint256 key) internal view returns (uint256[] memory) {
        uint256 len = self._checkpoints.length;
        uint256 pos = _lowerBinaryLookup(self._checkpoints, key, 0, len);
        return pos == len ? new uint256[](0) : _unsafeAccess(self._checkpoints, pos)._values;
    }

    /**
     * @notice Returns the value in the last (most recent) checkpoint with key lower or equal than the search key, or zero
     * if there is none.
     */
    function upperLookup(TraceArray storage self, uint256 key) internal view returns (uint256[] memory) {
        uint256 len = self._checkpoints.length;
        uint256 pos = _upperBinaryLookup(self._checkpoints, key, 0, len);
        return pos == 0 ? new uint256[](0) : _unsafeAccess(self._checkpoints, pos - 1)._values;
    }

    /**
     * @notice Returns the value in the last (most recent) checkpoint with key lower or equal than the search key, or zero
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
     * @notice Returns the value in the most recent checkpoint, or zero if there are no checkpoints.
     */
    function latest(TraceArray storage self) internal view returns (uint256[] memory) {
        uint256 pos = self._checkpoints.length;
        return pos == 0 ? new uint256[](0) : _unsafeAccess(self._checkpoints, pos - 1)._values;
    }

    /**
     * @notice Returns whether there is a checkpoint in the structure (i.e. it is not empty), and if so the key and values
     * in the most recent checkpoint.
     */
    function latestCheckpoint(TraceArray storage self)
        internal
        view
        returns (bool exists, uint256 _key, uint256[] memory _values)
    {
        uint256 pos = self._checkpoints.length;
        if (pos == 0) {
            return (false, 0, new uint256[](0));
        } else {
            CheckpointArray memory ckpt = _unsafeAccess(self._checkpoints, pos - 1);
            return (true, ckpt._key, ckpt._values);
        }
    }

    /**
     * @notice Returns the number of checkpoints.
     */
    function length(TraceArray storage self) internal view returns (uint256) {
        return self._checkpoints.length;
    }

    /**
     * @notice Returns checkpoint at given position.
     */
    function at(TraceArray storage self, uint32 pos) internal view returns (CheckpointArray memory) {
        return self._checkpoints[pos];
    }

    /**
     * @notice Pushes a (`key`, `values`) pair into an ordered list of checkpoints, either by inserting a new checkpoint,
     * or by updating the last one.
     */
    function _insert(CheckpointArray[] storage self, uint256 key, uint256[] memory values)
        private
        returns (uint256, uint256)
    {
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
     * @notice Return the index of the last (most recent) checkpoint with key lower or equal than the search key, or `high`
     * if there is none. `low` and `high` define a section where to do the search, with inclusive `low` and exclusive
     * `high`.
     *
     * WARNING: `high` should not be greater than the array's length.
     */
    function _upperBinaryLookup(CheckpointArray[] storage self, uint256 key, uint256 low, uint256 high)
        private
        view
        returns (uint256)
    {
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
     * @notice Return the index of the first (oldest) checkpoint with key is greater or equal than the search key, or
     * `high` if there is none. `low` and `high` define a section where to do the search, with inclusive `low` and
     * exclusive `high`.
     *
     * WARNING: `high` should not be greater than the array's length.
     */
    function _lowerBinaryLookup(CheckpointArray[] storage self, uint256 key, uint256 low, uint256 high)
        private
        view
        returns (uint256)
    {
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
     * @notice Access the member of an array `self` at position `pos`.
     * @dev Due to modifications on the original Checkpoints library (which checkpoints single values
     *      as opposed to dynamic-sized arrays), the assembly outlined here does not work, nor is required.
     *      It now does a high level array read and is no longer unsafe.
     */
    function _unsafeAccess(CheckpointArray[] storage self, uint256 pos)
        private
        view
        returns (CheckpointArray storage result)
    {
        // assembly {
        //     mstore(0, self.slot)
        //     result.slot := add(keccak256(0, 0x20), pos)
        // }
        return self[pos];
    }
}
