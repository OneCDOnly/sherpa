#!/usr/bin/env bash

. vars.source || exit

declare -a filenames
declare -a exclusions
declare -i index=0

filenames+=("$management_source_file")
exclusions+=(1090,1117,2012,2015,2016,2018,2019,2030,2031,2034,2086,2119,2120,2128,2155,2178,2181,2194,2206,2207,2209,2254,2317)

filenames+=("$service_library_source_file")
exclusions+=(1087,1090,1117,2012,2015,2016,2018,2019,2034,2086,2119,2120,2128,2155,2181,2194,2206,2207,2254)

filenames+=("$packages_source_file")
exclusions+=(1009,1036,1072,1073,1088,2034)

filenames+=('*.sh')
exclusions+=(1036,1090,1091,2001,2006,2012,2016,2028,2034,2054,2086,2154,2155)

for index in "${!filenames[@]}"; do
	echo -n "checking '${filenames[index]}' ... "

	if shellcheck --shell=bash --exclude="${exclusions[index]}" "$source_path"/${filenames[index]}; then
		ShowPassed
	else
		ShowFailed
		exit 1
	fi
done

exit 0
