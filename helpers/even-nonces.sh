#!/bin/bash

# Even out EOA nonces across all chains in deployments.toml by sending zero-value
# self-transfers on chains with lower nonces until they match the chain with the
# highest nonce. Uses chain IDs and RPC URLs from deployments.toml / .env.

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

# Build list of chain_id and rpc_url for chains that have RPC set in .env
CHAINS_WITH_RPC=()
declare -A RPC_BY_CHAIN
for chain in "${CHAIN_IDS[@]}"; do
    RPC_KEY=$(node "$SCRIPT_DIR/token/get-endpoint-env.js" "$chain" "$DEPLOYMENTS_TOML" 2>/dev/null) || true
    [ -z "$RPC_KEY" ] && continue
    RPC_URL="${!RPC_KEY}"
    if [ -z "$RPC_URL" ]; then
        echo "Skipping chain $chain (env $RPC_KEY not set or empty)"
        continue
    fi
    CHAINS_WITH_RPC+=( "$chain" )
    RPC_BY_CHAIN[$chain]=$RPC_URL
done

if [ ${#CHAINS_WITH_RPC[@]} -eq 0 ]; then
    echo "Error: No chains with RPC URL set in .env"
    exit 1
fi

echo "Chains: ${CHAINS_WITH_RPC[*]}"
echo ""

# Fetch current nonces
declare -A NONCE_BY_CHAIN
echo "Current nonces:"
for chain in "${CHAINS_WITH_RPC[@]}"; do
    rpc="${RPC_BY_CHAIN[$chain]}"
    n=$(cast nonce "$ADDRESS" --rpc-url "$rpc" 2>/dev/null) || n=0
    NONCE_BY_CHAIN[$chain]=$n
    echo "  chain $chain: $n"
done
echo ""

# Find highest nonce
MAX_NONCE=0
for chain in "${CHAINS_WITH_RPC[@]}"; do
    n=${NONCE_BY_CHAIN[$chain]}
    [ "$n" -gt "$MAX_NONCE" ] && MAX_NONCE=$n
done
echo "Target nonce (max): $MAX_NONCE"
echo ""

# Check if already even
ALL_EVEN=1
for chain in "${CHAINS_WITH_RPC[@]}"; do
    [ "${NONCE_BY_CHAIN[$chain]}" -ne "$MAX_NONCE" ] && ALL_EVEN=0 && break
done
if [ "$ALL_EVEN" -eq 1 ]; then
    echo "Nonces are already even. Nothing to do."
    exit 0
fi

# Number of transactions to send in parallel per batch
BATCH_SIZE=10

# Chains that require legacy transactions (no EIP-1559)
LEGACY_CHAIN_IDS="200810 3441006 1891 5887 59902"

# Chains that need high gas and batch size 1 on first pass (avoid "replacement transaction underpriced";
# ensures txs are accepted and show on explorer, e.g. 5887 Dukong/Mantra)
HIGH_GAS_FIRST_PASS_CHAIN_IDS="5887"
HIGH_GAS_FIRST_PASS_MULTIPLIER=400

# Chains that need wait-for-mined between txs (poll until on-chain nonce advances before sending next).
# Use when RPC accepts txs but explorer shows nothing until we wait for confirmation (e.g. 5887).
# Official Dukong RPC: https://evm.dukong.mantrachain.io
WAIT_FOR_NONCE_CHAIN_IDS="5887"
WAIT_FOR_NONCE_TIMEOUT=120

# Send zero-value self-transfers to bump nonce on each chain that is behind.
# Optional 5th arg: gas_multiplier (e.g. 400 for 4x gas price). Use for "replacement transaction underpriced".
# Optional 6th arg: wait_for_nonce_seconds — after each batch, poll until on-chain nonce catches up (0 = no wait).
# When gas_multiplier > 100 we use batch size 1 to avoid RPC timeouts from parallel sends.
# Returns 0 on success, 1 on failure (caller can continue with other chains).
send_catchup() {
    local chain_id=$1
    local rpc_url=$2
    local current=$3
    local target=$4
    local gas_multiplier=${5:-100}
    local wait_for_nonce_seconds=${6:-0}
    local gap=$((target - current))
    local legacy_flag=""
    local gas_flag=""
    local batch_size=$BATCH_SIZE
    [ "$gas_multiplier" -gt 100 ] && batch_size=1
    if [[ " $LEGACY_CHAIN_IDS " == *" $chain_id "* ]]; then
        legacy_flag="--legacy"
    fi
    if [ "$gas_multiplier" -gt 100 ]; then
        local base_gas
        base_gas=$(cast gas-price --rpc-url "$rpc_url" 2>/dev/null) || base_gas=0
        if [ "$base_gas" -gt 0 ]; then
            gas_flag="--gas-price $((base_gas * gas_multiplier / 100))"
        fi
    fi

    if [ "$gap" -le 0 ]; then
        return 0
    fi

    [ "$gas_multiplier" -gt 100 ] && echo "Chain $chain_id: using gas multiplier ${gas_multiplier}% (batch size 1 to avoid RPC timeouts)"
    [ "$wait_for_nonce_seconds" -gt 0 ] && echo "Chain $chain_id: will wait up to ${wait_for_nonce_seconds}s for each tx to be mined (RPC: $rpc_url)"
    echo "Sending $gap zero-value tx(s) on chain $chain_id to catch up (batches of $batch_size)..."
    local sent=0
    local tmpdir
    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' RETURN
    while [ "$sent" -lt "$gap" ]; do
        local batch_count=$((gap - sent))
        [ "$batch_count" -gt "$batch_size" ] && batch_count=$batch_size

        local pids=()
        for ((i = 0; i < batch_count; i++)); do
            local n=$((current + sent + i))
            (
                cast send "$ADDRESS" \
                    --value 0 \
                    --nonce "$n" \
                    --account "$DEPLOYER" \
                    --password-file "$PASSWORD_FILE" \
                    $legacy_flag \
                    $gas_flag \
                    --rpc-url "$rpc_url" 2> "$tmpdir/err$i"
                echo $? > "$tmpdir/exit$i"
            ) &
            pids+=($!)
        done

        local failed=0
        local batch_ok=0
        for ((i = 0; i < batch_count; i++)); do
            wait "${pids[$i]}"
            local exitcode
            exitcode=$(cat "$tmpdir/exit$i" 2>/dev/null)
            if [ "${exitcode:-1}" -eq 0 ]; then
                batch_ok=$((batch_ok + 1))
            else
                if grep -q "already known" "$tmpdir/err$i" 2>/dev/null; then
                    batch_ok=$((batch_ok + 1))
                else
                    failed=1
                fi
            fi
        done
        sent=$((sent + batch_ok))
        if [ "$failed" -ne 0 ]; then
            echo "  chain $chain_id: batch failed (sent $sent/$gap). Continuing other chains."
            return 1
        fi
        echo "  chain $chain_id: sent $sent/$gap"
        # Wait for on-chain nonce to advance before sending next batch (so txs show on explorer)
        if [ "$wait_for_nonce_seconds" -gt 0 ] && [ "$sent" -lt "$gap" ]; then
            local expected_nonce=$((current + sent))
            local deadline=$((SECONDS + wait_for_nonce_seconds))
            while true; do
                local on_chain_nonce
                on_chain_nonce=$(cast nonce "$ADDRESS" --rpc-url "$rpc_url" 2>/dev/null) || on_chain_nonce=-1
                [ "$on_chain_nonce" -ge "$expected_nonce" ] && break
                [ "$SECONDS" -ge "$deadline" ] && echo "  chain $chain_id: timeout waiting for nonce $expected_nonce (got $on_chain_nonce), continuing..." && break
                echo "  chain $chain_id: waiting for nonce $expected_nonce (current $on_chain_nonce)..."
                sleep 3
            done
        fi
    done
    echo "  chain $chain_id: done (nonce now $target)"
    echo ""
    return 0
}

# Run catchup for each chain; do not exit on first failure so all chains are attempted.
# Chains in HIGH_GAS_FIRST_PASS_CHAIN_IDS use higher gas and batch size 1 from the start.
# Chains in WAIT_FOR_NONCE_CHAIN_IDS wait for each tx to be mined before sending the next.
FAILED_CHAINS=()
for chain in "${CHAINS_WITH_RPC[@]}"; do
    gas=100
    wait_sec=0
    [[ " $HIGH_GAS_FIRST_PASS_CHAIN_IDS " == *" $chain "* ]] && gas=$HIGH_GAS_FIRST_PASS_MULTIPLIER
    [[ " $WAIT_FOR_NONCE_CHAIN_IDS " == *" $chain "* ]] && wait_sec=$WAIT_FOR_NONCE_TIMEOUT
    if ! send_catchup "$chain" "${RPC_BY_CHAIN[$chain]}" "${NONCE_BY_CHAIN[$chain]}" "$MAX_NONCE" "$gas" "$wait_sec"; then
        FAILED_CHAINS+=( "$chain" )
    fi
done

# Retry failed chains with 4x gas (e.g. for "replacement transaction underpriced")
RETRY_GAS_MULTIPLIER=400
if [ ${#FAILED_CHAINS[@]} -gt 0 ]; then
    echo "Retrying ${FAILED_CHAINS[*]} with gas multiplier ${RETRY_GAS_MULTIPLIER}%..."
    STILL_FAILED=()
    for chain in "${FAILED_CHAINS[@]}"; do
        current=$(cast nonce "$ADDRESS" --rpc-url "${RPC_BY_CHAIN[$chain]}" 2>/dev/null) || current=0
        wait_sec=0
        [[ " $WAIT_FOR_NONCE_CHAIN_IDS " == *" $chain "* ]] && wait_sec=$WAIT_FOR_NONCE_TIMEOUT
        if ! send_catchup "$chain" "${RPC_BY_CHAIN[$chain]}" "$current" "$MAX_NONCE" "$RETRY_GAS_MULTIPLIER" "$wait_sec"; then
            STILL_FAILED+=( "$chain" )
        fi
    done
    FAILED_CHAINS=( "${STILL_FAILED[@]}" )
fi

echo "Verifying nonces..."
ALL_VERIFIED=1
for chain in "${CHAINS_WITH_RPC[@]}"; do
    n=$(cast nonce "$ADDRESS" --rpc-url "${RPC_BY_CHAIN[$chain]}" 2>/dev/null) || n=-1
    echo "  chain $chain: $n"
    [ "$n" -ne "$MAX_NONCE" ] && ALL_VERIFIED=0
done

if [ "$ALL_VERIFIED" -eq 1 ]; then
    echo ""
    echo "Nonces are now even at $MAX_NONCE."
else
    echo ""
    echo "Warning: some nonces are not yet at $MAX_NONCE (e.g. tx not yet mined or catchup failed). Re-run to verify or retry."
    [ ${#FAILED_CHAINS[@]} -gt 0 ] && echo "Chains that failed during catchup: ${FAILED_CHAINS[*]}"
    exit 1
fi
