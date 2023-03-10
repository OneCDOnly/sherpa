#!/usr/bin/env bash

# compiler for all sherpa archives

if [[ ! -e vars.source ]]; then
	echo "'vars.source' not found"
	exit 1
fi

. ./vars.source

echo -n 'building archives ... '

declare -a source_pathfiles
declare -a target_pathfiles
declare -i index=0

source_pathfiles+=("$source_path"/objects)
target_pathfiles+=("$target_path"/objects.tar.gz)

source_pathfiles+=("$source_path"/packages)
target_pathfiles+=("$target_path"/packages.tar.gz)

source_pathfiles+=("$source_path"/sherpa.manager.sh)
target_pathfiles+=("$target_path"/sherpa.manager.tar.gz)

for index in "${!source_pathfiles[@]}"; do
	[[ -e ${target_pathfiles[index]} ]] && rm -f "${target_pathfiles[index]}"

	if [[ ! -e ${source_pathfiles[index]} ]]; then
		ColourTextBrightRed "'${source_pathfiles[index]}' not found, "
		continue
	fi

	tar --create --gzip --numeric-owner --file="${target_pathfiles[index]}" --directory="$source_path" "$(basename "${source_pathfiles[index]}")"

	if [[ ! -s ${target_pathfiles[index]} ]]; then
		ColourTextBrightRed "'${target_pathfiles[index]}' was not written\n"
		exit 1
	fi

	[[ -e ${source_pathfiles[index]} ]] && rm -f "${source_pathfiles[index]}"
	chmod 444 "${target_pathfiles[index]}"
done

ColourTextBrightGreen 'done\n'
exit 0
