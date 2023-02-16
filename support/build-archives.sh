#!/usr/bin/env bash

# compiler for all sherpa archives

echo -n 'building archives ... '

if [[ -e vars.source ]]; then
	. ./vars.source
else
	echo "'vars.source' not found"
	exit 1
fi

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
	tar --create --gzip --numeric-owner --file="${target_pathfiles[index]}" --directory="$source_path" "$(basename "${source_pathfiles[index]}")"
	[[ -e ${source_pathfiles[index]} ]] && rm -f "${source_pathfiles[index]}"
	chmod 444 "${target_pathfiles[index]}"
done

echo 'done'
exit 0
