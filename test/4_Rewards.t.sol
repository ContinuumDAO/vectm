// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import {Rewards} from "../src/Rewards.sol";
import {NodeProperties} from "../src/NodeProperties.sol";
import {VotingEscrowProxy} from "../src/VotingEscrowProxy.sol";
import {IVotingEscrow, VotingEscrow} from "../src/VotingEscrow.sol";
import {TestERC20} from "../src/TestERC20.sol";

contract TestRewards is Test {
    TestERC20 ctm;
    TestERC20 usdc;
    VotingEscrow veImpl;
    VotingEscrowProxy veProxy;
    IVotingEscrow ve;
    NodeProperties nodeProperties;
    Rewards rewards;
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

    function setUp() public virtual {
        gov = makeAddr("gov");
        committee = makeAddr("committee");
        treasury = makeAddr("treasury");
        user = makeAddr("user");
        bridge = makeAddr("bridge");

        ctm = new TestERC20("Continuum", "CTM", 18);
        usdc = new TestERC20("Tether USD", "USDT", 6);
        veImpl = new VotingEscrow();
        bytes memory initializerData = abi.encodeWithSignature(
            "initialize(address,string)",
            address(ctm),
            BASE_URI_V1
        );
        veProxy = new VotingEscrowProxy(address(veImpl), initializerData);

        ve = IVotingEscrow(address(veProxy));
        ctm.print(user, CTM_TS);
        ctm.print(bridge, CTM_TS);
        usdc.print(bridge, USDC_TS);
        
        nodeProperties = new NodeProperties(gov, address(ve));

        rewards = new Rewards(
            0, // _firstMidnight,
            gov, // _gov
            address(ctm), // _rewardToken
            address(usdc), // _feeToken
            address(0), // _swapRouter
            address(ve), // _ve
            address(nodeProperties), // _nodeProperties
            address(0), // _weth
            1 ether / 2000, // _baseEmissionRate
            1 ether / 1000, // _nodeEmissionRate
            5000 ether, // _nodeRewardThreshold
            7_812_500 gwei, // _feePerByteRewardToken
            3125 // _feePerByteFeeToken
        );

        ve.setUp(gov, address(nodeProperties), address(rewards), treasury);

        vm.startPrank(gov);
        nodeProperties.setRewards(address(rewards));
        ve.enableLiquidations();
        vm.stopPrank();

        vm.startPrank(gov);
        nodeProperties.setRewards(address(rewards));
        ve.enableLiquidations();
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

    function _attachTokenId(uint256 _tokenId) internal prank(user) {
        nodeProperties.attachNode(
            _tokenId,
            NodeProperties.NodeInfo(
                // string forumHandle;
                "@myhandle",
                // string email
                "john.doe@mail.com",
                // bytes32 nodeId
                keccak256(abi.encode("Example Node ID")),
                // uint8[4] ip;
                [0,0,0,0],
                // string vpsProvider;
                "Contabo",
                // uint256 ramInstalled;
                16000000000,
                // uint256 cpuCores;
                8,
                // string dIDType;
                "Galxe",
                // string dID;
                "123457890",
                // bytes data;
                ""
            )
        );
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
        _attachTokenId(tokenId);
        _setQualityOf(tokenId, 10);
        uint256 unclaimed = rewards.unclaimedRewards(tokenId);
        skip(1 days);
        unclaimed = rewards.unclaimedRewards(tokenId);
        console.log(unclaimed/1e18);
        // assertEq(unclaimed/1e18, 14); // 1 day => 14.95 CTM = 0.15%
        skip(9 days);
        unclaimed = rewards.unclaimedRewards(tokenId);
        console.log(unclaimed/1e18);
        // assertEq(unclaimed/1e18, 149); // 10 days => 149 CTM = 1.5%
        skip(355 days);
        unclaimed = rewards.unclaimedRewards(tokenId);
        console.log(unclaimed/1e18);
        // assertEq(unclaimed/1e18, 4773); // 365 days => 4774 CTM = 48%
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
        _attachTokenId(tokenId);
        _setQualityOf(tokenId, _quality);
        skip(_claimTime);
        uint256 unclaimedBefore = rewards.unclaimedRewards(tokenId);
        vm.prank(user);
        uint256 claimed = rewards.claimRewards(tokenId, user);
        uint256 unclaimedAfter = rewards.unclaimedRewards(tokenId);
        assertEq(claimed, unclaimedBefore);
        assertEq(unclaimedAfter, 0);
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