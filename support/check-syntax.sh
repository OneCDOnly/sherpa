#!/usr/bin/env bash

. $HOME/scripts/nas/sherpa/support/environment.sourced || exit

shopt -s compat32
declare -a a
declare -a b

declare -i i=0

a+=("$support_path/$management_source_file")
b+=(1090,2012,2016,2018,2019,2034,2048,2086,2119,2120,2154,2206,2207)

a+=("$support_path/$management_file")
b+=(1090,2012,2016,2018,2019,2034,2048,2086,2119,2120,2154,2206,2207,2283,2295)

# a+=("$support_path/*.sh")
# b+=(1036,1090,1091,2001,2006,2012,2016,2028,2034,2054,2086,2154,2155)

for i in "${!a[@]}"; do
	[[ -e ${a[i]} ]] || continue

	echo -n "checking syntax '${a[i]}' ... "

	if shellcheck --shell=bash --exclude="${b[i]}" "${a[i]}"; then
		ShowDone
	else
		ShowFailed

		exit 1
	fi
done

exit 0
