// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import {console} from "forge-std/console.sol";
import {GovernorHelpers} from "../helpers/GovernorHelpers.sol";
import {ContinuumDAO} from "../../src/governance/ContinuumDAO.sol";

contract TestGovernorSettings is GovernorHelpers {
    function setUp() public override {
        super.setUp();
        _create_voting_locks();
        _advanceTime(1 weeks);
    }

    function test_Settings_Defaults() public {
        uint256 votingPeriod = continuumDAO.votingPeriod();
        uint256 votingDelay = continuumDAO.votingDelay();
        uint256 proposalThresholdNumerator = continuumDAO.proposalThresholdNumerator();
        uint256 proposalThresholdDenominator = continuumDAO.proposalThresholdDenominator();
        uint256 proposalThreshold = continuumDAO.proposalThreshold();
        assertEq(votingDelay, 5 days);
        assertEq(votingPeriod, 10 days);
        assertEq(proposalThresholdNumerator, 1000);
        assertEq(proposalThresholdDenominator, 100_000);
        assertApproxEqRel(proposalThreshold, ve.totalPower() / 100, 0.01 ether); // 1% wiggle room
    }

    function test_Settings_UpdateProposalThreshold() public {
        uint256 initialProposalThreshold = continuumDAO.proposalThreshold();

        vm.startPrank(address(continuumDAO));
        continuumDAO.updateProposalThresholdDenominator(100);
        continuumDAO.updateProposalThresholdNumerator(1);
        vm.stopPrank();

        uint256 updatedProposalThreshold = continuumDAO.proposalThreshold();
        console.log(updatedProposalThreshold);
        console.log(initialProposalThreshold);
    }

    function test_Settings_ProposalThresholdNumeratorAboveDenominator() public {
        uint256 proposalThresholdDenominator = continuumDAO.proposalThresholdDenominator();
        uint256 invalidDenominator = 100_001;
        vm.startPrank(address(continuumDAO));
        vm.expectRevert(
            abi.encodeWithSelector(
                ContinuumDAO.GovernorInvalidProposalThreshold.selector, invalidDenominator, proposalThresholdDenominator
            )
        );
        continuumDAO.updateProposalThresholdNumerator(invalidDenominator);
    }
}
