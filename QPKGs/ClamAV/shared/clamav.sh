#!/usr/bin/env bash
####################################################################################
# clamav.sh
#
# Copyright (C) 2021 OneCD [one.cd.only@gmail.com]
#
# so, blame OneCD if it all goes horribly wrong. ;)
#
# For more info: https://forum.qnap.com/viewtopic.php?f=320&t=132373
####################################################################################

Init()
    {

    IsQNAP || return

    # specific environment
    readonly QPKG_NAME=ClamAV

    # cherry-pick required binaries
    readonly GREP_CMD=/bin/grep
    readonly SED_CMD=/bin/sed
    readonly TAR_CMD=/bin/tar

    readonly BASENAME_CMD=/usr/bin/basename
    readonly DIRNAME_CMD=/usr/bin/dirname
    readonly TAIL_CMD=/usr/bin/tail
    readonly TEE_CMD=/usr/bin/tee

    readonly CURL_CMD=/sbin/curl
    readonly GETCFG_CMD=/sbin/getcfg
    readonly SETCFG_CMD=/sbin/setcfg
    readonly WRITE_LOG_CMD=/sbin/write_log

    readonly LSOF_CMD=/usr/sbin/lsof

    readonly GIT_CMD=/opt/bin/git
    readonly GNU_LESS_CMD=/opt/bin/less
    readonly JQ_CMD=/opt/bin/jq

    # generic environment
    readonly APP_CENTER_CONFIG_PATHFILE=/etc/config/qpkg.conf
    readonly QPKG_PATH=$($GETCFG_CMD $QPKG_NAME Install_Path -f $APP_CENTER_CONFIG_PATHFILE)
    readonly QPKG_REPO_PATH=$QPKG_PATH/$QPKG_NAME
    readonly QPKG_VERSION=$($GETCFG_CMD $QPKG_NAME Version -f $APP_CENTER_CONFIG_PATHFILE)
    readonly SERVICE_STATUS_PATHFILE=/var/run/$QPKG_NAME.last.operation
    readonly SERVICE_LOG_PATHFILE=/var/log/$QPKG_NAME.log
    readonly OPKG_PATH=/opt/bin:/opt/sbin
    readonly APPARENT_PATH=/share/$($GETCFG_CMD SHARE_DEF defDownload -d Qdownload -f /etc/config/def_share.info)/$QPKG_NAME
    export PATH="$OPKG_PATH:$($SED_CMD "s|$OPKG_PATH||" <<< "$PATH")"
    [[ -n $PYTHON ]] && export PYTHONPATH=$PYTHON

    # application specific
    readonly AV_INIT_PATHFILE=/etc/init.d/antivirus.sh
    readonly AV_INIT_BACKUP_PATHFILE=/etc/init.d/antivirus.sh.bak
    readonly INSTALLED_RAM_KB=$($GREP_CMD MemTotal /proc/meminfo | cut -f2 -d':' | $SED_CMD 's|kB||;s| ||g')
    readonly MIN_RAM_KB=1578040

    if [[ $INSTALLED_RAM_KB -lt $MIN_RAM_KB ]]; then
        DisplayErrCommitAllLogs "ClamAV won't run on this NAS. Not enough RAM. :("
        exit 1
    fi

    if [[ -n $PYTHON ]]; then
        readonly LAUNCH_TARGET=$PYTHON
    elif [[ -n $TARGET_DAEMON ]]; then
        readonly LAUNCH_TARGET=$TARGET_DAEMON
    fi

    # all timeouts are in seconds
    readonly DAEMON_STOP_TIMEOUT=60
    readonly PORT_CHECK_TIMEOUT=60
    readonly GIT_APPEAR_TIMEOUT=300
    readonly LAUNCH_TARGET_APPEAR_TIMEOUT=30
    readonly PID_APPEAR_TIMEOUT=5

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
#    EnsureConfigFileExists
    [[ $(type -t DisableOpkgDaemonStart) = 'function' ]] && DisableOpkgDaemonStart
    LoadAppVersion

#     [[ ! -d $BACKUP_PATH ]] && mkdir -p "$BACKUP_PATH"

    return 0

    }

