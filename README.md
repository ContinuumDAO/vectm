```
             _____ ______ __  ___
 _  __ ___  / ___//_  __//  |/  /
| |/ // -_)/ /__   / /  / /|_/ / 
|___/ \__/ \___/  /_/  /_/  /_/  
```

### ContinuumDAO Voting Escrow

:pager: Users can create a lock - a position which locks an amount of CTM tokens
$a$ for a specified amount of time $t_l$ (rounded by week) and weighs voting
power $P$ based on $t_l$ and maximum lockable time $t_{max}$ (equal to 4 years).

***How is voting power calculated?***

$$P = a \times {t_l \over t_{max}}$$

# Table of Contents

- [Contract Architecture](#contract-architecture)
- [API Reference](#api-reference)
- [Upgrade Reference](docs/upgradeable/VotingEscrowUpgrades.md)
- [Installation](#installation)
- [Deployment](docs/DEPLOYMENT.md)

### Contract Architecture

- Based on [Solidly Voting Escrow code](https://web.archive.org/web/20220501080953/https://github.com/solidlyexchange/solidly/blob/master/contracts/ve.sol)
- Using OpenZeppelin [Governor Votes](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.1/contracts/governance/utils/Votes.sol) to support Governance.
- OpenZeppelin [UUPS Proxy](https://docs.openzeppelin.com/contracts/5.x/api/proxy#UUPSUpgradeable) patterns are used, complying to ERC-1967.

# API Reference

## Token

- [VotingEscrow](docs/token/VotingEscrow.md)
- [CTM](docs/token/CTM.md)

## Governance

- [CTMDAOGovernor](docs/gov/CTMDAOGovernor.md)
- [GovernorCountingMultiple](docs/gov/GovernorCountingMultiple.md)

# Installation

## Dependencies

[Foundry](https://getfoundry.sh/) is currently supported, or any smart contract
development framework that supports git submodules.
