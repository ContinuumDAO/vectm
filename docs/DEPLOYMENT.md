# Deployment Guide for Voting Escrow

## Introduction

Dependencies: foundry

Verification: An Etherscan API V2 key,
see [here](https://docs.etherscan.io/etherscan-v2/v2-quickstart).

For security in deployment, this guide assumes that you are using an account
saved in a keystore, and that you have a password file saved locally.

Use a fresh wallet and ensure you have plenty of gas for deployment and
configuration.

See [Foundry keystores](https://getfoundry.sh/cast/reference/wallet).

## .env file

Modify .env for the following structure.

```
# RPCs
ARBITRUM_SEPOLIA_RPC_URL=https://sepolia-rollup.arbitrum.io/rpc

# Etherscan API Key V2
ETHERSCAN_API_KEY=

# Fee Token
FEE_TOKEN_421614=0xbF5356AdE7e5F775659F301b07c4Bc6961044b11

# WETH
WETH_421614=0x980B62Da83eFf3D4576C647993b0c1D7faf17c73

# Uniswap V3 Swap Router
SWAP_ROUTER_421614=

# Treasury
TREASURY_421614=0xb5981FADCD79992f580ccFdB981d9D850b27DC37
```

## Make Scripts Executable

```bash
chmod +x helpers/[0-9]*
chmod +x helpers/deploy/*
```

## Flatten the source directory

This is required for single-file verification on chains that do not support Etherscan and to facilitate remedial manual verification.

```bash
./helpers/0-flatten.sh
```

## Compilation

Use the compilation script to compile the flattened source code and scripts.

```bash
./helpers/1-clean.sh
./helpers/2-build-flattened.sh
./helpers/5-build-script.sh
```

## Deploy Contracts

Run the following script to deploy. This will first execute a simulation, then allow you elect to deploy all contracts to the given network (broadcast) and verify the contracts on Etherscan if possible.

```bash
./helpers/deploy/arbitrum-sepolia.sh <DEPLOYER> <PATH_TO_PASSWORD_FILE>
```

All contracts are now deployed and initialized; their addresses are accessible in `broadcast/<chain-id>/run-latest.json`.

All contracts have an upgradeable version (ERC1967 Universal Upgradeable Proxy
Standard). This is the version deployed by default.

Note: For the proxies, go to Etherscan and select
"Contract > More Options > Is this a proxy?" to link its implementation contract.

## Write Deployed Contracts to File

Run the JS helper found in `js-helpers/` to generate a
JSON file containing latest deployed contract addresses.

```bash
node js-helpers/save-contract-addresses.js
```

## Complete

The contracts are now deployed and verified on all test networks.

NOTE: The chosen deployment network for the contracts in this repository is
Arbitrum Sepolia:

- CTM
- VotingEscrow
- CTMDAOGovernor
- NodeProperties
- Rewards
