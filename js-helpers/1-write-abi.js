const fs = require("fs")

Array.from([
    "CTM",
    "CTMMintable",
    "VotingEscrowProxy",
    "VotingEscrow",
    "ContinuumDAO",
    "Distribution"
]).forEach((arti, i) => {
    const abi = JSON.parse(
        fs.readFileSync(`./out/${arti}.sol/${arti}.json`)
    ).abi

    fs.writeFileSync(
        `./abi/${arti}.ts`,
        `export const ${arti}ABI = ${JSON.stringify(abi, null, 4)}`
    )

    fs.writeFileSync(
        `./abi/${arti}.json`,
        JSON.stringify(abi, null, 2)
    )
})
