#!/usr/bin/env bash

. vars.source || exit

declare -a a
declare -i i=0

a+=("$support_path/$objects_file")
a+=("$support_path/$management_file")

for i in "${!a[@]}"; do
	[[ -e ${a[i]} ]] && rm -f "${a[i]}"
done

$support_path/build-objects.sh || exit
$support_path/build-manager.sh || exit
$support_path/build-archives.sh || exit
