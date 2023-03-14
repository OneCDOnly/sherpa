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

	[[ -s $action_times_pathfile ]] || return
	[[ ${#1} -gt 0 ]] || return

# 	local sorted=$(sort -k2 -r <<<"$(for buff in $1; do
# 		grep "^$buff" "$action_times_pathfile"
# 	done)" | sed 's/|.*$//' | tr '\n' ' ')

	local package_names=($1)
	local unsorted_names=()
	local untimed_names=()
	local package_name=''

# 	DeDupeWords()
# 		{
#
# 		tr ' ' '\n' <<< "${1:-}" | $SORT_CMD | $UNIQ_CMD | tr '\n' ' ' | $SED_CMD 's|^[[:blank:]]*||;s|[[:blank:]]*$||'
#
# 		}

	for package_name in "${package_names[@]}"; do
		if buff=$(grep "^$package_name" "$action_times_pathfile"); then
			unsorted_names+=("$buff")
		else
			untimed_names+=($package_name)
		fi
	done


echo "unsorted_names=[${unsorted_names[@]}]"
echo "untimed_names=[${untimed_names[@]}]"


 	local sorted_names=$(sort -k2 -r <<<"${unsorted_names[@]}")
echo "sorted_names: [$sorted_names]"
	local names_only=$(sed 's/|.*$//' <<<"$sorted_names")

 	local untimed=$(sed 's/|.*$//' <<<"$untimed_names" | tr '\n' ' ')

	echo "${untimed%% } ${names_only%% }"

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

input_names=(c b e g)

action=${1:-start}
echo "action: '$action'"

action_times_pathfile="$action.milliseconds"

sorted_names=$(policy:longest "${input_names[*]}") || exit
echo "longest: '$sorted_names'"

exit

sorted_names=$(policy:shortest "${input_names[*]}") || exit
echo "shortest: '$sorted_names'"

sorted_names=$(policy:none "${input_names[*]}") || exit
echo "none: '$sorted_names'"
