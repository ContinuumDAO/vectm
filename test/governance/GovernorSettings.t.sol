// SPDX-License-Identifier: UNLICENSED

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

    function test_Settings_Defaults() public view {
        uint256 votingPeriod = continuumDAO.votingPeriod();
        uint256 votingDelay = continuumDAO.votingDelay();
        uint256 proposalThresholdNumerator = continuumDAO.proposalThresholdNumerator();
        uint256 proposalThresholdDenominator = continuumDAO.proposalThresholdDenominator();
        uint256 proposalThreshold = continuumDAO.proposalThreshold();
        assertEq(votingDelay, 5 days);
        assertEq(votingPeriod, 10 days);
        assertEq(proposalThresholdNumerator, 100);
        assertEq(proposalThresholdDenominator, 100_000);
        assertApproxEqRel(proposalThreshold, ve.totalPower() / 1000, 0.01 ether); // 0.1% of total power
    }

    function test_Settings_UpdateProposalThreshold() public {
        uint256 initialProposalThreshold = continuumDAO.proposalThreshold();

        vm.startPrank(address(continuumDAO));
        // Lower numerator first so denominator can be reduced without reverting
        continuumDAO.updateProposalThresholdNumerator(1);
        continuumDAO.updateProposalThresholdDenominator(100);
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

    function test_Settings_ProposalThresholdDenominatorZeroReverts() public {
        uint256 numerator = continuumDAO.proposalThresholdNumerator();
        vm.startPrank(address(continuumDAO));
        vm.expectRevert(
            abi.encodeWithSelector(ContinuumDAO.GovernorInvalidProposalThreshold.selector, numerator, uint256(0))
        );
        continuumDAO.updateProposalThresholdDenominator(0);
        vm.stopPrank();
    }

    function test_Settings_ProposalThresholdDenominatorBelowNumeratorReverts() public {
        uint256 numerator = continuumDAO.proposalThresholdNumerator();
        uint256 tooSmall = numerator - 1;
        vm.startPrank(address(continuumDAO));
        vm.expectRevert(
            abi.encodeWithSelector(ContinuumDAO.GovernorInvalidProposalThreshold.selector, numerator, tooSmall)
        );
        continuumDAO.updateProposalThresholdDenominator(tooSmall);
        vm.stopPrank();
    }
}
