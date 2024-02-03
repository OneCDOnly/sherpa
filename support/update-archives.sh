#!/usr/bin/env bash

source_path="$HOME"/scripts/nas/sherpa/support
this_path=$PWD
. $source_path/vars.source || exit

cd "$source_path" || exit
./build-all.sh || exit
./commit.sh '[update] archives' || exit

cd "$this_path" || exit

exit 0
