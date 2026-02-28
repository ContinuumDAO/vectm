# Deployment

- [X] Check DAO parameters: votingDelay, votingPeriod.
- [X] Use `./helpers/all.sh`.
- [X] Run `forge test`.
- [ ] Make a git commit with a message "Mainnet deployed instance".
- [ ] Check that nonces are even across networks for deployer & admin.
- [ ] Check gas balances for both deployer and for admin.
- [ ] Deploy Sepolia: `./helpers/deploy-protocol/sepolia.sh c3caller`
- [ ] Deploy Linea Sepolia: `./helpers/deploy-protocol/linea-sepolia.sh c3caller`
- [ ] Add protocol contract addresses to `config/initialize.toml` (both networks), `config/deploy-dao.toml` & `config/mint.toml`.
- [ ] Initialize Sepolia: `./helpers/initialize-protocol/sepolia.sh mainnet-admin`
- [ ] Initialize Linea Sepolia: `./helpers/initialize-protocol/linea-sepolia.sh mainnet-admin`
- [ ] Deploy DAO: `./helpers/deploy-dao/linea-sepolia.sh mainnet-admin`
- [ ] Add Distribution address to `config/mint.toml` and `config/distribute.toml`.
- [ ] Configure Relayer & Scanner with new protocol addresses.
- [ ] Mint: `./helpers/mint-ctm/sepolia.sh mainnet-admin`
- [ ] Distribute: `./helpers/distribute/linea-sepolia.sh mainnet-admin`
