// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import {VotingEscrowContinuum} from "../src/VotingEscrowContinuum.sol";
import {CTM} from "../src/CTM.sol";


contract VeCTMTest is Test {
    CTM ctm;
    VotingEscrowContinuum vectm;

    function setUp() public {
        ctm = new CTM();
        vectm = new VotingEscrowContinuum(address(ctm), "https://example.com/");
        ctm.print(address(this), 10 ether);
        ctm.approve(address(vectm), 10 ether);
    }

    function test_getURI() public {
        uint tokenId = vectm.create_lock(1 ether, block.timestamp + 2 weeks);
        string memory uri = vectm.tokenURI(tokenId);
        console.log(uri);
    }
}