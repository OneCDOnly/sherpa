#!/usr/bin/env bash

. $HOME/scripts/nas/sherpa/support/vars.source || exit				# Use full address as this script is called from outside its directory.

echo -n "building 'objects' file ... "

objects_epoch=$(date +%s)

target=$support_path/$objects_file

# These are used internally by sherpa. Maintain separate lists for sherpa internal-use, and what user has requested.
# ordered

# sorted

r_qpkg_basic_states=(complete enabled installed)
r_qpkg_extended_states=(active backedup downloaded installable missing signed upgradable)
r_qpkg_transient_states=(restarting slow starting stopping unknown)
	r_qpkg_is_states=(${r_qpkg_basic_states[*]} ${r_qpkg_extended_states[*]} ${r_qpkg_transient_states[*]})
	r_qpkg_isnt_states=(${r_qpkg_basic_states[*]} ${r_qpkg_extended_states[*]} ${r_qpkg_transient_states[*]})
r_qpkg_is_groups=(all canbackup canclean canrestarttoupdate dependent hasdependents independent optional)
r_qpkg_isnt_groups=(canclean)
r_qpkg_service_results=(failed ok)

# ordered

r_qpkg_actions=(status list rebuild reassign download backup deactivate disable uninstall upgrade reinstall install enableau disableau sign restore clean enable activate reactivate)
r_ipk_actions=(downgrade download uninstall upgrade install)
r_pip_actions=(uninstall upgrade install)

# These actions may be specified by the user.
# sorted

r_user_qpkg_actions=(activate backup clean deactivate disable disableau enable enableau install list reactivate reassign rebuild reinstall restore sign status uninstall upgrade)

AddFlagObj()
	{

	# $1 = object name to create.
	# $2 = set flag state on init (optional) default is 'false'.
	# $3 = set 'log boolean changes' on init (optional) default is 'true'.

	local public_function_name=${1:?no object name supplied}
	local safe_function_name=$(tr '[:upper:]' '[:lower:]' <<< "${public_function_name//[.-]/_}")
	local state_default=${2:-false}
	local state_logmods=${3:-true}

	_placeholder_main_flag_=o_f${safe_function_name}
	_placeholder_log_changes_flag_=o_c${safe_function_name}

echo $public_function_name':Init()
	{

	'$_placeholder_main_flag_'='$state_default'
	'$_placeholder_log_changes_flag_'='$state_logmods'

	}

'$public_function_name'.IsSet()
	{

	$'$_placeholder_main_flag_'

	}

'$public_function_name':Set()
	{

	$'$_placeholder_main_flag_' && return
	'$_placeholder_main_flag_'=true
	$'$_placeholder_log_changes_flag_' && DebugVar '$_placeholder_main_flag_'

	}

'$public_function_name':Init' >> "$target"

	return 0

	}

