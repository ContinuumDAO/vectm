#!/bin/bash

echo -e "\nFormatting codebase..."

forge fmt src/governance/ContinuumDAO.sol
forge fmt src/governance/GovernorCountingMultiple.sol
forge fmt src/governance/IContinuumDAO.sol
forge fmt src/node
forge fmt src/token
forge fmt src/utils
forge fmt test/
forge fmt script/
