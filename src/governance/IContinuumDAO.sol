// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import {Governor} from "./oz/Governor.sol";
import {GovernorCountingMultiple} from "./GovernorCountingMultiple.sol";
import {IERC5805} from "@openzeppelin/contracts/interfaces/IERC5805.sol";

interface IContinuumDAO {
    /*
       ==============================
       ========== Governor ==========
       ==============================
    */

    function BALLOT_TYPEHASH() external view returns (bytes32);
    function EXTENDED_BALLOT_TYPEHASH() external view returns (bytes32);
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
    function name() external view returns (string memory);
    function version() external view returns (string memory);
    function hashProposal(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external pure returns (uint256);
    function getProposalId(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external view returns (uint256);

    // Overiden by GovernorSuperQuorum and GovernorVotesSuperQuorumFraction
    // function state(uint256 proposalId) external view returns (Governor.ProposalState);

    // Overiden by GovernorSettings
    // function proposalThreshold() external view returns (uint256);

    function proposalSnapshot(uint256 proposalId) external view returns (uint256);

    // Overiden by GovernorPreventLateQuorum
    // function proposalDeadline(uint256 proposalId) external view returns (uint256);

    function proposalProposer(uint256 proposalId) external view returns (address);
    function proposalEta(uint256 proposalId) external view returns (uint256);
    function proposalNeedsQueuing(uint256) external view returns (bool);

    // Overidden by GovernorCountingMultiple
    // function propose(
    //     address[] memory targets,
    //     uint256[] memory values,
    //     bytes[] memory calldatas,
    //     string memory description
    // ) external returns (uint256);

    // Overidden by GovernorCountingMultiple and GovernorStorage
    // function queue(
    //     address[] memory targets,
    //     uint256[] memory values,
    //     bytes[] memory calldatas,
    //     bytes32 descriptionHash
    // ) external returns (uint256);

    // Overidden by GovernorCountingMultiple and GovernorStorage
    // function execute(
    //     address[] memory targets,
    //     uint256[] memory values,
    //     bytes[] memory calldatas,
    //     bytes32 descriptionHash
    // ) external payable returns (uint256);

    function cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external returns (uint256);
    function getVotes(address account, uint256 timepoint) external view returns (uint256);
    function getVotesWithParams(address account, uint256 timepoint, bytes memory params) external view returns (uint256);
    function castVote(uint256 proposalId, uint8 support) external returns (uint256);
    function castVoteWithReason(uint256 proposalId, uint8 support, string calldata reason) external returns (uint256);
    function castVoteWithReasonAndParams(
        uint256 proposalId,
        uint8 support,
        string calldata reason,
        bytes memory params
    ) external returns (uint256);
    function castVoteBySig(uint256 proposalId, uint8 support, address voter, bytes memory signature)
        external
        returns (uint256);
    function castVoteWithReasonAndParamsBySig(
        uint256 proposalId,
        uint8 support,
        address voter,
        string calldata reason,
        bytes memory params,
        bytes memory signature
    ) external returns (uint256);
    function relay(address target, uint256 value, bytes calldata data) external payable;
    function onERC721Received(address, address, uint256, bytes memory) external returns (bytes4);
    function onERC1155Received(address, address, uint256, uint256, bytes memory) external returns (bytes4);
    function onERC1155BatchReceived(address, address, uint256[] memory, uint256[] memory, bytes memory)
        external
        returns (bytes4);
    // function _encodeStateBitmap;
    // function _validateStateBitmap;
    // function _isValidDescriptionForProposer;

    // Overidden by GovernorProposalGuardian
    // function _validateCancel;

    // function _unsafeReadBytesOffset;
    // function _setProposalExecuted;
    // function _governanceCallPushBack;
    // function _governanceCallClear;
    // function _setProposalEtaSeconds;
    // function _governanceCallEmpty;
    // function ALL_PROPOSAL_STATES_BITMAP;
    // function _name;
    // function _proposals;
    // function _governanceCall;
    // function _executor;
    // function _validateVoteSig;
    // function _validateExtendedVoteSig;
    // function _castVote;
    // function _castVote;
    // function _cancel;
    // function _executeOperations;
    // function _queueOperations;

    // Overidden by GovernorStorage
    // function _propose;

    // function _checkGovernance;

    // Overidden by GovernorPreventLateQuorum
    // function _tallyUpdated; // does nothing by default

    // function _defaultParams;

    // Implemented by GovernorCountingMultiple
    // function _quorumReached;

    // Implemented by GovernorCountingMultiple
    // function _voteSucceeded;

    // Implemented by GovernorVotes
    // function _getVotes;

    // Implemented by GovernorCountingMultiple
    // function _countVote;

    // Implemented by GovernorVotes
    // function clock() external view returns (uint48);

    // Implemented by GovernorVotes
    // function CLOCK_MODE() external view returns (string memory);

    // Implemented by GovernorSettings
    // function votingDelay() external view returns (uint256);

    // Implemented by GovernorSettings
    // function votingPeriod() external view returns (uint256);

    // Implemented by GovernorVotesQuorumFraction
    // function quorum(uint256 timepoint) external view returns (uint256);

    /*
       ==============================================
       ========== GovernorCountingMultiple ==========
       ==============================================
    */

    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) external returns (uint256);
    function execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external payable returns (uint256);
    function queue(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external returns (uint256);
    function hasVoted(uint256 proposalId, address account) external view returns (bool);
    function proposalVotesDelta(uint256 proposalId) external view returns (uint256[] memory, uint256);
    function COUNTING_MODE() external pure returns (string memory);
    function proposalConfiguration(uint256 proposalId)
        external
        view
        returns (uint256, uint256);
    // function _proposalVotes;
    // function _proposalConfig;
    // function _countVote;
    // function _quorumReached;
    // function _voteSucceeded;
    // function _getProposalVotes;
    // function _validateProposalDimensions;
    // function _validateProposalConfiguration;
    // function _extractMetadata;
    // function _getWinningIndices;
    // function _buildOperations;
    // function _countOperations;

    /*
       ======================================
       ========== GovernorSettings ==========
       ======================================
    */

    function votingDelay() external view returns (uint256);
    function votingPeriod() external view returns (uint256);
    function proposalThreshold() external view returns (uint256);
    function setVotingDelay(uint48 newVotingDelay) external;
    function setVotingPeriod(uint32 newVotingPeriod) external;
    function setProposalThreshold(uint256 newProposalThreshold) external;
    // function _proposalThreshold;
    // function _votingDelay;
    // function _votingPeriod;
    // function _setVotingDelay;
    // function _setVotingPeriod;
    // function _setProposalThreshold;

    /*
       ======================================================
       ========== GovernorVotesSuperQuorumFraction ==========
       ======================================================
    */

    function superQuorumNumerator() external view returns (uint256);
    function superQuorumNumerator(uint256 timepoint) external view returns (uint256);
    function superQuorum(uint256 timepoint) external view returns (uint256);
    function updateSuperQuorumNumerator(uint256 newSuperQuorumNumerator) external;
    function state(uint256 proposalId) external view returns (Governor.ProposalState);
    // function _updateSuperQuorumNumerator;
    // function _updateQuorumNumerator;

    /*
       =================================================
       ========== GovernorVotesQuorumFraction ==========
       =================================================
    */

    function quorumNumerator() external view returns (uint256);
    function quorumNumerator(uint256 timepoint) external view returns (uint256);
    function quorumDenominator() external view returns (uint256);
    function quorum(uint256 timepoint) external view returns (uint256);
    function updateQuorumNumerator(uint256 newQuorumNumerator) external;
    // function _quorumNumeratorHistory;

    // Overidden by GovernorVotesSuperQuorumFraction
    // function _updateQuorumNumerator;

    // function _optimisticUpperLookupRecent;

    /*
       ===================================
       ========== GovernorVotes ==========
       ===================================
    */

    function token() external view returns (IERC5805);
    function clock() external view returns (uint48);
    function CLOCK_MODE() external view returns (string memory);
    // function _token;
    // function _getVotes;

    /*
       =========================================
       ========== GovernorSuperQuorum ==========
       =========================================
    */

    // Overidden by GovernorVotesSuperQuorumFraction
    // function superQuorum(uint256 timepoint) external view returns (uint256);

    function proposalVotes(uint256 proposalId) external view returns (uint256, uint256, uint256);

    // Overidden by GovernorVotesSuperQuorumFraction
    // function state(uint256 proposalId) external view returns (Governor.ProposalState);

    /*
       ===============================================
       ========== GovernorPreventLateQuorum ==========
       ===============================================
    */

    function proposalDeadline(uint256 proposalId) external view returns (uint256);
    function lateQuorumVoteExtension() external view returns (uint48);
    function setLateQuorumVoteExtension(uint48 newVoteExtension) external;
    // function _voteExtension;
    // function _extendedDeadlines;
    // function _tallyUpdated; // does something
    // function _setLateQuorumVoteExtension(uint48 newVoteExtension) internal;

    /*
       ==============================================
       ========== GovernorProposalGuardian ==========
       ==============================================
    */

    function proposalGuardian() external view returns (address);
    function setProposalGuardian(address newProposalGuardian) external;
    // function _proposalGuardian;
    // function _setProposalGuardian;
    // function _validateCancel;

    /*
       =====================================
       ========== GovernorStorage ==========
       =====================================
    */

    // function _proposalIds;
    // function _proposalDetails;
    // function _propose(
    //     address[] memory targets,
    //     uint256[] memory values,
    //     bytes[] memory calldatas,
    //     string memory description,
    //     address proposer
    // ) internal returns (uint256);

    // Overidden by GovernorCountingMultiple
    // function queue(uint256 proposalId) external;

    // Overidden by GovernorCountingMultiple
    // function execute(uint256 proposalId) external payable;

    function cancel(uint256 proposalId) external;
    function proposalCount() external view returns (uint256);
    function proposalDetails(uint256 proposalId)
        external
        view
        returns (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash);
    function proposalDetailsAt(uint256 index)
        external
        view
        returns (
            uint256 proposalId,
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            bytes32 descriptionHash
        );
}
