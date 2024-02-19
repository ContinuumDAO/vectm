// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import {Rewards} from "../src/Rewards.sol";
import {NodeProperties} from "../src/NodeProperties.sol";
import {VotingEscrowProxy} from "../src/VotingEscrowProxy.sol";
import {IVotingEscrow, VotingEscrow} from "../src/VotingEscrow.sol";
import {CTM} from "../src/CTM.sol";
import {TestERC20} from "../src/TestERC20.sol";

contract TestRewards is Test {
    CTM ctm;
    TestERC20 usdc;
    VotingEscrow veImpl;
    VotingEscrowProxy veProxy;
    IVotingEscrow ve;
    NodeProperties nodeProperties;
    Rewards rewards;
    string constant MNEMONIC = "test test test test test test test test test test test junk";
    string constant BASE_URI_V1 = "veCTM V1";
    address gov;
    address committee;
    address treasury;
    address user;
    uint256 CTM_TS = 100_000_000 ether;
    uint256 initialBalGov = CTM_TS;
    uint256 initialBalUser = CTM_TS;
    uint256 constant MAXTIME = 4 * 365 * 86400;
    uint256 constant ONE_YEAR = 365 * 86400;
    uint256 constant WEEK = 1 weeks;
    uint256 id1;
    uint256 id2;
    uint8 constant DEFAULT = uint8(NodeProperties.NodeValidationStatus.Default);
    uint8 constant PENDING = uint8(NodeProperties.NodeValidationStatus.Pending);
    uint8 constant APPROVED = uint8(NodeProperties.NodeValidationStatus.Approved);

    function setUp() public virtual {
        uint256 privKey0 = vm.deriveKey(MNEMONIC, 0);
        gov = vm.addr(privKey0);
        uint256 privKey1 = vm.deriveKey(MNEMONIC, 1);
        committee = vm.addr(privKey1);
        uint256 privKey2 = vm.deriveKey(MNEMONIC, 2);
        treasury = vm.addr(privKey2);
        uint256 privKey3 = vm.deriveKey(MNEMONIC, 3);
        user = vm.addr(privKey3);

        ctm = new CTM(gov);
        usdc = new TestERC20(6);
        veImpl = new VotingEscrow();
        bytes memory initializerData = abi.encodeWithSignature(
            "initialize(address,string)",
            address(ctm),
            BASE_URI_V1
        );
        veProxy = new VotingEscrowProxy(address(veImpl), initializerData);

        ve = IVotingEscrow(address(veProxy));
        ve.setGovernor(gov);
        ctm.print(user, initialBalUser);
        vm.prank(user);
        ctm.approve(address(ve), initialBalUser);
        
        nodeProperties = new NodeProperties(gov, committee, address(ve), 5000 ether);
        vm.startPrank(gov);
        ve.setTreasury(treasury);
        ve.setNodeProperties(address(nodeProperties));
        ve.enableLiquidations();
        vm.stopPrank();

        rewards = new Rewards(
            0,
            gov,
            address(ctm),
            address(usdc),
            address(0),
            address(ve),
            address(nodeProperties),
            address(0)
        );
    }

    modifier prank(address _user) {
        vm.startPrank(_user);
        _;
        vm.stopPrank();
    }
}