#!/bin/bash

echo -e "\n🔨 Compiling build/gov..."
forge build build/gov/
echo -e "🔨 Compiling build/node..."
forge build build/node/
echo -e "🔨 Compiling build/token..."
forge build build/token/
echo -e "🔨 Compiling build/utils..."
forge build build/utils/
