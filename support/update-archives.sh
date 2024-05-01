#!/usr/bin/env bash

. vars.source || exit

./build-all.sh || exit
./commit.sh '[update] management archives' || exit
