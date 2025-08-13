#!/bin/bash

echo -e "\nBuilding test/helpers..."
forge build test/helpers/
echo -e "\nBuilding test/gov..."
forge build test/gov/
echo -e "\nBuilding test/node..."
forge build test/node/
echo -e "\nBuilding test/token..."
forge build test/token/
