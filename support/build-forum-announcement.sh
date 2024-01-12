#!/usr/bin/env bash

. vars.source || exit

[[ ! -e $highest_package_versions_found_sorted_pathfile ]] && ./build-packages.sh

latest_release_version=$(grep ^sherpa_ "$highest_package_versions_found_sorted_pathfile" | tr -s ' ' | cut -d' ' -f4)
echo "latest release version: $latest_release_version"

source_pathfile=$docs_path/$forum_source_file
target_pathfile=$docs_path/$forum_file

SwapTags "$source_pathfile" "$target_pathfile"

exit 0
