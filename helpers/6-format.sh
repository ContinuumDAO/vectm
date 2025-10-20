#!/bin/bash

echo -e "\nFormatting codebase..."

forge fmt build/
forge fmt src/
forge fmt test/
forge fmt script/
