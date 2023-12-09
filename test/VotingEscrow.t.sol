// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import {VotingEscrow} from "../src/VotingEscrow.sol";
import {CTM} from "../src/CTM.sol";

contract SetUp is Test {
    CTM ctm;
    VotingEscrow ve;
    address user0;
    address user1;
    address user2;
    uint256 ctmBal0 = 10 ether;

    function setUp() public virtual {
        string memory mnemonic = "test test test test test test test test test test test junk";
        uint256 privKey0 = vm.deriveKey(mnemonic, 0);
        uint256 privKey1 = vm.deriveKey(mnemonic, 1);
        uint256 privKey2 = vm.deriveKey(mnemonic, 2);
        user0 = vm.addr(privKey0);
        user1 = vm.addr(privKey1);
        user2 = vm.addr(privKey2);
        ctm = new CTM();
        ve = new VotingEscrow(address(ctm), "<BASE_URI>");
        ctm.print(user0, ctmBal0);
        vm.prank(user0);
        ctm.approve(address(ve), ctmBal0);
    }
}


contract CreateLock is SetUp {
    uint256 constant MAXTIME = 4 * 365 * 86400;
    uint256 constant WEEK = 7 * 86400;
    uint256 tokenId;

    modifier assumeLockWithinBoundaries(uint256 lockAmount, uint256 lockEndpoint) {
        _;
    }

    function setUp() public override {
        super.setUp();
    }

    function testFuzz_CreateLockBasic(uint256 lockAmount, uint256 lockEndpoint) public {
        bool boundaryAssumptions = (
            lockEndpoint > block.timestamp + WEEK
            && lockEndpoint <= block.timestamp + MAXTIME
            && lockAmount > 0
            && lockAmount <= ctmBal0
        );
        vm.assume(boundaryAssumptions);
        vm.prank(user0);
        tokenId = ve.create_lock(lockAmount, lockEndpoint);
    }

    function testFuzz_IncreaseLockAmount(uint256 amountIncrease) public {
        uint256 lockAmount = 1 ether;
        uint256 lockEndpoint = block.timestamp + WEEK;
        bool boundaryAssumptions = (
            amountIncrease > 0
            && amountIncrease <= (ctmBal0 - lockAmount)
        );
        vm.assume(boundaryAssumptions);
        vm.startPrank(user0);
        tokenId = ve.create_lock(lockAmount, lockEndpoint);
        ve.increase_amount(tokenId, amountIncrease);
        vm.stopPrank();
    }

    function testFuzz_IncreaseLockTime(uint256 increasedTime) public {
        uint256 lockAmount = ctmBal0;
        uint256 lockEndpoint = block.timestamp + WEEK;
        bool boundaryAssumptions = (
            increasedTime > lockEndpoint + WEEK
            && increasedTime <= block.timestamp + MAXTIME
        );
        vm.assume(boundaryAssumptions);
        vm.startPrank(user0);
        tokenId = ve.create_lock(lockAmount, lockEndpoint);
        ve.increase_unlock_time(tokenId, increasedTime);
        vm.stopPrank();
    }

    // function test_IncreaseLockAmountAndIncreaseLockTime() public {}
    // function test_RemoveExpiredTokens() public {}

    function logLockDetailsAtTs(uint256 _tokenId, uint256 ts) public view {
        uint256 votingPowerTs = ve.balanceOfNFTAt(_tokenId, ts);
        console.log("Voting Power of lock at current ts: %s", votingPowerTs);
    }
}
