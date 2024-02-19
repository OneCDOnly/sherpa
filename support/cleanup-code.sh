#!/usr/bin/env bash

. vars.source || exit

declare -a filenames
declare -i index=0

filenames+=("$management_source_file")
filenames+=("$service_library_source_file")

for index in "${!filenames[@]}"; do
	echo -n "cleaning code '${filenames[index]}' ... "

	touch --reference="$source_path"/"${filenames[index]}" /tmp/"$index".tmp
	sed -i 's|^[ ][\t]|\t|' "$source_path"/${filenames[index]}		# remove leading space char left by kate line commenter/uncommenter
	touch --reference=/tmp/"$index".tmp "$source_path"/"${filenames[index]}"

	ShowPassed
done

exit 0
