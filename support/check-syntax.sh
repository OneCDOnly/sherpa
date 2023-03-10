#!/usr/bin/env bash

if [[ ! -e vars.source ]]; then
	echo "'vars.source' not found"
	exit 1
fi

. ./vars.source

declare -a filenames
declare -a exclusions
declare -i index=0

filenames+=(sherpa.manager.source)
exclusions+=(1090,1117,2012,2015,2016,2018,2019,2034,2086,2119,2120,2128,2155,2181,2206,2207)

filenames+=(packages.source)
exclusions+=(1036,1088,2034)

filenames+=('*.sh')
exclusions+=(1036,1090,1091,2001,2006,2016,2034,2054,2086,2154,2155)

for index in "${!filenames[@]}"; do
	echo -n "checking '${filenames[index]}' ... "

	if shellcheck --shell=bash --exclude="${exclusions[index]}" "$source_path"/${filenames[index]}; then
		ColourTextBrightGreen 'passed\n'
	else
		ColourTextBrightRed 'failed\n'
		exit 1
	fi
done

exit 0
