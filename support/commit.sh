#!/usr/bin/env bash

if [[ ! -e vars.source ]]; then
	echo "'vars.source' not found"
	exit 1
fi

. ./vars.source

# ./check-syntax.sh || exit

[[ -e $objects_file ]] && rm -f "$objects_file"
cd "$target_path" || exit
git add . && git commit && git push
cd "$source_path" || exit

exit 0
