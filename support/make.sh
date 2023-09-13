#!/usr/bin/env bash

if [[ ! -e vars.source ]]; then
	echo "'vars.source' not found"
	exit 1
fi

. ./vars.source

declare -a source_pathfiles
declare -i index=0

source_pathfiles+=("$source_path/$objects_file")
source_pathfiles+=("$source_path/$packages_file")
source_pathfiles+=("$source_path/$management_file")

for index in "${!source_pathfiles[@]}"; do
	[[ -e ${source_pathfiles[index]} ]] && rm -f "${source_pathfiles[index]}"
done

./check-syntax.sh || exit
./build-qpkgs.sh || exit
./build-packages.sh "${1:-$unstable_branch}" || exit
./build-objects.sh || exit
./build-manager.sh "${1:-$unstable_branch}" || exit
./build-archives.sh || exit

exit 0
