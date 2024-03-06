#!/usr/bin/env bash

. vars.source || exit

source_pathfile=$source_path/$objects_file

[[ ! -e $source_pathfile ]] && ./build-objects.sh

grep '.Init()' "$source_pathfile" | sort

exit 0
