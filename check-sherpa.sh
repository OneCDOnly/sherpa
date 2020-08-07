#!/usr/bin/env bash

echo -n "checking ... "

shellcheck --shell=bash --exclude=1117,2016,2021,2155 *.sh && echo 'passed!' || echo 'failed!'
