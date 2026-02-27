# Deployment

- [X] Use `./helpers/all.sh`.
- [ ] Make a git commit with a message "Mainnet deployed instance".
- [ ] Check that nonces are even across networks.
- [ ] Check gas balances for both deployer and for admin.
- [ ] `./helpers/deploy-protocol/sepolia.sh c3caller`
- [ ] Add protocol contract addresses to `config/initialize.toml` (both networks), `config/deploy-dao.toml` & `config/mint.toml`.
- [ ] Configure Relayer & Scanner with new protocol addresses.
- [ ] `./helpers/initialize-protocol/sepolia.sh mainnet-admin`
- [ ] `./helpers/deploy-protocol/linea-sepolia.sh c3caller`
- [ ] `./helpers/initialize-protocol/linea-sepolia.sh mainnet-admin`
- [ ] `./helpers/deploy-dao/linea-sepolia.sh mainnet-admin`
- [ ] Add DAO contract addresses to `config/distribute.toml` and `config/mint.toml`.
- [ ] `./helpers/distribute/linea-sepolia.sh mainnet-admin`
- [ ] `./helpers/mint-ctm/sepolia.sh mainnet-admin`
