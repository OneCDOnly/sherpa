#!/usr/bin/env bash

echo -n "checking ... "

shellcheck --shell=bash --exclude=1010,1091,1117,2004,2015,2016,2021,2053,2068,2086,2128,2155,2178,2181,2206,2207 *.sh && echo 'passed!' || echo 'failed!'
