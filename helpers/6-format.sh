#!/bin/bash

echo -e "\nFormatting codebase..."

forge fmt src/gov/CTMDAOGovernor.sol
forge fmt src/gov/GovernorCountingMultiple.sol
forge fmt src/node
forge fmt src/token
forge fmt src/utils
forge fmt test/
forge fmt script/
