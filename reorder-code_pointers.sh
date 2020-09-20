#!/bin/bash

base_path="${HOME}/scripts/nas/sherpa"
target_path="${base_path}/backups-b4-reordering"
source_file="sherpa.manager.sh"
source_pathfile="$base_path/$source_file"
target_pathfile="$target_path/$source_file.$(date +%s).bak"

mkdir -p "$target_path"

cp "$source_pathfile" "$target_pathfile"

# https://stackoverflow.com/questions/42869901/bash-script-to-rewrite-numbers-sequentially
perl -i -pe 's/(\bcode_pointer=)\d+/$1.$i++/ge' "$source_pathfile"
