// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import {VotingEscrow} from "../src/VotingEscrow.sol";
import {VotingEscrowV2} from "../src/VotingEscrowV2.sol";
import {IVotingEscrow} from "../src/IVotingEscrow.sol";
import {VotingEscrowProxy} from "../src/VotingEscrowProxy.sol";
import {CTM} from "../src/CTM.sol";

interface IVotingEscrowUpgradable is IVotingEscrow {
    function upgradeToAndCall(address newImplementation, bytes memory data) external;
}

contract SetUp is Test {
    CTM ctm;
    VotingEscrow veImplV1;
    VotingEscrowProxy veProxy;
    IVotingEscrowUpgradable ve;
    string constant MNEMONIC = "test test test test test test test test test test test junk";
    string constant BASE_URI_V1 = "veCTM V1";
    address gov;
    address user;
    uint256 ctmBalGov = 10 ether;
    uint256 ctmBalUser = 10 ether;

    function setUp() public virtual {
        uint256 privKey0 = vm.deriveKey(MNEMONIC, 0);
        gov = vm.addr(privKey0);
        uint256 privKey1 = vm.deriveKey(MNEMONIC, 1);
        user = vm.addr(privKey1);

        ctm = new CTM();
        veImplV1 = new VotingEscrow();
        bytes memory initializerData = abi.encodeWithSignature(
            "initialize(address,address,string)",
            address(ctm),
            gov,
            BASE_URI_V1
        );
        veProxy = new VotingEscrowProxy(address(veImplV1), initializerData);

        ve = IVotingEscrowUpgradable(address(veProxy));
        ctm.print(user, ctmBalUser);
        vm.prank(user);
        ctm.approve(address(ve), ctmBalUser);
    }

    modifier prankUser() {
        vm.startPrank(user);
        _;
        vm.stopPrank();
    }
}


contract CreateLock is SetUp {
    uint256 constant MAXTIME = 4 * 365 * 86400;
    uint256 tokenId;

    // UTILS
    function setUp() public override {
        super.setUp();
    }

    // TESTS
    function testFuzz_CreateLockBasic(uint256 amount, uint256 endpoint) public prankUser {
        amount = bound(amount, 1, ctmBalUser);
        endpoint = bound(endpoint, block.timestamp + 1 weeks, block.timestamp + MAXTIME);
        tokenId = ve.create_lock(amount, endpoint);
    }

    function testFuzz_IncreaseLockAmount(uint256 amount, uint256 endpoint, uint256 amountIncrease) public prankUser {
        amount = bound(amount, 1, ctmBalUser - 1);
        endpoint = bound(endpoint, block.timestamp + 1 weeks, block.timestamp + MAXTIME);
        amountIncrease = bound(amountIncrease, 1, ctmBalUser - amount);
        tokenId = ve.create_lock(amount, endpoint);
        ve.increase_amount(tokenId, amountIncrease);
    }

    function testFuzz_IncreaseLockTime(uint256 amount, uint256 endpoint, uint256 increasedTime) public prankUser {
        amount = bound(amount, 1, ctmBalUser);
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
    ) public prankUser {
        amount = bound(amount, 1, ctmBalUser - 1);
        endpoint = bound(endpoint, block.timestamp + 1 weeks, block.timestamp + MAXTIME - 1 weeks);
        amountIncrease = bound(amountIncrease, 1, ctmBalUser - amount);
        increasedTime = bound(increasedTime, endpoint + 1 weeks, block.timestamp + MAXTIME);
        tokenId = ve.create_lock(amount, endpoint);
        ve.increase_amount(tokenId, amountIncrease);
        ve.increase_unlock_time(tokenId, increasedTime);
    }

    function testFuzz_WithdrawExpiredLock(uint256 amount, uint256 endpoint, uint256 removalTime) public prankUser {
        amount = bound(amount, 1, ctmBalUser);
        endpoint = bound(endpoint, block.timestamp + 1 weeks, block.timestamp + MAXTIME);
        vm.assume(removalTime >= endpoint);
        tokenId = ve.create_lock(amount, endpoint);
        vm.warp(removalTime);
        ve.withdraw(tokenId);
    }
}


contract Proxy is SetUp {
    VotingEscrowV2 veImplV2;
    bytes initializerDataV2;
    string constant BASE_URI_V2 = "veCTM V2";

    error InvalidInitialization();

    // UTILS
    modifier prankGov() {
        vm.startPrank(gov);
        _;
        vm.stopPrank();
    }

    function setUp() public override {
        super.setUp();

        veImplV2 = new VotingEscrowV2();
        initializerDataV2 = abi.encodeWithSignature(
            "initialize(address,address,string)",
            address(ctm),
            gov,
            BASE_URI_V2
        );

        ctm.print(gov, ctmBalGov);
        vm.prank(gov);
        ctm.approve(address(ve), ctmBalGov);
    }

    // TESTS
    function test_InitializedStateEqualToInput() public {
        string memory baseURI = ve.baseURI();
        assertEq(baseURI, BASE_URI_V1);
    }

    function test_CannotInitializeTwice() public {
        vm.expectRevert(InvalidInitialization.selector);
        ve.initialize(address(ctm), gov, BASE_URI_V1);
    }

    function test_ValidUpgrade() public prankGov {
        ve.upgradeToAndCall(address(veImplV2), initializerDataV2);
        string memory baseURI = ve.baseURI();
        assertEq(baseURI, BASE_URI_V2);
    }

    function test_UnauthorizedUpgrade() public {
        vm.expectRevert("Only Governor is allowed to make upgrades");
        ve.upgradeToAndCall(address(veImplV2), initializerDataV2);
        string memory baseURI = ve.baseURI();
        assertEq(baseURI, BASE_URI_V1);
    }

    function test_CannotUpgradeToSameVersion() public prankGov {
        ve.upgradeToAndCall(address(veImplV2), initializerDataV2);
        string memory baseURI = ve.baseURI();
        assertEq(baseURI, BASE_URI_V2);
        veImplV2 = new VotingEscrowV2();
        vm.expectRevert(InvalidInitialization.selector);
        ve.upgradeToAndCall(address(veImplV2), initializerDataV2);
    }
}


contract Votes is SetUp {
    // UTILS
    modifier prankGov() {
        vm.startPrank(gov);
        _;
        vm.stopPrank();
    }

    function setUp() public override {
        super.setUp();

        ctm.print(gov, ctmBalGov);
        vm.prank(gov);
        ctm.approve(address(ve), ctmBalGov);
    }

    // TESTS
    function test_GetVotes() public {
        // test that get votes by address returns vote power equivalent to vote power of all delegated NFTs
    }
}