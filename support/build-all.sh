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

# touch a file in the main sherpa QPKG so it will be rebuilt by 'build-qpkgs.sh'
touch "$qpkgs_path"/sherpa/qpkg.source

# ./check-syntax.sh || exit
./build-qpkgs.sh || exit
./build-packages.sh || exit
./build-objects.sh || exit
./build-wiki-package-abbreviations.sh || exit
./build-manager.sh || exit
./build-archives.sh || exit
./build-readme.sh || exit
./build-forum-announcement.sh || exit

exit 0
