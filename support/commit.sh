#!/usr/bin/env bash

if [[ -e vars.source ]]; then
	. ./vars.source
else
	ColourTextBrightRed "'vars.source' not found\n"
	exit 1
fi

echo "$unstable_branch" > "$branch_pathfile"

cd "$target_path" || exit
git add . && git commit && git push
cd "$source_path" || exit

exit 0
