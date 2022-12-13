#!/usr/bin/env bash
####################################################################################
# nzbtomedia.sh
#
# Copyright (C) 2020-2022 OneCD [one.cd.only@gmail.com]
#
# so, blame OneCD if it all goes horribly wrong. ;)
#
# This is a type 2 service-script: https://github.com/OneCDOnly/sherpa/blob/main/QPKG-service-script-types.txt
#
# For more info: https://forum.qnap.com/viewtopic.php?f=320&t=132373
####################################################################################

Init()
    {

    IsQNAP || return

    # specific environment
    readonly QPKG_NAME=nzbToMedia
    readonly SCRIPT_VERSION=221213
    local -r MIN_RAM_KB=any

    # general environment
    readonly QPKG_PATH=$(/sbin/getcfg $QPKG_NAME Install_Path -f /etc/config/qpkg.conf)
    readonly QPKG_VERSION=$(/sbin/getcfg $QPKG_NAME Version -d unknown -f /etc/config/qpkg.conf)
    readonly APP_VERSION_STORE_PATHFILE=$QPKG_PATH/config/version.stored
    readonly SERVICE_STATUS_PATHFILE=/var/run/$QPKG_NAME.last.operation
    readonly SERVICE_LOG_PATHFILE=/var/log/$QPKG_NAME.log
    local -r BACKUP_PATH=$(/sbin/getcfg SHARE_DEF defVolMP -f /etc/config/def_share.info)/.qpkg_config_backup
    readonly BACKUP_PATHFILE=$BACKUP_PATH/$QPKG_NAME.config.tar.gz
    local -r INSTALLED_RAM_KB=$(/bin/grep MemTotal /proc/meminfo | cut -f2 -d':' | /bin/sed 's|kB||;s| ||g')
    readonly OPKG_PATH=/opt/bin:/opt/sbin
    export PATH="$OPKG_PATH:$(/bin/sed "s|$OPKG_PATH||" <<< "$PATH")"
    readonly APPARENT_PATH=/share/$(/sbin/getcfg SHARE_DEF defDownload -d Qdownload -f /etc/config/def_share.info)/$QPKG_NAME

    # specific to online-sourced applications only
    readonly SOURCE_GIT_URL=https://github.com/clinton-hall/nzbToMedia.git
    readonly SOURCE_GIT_BRANCH=master
    readonly SOURCE_GIT_DEPTH=shallow     # 'shallow' (depth 1) or 'single-branch' - note: 'shallow' implies a 'single-branch' too
    readonly TARGET_SCRIPT=''

    # general online-sourced applications only
    readonly QPKG_REPO_PATH=$QPKG_PATH/repo-cache
    readonly PIP_CACHE_PATH=$QPKG_PATH/pip-cache
    readonly INTERPRETER=/opt/bin/python3
    readonly VENV_PATH=$QPKG_PATH/venv
    readonly VENV_INTERPRETER=$VENV_PATH/bin/python3
    readonly ALLOW_ACCESS_TO_SYS_PACKAGES=false
    readonly APP_VERSION_PATHFILE=$QPKG_REPO_PATH/.bumpversion.cfg
    readonly DAEMON_PATHFILE=''
    readonly QPKG_INI_PATHFILE=$QPKG_REPO_PATH/autoProcessMedia.cfg
    readonly QPKG_INI_DEFAULT_PATHFILE=$QPKG_INI_PATHFILE.spec

    if [[ $MIN_RAM_KB != any && $INSTALLED_RAM_KB -lt $MIN_RAM_KB ]]; then
        DisplayErrCommitAllLogs "$(FormatAsPackageName $QPKG_NAME) won't run on this NAS. Not enough RAM. :("
        exit 1
    fi

    ui_port=0
    ui_port_secure=0
    ui_listening_address=''

    if [[ -z $LANG ]]; then
        export LANG=en_US.UTF-8
        export LC_ALL=en_US.UTF-8
        export LC_CTYPE=en_US.UTF-8
    fi

    UnsetError
    UnsetRestartPending
    LoadAppVersion

    IsSupportBackup && [[ -n $BACKUP_PATH && ! -d $BACKUP_PATH ]] && mkdir -p "$BACKUP_PATH"
    [[ -n $VENV_PATH && ! -d $VENV_PATH ]] && mkdir -p "$VENV_PATH"
    [[ -n $PIP_CACHE_PATH && ! -d $PIP_CACHE_PATH ]] && mkdir -p "$PIP_CACHE_PATH"

    IsAutoUpdateMissing && EnableAutoUpdate >/dev/null

    return 0

    }

