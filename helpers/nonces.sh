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

# Get the nonce for each chain (Ethereum and Linea only)
echo -e "\nNonce for Ethereum (1):"
cast nonce $(cast wallet address --account $DEPLOYER --password "$PW") --rpc-url mainnet-rpc-url

echo -e "\nNonce for Linea (59144):"
cast nonce $(cast wallet address --account $DEPLOYER --password "$PW") --rpc-url linea-rpc-url
