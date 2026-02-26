#!/bin/bash

# Even out EOA nonces across arbitrum-sepolia, sepolia, and bsc-testnet by
# sending zero-value self-transfers on chains with lower nonces until they
# match the chain with the highest nonce.

set -e

DEPLOYER=$1

if [ -z "$DEPLOYER" ]; then
    echo "Error: Account name is required"
    echo "Usage: $0 <account_name>"
    echo "You will be prompted for the keystore password."
    exit 1
fi

read -s -p "Keystore password: " PW
echo
[ -z "$PW" ] && { echo "Error: Password may not be empty"; exit 1; }

ADDRESS=$(cast wallet address --account "$DEPLOYER" --password "$PW")
echo "Account: $ADDRESS"
echo ""

# Fetch current nonces (cast nonce outputs a single decimal number)
NONCE_ARB=$(cast nonce "$ADDRESS" --rpc-url arbitrum-sepolia-rpc-url)
NONCE_SEP=$(cast nonce "$ADDRESS" --rpc-url sepolia-rpc-url)
NONCE_BSC=$(cast nonce "$ADDRESS" --rpc-url bsc-testnet-rpc-url)

echo "Current nonces:"
echo "  arbitrum-sepolia (421614): $NONCE_ARB"
echo "  sepolia (11155111):        $NONCE_SEP"
echo "  bsc-testnet (97):         $NONCE_BSC"
echo ""

# Find highest nonce
MAX_NONCE=$NONCE_ARB
[ "$NONCE_SEP" -gt "$MAX_NONCE" ] && MAX_NONCE=$NONCE_SEP
[ "$NONCE_BSC" -gt "$MAX_NONCE" ] && MAX_NONCE=$NONCE_BSC

echo "Target nonce (max): $MAX_NONCE"
echo ""

if [ "$NONCE_ARB" -eq "$MAX_NONCE" ] && [ "$NONCE_SEP" -eq "$MAX_NONCE" ] && [ "$NONCE_BSC" -eq "$MAX_NONCE" ]; then
    echo "Nonces are already even. Nothing to do."
    exit 0
fi

# Number of transactions to send in parallel per batch
BATCH_SIZE=10

# Send zero-value self-transfers to bump nonce on each chain that is behind.
# Sends up to BATCH_SIZE transactions in parallel per batch.
send_catchup() {
    local chain_name=$1
    local rpc_url=$2
    local current=$3
    local target=$4
    local gap=$((target - current))

    if [ "$gap" -le 0 ]; then
        return
    fi

    echo "Sending $gap zero-value tx(s) on $chain_name to catch up (batches of $BATCH_SIZE)..."
    local sent=0
    while [ "$sent" -lt "$gap" ]; do
        local batch_count=$((gap - sent))
        [ "$batch_count" -gt "$BATCH_SIZE" ] && batch_count=$BATCH_SIZE

        local pids=()
        for ((i = 0; i < batch_count; i++)); do
            local n=$((current + sent + i))
            cast send "$ADDRESS" \
                --value 0 \
                --nonce "$n" \
                --account "$DEPLOYER" \
                --password "$PW" \
                --rpc-url "$rpc_url" &
            pids+=($!)
        done

        local failed=0
        for pid in "${pids[@]}"; do
            if ! wait "$pid"; then
                failed=1
            fi
        done
        [ "$failed" -ne 0 ] && exit 1

        sent=$((sent + batch_count))
        echo "  $chain_name: sent $sent/$gap"
    done
    echo "  $chain_name: done (nonce now $target)"
    echo ""
}

send_catchup "arbitrum-sepolia" "arbitrum-sepolia-rpc-url" "$NONCE_ARB" "$MAX_NONCE"
send_catchup "sepolia"         "sepolia-rpc-url"         "$NONCE_SEP" "$MAX_NONCE"
send_catchup "bsc-testnet"     "bsc-testnet-rpc-url"     "$NONCE_BSC" "$MAX_NONCE"

echo "Verifying nonces..."
NONCE_ARB_NEW=$(cast nonce "$ADDRESS" --rpc-url arbitrum-sepolia-rpc-url)
NONCE_SEP_NEW=$(cast nonce "$ADDRESS" --rpc-url sepolia-rpc-url)
NONCE_BSC_NEW=$(cast nonce "$ADDRESS" --rpc-url bsc-testnet-rpc-url)

echo "  arbitrum-sepolia: $NONCE_ARB_NEW"
echo "  sepolia:          $NONCE_SEP_NEW"
echo "  bsc-testnet:      $NONCE_BSC_NEW"

if [ "$NONCE_ARB_NEW" -eq "$MAX_NONCE" ] && [ "$NONCE_SEP_NEW" -eq "$MAX_NONCE" ] && [ "$NONCE_BSC_NEW" -eq "$MAX_NONCE" ]; then
    echo ""
    echo "Nonces are now even at $MAX_NONCE."
else
    echo ""
    echo "Warning: nonces may not have fully synced (e.g. tx not yet mined). Re-run to verify."
    exit 1
fi
