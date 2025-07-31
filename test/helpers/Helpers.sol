// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import {Test} from "forge-std/Test.sol";

import {Accounts} from "./Accounts.sol";
import {Deployer} from "./Deployer.sol";

contract Helpers is Test, Accounts, Deployer {
    function setUp() public virtual {
        (admin, gov, treasury, user1, user2) = abi.decode(
            abi.encode(_getAccounts()),
            (address, address, address, address, address)
        );

        usdc = _deployUSDC();

        vm.deal(admin, 100 ether);
        vm.deal(gov, 100 ether);

        vm.startPrank(gov);

        _deployC3Caller();

        _dealAllERC20(address(usdc), _100_000);
        _dealAllERC20(address(ctm), _100_000);

        vm.stopPrank();

        _deployCTM(admin);
        _deployVotingEscrow(address(ctm));
        _deployNodeProperties(admin, address(ve));
        _deployRewards(address(usdc), address(treasury), admin);
    }
}