ShowHelp()
    {

    Display "$(ColourTextBrightWhite "$(/usr/bin/basename "$0")") $SCRIPT_VERSION • a service control script for the $(FormatAsPackageName $QPKG_NAME) QPKG"
    Display
    Display "Usage: $0 [OPTION]"
    Display
    Display '[OPTION] may be any one of the following:'
    Display
    DisplayAsHelp start "activate $(FormatAsPackageName $QPKG_NAME) if not already active."
    DisplayAsHelp stop "deactivate $(FormatAsPackageName $QPKG_NAME) if active."
    DisplayAsHelp restart "stop, then start $(FormatAsPackageName $QPKG_NAME)."
    DisplayAsHelp status "check if $(FormatAsPackageName $QPKG_NAME) package is active. Returns \$? = 0 if active, 1 if not."
    IsSupportBackup && DisplayAsHelp backup "backup the current $(FormatAsPackageName $QPKG_NAME) configuration to persistent storage."
    IsSupportBackup && DisplayAsHelp restore "restore a previously saved configuration from persistent storage. $(FormatAsPackageName $QPKG_NAME) will be stopped, then restarted."
    IsSupportReset && DisplayAsHelp reset-config "delete the application configuration, databases and history. $(FormatAsPackageName $QPKG_NAME) will be stopped, then restarted."
    IsSourcedOnline && DisplayAsHelp clean "delete the local copy of $(FormatAsPackageName $QPKG_NAME), and download it again from remote source. Configuration will be retained."
    DisplayAsHelp log 'display the service-script log.'
    IsSourcedOnline && DisplayAsHelp enable-auto-update "auto-update $(FormatAsPackageName $QPKG_NAME) before starting (default)."
    IsSourcedOnline && DisplayAsHelp disable-auto-update "don't auto-update $(FormatAsPackageName $QPKG_NAME) before starting."
    DisplayAsHelp version 'display the package version numbers.'
    Display

    }

