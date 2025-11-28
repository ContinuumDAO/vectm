# ContinuumDAO Voting Escrow - Voting & Governance

---

[![Solidity](https://img.shields.io/badge/Solidity-v0.8.27-#363636?style=for-the-badge&logo=solidity)](https://soliditylang.org)
[![OpenZeppelin](https://img.shields.io/badge/OpenZeppelin-v5.4.0-#4e5ee4?style=for-the-badge&logo=openzeppelin)](https://docs.openzeppelin.com/contracts/5.x)
[![Tests](https://img.shields.io/github/actions/workflow/status/ContinuumDAO/vectm/ci.yml?branch=main&label=tests&style=for-the-badge)](https://github.com/ContinuumDAO/vectm/actions)
[![Audit](https://img.shields.io/badge/Audit-In-Progress-brightgreen?style=for-the-badge)](https://github.com/ContinuumDAO/vectm/tree/main/audits)
[![License](https://img.shields.io/github/license/ContinuumDAO/vectm?style=for-the-badge)](https://github.com/ContinuumDAO/vectm/blob/main/LICENSE)
[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-ff3366?style=for-the-badge&logo=foundry)](https://github.com/foundry-rs/foundry)

# [![Coverage](https://img.shields.io/badge/coverage-100%25-brightgreen?style=flat-square)](https://coverage.yourproject.com)

## Lock CTM tokens for a period of up to four years to become a DAO member

Voting power $P$ is based on the amount of locked CTM tokens $a$ and the
remaining lock time $t_l$ (rounded down to the nearest week) with respect to the
total possible lock duration $t_{max}$ of four years.

$$P = a \times {t_l \over t_{max}}$$







```
             _____ ______ __  ___
 _  __ ___  / ___//_  __//  |/  /
| |/ // -_)/ /__   / /  / /|_/ / 
|___/ \__/ \___/  /_/  /_/  /_/  
```

### ContinuumDAO Voting Escrow

Users can create a lock - a position which locks an amount of CTM tokens
$a$ for a specified amount of time $t_l$ (rounded by week) and weighs voting
power $P$ based on $t_l$ and maximum lockable time $t_{max}$ (equal to 4 years).

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
