#!/bin/bash

# Set an account's nonce to a target number on linea-sepolia by sending
# zero-value self-transfers the chain reaches the target nonce.

set -e

DEPLOYER=$1
TARGET_NONCE=$2

if [ -z "$DEPLOYER" ]; then
    echo "Error: Account name is required"
    echo "Usage: $0 <account_name> [target_nonce]"
    echo "  If target_nonce is omitted, you will be prompted for it."
    echo "You will be prompted for the keystore password."
    exit 1
fi

if [ -z "$TARGET_NONCE" ]; then
    read -p "Target nonce: " TARGET_NONCE
    [ -z "$TARGET_NONCE" ] && { echo "Error: Target nonce may not be empty"; exit 1; }
fi

# Ensure it's a non-negative integer
if ! [[ "$TARGET_NONCE" =~ ^[0-9]+$ ]]; then
    echo "Error: Target nonce must be a non-negative integer"
    exit 1
fi

read -s -p "Keystore password: " PW
echo
[ -z "$PW" ] && { echo "Error: Password may not be empty"; exit 1; }

ADDRESS=$(cast wallet address --account "$DEPLOYER" --password "$PW")
echo "Account: $ADDRESS"
echo "Target nonce: $TARGET_NONCE"
echo ""

# Fetch current nonces (cast nonce outputs a single decimal number)
NONCE_LINEA=$(cast nonce "$ADDRESS" --rpc-url linea-rpc-url)

echo "Current nonces:"
echo "  linea (59144):        $NONCE_LINEA"
echo ""

# Check if any chain is behind target; warn if any is ahead (we can't decrease nonce)
if [ "$NONCE_LINEA" -gt "$TARGET_NONCE" ]; then
    echo "Warning: Linea already has nonce > $TARGET_NONCE. Nonce cannot be decreased."
    echo ""
fi

if [ "$NONCE_LINEA" -eq "$TARGET_NONCE" ]; then
    echo "Linea already at target nonce $TARGET_NONCE. Nothing to do."
    exit 0
fi

# Number of transactions to send in parallel per batch
BATCH_SIZE=10

# Send zero-value self-transfers to reach target nonce on each chain that is behind.
send_catchup() {
    local chain_name=$1
    local rpc_url=$2
    local current=$3
    local target=$4
    local gap=$((target - current))

    if [ "$gap" -le 0 ]; then
        echo "  $chain_name: already at or above target (current $current), skipping"
        echo ""
        return
    fi

    echo "Sending $gap zero-value tx(s) on $chain_name to reach nonce $target (batches of $BATCH_SIZE)..."
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

send_catchup "linea" "linea-rpc-url" "$NONCE_LINEA" "$TARGET_NONCE"

echo "Verifying nonces..."
NONCE_LINEA_NEW=$(cast nonce "$ADDRESS" --rpc-url linea-rpc-url)

echo "  linea: $NONCE_LINEA_NEW"

if [ "$NONCE_LINEA_NEW" -eq "$TARGET_NONCE" ]; then
    echo ""
    echo "Linea now at nonce $TARGET_NONCE."
else
    echo ""
    echo "Warning: linea may not have reached $TARGET_NONCE yet (e.g. tx not yet mined). Re-run to verify."
    exit 1
fi
