#!/usr/bin/env node
/**
 * Reads deployments.toml and prints the env var name used for endpoint_url for the given chainId.
 * Usage: node get-endpoint-env.js <CHAIN_ID> [path/to/deployments.toml]
 * Output: ENV_VAR_NAME (e.g. BSC_TESTNET_RPC_URL). Shell can expand with ${!ENV_VAR_NAME}.
 */
const fs = require("fs");
const path = require("path");

const chainId = process.argv[2];
const tomlPath = process.argv[3] || path.join(__dirname, "../../deployments.toml");

if (!chainId) {
  console.error("Usage: get-endpoint-env.js <CHAIN_ID> [path/to/deployments.toml]");
  process.exit(1);
}

let toml;
try {
  toml = fs.readFileSync(tomlPath, "utf8");
} catch (e) {
  console.error("get-endpoint-env.js: could not read", tomlPath, e.message);
  process.exit(1);
}

// Find section [chainId] and then endpoint_url = "${VAR}"
const sectionRe = new RegExp(`^\\[${chainId.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\](?=\\s*$)`, "m");
const match = toml.match(sectionRe);
if (!match) {
  console.error("get-endpoint-env.js: no section [", chainId, "] in", tomlPath);
  process.exit(1);
}

const afterSection = toml.slice(match.index + match[0].length);
const endpointRe = /endpoint_url\s*=\s*"\$\{([^}]+)\}"/;
const endpointMatch = afterSection.match(endpointRe);
if (!endpointMatch) {
  console.error("get-endpoint-env.js: no endpoint_url for chain", chainId);
  process.exit(1);
}

console.log(endpointMatch[1]);
