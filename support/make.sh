#!/usr/bin/env bash

# standalone compiler for all sherpa archives

./check.sh || exit

echo -n 'building archives ... '

WORK_PATH=$PWD/..

# $MANAGEMENT_ACTIONS haven't been coded yet, so don't create objects for it
#MANAGEMENT_ACTIONS=(Check List Paste Status)

# these words may be specified by the user when requesting actions, so each word can only be used once across all 4 of the following arrays
PACKAGE_GROUPS=(All CanBackup CanClean CanRestartToUpdate Dependent HasDependents Installable Standalone Upgradable)     	# sorted: 'Sc' & 'ScNt'
PACKAGE_STATES=(BackedUp Cleaned Downloaded Enabled Installed Missing Reassigned Reinstalled Restarted Started Upgraded)  	# sorted: 'Is' & 'IsNt'
PACKAGE_STATES_TRANSIENT=(Starting Stopping Restarting)                                                         			# unsorted: 'Is' & 'IsNt'
PACKAGE_ACTIONS=(Download Rebuild Reassign Backup Stop Disable Uninstall Upgrade Reinstall Install Restore Clean Enable Start Restart)  # ordered

# only used by sherpa QPKG service-script results parser
PACKAGE_RESULTS=(Ok Unknown)

MANAGER_FILE=sherpa.manager.sh
MANAGER_ARCHIVE_FILE=${MANAGER_FILE%.*}.tar.gz
MANAGER_ARCHIVE_PATHFILE=$WORK_PATH/$MANAGER_ARCHIVE_FILE

OBJECTS_FILE=objects
OBJECTS_ARCHIVE_FILE=$OBJECTS_FILE.tar.gz
OBJECTS_ARCHIVE_PATHFILE=$WORK_PATH/$OBJECTS_ARCHIVE_FILE
OBJECTS_PATHFILE=$WORK_PATH/$OBJECTS_FILE

PACKAGES_FILE=packages
PACKAGES_ARCHIVE_FILE=$PACKAGES_FILE.tar.gz
PACKAGES_ARCHIVE_PATHFILE=$WORK_PATH/$PACKAGES_ARCHIVE_FILE

AddFlagObj()
    {

    # $1 = object name to create
    # $2 = set flag state on init (optional) default is 'false'
    # $3 = set 'log boolean changes' on init (optional) default is 'true'

    local public_function_name=${1:?no object name supplied}
    local safe_function_name="$(tr 'A-Z' 'a-z' <<< "${public_function_name//[.-]/_}")"
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
'$public_function_name'.Init' >> "$OBJECTS_PATHFILE"

    return 0

    }

AddListObj()
    {

    # $1 = object name to create

    local public_function_name=${1:?no object name supplied}
    local safe_function_name="$(tr 'A-Z' 'a-z' <<< "${public_function_name//[.-]/_}")"

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
'$public_function_name'.Init' >> "$OBJECTS_PATHFILE"

    return 0

    }

[[ -e $MANAGER_ARCHIVE_PATHFILE ]] && rm $MANAGER_ARCHIVE_PATHFILE
[[ -e $OBJECTS_ARCHIVE_PATHFILE ]] && rm $OBJECTS_ARCHIVE_PATHFILE
echo "OBJECTS_VER=$(date +%y%m%d)" > "$OBJECTS_PATHFILE"
echo "# do not edit this file - it should only be built with the 'make.sh' script" >> "$OBJECTS_PATHFILE"
[[ -e $PACKAGES_ARCHIVE_PATHFILE ]] && rm $PACKAGES_ARCHIVE_PATHFILE

# session flags
for element in Display.Clean ShowBackupLoc SuggestIssue Summary; do
    AddFlagObj Self.$element
done

AddFlagObj Self.LineSpace false false   # disable change logging for this object (low importance)

AddFlagObj Self.Debug.ToArchive
AddFlagObj Self.Debug.ToScreen
# AddFlagObj Self.Debug.ToFile true       # set initial value to 'true' so debug info is recorded early-on
AddFlagObj Self.Debug.ToFile

for element in Loaded States.Built SkProc; do
    AddFlagObj QPKGs.$element
done

AddFlagObj IPKs.Upgrade
AddFlagObj IPKs.Install
AddFlagObj PIPs.Install

# user option flags
for element in Deps.Check Vers.View; do
    AddFlagObj Opts.$element
done

for element in Abbreviations Actions ActionsAll Backups Basic Failed Groups Ok Options Packages Problems Repos Results Skipped Status Tips; do
    AddFlagObj Opts.Help.$element
done

for element in Last Tail; do
    AddFlagObj Opts.Log.$element.Paste
    AddFlagObj Opts.Log.$element.View
done

for group in "${PACKAGE_GROUPS[@]}"; do
    AddFlagObj QPKGs.List.Sc${group}

    case $group in
        All|CanBackup|CanRestartToUpdate|Dependent|HasDependents|Standalone)
            continue
    esac

    AddFlagObj QPKGs.List.ScNt${group}
done

for state in "${PACKAGE_STATES[@]}"; do
    AddFlagObj QPKGs.List.Is${state}

    case $state in
        Cleaned|Missing|Reassigned|Reinstalled|Restarted|Upgraded)
            continue
    esac

    AddFlagObj QPKGs.List.IsNt${state}