AddListObj()
	{

	# $1 = object name to create.

	local public_function_name=${1:?no object name supplied}
	local safe_function_name=$(tr '[:upper:]' '[:lower:]' <<< "${public_function_name//[.-]/_}")

	_placeholder_size_=o_s${safe_function_name}
	_placeholder_array_=o_a${safe_function_name}

echo $public_function_name':Add()
	{

	local ar=(${1:-}) it='\'\''

	[[ ${#ar[@]} -eq 0 ]] && return

	for it in "${ar[@]:-}"; do
		! '$public_function_name'.Exist "$it" && '$_placeholder_array_'+=("$it")
	done

	}

'$public_function_name':Array()
	{

	echo -n "${'$_placeholder_array_'[@]:-}"

	}

'$public_function_name':Count()
	{

	echo "${#'$_placeholder_array_'[@]}"

	}

'$public_function_name'.Exist()
	{

	local patt="\b${1:-}\b"

	[[ "${'$_placeholder_array_'[*]:-}" =~ $patt ]]

	}

'$public_function_name':Init()
	{

	'$_placeholder_size_'=0 '$_placeholder_array_'=()

	}

'$public_function_name'.IsAny()
	{

	[[ ${#'$_placeholder_array_'[@]} -gt 0 ]]

	}

'$public_function_name'.IsNone()
	{

	[[ ${#'$_placeholder_array_'[@]} -eq 0 ]]

	}

'$public_function_name':List()
	{

	echo -n "${'$_placeholder_array_'[*]:-}"

	}

'$public_function_name':ListCSV()
	{

	echo -n "${'$_placeholder_array_'[*]:-}" | tr '\' \'' '\',\''

	}

'$public_function_name':Remove()
	{

	local agar=(${1:-}) tmar=() ag='\'\'' it='\'\'' m=false

	for it in "${'$_placeholder_array_'[@]:-}"; do
		m=false

		for ag in "${agar[@]+"${agar[@]}"}"; do
			if [[ $ag = "$it" ]]; then
				m=true
				break
			fi
		done

		$m || tmar+=("$it")
	done

	'$_placeholder_array_'=("${tmar[@]+"${tmar[@]}"}")
	[[ -z ${'$_placeholder_array_'[*]+"${'$_placeholder_array_'[@]}"} ]] && '$_placeholder_array_'=()

	}

'$public_function_name':Size()
	{

	if [[ -n ${1:-} && ${1:-} = "=" ]];then
		'$_placeholder_size_'=$2
	else
		echo -n "$'$_placeholder_size_'"
	fi

	}

'$public_function_name':Init' >> "$target"

	return 0

	}

[[ -e $target ]] && rm -f "$target"
echo "r_objects_epoch='<?objects_epoch?>'" > "$target"
echo "#* <?dont_edit?>" >> "$target"

# package action flag objects.

for action in "${r_user_qpkg_actions[@]}"; do
	for state in "${r_qpkg_is_states[@]}"; do
		case $state in
			downloaded)
				continue
				;;
			*)
				AddFlagObj QPKGs.AC"$action"IS"$state"
		esac
	done

	for state in "${r_qpkg_isnt_states[@]}"; do
		case $state in
			downloaded)
				continue
				;;
			*)
				AddFlagObj QPKGs.AC"$action"ISNT"$state"
		esac
	done

	for group in "${r_qpkg_is_groups[@]}"; do
		AddFlagObj QPKGs.AC"$action"GR"$group"
	done

	for group in "${r_qpkg_isnt_groups[@]}"; do
		AddFlagObj QPKGs.AC"$action"GRNT"$group"
	done
done

# session list objects.

for action in "${r_qpkg_actions[@]}"; do
	for prefix in to ok er sk so se sa dn; do		# 'to-do', 'done ok', 'done error', 'skipped', 'skipped-but-ok', 'skipped-with-error', 'skipped-with-abort', 'done' (all processed QPKGs are placed in the 'done' list, as-well as the regular exit status lists).
		AddListObj "QPKGs-AC${action}-${prefix}"
	done
done

for state in "${r_qpkg_extended_states[@]}" "${r_qpkg_transient_states[@]}" "${r_qpkg_service_results[@]}"; do
	AddListObj QPKGs-IS"$state"
	AddListObj QPKGs-ISNT"$state"
done

for group in "${r_qpkg_is_groups[@]}"; do
	AddListObj QPKGs-GR"$group"
done

for group in "${r_qpkg_isnt_groups[@]}"; do
	AddListObj QPKGs-GRNT"$group"
done

for action in "${r_ipk_actions[@]}"; do
	[[ $action != list ]] || continue

	for prefix in to ok er sk; do
		AddListObj "IPKs-AC${action}-${prefix}"
	done
done

for action in "${r_pip_actions[@]}"; do
	[[ $action != list ]] || continue

	for prefix in to ok er; do
		AddListObj "PIPs-AC${action}-${prefix}"
	done
done

if [[ ! -e $target ]]; then
	TextBrightRed "'$target' was not written to disk"; echo
	exit 1
else
	ShowDone
fi

SwapTags "$target" "$target"

if grep -q '<?\|?>' "$target"; then
	TextBrightRed "'$target' contains unswapped tags, can't continue"; echo
	exit 1
fi

Squeeze "$target" "$target"
[[ -f $target ]] && chmod 444 "$target"

exit 0
