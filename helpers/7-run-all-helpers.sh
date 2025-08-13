#!/bin/bash

./helpers/0-flatten.sh
./helpers/1-clean.sh
./helpers/2-build-flattened.sh
./helpers/3-build-src.sh
./helpers/4-build-test.sh
./helpers/5-build-script.sh
