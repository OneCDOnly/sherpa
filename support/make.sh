#!/usr/bin/env bash

echo "branch: $(<$HOME/scripts/nas/sherpa/support/branch.txt)"

./check-syntax.sh || exit
./build-objects.sh || exit
./build-packages.sh || exit
./build-manager.sh || exit
./build-archives.sh || exit

echo -e '\nthese files have changed since the last commit:'
git diff --name-only
