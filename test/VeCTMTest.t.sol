// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import {VotingEscrowContinuum} from "../src/VotingEscrowContinuum.sol";
import {CTM} from "../src/CTM.sol";

contract SetUp is Test {
    CTM public ctm;
    VotingEscrowContinuum public vectm;

    function setUp() public {
        ctm = new CTM();
        vectm = new VotingEscrowContinuum(address(ctm), "<BASE_URI>");
        ctm.approve(address(vectm), 10 ether);
    }
}


contract CreateLock is SetUp {
    function test_CreateLockBasic() public {
        ctm.print(msg.sender, 1 ether);
        uint256 tokenId = vectm.create_lock(1 ether, 208 weeks);
        uint256 votingPower = vectm.balanceOfAtNFT(tokenId, block.number);
        console.log("Token ID of lock: %s", tokenId);
        console.log("Voting Power of lock: %s", votingPower);
    }
}
