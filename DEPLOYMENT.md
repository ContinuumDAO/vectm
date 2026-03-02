# Deployment

- [X] Check DAO parameters: votingDelay, votingPeriod.
- [X] Use `./helpers/all.sh`.
- [X] Run `forge test`.
- [ ] Make a git commit with a message "Mainnet deployed instance".
- [ ] Check that nonces are even across networks for deployer & admin.
- [ ] Check gas balances for both deployer and for admin.
- [ ] Deploy Ethereum: `./helpers/deploy-protocol/ethereum.sh c3caller`
- [ ] Deploy Linea: `./helpers/deploy-protocol/linea.sh c3caller`
- [ ] Add protocol contract addresses to `config/initialize.toml` (both networks), `config/deploy-dao.toml` & `config/mint.toml`.
- [ ] Initialize Ethereum: `./helpers/initialize-protocol/ethereum.sh mainnet-admin`
- [ ] Initialize Linea: `./helpers/initialize-protocol/linea.sh mainnet-admin`
- [ ] Deploy DAO: `./helpers/deploy-dao/linea.sh mainnet-admin`
- [ ] Add Distribution address to `config/mint.toml` and `config/distribute.toml`.
- [ ] Mint: `./helpers/mint-ctm/ethereum.sh mainnet-admin`
- [ ] Distribute: `./helpers/distribute/linea.sh mainnet-admin`
- [ ] Configure Relayer & Scanner with new protocol addresses.
