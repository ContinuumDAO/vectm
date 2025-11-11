#!/bin/bash

# remove old build files
rm -r build/

# create folders
mkdir -p build/
mkdir -p build/governance/
mkdir -p build/node/
mkdir -p build/token/
mkdir -p build/utils/

echo -e "\n📄 Flattening src/ to build/..."

# gov
forge flatten src/governance/ContinuumDAO.sol --output build/governance/ContinuumDAO.sol

# node
forge flatten src/node/NodeProperties.sol --output build/node/NodeProperties.sol
forge flatten src/node/Rewards.sol --output build/node/Rewards.sol

# token
forge flatten src/token/CTM.sol --output build/token/CTM.sol
forge flatten src/token/VotingEscrow.sol --output build/token/VotingEscrow.sol

# utils
forge flatten src/utils/VotingEscrowProxy.sol --output build/utils/VotingEscrowProxy.sol
