#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../" && pwd)"
[ -f "$PROJECT_ROOT/.env" ] && set -a && source "$PROJECT_ROOT/.env" && set +a

# Set DApp address (CTM) in DApp Manager for a given chain.
# DAPP_MANAGER, CTM, and DEPLOYER: first two from deployments.toml, deployer from --account/--password-file.
# Optional CTM_ADDRESS overrides the address from deployments.toml.
#
# Usage: $0 <CHAIN_ID> --account <ACCOUNT> --password-file <PASSWORD_FILE> [CTM_ADDRESS]
# Example: $0 97 --account a55e7 --password-file ~/.evm-keys/.auth.a55e7
# Example: $0 97 --account a55e7 --password-file ~/.evm-keys/.auth.a55e7 0xdcb7641a75f335d9d65ef596e31f20900904540c

if [ $# -lt 4 ]; then
    echo "Error: Missing required arguments."
    echo "Usage: $0 <CHAIN_ID> --account <ACCOUNT> --password-file <PASSWORD_FILE> [CTM_ADDRESS]"
    echo "  CHAIN_ID       Chain ID (must exist in deployments.toml)"
    echo "  ACCOUNT        Cast account name or 0x address"
    echo "  PASSWORD_FILE  Path to password file for the account"
    echo "  CTM_ADDRESS    Optional. If omitted, read from deployments.toml (key ctm for this chain)."
    exit 1
fi

CHAIN_ID=$1
shift
ACCOUNT=""
PASSWORD_FILE=""
CTM_ADDRESS=""

while [ $# -gt 0 ]; do
    case "$1" in
        --account)
            ACCOUNT="$2"
            shift 2
            ;;
        --password-file)
            PASSWORD_FILE="$2"
            shift 2
            ;;
        *)
            if [ -z "$CTM_ADDRESS" ] && [[ $1 == 0x* ]]; then
                CTM_ADDRESS="$1"
            fi
            shift
            ;;
    esac
done

if [ -z "$ACCOUNT" ] || [ -z "$PASSWORD_FILE" ]; then
    echo "Error: --account and --password-file are required."
    echo "Usage: $0 <CHAIN_ID> --account <ACCOUNT> --password-file <PASSWORD_FILE> [CTM_ADDRESS]"
    exit 1
fi

DEPLOYMENTS_TOML="$PROJECT_ROOT/deployments.toml"

# RPC URL for the chain
RPC_URL_KEY=$(node "$SCRIPT_DIR/get-endpoint-env.js" "$CHAIN_ID" "$DEPLOYMENTS_TOML")
RPC_URL=${!RPC_URL_KEY}
if [ -z "$RPC_URL" ]; then
    echo "Error: could not get RPC URL for chain $CHAIN_ID (env $RPC_URL_KEY not set or empty)."
    exit 1
fi

# DApp Manager address from deployments.toml
DAPP_MANAGER=$(node "$SCRIPT_DIR/get-chain-address.js" "$CHAIN_ID" dappManager "$DEPLOYMENTS_TOML")
if [ -z "$DAPP_MANAGER" ]; then
    echo "Error: could not get dappManager for chain $CHAIN_ID in $DEPLOYMENTS_TOML"
    exit 1
fi

# Deployer from account (same as deploy-ctm-testnet.sh)
if [[ $ACCOUNT == 0x* ]]; then
    export DEPLOYER=$ACCOUNT
else
    export DEPLOYER=$(cast wallet address --account "$ACCOUNT" --password-file "$PASSWORD_FILE")
fi

# CTM address: from deployments.toml, or optional override from CLI
if [ -z "$CTM_ADDRESS" ]; then
    CTM_ADDRESS=$(node "$SCRIPT_DIR/get-chain-address.js" "$CHAIN_ID" ctm "$DEPLOYMENTS_TOML")
    if [ -z "$CTM_ADDRESS" ]; then
        echo "Error: could not get ctm for chain $CHAIN_ID in $DEPLOYMENTS_TOML"
        exit 1
    fi
fi

export DEPLOYER
export DAPP_MANAGER
export CTM=$CTM_ADDRESS

cd "$PROJECT_ROOT"

# Simulation first (same as deploy-ctm-testnet.sh)
forge script script/AddDAppAddr.s.sol \
    --account "$ACCOUNT" \
    --password-file "$PASSWORD_FILE" \
    --rpc-url "$RPC_URL" \
    --chain-id "$CHAIN_ID" \
    --gas-estimate-multiplier 200 \
    --legacy \
    --sender "$DEPLOYER"

if [ $? -ne 0 ]; then
    echo "Simulation failed. Exiting."
    exit 1
fi

read -p "Continue with broadcast? [Y/n] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ ! $REPLY =~ ^$ ]]; then
    echo "Cancelled."
    exit 1
fi

echo "Proceeding with broadcast..."
forge script script/AddDAppAddr.s.sol \
    --account "$ACCOUNT" \
    --password-file "$PASSWORD_FILE" \
    --rpc-url "$RPC_URL" \
    --chain-id "$CHAIN_ID" \
    --gas-estimate-multiplier 200 \
    --legacy \
    --sender "$DEPLOYER" \
    --broadcast

echo "Done."
