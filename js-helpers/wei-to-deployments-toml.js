const fs = require("fs");
const path = require("path");

/**
 * Reads all_testnet_wei.json and adds distribution entries to deployments.toml
 * under the allowed StdConfig type sections [profile.address] and [profile.uint].
 * Forge StdConfig only loads sub-tables named: bool, address, bytes32, uint, int, string, bytes.
 * So we use flat keys: distribution_count, distribution_0_address, distribution_0_amount, etc.
 *
 * In a Forge script use:
 *   config.get("distribution_count").toUint256()
 *   config.get(string.concat("distribution_", vm.toString(i), "_address")).toAddress()
 *   config.get(string.concat("distribution_", vm.toString(i), "_amount")).toUint256()
 */

const projectRoot = path.resolve(__dirname, "..");
const weiPath = path.join(projectRoot, "all_testnet_wei.json");
const tomlPath = path.join(projectRoot, "deployments.toml");

const ADDRESS_SECTION = "[arbitrum-sepolia.address]";
const UINT_SECTION = "[arbitrum-sepolia.uint]";
const DIST_SECTION = "[arbitrum-sepolia.distribution]";

function escapeTomlString(s) {
  return '"' + String(s).replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"';
}

function findSectionEnd(content, sectionStart) {
  const nextSection = content.indexOf("\n[", sectionStart + 1);
  return nextSection === -1 ? content.length : nextSection + 1;
}

function stripDistributionKeys(lines) {
  return lines.filter(
    (line) =>
      !/^\s*distribution_count\s*=/.test(line) &&
      !/^\s*distribution_\d+_(address|amount)\s*=/.test(line)
  );
}

const data = JSON.parse(fs.readFileSync(weiPath, "utf8"));
let tomlContent = fs.readFileSync(tomlPath, "utf8");

// 1. Remove [arbitrum-sepolia.distribution] section entirely
const distStart = tomlContent.indexOf(DIST_SECTION);
if (distStart !== -1) {
  const distEnd = findSectionEnd(tomlContent, distStart);
  tomlContent =
    tomlContent.slice(0, distStart).trimEnd() +
    (distEnd < tomlContent.length ? tomlContent.slice(distEnd) : "");
}

// 2. Inject into [arbitrum-sepolia.address]: distribution_0_address, ...
const addrStart = tomlContent.indexOf(ADDRESS_SECTION);
if (addrStart === -1) throw new Error(`Section ${ADDRESS_SECTION} not found`);
const addrEnd = findSectionEnd(tomlContent, addrStart);
const addrBlock = tomlContent.slice(addrStart, addrEnd);
const addrLines = stripDistributionKeys(addrBlock.split("\n"));
const addrAdditions = data.map((e, i) => `distribution_${i}_address = ${escapeTomlString(e.address)}`);
const newAddrBlock = addrLines.concat(addrAdditions).join("\n") + (addrEnd <= tomlContent.length ? "\n" : "");
tomlContent = tomlContent.slice(0, addrStart) + newAddrBlock + tomlContent.slice(addrEnd);

// 3. Inject into [arbitrum-sepolia.uint]: distribution_count, distribution_0_amount, ...
const uintStart = tomlContent.indexOf(UINT_SECTION);
if (uintStart === -1) throw new Error(`Section ${UINT_SECTION} not found`);
const uintEnd = findSectionEnd(tomlContent, uintStart);
const uintBlock = tomlContent.slice(uintStart, uintEnd);
const uintLines = stripDistributionKeys(uintBlock.split("\n"));
const uintAdditions = [
  `distribution_count = ${data.length}`,
  ...data.map((e, i) => `distribution_${i}_amount = ${escapeTomlString(e.amount)}`),
];
const newUintBlock = uintLines.concat(uintAdditions).join("\n") + (uintEnd <= tomlContent.length ? "\n" : "");
tomlContent = tomlContent.slice(0, uintStart) + newUintBlock + tomlContent.slice(uintEnd);

tomlContent = tomlContent.replace(/\n{3,}/g, "\n\n").trimEnd() + "\n";
fs.writeFileSync(tomlPath, tomlContent);

console.log(`Added ${data.length} distribution entries to deployments.toml (address + uint sections).`);
console.log(
  'Script keys: config.get("distribution_count").toUint256(), config.get(string.concat("distribution_", vm.toString(i), "_address")).toAddress(), config.get(string.concat("distribution_", vm.toString(i), "_amount")).toUint256()'
);
