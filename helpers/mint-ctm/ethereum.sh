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

# Simulate the mint
forge script script/MintCTM.s.sol \
--sender $(cast wallet addr --account $1 --password "$PW") \
--rpc-url ethereum-rpc-url \
--chain ethereum

# Check if the simulation succeeded
if [ $? -ne 0 ]; then
    echo "❌ Simulation failed. Exiting."
    exit 1
fi

read -p "Continue with mint? [Y/n] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ ! $REPLY =~ ^$ ]]; then
    echo "❌ Mint cancelled."
    exit 1
fi

echo "Proceeding with mint..."

forge script script/MintCTM.s.sol \
--account $1 \
--password "$PW" \
--sender $(cast wallet addr --account $1 --password "$PW") \
--slow \
--rpc-url ethereum-rpc-url \
--chain ethereum \
--broadcast

echo "✅ Mint complete."
