#!/usr/bin/env bash

echo -n 'checking ... '

fail=false

if ! shellcheck --shell=bash --exclude=1090,1117,2015,2016,2018,2019,2086,2155,2181,2206,2207 ./*.sh; then
    fail=true
    echo
fi

[[ $fail = true ]] && echo 'failed!' || echo 'passed!'
