#!/usr/bin/env bash

this_path=$PWD
. $HOME/scripts/nas/sherpa/support/vars.source || exit

cd "$support_path" || exit

./build-all.sh || exit
./commit.sh '[update] management archives' || exit

cd "$qpkgs_root_path" || exit
git add .
git commit -m '[update] QPKG archives' || exit
git push

cd "$this_path" || exit
