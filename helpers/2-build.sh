#!/bin/bash

echo -e "\n🔨 Compiling build/governance..."
forge build build/governance/
echo -e "🔨 Compiling build/node..."
forge build build/node/
echo -e "🔨 Compiling build/token..."
forge build build/token/
echo -e "🔨 Compiling build/utils..."
forge build build/utils/
