#!/usr/bin/env bash

if [[ ! -e vars.source ]]; then
	echo "'vars.source' not found"
	exit 1
fi

. ./vars.source

echo -n "building 'objects' ... "

target_pathfile="$source_path"/objects

# these are used internally by sherpa -----------------------------------------------------
# sorted
QPKG_IS_STATES=(backedup downloaded enabled installed missing signed started)
QPKG_ISNT_STATES=(backedup downloaded enabled installed signed started)
QPKG_STATES_TRANSIENT=(starting stopping restarting)
QPKG_SERVICE_RESULTS=(ok failed unknown)

# sorted
IPK_STATES=(downloaded installed reinstalled upgraded)

# ordered
PIP_ACTIONS=(download uninstall upgrade reinstall install)
IPK_ACTIONS=(download uninstall upgrade reinstall install)
QPKG_ACTIONS=(download rebuild reassign backup stop disable uninstall upgrade reinstall install restore clean enable start restart sign)

# these words may be specified by the user -----------------------------------------------------
# sorted
USER_QPKG_SC_GROUPS=(all canbackup canclean canrestarttoupdate dependent hasdependents installable standalone upgradable)
USER_QPKG_SCNT_GROUPS=(canclean installable upgradable)
USER_QPKG_IS_STATES=(backedup installed missing started)
USER_QPKG_ISNT_STATES=(backedup installed started)
USER_QPKG_ACTIONS=(backup clean install list reassign rebuild reinstall restart restore start stop uninstall upgrade)

# disabled for-now, but would be helpful to have these as user-specified states
# USER_QPKG_IS_STATES+=(${QPKG_SERVICE_RESULTS[@]})
# USER_QPKG_ISNT_STATES+=(${QPKG_SERVICE_RESULTS[@]})

