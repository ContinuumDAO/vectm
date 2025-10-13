#!/bin/bash

echo -e "\n🔨 Compiling test/helpers..."
forge build test/helpers/
echo -e "🔨 Compiling test/gov..."
forge build test/gov/
echo -e "🔨 Compiling test/node..."
forge build test/node/
echo -e "🔨 Compiling test/token..."
forge build test/token/
