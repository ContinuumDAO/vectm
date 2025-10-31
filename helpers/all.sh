#!/bin/bash

echo -e "\n💻 Running all operations..."

./helpers/0-flatten.sh
./helpers/1-clean.sh
./helpers/2-build.sh
./helpers/3-build-src.sh
./helpers/4-build-test.sh
./helpers/5-build-script.sh

echo -e "\n✅ All operations complete!"
