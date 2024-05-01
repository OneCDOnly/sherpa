#!/usr/bin/env bash

. vars.source || exit

declare -a a
declare -i i=0

a+=("$management_source_file")

for i in "${!a[@]}"; do
	echo -n "cleaning '${a[i]}' ... "

	touch --reference="$support_path"/"${a[i]}" /tmp/"$i".tmp
	sed -i 's|^[ ][\t]|\t|' "$support_path"/${a[i]}					# remove leading space char left by Kate line commenter/uncommenter
	touch --reference=/tmp/"$i".tmp "$support_path"/"${a[i]}"

	ShowPassed
done

exit 0
