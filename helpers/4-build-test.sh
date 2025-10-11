#!/bin/bash

echo -e "\n🔨 Compiling test/helpers..."
forge build test/helpers/
echo -e "\n🔨 Compiling test/gov..."
forge build test/gov/
echo -e "\n🔨 Compiling test/node..."
forge build test/node/
echo -e "\n🔨 Compiling test/token..."
forge build test/token/
