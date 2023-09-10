#!/usr/bin/env bash

# compiler for all sherpa archives.

if [[ ! -e vars.source ]]; then
	echo "'vars.source' not found"
	exit 1
fi

. ./vars.source

echo -n 'building archives ... '

declare -a source_pathfiles
declare -a target_pathfiles
declare -i index=0

source_pathfiles+=("$source_path/$objects_file")
target_pathfiles+=("$target_path/$objects_archive_file")

source_pathfiles+=("$source_path/$packages_file")
target_pathfiles+=("$target_path/$packages_archive_file")

source_pathfiles+=("$source_path/$management_file")
target_pathfiles+=("$target_path/$management_archive_file")

for index in "${!source_pathfiles[@]}"; do
	[[ -e ${target_pathfiles[index]} ]] && rm -f "${target_pathfiles[index]}"

	if [[ ! -e ${source_pathfiles[index]} ]]; then
		ColourTextBrightRed "'${source_pathfiles[index]}' not found, "
		continue
	fi

	tar --create --gzip --numeric-owner --file="${target_pathfiles[index]}" --directory="$source_path" "$(basename "${source_pathfiles[index]}")"

	if [[ ! -s ${target_pathfiles[index]} ]]; then
		ColourTextBrightRed "'${target_pathfiles[index]}' was not written"; echo
		exit 1
	fi

	[[ -e ${source_pathfiles[index]} ]] && rm -f "${source_pathfiles[index]}"
	chmod 444 "${target_pathfiles[index]}"
done

ShowDone
exit 0
