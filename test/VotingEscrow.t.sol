// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import {IVotingEscrow, VotingEscrow} from "../src/VotingEscrow.sol";
import {VotingEscrowV2} from "../src/VotingEscrowV2.sol";
import {VotingEscrowProxy} from "../src/VotingEscrowProxy.sol";
import {CTM} from "../src/CTM.sol";
import {NodeProperties} from "../src/NodeProperties.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

interface IVotingEscrowUpgradable is IVotingEscrow {
    function upgradeToAndCall(address newImplementation, bytes memory data) external;
}

contract SetUp is Test {
    CTM ctm;
    VotingEscrow veImplV1;
    VotingEscrowProxy veProxy;
    IVotingEscrowUpgradable ve;
    NodeProperties nodeProperties;
    string constant MNEMONIC = "test test test test test test test test test test test junk";
    string constant BASE_URI_V1 = "veCTM V1";
    address gov;
    address committee;
    address user;
    uint256 ctmBalGov = 10 ether;
    uint256 ctmBalUser = 10 ether;
    uint256 constant MAXTIME = 4 * 365 * 86400;

    function setUp() public virtual {
        uint256 privKey0 = vm.deriveKey(MNEMONIC, 0);
        gov = vm.addr(privKey0);
        uint256 privKey1 = vm.deriveKey(MNEMONIC, 1);
        committee = vm.addr(privKey1);
        uint256 privKey2 = vm.deriveKey(MNEMONIC, 2);
        user = vm.addr(privKey2);

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
        
        nodeProperties = new NodeProperties(gov, committee, address(ve));
        vm.prank(gov);
        ve.setNodeProperties(address(nodeProperties));
    }

    modifier prankUser() {
        vm.startPrank(user);
        _;
        vm.stopPrank();
    }
}


contract CreateLock is SetUp {
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
        vm.expectRevert(Initializable.InvalidInitialization.selector);
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
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        ve.upgradeToAndCall(address(veImplV2), initializerDataV2);
    }
}


