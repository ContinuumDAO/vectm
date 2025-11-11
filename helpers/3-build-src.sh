#!/bin/bash

echo -e "\n🔨 Compiling src/governance..."
forge build src/governance/
echo -e "🔨 Compiling src/node..."
forge build src/node/
echo -e "🔨 Compiling src/token..."
forge build src/token/
echo -e "🔨 Compiling src/utils..."
forge build src/utils/
