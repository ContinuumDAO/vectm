#!/usr/bin/env node
/**
 * Backfill missing receipts in a Forge broadcast run-latest.json.
 * When a tx was mined but Forge didn't save the receipt (e.g. RPC timeout),
 * --resume still tries to resend that tx and fails with "nonce too low".
 * This script finds the first tx with hash: null, looks it up on chain by nonce,
 * fetches its receipt, and appends it so the next --resume can continue.
 *
 * Usage: node backfill-broadcast-receipts.js <path-to-run-latest.json> <rpc_url>
 * Example: node backfill-broadcast-receipts.js ../../broadcast/DeployCtm.s.sol/3441006/run-latest.json "$MANTA_SEPOLIA_RPC_URL"
 */
const fs = require("fs");
const path = require("path");

const runPath = process.argv[2];
const rpcUrl = process.argv[3];

if (!runPath || !rpcUrl) {
  console.error("Usage: backfill-broadcast-receipts.js <run-latest.json> <rpc_url>");
  process.exit(1);
}

async function rpc(method, params) {
  const res = await fetch(rpcUrl, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ jsonrpc: "2.0", id: 1, method, params: params || [] }),
  });
  const data = await res.json();
  if (data.error) throw new Error(data.error.message || JSON.stringify(data.error));
  return data.result;
}

function toHex(n) {
  if (typeof n === "string" && n.startsWith("0x")) return n;
  return "0x" + Number(n).toString(16);
}

async function findTxHashByNonce(sender, nonceDec) {
  const currentBlock = await rpc("eth_blockNumber");
  let blockNum = parseInt(currentBlock, 16);
  const stop = Math.max(0, blockNum - 500);
  for (; blockNum >= stop; blockNum--) {
    const block = await rpc("eth_getBlockByNumber", [toHex(blockNum), true]);
    if (!block || !block.transactions) continue;
    for (const tx of block.transactions) {
      if (tx.from && tx.nonce !== undefined) {
        const txNonce = parseInt(tx.nonce, 16);
        if (tx.from.toLowerCase() === sender.toLowerCase() && txNonce === nonceDec) {
          return tx.hash;
        }
      }
    }
  }
  return null;
}

async function main() {
  const fullPath = path.isAbsolute(runPath) ? runPath : path.join(process.cwd(), runPath);
  const data = JSON.parse(fs.readFileSync(fullPath, "utf8"));
  const txs = data.transactions || [];
  const receipts = data.receipts || [];

  const firstNullIndex = txs.findIndex((t) => t.hash === null || t.hash === undefined);
  if (firstNullIndex < 0) {
    console.log("No transaction with missing hash found. Nothing to backfill.");
    return;
  }

  if (receipts.length !== firstNullIndex) {
    console.error(
      `Expected ${firstNullIndex} receipts but found ${receipts.length}. Backfilling only the next missing one.`
    );
  }

  const tx = txs[firstNullIndex];
  const from = tx.transaction?.from;
  const nonceHex = tx.transaction?.nonce;
  if (!from || nonceHex === undefined) {
    console.error("Transaction at index", firstNullIndex, "has no from/nonce.");
    process.exit(1);
  }
  const nonceDec = parseInt(nonceHex, 16);
  console.log("Looking for tx from", from, "with nonce", nonceDec, "on chain...");

  const txHash = await findTxHashByNonce(from, nonceDec);
  if (!txHash) {
    console.error("Could not find transaction on chain. It may not have been mined yet.");
    process.exit(1);
  }
  console.log("Found tx hash:", txHash);

  const rawReceipt = await rpc("eth_getTransactionReceipt", [txHash]);
  if (!rawReceipt) {
    console.error("No receipt for", txHash);
    process.exit(1);
  }

  const receipt = {
    status: rawReceipt.status,
    cumulativeGasUsed: rawReceipt.cumulativeGasUsed,
    logs: rawReceipt.logs || [],
    logsBloom: rawReceipt.logsBloom || "0x" + "0".repeat(512),
    type: rawReceipt.type !== undefined ? rawReceipt.type : "0x2",
    transactionHash: rawReceipt.transactionHash,
    transactionIndex: rawReceipt.transactionIndex,
    blockHash: rawReceipt.blockHash,
    blockNumber: rawReceipt.blockNumber,
    gasUsed: rawReceipt.gasUsed,
    effectiveGasPrice: rawReceipt.effectiveGasPrice || "0x0",
    from: rawReceipt.from,
    to: rawReceipt.to,
    contractAddress: rawReceipt.contractAddress || null,
  };
  if (rawReceipt.l1BaseFeeScalar != null) receipt.l1BaseFeeScalar = rawReceipt.l1BaseFeeScalar;
  if (rawReceipt.l1BlobBaseFee != null) receipt.l1BlobBaseFee = rawReceipt.l1BlobBaseFee;
  if (rawReceipt.l1BlobBaseFeeScalar != null) receipt.l1BlobBaseFeeScalar = rawReceipt.l1BlobBaseFeeScalar;
  if (rawReceipt.l1Fee != null) receipt.l1Fee = rawReceipt.l1Fee;
  if (rawReceipt.l1GasPrice != null) receipt.l1GasPrice = rawReceipt.l1GasPrice;
  if (rawReceipt.l1GasUsed != null) receipt.l1GasUsed = rawReceipt.l1GasUsed;

  data.receipts.push(receipt);
  tx.hash = txHash;
  fs.writeFileSync(fullPath, JSON.stringify(data, null, 2));
  console.log("Backfilled 1 receipt and updated tx hash. You can run with --resume again.");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
