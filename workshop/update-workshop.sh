#!/usr/bin/env bash

source_path="$HOME"/scripts/nas/sherpa/support
this_path=$PWD
. $source_path/vars.source || exit

[[ -e $source_path/$objects_file ]] && rm -f "$source_path/$objects_file"
[[ -e $source_path/$management_file ]] && rm -f "$source_path/$management_file"
[[ -e $source_path/$packages_file ]] && rm -f "$source_path/$packages_file"

git add ./* && git commit -m '[update] workshop' && git push

exit 0
