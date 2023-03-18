#!/usr/bin/env bash

# input:
#	- a string of package names
#   - action

# check their last launch times for a specific action
# sort them based on current policy setting.

# output:
#	stdout=sorted list of package names

policy:longest()
	{

	# package names will be listed with the longest action time first. Packages without times will be listed before timed packages.

	[[ ${#1} -gt 0 ]] || return

	if [[ ! -s $action_times_pathfile ]]; then
		echo "${1:-}"
		return
	fi

	local package=''
	local source_timed=''
	local supplied_packages=($1)
	local unsorted_timed=()
	local unsorted_untimed=()
	local sorted_supplied=()
	local re=''

# echo "supplied_packages=[${supplied_packages[*]}]"

	# get list of only supplied package names where times have been recorded, sort this list by time, then return names-only
 	local source_timed=$(sort -k2 -r <<<"$(for package in ${supplied_packages[*]}; do
		re="\b${package}\b"
		grep "$re" "$action_times_pathfile"
		done )" | sed 's/|.*$//' | tr '\n' ' ')

# echo "source_timed=[$source_timed]"

	# separate timed package names from untimed
	for package in ${supplied_packages[*]}; do
# echo -e "\nchecking supplied name [$package]"
		re="\b${package}\b"

		if [[ "$source_timed" =~ $re ]]; then
# echo "adding [$package] to unsorted_timed"
			unsorted_timed+=($package)
		else
# echo "adding [$package] to unsorted_untimed"
			unsorted_untimed+=($package)
		fi
	done

# echo
# echo "unsorted_timed=[${unsorted_timed[*]}]"
# echo "unsorted_untimed=[${unsorted_untimed[*]}]"
# echo '----------------------------------'

	# sort supplied package names as-per time-sorted list
	for package in ${source_timed[*]}; do
# echo -e "\nchecking sorted name [$package]"
		re="\b${package}\b"

		if [[ "${source_timed[*]}" =~ $re ]]; then
# echo "adding [$package] to sorted_supplied"
			sorted_supplied+=($package)
		fi
	done

# echo
# echo "sorted_supplied=[${sorted_supplied[*]}]"
# echo

# echo "final list=[${unsorted_untimed[*]%% } ${sorted_supplied[*]%% }}"
echo "${unsorted_untimed[*]%% } ${sorted_supplied[*]%% }"

	return 0

	} 2>/dev/null

policy:shortest()
	{

	[[ -s $action_times_pathfile ]] || return
	[[ ${#1} -gt 0 ]] || return

	local sorted=$(sort -k2 <<<"$(for buff in $1; do
		grep "^$buff" "$action_times_pathfile"
	done)" | sed 's/|.*$//' | tr '\n' ' ')

	echo "${sorted%% }"

	return 0

	} 2>/dev/null

policy:none()
	{

	[[ ${#1} -gt 0 ]] || return

	echo "${1%% }"

	return 0

	} 2>/dev/null

input_names=(c ab y d eywtrwu  aa rrr)

action=${1:-start}
echo "action: '$action'"

action_times_pathfile="$action.milliseconds"

# policy:longest "${input_names[*]}" || exit
# exit
sorted_names=$(policy:longest "${input_names[*]}") || exit
echo "sorted by longest policy: '$sorted_names'"

for package_name in $sorted_names; do
	echo "whitespace name: '$package_name'"
done


# sorted_names=$(policy:shortest "${input_names[*]}") || exit
# echo "shortest: '$sorted_names'"
#
# sorted_names=$(policy:none "${input_names[*]}") || exit
# echo "none: '$sorted_names'"
