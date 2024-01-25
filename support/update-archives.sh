#!/usr/bin/env bash

. vars.source || exit

./build-all.sh || exit

[[ -e $objects_file ]] && rm -f "$objects_file"
cd "$target_path" || exit
git add . && git commit -m '[update] archives' && git push
cd "$source_path" || exit

exit 0