ShowHelp()
    {

    Display "$(ColourTextBrightWhite "$($BASENAME_CMD "$0")") ($QPKG_VERSION) a service control script for the $(FormatAsPackageName $QPKG_NAME) QPKG"
    Display
    Display "Usage: $0 [OPTION]"
    Display
    Display '[OPTION] may be any one of the following:'
    Display
    DisplayAsHelp 'start' "launch $(FormatAsPackageName $QPKG_NAME) if not already running."
    DisplayAsHelp 'stop' "shutdown $(FormatAsPackageName $QPKG_NAME) if running."
    DisplayAsHelp 'restart' "stop, then start $(FormatAsPackageName $QPKG_NAME)."
    DisplayAsHelp 'status' "check if $(FormatAsPackageName $QPKG_NAME) is still running. Returns \$? = 0 if running, 1 if not."
#     DisplayAsHelp 'backup' "backup the current $(FormatAsPackageName $QPKG_NAME) configuration to persistent storage."
#     DisplayAsHelp 'restore' "restore a previously saved configuration from persistent storage. $(FormatAsPackageName $QPKG_NAME) will be stopped, then restarted."
#     DisplayAsHelp 'reset-config' "delete the application configuration, databases and history. $(FormatAsPackageName $QPKG_NAME) will be stopped, then restarted."
#     [[ $(type -t ImportFromSAB2) = 'function' ]] && DisplayAsHelp 'import' "create a backup of an installed $(FormatAsPackageName SABnzbdplus) config and restore it into $(FormatAsPackageName $QPKG_NAME)."
#     [[ $(type -t CleanLocalClone) = 'function' ]] && DisplayAsHelp 'clean' "wipe the current local copy of $(FormatAsPackageName $QPKG_NAME), and download it again from remote source. Configuration will be retained."
    DisplayAsHelp 'log' 'display this service script runtime log.'
    DisplayAsHelp 'version' 'display the package version number.'
    Display

    }

StartQPKG()
    {

    IsError && return

    if [[ ! -e $AV_INIT_BACKUP_PATHFILE ]]; then
        cp "$AV_INIT_PATHFILE" "$AV_INIT_BACKUP_PATHFILE"

        # mod base references
        $SED_CMD -i 's|/usr/local/bin/clamscan|/opt/sbin/clamscan|' "$AV_INIT_PATHFILE"
        $SED_CMD -i 's|/usr/local/bin/freshclam|/opt/sbin/freshclam|' "$AV_INIT_PATHFILE"

        # disable dryrun. The new ClamAV engine (0.102.4) doesn't support the '--dryrun' or '--countfile=' options.
        # match second occurrence only. First one is used by Mcafee. Solution here: https://unix.stackexchange.com/a/403272
        $SED_CMD -i ':a;N;$!ba; s|/bin/sh -c "$AV_SCAN_PATH $DRY_RUN_OPTIONS --dryrun|#/bin/sh -c "$AV_SCAN_PATH $DRY_RUN_OPTIONS --dryrun|2' "$AV_INIT_PATHFILE"

        # mod 'clamscan' runtime options
        # match second occurrence only. First one is used by Mcafee.
        $SED_CMD -i ':a;N;$!ba; s|OPTIONS="$OPTIONS --countfile=/tmp/antivirous.job.$job_id.scanning"|OPTIONS="$OPTIONS --database=$ANTIVIRUS_CLAMAV"|2' "$AV_INIT_PATHFILE"

        # mod 'freshclam' runtime options
        $SED_CMD -i 's|$FRESHCLAM -u admin -l /tmp/.freshclam.log|$FRESHCLAM -u admin --config-file=$FRESHCLAM_CONFIG --datadir=$ANTIVIRUS_CLAMAV -l /tmp/.freshclam.log|' "$AV_INIT_PATHFILE"

        "$AV_INIT_PATHFILE" restart
    fi

    DisplayCommitToLog 'start package: OK'
    EnableThisQPKGIcon

    return 0

    }

StopQPKG()
    {

    IsError && return

    if [[ -e $AV_INIT_BACKUP_PATHFILE ]]; then
        mv "$AV_INIT_BACKUP_PATHFILE" "$AV_INIT_PATHFILE"

        "$AV_INIT_PATHFILE" restart
    fi

    DisplayCommitToLog 'stop package: OK'
    DisableThisQPKGIcon

    return 0

    }

