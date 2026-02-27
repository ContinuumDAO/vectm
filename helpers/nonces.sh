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

# Get the nonce for each chain (sepolia and linea-sepolia only)
echo -e "\nNonce for sepolia (11155111):"
cast nonce $(cast wallet address --account $DEPLOYER --password "$PW") --rpc-url sepolia-rpc-url

echo -e "\nNonce for linea-sepolia (59141):"
cast nonce $(cast wallet address --account $DEPLOYER --password "$PW") --rpc-url linea-sepolia-rpc-url
