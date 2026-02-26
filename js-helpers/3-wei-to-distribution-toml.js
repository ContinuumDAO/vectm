const fs = require("fs");
const path = require("path");
const readline = require("readline");

/**
 * Reads all_finalized_wei.json and adds distribution entries to distribution.toml
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
const weiPath = path.join(projectRoot, "all_finalized_wei.json");

function question(rl, prompt) {
  return new Promise((resolve) => {
    rl.question(prompt, (answer) => resolve(answer));
  });
}

async function main() {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  const raw = await question(rl, "Network name (default 'mainnet'): ");
  rl.close();
  const network = raw.trim() || "mainnet";

  const ADDRESS_SECTION = `[${network}.address]`;
  const UINT_SECTION = `[${network}.uint]`;
  const DIST_SECTION = `[${network}.distribution]`;

  const data = JSON.parse(fs.readFileSync(weiPath, "utf8"));
  const tomlPathAbs = path.resolve(projectRoot, "distribution.toml");
  let tomlContent = fs.existsSync(tomlPathAbs) ? fs.readFileSync(tomlPathAbs, "utf8") : "";

  // 1. Remove [network.distribution] section entirely
  const distStart = tomlContent.indexOf(DIST_SECTION);
  if (distStart !== -1) {
    const distEnd = findSectionEnd(tomlContent, distStart);
    tomlContent =
      tomlContent.slice(0, distStart).trimEnd() +
      (distEnd < tomlContent.length ? tomlContent.slice(distEnd) : "");
  }

  // 2. Inject into [network.address]: distribution_0_address, ... (create section if missing)
  const addrStart = tomlContent.indexOf(ADDRESS_SECTION);
  const addrAdditions = data.map((e, i) => `distribution_${i}_address = ${escapeTomlString(e.address)}`);
  if (addrStart !== -1) {
    const addrEnd = findSectionEnd(tomlContent, addrStart);
    const addrBlock = tomlContent.slice(addrStart, addrEnd);
    const addrLines = stripDistributionKeys(addrBlock.split("\n"));
    const newAddrBlock = addrLines.concat(addrAdditions).join("\n") + (addrEnd <= tomlContent.length ? "\n" : "");
    tomlContent = tomlContent.slice(0, addrStart) + newAddrBlock + tomlContent.slice(addrEnd);
  } else {
    const block = [ADDRESS_SECTION, ...addrAdditions].join("\n") + "\n";
    tomlContent = (tomlContent.trimEnd() + "\n\n" + block).replace(/^\n+/, "");
  }

  // 3. Inject into [network.uint]: distribution_count, distribution_0_amount, ... (create section if missing)
  const uintStart = tomlContent.indexOf(UINT_SECTION);
  const uintAdditions = [
    `distribution_count = ${data.length}`,
    ...data.map((e, i) => `distribution_${i}_amount = ${escapeTomlString(e.amount)}`),
  ];
  if (uintStart !== -1) {
    const uintEnd = findSectionEnd(tomlContent, uintStart);
    const uintBlock = tomlContent.slice(uintStart, uintEnd);
    const uintLines = stripDistributionKeys(uintBlock.split("\n"));
    const newUintBlock = uintLines.concat(uintAdditions).join("\n") + (uintEnd <= tomlContent.length ? "\n" : "");
    tomlContent = tomlContent.slice(0, uintStart) + newUintBlock + tomlContent.slice(uintEnd);
  } else {
    const block = [UINT_SECTION, ...uintAdditions].join("\n") + "\n";
    tomlContent = (tomlContent.trimEnd() + "\n\n" + block).replace(/^\n+/, "");
  }

  tomlContent = tomlContent.replace(/\n{3,}/g, "\n\n").trimEnd() + "\n";
  fs.writeFileSync(tomlPathAbs, tomlContent);

  console.log(`Added ${data.length} distribution entries to distribution.toml (address + uint sections).`);
  console.log(
    'Script keys: config.get("distribution_count").toUint256(), config.get(string.concat("distribution_", vm.toString(i), "_address")).toAddress(), config.get(string.concat("distribution_", vm.toString(i), "_amount")).toUint256()'
  );
}

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

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
