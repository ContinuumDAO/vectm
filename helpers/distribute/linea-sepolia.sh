#!/bin/bash

# Check if required arguments are provided
if [ $# -lt 1 ]; then
    echo "Error: Missing required arguments."
    echo "Usage: $0 <ACCOUNT>"
    echo "Example: $0 0x1234..."
    echo "You will be prompted for the keystore password."
    exit 1
fi
read -s -p "Keystore password: " PW
echo
[ -z "$PW" ] && { echo "Error: Password may not be empty"; exit 1; }

# Simulate the deployment
forge script script/Distribute.s.sol \
--sender $(cast wallet addr --account $1 --password "$PW") \
--rpc-url linea-sepolia-rpc-url \
--chain linea-sepolia

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
--password "$PW" \
--sender $(cast wallet addr --account $1 --password "$PW") \
--slow \
--rpc-url linea-sepolia-rpc-url \
--chain linea-sepolia \
--broadcast

echo "✅ Distribution complete."
