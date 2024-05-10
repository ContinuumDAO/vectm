// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import {CTMDAOGovernor} from "../src/CTMDAOGovernor.sol";
import {IVotingEscrow, VotingEscrow} from "../src/VotingEscrow.sol";
import {VotingEscrowProxy} from "../src/VotingEscrowProxy.sol";
import {VotingEscrowV2} from "../src/VotingEscrowV2.sol";
import {TestERC20} from "../src/TestERC20.sol";
import {NodeProperties} from "../src/NodeProperties.sol";
// import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

interface IVotingEscrowUpgradable is IVotingEscrow {
    function upgradeToAndCall(address newImplementation, bytes memory data) external;
}

contract SetUp is Test {
    CTMDAOGovernor governor;
    TestERC20 ctm;
    VotingEscrow veImplV1;
    VotingEscrowProxy veProxy;
    IVotingEscrowUpgradable ve;
    NodeProperties nodeProperties;
    string constant BASE_URI_V1 = "veCTM V1";
    address gov;
    address committee;
    address user;
    address user2;
    uint256 CTM_TS = 100_000_000 ether;
    uint256 initialBalGov = CTM_TS;
    uint256 initialBalUser = CTM_TS;
    uint256 constant MAXTIME = 4 * 365 * 86400;
    uint256 constant ONE_YEAR = 365 * 86400;
    uint256 constant WEEK = 1 weeks;

    enum VoteType {
        Against,
        For,
        Abstain
    }

    function setUp() public virtual {
        committee = makeAddr("committee");
        user = makeAddr("user");
        user2 = makeAddr("user2");

        ctm = new TestERC20("Continuum", "CTM", 18);
        veImplV1 = new VotingEscrow();
        bytes memory initializerData = abi.encodeWithSignature(
            "initialize(address,string)",
            address(ctm),
            BASE_URI_V1
        );
        veProxy = new VotingEscrowProxy(address(veImplV1), initializerData);

        governor = new CTMDAOGovernor(address(veProxy));
        gov = address(governor);

        ve = IVotingEscrowUpgradable(address(veProxy));
        ctm.print(user, initialBalUser);
        vm.prank(user);
        ctm.approve(address(ve), initialBalUser);
        
        nodeProperties = new NodeProperties(gov, address(ve));

        ve.setUp(gov, address(nodeProperties), address(0), address(0));
    }

    modifier prank(address _user) {
        vm.startPrank(_user);
        _;
        vm.stopPrank();
    }
}

contract GovernorBasic is SetUp {
    uint256 tokenId;

    // proposal details
    uint256 proposalId;
    address[] targets;
    uint256[] values;
    bytes[] calldatas;
    bytes32 descriptionHash;

    // UTILS
    
    function setUp() public override {
        super.setUp();
        vm.prank(user);
        uint256 WEEK_4_YEARS = _weekTsInXYears(4);
        ve.create_lock(1 ether, WEEK_4_YEARS);
        skip(2 * WEEK);
    }

    function _weekTsInXYears(uint256 _years) internal pure returns (uint256) {
        return (_years * ONE_YEAR) / WEEK * WEEK;
    }

    function _proposeVote(
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        string memory description
    ) internal returns (uint256) {
        return governor.propose(_targets, _values, _calldatas, description);
    }

    function _castVote(uint256 _proposalId, uint8 support) internal returns (uint256) {
        skip(5 days + 1);
        // skip(5 minutes + 1);
        uint256 weight = governor.castVote(_proposalId, support);
        return weight;
    }

    function _queueVote(
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        string memory description
    ) internal returns (uint256) {
        // skip(12 hours + 1);
        uint256 _proposalId = governor.queue(_targets, _values, _calldatas, keccak256(bytes(description)));
        return _proposalId;
    }

    function _executeVote(
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        string memory description
    ) internal returns (uint256) {
        skip(10 days + 1);
        uint256 _proposalId = governor.execute(_targets, _values, _calldatas, keccak256(bytes(description)));
        return _proposalId;
    }

    function test_InitialSettings() public prank(user) {
        skip(1);
        uint256 totalPower = ve.getPastTotalSupply(block.timestamp - 1);
        uint256 votingDelay = governor.votingDelay();
        uint256 votingPeriod = governor.votingPeriod();
        uint256 proposalThreshold = governor.proposalThreshold();
        uint256 quorum = governor.quorumNumerator(block.timestamp);
        assertEq(votingDelay, 5 days);
        assertEq(votingPeriod, 10 days);
        assertEq(proposalThreshold, totalPower / 100);
        assertEq(quorum, 20); // 20%
    }

    function test_VoteCallContractFunction() public prank(user) {
        address[] memory _targets = new address[](2);
        _targets[0] = address(ve);
        _targets[1] = address(ve);
        uint256[] memory _values = new uint256[](2);
        bytes[] memory _calldatas = new bytes[](2);
        _calldatas[0] = abi.encodeWithSignature(
            "setup(address,address,address,address)",
            gov,
            address(nodeProperties),
            address(0),
            user2
        );
        _calldatas[1] = abi.encodeWithSignature("enableLiquidations()");
        string memory _description = "Proposal #1: Setup addresses in veCTM.";

        _proposeVote(_targets, _values, _calldatas, _description);

        (proposalId, targets, values, calldatas, descriptionHash) = governor.proposalDetailsAt(0);

        _castVote(proposalId, uint8(VoteType.For));

        _executeVote(_targets, _values, _calldatas, _description);

        address nodePropertiesSet = ve.nodeProperties();
        bool liquidationsEnabled = ve.liquidationsEnabled();
        address treasury = ve.treasury();

        assertEq(nodePropertiesSet, address(nodeProperties));
        assertEq(liquidationsEnabled, true);
        assertEq(treasury, user2);
    }

    function test_ProposalThresholdChanges() public prank(user) {
        uint256 totalVotePowerBefore = ve.getPastTotalSupply(block.timestamp - 1);
        uint256 thresholdBefore = governor.proposalThreshold();
        uint256 WEEK_4_YEARS = _weekTsInXYears(4);
        console.log(totalVotePowerBefore);
        ve.create_lock(1 ether, WEEK_4_YEARS);
        skip(4 weeks);
        ve.checkpoint();
        skip(4 weeks);
        uint256 totalVotePowerAfter = ve.getPastTotalSupply(block.timestamp - 1);
        uint256 thresholdAfter = governor.proposalThreshold();
        assertEq(thresholdBefore, totalVotePowerBefore / 100);
        assertEq(thresholdAfter, totalVotePowerAfter / 100);
    }

    function test_VoteTransferETH() public prank(user) {
        vm.deal(gov, 2000 ether);

        address[] memory _targets = new address[](1);
        _targets[0] = user2;
        uint256[] memory _values = new uint256[](1);
        _values[0] = 10 ether;
        bytes[] memory _calldatas = new bytes[](1);
        string memory _description = "Proposal #2: Transfer 10 ether to user2.";

        uint256 bal2Before = user2.balance;
        uint256 balGovBefore = gov.balance;

        _proposeVote(_targets, _values, _calldatas, _description);
        (proposalId, targets, values, calldatas, descriptionHash) = governor.proposalDetailsAt(0);
        _castVote(proposalId, uint8(VoteType.For));
        _executeVote(_targets, _values, _calldatas, _description);

        uint256 bal2After = user2.balance;
        uint256 balGovAfter = gov.balance;

        assertEq(bal2After, bal2Before + 10 ether);
        assertEq(balGovAfter, balGovBefore - 10 ether);
    }
}