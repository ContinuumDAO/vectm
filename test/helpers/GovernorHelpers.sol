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

    struct Operation {
        address target;
        uint256 val;
        bytes data;
    }

    uint256 proposalId;

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
        vm.prank(owner);
        ve.create_lock(10_000 ether, YEARS_4);
        vm.prank(proposer);
        ve.create_lock(10_000 ether, YEARS_4);
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
    function _generateOptions(bytes memory _metadata, address target) internal pure returns (Operation[] memory) {
        uint256 metadataLength = _metadata.length / 32;  // length = 6

        // Decode metadata bytes string into uint256 variables
        uint256[] memory decoded = new uint256[](metadataLength); // [4,1,1,2,3,4]
        assembly {
            let decodedPtr := add(decoded, 0x20) // Skip length prefix of array
            for { let i := 0 } lt(i, metadataLength) { i := add(i, 1) } {
                mstore(add(decodedPtr, mul(i, 0x20)), mload(add(_metadata, mul(i, 0x20))))
            }
        }

        // Assign variables from decoded array
        uint256 nOptions = decoded[0];
        uint256 nOperations = decoded[2] - decoded[3];

        Operation[] memory options = new Operation[](nOptions);
        options[0] = Operation(address(0), 0, _metadata);

        // NOTE: Options indices are 1-indexed because metadata occupies calldatas[0].
        for (uint256 i = 1; i < nOptions + 1; i++) {
            // NOTE: Operations are also 1-indexed for sake of testing (when viewing in logs)
            for (uint256 j = 1; j <= nOperations; j++) {
                uint256 val = 0;
                bytes memory data =
                    abi.encodeWithSelector(CallReceiverMock.mockFunctionWithArgs.selector, i, j);
                options[i + 1] = Operation(target, val, data);
            }
        }

        return options;
    }

    // INFO: Given a number of options and an option to vote for, format the vote weights such that all are zero
    // except for the option to vote for. This will result in all available votes going towards this option.
    function _encodeSingleVote(uint256 _nOptions, uint256 _singleOption) internal pure returns (bytes memory) {
        bytes memory params;
        for (uint256 i = 0; i < _nOptions; i++) {
            params = abi.encode(params, i == _singleOption ? 100 : 0);
        }
        return params;
    }

    // INFO: Given a number of options, format the vote weights such that each option is attributed an equal weight.
    // This will result in their total votes being divided between each option.
    function _encodeApprovalVote(uint256 _nOptions) internal pure returns (bytes memory) {
        bytes memory params;
        for (uint256 i = 0; i < _nOptions; i++) {
            params = abi.encode(params, 100);
        }
        return params;
    }

    // INFO: Given a number of options and a weighting array, format the vote weights according to the weighting array.
    // This allows the voter to attribute varying proportions of their available votes to different options.
    function _encodeWeightedVote(uint256 _nOptions, uint256[] memory _weights) internal pure returns (bytes memory) {
        bytes memory params;
        for (uint256 i = 0; i < _nOptions; i++) {
            params = abi.encode(params, _weights[i]);
        }
        return params;
    }

    function _getProposalConfiguration() internal view returns (uint256, uint256) {
        (uint256 nOptions, uint256 nWinners) = IContinuumDAO(address(continuumDAO)).proposalConfiguration(proposalId);
        return (nOptions, nWinners);
    }

    // INFO: Helper to shorten the tests where `propose` is not being tested.
    function _proposeDelta(
        address _proposer,
        uint256 _nOptions,
        uint256 _nWinners,
        uint256 _nOperations,
        address _target
    ) internal {
        bytes memory metadata = _buildMetadata(_nOptions, _nWinners, _nOperations);
        Operation[] memory options = _generateOptions(metadata, _target);
        vm.prank(_proposer);
        _propose(options, "<proposal description>");
        _waitForSnapshot();
    }

    // INFO: Helper to shorten the tests where `castVote` is not being tested.
    function _castVoteDelta(
        uint256 _nOptions,
        uint256 _supportSingle,
        uint256[] memory _supportWeighted
    ) internal {
        bytes memory paramsSingle = _encodeSingleVote(_nOptions, _supportSingle);
        bytes memory paramsApproval = _encodeApprovalVote(_nOptions);
        bytes memory paramsWeighted = _encodeWeightedVote(_nOptions, _supportWeighted);
        _castVoteWithReasonAndParams(voter1, AGAINST, "", paramsSingle);
        _castVoteWithReasonAndParams(voter2, AGAINST, "", paramsApproval);
        _castVoteWithReasonAndParams(voter3, AGAINST, "", paramsWeighted);
        _waitForDeadline();
    }

    function _propose(Operation[] memory _options, string memory _description) internal {
        address[] memory targets = new address[](_options.length);
        uint256[] memory values = new uint256[](_options.length);
        bytes[] memory calldatas = new bytes[](_options.length);
        for (uint256 i = 0; i < _options.length; i++) {
            targets[i] = _options[i].target;
            values[i] = _options[i].val;
            calldatas[i] = _options[i].data;
        }
        proposalId = continuumDAO.propose(targets, values, calldatas, _description);
        initiationTs = block.timestamp;
        snapshotTs = initiationTs + continuumDAO.votingDelay();
        completionTs = snapshotTs + continuumDAO.votingPeriod();
    }

    function _execute(Operation[] memory _options, string memory _description) internal {
        address[] memory targets = new address[](_options.length);
        uint256[] memory values = new uint256[](_options.length);
        bytes[] memory calldatas = new bytes[](_options.length);
        for (uint256 i = 0; i < _options.length; i++) {
            targets[i] = _options[i].target;
            values[i] = _options[i].val;
            calldatas[i] = _options[i].data;
        }
        proposalId = continuumDAO.execute(targets, values, calldatas, keccak256(bytes(_description)));
    }

    function _waitForSnapshot() internal {
        // uint256 _t = continuumDAO.votingDelay() + 1;
        // skip(_t);
        // currentTs += _t;
        vm.warp(continuumDAO.proposalSnapshot(proposalId) + 1);
    }

    function _waitForDeadline() internal {
        // uint256 _t = continuumDAO.votingPeriod() + 10;
        // skip(_t);
        // currentTs += _t;
        vm.warp(continuumDAO.proposalDeadline(proposalId) + 1);
    }

    function _advanceTime(uint256 _time) internal {
        currentTs += _time;
        skip(_time);
    }

    function _castVote(
        address _voter,
        GovernorCountingMultiple.VoteTypeSimple _support
    ) internal returns (uint256) {
        vm.prank(_voter);
        return continuumDAO.castVote(proposalId, uint8(_support));
    }

    function _castVoteWithReason(
        address _voter,
        GovernorCountingMultiple.VoteTypeSimple _support,
        string memory _reason
    ) internal returns (uint256) {
        vm.prank(_voter);
        return continuumDAO.castVoteWithReason(proposalId, uint8(_support), _reason);
    }

    function _castVoteWithReasonAndParams(
        address _voter,
        GovernorCountingMultiple.VoteTypeSimple _support,
        string memory _reason,
        bytes memory _params
    ) internal returns (uint256) {
        vm.prank(_voter);
        return continuumDAO.castVoteWithReasonAndParams(proposalId, uint8(_support), _reason, _params);
    }
}
