#!/usr/bin/env bash

echo -n 'checking syntax ... '

fail=false

if ! shellcheck --shell=bash --exclude=1090,1117,2012,2015,2016,2018,2019,2034,2086,2119,2120,2128,2155,2181,2206,2207 sherpa.manager.source; then
    fail=true
    echo
fi

if [[ $fail = true ]]; then
    echo 'failed!'
    exit 1
else
    echo 'passed!'
    exit 0
fi
