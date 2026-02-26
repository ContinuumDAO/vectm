#!/bin/bash

# Get the deployer address from the first argument
DEPLOYER=$1

# Check if the deployer address is provided
if [ -z "$DEPLOYER" ]; then
    echo "Error: Deployer address is required"
    echo "Usage: $0 <deployer_address>"
    echo "You will be prompted for the keystore password."
    exit 1
fi

read -s -p "Keystore password: " PW
echo
[ -z "$PW" ] && { echo "Error: Password may not be empty"; exit 1; }

# Get the nonce for each chain
echo -e "\nNonce for arbitrum-sepolia (421614):"
cast nonce $(cast wallet address --account $DEPLOYER --password "$PW") --rpc-url arbitrum-sepolia-rpc-url

echo -e "\nNonce for sepolia (11155111):"
cast nonce $(cast wallet address --account $DEPLOYER --password "$PW") --rpc-url sepolia-rpc-url

echo -e "\nNonce for bsc-testnet (97):"
cast nonce $(cast wallet address --account $DEPLOYER --password "$PW") --rpc-url bsc-testnet-rpc-url
