#!/usr/bin/env bash

target_pathfile=sherpa.manager.sh
target_func=''
count=0

for target_func in $(grep '()$' "$target_pathfile" | grep -v '=\|\$' | sed 's|()||g'); do
	count=$(grep -ow "$target_func" < "$target_pathfile" | wc -l)
	[[ $count -eq 1 ]] && echo "$target_func()"
done
