// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import {Test} from "forge-std/Test.sol";

import {Accounts} from "./Accounts.sol";
import {Deployer} from "./Deployer.sol";

contract Helpers is Test, Accounts, Deployer {
    uint256 constant CTM_TS = 100_000_000 ether;

    function setUp() public virtual {
        (admin, treasury, committee, user1, user2) =
            abi.decode(abi.encode(_getAccounts()), (address, address, address, address, address));
        (owner, proposer, voter1, voter2, voter3, voter4, other) =
            abi.decode(abi.encode(_getGovernanceAccounts()), (address, address, address, address, address, address, address));

        _deployUSDC();
        _deployCTM(admin);

        vm.deal(admin, 100 ether);
        vm.deal(treasury, 100 ether);
        vm.deal(committee, 100 ether);
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);

        vm.deal(owner, 100 ether);
        vm.deal(proposer, 100 ether);
        vm.deal(voter1, 100 ether);
        vm.deal(voter2, 100 ether);
        vm.deal(voter3, 100 ether);
        vm.deal(voter4, 100 ether);
        vm.deal(other, 100 ether);

        vm.startPrank(admin);

        _dealAllERC20(address(usdc), CTM_TS);
        _dealAllERC20(address(ctm), CTM_TS);

        vm.stopPrank();

        _deployC3Caller();
        _deployVotingEscrow();
        _deployCTMDAOGovernor(admin);
        _deployNodeProperties();
        _deployRewards();

        address[] memory spenders = new address[](4);
        spenders[0] = address(ve);
        spenders[1] = address(continuumDAO);
        spenders[2] = address(rewards);
        spenders[3] = address(nodeProperties);
        _approveAllERC20(address(usdc), spenders);
        _approveAllERC20(address(ctm), spenders);

        _initContracts(address(treasury));

        _fundRewards();
    }
}
