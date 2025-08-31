export const RewardsABI = [
    {
        "type": "constructor",
        "inputs": [
            {
                "name": "_firstMidnight",
                "type": "uint48",
                "internalType": "uint48"
            },
            {
                "name": "_ve",
                "type": "address",
                "internalType": "address"
            },
            {
                "name": "_gov",
                "type": "address",
                "internalType": "address"
            },
            {
                "name": "_rewardToken",
                "type": "address",
                "internalType": "address"
            },
            {
                "name": "_feeToken",
                "type": "address",
                "internalType": "address"
            },
            {
                "name": "_swapRouter",
                "type": "address",
                "internalType": "address"
            },
            {
                "name": "_nodeProperties",
                "type": "address",
                "internalType": "address"
            },
            {
                "name": "_weth",
                "type": "address",
                "internalType": "address"
            },
            {
                "name": "_baseEmissionRate",
                "type": "uint256",
                "internalType": "uint256"
            },
            {
                "name": "_nodeEmissionRate",
                "type": "uint256",
                "internalType": "uint256"
            },
            {
                "name": "_nodeRewardThreshold",
                "type": "uint256",
                "internalType": "uint256"
            },
            {
                "name": "_feePerByteRewardToken",
                "type": "uint256",
                "internalType": "uint256"
            },
            {
                "name": "_feePerByteFeeToken",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "stateMutability": "nonpayable"
    },
    {
        "type": "function",
        "name": "MULTIPLIER",
        "inputs": [],
        "outputs": [
            {
                "name": "",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "ONE_DAY",
        "inputs": [],
        "outputs": [
            {
                "name": "",
                "type": "uint48",
                "internalType": "uint48"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "WETH",
        "inputs": [],
        "outputs": [
            {
                "name": "",
                "type": "address",
                "internalType": "address"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "baseEmissionRate",
        "inputs": [],
        "outputs": [
            {
                "name": "",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "baseEmissionRateAt",
        "inputs": [
            {
                "name": "_timestamp",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "outputs": [
            {
                "name": "",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "claimRewards",
        "inputs": [
            {
                "name": "_tokenId",
                "type": "uint256",
                "internalType": "uint256"
            },
            {
                "name": "_to",
                "type": "address",
                "internalType": "address"
            }
        ],
        "outputs": [
            {
                "name": "",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "stateMutability": "nonpayable"
    },
    {
        "type": "function",
        "name": "compoundLockRewards",
        "inputs": [
            {
                "name": "_tokenId",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "outputs": [
            {
                "name": "",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "stateMutability": "nonpayable"
    },
    {
        "type": "function",
        "name": "feePerByteFeeToken",
        "inputs": [],
        "outputs": [
            {
                "name": "",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "feePerByteRewardToken",
        "inputs": [],
        "outputs": [
            {
                "name": "",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "feeToken",
        "inputs": [],
        "outputs": [
            {
                "name": "",
                "type": "address",
                "internalType": "address"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "genesis",
        "inputs": [],
        "outputs": [
            {
                "name": "",
                "type": "uint48",
                "internalType": "uint48"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "gov",
        "inputs": [],
        "outputs": [
            {
                "name": "",
                "type": "address",
                "internalType": "address"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "latestMidnight",
        "inputs": [],
        "outputs": [
            {
                "name": "",
                "type": "uint48",
                "internalType": "uint48"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "nodeEmissionRate",
        "inputs": [],
        "outputs": [
            {
                "name": "",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "nodeEmissionRateAt",
        "inputs": [
            {
                "name": "_timestamp",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "outputs": [
            {
                "name": "",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "nodeProperties",
        "inputs": [],
        "outputs": [
            {
                "name": "",
                "type": "address",
                "internalType": "address"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "nodeRewardThreshold",
        "inputs": [],
        "outputs": [
            {
                "name": "",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "nodeRewardThresholdAt",
        "inputs": [
            {
                "name": "_timestamp",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "outputs": [
            {
                "name": "",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "receiveFees",
        "inputs": [
            {
                "name": "_token",
                "type": "address",
                "internalType": "address"
            },
            {
                "name": "_amount",
                "type": "uint256",
                "internalType": "uint256"
            },
            {
                "name": "_fromChainId",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "outputs": [],
        "stateMutability": "nonpayable"
    },
    {
        "type": "function",
        "name": "rewardToken",
        "inputs": [],
        "outputs": [
            {
                "name": "",
                "type": "address",
                "internalType": "address"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "setBaseEmissionRate",
        "inputs": [
            {
                "name": "_baseEmissionRate",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "outputs": [],
        "stateMutability": "nonpayable"
    },
    {
        "type": "function",
        "name": "setFeePerByteFeeToken",
        "inputs": [
            {
                "name": "_fee",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "outputs": [],
        "stateMutability": "nonpayable"
    },
    {
        "type": "function",
        "name": "setFeePerByteRewardToken",
        "inputs": [
            {
                "name": "_fee",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "outputs": [],
        "stateMutability": "nonpayable"
    },
    {
        "type": "function",
        "name": "setFeeToken",
        "inputs": [
            {
                "name": "_feeToken",
                "type": "address",
                "internalType": "address"
            },
            {
                "name": "_recipient",
                "type": "address",
                "internalType": "address"
            }
        ],
        "outputs": [],
        "stateMutability": "nonpayable"
    },
    {
        "type": "function",
        "name": "setNodeEmissionRate",
        "inputs": [
            {
                "name": "_nodeEmissionRate",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "outputs": [],
        "stateMutability": "nonpayable"
    },
    {
        "type": "function",
        "name": "setNodeProperties",
        "inputs": [
            {
                "name": "_nodeProperties",
                "type": "address",
                "internalType": "address"
            }
        ],
        "outputs": [],
        "stateMutability": "nonpayable"
    },
    {
        "type": "function",
        "name": "setNodeRewardThreshold",
        "inputs": [
            {
                "name": "_nodeRewardThreshold",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "outputs": [],
        "stateMutability": "nonpayable"
    },
    {
        "type": "function",
        "name": "setRewardToken",
        "inputs": [
            {
                "name": "_rewardToken",
                "type": "address",
                "internalType": "address"
            },
            {
                "name": "_firstMidnight",
                "type": "uint48",
                "internalType": "uint48"
            },
            {
                "name": "_recipient",
                "type": "address",
                "internalType": "address"
            }
        ],
        "outputs": [],
        "stateMutability": "nonpayable"
    },
    {
        "type": "function",
        "name": "setSwapEnabled",
        "inputs": [
            {
                "name": "_enabled",
                "type": "bool",
                "internalType": "bool"
            }
        ],
        "outputs": [],
        "stateMutability": "nonpayable"
    },
    {
        "type": "function",
        "name": "swapFeeToReward",
        "inputs": [
            {
                "name": "_amountIn",
                "type": "uint256",
                "internalType": "uint256"
            },
            {
                "name": "_uniFeeWETH",
                "type": "uint256",
                "internalType": "uint256"
            },
            {
                "name": "_uniFeeReward",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "outputs": [
            {
                "name": "_amountOut",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "stateMutability": "nonpayable"
    },
    {
        "type": "function",
        "name": "swapRouter",
        "inputs": [],
        "outputs": [
            {
                "name": "",
                "type": "address",
                "internalType": "address"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "unclaimedRewards",
        "inputs": [
            {
                "name": "_tokenId",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "outputs": [
            {
                "name": "",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "updateLatestMidnight",
        "inputs": [],
        "outputs": [],
        "stateMutability": "nonpayable"
    },
    {
        "type": "function",
        "name": "ve",
        "inputs": [],
        "outputs": [
            {
                "name": "",
                "type": "address",
                "internalType": "address"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "withdrawToken",
        "inputs": [
            {
                "name": "_token",
                "type": "address",
                "internalType": "address"
            },
            {
                "name": "_recipient",
                "type": "address",
                "internalType": "address"
            },
            {
                "name": "_amount",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "outputs": [],
        "stateMutability": "nonpayable"
    },
    {
        "type": "event",
        "name": "BaseEmissionRateChange",
        "inputs": [
            {
                "name": "_oldBaseEmissionRate",
                "type": "uint256",
                "indexed": false,
                "internalType": "uint256"
            },
            {
                "name": "_newBaseEmissionRate",
                "type": "uint256",
                "indexed": false,
                "internalType": "uint256"
            }
        ],
        "anonymous": false
    },
    {
        "type": "event",
        "name": "Claim",
        "inputs": [
            {
                "name": "_tokenId",
                "type": "uint256",
                "indexed": true,
                "internalType": "uint256"
            },
            {
                "name": "_claimedReward",
                "type": "uint256",
                "indexed": false,
                "internalType": "uint256"
            },
            {
                "name": "_rewardToken",
                "type": "address",
                "indexed": true,
                "internalType": "address"
            }
        ],
        "anonymous": false
    },
    {
        "type": "event",
        "name": "FeeTokenChange",
        "inputs": [
            {
                "name": "_oldFeeToken",
                "type": "address",
                "indexed": true,
                "internalType": "address"
            },
            {
                "name": "_newFeeToken",
                "type": "address",
                "indexed": true,
                "internalType": "address"
            }
        ],
        "anonymous": false
    },
    {
        "type": "event",
        "name": "FeesReceived",
        "inputs": [
            {
                "name": "_token",
                "type": "address",
                "indexed": true,
                "internalType": "address"
            },
            {
                "name": "_amount",
                "type": "uint256",
                "indexed": false,
                "internalType": "uint256"
            },
            {
                "name": "_fromChainId",
                "type": "uint256",
                "indexed": true,
                "internalType": "uint256"
            }
        ],
        "anonymous": false
    },
    {
        "type": "event",
        "name": "NodeEmissionRateChange",
        "inputs": [
            {
                "name": "_oldNodeEmissionRate",
                "type": "uint256",
                "indexed": false,
                "internalType": "uint256"
            },
            {
                "name": "_newNodeEmissionRate",
                "type": "uint256",
                "indexed": false,
                "internalType": "uint256"
            }
        ],
        "anonymous": false
    },
    {
        "type": "event",
        "name": "NodeRewardThresholdChange",
        "inputs": [
            {
                "name": "_oldMinimumThreshold",
                "type": "uint256",
                "indexed": false,
                "internalType": "uint256"
            },
            {
                "name": "_newMinimumThreshold",
                "type": "uint256",
                "indexed": false,
                "internalType": "uint256"
            }
        ],
        "anonymous": false
    },
    {
        "type": "event",
        "name": "RewardTokenChange",
        "inputs": [
            {
                "name": "_oldRewardToken",
                "type": "address",
                "indexed": true,
                "internalType": "address"
            },
            {
                "name": "_newRewardToken",
                "type": "address",
                "indexed": true,
                "internalType": "address"
            }
        ],
        "anonymous": false
    },
    {
        "type": "event",
        "name": "Swap",
        "inputs": [
            {
                "name": "_feeToken",
                "type": "address",
                "indexed": true,
                "internalType": "address"
            },
            {
                "name": "_rewardToken",
                "type": "address",
                "indexed": true,
                "internalType": "address"
            },
            {
                "name": "_amountIn",
                "type": "uint256",
                "indexed": false,
                "internalType": "uint256"
            },
            {
                "name": "_amountOut",
                "type": "uint256",
                "indexed": false,
                "internalType": "uint256"
            }
        ],
        "anonymous": false
    },
    {
        "type": "event",
        "name": "Withdrawal",
        "inputs": [
            {
                "name": "_token",
                "type": "address",
                "indexed": true,
                "internalType": "address"
            },
            {
                "name": "_recipient",
                "type": "address",
                "indexed": true,
                "internalType": "address"
            },
            {
                "name": "_amount",
                "type": "uint256",
                "indexed": false,
                "internalType": "uint256"
            }
        ],
        "anonymous": false
    },
    {
        "type": "error",
        "name": "CheckpointUnorderedInsertion",
        "inputs": []
    },
    {
        "type": "error",
        "name": "Rewards_EmissionRateChangeTooHigh",
        "inputs": []
    },
    {
        "type": "error",
        "name": "Rewards_FeesAlreadyReceivedFromChain",
        "inputs": []
    },
    {
        "type": "error",
        "name": "Rewards_InsufficientContractBalance",
        "inputs": [
            {
                "name": "_balance",
                "type": "uint256",
                "internalType": "uint256"
            },
            {
                "name": "_required",
                "type": "uint256",
                "internalType": "uint256"
            }
        ]
    },
    {
        "type": "error",
        "name": "Rewards_InvalidToken",
        "inputs": [
            {
                "name": "_token",
                "type": "address",
                "internalType": "address"
            }
        ]
    },
    {
        "type": "error",
        "name": "Rewards_NoUnclaimedRewards",
        "inputs": []
    },
    {
        "type": "error",
        "name": "Rewards_OnlyAuthorized",
        "inputs": [
            {
                "name": "",
                "type": "uint8",
                "internalType": "enum VotingEscrowErrorParam"
            },
            {
                "name": "",
                "type": "uint8",
                "internalType": "enum VotingEscrowErrorParam"
            }
        ]
    },
    {
        "type": "error",
        "name": "Rewards_SwapDisabled",
        "inputs": []
    },
    {
        "type": "error",
        "name": "Rewards_TransferFailed",
        "inputs": []
    },
    {
        "type": "error",
        "name": "SafeCastOverflowedUintDowncast",
        "inputs": [
            {
                "name": "bits",
                "type": "uint8",
                "internalType": "uint8"
            },
            {
                "name": "value",
                "type": "uint256",
                "internalType": "uint256"
            }
        ]
    }
]