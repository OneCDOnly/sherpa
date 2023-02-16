#!/usr/bin/env bash

target_pathfile=../sherpa.manager.sh
target_func=''

# shellcheck disable=SC2013
for target_func in $(grep '()$' "$target_pathfile" | grep -v '=\|\$\|_(' | sed 's|()||g'); do
	if [[ $(grep -ow "$target_func" < "$target_pathfile" | wc -l) -eq 1 ]]; then
		echo "$target_func()"
	fi
done
