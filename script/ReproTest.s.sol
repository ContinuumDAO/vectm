// SPDX-License-Identifier: UNLICENSED
//
// Minimal local deployment to test historic timestamp checks (getPastTotalSupply,
// balanceOfNFTAt). Same scenario as ReproduceGetPastTotalSupplyBug.s.sol but
// without forking: deploy token + VE + mocks, create two locks, merge, then
// query at a past time. With the fix in place, both calls succeed and return
// correct values.
//
// Run: forge script script/ReproTest.s.sol:ReproTest --sig "run()"

pragma solidity 0.8.27;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {IVotingEscrow} from "../src/token/IVotingEscrow.sol";
import {VotingEscrow} from "../src/token/VotingEscrow.sol";
import {VotingEscrowProxy} from "../src/utils/VotingEscrowProxy.sol";

/// @notice Minimal ERC20 with mint for testing
contract MockERC20 is ERC20 {
    constructor() ERC20("Mock", "MOCK") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @notice Minimal stub so merge() passes checkNotAttached
contract MockNodeProperties {
    function attachedNodeId(uint256) external pure returns (bytes32) {
        return bytes32(0);
    }
}

/// @notice Minimal stub so merge() passes checkNoRewards
contract MockRewards {
    function unclaimedRewards(uint256) external pure returns (uint256) {
        return 0;
    }
}

contract ReproTest is Script {
    uint256 constant MAXTIME = 4 * 365 * 86_400;

    function run() public {
        address user = vm.addr(1);
        vm.deal(user, 1 ether);

        MockERC20 token = new MockERC20();
        token.mint(user, 1000 ether);

        VotingEscrow veImpl = new VotingEscrow();
        bytes memory veInit =
            abi.encodeWithSelector(VotingEscrow.initialize.selector, address(token), "https://example.com/");
        VotingEscrowProxy veProxy = new VotingEscrowProxy(address(veImpl), veInit);
        IVotingEscrow ve = IVotingEscrow(address(veProxy));

        MockNodeProperties mockNode = new MockNodeProperties();
        MockRewards mockRewards = new MockRewards();
        address treasury = address(0x1);
        address governor = vm.addr(2);
        ve.initContracts(governor, address(mockNode), address(mockRewards), treasury);
        vm.prank(governor);
        ve.setMinimumLock(1);

        vm.startPrank(user);
        token.approve(address(ve), type(uint256).max);

        uint256 unlockTime = (block.timestamp + MAXTIME) / (1 weeks) * (1 weeks);
        uint256 id1 = ve.create_lock(500 ether, unlockTime - block.timestamp);
        vm.warp(block.timestamp + 1);
        uint256 id2 = ve.create_lock(500 ether, unlockTime - block.timestamp);

        uint256 snapshotBeforeMerge = block.timestamp;
        uint256 correctBalanceId2AtPastTime = ve.balanceOfNFTAt(id2, snapshotBeforeMerge);
        console.log("Snapshot (past time we will query):", snapshotBeforeMerge);
        console.log("id2 balance at snapshot (correct value):", correctBalanceId2AtPastTime);

        vm.warp(block.timestamp + 10);
        ve.merge(id1, id2);

        uint256 currentEpoch = ve.epoch();
        (,, uint256 pointTs,) = ve.point_history(currentEpoch);
        uint256 timepointToQuery = pointTs - 10;
        console.log("point_history[epoch].ts after merge:", pointTs);
        console.log("timepointToQuery:", timepointToQuery);

        uint256 totalSupplyAtPast = IVotes(address(ve)).getPastTotalSupply(timepointToQuery);
        console.log("getPastTotalSupply(timepointToQuery):", totalSupplyAtPast);

        uint256 balanceAtPast = ve.balanceOfNFTAt(id2, timepointToQuery);
        console.log("balanceOfNFTAt(id2, timepointToQuery):", balanceAtPast);

        require(balanceAtPast == correctBalanceId2AtPastTime, "balanceOfNFTAt should equal correct past balance");

        console.log("OK: historic timestamp checks passed (fix verified).");
    }
}
