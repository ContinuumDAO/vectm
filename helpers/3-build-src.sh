#!/bin/bash

echo -e "\nBuilding src/gov..."
forge build src/gov/
echo -e "\nBuilding src/node..."
forge build src/node/
echo -e "\nBuilding src/token..."
forge build src/token/
echo -e "\nBuilding src/utils..."
forge build src/utils/