done

for state in "${PACKAGE_STATES_TRANSIENT[@]}"; do
    AddFlagObj QPKGs.List.Is${state}
done

for group in "${PACKAGE_GROUPS[@]}"; do
    for action in "${PACKAGE_ACTIONS[@]}"; do
        [[ $action = Enable || $action = Disable ]] && continue
        AddFlagObj QPKGs.Ac${action}.Sc${group}
    done

    case $group in
        All|CanBackup|CanRestartToUpdate|Dependent|HasDependents|Standalone)
            continue
    esac

    for action in "${PACKAGE_ACTIONS[@]}"; do
        [[ $action = Enable || $action = Disable ]] && continue
        AddFlagObj QPKGs.Ac${action}.ScNt${group}
    done
done

for state in "${PACKAGE_STATES[@]}"; do
    for action in "${PACKAGE_ACTIONS[@]}"; do
        [[ $action = Enable || $action = Disable ]] && continue
        AddFlagObj QPKGs.Ac${action}.Is${state}
    done

    [[ $state = Missing || $state = Reassigned ]] && continue

    for action in "${PACKAGE_ACTIONS[@]}"; do
        [[ $action = Enable || $action = Disable ]] && continue
        AddFlagObj QPKGs.Ac${action}.IsNt${state}
    done
done

# actions on QPKGs with temporary states are unsupported, so don't create flags for them

# session lists
AddListObj Args.Unknown

# $MANAGEMENT_ACTIONS haven't been coded yet, so don't create objects for it
# for action in "${MANAGEMENT_ACTIONS[@]}"; do
#     AddListObj Self.AcTo${action}       # action to be tried
#     AddListObj Self.AcOk${action}       # action was tried and succeeded
#     AddListObj Self.AcEr${action}       # action was tried but failed
#     AddListObj Self.AcSk${action}       # action was skipped
# done

for action in "${PACKAGE_ACTIONS[@]}"; do
    case $action in
        Disable|Enable)
            continue
    esac

    for prefix in To Ok Er Sk So Se; do
        AddListObj QPKGs.Ac${prefix}${action}
    done
done

for action in "${PACKAGE_ACTIONS[@]}"; do
    case $action in
        Backup|Clean|Disable|Enable|Reassign|Rebuild|Restart|Restore)
            continue
    esac

    for prefix in To Ok Er; do
        AddListObj IPKs.Ac${prefix}${action}
    done
done

for group in "${PACKAGE_GROUPS[@]}"; do
    AddListObj QPKGs.Sc${group}

    case $group in
        All|Dependent|HasDependents|Standalone)
            continue
    esac

    AddListObj QPKGs.ScNt${group}
done

for state in "${PACKAGE_STATES[@]}" "${PACKAGE_RESULTS[@]}"; do
    AddListObj QPKGs.Is${state}
    AddListObj QPKGs.IsNt${state}
done

for state in "${PACKAGE_STATES_TRANSIENT[@]}"; do
    AddListObj QPKGs.Is${state}
    AddListObj QPKGs.IsNt${state}
done

tar --create --gzip --numeric-owner --file="$MANAGER_ARCHIVE_PATHFILE" --directory="$WORK_PATH" "$MANAGER_FILE"
tar --create --gzip --numeric-owner --file="$OBJECTS_ARCHIVE_PATHFILE" --directory="$WORK_PATH" "$OBJECTS_FILE"
tar --create --gzip --numeric-owner --file="$PACKAGES_ARCHIVE_PATHFILE" --directory="$WORK_PATH" "$PACKAGES_FILE"

echo 'done!'

echo 'these files have changed since the last commit:'
git diff --name-only
