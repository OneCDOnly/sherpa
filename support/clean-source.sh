#!/usr/bin/env bash

. vars.source || exit

declare -a a
declare -i i=0

a+=("$management_source_file")

for i in "${!a[@]}"; do
	echo -n "cleaning '${a[i]}' ... "

	touch --reference="$support_path"/"${a[i]}" /tmp/"$i".tmp
	sed -i 's|^[ ][\t]|\t|' "$support_path"/${a[i]}					# remove leading space char left by Kate line commenter/uncommenter
	sed -i '/./b;:n;N;s/\n$//;tn' "$support_path"/${a[i]}   		# squeeze multiple linespaces to a single linespace https://unix.stackexchange.com/a/131228/94864
	touch --reference=/tmp/"$i".tmp "$support_path"/"${a[i]}"

	ShowDone
done

exit 0
