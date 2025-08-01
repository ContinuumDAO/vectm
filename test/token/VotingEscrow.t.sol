// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import { console } from "forge-std/console.sol";

import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import { IVotingEscrow } from "../../src/token/IVotingEscrow.sol";
import { VotingEscrowErrorParam } from "../../src/utils/VotingEscrowUtils.sol";
import { Helpers } from "../helpers/Helpers.sol";

contract TestVotingEscrow is Helpers {
    uint256 id1;
    uint256 id2;
    uint256 id3;
    uint256 id4;

    uint256 constant MAXTIME = 4 * 365 * 86_400;
    uint256 constant ONE_YEAR = 365 * 86_400;
    uint256 tokenId;

    // UTILS
    modifier approveUser2() {
        vm.prank(user1);
        ve.setApprovalForAll(user2, true);
        _;
    }

    modifier prank(address _user) {
        vm.startPrank(_user);
        _;
        vm.stopPrank();
    }

    // UTILS
    function setUp() public override {
        super.setUp();
        vm.startPrank(address(ctmDaoGovernor));
        rewards.setBaseEmissionRate(0);
        rewards.setNodeEmissionRate(0);
        vm.stopPrank();
    }

    // TESTS
    function testFuzz_CreateLockBasic(uint256 amount, uint256 endpoint) public prank(user1) {
        amount = bound(amount, 1, _100_000);
        endpoint = bound(endpoint, block.timestamp + 1 weeks, block.timestamp + MAXTIME);
        tokenId = ve.create_lock(amount, endpoint);
    }

    function testFuzz_IncreaseLockAmount(uint256 amount, uint256 endpoint, uint256 amountIncrease)
        public
        prank(user1)
    {
        amount = bound(amount, 1, _100_000 - 1);
        endpoint = bound(endpoint, block.timestamp + 1 weeks, block.timestamp + MAXTIME);
        amountIncrease = bound(amountIncrease, 1, _100_000 - amount);
        tokenId = ve.create_lock(amount, endpoint);
        ve.increase_amount(tokenId, amountIncrease);
    }

    function testFuzz_IncreaseLockTime(uint256 amount, uint256 endpoint, uint256 increasedTime) public prank(user1) {
        amount = bound(amount, 1, _100_000);
        endpoint = bound(endpoint, block.timestamp + 1 weeks, block.timestamp + MAXTIME - 1 weeks);
        increasedTime = bound(increasedTime, endpoint + 1 weeks, block.timestamp + MAXTIME);
        tokenId = ve.create_lock(amount, endpoint);
        ve.increase_unlock_time(tokenId, increasedTime);
    }

    function testFuzz_IncreaseLockAmountAndIncreaseLockTime(
        uint256 amount,
        uint256 endpoint,
        uint256 amountIncrease,
        uint256 increasedTime
    ) public prank(user1) {
        amount = bound(amount, 1, _100_000 - 1);
        endpoint = bound(endpoint, block.timestamp + 1 weeks, block.timestamp + MAXTIME - 1 weeks);
        amountIncrease = bound(amountIncrease, 1, _100_000 - amount);
        increasedTime = bound(increasedTime, endpoint + 1 weeks, block.timestamp + MAXTIME);
        tokenId = ve.create_lock(amount, endpoint);
        ve.increase_amount(tokenId, amountIncrease);
        ve.increase_unlock_time(tokenId, increasedTime);
    }

    function testFuzz_WithdrawExpiredLock(uint256 amount, uint256 endpoint, uint256 removalTime) public prank(user1) {
        amount = bound(amount, 1, CTM_TS);
        endpoint = bound(endpoint, block.timestamp + 1 weeks, block.timestamp + MAXTIME);
        removalTime = bound(removalTime, endpoint, type(uint48).max);

        tokenId = ve.create_lock(amount, endpoint);
        vm.warp(removalTime);
        ve.withdraw(tokenId);
    }

    function test_LockValueOverInt128() public prank(user1) {
        vm.expectRevert(
            abi.encodeWithSelector(
                SafeCast.SafeCastOverflowedIntDowncast.selector, 128, uint256(int256(type(int128).max)) + 1
            )
        );
        tokenId = ve.create_lock(uint256(int256(type(int128).max)) + 1, block.timestamp + MAXTIME);
    }

    function skip() internal {
        vm.warp(block.timestamp + 1);
    }

    function _weekTsInXYears(uint256 _years) internal pure returns (uint256) {
        return (_years * ONE_YEAR) / 1 weeks * 1 weeks;
    }

    // TESTS
    function test_FailSameTimestamp() public prank(user1) {
        id1 = ve.create_lock(1 ether, block.timestamp + MAXTIME);
        vm.expectRevert(IVotingEscrow.VotingEscrow_SameTimestamp.selector);
        id2 = ve.create_lock(1 ether, block.timestamp + MAXTIME);
    }

    function test_GetVePower() public prank(user1) {
        uint256 WEEK_4_YEARS = _weekTsInXYears(4);
        id1 = ve.create_lock(1000 ether, WEEK_4_YEARS);
        uint256 vepowerStartEth = ve.balanceOfNFT(id1) / 1e18;
        (int128 _value, uint256 _end) = ve.locked(id1);
        assertEq(vepowerStartEth, 997);
        assertEq(_value, 1000 ether);
        assertEq(_end, WEEK_4_YEARS);

        uint256 WEEK_2_YEARS = _weekTsInXYears(2);
        vm.warp(WEEK_2_YEARS);
        uint256 vepowerHalfwayEth = ve.balanceOfNFT(id1) / 1e18;
        assertEq(vepowerHalfwayEth, vepowerStartEth / 2);

        vm.warp(WEEK_4_YEARS);
        uint256 vepowerEndEth = ve.balanceOfNFT(id1) / 1e18;
        assertEq(vepowerEndEth, 0);

        rewards.claimRewards(id1, user1);
        uint256 balBefore = ctm.balanceOf(user1);
        ve.withdraw(id1);
        uint256 balAfter = ctm.balanceOf(user1);
        assertEq(balAfter, balBefore + uint256(int256(_value)));
    }

    function test_OnlyVotingTokensCount() public prank(user1) {
        uint256 WEEK_4_YEARS = _weekTsInXYears(4);
        id1 = ve.create_lock(1000 ether, WEEK_4_YEARS);
        uint256 vePowerBefore = ve.balanceOfNFT(id1);
        uint256 idLengthBefore = ve.tokenIdsDelegatedTo(user1).length;
        skip(1);
        id2 = ve.create_nonvoting_lock_for(1000 ether, WEEK_4_YEARS, user1);
        uint256 vePowerAfter = ve.balanceOfNFTAt(id1, block.timestamp - 1);
        uint256 idLengthAfter = ve.tokenIdsDelegatedTo(user1).length;
        assertEq(idLengthAfter, idLengthBefore + 1);
        assertEq(vePowerAfter, vePowerBefore);
    }

    function test_DelegateTokens() public prank(user1) {
        console.log("Pre-check: User and user2 should have no delegated tokens");
        uint256[] memory userDelegatedIDs = ve.tokenIdsDelegatedTo(user1);
        uint256[] memory user2DelegatedIDs = ve.tokenIdsDelegatedTo(user2);
        assertEq(userDelegatedIDs.length, 0);
        assertEq(user2DelegatedIDs.length, 0);
        skip(1);

        console.log("Create token 1: User should have one delegated (1), one owned (1)");
        id1 = ve.create_lock(1 ether, block.timestamp + MAXTIME);
        userDelegatedIDs = ve.tokenIdsDelegatedTo(user1);
        assertEq(userDelegatedIDs.length, 1);
        assertEq(userDelegatedIDs[0], id1);
        skip(1);

        console.log("Create token 2: User should have two delegated (1,2), two owned (1,2)");
        id2 = ve.create_lock(1 ether, block.timestamp + MAXTIME);
        userDelegatedIDs = ve.tokenIdsDelegatedTo(user1);
        assertEq(userDelegatedIDs.length, 2);
        assertEq(userDelegatedIDs[0], id1);
        assertEq(userDelegatedIDs[1], id2);
        skip(1);

        console.log(
            "Delegate user => user2: User should have zero delegated, two owned (1,2) and user2 should have two delegated (1,2)"
        );
        ve.delegate(user2);
        userDelegatedIDs = ve.tokenIdsDelegatedTo(user1);
        user2DelegatedIDs = ve.tokenIdsDelegatedTo(user2);
        assertEq(userDelegatedIDs.length, 0);
        assertEq(user2DelegatedIDs.length, 2);
        assertEq(user2DelegatedIDs[0], id1);
        assertEq(user2DelegatedIDs[1], id2);
        assertEq(ve.ownerOf(id1), user1);
        assertEq(ve.ownerOf(id2), user1);
        skip(1);

        console.log(
            "Create token 3: User should have zero delegated, three owned (1,2,3) and user2 should have three delegated (1,2,3)"
        );
        id3 = ve.create_lock(1 ether, block.timestamp + MAXTIME);
        userDelegatedIDs = ve.tokenIdsDelegatedTo(user1);
        user2DelegatedIDs = ve.tokenIdsDelegatedTo(user2);
        assertEq(userDelegatedIDs.length, 0);
        assertEq(user2DelegatedIDs.length, 3);
        assertEq(user2DelegatedIDs[0], id1);
        assertEq(user2DelegatedIDs[1], id2);
        assertEq(user2DelegatedIDs[2], id3);
        assertEq(ve.ownerOf(id1), user1);
        assertEq(ve.ownerOf(id2), user1);
        assertEq(ve.ownerOf(id3), user1);
        skip(1);

        console.log(
            "Transfer token 2: User should have zero delegated, two owned (1,3) and user2 should have two delegated (1,3), one owned (2)"
        );
        ve.transferFrom(user1, user2, id2);
        userDelegatedIDs = ve.tokenIdsDelegatedTo(user1);
        user2DelegatedIDs = ve.tokenIdsDelegatedTo(user2);
        assertEq(userDelegatedIDs.length, 0);
        assertEq(user2DelegatedIDs.length, 2);
        assertEq(user2DelegatedIDs[0], id1);
        assertEq(user2DelegatedIDs[1], id3);
        assertEq(ve.ownerOf(id1), user1);
        assertEq(ve.ownerOf(id2), user2);
        assertEq(ve.ownerOf(id3), user1);
        skip(1);

        vm.stopPrank();
        vm.startPrank(user2);

        console.log(
            "Delegate user2 => user2: User should have zero delegated, two owned (1,3) and user2 should have three delegated (1,3,2), one owned (2)"
        );
        ve.delegate(user2);
        userDelegatedIDs = ve.tokenIdsDelegatedTo(user1);
        user2DelegatedIDs = ve.tokenIdsDelegatedTo(user2);
        assertEq(userDelegatedIDs.length, 0);
        assertEq(user2DelegatedIDs.length, 3);
        assertEq(user2DelegatedIDs[0], id1);
        assertEq(user2DelegatedIDs[1], id3);
        assertEq(user2DelegatedIDs[2], id2);
        assertEq(ve.ownerOf(id1), user1);
        assertEq(ve.ownerOf(id2), user2);
        assertEq(ve.ownerOf(id3), user1);
        skip(1);

        console.log(
            "Create token 4: User should have zero delegated, two owned (1,3) and user2 should have four delegated (1,3,2,4), two owned (2,4)"
        );
        id4 = ve.create_lock(1 ether, block.timestamp + MAXTIME);
        userDelegatedIDs = ve.tokenIdsDelegatedTo(user1);
        user2DelegatedIDs = ve.tokenIdsDelegatedTo(user2);
        assertEq(userDelegatedIDs.length, 0);
        assertEq(user2DelegatedIDs.length, 4);
        assertEq(user2DelegatedIDs[0], id1);
        assertEq(user2DelegatedIDs[1], id3);
        assertEq(user2DelegatedIDs[2], id2);
        assertEq(user2DelegatedIDs[3], id4);
        assertEq(ve.ownerOf(id1), user1);
        assertEq(ve.ownerOf(id2), user2);
        assertEq(ve.ownerOf(id3), user1);
        assertEq(ve.ownerOf(id4), user2);
        skip(1);

        console.log(
            "Delegate user2 => user: User should have two delegated, two owned (1,3) and user2 should have two delegated (1,3), two owned (2,4)"
        );
        ve.delegate(user1);
        userDelegatedIDs = ve.tokenIdsDelegatedTo(user1);
        user2DelegatedIDs = ve.tokenIdsDelegatedTo(user2);
        assertEq(userDelegatedIDs.length, 2);
        assertEq(user2DelegatedIDs.length, 2);
        assertEq(userDelegatedIDs[0], id2);
        assertEq(userDelegatedIDs[1], id4);
        assertEq(user2DelegatedIDs[0], id1);
        assertEq(user2DelegatedIDs[1], id3);
        assertEq(ve.ownerOf(id1), user1);
        assertEq(ve.ownerOf(id2), user2);
        assertEq(ve.ownerOf(id3), user1);
        assertEq(ve.ownerOf(id4), user2);
    }

    function test_GetVotes() public prank(user1) {
        uint256 WEEK_4_YEARS = _weekTsInXYears(4);
        id1 = ve.create_lock(1000 ether, WEEK_4_YEARS);
        id2 = ve.create_lock_for(1000 ether, WEEK_4_YEARS, user2);
        uint256 vePower1Start = ve.balanceOfNFT(id1);
        uint256 vePower2Start = ve.balanceOfNFT(id2);
        uint256 votesUserStart = ve.getVotes(user1);
        uint256 votesUser2Start = ve.getVotes(user2);
        skip(1);
        uint256 totalSupplyStart = ve.getPastTotalSupply(1);
        assertEq(totalSupplyStart, vePower1Start + vePower2Start);
        assertEq(votesUserStart, vePower1Start);
        assertEq(votesUser2Start, vePower2Start);
        ve.delegate(user2);
        vePower1Start = ve.balanceOfNFT(id1);
        vePower2Start = ve.balanceOfNFT(id2);
        uint256 votesUserDelegated = ve.getVotes(user1);
        uint256 votesUser2Delegated = ve.getVotes(user2);
        assertEq(votesUserDelegated, 0);
        assertEq(votesUser2Delegated, vePower1Start + vePower2Start);

        uint256 WEEK_2_YEARS = _weekTsInXYears(2);
        vm.warp(WEEK_2_YEARS);
        uint256 vePower1Halfway = ve.balanceOfNFT(id1);
        uint256 vePower2Halfway = ve.balanceOfNFT(id2);
        uint256 votesUser1Halfway = ve.getVotes(user1);
        uint256 votesUser2Halfway = ve.getVotes(user2);
        assertEq(votesUser1Halfway, 0);
        assertEq(votesUser2Halfway, vePower1Halfway + vePower2Halfway);
    }

    function test_GetPastVotes() public prank(user1) {
        uint256 WEEK_4_YEARS = _weekTsInXYears(4);
        id1 = ve.create_lock(1000 ether, WEEK_4_YEARS);
        skip(1);
        id2 = ve.create_lock(1000 ether, WEEK_4_YEARS);
        uint256 votesUserStart = ve.getVotes(user1);
        uint256 votesUser2Start = ve.getVotes(user2);

        uint256 WEEK_2_YEARS = _weekTsInXYears(2);
        vm.warp(WEEK_2_YEARS);
        ve.delegate(user2);
        uint256 pastVotesUserStart = ve.getPastVotes(user1, 2);
        uint256 pastVotesUser2Start = ve.getPastVotes(user2, 2);
        assertEq(pastVotesUserStart, votesUserStart);
        assertEq(pastVotesUser2Start, votesUser2Start);
        uint256 votesUserHalfway = ve.getVotes(user1);
        uint256 votesUser2Halfway = ve.getVotes(user2);

        vm.warp(WEEK_4_YEARS);
        ve.delegate(user1);
        uint256 pastVotesUserHalfway = ve.getPastVotes(user1, WEEK_2_YEARS);
        uint256 pastVotesUser2Halfway = ve.getPastVotes(user2, WEEK_2_YEARS);
        assertEq(pastVotesUserHalfway, votesUserHalfway);
        assertEq(pastVotesUser2Halfway, votesUser2Halfway);
    }

    function test_MergeCombinesVotes() public prank(user1) {
        uint256 WEEK_4_YEARS = _weekTsInXYears(4);
        uint256 WEEK_2_YEARS = _weekTsInXYears(2);
        id1 = ve.create_lock(500 ether, WEEK_4_YEARS);
        skip(1);
        id2 = ve.create_lock(1000 ether, WEEK_2_YEARS);
        uint256 individualVotesEth = ve.getVotes(user1) / 1e18;
        uint256 vePower1EthBefore = ve.balanceOfNFT(id1) / 1e18;
        uint256 vePower2EthBefore = ve.balanceOfNFT(id2) / 1e18;
        assertEq(vePower1EthBefore, vePower2EthBefore);
        skip(1);
        ve.merge(id1, id2);
        uint256 mergedVotesEth = ve.getVotes(user1) / 1e18;
        uint256 vePower1EthAfter = ve.balanceOfNFT(id1) / 1e18;
        uint256 vePower2EthAfter = ve.balanceOfNFT(id2) / 1e18;
        assertEq(mergedVotesEth, individualVotesEth + 2); // the lock time of merge got rounded up
        assertEq(vePower1EthAfter, 0);
        assertEq(vePower2EthAfter, mergedVotesEth);
    }

    function test_SplitSeparatesVotes() public prank(user1) {
        uint256 WEEK_4_YEARS = _weekTsInXYears(4);
        id1 = ve.create_lock(1000 ether, WEEK_4_YEARS);
        uint256 votesBeforeEth = ve.getVotes(user1) / 1e18;
        (, uint256 _endBefore) = ve.locked(id1);
        skip(1);
        id2 = ve.split(id1, 980 ether);
        (int128 _value1, uint256 _end1) = ve.locked(id1);
        (int128 _value2, uint256 _end2) = ve.locked(id2);
        uint256 votesAfterEth = ve.getVotes(user1) / 1e18;
        assertEq(votesAfterEth, votesBeforeEth);
        assertEq(_value1, 20 ether);
        assertEq(_value2, 980 ether);
        assertEq(_end1, _endBefore);
        assertEq(_end2, _endBefore);
    }

    function test_LiquidateInvalidatesVotes() public prank(user1) {
        uint256 WEEK_4_YEARS = _weekTsInXYears(4);
        id1 = ve.create_lock(100 ether, WEEK_4_YEARS);
        uint256 lengthBefore = ve.tokenIdsDelegatedTo(user1).length;
        uint256 balanceUserBeforeEth = ctm.balanceOf(user1) / 1e18;
        uint256 balanceTreasuryBeforeEth = ctm.balanceOf(treasury) / 1e18;
        skip(1);
        ve.liquidate(id1);
        uint256 lengthAfter = ve.tokenIdsDelegatedTo(user1).length;
        uint256 votesAfterEth = ve.getVotes(user1) / 1e18;
        uint256 balanceUserAfterEth = ctm.balanceOf(user1) / 1e18;
        uint256 balanceTreasuryAfterEth = ctm.balanceOf(treasury) / 1e18;
        assertEq(lengthAfter, lengthBefore - 1);
        assertEq(votesAfterEth, 0);
        assertEq(balanceUserAfterEth, balanceUserBeforeEth + 50);
        assertEq(balanceTreasuryAfterEth, balanceTreasuryBeforeEth + 49);
    }

    function test_Liquidate1YearBefore() public prank(user1) {
        uint256 WEEK_4_YEARS = _weekTsInXYears(4);
        uint256 WEEK_3_YEARS = _weekTsInXYears(3);
        id1 = ve.create_lock(100 ether, WEEK_4_YEARS);
        uint256 balanceUserBeforeEth = ctm.balanceOf(user1) / 1e18;
        uint256 balanceTreasuryBeforeEth = ctm.balanceOf(treasury) / 1e18;
        vm.warp(WEEK_3_YEARS);
        uint256 claimed = rewards.claimRewards(id1, user1);
        ctm.burn(claimed);
        ve.liquidate(id1);
        uint256 votesAfterEth = ve.getVotes(user1) / 1e18;
        uint256 balanceUserAfterEth = ctm.balanceOf(user1) / 1e18;
        uint256 balanceTreasuryAfterEth = ctm.balanceOf(treasury) / 1e18;
        assertEq(votesAfterEth, 0);
        assertEq(balanceUserAfterEth, balanceUserBeforeEth + 87); // should be 5/8s of original lock = 87.5 (truncation)
        assertEq(balanceTreasuryAfterEth, balanceTreasuryBeforeEth + 12); // should be 3/8s of original lock = 12.5
            // (truncation)
    }

    function test_LiquidateAfter4Years() public prank(user1) {
        uint256 WEEK_4_YEARS = _weekTsInXYears(4);
        uint256 balanceUserBefore = ctm.balanceOf(user1);
        uint256 balanceTreasuryBefore = ctm.balanceOf(treasury);
        id1 = ve.create_lock(100 ether, WEEK_4_YEARS);
        vm.warp(WEEK_4_YEARS);

        ve.liquidate(id1);
        uint256 balanceUserAfter = ctm.balanceOf(user1);
        uint256 balanceTreasuryAfter = ctm.balanceOf(treasury);
        assertEq(balanceUserAfter, balanceUserBefore);
        assertEq(balanceTreasuryAfter, balanceTreasuryBefore);
    }

    function _weekTsInXWeeks(uint256 _weeks) internal pure returns (uint256) {
        return (_weeks * 1 weeks) / 1 weeks * 1 weeks;
    }

    // TESTS
    function test_ApprovedMerge() public approveUser2 prank(user2) {
        uint256 WEEK_4_YEARS = _weekTsInXYears(4);
        id1 = ve.create_lock_for(1000 ether, WEEK_4_YEARS, user1);
        skip(1);
        id2 = ve.create_lock_for(1000 ether, WEEK_4_YEARS, user1);
        skip(1);
        uint256[] memory userDelegatedIDsBefore = ve.tokenIdsDelegatedTo(user1);
        ve.merge(id1, id2);
        uint256[] memory userDelegatedIDsAfter = ve.tokenIdsDelegatedTo(user1);
        assertEq(userDelegatedIDsBefore[0], 1);
        assertEq(userDelegatedIDsBefore[1], 2);
        assertEq(userDelegatedIDsAfter[0], 2);
    }

    function test_NotApprovedMerge() public prank(user2) {
        uint256 WEEK_4_YEARS = _weekTsInXYears(4);
        id1 = ve.create_lock_for(1000 ether, WEEK_4_YEARS, user1);
        skip(1);
        id2 = ve.create_lock_for(1000 ether, WEEK_4_YEARS, user1);
        skip(1);
        uint256[] memory userDelegatedIDsBefore = ve.tokenIdsDelegatedTo(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IVotingEscrow.VotingEscrow_OnlyAuthorized.selector,
                VotingEscrowErrorParam.Sender,
                VotingEscrowErrorParam.ApprovedOrOwner
            )
        );
        ve.merge(id1, id2);
        uint256[] memory userDelegatedIDsAfter = ve.tokenIdsDelegatedTo(user1);
        assertEq(userDelegatedIDsAfter[0], userDelegatedIDsBefore[0]);
        assertEq(userDelegatedIDsAfter[1], userDelegatedIDsBefore[1]);
    }

    function test_MergeWithTwoNonVoting() public prank(user1) {
        uint256 WEEK_4_YEARS = _weekTsInXYears(4);
        id1 = ve.create_nonvoting_lock_for(1000 ether, WEEK_4_YEARS, user1);
        skip(1);
        id2 = ve.create_nonvoting_lock_for(1000 ether, WEEK_4_YEARS, user1);
        skip(1);
        ve.merge(id1, id2);
        uint256 votes = ve.getVotes(user1);
        assertEq(votes, 0);
    }

    function test_CannotMergeVotingWithNonVoting() public prank(user1) {
        uint256 WEEK_4_YEARS = _weekTsInXYears(4);
        id1 = ve.create_lock(1000 ether, WEEK_4_YEARS);
        skip(1);
        id2 = ve.create_nonvoting_lock_for(1000 ether, WEEK_4_YEARS, user1);
        skip(1);
        // vm.expectRevert("veCTM: Merging between voting and non-voting token ID not allowed");
        vm.expectRevert(abi.encodeWithSelector(IVotingEscrow.VotingEscrow_VotingAndNonVotingMerge.selector, id1, id2));
        ve.merge(id1, id2);
    }

    function testFuzz_Merge(uint256 _value1, uint256 _value2, uint256 _end1, uint256 _end2) public prank(user1) {
        uint256 MIN_LOCK = _weekTsInXWeeks(1);
        uint256 MAX_LOCK = _weekTsInXYears(4);
        _end1 = bound(_end1, MIN_LOCK, MAX_LOCK);
        _end2 = bound(_end2, MIN_LOCK, MAX_LOCK);
        _value1 = bound(_value1, 1, _100_000 / 2);
        _value2 = bound(_value2, 1, _100_000 / 2);

        id1 = ve.create_lock(_value1, _end1);
        (int128 _value1Before128, uint256 _end1Before) = ve.locked(id1);
        uint256 _value1Before = SafeCast.toUint256(int256(_value1Before128));
        skip(1);
        id2 = ve.create_lock(_value2, _end2);
        (int128 _value2Before128, uint256 _end2Before) = ve.locked(id2);
        uint256 _value2Before = SafeCast.toUint256(int256(_value2Before128));
        skip(1);
        ve.merge(id1, id2);
        (int128 _value1After128, uint256 _end1After) = ve.locked(id1);
        (int128 _value2After128, uint256 _end2After) = ve.locked(id2);
        uint256 _value1After = SafeCast.toUint256(int256(_value1After128));
        uint256 _value2After = SafeCast.toUint256(int256(_value2After128));
        uint256 weightedEnd =
            ((_end1Before * _value1Before) + (_end2Before * _value2Before)) / (_value1Before + _value2Before);
        // uint256 unlockTime = (((block.timestamp + weightedEnd) / WEEK) * WEEK) + WEEK;
        uint256 unlockTime = ((weightedEnd / 1 weeks) * 1 weeks) + 1 weeks;
        if (unlockTime > MAX_LOCK) {
            unlockTime -= 1 weeks;
        }

        assertEq(_value1After, 0);
        assertEq(_end1After, 0);
        assertEq(_value2After, _value1Before + _value2Before);
        assertEq(_end2After, unlockTime);
    }

    function test_SplitValueOverMaxInt128() public prank(user1) {
        uint256 WEEK_4_YEARS = _weekTsInXYears(4);
        id1 = ve.create_lock(1000 ether, WEEK_4_YEARS);
        skip(1);
        vm.expectRevert(
            abi.encodeWithSelector(
                SafeCast.SafeCastOverflowedIntDowncast.selector, 128, uint256(int256(type(int128).max)) + 1
            )
        );
        ve.split(id1, uint256(int256(type(int128).max)) + 1);
    }

    function test_ApprovedSplit() public approveUser2 prank(user2) {
        uint256 WEEK_4_YEARS = _weekTsInXYears(4);
        id1 = ve.create_lock_for(1000 ether, WEEK_4_YEARS, user1);
        skip(1);
        uint256[] memory userDelegatedIDsBefore = ve.tokenIdsDelegatedTo(user1);
        ve.split(id1, 500 ether);
        uint256[] memory userDelegatedIDsAfter = ve.tokenIdsDelegatedTo(user1);
        assertEq(userDelegatedIDsBefore[0], 1);
        assertEq(userDelegatedIDsAfter[0], 1);
        assertEq(userDelegatedIDsAfter[1], 2);
    }

    function test_NotApprovedSplit() public prank(user2) {
        uint256 WEEK_4_YEARS = _weekTsInXYears(4);
        id1 = ve.create_lock_for(1000 ether, WEEK_4_YEARS, user1);
        skip(1);
        uint256[] memory userDelegatedIDsBefore = ve.tokenIdsDelegatedTo(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IVotingEscrow.VotingEscrow_OnlyAuthorized.selector,
                VotingEscrowErrorParam.Sender,
                VotingEscrowErrorParam.ApprovedOrOwner
            )
        );
        ve.split(id1, 500 ether);
        uint256[] memory userDelegatedIDsAfter = ve.tokenIdsDelegatedTo(user1);
        assertEq(userDelegatedIDsAfter[0], userDelegatedIDsBefore[0]);
    }

    function test_SplitNonVoting() public prank(user1) {
        uint256 WEEK_4_YEARS = _weekTsInXYears(4);
        id1 = ve.create_nonvoting_lock_for(1000 ether, WEEK_4_YEARS, user1);
        skip(1);
        id2 = ve.split(id1, 500 ether);
        uint256 votes = ve.getVotes(user1);
        bool id1NonVoting = ve.nonVoting(id1);
        bool id2NonVoting = ve.nonVoting(id2);
        assertEq(id1NonVoting, true);
        assertEq(id2NonVoting, true);
        assertEq(votes, 0);
    }

    function testFuzz_Split(uint256 _initialValue, uint256 _extractedValue, uint256 _initialEnd) public prank(user1) {
        uint256 MIN_LOCK = _weekTsInXWeeks(1);
        uint256 MAX_LOCK = _weekTsInXYears(4);
        _initialEnd = bound(_initialEnd, MIN_LOCK, MAX_LOCK);
        _initialValue = bound(_initialValue, 2, _100_000 / 2);
        _extractedValue = bound(_extractedValue, 1, _initialValue - 1);

        id1 = ve.create_lock(_initialValue, _initialEnd);
        (int128 _value1Before128,) = ve.locked(id1);
        uint256 _value1Before = uint256(int256(_value1Before128));
        skip(1);
        id2 = ve.split(id1, _extractedValue);
        (int128 _value1After128,) = ve.locked(id1);
        (int128 _value2After128,) = ve.locked(id2);
        uint256 _value1After = uint256(int256(_value1After128));
        uint256 _value2After = uint256(int256(_value2After128));
        assertEq(_value1After + _value2After, _value1Before);
        assertEq(_value1After, _initialValue - _extractedValue);
        assertEq(_value2After, _extractedValue);
    }

    function test_ApprovedLiquidation() public approveUser2 {
        uint256 WEEK_4_YEARS = _weekTsInXYears(4);
        vm.prank(user2);
        id1 = ve.create_lock_for(1000 ether, WEEK_4_YEARS, user1);
        uint256 lengthBefore = ve.tokenIdsDelegatedTo(user1).length;
        vm.warp(WEEK_4_YEARS);
        vm.prank(user1);
        rewards.claimRewards(id1, user1);
        vm.prank(user2);
        ve.liquidate(id1);
        uint256 lengthAfter = ve.tokenIdsDelegatedTo(user1).length;
        assertEq(lengthAfter, lengthBefore - 1);
    }

    function testFuzz_Liquidate(uint256 _value, uint256 _end, uint256 _liquidationTs) public prank(user1) {
        uint256 MIN_LOCK = _weekTsInXWeeks(1);
        uint256 MAX_LOCK = _weekTsInXYears(4);
        _value = bound(_value, 101 gwei, _100_000);
        _end = bound(_end, MIN_LOCK, MAX_LOCK);
        _liquidationTs = bound(_liquidationTs, MIN_LOCK + 1, MAX_LOCK + 1);

        id1 = ve.create_lock(_value, _end);
        vm.warp(_liquidationTs);

        // if (_liquidationTs >= _end) {
        //     vm.expectEmit(true, false, false, true);
        //     emit VotingEscrow.Withdraw(user, id1, _value, _liquidationTs);
        //     ve.liquidate(id1);
        // } else {
        rewards.claimRewards(id1, user1);
        ve.liquidate(id1);
        // }
    }
}
