#!/usr/bin/env bash

if [[ ! -e vars.source ]]; then
	echo "'vars.source' not found"
	exit 1
fi

. ./vars.source

[[ ! -e $highest_package_versions_found_sorted_pathfile ]] && ./build-packages.sh "${1:-$unstable_branch}"

latest_release_version=$(grep ^sherpa_ "$highest_package_versions_found_sorted_pathfile" | tr -s ' ' | cut -d' ' -f4)
echo "latest release version: $latest_release_version"

source_pathfile=$docs_path/$readme_source_file
target_pathfile=$docs_path/$readme_file

SwapTags "$source_pathfile" "$target_pathfile"

exit 0
