const fs = require("fs")

Array.from([
    "CTM",
    "VotingEscrowProxy",
    "VotingEscrow",
    "CTMDAOGovernor",
    "NodeProperties",
    "Rewards"
]).forEach((arti, i) => {
    fs.writeFileSync(
        `./abi/${arti}.ts`,
        `export const ${arti}ABI = ${JSON.stringify(
            JSON.parse(
                fs.readFileSync(`./out/${arti}.sol/${arti}.json`)
            ).abi,
            null,
            4
        )}`
    )
})
