// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import {CTMDAOGovernor} from "../src/CTMDAOGovernor.sol";
import {IVotingEscrow, VotingEscrow} from "../src/VotingEscrow.sol";
import {VotingEscrowProxy} from "../src/VotingEscrowProxy.sol";
import {VotingEscrowV2} from "../src/VotingEscrowV2.sol";
import {CTM} from "../src/CTM.sol";
import {NodeProperties} from "../src/NodeProperties.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

interface IVotingEscrowUpgradable is IVotingEscrow {
    function upgradeToAndCall(address newImplementation, bytes memory data) external;
}

contract SetUp is Test {
    CTMDAOGovernor governor;
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
    uint256 CTM_TS = 100_000_000 ether;
    uint256 initialBalGov = CTM_TS;
    uint256 initialBalUser = CTM_TS;
    uint256 constant MAXTIME = 4 * 365 * 86400;
    uint256 constant ONE_YEAR = 365 * 86400;
    uint256 constant WEEK = 1 weeks;

    function setUp() public virtual {
        uint256 privKey1 = vm.deriveKey(MNEMONIC, 1);
        committee = vm.addr(privKey1);
        uint256 privKey2 = vm.deriveKey(MNEMONIC, 2);
        user = vm.addr(privKey2);

        ctm = new CTM(gov);
        veImplV1 = new VotingEscrow();
        bytes memory initializerData = abi.encodeWithSignature(
            "initialize(address,address,string)",
            address(ctm),
            BASE_URI_V1
        );
        veProxy = new VotingEscrowProxy(address(veImplV1), initializerData);

        governor = new CTMDAOGovernor(IVotes(address(veProxy)));
        gov = address(governor);

        ve = IVotingEscrowUpgradable(address(veProxy));
        ctm.print(user, initialBalUser);
        vm.prank(user);
        ctm.approve(address(ve), initialBalUser);
        
        nodeProperties = new NodeProperties(gov, committee, address(ve));
        vm.prank(gov);
        ve.setNodeProperties(address(nodeProperties));
    }

    modifier prank(address _user) {
        vm.startPrank(_user);
        _;
        vm.stopPrank();
    }
}

contract GovernorBasic is SetUp {}