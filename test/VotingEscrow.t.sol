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

    function setUp() public {
        ctm = new CTM();
        ve = new VotingEscrow(address(ctm), "<BASE_URI>");
        ctm.print(msg.sender, 10 ether);
        ctm.approve(address(ve), 10 ether);
        string memory mnemonic = "test test test test test test test test test test test junk";
        uint256 privKey0 = vm.deriveKey(mnemonic, 0);
        uint256 privKey1 = vm.deriveKey(mnemonic, 1);
        uint256 privKey2 = vm.deriveKey(mnemonic, 2);
        user0 = vm.addr(privKey0);
        user1 = vm.addr(privKey1);
        user2 = vm.addr(privKey2);
    }
}


contract CreateLock is SetUp {
    function test_CreateLockBasic() public {
        uint256 MAXTIME = 4 * 365 * 86400;
        uint256 tokenId = ve.create_lock(1 ether, MAXTIME);
        uint256 votingPower = ve.balanceOfAtNFT(tokenId, block.number);
        console.log("Token ID of lock: %s", tokenId);
        console.log("Voting Power of lock: %s", votingPower);
    }

    function test_IncreaseLockAmount() public {}
    function test_IncreaseLockTime() public {}
    function test_RemoveExpiredTokens() public {}
}