contract Votes is SetUp {
    address user2;
    uint256 id1;
    uint256 id2;
    uint256 id3;
    uint256 id4;

    // UTILS
    modifier prankGov() {
        vm.startPrank(gov);
        _;
        vm.stopPrank();
    }

    function setUp() public override {
        super.setUp();

        uint256 privKey3 = vm.deriveKey(MNEMONIC, 3);
        user2 = vm.addr(privKey3);

        ctm.print(user2, ctmBalUser);
        vm.prank(user2);
        ctm.approve(address(ve), ctmBalUser);

        ctm.print(gov, ctmBalGov);
        vm.prank(gov);
        ctm.approve(address(ve), ctmBalGov);
    }

    function _displayCheckpointInfo(address user) internal view {
         (bool exists, uint256 ts, uint256[] memory values, uint256 length) = ve.returnCheckpointInfo(user);
        console.log("exists ", exists);
        console.log("ts ", ts);
        console.log("length ", length);
        for (uint8 i = 0; i < values.length; i++) {
            console.log("values ", i, ":", values[i]);
        }
        console.log("################");      
    }

    function _warp1() internal {
        vm.warp(block.timestamp + 1);
    }

    // TESTS
    function test_FailSameTimestamp() public prankUser {
        id1 = ve.create_lock(1 ether, block.timestamp + MAXTIME);
        vm.expectRevert(VotingEscrow.SameTimestamp.selector);
        id2 = ve.create_lock(1 ether, block.timestamp + MAXTIME);
    }

    function test_DelegateTokensOnCreation() public {
        vm.startPrank(user);

        console.log("Pre-check: User and user2 should have no delegated tokens");
        uint256[] memory userDelegatedIDs = ve.tokenIdsDelegatedTo(user);
        uint256[] memory user2DelegatedIDs = ve.tokenIdsDelegatedTo(user2);
        assertEq(userDelegatedIDs.length, 0);
        assertEq(user2DelegatedIDs.length, 0);
        _warp1();

        console.log("Create token 1: User should have one delegated (1), one owned (1)");
        id1 = ve.create_lock(1 ether, block.timestamp + MAXTIME);
        userDelegatedIDs = ve.tokenIdsDelegatedTo(user);
        assertEq(userDelegatedIDs.length, 1);
        assertEq(userDelegatedIDs[0], id1);
        _warp1();

        console.log("Create token 2: User should have two delegated (1,2), two owned (1,2)");
        id2 = ve.create_lock(1 ether, block.timestamp + MAXTIME);
        userDelegatedIDs = ve.tokenIdsDelegatedTo(user);
        assertEq(userDelegatedIDs.length, 2);
        assertEq(userDelegatedIDs[0], id1);
        assertEq(userDelegatedIDs[1], id2);
        _warp1();

        console.log("Delegate user => user2: User should have zero delegated, two owned (1,2) and user2 should have two delegated (1,2)");
        ve.delegate(user2);
        userDelegatedIDs = ve.tokenIdsDelegatedTo(user);
        user2DelegatedIDs = ve.tokenIdsDelegatedTo(user2);
        assertEq(userDelegatedIDs.length, 0);
        assertEq(user2DelegatedIDs.length, 2);
        assertEq(user2DelegatedIDs[0], id1);
        assertEq(user2DelegatedIDs[1], id2);
        assertEq(ve.ownerOf(id1), user);
        assertEq(ve.ownerOf(id2), user);
        _warp1();

        console.log("Create token 3: User should have zero delegated, three owned (1,2,3) and user2 should have three delegated (1,2,3)");
        id3 = ve.create_lock(1 ether, block.timestamp + MAXTIME);
        userDelegatedIDs = ve.tokenIdsDelegatedTo(user);
        user2DelegatedIDs = ve.tokenIdsDelegatedTo(user2);
        assertEq(userDelegatedIDs.length, 0);
        assertEq(user2DelegatedIDs.length, 3);
        assertEq(user2DelegatedIDs[0], id1);
        assertEq(user2DelegatedIDs[1], id2);
        assertEq(user2DelegatedIDs[2], id3);
        assertEq(ve.ownerOf(id1), user);
        assertEq(ve.ownerOf(id2), user);
        assertEq(ve.ownerOf(id3), user);
        _warp1();

        console.log("Transfer token 2: User should have zero delegated, two owned (1,3) and user2 should have two delegated (1,3), one owned (2)");
        ve.transferFrom(user, user2, id2);
        userDelegatedIDs = ve.tokenIdsDelegatedTo(user);
        user2DelegatedIDs = ve.tokenIdsDelegatedTo(user2); 
        assertEq(userDelegatedIDs.length, 0);
        assertEq(user2DelegatedIDs.length, 2);
        assertEq(user2DelegatedIDs[0], id1);
        assertEq(user2DelegatedIDs[1], id3);
        assertEq(ve.ownerOf(id1), user);
        assertEq(ve.ownerOf(id2), user2);
        assertEq(ve.ownerOf(id3), user);
        _warp1();

        vm.stopPrank();
        vm.startPrank(user2);

        console.log("Delegate user2 => user2: User should have zero delegated, two owned (1,3) and user2 should have three delegated (1,3,2), one owned (2)");
        ve.delegate(user2);
        userDelegatedIDs = ve.tokenIdsDelegatedTo(user);
        user2DelegatedIDs = ve.tokenIdsDelegatedTo(user2); 
        assertEq(userDelegatedIDs.length, 0);
        assertEq(user2DelegatedIDs.length, 3);
        assertEq(user2DelegatedIDs[0], id1);
        assertEq(user2DelegatedIDs[1], id3);
        assertEq(user2DelegatedIDs[2], id2);
        assertEq(ve.ownerOf(id1), user);
        assertEq(ve.ownerOf(id2), user2);
        assertEq(ve.ownerOf(id3), user);
        _warp1();

        console.log("Create token 4: User should have zero delegated, two owned (1,3) and user2 should have four delegated (1,3,2,4), two owned (2,4)");
        id4 = ve.create_lock(1 ether, block.timestamp + MAXTIME);
        userDelegatedIDs = ve.tokenIdsDelegatedTo(user);
        user2DelegatedIDs = ve.tokenIdsDelegatedTo(user2); 
        assertEq(userDelegatedIDs.length, 0);
        assertEq(user2DelegatedIDs.length, 4);
        assertEq(user2DelegatedIDs[0], id1);
        assertEq(user2DelegatedIDs[1], id3);
        assertEq(user2DelegatedIDs[2], id2);
        assertEq(user2DelegatedIDs[3], id4);
        assertEq(ve.ownerOf(id1), user);
        assertEq(ve.ownerOf(id2), user2);
        assertEq(ve.ownerOf(id3), user);
        assertEq(ve.ownerOf(id4), user2);
        _warp1();

        console.log("Delegate user2 => user: User should have two delegated, two owned (1,3) and user2 should have two delegated (1,3), two owned (2,4)");
        ve.delegate(user);
        userDelegatedIDs = ve.tokenIdsDelegatedTo(user);
        user2DelegatedIDs = ve.tokenIdsDelegatedTo(user2); 
        assertEq(userDelegatedIDs.length, 2);
        assertEq(user2DelegatedIDs.length, 2);
        assertEq(userDelegatedIDs[0], id2);
        assertEq(userDelegatedIDs[1], id4);
        assertEq(user2DelegatedIDs[0], id1);
        assertEq(user2DelegatedIDs[1], id3);
        assertEq(ve.ownerOf(id1), user);
        assertEq(ve.ownerOf(id2), user2);
        assertEq(ve.ownerOf(id3), user);
        assertEq(ve.ownerOf(id4), user2);

        vm.stopPrank();
    }

    // function test_Delegate

    function test_GetVotes() public {
        // test that get votes by address returns vote power equivalent to vote power of all delegated NFTs
    }
}