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

    function setUp() public virtual {
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
    uint256 constant MAXTIME = 4 * 365 * 86400;
    uint256 tokenId;

    function setUp() public override {
        super.setUp();
        tokenId = ve.create_lock(1 ether, MAXTIME);
    }

    function test_CreateLockBasic() public {
        uint256 votingPowerBlk = ve.balanceOfAtNFT(tokenId, block.number);
        uint256 votingPowerTs = ve.balanceOfNFTAt(tokenId, block.timestamp);
        int256 last_slope = ve.get_last_user_slope(tokenId);
        // assertEq(votingPower, 1 ether);
        // console.log("Token ID of lock: %s", tokenId);
        // console.log("Voting Power of lock blk: %s", votingPowerBlk);
        // console.log("Voting Power of lock ts: %s", votingPowerTs);
        console.logInt(last_slope);
    }

    // function test_IncreaseLockAmount() public {}
    // function test_IncreaseLockTime() public {}
    // function test_RemoveExpiredTokens() public {}
}