#### customisable functions for this app appear below ###

BackupConfig()
    {

    CommitOperationToLog
    ExecuteAndLog 'update configuration backup' "$TAR_CMD --create --gzip --file=$BACKUP_PATHFILE --directory=$QPKG_REPO_PATH autoProcessMedia.cfg" log:everything

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
    ExecuteAndLog 'restore configuration backup' "$TAR_CMD --extract --gzip --file=$BACKUP_PATHFILE --directory=$QPKG_REPO_PATH" log:everything
    StartQPKG

    }

ResetConfig()
    {

    CommitOperationToLog

    StopQPKG
    ExecuteAndLog 'resetting configuration' "rm $QPKG_INI_PATHFILE" log:everything
    StartQPKG

    }

LoadAppVersion()
    {

    # Find the application's internal version number
    # creates a global var: $app_version
    # this is the installed application version (not the QPKG version)

    app_version=''

    [[ ! -e $APP_VERSION_PATHFILE ]] && return

    app_version=$($GREP_CMD '__version__ =' "$APP_VERSION_PATHFILE" | $SED_CMD 's|^.*"\(.*\)"|\1|')

    }

StatusQPKG()
    {

    IsNotError || return

    if IsNotDaemonActive; then
        DisableThisQPKGIcon
        return
    fi

#    LoadUIPorts qts
#    CheckPorts || SetError
    EnableThisQPKGIcon

    }

#### functions specific to this app appear below ###

#### optional functions for this app appear below ###

PullGitRepo()
    {

    # $1 = package name
    # $2 = URL to pull/clone from
    # $3 = remote branch or tag
    # $4 = remote depth: 'shallow' or 'single-branch'
    # $5 = local path to clone into

    [[ -z $1 || -z $2 || -z $3 || -z $4 || -z $5 ]] && return 1

    local -r QPKG_GIT_PATH="$5/$1"
    local -r GIT_HTTP_URL="$2"
    local -r GIT_HTTPS_URL=${GIT_HTTP_URL/http/git}
    local installed_branch=''
    local branch_switch=false
    [[ $4 = shallow ]] && local -r DEPTH=' --depth 1'
    [[ $4 = single-branch ]] && local -r DEPTH=' --single-branch'

    if [[ -d $QPKG_GIT_PATH/.git ]]; then
        installed_branch=$($GIT_CMD -C "$QPKG_GIT_PATH" branch | $GREP_CMD '^\*' | $SED_CMD 's|^\* ||')

        if [[ $installed_branch != "$3" ]]; then
            branch_switch=true
            DisplayCommitToLog "current git branch: $installed_branch, new git branch: $3"
            BackupConfig
            ExecuteAndLog 'new git branch was specified so clean local repository' "rm -r $QPKG_GIT_PATH"
        fi
    fi

    if [[ ! -d $QPKG_GIT_PATH/.git ]]; then
        ExecuteAndLog "clone $(FormatAsPackageName "$1") from remote repository" "$GIT_CMD clone --branch $3 $DEPTH -c advice.detachedHead=false $GIT_HTTPS_URL $QPKG_GIT_PATH || $GIT_CMD clone --branch $3 $DEPTH -c advice.detachedHead=false $GIT_HTTP_URL $QPKG_GIT_PATH"
    else
        ExecuteAndLog "update $(FormatAsPackageName "$1") from remote repository" "$GIT_CMD -C $QPKG_GIT_PATH reset --hard; $GIT_CMD -C $QPKG_GIT_PATH pull"
    fi

    installed_branch=$($GIT_CMD -C "$QPKG_GIT_PATH" branch | $GREP_CMD '^\*' | $SED_CMD 's|^\* ||')
    DisplayCommitToLog "current git branch: $installed_branch"

    [[ $branch_switch = true ]] && RestoreConfig

    return 0

    }

