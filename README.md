# ContinuumDAO Voting Escrow - Voting & Governance

## Voting & Governance

---

[![Solidity](https://img.shields.io/badge/solidity-v0.8.27-%23363636?style=for-the-badge&logo=solidity)](https://soliditylang.org)
[![OpenZeppelin](https://img.shields.io/badge/openzeppelin-v5.4.0-%234e5ee4?style=for-the-badge&logo=openzeppelin)](https://docs.openzeppelin.com/contracts/5.x)
[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-ff3366?style=for-the-badge&logo=foundry)](https://github.com/foundry-rs/foundry)
[![Audit](https://img.shields.io/badge/audit-In%20Progress-yellow?style=for-the-badge)](https://github.com/ContinuumDAO/vectm/tree/main/audits)

---

## Lock CTM tokens for a period of up to four years to become a DAO member

Voting power $P$ is based on the amount of locked CTM tokens $a$ and the remaining lock time $t_l$ (rounded down to the nearest week) with respect to the total possible lock duration $t_{max}$ of four years.

$$P = a \times {t_l \over t_{max}}$$

- Based on [Solidly Voting Escrow code](https://web.archive.org/web/20220501080953/https://github.com/solidlyexchange/solidly/blob/master/contracts/ve.sol)
- Using OpenZeppelin [Governor Votes](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.1/contracts/governance/utils/Votes.sol) to support Governance.
- OpenZeppelin [UUPS Proxy](https://docs.openzeppelin.com/contracts/5.x/api/proxy#UUPSUpgradeable) patterns are used, complying to ERC-1967.

---
