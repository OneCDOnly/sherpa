#!/usr/bin/env bash

echo -n "building 'objects' ... "

if [[ -e vars.source ]]; then
	. ./vars.source
else
	ColourTextBrightRed "'vars.source' not found\n"
	exit 1
fi

target_pathfile="$source_path"/objects

# $MANAGEMENT_ACTIONS haven't been coded yet, so don't create objects for it
#MANAGEMENT_ACTIONS=(Check List Paste Status)

# these words may be specified by the user when requesting actions, so each word can only be used once across all 4 of the following arrays
PACKAGE_GROUPS=(All CanBackup CanClean CanRestartToUpdate Dependent HasDependents Installable Standalone Upgradable)        # sorted: 'Sc' & 'ScNt'
PACKAGE_STATES=(BackedUp Cleaned Downloaded Enabled Installed Missing Reassigned Reinstalled Restarted Signed Started Upgraded)    # sorted: 'Is' & 'IsNt'
PACKAGE_STATES_TRANSIENT=(Starting Stopping Restarting)                                                                     # unsorted: 'Is' & 'IsNt'
PACKAGE_ACTIONS=(Download Rebuild Reassign Backup Stop Disable Uninstall Upgrade Reinstall Install Restore Clean Enable Start Restart Sign)  # ordered

# only used by sherpa QPKG service-script results parser
QPKG_RESULTS=(Ok Unknown)

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

echo $public_function_name'.Init()
	{ '$_placeholder_flag_'='$state_default'
	'$_placeholder_log_changes_flag_'='$state_logmods' ;}

'$public_function_name'.IsNt()
	{ [[ $'$_placeholder_flag_' != '\'true\'' ]] ;}

'$public_function_name'.IsSet()
	{ [[ $'$_placeholder_flag_' = '\'true\'' ]] ;}

'$public_function_name'.Set()
	{ [[ $'$_placeholder_flag_' = '\'true\'' ]] && return
	'$_placeholder_flag_'=true
	[[ $'$_placeholder_log_changes_flag_' = '\'true\'' ]] && DebugVar '$_placeholder_flag_' ;}

'$public_function_name'.UnSet()
	{ [[ $'$_placeholder_flag_' != '\'true\'' ]] && return
	'$_placeholder_flag_'=false
	[[ $'$_placeholder_log_changes_flag_' = '\'true\'' ]] && DebugVar '$_placeholder_flag_' ;}

'$public_function_name'.NoLogMods()
	{ '$_placeholder_log_changes_flag_'=false ;}

'$public_function_name'.Init' >> "$target_pathfile"

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

