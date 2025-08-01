// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import {console} from "forge-std/console.sol";

import {Rewards} from "../../src/node/Rewards.sol";
import {IRewards} from "../../src/node/IRewards.sol";
import {NodeProperties} from "../../src/node/NodeProperties.sol";
import {VotingEscrowProxy} from "../../src/utils/VotingEscrowProxy.sol";
import {VotingEscrow} from "../../src/token/VotingEscrow.sol";
import {IVotingEscrow} from "../../src/token/IVotingEscrow.sol";
import {VotingEscrowErrorParam} from "../../src/utils/VotingEscrowUtils.sol";
import {TestERC20} from "../helpers/mocks/TestERC20.sol";
import {Helpers} from "../helpers/Helpers.sol";

contract TestRewards is Helpers {
    uint256 constant MAXTIME = 4 * 365 * 86400;

    function setUp() public override {
        super.setUp();
    }

    modifier prank(address _user) {
        vm.startPrank(_user);
        _;
        vm.stopPrank();
    }

    function _attachTokenId(uint256 _tokenId, address _sender) internal prank(_sender) {
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

    function _setQualityOf(uint256 _tokenId, uint256 _quality) internal prank(address(ctmDaoGovernor)) {
        nodeProperties.setNodeQualityOf(_tokenId, _quality);
    }

    function test_SetRewardsTooHigh() public prank(address(ctmDaoGovernor)) {
        vm.expectRevert(abi.encodeWithSelector(IRewards.Rewards_EmissionRateChangeTooHigh.selector));
        rewards.setBaseEmissionRate(1 ether / uint256(99));
        vm.expectRevert(abi.encodeWithSelector(IRewards.Rewards_EmissionRateChangeTooHigh.selector));
        rewards.setNodeEmissionRate(1 ether / uint256(99));
    }

    function test_RewardBaseEmissions() public {
        _setQualityOf(1, 0);
        vm.prank(user1);
        uint256 tokenId = ve.create_lock(10000 ether, MAXTIME);
        uint256 unclaimed = rewards.unclaimedRewards(tokenId);
        skip(1 days);
        unclaimed = rewards.unclaimedRewards(tokenId);
        console.log(unclaimed/1e18);
        // assertEq(unclaimed/1e18, 4); // 1 day => 4.9 CTM = 0.05%
        skip(9 days);
        unclaimed = rewards.unclaimedRewards(tokenId);
        console.log(unclaimed/1e18);
        // assertEq(unclaimed/1e18, 49); // 10 days => 49.67 CTM = 0.5%
        skip(355 days);
        unclaimed = rewards.unclaimedRewards(tokenId);
        console.log(unclaimed/1e18);
        // assertEq(unclaimed/1e18, 1591); // 365 days => 1591 CTM = 15.9%
    }

    function test_RewardNodeEmissions() public {
        vm.prank(user1);
        uint256 tokenId = ve.create_lock(10000 ether, MAXTIME);
        _attachTokenId(tokenId, user1);
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
        assertEq(unclaimed/1e18, 4773); // 365 days => 4773 CTM = 48%
    }

    function test_FuzzClaimBaseRewards(uint256 _lockAmount, uint256 _claimDays) public {
        _lockAmount = bound(_lockAmount, 1, _100_000);
        _claimDays = bound(_claimDays, 1, 3650);
        uint256 _claimTime = _claimDays * 1 days;
        vm.startPrank(user1);
        uint256 tokenId = ve.create_lock(_lockAmount, MAXTIME);
        skip(_claimTime);
        rewards.claimRewards(tokenId, user1);
        vm.stopPrank();
    }

    function test_FuzzClaimNodeRewards(uint256 _lockAmount, uint256 _claimDays, uint256 _quality) public {
        vm.startPrank(address(ctmDaoGovernor));
        rewards.setBaseEmissionRate(1 ether / 200000);
        rewards.setNodeEmissionRate(1 ether / 100000);
        vm.stopPrank();
        _quality = bound(_quality, 0, 10);
        _lockAmount = bound(_lockAmount, 6000 ether, CTM_TS);
        _claimDays = bound(_claimDays, 1, 1825);
        uint256 _claimTime = _claimDays * 1 days;
        vm.prank(admin);
        uint256 tokenId = ve.create_lock(_lockAmount, MAXTIME);
        _attachTokenId(tokenId, admin);
        _setQualityOf(tokenId, _quality);
        skip(_claimTime);
        uint256 unclaimedBefore = rewards.unclaimedRewards(tokenId);
        vm.prank(admin);
        uint256 claimed = rewards.claimRewards(tokenId, user1);
        uint256 unclaimedAfter = rewards.unclaimedRewards(tokenId);
        assertEq(claimed, unclaimedBefore);
        assertEq(unclaimedAfter, 0);
    }

    function test_OnlyOwnerClaimsRewards() public {
        vm.prank(user1);
        uint256 tokenId = ve.create_lock(10000 ether, MAXTIME);
        skip(1 days);
        vm.expectRevert(abi.encodeWithSelector(IRewards.Rewards_OnlyAuthorized.selector, VotingEscrowErrorParam.Sender, VotingEscrowErrorParam.Owner));
        rewards.claimRewards(tokenId, user1);
        vm.prank(user1);
        rewards.claimRewards(tokenId, address(this));
    }

    function test_CompoundLockRewards() public {
        vm.prank(user1);
        uint256 tokenId = ve.create_lock(10000 ether, MAXTIME);
        (int128 lockedAmountBefore,) = ve.locked(tokenId);
        skip(10 days);
        vm.prank(user1);
        uint256 rewardsCompounded = rewards.compoundLockRewards(tokenId);
        (int128 lockedAmountAfter,) = ve.locked(tokenId);
        uint256 lockedDifference = uint256(int256(lockedAmountAfter) - int256(lockedAmountBefore));
        assertEq(rewardsCompounded, lockedDifference);
    }
}