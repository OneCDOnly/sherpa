#!/usr/bin/env bash

echo "checking ... "

target_pathfile=sherpa.manager.sh
target_func=''

# shellcheck disable=SC2013
for target_func in $(grep '()$' "$target_pathfile" | grep -v '=\|\$' | sed 's|()||g'); do
    [[ $(grep -ow "$target_func" < "$target_pathfile" | wc -l) -eq 1 ]] && echo "$target_func()"
done

echo "done!"
