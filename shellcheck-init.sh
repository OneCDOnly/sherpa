#!/usr/bin/env bash

# used for checking QPKG service scripts

[[ -z $1 || ! -f $1 ]] && exit 1

target=$1

{

echo -n "checking $target "

shellcheck --shell=bash --exclude=1010,1117,2004,2015,2016,2021,2053,2068,2086,2128,2155,2178,2181,2206,2207 "$target"

} && echo 'passed!' || echo 'failed!'
