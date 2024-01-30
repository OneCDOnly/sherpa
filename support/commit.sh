#!/usr/bin/env bash

source_path="$HOME"/scripts/nas/sherpa/support
this_path=$PWD
. $source_path/vars.source || exit

cd "$source_path" || exit
./check-syntax.sh || exit

[[ -e $objects_file ]] && rm -f "$objects_file"
[[ -e $management_file ]] && rm -f "$management_file"
[[ -e $packages_file ]] && rm -f "$packages_file"

cd "$target_path" || exit

git add . && git commit && git push

cd "$this_path" || exit

exit 0