StartQPKG()
    {

    # this function is customised depending on the requirements of the packaged application

    IsError && return

    if IsNotRestart && IsNotRestore && IsNotClean && IsNotReset; then
        CommitOperationToLog
        IsPackageActive && return
    fi

    if IsRestore || IsClean || IsReset; then
        IsNotRestartPending && return
    fi

    local -r SAB_MIN_VERSION=200809

    DisplayCommitToLog "auto-update: $(IsAutoUpdate && echo TRUE || echo FALSE)"
    PullGitRepo "$QPKG_NAME" "$SOURCE_GIT_URL" "$SOURCE_GIT_BRANCH" "$SOURCE_GIT_DEPTH" "$QPKG_REPO_PATH" || return
    WaitForLaunchTarget || return

    if [[ $(/sbin/getcfg SABnzbdplus Enable -f /etc/config/qpkg.conf) = TRUE ]]; then
        DisplayErrCommitAllLogs "unable to link from package to target: installed $(FormatAsPackageName SABnzbdplus) QPKG must be replaced with $(FormatAsPackageName SABnzbd) $SAB_MIN_VERSION or later"
        return 1
    fi

    if [[ $(/sbin/getcfg SABnzbd Enable -f /etc/config/qpkg.conf) = TRUE ]]; then
        local current_version=$(/sbin/getcfg SABnzbd Version -f /etc/config/qpkg.conf)

        if [[ ${current_version//[!0-9]/} -lt $SAB_MIN_VERSION ]]; then
            DisplayErrCommitAllLogs "unable to link from package to target: installed $(FormatAsPackageName SABnzbd) QPKG must first be upgraded to $SAB_MIN_VERSION or later"
            return 1
        fi
    fi

    # save config from original nzbToMedia install (created by sherpa SABnzbd QPKGs earlier than $SAB_MIN_VERSION)
    if [[ -d $APPARENT_PATH && ! -L $APPARENT_PATH && -e "$APPARENT_PATH/$(/usr/bin/basename "$QPKG_INI_PATHFILE")" ]]; then
        cp "$APPARENT_PATH/$(/usr/bin/basename "$QPKG_INI_PATHFILE")" "$QPKG_INI_PATHFILE"
    fi

    # destroy original installation
    [[ -d $APPARENT_PATH ]] && rm -r "$APPARENT_PATH"

    # need this if [Download] isn't a share on this NAS
    [[ ! -e $(/usr/bin/dirname $APPARENT_PATH) ]] && mkdir -p $(/usr/bin/dirname $APPARENT_PATH)

    ln -s "$QPKG_REPO_PATH" "$APPARENT_PATH"

    DisplayCommitToLog 'start package: OK'
    EnsureConfigFileExists
    IsPackageActive || return

    return 0

    }

StopQPKG()
    {

    # this function is customised depending on the requirements of the packaged application

    IsError && return

    if IsNotRestart && IsNotRestore && IsNotClean && IsNotReset; then
        CommitOperationToLog
        IsNotPackageActive && return
    fi

    if IsRestart || IsRestore || IsClean || IsReset; then
        SetRestartPending
    fi

    [[ -L $APPARENT_PATH ]] && rm "$APPARENT_PATH"
    DisplayCommitToLog 'stop package: OK'
    IsNotPackageActive || return

    return 0

    }

BackupConfig()
    {

    CommitOperationToLog
    ExecuteAndLog 'update configuration backup' "/bin/tar --create --gzip --file=$BACKUP_PATHFILE --directory=$QPKG_REPO_PATH autoProcessMedia.cfg" log:everything

    }

RestoreConfig()
    {

    CommitOperationToLog

    if [[ ! -f $BACKUP_PATHFILE ]]; then
        DisplayErrCommitAllLogs 'unable to restore configuration: no backup file was found!'
        SetError
        return 1
    fi

    StopQPKG
    ExecuteAndLog 'restore configuration backup' "/bin/tar --extract --gzip --file=$BACKUP_PATHFILE --directory=$QPKG_REPO_PATH" log:everything
    StartQPKG

    }

ResetConfig()
    {

    CommitOperationToLog

    StopQPKG
    ExecuteAndLog 'reset configuration' "rm $QPKG_INI_PATHFILE" log:everything
    StartQPKG

    }

LoadAppVersion()
    {

    # Find the application's internal version number
    # creates a global var: $app_version
    # this is the installed application version (not the QPKG version)

    app_version=''

    if [[ -n $APP_VERSION_PATHFILE && -e $APP_VERSION_PATHFILE ]]; then
        app_version=$(/sbin/getcfg bumpversion current_version -d 0 -f "$APP_VERSION_PATHFILE")
        return
    elif [[ -n $DAEMON_PATHFILE && -e $DAEMON_PATHFILE ]]; then
        app_version=$($DAEMON_PATHFILE --version 2>&1 | /bin/sed 's|nzbget version: ||')
        return
    fi

    return 1

    }

StatusQPKG()
    {

    IsNotError || return

    if IsNotPackageActive; then
        SetError
        return 1
    fi

    return 0

    }

PullGitRepo()
    {

    # $1 = package name
    # $2 = URL to pull/clone from
    # $3 = remote branch or tag
    # $4 = remote depth: 'shallow' or 'single-branch'
    # $5 = local path to clone into

    [[ -z $1 || -z $2 || -z $3 || -z $4 || -z $5 ]] && return 1

    local -r QPKG_GIT_PATH="$5"
    local -r GIT_HTTPS_URL="$2"
    local installed_branch=''
    local branch_switch=false
    [[ $4 = shallow ]] && local -r DEPTH='--depth 1'
    [[ $4 = single-branch ]] && local -r DEPTH='--single-branch'

    WaitForGit || return 1

    if [[ -d $QPKG_GIT_PATH/.git ]]; then
        installed_branch=$(/opt/bin/git -C "$QPKG_GIT_PATH" branch | /bin/grep '^\*' | /bin/sed 's|^\* ||')

        if [[ $installed_branch != "$3" ]]; then
            branch_switch=true
            DisplayCommitToLog "current git branch: $installed_branch, new git branch: $3"
            [[ $QPKG_NAME = nzbToMedia ]] && BackupConfig
            ExecuteAndLog 'new git branch has been specified, so clean local repository' "cd /tmp; rm -r $QPKG_GIT_PATH"
        fi
    fi

    if [[ ! -d $QPKG_GIT_PATH/.git ]]; then
        ExecuteAndLog "clone $(FormatAsPackageName "$1") from remote repository" "cd /tmp; /opt/bin/git clone --branch $3 $DEPTH -c advice.detachedHead=false $GIT_HTTPS_URL $QPKG_GIT_PATH"
    else
        if IsAutoUpdate; then
            # latest effort at resolving local corruption, source: https://stackoverflow.com/a/10170195
            ExecuteAndLog "update $(FormatAsPackageName "$1") from remote repository" "cd /tmp; /opt/bin/git -C $QPKG_GIT_PATH clean -f; /opt/bin/git -C $QPKG_GIT_PATH reset --hard origin/$3; /opt/bin/git -C $QPKG_GIT_PATH pull"
        fi
    fi

    if IsAutoUpdate; then
        installed_branch=$(/opt/bin/git -C "$QPKG_GIT_PATH" branch | /bin/grep '^\*' | /bin/sed 's|^\* ||')
        DisplayCommitToLog "current git branch: $installed_branch"
    fi

    [[ $branch_switch = true && $QPKG_NAME = nzbToMedia ]] && RestoreConfig

    return 0

    }

CleanLocalClone()
    {

    # for occasions where the local repo needs to be deleted and cloned again from source.

    CommitOperationToLog

    if [[ -z $QPKG_PATH || -z $QPKG_NAME ]] || IsNotSourcedOnline; then
        SetError
        return 1
    fi

    StopQPKG
    ExecuteAndLog 'clean local repository' "rm -rf $QPKG_REPO_PATH"
    [[ -d $(dirname $QPKG_REPO_PATH)/$QPKG_NAME ]] && ExecuteAndLog 'KLUDGE: remove previous local repository' "rm -r $(dirname $QPKG_REPO_PATH)/$QPKG_NAME"
    ExecuteAndLog 'clean virtual environment' "rm -rf $VENV_PATH"
    ExecuteAndLog 'clean PyPI cache' "rm -rf $PIP_CACHE_PATH"
    StartQPKG

    }

IsQNAP()
    {

    # returns 0 if this is a QNAP NAS

    if [[ ! -e /etc/init.d/functions ]]; then
        Display 'QTS functions missing (is this a QNAP NAS?)'
        SetError
        return 1
    fi

    return 0

    }

WaitForGit()
    {

    if WaitForFileToAppear '/opt/bin/git' 300; then
        export PATH="$OPKG_PATH:$(/bin/sed "s|$OPKG_PATH||" <<< "$PATH")"
        return 0
    else
        return 1
    fi

    }

WaitForLaunchTarget()
    {

    local launch_target=''

    if [[ -n $INTERPRETER ]]; then
        launch_target=$INTERPRETER
    elif [[ -n $DAEMON_PATHFILE ]]; then
        launch_target=$DAEMON_PATHFILE
    else
        return 0
    fi

    if WaitForFileToAppear "$launch_target" 30; then
        return 0
    else
        return 1
    fi

    }

WaitForFileToAppear()
    {

    # input:
    #   $1 = pathfilename to watch for
    #   $2 = timeout in seconds (optional) - default 30

    # output:
    #   $? = 0 (file was found) or 1 (file not found: timeout)

    [[ -z $1 ]] && return

    if [[ -n $2 ]]; then
        MAX_SECONDS=$2
    else
        MAX_SECONDS=30
    fi

    if [[ ! -e $1 ]]; then
        DisplayWaitCommitToLog "wait for $(FormatAsFileName "$1") to appear:"
        DisplayWait "(no-more than $MAX_SECONDS seconds):"

        (
            for ((count=1; count<=MAX_SECONDS; count++)); do
                sleep 1
                DisplayWait "$count,"
                if [[ -e $1 ]]; then
                    Display OK
                    CommitLog "visible in $count second$(FormatAsPlural "$count")"
                    true
                    exit    # only this sub-shell
                fi
            done
            false
        )

        if [[ $? -ne 0 ]]; then
            DisplayCommitToLog 'failed!'
            DisplayErrCommitAllLogs "$(FormatAsFileName "$1") not found! (exceeded timeout: $MAX_SECONDS seconds)"
            return 1
        fi
    fi

    DisplayCommitToLog "file $(FormatAsFileName "$1"): exists"

    return 0

    }

EnsureConfigFileExists()
    {

    IsNotSupportReset && return

    if IsNotConfigFound && IsDefaultConfigFound; then
        DisplayCommitToLog 'no configuration file found: using default'
        cp "$QPKG_INI_DEFAULT_PATHFILE" "$QPKG_INI_PATHFILE"
    fi

    }

SaveAppVersion()
    {

    [[ -z $APP_VERSION_STORE_PATHFILE ]] && return

    echo "$app_version" > "$APP_VERSION_STORE_PATHFILE"

    }

ViewLog()
    {

    if [[ -e $SERVICE_LOG_PATHFILE ]]; then
        if [[ -e /opt/bin/less ]]; then
            LESSSECURE=1 /opt/bin/less +G --quit-on-intr --tilde --LINE-NUMBERS --prompt ' use arrow-keys to scroll up-down left-right, press Q to quit' "$SERVICE_LOG_PATHFILE"
        else
            cat --number "$SERVICE_LOG_PATHFILE"
        fi
    else
        Display "service log not found: $(FormatAsFileName "$SERVICE_LOG_PATHFILE")"
        SetError
        return 1
    fi

    return 0

    }

ExecuteAndLog()
    {

    # $1 processing message
    # $2 command(s) to run
    # $3 'log:everything' (optional) - if specified, the processing message and successful results are recorded in the QTS system log.
    #                                - if unspecified, only warnings/ errors are recorded in the QTS system log.

    if [[ -z $1 || -z $2 ]]; then
        SetError
        return 1
    fi

    local exec_msgs=''
    local result=0

    DisplayWaitCommitToLog "$1:"
    exec_msgs=$(eval "$2" 2>&1)
    result=$?

    if [[ $result = 0 ]]; then
        DisplayCommitToLog OK
        [[ $3 = log:everything ]] && CommitInfoToSysLog "$1: OK."
        return 0
    else
        DisplayCommitToLog 'failed!'
        DisplayCommitToLog "$(FormatAsFuncMessages "$exec_msgs")"
        DisplayCommitToLog "$(FormatAsResult $result)"
        CommitWarnToSysLog "A problem occurred while $1. Check $(FormatAsFileName "$SERVICE_LOG_PATHFILE") for more details."
        SetError
        return 1
    fi

    }

IsQPKGEnabled()
    {

    [[ $(/sbin/getcfg $QPKG_NAME Enable -u -d FALSE -f /etc/config/qpkg.conf) = TRUE ]]

    }

IsNotQPKGEnabled()
    {

    ! IsQPKGEnabled

    }

IsSupportBackup()
    {

    [[ -n $BACKUP_PATHFILE ]]

    }

IsNotSupportBackup()
    {

    ! IsSupportBackup

    }

IsSupportReset()
    {

    [[ -n $QPKG_INI_PATHFILE ]]

    }

IsNotSupportReset()
    {

    ! IsSupportReset

    }

IsSourcedOnline()
    {

    [[ -n $SOURCE_GIT_URL ]]

    }

IsNotSourcedOnline()
    {

    ! IsSourcedOnline

    }

IsPackageActive()
    {

    if [[ -L $APPARENT_PATH ]]; then
        DisplayCommitToLog 'package: IS active'
        return
    fi

    DisplayCommitToLog 'package: NOT active'
    return 1

    }

IsNotPackageActive()
    {

    ! IsPackageActive

    }

IsSysFilePresent()
    {

    # $1 = pathfile to check

    if [[ -z $1 ]]; then
        SetError
        return 1
    fi

    if [[ ! -e $1 ]]; then
        Display "A required NAS system file is missing: $(FormatAsFileName "$1")"
        SetError
        return 1
    else
        return 0
    fi

    }

IsNotSysFilePresent()
    {

    # $1 = pathfile to check

    ! IsSysFilePresent "$1"

    }

IsPortAvailable()
    {

    # $1 = port to check
    # $? = 0 if available
    # $? = 1 if already used

    [[ -z $1 || $1 -eq 0 ]] && return

    if (/usr/sbin/lsof -i :"$1" -sTCP:LISTEN >/dev/null 2>&1); then
        return 1
    else
        return 0
    fi

    }

IsNotPortAvailable()
    {

    # $1 = port to check
    # $? = 1 if available
    # $? = 0 if already used

    ! IsPortAvailable "$1"

    }

IsPortResponds()
    {

    # $1 = port to check
    # $? = 0 if response received
    # $? = 1 if not OK

    if [[ -z $1 || $1 -eq 0 ]]; then
        SetError
        return 1
    fi

    local acc=0

    DisplayWaitCommitToLog "check for UI port $1 response:"
    DisplayWait "(no-more than $PORT_CHECK_TIMEOUT seconds):"

    while ! /sbin/curl --silent --fail --max-time 1 http://localhost:"$1" >/dev/null; do
        sleep 1
        ((acc+=2))
        DisplayWait "$acc,"

        if [[ $acc -ge $PORT_CHECK_TIMEOUT ]]; then
            DisplayCommitToLog 'failed!'
            CommitErrToSysLog "UI port $1 failed to respond after $acc seconds"
            return 1
        fi
    done

    Display OK
    CommitLog "UI port responded after $acc seconds"

    return 0

    }

IsPortSecureResponds()
    {

    # $1 = port to check
    # $? = 0 if response received
    # $? = 1 if not OK or port unspecified

    if [[ -z $1 || $1 -eq 0 ]]; then
        SetError
        return 1
    fi

    local acc=0

    DisplayWaitCommitToLog "check for secure UI port $1 response:"
    DisplayWait "(no-more than $PORT_CHECK_TIMEOUT seconds):"

    while ! /sbin/curl --silent --insecure --fail --max-time 1 https://localhost:"$1" >/dev/null; do
        sleep 1
        ((acc+=2))
        DisplayWait "$acc,"

        if [[ $acc -ge $PORT_CHECK_TIMEOUT ]]; then
            DisplayCommitToLog 'failed!'
            CommitErrToSysLog "secure UI port $1 failed to respond after $acc seconds"
            return 1
        fi
    done

    Display OK
    CommitLog "secure UI port responded after $acc seconds"

    return 0

    }

IsConfigFound()
    {

    # Is there an application configuration file to read from?

    [[ -e $QPKG_INI_PATHFILE ]]

    }

IsNotConfigFound()
    {

    ! IsConfigFound

    }

IsDefaultConfigFound()
    {

    # Is there a default application configuration file to read from?

    [[ -e $QPKG_INI_DEFAULT_PATHFILE ]]

    }

IsNotDefaultConfigFound()
    {

    ! IsDefaultConfigFound

    }

IsVirtualEnvironmentExist()
    {

    # Is there a virtual environment to run the application in?

    [[ -e $VENV_PATH/bin/activate ]]

    }

IsNotVirtualEnvironmentExist()
    {

    ! IsVirtualEnvironmentExist

    }

SetServiceOperation()
    {

    service_operation="$1"
    SetServiceOperationResult "$1"

    }

SetServiceOperationResultOK()
    {

    SetServiceOperationResult ok

    }

SetServiceOperationResultFailed()
    {

    SetServiceOperationResult failed

    }

SetServiceOperationResult()
    {

    # $1 = result of operation to recorded

    [[ -n $1 && -n $SERVICE_STATUS_PATHFILE ]] && echo "$1" > "$SERVICE_STATUS_PATHFILE"

    }

SetRestartPending()
    {

    IsRestartPending && return
    _restart_pending_flag=true

    }

UnsetRestartPending()
    {

    IsNotRestartPending && return
    _restart_pending_flag=false

    }

IsRestartPending()
    {

    [[ $_restart_pending_flag = true ]]

    }

IsNotRestartPending()
    {

    [[ $_restart_pending_flag = false ]]

    }

SetError()
    {

    IsError && return
    _error_flag=true

    }

UnsetError()
    {

    IsNotError && return
    _error_flag=false

    }

IsError()
    {

    [[ $_error_flag = true ]]

    }

IsNotError()
    {

    ! IsError

    }

IsRestart()
    {

    [[ $service_operation = restarting ]]

    }

IsNotRestart()
    {

    ! IsRestart

    }

IsNotRestore()
    {

    ! [[ $service_operation = restoring ]]

    }

IsNotLog()
    {

    ! [[ $service_operation = log ]]

    }

IsClean()
    {

    [[ $service_operation = cleaning ]]

    }

IsNotClean()
    {

    ! IsClean

    }

IsRestore()
    {

    [[ $service_operation = restoring ]]

    }

IsNotRestore()
    {

    ! IsRestore

    }

IsReset()
    {

    [[ $service_operation = 'resetting-config' ]]

    }

IsNotReset()
    {

    ! IsReset

    }

IsNotStatus()
    {

    ! [[ $service_operation = status ]]

    }

DisplayErrCommitAllLogs()
    {

    DisplayCommitToLog "$1"
    CommitErrToSysLog "$1"

    }

DisplayCommitToLog()
    {

    Display "$1"
    CommitLog "$1"

    }

DisplayWaitCommitToLog()
    {

    DisplayWait "$1"
    CommitLogWait "$1"

    }

FormatAsStdout()
    {

    Display "output: \"$1\""

    }

FormatAsResult()
    {

    Display "result: $(FormatAsExitcode "$1")"

    }

FormatAsFuncMessages()
    {

    echo "= ${FUNCNAME[1]}()"
    FormatAsStdout "$1"

    }

FormatAsExitcode()
    {

    echo "[$1]"

    }

FormatAsPackageName()
    {

    echo "'$1'"

    }

FormatAsFileName()
    {

    echo "($1)"

    }

DisplayAsHelp()
    {

    printf "  --%-19s  %s\n" "$1" "$2"

    }

Display()
    {

    echo "$1"

    }

DisplayWait()
    {

    echo -n "$1 "

    }

CommitOperationToLog()
    {

    CommitLog "$(SessionSeparator "datetime:'$(date)', request:'$service_operation', package:'$QPKG_VERSION', service:'$SCRIPT_VERSION', app:'$app_version'")"

    }

CommitInfoToSysLog()
    {

    CommitSysLog "$1" 4

    }

CommitWarnToSysLog()
    {

    CommitSysLog "$1" 2

    }

CommitErrToSysLog()
    {

    CommitSysLog "$1" 1

    }

CommitLog()
    {

    if IsNotStatus && IsNotLog; then
        echo "$1" >> "$SERVICE_LOG_PATHFILE"
    fi

    }

CommitLogWait()
    {

    if IsNotStatus && IsNotLog; then
        echo -n "$1 " >> "$SERVICE_LOG_PATHFILE"
    fi

    }

CommitSysLog()
    {

    # $1 = message to append to QTS system log
    # $2 = event type:
    #    1 : Error
    #    2 : Warning
    #    4 : Information

    if [[ -z $1 || -z $2 ]]; then
        SetError
        return 1
    fi

    /sbin/write_log "[$QPKG_NAME] $1" "$2"

    }

SessionSeparator()
    {

    # $1 = message

    printf '%0.s>' {1..10}; echo -n " $1 "; printf '%0.s<' {1..10}

    }

ColourTextBrightWhite()
    {

    echo -en '\033[1;97m'"$(ColourReset "$1")"

    }

ColourReset()
    {

    echo -en "$1"'\033[0m'

    }

FormatAsPlural()
    {

    [[ $1 -ne 1 ]] && echo s

    }

IsAutoUpdateMissing()
    {

    [[ $(/sbin/getcfg $QPKG_NAME Auto_Update -u -f /etc/config/qpkg.conf) = '' ]]

    }

IsAutoUpdate()
    {

    [[ $(/sbin/getcfg $QPKG_NAME Auto_Update -u -f /etc/config/qpkg.conf) = TRUE ]]

    }

IsNotAutoUpdate()
    {

    ! IsAutoUpdate

    }

EnableAutoUpdate()
    {

    StoreAutoUpdateSelection TRUE

    }

DisableAutoUpdate()
    {

    StoreAutoUpdateSelection FALSE

    }

StoreAutoUpdateSelection()
    {

    /sbin/setcfg "$QPKG_NAME" Auto_Update "$1" -f /etc/config/qpkg.conf
    DisplayCommitToLog "auto-update: $1"

    }

Init

if IsNotError; then
    case $1 in
        start|--start)
            if IsNotQPKGEnabled; then
                echo "The $(FormatAsPackageName $QPKG_NAME) QPKG is disabled. Please enable it first with: qpkg_service enable $QPKG_NAME"
                SetError
            fi

            SetServiceOperation starting
            StartQPKG
            ;;
        stop|--stop)
            if IsNotQPKGEnabled; then
                echo "The $(FormatAsPackageName $QPKG_NAME) QPKG is disabled. Please enable it first with: qpkg_service enable $QPKG_NAME"
                SetError
            fi

            SetServiceOperation stopping
            StopQPKG
            ;;
        r|-r|restart|--restart)
            if IsNotQPKGEnabled; then
                echo "The $(FormatAsPackageName $QPKG_NAME) QPKG is disabled. Please enable it first with: qpkg_service enable $QPKG_NAME"
                SetError
            fi

            SetServiceOperation restarting
            StopQPKG
            StartQPKG
            ;;
        s|-s|status|--status)
            SetServiceOperation status
            StatusQPKG
            ;;
        b|-b|backup|--backup|backup-config|--backup-config)
            if IsSupportBackup; then
                SetServiceOperation backing-up
                BackupConfig
            else
                SetServiceOperation none
                ShowHelp
            fi
            ;;
        reset-config|--reset-config)
            if IsSupportReset; then
                SetServiceOperation resetting-config
                ResetConfig
            else
                SetServiceOperation none
                ShowHelp
            fi
            ;;
        restore|--restore|restore-config|--restore-config)
            if IsSupportBackup; then
                SetServiceOperation restoring
                RestoreConfig
            else
                SetServiceOperation none
                ShowHelp
            fi
            ;;
        c|-c|clean|--clean)
            if IsSourcedOnline; then
                SetServiceOperation cleaning

                if [[ $QPKG_NAME = nzbToMedia ]]; then
                    # nzbToMedia stores the config file in the repo location, so save it and restore again after new clone is complete
                    BackupConfig && CleanLocalClone && RestoreConfig
                else
                    CleanLocalClone
                fi
            else
                SetServiceOperation none
                ShowHelp
            fi
            ;;
        l|-l|log|--log)
            SetServiceOperation logging
            ViewLog
            ;;
        disable-auto-update|--disable-auto-update)
            SetServiceOperation disable-auto-update
            DisableAutoUpdate
            ;;
        enable-auto-update|--enable-auto-update)
            SetServiceOperation enable-auto-update
            EnableAutoUpdate
            ;;
        v|-v|version|--version)
            SetServiceOperation versioning
            Display "package: $QPKG_VERSION"
            Display "service: $SCRIPT_VERSION"
            ;;
        *)
            SetServiceOperation none
            ShowHelp
    esac
fi

if IsError; then
    SetServiceOperationResultFailed
    exit 1
fi

SetServiceOperationResultOK
exit
