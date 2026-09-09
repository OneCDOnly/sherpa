#!/usr/bin/env bash

. $HOME/scripts/nas/sherpa/support/environment.sourced || exit

declare -a a_a

declare -i i=0

b=''

a_a+=($support_path/$management_source_file)

for i in "${!a_a[@]}"; do
	echo -n "checking for unwanted whitespace '${a_a[i]}' ... "

	b=$(grep -nP ' \t' "${a_a[i]}")												# check for space char followed by tab char (should never happen).
	b+=$(grep -nF '    ' "${a_a[i]}" | grep -v 'dont-squeeze\|ignore-leader')	# check for 4 consecutive space chars.

	if [[ -z $b ]]; then
		ShowDone
	else
		ShowFailed
		echo "$b"

		exit 1
	fi
done

exit 0
