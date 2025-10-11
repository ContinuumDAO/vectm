#!/bin/bash

echo -e "\n🔨 Compiling src/gov..."
forge build src/gov/
echo -e "🔨 Compiling src/node..."
forge build src/node/
echo -e "🔨 Compiling src/token..."
forge build src/token/
echo -e "🔨 Compiling src/utils..."
forge build src/utils/
