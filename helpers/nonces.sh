#!/bin/bash

# Get the deployer address from the first argument
DEPLOYER=$1
PASSWORD_FILE=$2

# Check if the deployer address is provided
if [ -z "$DEPLOYER" ]; then
    echo "Error: Deployer address is required"
    echo "Usage: $0 <deployer_address> <path_to_password_file>"
    exit 1
fi

# Check if the password file is provided
if [ -z "$PASSWORD_FILE" ]; then
    echo "Error: Password file is required"
    echo "Usage: $0 <deployer_address> <path_to_password_file>"
    exit 1
fi

# Get the nonce for each chain
echo -e "\nNonce for arbitrum-sepolia (421614):"
cast nonce $(cast wallet address --account $DEPLOYER --password-file $PASSWORD_FILE) --rpc-url arbitrum-sepolia-rpc-url

echo -e "\nNonce for sepolia (11155111):"
cast nonce $(cast wallet address --account $DEPLOYER --password-file $PASSWORD_FILE) --rpc-url sepolia-rpc-url

echo -e "\nNonce for bsc-testnet (97):"
cast nonce $(cast wallet address --account $DEPLOYER --password-file $PASSWORD_FILE) --rpc-url bsc-testnet-rpc-url
