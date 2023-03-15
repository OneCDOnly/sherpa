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

	# package names will be listed with the longest action time first. Packages without times will be listed first.

	[[ -s $action_times_pathfile ]] || return
	[[ ${#1} -gt 0 ]] || return

	local package_name=''
	local supplied_package_names=($1)
	local matched_names=()
	local untimed_names=()
	local patt=''

	local sorted=$(sort -k2 -r <<<"$(for package_name in $1; do
		grep "^$package_name" "$action_times_pathfile"
	done)" | sed 's/|.*$//' | tr '\n' ' ')

echo "supplied_package_names[${supplied_package_names[*]}]"
echo "sorted[$sorted]"

	for sorted_index in "${!sorted[@]}"; do
echo "checking sorted name [${sorted[$sorted_index]}]"

		patt="\b${sorted_package_name}\b"

		for supplied_package_name in ${supplied_package_names[*]}; do
echo "checking supplied name [$supplied_package_name]"
			supp_patt="\b${supplied_package_name}\b"

			if [[ "$sorted" =~ $supp_patt ]]; then
				echo -e "adding [$sorted_package_name] to matched\n"
				matched_names+=($sorted_package_name)
# 			else
# 				echo "adding [$supplied_package_name] to untimed"
# 				untimed_names+=($sorted_package_name)
				break
			fi
		done

# 		[[ $sorted_package_name != $supplied_package_name ]] && continue
#
# 			if [[ "${supplied_package_names[*]}" =~ $patt ]]; then
# 				echo "adding [$supplied_package_name] to matched"
# 				matched_names+=($supplied_package_name)
# 			else
# 				echo "adding [$supplied_package_name] to untimed"
# 				untimed_names+=($supplied_package_name)
# 			fi
# 			break
# 		done
	done

echo "matched[${matched_names[*]}]"
echo "untimed[${untimed_names[*]}]"

exit
	echo "${untimed_names[*]%% } ${matched_names[*]%% }"

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

input_names=(c b a e g z d 3)

action=${1:-start}
echo "action: '$action'"

action_times_pathfile="$action.milliseconds"

policy:longest "${input_names[*]}" || exit
exit
sorted_names=$(policy:longest "${input_names[*]}") || exit
echo "longest: '$sorted_names'"

# while read -r package_name; do
# 	echo "newlines name: [$package_name]"
# done <<< "$(tr ' ' '\n' <<< "$sorted_names")"

for package_name in $sorted_names; do
	echo "spaces name: [$package_name]"
done


# sorted_names=$(policy:shortest "${input_names[*]}") || exit
# echo "shortest: '$sorted_names'"
#
# sorted_names=$(policy:none "${input_names[*]}") || exit
# echo "none: '$sorted_names'"
