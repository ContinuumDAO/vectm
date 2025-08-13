#!/bin/bash

# remove old flattened files
rm -r flattened/

# create folders
mkdir -p flattened/
mkdir -p flattened/gov/
mkdir -p flattened/node/
mkdir -p flattened/token/
mkdir -p flattened/utils/

# gov
forge flatten src/gov/CTMDAOGovernor.sol --output flattened/gov/CTMDAOGovernor.sol

# node
forge flatten src/node/NodeProperties.sol --output flattened/node/NodeProperties.sol
forge flatten src/node/Rewards.sol --output flattened/node/Rewards.sol

# token
forge flatten src/token/CTM.sol --output flattened/token/CTM.sol
forge flatten src/token/VotingEscrow.sol --output flattened/token/VotingEscrow.sol

# utils
forge flatten src/utils/VotingEscrowProxy.sol --output flattened/utils/VotingEscrowProxy.sol
