#!/bin/bash

# Show EOA nonces for all chains in deployments.toml that have RPC URL set in .env.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../" && pwd)"
DEPLOYMENTS_TOML="$PROJECT_ROOT/deployments.toml"
[ -f "$PROJECT_ROOT/.env" ] && set -a && source "$PROJECT_ROOT/.env" && set +a

DEPLOYER=$1
PASSWORD_FILE=$2

if [ -z "$DEPLOYER" ]; then
    echo "Error: Account name is required"
    echo "Usage: $0 <account_name> <path_to_password_file>"
    exit 1
fi

if [ -z "$PASSWORD_FILE" ]; then
    echo "Error: Password file is required"
    echo "Usage: $0 <account_name> <path_to_password_file>"
    exit 1
fi

if [ ! -f "$DEPLOYMENTS_TOML" ]; then
    echo "Error: deployments.toml not found at $DEPLOYMENTS_TOML"
    exit 1
fi

ADDRESS=$(cast wallet address --account "$DEPLOYER" --password-file "$PASSWORD_FILE")
echo "Account: $ADDRESS"
echo ""

# Chain IDs from deployments.toml (sections [97], [1946], ...)
CHAIN_IDS=()
while IFS= read -r line; do
    CHAIN_IDS+=( "$line" )
done < <(grep -oE '^\[[0-9]+\]$' "$DEPLOYMENTS_TOML" | tr -d '[]')

# Build list of chains that have RPC set in .env
CHAINS_WITH_RPC=()
declare -A RPC_BY_CHAIN
for chain in "${CHAIN_IDS[@]}"; do
    RPC_KEY=$(node "$SCRIPT_DIR/token/get-endpoint-env.js" "$chain" "$DEPLOYMENTS_TOML" 2>/dev/null) || true
    [ -z "$RPC_KEY" ] && continue
    RPC_URL="${!RPC_KEY}"
    if [ -z "$RPC_URL" ]; then
        continue
    fi
    CHAINS_WITH_RPC+=( "$chain" )
    RPC_BY_CHAIN[$chain]=$RPC_URL
done

if [ ${#CHAINS_WITH_RPC[@]} -eq 0 ]; then
    echo "No chains with RPC URL set in .env"
    exit 1
fi

for chain in "${CHAINS_WITH_RPC[@]}"; do
    rpc="${RPC_BY_CHAIN[$chain]}"
    n=$(cast nonce "$ADDRESS" --rpc-url "$rpc" 2>/dev/null) || n="?"
    echo "Chain $chain: $n"
done
