#!/usr/bin/env bash

declare -a filenames
declare -a exclusions
declare -i index=0

working_path=$HOME/scripts/nas/sherpa/support

filenames+=(sherpa.manager.source)
exclusions+=(1090,1117,2012,2015,2016,2018,2019,2034,2086,2119,2120,2128,2155,2181,2206,2207)

filenames+=(packages.source)
exclusions+=(1036,1088,2034)

filenames+=('*.sh')
exclusions+=(1036,2001,2006,2016,2034,2054,2086,2155)

for index in "${!filenames[@]}"; do
    echo -n "checking '${filenames[index]}' ... "

    if shellcheck --shell=bash --exclude="${exclusions[index]}" "$working_path"/${filenames[index]}; then
        echo 'passed'
    else
        echo 'failed!'
        exit 1
    fi
done

exit 0
