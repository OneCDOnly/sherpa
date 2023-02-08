#!/usr/bin/env bash

echo "hardcoding with branch: $(<"$HOME"/scripts/nas/sherpa/support/branch.txt)"

./check-syntax.sh || exit
./build-packages.sh || exit
./build-objects.sh || exit
./build-manager.sh || exit
./build-archives.sh || exit

exit 0
