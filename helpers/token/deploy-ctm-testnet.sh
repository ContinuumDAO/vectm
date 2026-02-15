#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../" && pwd)"
[ -f "$PROJECT_ROOT/.env" ] && set -a && source "$PROJECT_ROOT/.env" && set +a

# Check if required arguments are provided
# Optional 5th arg: "resume" to continue a failed broadcast (skips simulation, uses --resume)
if [ $# -lt 4 ]; then
    echo "Error: Missing required arguments."
    echo "Usage: $0 <CHAIN_ID> <DAPP_KEY> <ACCOUNT> <PASSWORD_FILE> [resume]"
    echo "Example: $0 97 \"v1.ctm.continuumdao\" 0x1234... /path/to/password.txt"
    echo "Resume:  $0 3441006 \"v1.ctm.continuumdao\" a55e7 ~/.evm-keys/.auth.a55e7 resume"
    exit 1
fi

CHAIN_ID=$1
DAPP_KEY=$2
ACCOUNT=$3
PASSWORD_FILE=$4
RESUME="${5:-}"

DEPLOYMENTS_TOML="$PROJECT_ROOT/deployments.toml"
RPC_URL_KEY=$(node "$SCRIPT_DIR/get-endpoint-env.js" "$CHAIN_ID" "$DEPLOYMENTS_TOML")
RPC_URL=${!RPC_URL_KEY}
if [ -z "$RPC_URL" ]; then
    echo "Error: could not get RPC URL for chain $CHAIN_ID (env $RPC_URL_KEY not set or empty)."
    exit 1
fi

# Env vars required by DeployCtm.s.sol
if [[ $ACCOUNT == 0x* ]]; then
    export DEPLOYER=$ACCOUNT
else
    export DEPLOYER=$(cast wallet address --account "$ACCOUNT" --password-file "$PASSWORD_FILE")
fi
export CHAIN_ID
export DAPP_KEY

FORGE_EXTRA=""
if [[ "$RESUME" == "resume" ]]; then
    echo "Resume mode: continuing previous broadcast (no simulation)."
    BROADCAST_RUN="$PROJECT_ROOT/broadcast/DeployCtm.s.sol/$CHAIN_ID/run-latest.json"
    if [ -f "$BROADCAST_RUN" ]; then
        echo "Backfilling any missing receipts so --resume can continue from the right nonce..."
        node "$SCRIPT_DIR/backfill-broadcast-receipts.js" "$BROADCAST_RUN" "$RPC_URL" || true
    fi
    FORGE_EXTRA="--resume"
else
    forge script script/DeployCtm.s.sol \
    --account $ACCOUNT \
    --password-file $PASSWORD_FILE \
    --rpc-url "$RPC_URL" \
    --legacy \
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
fi

forge script script/DeployCtm.s.sol \
--account $ACCOUNT \
--password-file $PASSWORD_FILE \
--slow \
--verify \
--etherscan-api-key $ETHERSCAN_API_KEY \
--rpc-url "$RPC_URL" \
--chain-id $CHAIN_ID \
--gas-estimate-multiplier 200 \
${FORGE_EXTRA:+$FORGE_EXTRA }\
--sender $DEPLOYER \
--legacy \
--broadcast

echo "Deployment complete."
