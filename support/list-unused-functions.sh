#!/usr/bin/env bash

if [[ -e vars.source ]]; then
	. ./vars.source
else
	echo "'vars.source' not found"
	exit 1
fi

source_pathfile="$source_path"/sherpa.manager.source
target_func=''

# shellcheck disable=SC2013
for target_func in $(grep '()$' "$source_pathfile" | grep -v '=\|\$\|_(' | sed 's|()||g'); do
	case $target_func in
		IPKs:upgrade|IPKs:install|PIPs:install)		# called by constructing the function name with vars
			continue
			;;
		QPKGs.Actions:ListAll|QPKG.AppAuthor)		# unused for-now
			continue
	esac

	if [[ $(grep -ow "$target_func" < "$source_pathfile" | wc -l) -eq 1 ]]; then
		echo "$target_func()"
	fi
done
