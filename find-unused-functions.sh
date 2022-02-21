#!/usr/bin/env bash

echo -n 'checking ... '

target_pathfile=sherpa.manager.sh
target_func=''
fail=false

# shellcheck disable=SC2013
for target_func in $(grep '()$' "$target_pathfile" | grep -v '=\|\$' | sed 's|()||g'); do
    if [[ $(grep -ow "$target_func" < "$target_pathfile" | wc -l) -eq 1 ]]; then
        if [[ $fail = false ]]; then
            fail=true
            echo
        fi
        echo "$target_func()"
    fi
done

[[ $fail = true ]] && echo 'failed!' || echo 'passed!'
