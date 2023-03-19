#!/usr/bin/env bash

# input:
#	- a string of package names
#   - action

# check their last launch times for a specific action
# sort them based on current policy setting.

# output:
#	stdout=sorted list of package names

policy:slowest()
	{

	# package names will be listed with the longest action time first. Packages without times will be listed before timed packages.

	# input:
	#   $action_times_pathfile (global) : a file with previously recorded execution times for each package for a specific action
	#   $1 : a string of package names to be sorted

	# output:
	#	stdout : sorted package names

	[[ ${#1} -gt 0 ]] || return

	if [[ ! -s $action_times_pathfile ]]; then
		echo "${1:-}"
		return
	fi

	local target_packages=($1)
	local target_timed=''
	local package=''
	local unsorted_timed=()
	local unsorted_untimed=()
	local sorted_timed=()
	local re=''

	# get list of only supplied package names where times have been recorded, sort this list by time, then return names-only
 	local target_timed=$(sort -k2 -r <<<"$(for package in ${target_packages[*]}; do
		re="\b${package}\b"
		grep "$re" "$action_times_pathfile"
		done )" | sed 's/|.*$//' | tr '\n' ' ')

	# separate timed package names from untimed
	for package in ${target_packages[*]}; do
		re="\b${package}\b"

		if [[ "$target_timed" =~ $re ]]; then
			unsorted_timed+=($package)
		else
			unsorted_untimed+=($package)
		fi
	done

	# sort supplied package names as-per time-sorted list
	for package in ${target_timed[*]}; do
		re="\b${package}\b"

		if [[ "${target_timed[*]}" =~ $re ]]; then
			sorted_timed+=($package)
		fi
	done

	echo "${unsorted_untimed[*]%% } ${sorted_timed[*]%% }"

	return 0

	} 2>/dev/null

policy:quickest()
	{

	# package names will be listed with the shorted action time first. Packages without times will be listed before timed packages.

	# input:
	#   $action_times_pathfile (global) : a file with execution times for each package
	#   $1 : a string of package names to be sorted

	# output:
	#	stdout : sorted package names

	[[ ${#1} -gt 0 ]] || return

	if [[ ! -s $action_times_pathfile ]]; then
		echo "${1:-}"
		return
	fi

	local target_packages=($1)
	local target_timed=''
	local package=''
	local unsorted_timed=()
	local unsorted_untimed=()
	local sorted_timed=()
	local re=''

	# get list of only supplied package names where times have been recorded, sort this list by time, then return names-only
 	local target_timed=$(sort -k2 <<<"$(for package in ${target_packages[*]}; do
		re="\b${package}\b"
		grep "$re" "$action_times_pathfile"
		done )" | sed 's/|.*$//' | tr '\n' ' ')

	# separate timed package names from untimed
	for package in ${target_packages[*]}; do
		re="\b${package}\b"

		if [[ "$target_timed" =~ $re ]]; then
			unsorted_timed+=($package)
		else
			unsorted_untimed+=($package)
		fi
	done

	# sort supplied package names as-per time-sorted list
	for package in ${target_timed[*]}; do
		re="\b${package}\b"

		if [[ "${target_timed[*]}" =~ $re ]]; then
			sorted_timed+=($package)
		fi
	done

	echo "${unsorted_untimed[*]%% } ${sorted_timed[*]%% }"

	return 0

	} 2>/dev/null

policy:none()
	{

	[[ ${#1} -gt 0 ]] || return

	echo "${1%% }"

	return 0

	} 2>/dev/null

input_names=(c ab y d eywtrwu  aa rrr c a)
action=${1:-start}
action_times_pathfile="$action.milliseconds"

echo "action: '$action'"

sorted_names=$(policy:none "${input_names[*]}") || exit
echo "'none' policy: '$sorted_names'"

sorted_names=$(policy:slowest "${input_names[*]}") || exit
echo "'slowest' policy: '$sorted_names'"

# for package_name in $sorted_names; do
# 	echo "whitespace name: '$package_name'"
# done

sorted_names=$(policy:quickest "${input_names[*]}") || exit
echo "'quickest' policy: '$sorted_names'"
