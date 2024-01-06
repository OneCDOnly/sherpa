#!/usr/bin/env bash

. vars.source || exit

source_pathfile=$source_path/$management_source_file
target_pathfile=$source_path/$management_file

SwapTags "$source_pathfile" "$target_pathfile"
Squeeze "$target_pathfile" "$target_pathfile"

[[ -e $target_pathfile ]] && chmod 554 "$target_pathfile"

exit 0
