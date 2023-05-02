#!/usr/bin/env bash

if [[ ! -e vars.source ]]; then
	echo "'vars.source' not found"
	exit 1
fi

. ./vars.source

declare -a source_pathfiles
declare -i index=0

source_pathfiles+=("$source_path"/objects)
source_pathfiles+=("$source_path"/packages)
source_pathfiles+=("$source_path"/sherpa.manager.sh)

for index in "${!source_pathfiles[@]}"; do
	[[ -e ${source_pathfiles[index]} ]] && rm -f "${source_pathfiles[index]}"
done

./check-syntax.sh || exit
./build-packages.sh || exit
./build-objects.sh || exit
./build-manager.sh || exit
./build-archives.sh || exit

exit 0
