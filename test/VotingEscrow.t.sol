// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import {VotingEscrow} from "../src/VotingEscrow.sol";
import {IVotingEscrow} from "../src/IVotingEscrow.sol";
import {VotingEscrowProxy} from "../src/VotingEscrowProxy.sol";
import {CTM} from "../src/CTM.sol";

contract SetUp is Test {
    CTM ctm;
    VotingEscrow veImpl;
    VotingEscrowProxy veProxy;
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
        veImpl = new VotingEscrow();
        bytes memory initializerData = abi.encodeWithSignature("initialize(address,address,string)", address(ctm), user0, "<BASE_URI>");
        veProxy = new VotingEscrowProxy(address(veImpl), initializerData);
        ve = VotingEscrow(address(veImpl));
        ctm.print(user0, ctmBal0);
        vm.prank(user0);
        ctm.approve(address(ve), ctmBal0);
    }
}


contract CreateLock is SetUp {
    uint256 constant MAXTIME = 4 * 365 * 86400;
    uint256 tokenId;

    // UTILS

    modifier prankUser0() {
        vm.startPrank(user0);
        _;
        vm.stopPrank();
    }

    function setUp() public override {
        super.setUp();
    }


    // TESTS

    function testFuzz_CreateLockBasic(uint256 amount, uint256 endpoint) public prankUser0 {
        amount = bound(amount, 1, ctmBal0);
        endpoint = bound(endpoint, block.timestamp + 1 weeks, block.timestamp + MAXTIME);
        tokenId = ve.create_lock(amount, endpoint);
    }

    function testFuzz_IncreaseLockAmount(uint256 amount, uint256 endpoint, uint256 amountIncrease) public prankUser0 {
        amount = bound(amount, 1, ctmBal0 - 1);
        endpoint = bound(endpoint, block.timestamp + 1 weeks, block.timestamp + MAXTIME);
        amountIncrease = bound(amountIncrease, 1, ctmBal0 - amount);
        tokenId = ve.create_lock(amount, endpoint);
        ve.increase_amount(tokenId, amountIncrease);
    }

    function testFuzz_IncreaseLockTime(uint256 amount, uint256 endpoint, uint256 increasedTime) public prankUser0 {
        amount = bound(amount, 1, ctmBal0);
        endpoint = bound(endpoint, block.timestamp + 1 weeks, block.timestamp + MAXTIME - 1 weeks);
        increasedTime = bound(increasedTime, endpoint + 1 weeks, block.timestamp + MAXTIME);
        tokenId = ve.create_lock(amount, endpoint);
        ve.increase_unlock_time(tokenId, increasedTime);
    }

    function testFuzz_IncreaseLockAmountAndIncreaseLockTime(uint256 amount, uint256 endpoint, uint256 amountIncrease, uint256 increasedTime) public prankUser0 {
        amount = bound(amount, 1, ctmBal0 - 1);
        endpoint = bound(endpoint, block.timestamp + 1 weeks, block.timestamp + MAXTIME - 1 weeks);
        amountIncrease = bound(amountIncrease, 1, ctmBal0 - amount);
        increasedTime = bound(increasedTime, endpoint + 1 weeks, block.timestamp + MAXTIME);
        tokenId = ve.create_lock(amount, endpoint);
        ve.increase_amount(tokenId, amountIncrease);
        ve.increase_unlock_time(tokenId, increasedTime);
    }

    function testFuzz_WithdrawExpiredLock(uint256 amount, uint256 endpoint, uint256 removalTime) public prankUser0 {
        amount = bound(amount, 1, ctmBal0);
        endpoint = bound(endpoint, block.timestamp + 1 weeks, block.timestamp + MAXTIME);
        vm.assume(removalTime >= endpoint);
        tokenId = ve.create_lock(amount, endpoint);
        vm.warp(removalTime);
        ve.withdraw(tokenId);
    }
}


contract Proxy is SetUp {
    function setUp() public override {
        super.setUp();
    }

    function test_SetUpPass() public view {
        string memory baseURI = VotingEscrow(address(veProxy)).baseURI();
        console.log(baseURI);
    }
}