// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import "forge-std/console.sol";
import {IGovernor} from "build/CTMDAOGovernor.sol";

contract Proposal is Script {
    address governorAddr = 0x1271D5C10663a0e34aFD1Ae5362EB9E29b1E3d97;
    IGovernor governor = IGovernor(governorAddr);

    address ctmAddr = 0xADeE65208A9fd9d6d47AD2D8A53D7E019955d1Db;

    function run() external {

        uint256 senderPrivateKey = vm.envUint("PRIVATE_KEY");
        address senderAccount = vm.addr(senderPrivateKey);

        vm.startBroadcast(senderPrivateKey);

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        targets[0] = ctmAddr;
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("transfer(address,uint256)", senderAccount, 1 ether);

        string memory description = "Proposal #4: Transfer 1 CTM from Governor to me";

        governor.propose(targets, values, calldatas, description);

        vm.stopBroadcast();
    }
}