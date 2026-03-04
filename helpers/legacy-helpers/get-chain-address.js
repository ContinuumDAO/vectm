#!/usr/bin/env node
/**
 * Reads deployments.toml and prints the address for a given chainId and key (e.g. dappManager).
 * Usage: node get-chain-address.js <CHAIN_ID> <KEY> [path/to/deployments.toml]
 * Example: node get-chain-address.js 97 dappManager ../../deployments.toml
 * Output: 0xD384b9908baF9fD39Cf75A51A45102b4C19d953c
 */
const fs = require("fs");
const path = require("path");

const chainId = process.argv[2];
const key = process.argv[3];
const tomlPath = process.argv[4] || path.join(__dirname, "../../deployments.toml");

if (!chainId || !key) {
  console.error("Usage: get-chain-address.js <CHAIN_ID> <KEY> [path/to/deployments.toml]");
  process.exit(1);
}

let toml;
try {
  toml = fs.readFileSync(tomlPath, "utf8");
} catch (e) {
  console.error("get-chain-address.js: could not read", tomlPath, e.message);
  process.exit(1);
}

const sectionRe = new RegExp(`^\\[${chainId.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\.address\\](?=\\s*$)`, "m");
const match = toml.match(sectionRe);
if (!match) {
  console.error("get-chain-address.js: no section [", chainId, ".address] in", tomlPath);
  process.exit(1);
}

const afterSection = toml.slice(match.index + match[0].length);
const keyRe = new RegExp(`^${key.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\s*=\\s*"([^"]+)"`, "m");
const keyMatch = afterSection.match(keyRe);
if (!keyMatch) {
  console.error("get-chain-address.js: no key", key, "for chain", chainId);
  process.exit(1);
}

console.log(keyMatch[1]);
