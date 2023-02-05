#!/usr/bin/env bash

./check.sh || exit
./build-objects.sh || exit
./build-archives.sh || exit

echo 'these files have changed since the last commit:'
git diff --name-only
