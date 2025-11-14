// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import {Helpers} from "./Helpers.sol";
import {IContinuumDAO} from "../../src/governance/IContinuumDAO.sol";
import {IVotingEscrow} from "../../src/token/IVotingEscrow.sol";
import {GovernorCountingMultiple} from "../../src/governance/GovernorCountingMultiple.sol";
import {CallReceiverMock} from "../helpers/mocks/CallReceiverMock.sol";

contract GovernorHelpers is Helpers {
    uint256 constant YEARS_4 = 4 * 365 * 86_400;
    uint256 constant WEEK_4_YEARS = YEARS_4 / 1 weeks * 1 weeks;
    uint256 currentTs;

    CallReceiverMock receiver;

    GovernorCountingMultiple.VoteTypeSimple AGAINST = GovernorCountingMultiple.VoteTypeSimple.Against;
    GovernorCountingMultiple.VoteTypeSimple FOR = GovernorCountingMultiple.VoteTypeSimple.For;
    GovernorCountingMultiple.VoteTypeSimple ABSTAIN = GovernorCountingMultiple.VoteTypeSimple.Abstain;

    // INFO: Save proposal metadata to storage for quick access
    Operation[] optionsDelta;
    string descriptionDelta;
    uint256 nOptionsDelta;

    struct Operation {
        address target;
        uint256 val;
        bytes data;
    }

    uint256 proposalIdDelta;

    uint256 initiationTs;
    uint256 snapshotTs;
    uint256 completionTs;

    function setUp() public virtual override {
        super.setUp();
        receiver = new CallReceiverMock();
        currentTs = block.timestamp;
    }

    // INFO: create some locks so that all DAO members can vote
    function _create_voting_locks() internal {
        // NOTE: total power should be 20 million veCTM.
        // quorum is 5% (=1 million) of total power in tests, super quorum is 10% (=2 million)
        vm.prank(owner);
        ve.create_lock(18_500_000 ether, YEARS_4);
        vm.prank(proposer);
        ve.create_lock(1_499_976 ether, YEARS_4);
        vm.prank(voter1);
        ve.create_lock(10 ether, YEARS_4);
        vm.prank(voter2);
        ve.create_lock(7 ether, YEARS_4);
        vm.prank(voter3);
        ve.create_lock(5 ether, YEARS_4);
        vm.prank(voter4);
        ve.create_lock(2 ether, YEARS_4);
    }

    // INFO: Builds metadata with either a single operation or multiple operations per option.
    function _buildMetadata(
        uint256 _nOptions,
        uint256 _nWinners,
        uint256 _nOperations
    ) internal pure returns (bytes memory) {
        // the first two 32-bytes chunks in metadata are reserved for nOptions and nWinners.
        // first 32-bytes is number of options; second 32-bytes is number of winners
        // Create bytes memory with exact size: (_nOptions + 2) * 32 bytes
        bytes memory metadata = new bytes((_nOptions + 2) * 32);

        // Write each uint256 directly into the bytes without any array length prefix
        assembly {
            let metadataPtr := add(metadata, 0x20) // Skip length prefix of bytes
            // Write nOptions at offset 0
            mstore(metadataPtr, _nOptions)
            // Write nWinners at offset 32
            mstore(add(metadataPtr, 0x20), _nWinners)

            // Write option indices starting at offset 64
            // option indices always start at calldatas[1] (calldatas[0] is dedicated to metadata)
            let currentOptionIndex := 1 // index of option 0 is always 1
            let offset := 0x40 // Start at 64 bytes (after nOptions and nWinners)
            for { let i := 0 } lt(i, _nOptions) { i := add(i, 1) } {
                mstore(add(metadataPtr, offset), currentOptionIndex)
                offset := add(offset, 0x20) // Move to next 32-byte slot
                currentOptionIndex := add(currentOptionIndex, _nOperations)
            }
        }

        // Result: [nOptions, nWinners, 1, 1+nOperations, 1+2*nOperations, ..., 1+(nOptions-1)*nOperations]
        // Example: (nOptions=4, nWinners=1, nOperations=1) -> [4, 1, 1, 2, 3, 4]
        // Example: (nOptions=2, nWinners=1, nOperations=2) -> [2, 1, 1, 3]
        return metadata;
    }

    // INFO: Generates options for a `GovernorCountingMultiple` proposal.
    // Metadata includes nOptions, nWinners, option indices.
    // Each option can have a defined number of operations eg:
    //  - option A -> {[target1, target2], [value1, value2], [calldata1, calldata2]}
    //  - option B -> {[target1, target3], [value1, value3], [calldata1, calldata3]} etc.
    // `metadata` already contains encoded proposal information such as nOptions, nWinners & indices.
    function _generateOptions(bytes memory _metadata) internal view returns (Operation[] memory) {
        bytes32 nOptionsBytes;
        assembly ("memory-safe") {
            nOptionsBytes := mload(add(_metadata, 0x20)) // skip length prefix
        }

        uint256 nOptions = uint256(nOptionsBytes);

        uint256[] memory optionIndices = new uint256[](nOptions);

        // Read indices in remainder of _metadata
        //   0 = length prefix
        //  32 = nOptions
        //  64 = nWinners
        //  96 = index of option 0
        // 128 = index of option 1
        // ...
        // 96+(n*32) = index of option n
        for (uint256 i = 0; i < nOptions; i++) {
            uint256 offset = 96 + (i * 32);
            bytes32 optionIndexBytes;
            assembly ("memory-safe") {
                optionIndexBytes := mload(add(_metadata, offset))
            }
            optionIndices[i] = uint256(optionIndexBytes);
        }

        // NOTE: all operations length needs to accommodate the highest option index + operations for that option
        // Calculate nOperations from the difference between consecutive option indices
        uint256 nOperations;
        uint256 maxIndex = 0;

        if (nOptions >= 2) {
            // Calculate nOperations from the difference between consecutive option indices
            // Handle non-incrementing indices (test case) by using a default value
            if (optionIndices[1] >= optionIndices[0]) {
                nOperations = optionIndices[1] - optionIndices[0];
            } else {
                // Non-incrementing indices - use a default value
                // This allows the test to proceed and fail at the contract validation level
                nOperations = 1;
            }
            // Find the maximum index to ensure array is large enough
            for (uint256 i = 0; i < nOptions; i++) {
                if (optionIndices[i] > maxIndex) {
                    maxIndex = optionIndices[i];
                }
            }
        } else if (nOptions == 1) {
            // For nOptions == 1, we can't calculate from difference between options
            // Default to 1 operation per option
            nOperations = 1;
            maxIndex = optionIndices[0];
        } else {
            // nOptions == 0: no operations needed, just metadata
            nOperations = 0;
            maxIndex = 0;
        }

        // Array size needs to be at least maxIndex + nOperations to accommodate all operations
        // Add 1 for metadata at index 0
        // For nOptions == 0, we still need at least 2 elements (metadata + one operation) 
        // to match test expectations and allow contract validation to work
        uint256 arraySize;
        if (nOptions == 0) {
            arraySize = 2; // metadata + one dummy operation for contract validation
        } else {
            arraySize = maxIndex > 0 ? maxIndex + nOperations + 1 : (nOptions * nOperations) + 1;
        }
        Operation[] memory allOperations = new Operation[](arraySize);
        allOperations[0] = Operation(address(0), 0, _metadata);

        // Counter to simulate push behavior (starts at 1 since index 0 is metadata)
        uint256 currentIndex = 1;

        // NOTE: Options indices are 1-indexed because metadata occupies calldatas[0].
        for (uint256 i = 1; i <= nOptions; i++) {
            // NOTE: Operations are also 1-indexed for sake of testing (when viewing in logs)
            for (uint256 j = 1; j <= nOperations; j++) {
                uint256 val = 0;
                bytes memory data =
                    abi.encodeWithSelector(CallReceiverMock.mockFunctionWithArgs.selector, i, j);
                allOperations[currentIndex] = Operation(address(receiver), val, data);
                currentIndex++; // Simulate push by incrementing counter
            }
        }

        // When nOptions == 0, add a dummy operation at index 1 to match test expectations
        // This allows the contract to properly validate the metadata
        if (nOptions == 0 && arraySize > 1) {
            allOperations[1] = Operation(address(receiver), 0, abi.encodeWithSelector(CallReceiverMock.mockFunction.selector));
        }

        return allOperations;
    }

    // INFO: Given a number of options and an option to vote for, format the vote weights such that all are zero
    // except for the option to vote for. This will result in all available votes going towards this option.
    function _encodeSingleVote(uint256 _nOptions, uint256 _singleOption) internal pure returns (bytes memory) {
        bytes memory params = new bytes(_nOptions * 32);
        for (uint256 i = 0; i < _nOptions; i++) {
            uint256 weight_i = i == _singleOption ? 100 : 0;
            assembly {
                let paramsPtr := add(params, 0x20) // Skip length prefix
                mstore(add(paramsPtr, mul(i, 0x20)), weight_i)
            }
        }
        return params;
    }

    // INFO: Given a number of options, format the vote weights such that each option is attributed an equal weight.
    // This will result in their total votes being divided between each option.
    function _encodeApprovalVote(uint256 _nOptions) internal pure returns (bytes memory) {
        bytes memory params = new bytes(_nOptions * 32);
        for (uint256 i = 0; i < _nOptions; i++) {
            uint256 weight_i = 100;
            assembly {
                let paramsPtr := add(params, 0x20) // Skip length prefix
                mstore(add(paramsPtr, mul(i, 0x20)), weight_i)
            }
        }
        return params;
    }

    // INFO: Given a number of options and a weighting array, format the vote weights according to the weighting array.
    // This allows the voter to attribute varying proportions of their available votes to different options.
    function _encodeWeightedVote(uint256 _nOptions, uint256[] memory _weights) internal pure returns (bytes memory) {
        bytes memory params = new bytes(_nOptions * 32);
        for (uint256 i = 0; i < _nOptions; i++) {
            uint256 weight_i = _weights[i];
            assembly {
                let paramsPtr := add(params, 0x20) // Skip length prefix
                mstore(add(paramsPtr, mul(i, 0x20)), weight_i)
            }
        }
        return params;
    }

    // INFO: Get proposal configuration for a delta proposal (number of options and number of winners)
    function _getProposalConfiguration(uint256 _proposalId) internal view returns (uint256 nOptions, uint256 nWinners) {
        (nOptions, nWinners) = IContinuumDAO(address(continuumDAO)).proposalConfiguration(_proposalId);
    }

    // INFO: Get proposal votes for each option and the total voting power cast
    function _getProposalVotesDelta(uint256 _proposalId) internal view returns (uint256[] memory optionVotes, uint256 totalVotes) {
        (optionVotes, totalVotes) = continuumDAO.proposalVotesDelta(_proposalId);
    }

    // INFO: Helper to shorten the tests where `propose` is not being tested.
    function _proposeDelta(
        uint256 _nOptions,
        uint256 _nWinners,
        uint256 _nOperations,
        string memory _description
    ) internal {
        bytes memory metadata = _buildMetadata(_nOptions, _nWinners, _nOperations);
        optionsDelta = _generateOptions(metadata);
        proposalIdDelta = _propose(proposer, optionsDelta, _description);
        nOptionsDelta = _nOptions;
        descriptionDelta = _description;
        _waitForSnapshot(proposalIdDelta);
    }

    // INFO: Helper to shorten the tests where `castVote` is not being tested.
    function _castVoteDelta(
        uint256 _supportSingle,
        uint256[] memory _supportWeighted
    ) internal {
        bytes memory paramsSingle = _encodeSingleVote(nOptionsDelta, _supportSingle);
        bytes memory paramsApproval = _encodeApprovalVote(nOptionsDelta);
        bytes memory paramsWeighted = _encodeWeightedVote(nOptionsDelta, _supportWeighted);
        _castVoteWithReasonAndParams(proposalIdDelta, voter1, AGAINST, "", paramsSingle);
        _castVoteWithReasonAndParams(proposalIdDelta, voter2, AGAINST, "", paramsApproval);
        _castVoteWithReasonAndParams(proposalIdDelta, voter3, AGAINST, "", paramsWeighted);
        _waitForDeadline(proposalIdDelta);
    }

    // INFO: Helper to shorted the tests where `execute` is not being tested.
    function _executeDelta() internal {
        _execute(proposer, optionsDelta, descriptionDelta);
    }

    function _propose(
        address _proposer,
        Operation[] memory _operations,
        string memory _description
    ) internal returns (uint256) {
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) = _operationsToArrays(_operations);
        vm.prank(_proposer);
        uint256 _proposalId = continuumDAO.propose(targets, values, calldatas, _description);
        return _proposalId;
    }

    function _execute(
        address _executor,
        Operation[] memory _operations,
        string memory _description
    ) internal returns (uint256) {
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) = _operationsToArrays(_operations);
        vm.prank(_executor);
        return continuumDAO.execute(targets, values, calldatas, keccak256(bytes(_description)));
    }

    // INFO: GovernorStorage utility to execute functions by ID instead of by targets/values/calldatas/descriptionHash
    function _executeById(address _executor, uint256 _proposalId) internal {
        vm.prank(_executor);
        continuumDAO.execute(_proposalId);
    }

    // INFO: Skip the time between proposal creation and snapshot (votingDelay)
    function _waitForSnapshot(uint256 _proposalId) internal {
        uint256 waitTime = continuumDAO.proposalSnapshot(_proposalId);
        currentTs += waitTime;
        vm.warp(waitTime + 1);
    }

    // INFO: Skip the the between proposal snapshot and deadline (votingPeriod)
    function _waitForDeadline(uint256 _proposalId) internal {
        uint256 waitTime = continuumDAO.proposalDeadline(_proposalId);
        currentTs += waitTime;
        vm.warp(waitTime + 1);
    }

    // INFO: Skip time
    function _advanceTime(uint256 _time) internal {
        currentTs += _time;
        skip(_time);
    }

    function _castVote(
        uint256 _proposalId,
        address _voter,
        GovernorCountingMultiple.VoteTypeSimple _support
    ) internal returns (uint256) {
        vm.prank(_voter);
        return continuumDAO.castVote(_proposalId, uint8(_support));
    }

    function _castVoteWithReason(
        uint256 _proposalId,
        address _voter,
        GovernorCountingMultiple.VoteTypeSimple _support,
        string memory _reason
    ) internal returns (uint256) {
        vm.prank(_voter);
        return continuumDAO.castVoteWithReason(_proposalId, uint8(_support), _reason);
    }

    function _castVoteWithReasonAndParams(
        uint256 _proposalId,
        address _voter,
        GovernorCountingMultiple.VoteTypeSimple _support,
        string memory _reason,
        bytes memory _params
    ) internal returns (uint256) {
        vm.prank(_voter);
        return continuumDAO.castVoteWithReasonAndParams(_proposalId, uint8(_support), _reason, _params);
    }

    function _operationsToArrays(
        Operation[] memory _operations
    ) internal pure returns (address[] memory, uint256[] memory, bytes[] memory) {
        address[] memory targets = new address[](_operations.length);
        uint256[] memory values = new uint256[](_operations.length);
        bytes[] memory calldatas = new bytes[](_operations.length);
        for (uint256 i = 0; i < _operations.length; i++) {
            targets[i] = _operations[i].target;
            values[i] = _operations[i].val;
            calldatas[i] = _operations[i].data;
        }
        return (targets, values, calldatas);
    }
}
