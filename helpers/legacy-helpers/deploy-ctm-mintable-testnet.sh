#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../" && pwd)"
[ -f "$PROJECT_ROOT/.env" ] && set -a && source "$PROJECT_ROOT/.env" && set +a

# Check if required arguments are provided
if [ $# -lt 4 ]; then
    echo "Error: Missing required arguments."
    echo "Usage: $0 <CHAIN_ID> <DAPP_KEY> <ACCOUNT> <PASSWORD_FILE>"
    echo "Example: $0 97 "v1.ctm.continuumdao" 0x1234... /path/to/password.txt"
    exit 1
fi

CHAIN_ID=$1
DAPP_KEY=$2
ACCOUNT=$3
PASSWORD_FILE=$4

DEPLOYMENTS_TOML="$PROJECT_ROOT/deployments.toml"
RPC_URL_KEY=$(node "$SCRIPT_DIR/get-endpoint-env.js" "$CHAIN_ID" "$DEPLOYMENTS_TOML")
RPC_URL=${!RPC_URL_KEY}
if [ -z "$RPC_URL" ]; then
    echo "Error: could not get RPC URL for chain $CHAIN_ID (env $RPC_URL_KEY not set or empty)."
    exit 1
fi

# Env vars required by DeployCtmMintable.s.sol
if [[ $ACCOUNT == 0x* ]]; then
    export DEPLOYER=$ACCOUNT
else
    export DEPLOYER=$(cast wallet address --account "$ACCOUNT" --password-file "$PASSWORD_FILE")
fi
export CHAIN_ID
export DAPP_KEY

forge script script/DeployCtmMintable.s.sol \
--account $ACCOUNT \
--password-file $PASSWORD_FILE \
--rpc-url "$RPC_URL" \
--chain-id $CHAIN_ID \
--sender $DEPLOYER 

# Check if the simulation succeeded
if [ $? -ne 0 ]; then
    echo "Simulation failed. Exiting."
    exit 1
fi

read -p "Continue with deployment? [Y/n] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ ! $REPLY =~ ^$ ]]; then
    echo "Deployment cancelled."
    exit 1
fi

echo "Proceeding with deployment..."

forge script script/DeployCtmMintable.s.sol \
--account $ACCOUNT \
--password-file $PASSWORD_FILE \
--slow \
--verify \
--etherscan-api-key $ETHERSCAN_API_KEY \
--rpc-url "$RPC_URL" \
--chain-id $CHAIN_ID \
--sender $DEPLOYER \
--broadcast

echo "Deployment complete."
