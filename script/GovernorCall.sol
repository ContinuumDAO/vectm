// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import "forge-std/console.sol";
import {IGovernor} from "build/CTMDAOGovernor.sol";

contract GovernorCall is Script {
    address governorAddr = 0x8582805645C1FC0B009231CA858e6CEfA708569D;
    IGovernor governor = IGovernor(governorAddr);

    address rewards = 0x9dD62AA5dC3A3d4F8aC9DE7E22Aa6791b4af2303;

    function run() external {

        uint256 senderPrivateKey = vm.envUint("PRIVATE_KEY");
        address sender = vm.addr(senderPrivateKey);

        vm.startBroadcast(senderPrivateKey);

        address[] memory targets = new address[](2);
        uint256[] memory values = new uint256[](2);
        bytes[] memory calldatas = new bytes[](2);
        targets[0] = rewards;
        targets[1] = rewards;
        values[0] = 0;
        values[1] = 0;
        calldatas[0] = abi.encodeWithSignature(
            "setRewardToken(address,uint8,address)",
            0xcf4CDfa3003083f0A340a7a996d7e4dFFCC7b8cf,
            1712102400,
            sender
        );
        calldatas[1] = abi.encodeWithSignature(
            "setFeeToken(address,address)",
            0x9Da2063ffD5F1d16728A1FC1f8d2451A2c29Dd85,
            sender
        );
        string memory description = "Proposal #1: Set reward token to CTM and fee token to USDT.";

        console.log(description);

        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        console.log("Proposal ID: ", proposalId);

        vm.stopBroadcast();
    }
}