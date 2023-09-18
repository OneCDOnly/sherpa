#!/usr/bin/env bash

if [[ ! -e vars.source ]]; then
	echo "'vars.source' not found"
	exit 1
fi

. ./vars.source

target_branch=${1:-$unstable_branch}
cdn_sherpa_url="$cdn_onecd_url/sherpa/$target_branch"
cdn_sherpa_packages_url="$cdn_sherpa_url/QPKGs/<?package_name?>/build"

source_pathfile="$source_path/$management_source_file"
target_pathfile="$source_path/$management_file"

SwapTags "$source_pathfile" "$target_pathfile"
Squeeze "$target_pathfile" "$target_pathfile"

[[ -e $target_pathfile ]] && chmod 554 "$target_pathfile"

exit 0
