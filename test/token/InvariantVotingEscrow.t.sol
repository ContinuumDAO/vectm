// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import { console } from "forge-std/console.sol";
import { StdInvariant } from "forge-std/StdInvariant.sol";
import { Test } from "forge-std/Test.sol";

import { Helpers } from "../helpers/Helpers.sol";

import { IVotingEscrow } from "../../src/token/IVotingEscrow.sol";

// BUG: #5 Structural week-ratcheting suppresses intended decay
// TESTING:
contract MergeSplitHandler is Test {
    IVotingEscrow ve;
    uint256 id1;
    uint256 id2;
    address user1;

    uint256 public referenceEnd;
    // uint256 public referenceEnd2;
    uint256 public latestEnd1;
    uint256 public latestEnd2;

    // alternate between merge and split
    uint8 constant MERGE_OP = 1;
    uint8 constant SPLIT_OP = 2;

    uint8 public op = 1; // start with merge

    uint256 constant MAXTIME = 4 * 365 * 86_400;

    modifier flipOp() {
        _;
        op = op == MERGE_OP ? SPLIT_OP : MERGE_OP;
        skip(1);
    }

    constructor(address _ve, uint256 _id1, uint256 _id2, address _user1) {
        ve = IVotingEscrow(_ve);
        id1 = _id1;
        id2 = _id2;
        user1 = _user1;
    }

    function execOp(uint256 _amount) public flipOp {
        (, referenceEnd) = ve.locked(id1);
        if (op == MERGE_OP) {
            // (, referenceEnd2) = ve.locked(id2);
            merge();
        } else if (op == SPLIT_OP) {
            split(_amount);
        }
    }

    function merge() public {
        vm.prank(user1);
        ve.merge(id2, id1);
        (, latestEnd1) = ve.locked(id1);
    }

    function split(uint256 _amount) public {
        // NOTE: bound amount to between 1 and lock amount - 1
        (int256 lockAmount,) = ve.locked(id1);
        _amount = bound(_amount, 1, uint256(lockAmount - 1));

        vm.prank(user1);
        id2 = ve.split(id1, _amount);

        (, latestEnd1) = ve.locked(id1);
        (, latestEnd2) = ve.locked(id2);
    }
}

contract InvariantVotingEscrow is StdInvariant, Helpers {
    uint256 id1;
    uint256 id2;

    uint256 constant MAXTIME = 4 * 365 * 86_400;

    MergeSplitHandler mergeSplitHandler;

    function setUp() public override {
        super.setUp();
        vm.startPrank(address(ctmDaoGovernor));
        rewards.setBaseEmissionRate(0);
        rewards.setNodeEmissionRate(0);
        vm.stopPrank();

        vm.startPrank(user1);
        id1 = ve.create_lock(1000 ether, MAXTIME);
        skip(1);
        id2 = ve.create_lock(1000 ether, MAXTIME);
        skip(1);
        vm.stopPrank();

        mergeSplitHandler = new MergeSplitHandler(address(ve), id1, id2, user1);

        // target contract MergeSplitHandler
        targetContract(address(mergeSplitHandler));

        // target selectors merge and split
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MergeSplitHandler.execOp.selector;
        targetSelector(
            FuzzSelector({
                addr: address(mergeSplitHandler),
                selectors: selectors
            })
        );

        // target interface IVotingEscrow
        string[] memory artifacts = new string[](1);
        artifacts[0] = "MergeSplitHandler";
        targetInterface(
            FuzzInterface({
                addr: address(mergeSplitHandler),
                artifacts: artifacts
            })
        );

        // target sender user1
        targetSender(user1);
    }

    function invariant_LockEndDoesNotIncrease() public {
        uint8 nextOp = mergeSplitHandler.op();

        // NOTE: last operation was a merge or a split -> tokenId 1 always exists
        uint256 referenceEnd = mergeSplitHandler.referenceEnd();
        uint256 latestEnd1 = mergeSplitHandler.latestEnd1();
        assertLe(referenceEnd, latestEnd1);

        // NOTE: last operation was a split -> tokenId 2 
        if (nextOp == 1) {
            uint256 latestEnd2 = mergeSplitHandler.latestEnd2();
            assertLe(referenceEnd, latestEnd2);
        }
    }
}
