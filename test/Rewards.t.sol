// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import {Rewards} from "../src/Rewards.sol";
import {NodeProperties} from "../src/NodeProperties.sol";
import {VotingEscrowProxy} from "../src/VotingEscrowProxy.sol";
import {IVotingEscrow, VotingEscrow} from "../src/VotingEscrow.sol";
import {CTM} from "../src/CTM.sol";
import {TestERC20} from "../src/TestERC20.sol";

contract TestRewards is Test {
    CTM ctm;
    TestERC20 usdc;
    VotingEscrow veImpl;
    VotingEscrowProxy veProxy;
    IVotingEscrow ve;
    NodeProperties nodeProperties;
    Rewards rewards;
    string constant MNEMONIC = "test test test test test test test test test test test junk";
    string constant BASE_URI_V1 = "veCTM V1";
    address gov;
    address committee;
    address treasury;
    address user;
    address bridge;
    uint256 CTM_TS = 100_000_000 ether;
    uint256 USDC_TS = 100_000_000e6;
    uint256 initialBalGov = CTM_TS;
    uint256 initialBalUser = CTM_TS;
    uint256 constant MAXTIME = 4 * 365 * 86400;
    uint256 constant ONE_YEAR = 365 * 86400;
    uint256 constant WEEK = 1 weeks;
    uint256 id1;
    uint256 id2;
    uint8 constant DEFAULT = uint8(NodeProperties.NodeValidationStatus.Default);
    uint8 constant PENDING = uint8(NodeProperties.NodeValidationStatus.Pending);
    uint8 constant APPROVED = uint8(NodeProperties.NodeValidationStatus.Approved);

    function setUp() public virtual {
        uint256 privKey0 = vm.deriveKey(MNEMONIC, 0);
        gov = vm.addr(privKey0);
        uint256 privKey1 = vm.deriveKey(MNEMONIC, 1);
        committee = vm.addr(privKey1);
        uint256 privKey2 = vm.deriveKey(MNEMONIC, 2);
        treasury = vm.addr(privKey2);
        uint256 privKey3 = vm.deriveKey(MNEMONIC, 3);
        user = vm.addr(privKey3);
        uint256 privKey4 = vm.deriveKey(MNEMONIC, 4);
        bridge = vm.addr(privKey4);

        ctm = new CTM(gov);
        usdc = new TestERC20(6);
        veImpl = new VotingEscrow();
        bytes memory initializerData = abi.encodeWithSignature(
            "initialize(address,string)",
            address(ctm),
            BASE_URI_V1
        );
        veProxy = new VotingEscrowProxy(address(veImpl), initializerData);

        ve = IVotingEscrow(address(veProxy));
        ve.setGovernor(gov);
        ctm.print(user, CTM_TS);
        ctm.print(bridge, CTM_TS);
        usdc.print(bridge, USDC_TS);
        
        nodeProperties = new NodeProperties(gov, committee, address(ve), 5000 ether);

        vm.startPrank(gov);
        ve.setTreasury(treasury);
        ve.setNodeProperties(address(nodeProperties));
        ve.enableLiquidations();

        rewards = new Rewards(
            0,
            gov,
            address(ctm),
            address(usdc),
            address(0),
            address(ve),
            address(nodeProperties),
            address(0)
        );

        rewards.setBaseEmissionRate(1 ether / 2000);
        rewards.setNodeEmissionRate(1 ether / 1000);
        rewards.setNodeRewardThreshold(5000 ether);
        vm.stopPrank();

        vm.startPrank(bridge);
        ctm.approve(address(ve), CTM_TS);
        ctm.approve(address(rewards), CTM_TS);
        usdc.approve(address(rewards), USDC_TS);
        vm.stopPrank();

        vm.prank(user);
        ctm.approve(address(ve), CTM_TS);
    }

    modifier prank(address _user) {
        vm.startPrank(_user);
        _;
        vm.stopPrank();
    }

    // utils
    function _receive(address _token, uint256 _amount) internal prank(bridge) {
        rewards.receiveFees(_token, _amount, 1);
    }

    function _attachTokenId(uint256 _tokenId, uint256 _nodeId) internal prank(gov) {
        nodeProperties.attachNode(_tokenId, _nodeId);
    }

    function _setQualityOf(uint256 _tokenId, uint256 _quality) internal prank(gov) {
        nodeProperties.setNodeQualityOf(_tokenId, _quality);
    }

    function test_SetRewardsTooHigh() public prank(gov) {
        vm.expectRevert("Cannot set base rewards per vepower-day higher than 1%.");
        rewards.setBaseEmissionRate(1 ether / uint256(99));
        vm.expectRevert("Cannot set node rewards per vepower-day higher than 1%.");
        rewards.setNodeEmissionRate(1 ether / uint256(99));
    }

    function test_RewardBaseEmissions() public {
        _setQualityOf(1, 0);
        _receive(address(ctm), 10000 ether);
        vm.prank(user);
        uint256 tokenId = ve.create_lock(10000 ether, MAXTIME);
        uint256 unclaimed = rewards.unclaimedRewards(tokenId);
        skip(1 days);
        unclaimed = rewards.unclaimedRewards(tokenId);
        assertEq(unclaimed/1e18, 4); // 1 day => 4.9 CTM = 0.05%
        skip(9 days);
        unclaimed = rewards.unclaimedRewards(tokenId);
        assertEq(unclaimed/1e18, 49); // 10 days => 49.67 CTM = 0.5%
        skip(355 days);
        unclaimed = rewards.unclaimedRewards(tokenId);
        assertEq(unclaimed/1e18, 1591); // 365 days => 1591 CTM = 15.9%
    }

    function test_RewardNodeEmissions() public {
        _receive(address(ctm), 10000 ether);
        vm.prank(user);
        uint256 tokenId = ve.create_lock(10000 ether, MAXTIME);
        _attachTokenId(tokenId, 1);
        _setQualityOf(tokenId, 10);
        uint256 unclaimed = rewards.unclaimedRewards(tokenId);
        skip(1 days);
        unclaimed = rewards.unclaimedRewards(tokenId);
        assertEq(unclaimed/1e18, 14); // 1 day => 14.95 CTM = 0.15%
        skip(9 days);
        unclaimed = rewards.unclaimedRewards(tokenId);
        assertEq(unclaimed/1e18, 149); // 10 days => 149 CTM = 1.5%
        skip(355 days);
        unclaimed = rewards.unclaimedRewards(tokenId);
        assertEq(unclaimed/1e18, 4773); // 365 days => 4774 CTM = 48%
    }

    function test_FuzzClaimBaseRewards(uint256 _lockAmount, uint256 _claimDays) public {
        _lockAmount = bound(_lockAmount, 1, CTM_TS);
        _claimDays = bound(_claimDays, 1, 3650);
        uint256 _claimTime = _claimDays * 1 days;
        _receive(address(ctm), CTM_TS);
        vm.startPrank(user);
        uint256 tokenId = ve.create_lock(_lockAmount, MAXTIME);
        skip(_claimTime);
        rewards.claimRewards(tokenId, user);
        vm.stopPrank();
    }

    function test_FuzzClaimNodeRewards(uint256 _lockAmount, uint256 _claimDays, uint256 _quality) public {
        vm.startPrank(gov);
        rewards.setBaseEmissionRate(1 ether / 200000);
        rewards.setNodeEmissionRate(1 ether / 100000);
        vm.stopPrank();
        _quality = bound(_quality, 0, 10);
        _lockAmount = bound(_lockAmount, 10000000 ether, CTM_TS);
        _claimDays = bound(_claimDays, 1, 1825);
        uint256 _claimTime = _claimDays * 1 days;
        _receive(address(ctm), CTM_TS);
        vm.prank(user);
        uint256 tokenId = ve.create_lock(_lockAmount, MAXTIME);
        _attachTokenId(tokenId, 1);
        _setQualityOf(tokenId, _quality);
        skip(_claimTime);
        vm.prank(user);
        rewards.claimRewards(tokenId, user);
    }

    function test_OnlyOwnerClaimsRewards() public {
        _receive(address(ctm), CTM_TS);
        vm.prank(user);
        uint256 tokenId = ve.create_lock(10000 ether, MAXTIME);
        skip(1 days);
        vm.expectRevert("Only owner of token ID can claim rewards.");
        rewards.claimRewards(tokenId, user);
        vm.prank(user);
        rewards.claimRewards(tokenId, address(this));
    }

    function test_CompoundLockRewards() public {
        _receive(address(ctm), CTM_TS);
        vm.prank(user);
        uint256 tokenId = ve.create_lock(10000 ether, MAXTIME);
        (int128 lockedAmountBefore,) = ve.locked(tokenId);
        skip(1 days);
        vm.prank(user);
        uint256 rewardsCompounded = rewards.compoundLockRewards(tokenId);
        (int128 lockedAmountAfter,) = ve.locked(tokenId);
        uint256 lockedDifference = uint256(int256(lockedAmountAfter) - int256(lockedAmountBefore));
        assertEq(rewardsCompounded, lockedDifference);
    }
}