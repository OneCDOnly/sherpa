#!/bin/bash

. .package_name

source_path="${HOME}/scripts/nas/${package_name}"
source_file="${package_name}.sh"
target_path="${source_path}/uploaded-archives"
prefix="local SCRIPT_VERSION="
version=$(grep -F "$prefix" "${source_path}/${source_file}" | sed "s|$prefix||;s|\"||g;s|^[ \t]*||")
target_pathfile="${target_path}/${package_name}.${version}.tar.gz"

echo "target_pathfile: [$target_pathfile]"

tar -zcf "$target_pathfile" -C "$source_path"/ "$source_file" SABnzbdplus SickRage CouchPotato2 LazyLibrarian --owner=0 --group=0
cp "$target_pathfile" "${source_path}/${package_name}.tar.gz"