AddFlagObj()
	{

	# $1 = object name to create
	# $2 = set flag state on init (optional) default is 'false'
	# $3 = set 'log boolean changes' on init (optional) default is 'true'

	local public_function_name=${1:?no object name supplied}
	local safe_function_name="$(tr '[:upper:]' '[:lower:]' <<< "${public_function_name//[.-]/_}")"
	local state_default=${2:-false}
	local state_logmods=${3:-true}

	_placeholder_flag_=_ob_${safe_function_name}_fl_
	_placeholder_log_changes_flag_=_ob_${safe_function_name}_chfl_

echo $public_function_name':Init()
	{ '$_placeholder_flag_'='$state_default'
	'$_placeholder_log_changes_flag_'='$state_logmods' ;}

'$public_function_name':IsNt()
	{ [[ $'$_placeholder_flag_' != '\'true\'' ]] ;}

'$public_function_name':IsSet()
	{ [[ $'$_placeholder_flag_' = '\'true\'' ]] ;}

'$public_function_name':Set()
	{ [[ $'$_placeholder_flag_' = '\'true\'' ]] && return
	'$_placeholder_flag_'=true
	[[ $'$_placeholder_log_changes_flag_' = '\'true\'' ]] && DebugVar '$_placeholder_flag_' ;}

'$public_function_name':UnSet()
	{ [[ $'$_placeholder_flag_' != '\'true\'' ]] && return
	'$_placeholder_flag_'=false
	[[ $'$_placeholder_log_changes_flag_' = '\'true\'' ]] && DebugVar '$_placeholder_flag_' ;}

'$public_function_name':NoLogMods()
	{ '$_placeholder_log_changes_flag_'=false ;}

'$public_function_name':Init' >> "$target_pathfile"

	return 0

	}

AddListObj()
	{

	# $1 = object name to create

	local public_function_name=${1:?no object name supplied}
	local safe_function_name="$(tr '[:upper:]' '[:lower:]' <<< "${public_function_name//[.-]/_}")"

	_placeholder_size_=_ob_${safe_function_name}_sz_
	_placeholder_array_=_ob_${safe_function_name}_ar_
	_placeholder_array_index_=_ob_${safe_function_name}_arin_

echo $public_function_name':Add()
	{ local ar=(${1:-}) it='\'\''; [[ ${#ar[@]} -eq 0 ]] && return
	for it in "${ar[@]:-}"; do
		! '$public_function_name':Exist "$it" && '$_placeholder_array_'+=("$it")
	done ;}

'$public_function_name':Array()
	{ echo -n "${'$_placeholder_array_'[@]:-}" ;}

'$public_function_name':Count()
	{ echo "${#'$_placeholder_array_'[@]}" ;}

'$public_function_name':Exist()
	{ local patt="\b${1:-}\b"; [[ "${'$_placeholder_array_'[*]:-}" =~ $patt ]] ;}

'$public_function_name':Init()
	{ '$_placeholder_size_'=0 '$_placeholder_array_'=() '$_placeholder_array_index_'=1 ;}

'$public_function_name':IsAny()
	{ [[ ${#'$_placeholder_array_'[@]} -gt 0 ]] ;}

'$public_function_name':IsNone()
	{ [[ ${#'$_placeholder_array_'[@]} -eq 0 ]] ;}

'$public_function_name':List()
	{ echo -n "${'$_placeholder_array_'[*]:-}" ;}

'$public_function_name':ListCSV()
	{ echo -n "${'$_placeholder_array_'[*]:-}" | tr '\' \'' '\',\'' ;}

'$public_function_name':Remove()
	{ local agar=(${1:-}) tmar=() ag='\'\'' it='\'\'' m=false
	for it in "${'$_placeholder_array_'[@]:-}"; do m=false
		for ag in "${agar[@]+"${agar[@]}"}"; do if [[ $ag = "$it" ]]; then m=true; break; fi
		done
		[[ $m = false ]] && tmar+=("$it")
	done
	'$_placeholder_array_'=("${tmar[@]+"${tmar[@]}"}")
	[[ -z ${'$_placeholder_array_'[*]+"${'$_placeholder_array_'[@]}"} ]] && '$_placeholder_array_'=() ;}

'$public_function_name':Size()
	{ if [[ -n ${1:-} && ${1:-} = "=" ]]; then '$_placeholder_size_'=$2; else echo -n "$'$_placeholder_size_'"
	fi ;}

'$public_function_name':Init' >> "$target_pathfile"

	return 0

	}

[[ -e $target_pathfile ]] && rm -f "$target_pathfile"
echo "OBJECTS_VER='$today'" > "$target_pathfile"
echo "#*$dontedit_msg" >> "$target_pathfile"

# user option & package action flag objects -----------------------------------------------------------------------------------------------------------------------------

for group in "${USER_QPKG_SC_GROUPS[@]}"; do
	for action in "${USER_QPKG_ACTIONS[@]}"; do
		AddFlagObj QPKGs.AC"$action".SC"$group"
	done
done

for group in "${USER_QPKG_SCNT_GROUPS[@]}"; do
	for action in "${USER_QPKG_ACTIONS[@]}"; do
		AddFlagObj QPKGs.AC"$action".SCNT"$group"
	done
done

for state in "${USER_QPKG_IS_STATES[@]}"; do
	for action in "${USER_QPKG_ACTIONS[@]}"; do
		AddFlagObj QPKGs.AC"$action".IS"$state"
	done
done

for state in "${USER_QPKG_ISNT_STATES[@]}"; do
	for action in "${USER_QPKG_ACTIONS[@]}"; do
		AddFlagObj QPKGs.AC"$action".ISNT"$state"
	done
done

# session list objects ---------------------------------------------------------------------------------------------------------------------------------

AddListObj ARGs-unknown

for group in "${USER_QPKG_SC_GROUPS[@]}"; do
	AddListObj QPKGs-SC"$group"
done

for group in "${USER_QPKG_SCNT_GROUPS[@]}"; do
	AddListObj QPKGs-SCNT"$group"
done

for state in "${QPKG_IS_STATES[@]}" "${QPKG_STATES_TRANSIENT[@]}" "${QPKG_SERVICE_RESULTS[@]}"; do
	AddListObj QPKGs-IS"$state"
done

for state in "${QPKG_ISNT_STATES[@]}" "${QPKG_STATES_TRANSIENT[@]}" "${QPKG_SERVICE_RESULTS[@]}"; do
	AddListObj QPKGs-ISNT"$state"
done

for action in "${QPKG_ACTIONS[@]}"; do
	case $action in
		disable|enable|list)
			continue    # action result lists are not required for these
	esac

	for prefix in to ok er sk so se; do
		AddListObj "QPKGs-AC${action}-${prefix}"
	done
done

for action in "${IPK_ACTIONS[@]}"; do
	case $action in
		disable|enable|list)
			continue    # action result lists are not required for these
	esac

	for prefix in to ok er; do
		AddListObj "IPKs-AC${action}-${prefix}"
	done
done

buffer=$(<"$target_pathfile")
buffer=$(sed -e '/^#[[:space:]].*/d;s/[[:space:]]#[[:space:]].*//' <<< "$buffer")		# remove comment lines and line comments
buffer=$(sed -e 's/^[[:space:]]*//' <<< "$buffer")										# remove leading whitespace
buffer=$(sed 's/[[:space:]]*$//' <<< "$buffer")											# remove trailing whitespace
buffer=$(sed "/^$/d" <<< "$buffer")														# remove empty lines

echo "$buffer" > "$target_pathfile"

if [[ ! -e $target_pathfile ]]; then
	ColourTextBrightRed "'$target_pathfile' was not written to disk\n"
	exit 1
fi

chmod 444 "$target_pathfile"

ColourTextBrightGreen 'done\n'
exit 0
