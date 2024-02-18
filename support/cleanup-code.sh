#!/usr/bin/env bash

. vars.source || exit

declare -a filenames
declare -i index=0

filenames+=("$management_source_file")
filenames+=("$service_library_source_file")
filenames+=('*.sh')

for index in "${!filenames[@]}"; do
	echo -n "cleaning code '${filenames[index]}' ... "

	sed -i 's|^[ ][\t]|\t|' "$source_path"/${filenames[index]}		# remove leading space char left by kate line commenter/uncommenter
	ShowPassed
done

exit 0
