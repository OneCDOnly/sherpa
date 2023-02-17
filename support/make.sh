#!/usr/bin/env bash

if [[ -e vars.source ]]; then
	. ./vars.source
else
	ColourTextBrightRed "'vars.source' not found\n"
	exit 1
fi

echo -e "hardcoding with branch: $branch_msg"

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
