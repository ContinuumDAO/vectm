// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
import {TestERC20} from "build/TestERC20.sol";
import {VotingEscrow, IVotingEscrow} from "build/VotingEscrow.sol";
import {VotingEscrowProxy} from "build/VotingEscrowProxy.sol";
import {CTMDAOGovernor} from "build/CTMDAOGovernor.sol";
import {NodeProperties} from "build/NodeProperties.sol";
import {Rewards} from "build/Rewards.sol";

contract DeployAll is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        uint48 firstMidnight = 1712102400; // 2024/03/03 00:00:00Z
        address router = 0x101F443B4d1b059569D643917553c771E1b9663E; // ARB Sepolia
        address weth = 0x980B62Da83eFf3D4576C647993b0c1D7faf17c73; // ARB Sepolia
            
        uint256 baseEmissionRate = 1 ether / 2000; // 0.05%
        uint256 nodeEmissionRate = 1 ether / 1000; // 0.1%
        uint256 nodeRewardThreshold = 5000 ether; // 5000 CTM x 4 years, 10000 CTM x 2 years, etc.
        uint256 feePerByteRewardToken = 7_812_500 gwei; // 5e17 = 0.5 CTM, 64 byte message, 5e17 / 64 = 7.8e15
        uint256 feePerByteFeeToken = 3125; // 200_000 USDT = 0.2 USD, 64 byte message, 200_000 / 64 bytes = 3125;

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy CTM and other testnet tokens
        // 2. Deploy veCTM impl
        // 3. Deploy veCTM proxy, initializing with veCTM impl addr and base URI
        // 4. Deploy CTMDAOGovernor, with veCTM proxy address
        // 5. Deploy NodeProperties, with Governor and veCTM proxy
        // 6. Deploy Rewards, with first midnight, Governor, USDT, CTM, Router, veCTM proxy, NodeProperties, WETH
        // 7. Setup calls

        // 1
        TestERC20 ctm = new TestERC20("Continuum", "CTM", 18);
        TestERC20 usdt = new TestERC20("Tether USD", "USDT", 6);

        // 2
        VotingEscrow veImpl = new VotingEscrow();

        // 3
        bytes memory initializerData = abi.encodeWithSignature(
            "initialize(address,string)",
            address(ctm),
            "veCTM_URI"
        );

        VotingEscrowProxy veProxy = new VotingEscrowProxy(address(veImpl), initializerData);
        IVotingEscrow ve = IVotingEscrow(address(veProxy));

        // 4
        CTMDAOGovernor gov = new CTMDAOGovernor(address(ve));

        // 5
        NodeProperties nodeProperties = new NodeProperties(address(gov), address(ve));

        // 6
        Rewards rewards = new Rewards(
            firstMidnight,
            address(gov),
            address(ctm),
            address(usdt),
            router,
            address(ve),
            address(nodeProperties),
            weth,
            baseEmissionRate,
            nodeEmissionRate,
            nodeRewardThreshold,
            feePerByteRewardToken,
            feePerByteFeeToken
        );

        // 7
        ve.setUp(address(gov), address(nodeProperties), address(rewards), deployer);
        nodeProperties.setRewards(address(rewards));

        vm.stopBroadcast();

        console.log("Deployer: ", deployer);
        console.log("CTM: ", address(ctm));
        console.log("USDT: ", address(usdt));
        console.log("Voting Escrow: ", address(ve));
        console.log("Governor: ", address(gov));
        console.log("Node Properties: ", address(nodeProperties));
        console.log("Rewards: ", address(rewards));
    }
}