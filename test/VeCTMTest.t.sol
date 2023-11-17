// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import {VotingEscrowContinuum} from "../src/VotingEscrowContinuum.sol";
import {CTM} from "../src/CTM.sol";

contract VotingEscrowContinuumTest is Test {
    CTM public ctm;
    VotingEscrowContinuum public vectm;

    function setUp() public {
        ctm = new CTM();
        vectm = new VotingEscrowContinuum(address(ctm), "<BASE_URI>");
        ctm.approve(address(vectm), 10 ether);
    }

    // create a lock with a defined end date and amount, and check its status as time goes on
    function test_createLock() public {
        vm.deal(msg.sender, 10 ether);
    }
}
