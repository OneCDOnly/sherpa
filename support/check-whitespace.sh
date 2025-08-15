#!/usr/bin/env bash

. $HOME/scripts/nas/sherpa/support/environment.sourced || exit

declare -a a
declare -a b
declare -i i=0

a+=($support_path/$management_source_file)

for i in "${!a[@]}"; do
	echo -n "checking for unwanted whitespace '${a[i]}' ... "

	b=$(grep -nP ' \t' "${a[i]}")													# check for space char followed by tab char (should never happen)
	b+=$(grep -nF '    ' "${a[i]}" | grep -v 'squeezer-ignore\|whitespace-ignore')	# check for 4 consecutive space chars.

	if [[ -z $b ]]; then
		ShowDone
	else
		ShowFailed
		echo "$b"
		exit 1
	fi
done

exit 0
