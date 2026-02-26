const fs = require("fs");
const path = require("path");

const WEI = 10n ** 18n;

/**
 * Convert a decimal amount string to wei (BigInt) without floating-point precision loss.
 */
function toWei(amountStr) {
  const [intPart = "0", decPart = ""] = amountStr.split(".");
  const paddedDec = decPart.padEnd(18, "0").slice(0, 18);
  return BigInt(intPart) * WEI + BigInt(paddedDec);
}

const projectRoot = path.resolve(__dirname, "..");
const inputPath = path.join(projectRoot, "all_finalized.json");
const outputPath = path.join(projectRoot, "all_finalized_wei.json");

const data = JSON.parse(fs.readFileSync(inputPath, "utf8"));

let grandTotal = 0n;

const weiData = data.map((entry) => {
  const weiAmount = toWei(entry.amount);
  grandTotal += weiAmount;
  return {
    address: entry.address,
    amount: weiAmount.toString(),
  };
});

fs.writeFileSync(outputPath, JSON.stringify(weiData, null, 2));

console.log("Grand total (wei):", grandTotal.toString());
console.log(`Wrote ${weiData.length} entries to all_finalized_wei.json`);
