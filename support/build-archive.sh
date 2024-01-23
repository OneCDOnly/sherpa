#!/usr/bin/env bash

# compiler for sherpa archive.

. vars.source || exit

echo -n 'building archive ... '

target_pathfile="$target_path/$management_archive_file"
[[ -e $target_pathfile ]] && rm -f "$target_pathfile"

tar --create --gzip --numeric-owner --file="$target_pathfile" --directory="$source_path" "$objects_file" "$packages_file" "$management_file"

if [[ ! -s $target_pathfile ]]; then
	ColourTextBrightRed "'$target_pathfile' was not written"; echo
	exit 1
fi

rm -f "$objects_file" "$packages_file" "$management_file"
chmod 444 "$target_pathfile"

ShowDone
exit 0
