#!/usr/bin/env bash

. vars.source || exit

declare -a source_pathfiles
declare -i index=0

source_pathfiles+=("$source_path/$objects_file")
source_pathfiles+=("$source_path/$packages_file")
source_pathfiles+=("$source_path/$management_file")

for index in "${!source_pathfiles[@]}"; do
	[[ -e ${source_pathfiles[index]} ]] && rm -f "${source_pathfiles[index]}"
done

./build-qpkgs.sh sherpa || exit
./build-packages.sh || exit
./build-objects.sh || exit
./build-wiki-package-abbreviations.sh || exit
./build-manager.sh || exit
./build-archives.sh || exit
./build-readme.sh || exit
./build-forum-announcement.sh || exit

exit 0