CleanLocalClone()
    {

    # for occasions where the local repo needs to be deleted and cloned again from source.

    CommitOperationToLog

    if [[ -z $QPKG_PATH || -z $QPKG_NAME || -z $SOURCE_GIT_URL ]]; then
        SetError
        return 1
    fi

    StopQPKG
    ExecuteAndLog 'clean local repository' "rm -r $QPKG_REPO_PATH"
    StartQPKG

    }

#### end of optional functions

IsQNAP()
    {

    # is this a QNAP NAS?

    if [[ ! -e /etc/init.d/functions ]]; then
        Display 'QTS functions missing (is this a QNAP NAS?)'
        SetError
        return 1
    fi

    return 0

    }

WaitForGit()
    {

    if WaitForFileToAppear "$GIT_CMD" "$GIT_APPEAR_TIMEOUT"; then
        export PATH="$OPKG_PATH:$($SED_CMD "s|$OPKG_PATH||" <<< "$PATH")"
        return 0
    else
        return 1
    fi

    }

WaitForLaunchTarget()
    {

    if WaitForFileToAppear "$LAUNCH_TARGET" "$LAUNCH_TARGET_APPEAR_TIMEOUT"; then
        return 0
    else
        return 1
    fi

    }

WaitForPID()
    {

    if WaitForFileToAppear "$DAEMON_PID_PATHFILE" "$PID_APPEAR_TIMEOUT"; then
        sleep 1       # wait one more second to allow file to have PID written into it
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
                    Display 'OK'
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

    if IsNotConfigFound && IsDefaultConfigFound; then
        DisplayCommitToLog 'no configuration file found: using default'
        cp "$QPKG_INI_DEFAULT_PATHFILE" "$QPKG_INI_PATHFILE"
    fi

    }

SaveAppVersion()
    {

    echo "$app_version" > "$APP_VERSION_STORE_PATHFILE"

    }

ViewLog()
    {

    if [[ -e $SERVICE_LOG_PATHFILE ]]; then
        if [[ -e $GNU_LESS_CMD ]]; then
            LESSSECURE=1 $GNU_LESS_CMD +G --quit-on-intr --tilde --LINE-NUMBERS --prompt ' use arrow-keys to scroll up-down left-right, press Q to quit' "$SERVICE_LOG_PATHFILE"
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
    # $3 'log:everything' (optional) - if specified, the result of the command is recorded in the QTS system log.
    #                                - if unspecified, only warnings are logged in the QTS system log.

    if [[ -z $1 || -z $2 ]]; then
        SetError
        return 1
    fi

    local exec_msgs=''
    local result=0
    local returncode=0

    DisplayWaitCommitToLog "$1:"
    exec_msgs=$(eval "$2" 2>&1)
    result=$?

    if [[ $result = 0 ]]; then
        DisplayCommitToLog 'OK'
        [[ $3 = log:everything ]] && CommitInfoToSysLog "$1: OK."
    else
        DisplayCommitToLog 'failed!'
        DisplayCommitToLog "$(FormatAsFuncMessages "$exec_msgs")"
        DisplayCommitToLog "$(FormatAsResult $result)"
        CommitWarnToSysLog "A problem occurred while $1. Check $(FormatAsFileName "$SERVICE_LOG_PATHFILE") for more details."
        returncode=1
    fi

    return $returncode

    }

IsQPKGEnabled()
    {

    # input:
    #   $1 = package name to check

    # output:
    #   $? = 0 (true) or 1 (false)

    [[ $($GETCFG_CMD "$1" Enable -u -f $APP_CENTER_CONFIG_PATHFILE) = 'TRUE' ]]

    }

IsNotQPKGEnabled()
    {

    # input:
    #   $1 = package name to check

    # output:
    #   $? = 0 (true) or 1 (false)

    ! IsQPKGEnabled "$1"

    }

EnableThisQPKGIcon()
    {

    EnableQPKG "$QPKG_NAME"

    }

DisableThisQPKGIcon()
    {

    DisableQPKG "$QPKG_NAME"

    }

EnableQPKG()
    {

    # $1 = package name to enable

    IsNotQPKGEnabled "$1" && ExecuteAndLog 'enable QPKG icon' "qpkg_service enable $1"
    $SETCFG_CMD "$QPKG_NAME" Status complete -f "$APP_CENTER_CONFIG_PATHFILE"

    }

