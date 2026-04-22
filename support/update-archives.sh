#!/usr/bin/env bash

. $HOME/scripts/nas/sherpa/support/environment.sourced || exit

./build-all.sh || exit
./commit.sh '[update] management archives' nocheck || exit
