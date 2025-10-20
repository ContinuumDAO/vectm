# ArrayCheckpoints

## Overview

The ArrayCheckpoints library is a modified version of OpenZeppelin's Checkpoints library that tracks arrays instead of single values. It provides efficient checkpointing for dynamic arrays with binary search capabilities for historical lookups.

## Contract Details

- **Contract**: `ArrayCheckpoints.sol`
- **Type**: Library
- **License**: MIT
- **Solidity Version**: 0.8.27

## Data Structures

### `TraceArray`
```solidity
struct TraceArray {
    CheckpointArray[] _checkpoints;
}
```
Contains an array of checkpoints for tracking historical array states.

### `CheckpointArray`
```solidity
struct CheckpointArray {
    uint256 _key;
    uint256[] _values;
}
```
Represents a single checkpoint with a key (timestamp) and an array of values.

## Errors

### `CheckpointUnorderedInsertion()`
Thrown when an array is attempted to be inserted on a past checkpoint.

## Functions

### `push(TraceArray storage self, uint256 key, uint256[] memory values) internal returns (uint256, uint256)`

Pushes a new checkpoint with an array of values.

**Parameters:**
- `self` (TraceArray storage): The trace array to update
- `key` (uint256): The timestamp/key for the checkpoint
- `values` (uint256[]): The array of values to store

**Returns:**
- `(uint256, uint256)`: Previous values array length and new values array length

**Behavior:**
- Adds a new checkpoint to the trace array
- Stores the key and values array
- Returns the lengths for tracking purposes
- IMPORTANT: Never accept `key` as user input to prevent disabling the library

### `lowerLookup(TraceArray storage self, uint256 key) internal view returns (uint256[] memory)`

Finds the first checkpoint with key greater than or equal to the search key.

**Parameters:**
- `self` (TraceArray storage): The trace array to search
- `key` (uint256): The search key

**Returns:**
- `uint256[]`: The values array from the first matching checkpoint, or empty array if none found

**Behavior:**
- Performs binary search to find the first checkpoint with key >= search key
- Returns the values array from that checkpoint
- Returns empty array if no matching checkpoint is found

### `upperLookup(TraceArray storage self, uint256 key) internal view returns (uint256[] memory)`

Finds the last checkpoint with key less than or equal to the search key.

**Parameters:**
- `self` (TraceArray storage): The trace array to search
- `key` (uint256): The search key

**Returns:**
- `uint256[]`: The values array from the last matching checkpoint, or empty array if none found

**Behavior:**
- Performs binary search to find the last checkpoint with key <= search key
- Returns the values array from that checkpoint
- Returns empty array if no matching checkpoint is found

### `upperLookupRecent(TraceArray storage self, uint256 key) internal view returns (uint256[] memory)`

Optimized version of upperLookup for finding recent checkpoints.

**Parameters:**
- `self` (TraceArray storage): The trace array to search
- `key` (uint256): The search key

**Returns:**
- `uint256[]`: The values array from the last matching checkpoint, or empty array if none found

**Behavior:**
- Optimized variant of upperLookup for finding "recent" checkpoints
- Uses square root optimization for large checkpoint arrays
- More efficient when searching for recent timestamps
- Returns empty array if no matching checkpoint is found

### `latest(TraceArray storage self) internal view returns (uint256[] memory)`

Gets the most recent checkpoint values.

**Parameters:**
- `self` (TraceArray storage): The trace array to query

**Returns:**
- `uint256[]`: The values array from the most recent checkpoint, or empty array if none exist

**Behavior:**
- Returns the values from the most recent checkpoint
- Returns empty array if no checkpoints exist

### `at(TraceArray storage self, uint32 pos) internal view returns (CheckpointArray memory)`

Gets a specific checkpoint at a given position.

**Parameters:**
- `self` (TraceArray storage): The trace array to query
- `pos` (uint32): The position of the checkpoint to retrieve

**Returns:**
- `CheckpointArray`: The checkpoint at the specified position

**Behavior:**
- Returns the checkpoint at the specified position
- Reverts if position is out of bounds

### `latestCheckpoint(TraceArray storage self) internal view returns (bool exists, uint256 _key, uint256[] memory _values)`

Gets the most recent checkpoint with existence check.

**Parameters:**
- `self` (TraceArray storage): The trace array to query

