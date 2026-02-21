#!/bin/bash

# Check if required arguments are provided
if [ $# -lt 2 ]; then
    echo "Error: Missing required arguments."
    echo "Usage: $0 <ACCOUNT> <PASSWORD_FILE>"
    echo "Example: $0 0x1234... /path/to/password.txt"
    exit 1
fi

# Simulate the deployment
forge script script/Distribute.s.sol \
--sender $(cast wallet addr --account $1 --password-file $2) \
--rpc-url arbitrum-sepolia-rpc-url \
--chain arbitrum-sepolia

# Check if the simulation succeeded
if [ $? -ne 0 ]; then
    echo "❌ Simulation failed. Exiting."
    exit 1
fi

read -p "Continue with distribution? [Y/n] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ ! $REPLY =~ ^$ ]]; then
    echo "❌ Distribution cancelled."
    exit 1
fi

echo "Proceeding with distribution..."

forge script script/Distribute.s.sol \
--account $1 \
--password-file $2 \
--sender $(cast wallet addr --account $1 --password-file $2) \
--slow \
--rpc-url arbitrum-sepolia-rpc-url \
--chain arbitrum-sepolia \
--broadcast

echo "✅ Distribution complete."
