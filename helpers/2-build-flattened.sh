#!/bin/bash

echo -e "\nBuilding flattened/gov..."
forge build flattened/gov/
echo -e "\nBuilding flattened/node..."
forge build flattened/node/
echo -e "\nBuilding flattened/token..."
forge build flattened/token/
echo -e "\nBuilding flattened/utils..."
forge build flattened/utils/