**Returns:**
- `exists` (bool): Whether there is a checkpoint in the structure
- `_key` (uint256): The key of the most recent checkpoint
- `_values` (uint256[]): The values array of the most recent checkpoint

**Behavior:**
- Returns whether there is a checkpoint in the structure and if so, the key and values in the most recent checkpoint
- Returns (false, 0, empty array) if no checkpoints exist

### `length(TraceArray storage self) internal view returns (uint256)`

Gets the number of checkpoints.

**Parameters:**
- `self` (TraceArray storage): The trace array to query

**Returns:**
- `uint256`: The number of checkpoints

**Behavior:**
- Returns the total number of checkpoints stored in the trace array

## Internal Functions

### `_insert(CheckpointArray[] storage self, uint256 key, uint256[] memory values) private returns (uint256, uint256)`

Inserts a new checkpoint into the array.

**Parameters:**
- `self` (CheckpointArray[] storage): The checkpoint array
- `key` (uint256): The key for the new checkpoint
- `values` (uint256[]): The values array for the new checkpoint

**Returns:**
- `(uint256, uint256)`: Previous values array length and new values array length

**Behavior:**
- Inserts a new checkpoint at the appropriate position
- Maintains chronological order of checkpoints
- Returns length information for tracking

### `_lowerBinaryLookup(CheckpointArray[] storage self, uint256 key, uint256 low, uint256 high) private view returns (uint256)`

Performs binary search to find the first checkpoint with key >= search key.

**Parameters:**
- `self` (CheckpointArray[] storage): The checkpoint array to search
- `key` (uint256): The search key
- `low` (uint256): Lower bound for search
- `high` (uint256): Upper bound for search

**Returns:**
- `uint256`: Position of the first matching checkpoint

**Behavior:**
- Performs binary search within the specified bounds
- Returns position of first checkpoint with key >= search key
- Returns array length if no matching checkpoint found

### `_upperBinaryLookup(CheckpointArray[] storage self, uint256 key, uint256 low, uint256 high) private view returns (uint256)`

Performs binary search to find the last checkpoint with key <= search key.

**Parameters:**
- `self` (CheckpointArray[] storage): The checkpoint array to search
- `key` (uint256): The search key
- `low` (uint256): Lower bound for search
- `high` (uint256): Upper bound for search

**Returns:**
- `uint256`: Position of the last matching checkpoint

**Behavior:**
- Performs binary search within the specified bounds
- Returns position of last checkpoint with key <= search key
- Returns 0 if no matching checkpoint found

### `_unsafeAccess(CheckpointArray[] storage self, uint256 pos) private pure returns (CheckpointArray storage)`

Safely accesses a checkpoint at a specific position.

**Parameters:**
- `self` (CheckpointArray[] storage): The checkpoint array
- `pos` (uint256): The position to access

**Returns:**
- `CheckpointArray storage`: Reference to the checkpoint at the specified position

**Behavior:**
- Provides safe access to checkpoints without bounds checking
- Used internally by the library functions
- Assumes position is within bounds

## Usage

The ArrayCheckpoints library is primarily used for tracking historical states of arrays:

1. **Delegation Tracking**: Used in VotingEscrow to track delegated token IDs over time
2. **Historical Queries**: Enables efficient lookups of array states at past timestamps
3. **Checkpoint Management**: Provides efficient storage and retrieval of array checkpoints
4. **Binary Search**: Optimized search algorithms for finding relevant checkpoints

## Key Features

### Efficient Storage
- Stores arrays at specific timestamps
- Maintains chronological order
- Optimized for historical lookups

### Binary Search
- Fast lookup algorithms for finding relevant checkpoints
- Supports both lower and upper bound searches
- Optimized for recent checkpoint access

### Memory Safety
- Removed assembly code that could cause issues with dynamic arrays
- Safe access patterns for array operations
- Proper bounds checking where necessary

## Security Considerations

- Never accept checkpoint keys as user input to prevent disabling the library
- Uses safe access patterns for array operations
- Implements proper bounds checking for public functions
- Removed potentially problematic assembly code
- Maintains chronological order of checkpoints

## Integration

The library is used by the VotingEscrow contract for:
- Tracking delegated token IDs over time
- Historical voting power calculations
- Efficient delegation state lookups
- Checkpointed delegation management
