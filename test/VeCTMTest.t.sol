// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import {VeCTM} from "../src/VeCTM.sol";


contract VeCTMTest is Test {
    VeCTM veCTM;

    function setUp() public {
        veCTM = new VeCTM();
    }
}