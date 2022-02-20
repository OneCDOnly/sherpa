#!/usr/bin/env bash

# standalone compiler for all sherpa archives

PROJECT_NAME=sherpa
PROJECT_BRANCH=main
WORK_PATH=$PWD

PACKAGE_SCOPES=(All Dependent HasDependents Installable Names Standalone SupportBackup SupportUpdateOnRestart Upgradable)
PACKAGE_STATES=(BackedUp Disabled Downloaded Enabled Installed Missing Starting Started Stopping Stopped Restarting)
PACKAGE_OPERATIONS=(Backup Disable Download Enable Install Rebuild Reinstall Restart Restore Start Stop Uninstall Upgrade)
PACKAGE_TIERS=(Standalone Addon Dependent)

MANAGER_FILE=$PROJECT_NAME.manager.sh
MANAGER_ARCHIVE_FILE=${MANAGER_FILE%.*}.tar.gz
MANAGER_ARCHIVE_URL=https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/$PROJECT_BRANCH/$MANAGER_ARCHIVE_FILE
MANAGER_ARCHIVE_PATHFILE=$WORK_PATH/$MANAGER_ARCHIVE_FILE
MANAGER_PATHFILE=$WORK_PATH/$MANAGER_FILE

OBJECTS_FILE=objects
OBJECTS_ARCHIVE_FILE=$OBJECTS_FILE.tar.gz
OBJECTS_ARCHIVE_URL=https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/$PROJECT_BRANCH/$OBJECTS_ARCHIVE_FILE
OBJECTS_ARCHIVE_PATHFILE=$WORK_PATH/$OBJECTS_ARCHIVE_FILE
OBJECTS_PATHFILE=$WORK_PATH/$OBJECTS_FILE

PACKAGES_FILE=packages
PACKAGES_ARCHIVE_FILE=$PACKAGES_FILE.tar.gz
PACKAGES_ARCHIVE_URL=https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/$PROJECT_BRANCH/$PACKAGES_ARCHIVE_FILE
PACKAGES_ARCHIVE_PATHFILE=$WORK_PATH/$PACKAGES_ARCHIVE_FILE
PACKAGES_PATHFILE=$WORK_PATH/$PACKAGES_FILE

AddFlagObj()
    {

    # $1 = object name to create

    local public_function_name=${1:?no object name supplied}
    local safe_function_name="$(tr 'A-Z' 'a-z' <<< "${public_function_name//[.-]/_}")"

    _placeholder_text_=_ob_${safe_function_name}_tx_
    _placeholder_flag_=_ob_${safe_function_name}_fl_
    _placeholder_log_changes_flag_=_ob_${safe_function_name}_chfl_

echo $public_function_name'.Clear()
{ [[ $'$_placeholder_flag_' != '\'true\'' ]] && return
'$_placeholder_flag_'=false
[[ $'$_placeholder_log_changes_flag_' = '\'true\'' ]] && DebugVar '$_placeholder_flag_' ;}
'$public_function_name'.NoLogMods()
{ [[ $'$_placeholder_log_changes_flag_' != '\'true\'' ]] && return
'$_placeholder_log_changes_flag_'=false ;}
'$public_function_name'.Init()
{ '$_placeholder_text_'='\'\''
'$_placeholder_flag_'=false
'$_placeholder_log_changes_flag_'=true ;}
'$public_function_name'.IsNt()
{ [[ $'$_placeholder_flag_' != '\'true\'' ]] ;}
'$public_function_name'.IsSet()
{ [[ $'$_placeholder_flag_' = '\'true\'' ]] ;}
'$public_function_name'.Set()
{ [[ $'$_placeholder_flag_' = '\'true\'' ]] && return
'$_placeholder_flag_'=true
[[ $'$_placeholder_log_changes_flag_' = '\'true\'' ]] && DebugVar '$_placeholder_flag_' ;}
'$public_function_name'.Text()
{ if [[ -n ${1:-} && $1 = "=" ]]; then
'$_placeholder_text_'=$2
else
echo -n "$'$_placeholder_text_'"
fi ;}
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
if [[ $ag = $it ]]; then
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
echo -n $'$_placeholder_size_'
fi ;}
'$public_function_name'.Init' >> "$OBJECTS_PATHFILE"

    return 0

    }

[[ -e $MANAGER_ARCHIVE_PATHFILE ]] && rm $MANAGER_ARCHIVE_PATHFILE
[[ -e $OBJECTS_ARCHIVE_PATHFILE ]] && rm $OBJECTS_ARCHIVE_PATHFILE
[[ -e $OBJECTS_PATHFILE ]] && rm $OBJECTS_PATHFILE
[[ -e $PACKAGES_ARCHIVE_PATHFILE ]] && rm $PACKAGES_ARCHIVE_PATHFILE

# session flags
for element in Display.Clean LineSpace ShowBackupLoc SuggestIssue Summary; do
    AddFlagObj Session.$element
done

for element in ToArchive ToFile ToScreen; do
    AddFlagObj Session.Debug.$element
done

AddFlagObj QPKGs.States.Built
AddFlagObj QPKGs.SkProc
AddFlagObj IPKGs.ToUpgrade
AddFlagObj IPKGs.ToInstall
AddFlagObj PIPs.ToInstall

# user option flags
for element in Deps.Check IgFreeSpace Versions.View; do
    AddFlagObj Opts.$element
done

for element in Abbreviations Actions ActionsAll Backups Basic Options Packages Problems Status Tips; do
    AddFlagObj Opts.Help.$element
done

for element in All Last Tail; do
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
    for operation in "${PACKAGE_OPERATIONS[@]}"; do
        AddFlagObj Opts.Apps.Op${operation}.Sc${scope}
        AddFlagObj Opts.Apps.Op${operation}.ScNt${scope}
    done
done

for state in "${PACKAGE_STATES[@]}"; do
    for operation in "${PACKAGE_OPERATIONS[@]}"; do
        AddFlagObj Opts.Apps.Op${operation}.Is${state}
        AddFlagObj Opts.Apps.Op${operation}.IsNt${state}
    done
done

# lists
AddListObj Args.Unknown

for operation in "${PACKAGE_OPERATIONS[@]}"; do
    AddListObj QPKGs.OpTo${operation}      # to operate on
    AddListObj QPKGs.OpOk${operation}      # operation was tried and succeeded
    AddListObj QPKGs.OpEr${operation}      # operation was tried but failed
    AddListObj QPKGs.OpSk${operation}      # operation was skipped
done

for operation in Download Install Uninstall Upgrade; do     # only a subset of addon package operations are supported for-now
    AddListObj IPKGs.OpTo${operation}
    AddListObj PIPs.OpTo${operation}
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