DisableQPKG()
    {

    IsQPKGEnabled "$QPKG_NAME" && ExecuteAndLog 'disable QPKG icon' "qpkg_service disable $1"

    }

IsDaemonActive()
    {

    # $? = 0 : package is 'started'
    # $? = 1 : package is 'stopped'

    if [[ -L $APPARENT_PATH ]]; then
        DisplayCommitToLog "package: IS active"
        return
    fi

    DisplayCommitToLog 'package: NOT active'
    [[ -f $DAEMON_PID_PATHFILE ]] && rm "$DAEMON_PID_PATHFILE"
    return 1

    }

IsNotDaemonActive()
    {

    # $? = 1 if $QPKG_NAME is active
    # $? = 0 if $QPKG_NAME is not active

    ! IsDaemonActive

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

SetServiceOperation()
    {

    service_operation="$1"

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

    [[ $service_operation = restart ]]

    }

IsNotRestart()
    {

    ! IsRestart

    }

IsNotRestore()
    {

    ! [[ $service_operation = restore ]]

    }

IsNotLog()
    {

    ! [[ $service_operation = log ]]

    }

IsClean()
    {

    [[ $service_operation = clean ]]

    }

IsNotClean()
    {

    ! IsClean

    }

IsRestore()
    {

    [[ $service_operation = restore ]]

    }

IsNotRestore()
    {

    ! IsRestore

    }

IsReset()
    {

    [[ $service_operation = 'reset-config' ]]

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

    printf "  --%-12s  %s\n" "$1" "$2"

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

    CommitLog "$(SessionSeparator "datetime:'$(date)',request:'$service_operation',QPKG:'$QPKG_VERSION',app:'$app_version'")"

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

    $WRITE_LOG_CMD "[$QPKG_NAME] $1" "$2"

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

    [[ $1 -ne 1 ]] && echo 's'

    }

Init

if IsNotError; then
    case $1 in
        start|--start)
            SetServiceOperation "$1"
            # ensure those still on SickBeard.py are using the updated repo
            if [[ ! -e $TARGET_SCRIPT_PATHFILE && -e $($DIRNAME_CMD "$TARGET_SCRIPT_PATHFILE")/SickBeard.py ]]; then
                CleanLocalClone
            else
                StartQPKG || SetError
            fi
            ;;
        stop|--stop)
            SetServiceOperation "$1"
            StopQPKG || SetError
            ;;
        r|-r|restart|--restart)
            SetServiceOperation restart
            { StopQPKG; StartQPKG ;} || SetError
            ;;
        s|-s|status|--status)
            SetServiceOperation status
            StatusQPKG || SetError
            ;;
        b|-b|backup|--backup)
            SetServiceOperation backup
            BackupConfig || SetError
            ;;
        reset-config|--reset-config)
            SetServiceOperation "$1"
            ResetConfig || SetError
            ;;
        restore|--restore)
            SetServiceOperation "$1"
            RestoreConfig || SetError
            ;;
        c|-c|clean|--clean)
            if [[ $(type -t CleanLocalClone) = 'function' ]]; then
                SetServiceOperation clean

                if [[ $($DIRNAME_CMD "$QPKG_INI_PATHFILE") = "$QPKG_REPO_PATH" ]]; then
                    # nzbToMedia stores the config file in the repo location, so save it and restore again after new clone is complete
                    { BackupConfig; CleanLocalClone; RestoreConfig ;} || SetError
                else
                    CleanLocalClone || SetError
                fi
            else
                SetServiceOperation none
                ShowHelp
            fi
            ;;
        l|-l|log|--log)
            SetServiceOperation log
            ViewLog
            ;;
        v|-v|version|--version)
            SetServiceOperation version
            Display "$QPKG_VERSION"
            ;;
        import|--import)
            if [[ $(type -t ImportFromSAB2) = 'function' ]]; then
                SetServiceOperation "$1"
                ImportFromSAB2 || SetError
            else
                SetServiceOperation none
                ShowHelp
            fi
            ;;
        *)
            SetServiceOperation none
            ShowHelp
            ;;
    esac
fi

if IsError; then
    SetServiceOperationResultFailed
    exit 1
fi

SetServiceOperationResultOK
exit
