#!/usr/bin/env bash

source_path="$HOME"/scripts/nas/sherpa/support
. $source_path/vars.source || exit

[[ -e $objects_file ]] && rm -f "$objects_file"
cd "$target_path" || exit
git add . && git commit && git push
cd "$source_path" || exit

exit 0
