#!/usr/bin/env bash

# standalone compiler for all sherpa archives

PROJECT_NAME=sherpa
WORK_PATH=$PWD

MANAGEMENT_ACTIONS=(Check List Paste Reset Status View)

PACKAGE_SCOPES=(All Dependent HasDependents Installable Names Standalone SupportBackup SupportUpdateOnRestart Upgradable)
PACKAGE_STATES=(BackedUp Cleaned Disabled Downloaded Enabled Installed Missing Starting Started Stopping Stopped Restarting)
PACKAGE_ACTIONS=(Backup Clean Disable Download Enable Install Rebuild Reinstall Restart Restore Start Stop Uninstall Upgrade)

MANAGER_FILE=$PROJECT_NAME.manager.sh
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

echo $public_function_name'.Clear()
{ [[ $'$_placeholder_flag_' != '\'true\'' ]] && return
'$_placeholder_flag_'=false
[[ $'$_placeholder_log_changes_flag_' = '\'true\'' ]] && DebugVar '$_placeholder_flag_' ;}
'$public_function_name'.NoLogMods()
{ '$_placeholder_log_changes_flag_'=false ;}
'$public_function_name'.Init()
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
{ local ar=(${1}) it='\'\''
[[ ${#ar[@]} -eq 0 ]] && return
for it in "${ar[@]:-}"; do
[[ " ${'$_placeholder_array_'[*]+"${'$_placeholder_array_'[@]}"} " != *"$it"* ]] && '$_placeholder_array_'+=("$it")
done ;}
'$public_function_name'.Array()
{ echo -n "${'$_placeholder_array_'[@]+"${'$_placeholder_array_'[@]}"}" ;}
'$public_function_name'.Count()
{ echo "${#'$_placeholder_array_'[@]}" ;}
'$public_function_name'.Exist()
{ [[ ${'$_placeholder_array_'[*]:-} == *"$1"* ]] ;}
'$public_function_name'.Init()
{ '$_placeholder_size_'=0
'$_placeholder_array_'=()
'$_placeholder_array_index_'=1 ;}
'$public_function_name'.IsAny()
{ [[ ${#'$_placeholder_array_'[@]} -gt 0 ]] ;}
'$public_function_name'.IsNone()
{ [[ ${#'$_placeholder_array_'[@]} -eq 0 ]] ;}
'$public_function_name'.List()
{ echo -n "${'$_placeholder_array_'[*]+"${'$_placeholder_array_'[@]}"}" ;}
'$public_function_name'.ListCSV()
{ echo -n "${'$_placeholder_array_'[*]+"${'$_placeholder_array_'[@]}"}" | tr '\' \'' '\',\'' ;}
'$public_function_name'.Remove()
{ local agar=(${1}) tmar=() ag='\'\'' it='\'\'' m=false
for it in "${'$_placeholder_array_'[@]+"${'$_placeholder_array_'[@]}"}"; do
m=false
for ag in "${agar[@]+"${agar[@]}"}"; do
if [[ $ag = "$it" ]]; then
m=true; break
fi
done
[[ $m = false ]] && tmar+=("$it")
done
'$_placeholder_array_'=("${tmar[@]+"${tmar[@]}"}")
[[ -z ${'$_placeholder_array_'[*]+"${'$_placeholder_array_'[@]}"} ]] && '$_placeholder_array_'=() ;}
'$public_function_name'.Size()
{ if [[ -n ${1:-} && ${1:-} = "=" ]]; then
'$_placeholder_size_'=$2
else
echo -n "$'$_placeholder_size_'"
fi ;}
'$public_function_name'.Init' >> "$OBJECTS_PATHFILE"

    return 0

    }

[[ -e $MANAGER_ARCHIVE_PATHFILE ]] && rm $MANAGER_ARCHIVE_PATHFILE
[[ -e $OBJECTS_ARCHIVE_PATHFILE ]] && rm $OBJECTS_ARCHIVE_PATHFILE
echo "# do not edit this file - it should only be built with the 'construct.sh' script" > "$OBJECTS_PATHFILE"
[[ -e $PACKAGES_ARCHIVE_PATHFILE ]] && rm $PACKAGES_ARCHIVE_PATHFILE

# session flags
for element in Display.Clean ShowBackupLoc SuggestIssue Summary; do
    AddFlagObj Session.$element
done

AddFlagObj Session.LineSpace false false    # disable change logging for this object (low importance)

AddFlagObj Session.Debug.ToArchive
AddFlagObj Session.Debug.ToScreen
AddFlagObj Session.Debug.ToFile true        # set initial value to 'true' so debug info is recorded early-on

for element in Loaded States.Built SkProc; do
    AddFlagObj QPKGs.$element
done

AddFlagObj IPKGs.Upgrade
AddFlagObj IPKGs.Install
AddFlagObj PIPs.Install

# user option flags
for element in Deps.Check Versions.View; do
    AddFlagObj Opts.$element
done

for element in Abbreviations Actions ActionsAll Backups Basic Options Packages Problems Status Tips; do
    AddFlagObj Opts.Help.$element
done

for element in Last Tail; do
    AddFlagObj Opts.Log.$element.Paste
    AddFlagObj Opts.Log.$element.View
done

for scope in "${PACKAGE_SCOPES[@]}"; do
    AddFlagObj Opts.Apps.List.Sc${scope}
    AddFlagObj Opts.Apps.List.ScNt${scope}
done

for state in "${PACKAGE_STATES[@]}"; do
    AddFlagObj Opts.Apps.List.Is${state}
    AddFlagObj Opts.Apps.List.IsNt${state}
done

for scope in "${PACKAGE_SCOPES[@]}"; do
    for action in "${PACKAGE_ACTIONS[@]}"; do
        AddFlagObj Opts.Apps.Ac${action}.Sc${scope}
        AddFlagObj Opts.Apps.Ac${action}.ScNt${scope}
    done
done

for state in "${PACKAGE_STATES[@]}"; do
    for action in "${PACKAGE_ACTIONS[@]}"; do
        AddFlagObj Opts.Apps.Ac${action}.Is${state}
        AddFlagObj Opts.Apps.Ac${action}.IsNt${state}
    done
done

# lists
AddListObj Args.Unknown

for action in "${MANAGEMENT_ACTIONS[@]}"; do
    AddListObj Self.AcTo${action}       # action to be tried
    AddListObj Self.AcOk${action}       # action was tried and succeeded
    AddListObj Self.AcEr${action}       # action was tried but failed
    AddListObj Self.AcSk${action}       # action was skipped
done

for action in "${PACKAGE_ACTIONS[@]}"; do
    AddListObj QPKGs.AcTo${action}       # action to be tried
    AddListObj QPKGs.AcOk${action}       # action was tried and succeeded
    AddListObj QPKGs.AcEr${action}       # action was tried but failed
    AddListObj QPKGs.AcSk${action}       # action was skipped
done

for action in Download Install Uninstall Upgrade; do    # only a subset of addon package actions are supported for-now
    AddListObj IPKGs.AcTo${action}
    AddListObj PIPs.AcTo${action}
done

for scope in "${PACKAGE_SCOPES[@]}"; do
    AddListObj QPKGs.Sc${scope}
    AddListObj QPKGs.ScNt${scope}
done

for state in "${PACKAGE_STATES[@]}"; do
    AddListObj QPKGs.Is${state}
    AddListObj QPKGs.IsNt${state}
done

tar --create --gzip --numeric-owner --file="$MANAGER_ARCHIVE_PATHFILE" --directory="$WORK_PATH" "$MANAGER_FILE"
tar --create --gzip --numeric-owner --file="$OBJECTS_ARCHIVE_PATHFILE" --directory="$WORK_PATH" "$OBJECTS_FILE"
tar --create --gzip --numeric-owner --file="$PACKAGES_ARCHIVE_PATHFILE" --directory="$WORK_PATH" "$PACKAGES_FILE"
