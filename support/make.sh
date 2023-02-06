#!/usr/bin/env bash

./check.sh || exit
./build-objects.sh || exit
./update-package-versions.sh || exit
./build-archives.sh || exit

echo -e '\nthese files have changed since the last commit:'
git diff --name-only