echo $public_function_name'.Add()
	{ local ar=(${1:-}) it='\'\''; [[ ${#ar[@]} -eq 0 ]] && return
	for it in "${ar[@]:-}"; do
		! '$public_function_name'.Exist "$it" && '$_placeholder_array_'+=("$it")
	done ;}

'$public_function_name'.Array()
	{ echo -n "${'$_placeholder_array_'[@]:-}" ;}

'$public_function_name'.Count()
	{ echo "${#'$_placeholder_array_'[@]}" ;}

'$public_function_name'.Exist()
	{ local patt="\b${1:-}\b"; [[ " ${'$_placeholder_array_'[*]:-} " =~ $patt ]] ;}

'$public_function_name'.Init()
	{ '$_placeholder_size_'=0 '$_placeholder_array_'=() '$_placeholder_array_index_'=1 ;}

'$public_function_name'.IsAny()
	{ [[ ${#'$_placeholder_array_'[@]} -gt 0 ]] ;}

'$public_function_name'.IsNone()
	{ [[ ${#'$_placeholder_array_'[@]} -eq 0 ]] ;}

'$public_function_name'.List()
	{ echo -n "${'$_placeholder_array_'[*]:-}" ;}

'$public_function_name'.ListCSV()
	{ echo -n "${'$_placeholder_array_'[*]:-}" | tr '\' \'' '\',\'' ;}

'$public_function_name'.Remove()
	{ local agar=(${1:-}) tmar=() ag='\'\'' it='\'\'' m=false
	for it in "${'$_placeholder_array_'[@]:-}"; do m=false
		for ag in "${agar[@]+"${agar[@]}"}"; do if [[ $ag = "$it" ]]; then m=true; break; fi
		done
		[[ $m = false ]] && tmar+=("$it")
	done
	'$_placeholder_array_'=("${tmar[@]+"${tmar[@]}"}")
	[[ -z ${'$_placeholder_array_'[*]+"${'$_placeholder_array_'[@]}"} ]] && '$_placeholder_array_'=() ;}

'$public_function_name'.Size()
	{ if [[ -n ${1:-} && ${1:-} = "=" ]]; then '$_placeholder_size_'=$2; else echo -n "$'$_placeholder_size_'"
	fi ;}

'$public_function_name'.Init' >> "$target_pathfile"

	return 0

	}

[[ -e $target_pathfile ]] && rm -f "$target_pathfile"
echo "OBJECTS_VER='$today'" > "$target_pathfile"
echo "#*$dontedit_msg" >> "$target_pathfile"

# user option flag objects -----------------------------------------------------------------------------------------------------------------------------

for group in "${PACKAGE_GROUPS[@]}"; do
	AddFlagObj QPKGs.List.Sc"${group}"

	case $group in
		All|CanBackup|CanRestartToUpdate|Dependent|HasDependents|Standalone)
			continue    # ScNt flags are not required for these
	esac

	AddFlagObj QPKGs.List.ScNt"${group}"
done

for state in "${PACKAGE_STATES[@]}"; do
	AddFlagObj QPKGs.List.Is"${state}"

	case $state in
		Cleaned|Missing|Reassigned|Reinstalled|Restarted|Upgraded)
			continue    # IsNt flags are not required for these
	esac

	AddFlagObj QPKGs.List.IsNt"${state}"
done

for state in "${PACKAGE_STATES_TRANSIENT[@]}"; do
	AddFlagObj QPKGs.List.Is"${state}"
done

# package action flag objects --------------------------------------------------------------------------------------------------------------------------

for group in "${PACKAGE_GROUPS[@]}"; do
	for action in "${PACKAGE_ACTIONS[@]}"; do
		case $action in
			Disable|Enable)
				continue    # Ac flags are not required for these
		esac

		AddFlagObj QPKGs.Ac"${action}".Sc"${group}"
	done

	case $group in
		All|CanBackup|CanRestartToUpdate|Dependent|HasDependents|Standalone)
			continue    # ScNt flags are not required for these
	esac

	for action in "${PACKAGE_ACTIONS[@]}"; do
		case $action in
			Disable|Enable)
				continue    # Ac flags are not required for these
		esac

		AddFlagObj QPKGs.Ac"${action}".ScNt"${group}"
	done
done

for state in "${PACKAGE_STATES[@]}"; do
	for action in "${PACKAGE_ACTIONS[@]}"; do
		case $action in
			Disable|Enable)
				continue    # Ac flags are not required for these
		esac
		AddFlagObj QPKGs.Ac"${action}".Is"${state}"
	done

	case $state in
		Missing|Reassigned)
			continue    # IsNt flags are not required for these
	esac

	for action in "${PACKAGE_ACTIONS[@]}"; do
		case $action in
			Disable|Enable)
				continue    # Ac flags are not required for these
		esac

		AddFlagObj QPKGs.Ac"${action}".IsNt"${state}"
	done
done

# performing actions on QPKGs with temporary states is unsupported, so don't create flags for them

# session list objects ---------------------------------------------------------------------------------------------------------------------------------

AddListObj Args.Unknown

# $MANAGEMENT_ACTIONS haven't been coded yet, so don't create objects for it
# for action in "${MANAGEMENT_ACTIONS[@]}"; do
#     AddListObj Self.AcTo${action}       # action to be tried
#     AddListObj Self.AcOk${action}       # action was tried and succeeded
#     AddListObj Self.AcEr${action}       # action was tried but failed
#     AddListObj Self.AcSk${action}       # action was skipped
# done

for group in "${PACKAGE_GROUPS[@]}"; do
	AddListObj QPKGs.Sc"${group}"

	case $group in
		All|Dependent|HasDependents|Standalone)
			continue    # ScNt lists are not required for these
	esac

	AddListObj QPKGs.ScNt"${group}"
done

for state in "${PACKAGE_STATES[@]}" "${QPKG_RESULTS[@]}"; do
	AddListObj QPKGs.Is"${state}"
	AddListObj QPKGs.IsNt"${state}"
done

for state in "${PACKAGE_STATES_TRANSIENT[@]}"; do
AddListObj QPKGs.Is"${state}"
AddListObj QPKGs.IsNt"${state}"
done

for action in "${PACKAGE_ACTIONS[@]}"; do
	case $action in
		Disable|Enable)
			continue    # Ac lists are not required for these
	esac

	for prefix in To Ok Er Sk So Se; do
		AddListObj QPKGs.Ac"${prefix}${action}"
	done
done

for action in "${PACKAGE_ACTIONS[@]}"; do
	case $action in
		Backup|Clean|Disable|Enable|Reassign|Rebuild|Restart|Restore|Sign)
			continue    # Ac lists are not required for these
	esac

	for prefix in To Ok Er; do
		AddListObj IPKs.Ac"${prefix}${action}"
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
