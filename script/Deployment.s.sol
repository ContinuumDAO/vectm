// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import "forge-std/console.sol";
import {IGovernor} from "build/CTMDAOGovernor.sol";

contract Deployment is Script {
    address governorAddr = 0x1271D5C10663a0e34aFD1Ae5362EB9E29b1E3d97;
    IGovernor governor = IGovernor(governorAddr);

    address ve = 0xAF0D3b20ac92e6825014549bB3FA937b3BF5731A;

    // VotingEscrow
    // setGov
    // (done)
    // setTreasury
    address treasury = governorAddr;
    // setNodeProperties
    address nodeProperties = 0x8A0475AF86f6E5a9B1A2f5839Dd6064AFeAf9b91;
    // enableLiquidations
    // set

    // Rewards
    // setBaseEmissionRate
    uint256 baseEmissionRate = 1 ether / 2000;
    // setNodeEmissionRate
    uint256 nodeEmissionRate = 1 ether / 1000;
    // setNodeRewardThreshold
    uint256 nodeRewardThreshold = 5000 ether;
    // setFeePerByteFeeToken
    uint256 feePerByteFeeToken = 3125; // 200_000 USDT = 0.2 USD, 64 byte message, 200_000 / 64 = 3125
    // setFeePerByteRewardToken
    uint256 feePerByteRewardToken = 7_812_500 gwei; // 5e17 = 0.5 CTM, 64 byte message, 5e17 / 64 = 7.8e15
    // setNodeProperties
    // address nodeProperties
    // setSwapEnabled
    bool swapEnabled = true;

    // NodeProperties
    // setRewards
    address rewards = 0x84762a8296c968b395ba92e34a3E0243DcDed2B8;
    // setCommittee
    address committee = 0xb5981FADCD79992f580ccFdB981d9D850b27DC37;


    function run() external {
        uint256 senderPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(senderPrivateKey);

        address[] memory targets = new address[](12);
        uint256[] memory values = new uint256[](12);
        bytes[] memory calldatas = new bytes[](12);
        string memory description = "Proposal #1: Initialize core contracts";

        targets[0] = ve;
        targets[1] = ve;
        targets[2] = ve;

        targets[3] = rewards;
        targets[4] = rewards;
        targets[5] = rewards;
        targets[6] = rewards;
        targets[7] = rewards;
        targets[8] = rewards;
        targets[9] = rewards;

        targets[10] = nodeProperties;
        targets[11] = nodeProperties;

        calldatas[0] = abi.encodeWithSignature("setTreasury(address)", treasury);
        calldatas[1] = abi.encodeWithSignature("setNodeProperties(address)", nodeProperties);
        calldatas[2] = abi.encodeWithSignature("enableLiquidations()");
        // calldatas[2] = bytes4(keccak256(bytes("enableLiquidations()")));

        calldatas[3] = abi.encodeWithSignature("setBaseEmissionRate(uint256)", baseEmissionRate);
        calldatas[4] = abi.encodeWithSignature("setNodeEmissionRate(uint256)", nodeEmissionRate);
        calldatas[5] = abi.encodeWithSignature("setNodeRewardThreshold(uint256)", nodeRewardThreshold);
        calldatas[6] = abi.encodeWithSignature("setFeePerByteFeeToken(uint256)", feePerByteFeeToken);
        calldatas[7] = abi.encodeWithSignature("setFeePerByteRewardToken(uint256)", feePerByteRewardToken);
        calldatas[8] = abi.encodeWithSignature("setNodeProperties(address)", nodeProperties);
        calldatas[9] = abi.encodeWithSignature("setSwapEnabled(bool)", true);

        calldatas[10] = abi.encodeWithSignature("setRewards(address)", rewards);
        calldatas[11] = abi.encodeWithSignature("setCommittee(address)", committee);

        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        vm.stopBroadcast();

        console.log(proposalId);
    }
}