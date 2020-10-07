#!/usr/bin/env bash

echo -n "checking ... "

shellcheck --shell=bash --exclude=1003,1090,1117,2016,2021,2086,2155,2181,2206,2207 ./*.sh && echo 'passed!' || echo 'failed!'
