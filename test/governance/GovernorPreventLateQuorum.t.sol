// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import {console} from "forge-std/console.sol";

import {ContinuumDAO} from "../../src/governance/ContinuumDAO.sol";
import {GovernorCountingMultiple} from "../../src/governance/GovernorCountingMultiple.sol";

import {IVotingEscrow} from "../../src/token/VotingEscrow.sol";
import {Helpers} from "../helpers/Helpers.sol";

contract TestGovernorPreventLateQuorum is Helpers {
    uint256 constant LOCK_TS_4_YEARS = 4 * 365 * 1 days / 1 weeks * 1 weeks;

    uint256 tokenId;
    uint256 proposalId;

    address[] targets;
    uint256[] values;
    bytes[] calldatas;
    string description;

    function setUp() public override {
        super.setUp();
        vm.prank(user1);
        ve.create_lock(10_000 ether, LOCK_TS_4_YEARS);
        skip(2 * 1 weeks);
    }

    function _setProposalDataChangeURI() private {
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);
        targets[0] = address(ve);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSelector(IVotingEscrow.setBaseURI.selector, "new.base.uri");
        description = "On-chain #1: Set base URI to new.base.uri";
    }

    function test_LateQuorum() public {
        vm.startPrank(user1);
        _setProposalDataChangeURI();
        proposalId = continuumDAO.propose(targets, values, calldatas, description);
        uint256 votingDelay = continuumDAO.votingDelay();
        uint256 votingDuration = continuumDAO.votingPeriod();
        skip(votingDelay - 1);
    }
}
