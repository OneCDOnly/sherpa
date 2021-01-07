#!/usr/bin/env bash
####################################################################################
# otransmission.sh
#
# Copyright (C) 2020-2021 OneCD [one.cd.only@gmail.com]
#
# so, blame OneCD if it all goes horribly wrong. ;)
#
# For more info: https://forum.qnap.com/viewtopic.php?f=320&t=132373
####################################################################################

Init()
    {

    IsQNAP || return 1

    # specific environment
    readonly QPKG_NAME=OTransmission
    readonly TARGET_DAEMON=/opt/bin/transmission-daemon
    readonly ORIG_DAEMON_SERVICE_SCRIPT=/opt/etc/init.d/S88transmission
    readonly TRANSMISSION_WEB_HOME=/opt/share/transmission/web

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
    local -r OPKG_PATH=/opt/bin:/opt/sbin
    local -r BACKUP_PATH=$($GETCFG_CMD SHARE_DEF defVolMP -f /etc/config/def_share.info)/.qpkg_config_backup
    readonly BACKUP_PATHFILE=$BACKUP_PATH/$QPKG_NAME.config.tar.gz
    readonly APPARENT_PATH=/share/$($GETCFG_CMD SHARE_DEF defDownload -d Qdownload -f /etc/config/def_share.info)/$QPKG_NAME
    export PATH="$OPKG_PATH:$($SED_CMD "s|$OPKG_PATH||" <<< "$PATH")"
    [[ -n $PYTHON ]] && export PYTHONPATH=$PYTHON

    # application specific
    readonly QPKG_INI_PATHFILE=$QPKG_PATH/config/settings.json
    readonly QPKG_INI_DEFAULT_PATHFILE=$QPKG_INI_PATHFILE.def
    readonly DAEMON_PID_PATHFILE=/var/run/$QPKG_NAME.pid
    readonly APP_VERSION_PATHFILE=''
    readonly APP_VERSION_STORE_PATHFILE=$($DIRNAME_CMD "$APP_VERSION_PATHFILE")/version.stored
    readonly TARGET_SCRIPT_PATHFILE=''
    readonly LAUNCHER="$TARGET_DAEMON --config-dir $($DIRNAME_CMD "$QPKG_INI_PATHFILE") --pid-file $DAEMON_PID_PATHFILE"

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
    EnsureConfigFileExists
    [[ $(type -t DisableOpkgDaemonStart) = 'function' ]] && DisableOpkgDaemonStart
    LoadAppVersion

    [[ ! -d $BACKUP_PATH ]] && mkdir -p "$BACKUP_PATH"

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
    DisplayAsHelp 'backup' "backup the current $(FormatAsPackageName $QPKG_NAME) configuration to persistent storage."
    DisplayAsHelp 'restore' "restore a previously saved configuration from persistent storage. $(FormatAsPackageName $QPKG_NAME) will be stopped, then restarted."
    DisplayAsHelp 'reset-config' "delete the application configuration, databases and history. $(FormatAsPackageName $QPKG_NAME) will be stopped, then restarted."
    [[ $(type -t ImportFromSAB2) = 'function' ]] && DisplayAsHelp 'import' "create a backup of an installed $(FormatAsPackageName SABnzbdplus) config and restore it into $(FormatAsPackageName $QPKG_NAME)."
    [[ $(type -t CleanLocalClone) = 'function' ]] && DisplayAsHelp 'clean' "wipe the current local copy of $(FormatAsPackageName $QPKG_NAME), and download it again from remote source. Configuration will be retained."
    DisplayAsHelp 'log' 'display this service script runtime log.'
    DisplayAsHelp 'version' 'display the package version number.'
    Display

    }

StartQPKG()
    {

    IsError && return

    if IsNotRestart && IsNotRestore && IsNotClean && IsNotReset; then
        CommitOperationToLog
        IsDaemonActive && return
    fi

    if [[ -z $DAEMON_PID_PATHFILE ]]; then  # nzbToMedia: when cleaning, ignore restart and start anyway to create repo and restore config
        if IsRestore || IsReset; then
            IsNotRestartPending && return
        fi
    else
        if IsRestore || IsClean || IsReset; then
            IsNotRestartPending && return
        fi
    fi

    [[ $(type -t WaitForGit) = 'function' ]] && { WaitForGit || return 1 ;}
    [[ $(type -t PullGitRepo) = 'function' ]] && PullGitRepo "$QPKG_NAME" "$SOURCE_GIT_URL" "$SOURCE_GIT_BRANCH" "$SOURCE_GIT_DEPTH" "$QPKG_PATH"

    WaitForLaunchTarget || return 1
    [[ $(type -t UpdateLanguages) = 'function' ]] && UpdateLanguages

    EnsureConfigFileExists
    LoadUIPorts app || return

    if [[ $ui_port -le 0 && $ui_port_secure -le 0 ]]; then
        DisplayErrCommitAllLogs 'unable to start daemon: no UI port was specified!'
        return 1
    elif IsNotPortAvailable $ui_port || IsNotPortAvailable $ui_port_secure; then
        DisplayErrCommitAllLogs "unable to start daemon: ports $ui_port or $ui_port_secure are already in use!"
        return 1
    fi

    ExecuteAndLog 'start daemon' "$LAUNCHER" log:everything || return 1
    WaitForPID || return 1
    IsDaemonActive || return 1
    CheckPorts || return 1
    EnableThisQPKGIcon

    return 0

    }

StopQPKG()
    {

    IsError && return

    if IsNotRestore && IsNotClean && IsNotReset; then
        CommitOperationToLog
    fi

    IsNotDaemonActive && return

    if IsRestart || IsRestore || IsClean || IsReset; then
        SetRestartPending
    fi

    local acc=0
    local pid=0
    SetRestartPending

    killall "$($BASENAME_CMD "$TARGET_DAEMON")"
    DisplayWaitCommitToLog 'stop daemon with SIGTERM:'
    DisplayWait "(no-more than $DAEMON_STOP_TIMEOUT seconds):"

    while true; do
        while (ps ax | $GREP_CMD $TARGET_DAEMON | $GREP_CMD -vq grep); do
            sleep 1
            ((acc++))
            DisplayWait "$acc,"

            if [[ $acc -ge $DAEMON_STOP_TIMEOUT ]]; then
                DisplayCommitToLog 'failed!'
                DisplayCommitToLog 'stop daemon with SIGKILL'
                killall -9 "$($BASENAME_CMD "$TARGET_DAEMON")"
                [[ -f $DAEMON_PID_PATHFILE ]] && rm -f $DAEMON_PID_PATHFILE
                break 2
            fi
        done

        [[ -f $DAEMON_PID_PATHFILE ]] && rm -f $DAEMON_PID_PATHFILE
        Display 'OK'
        CommitLog "stopped OK in $acc seconds"

        CommitInfoToSysLog "stop daemon: OK."
        break
    done

    IsNotDaemonActive || return 1
    DisableThisQPKGIcon

    return 0

    }

#### customisable functions for this app appear below ###

BackupConfig()
    {

    CommitOperationToLog
    ExecuteAndLog 'update configuration backup' "$TAR_CMD --create --gzip --file=$BACKUP_PATHFILE --directory=$QPKG_PATH/config ." log:everything

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
    ExecuteAndLog 'restore configuration backup' "$TAR_CMD --extract --gzip --file=$BACKUP_PATHFILE --directory=$QPKG_PATH/config" log:everything
    StartQPKG

    }

ResetConfig()
    {

    CommitOperationToLog

    StopQPKG
    ExecuteAndLog 'reset configuration' "mv $QPKG_INI_DEFAULT_PATHFILE $QPKG_PATH; rm -rf $QPKG_PATH/config/*; mv $QPKG_PATH/$($BASENAME_CMD "$QPKG_INI_DEFAULT_PATHFILE") $QPKG_INI_DEFAULT_PATHFILE" log:everything
    StartQPKG

    }

LoadUIPorts()
    {

    # If user changes ports via app UI, must first 'stop' application on old ports, then 'start' on new ports

    case $1 in
        app)
            # Read the current application UI ports from application configuration
            DisplayWaitCommitToLog 'load UI ports from application:'
            ui_port=$($JQ_CMD -r '."rpc-port"' < "$QPKG_INI_PATHFILE")
            # Transmission doesn't appear to contain any SSL UI ability, so ...
            ui_port_secure=0
            DisplayCommitToLog 'OK'
            ;;
        qts)
            # Read the current application UI ports from QTS App Center
            DisplayWaitCommitToLog 'load UI ports from QPKG icon:'
            ui_port=$($GETCFG_CMD $QPKG_NAME Web_Port -d 0 -f "$APP_CENTER_CONFIG_PATHFILE")
            ui_port_secure=$($GETCFG_CMD $QPKG_NAME Web_SSL_Port -d 0 -f "$APP_CENTER_CONFIG_PATHFILE")
            DisplayCommitToLog 'OK'
            ;;
        *)
            DisplayErrCommitAllLogs "unable to load UI ports: action '$1' unrecognised"
            SetError
            return 1
            ;;
    esac

    if [[ $ui_port -eq 0 ]] && IsNotDefaultConfigFound; then
        ui_port=0
        ui_port_secure=0
    fi

    # Always read this from the application configuration
    ui_listening_address=$($JQ_CMD -r '."rpc-bind-address"' < "$QPKG_INI_PATHFILE")

    return 0

    }

IsSSLEnabled()
    {

    # Transmission doesn't appear to contain any SSL UI ability, so ...
    false

    }

LoadAppVersion()
    {

    # Find the application's internal version number
    # creates a global var: $app_version
    # this is the installed application version (not the QPKG version)

    app_version=''

    [[ ! -e $TARGET_DAEMON ]] && return 1

    app_version=$($TARGET_DAEMON --version 2>&1 | $SED_CMD 's|transmission-daemon ||')

    }

StatusQPKG()
    {

    IsNotError || return

    if IsNotDaemonActive; then
        DisableThisQPKGIcon
        return
    fi

    LoadUIPorts qts
    CheckPorts || SetError
    EnableThisQPKGIcon

    }

#### functions specific to this app appear below ###

#### optional functions for this app appear below ###

DisableOpkgDaemonStart()
    {

    if [[ -n $ORIG_DAEMON_SERVICE_SCRIPT && -x $ORIG_DAEMON_SERVICE_SCRIPT ]]; then
        $ORIG_DAEMON_SERVICE_SCRIPT stop        # stop default daemon
        chmod -x $ORIG_DAEMON_SERVICE_SCRIPT    # ... and ensure Entware doesn't re-launch it on startup
    fi

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

ReWriteUIPorts()
    {

    # Write the current application UI ports into the QTS App Center configuration

    # QTS App Center requires 'Web_Port' to always be non-zero

    # 'Web_SSL_Port' behaviour:
    #            < -2 = crashes current QTS session. Starts with non-responsive package icons in App Center
    #   missing or -2 = QTS will fallback from HTTPS to HTTP, with a warning to user
    #              -1 = launch QTS UI again (only if WebUI = '/'), else show "QNAP Error" page
    #               0 = "unable to connect"
    #             > 0 = works if logged-in to QTS UI via HTTPS

    # If SSL is enabled, attempting to access with non-SSL via 'Web_Port' results in "connection was reset"

    DisplayWaitCommitToLog 'update QPKG icon with UI ports:'

    $SETCFG_CMD $QPKG_NAME Web_Port "$ui_port" -f $APP_CENTER_CONFIG_PATHFILE

    if IsSSLEnabled; then
        $SETCFG_CMD $QPKG_NAME Web_SSL_Port "$ui_port_secure" -f $APP_CENTER_CONFIG_PATHFILE
    else
        $SETCFG_CMD $QPKG_NAME Web_SSL_Port '-2' -f $APP_CENTER_CONFIG_PATHFILE
    fi

    DisplayCommitToLog 'OK'

    }

CheckPorts()
    {

    local msg=''

    DisplayCommitToLog "daemon listening address: $ui_listening_address"

    if IsSSLEnabled && IsPortSecureResponds $ui_port_secure; then
        msg="HTTPS port $ui_port_secure"
    fi

    if IsNotSSLEnabled || [[ $ui_port -ne $ui_port_secure ]]; then
        # assume $ui_port should be checked too
        if IsPortResponds $ui_port; then
            if [[ -n $msg ]]; then
                msg+=" and HTTP port $ui_port"
            else
                msg="HTTP port $ui_port"
            fi
        fi
    fi

    if [[ -z $msg ]]; then
        DisplayErrCommitAllLogs 'no response on configured port(s)!'
        SetError
        return 1
    fi

    DisplayCommitToLog "$msg: OK"
    ReWriteUIPorts

    return 0

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

IsNotSSLEnabled()
    {

    ! IsSSLEnabled

    }

IsDaemonActive()
    {

    # $? = 0 : $TARGET_DAEMON is in memory
    # $? = 1 : $TARGET_DAEMON is not in memory

    if [[ -e $DAEMON_PID_PATHFILE && -d /proc/$(<$DAEMON_PID_PATHFILE) && -n $TARGET_DAEMON && $(</proc/"$(<$DAEMON_PID_PATHFILE)"/cmdline) =~ $TARGET_DAEMON ]]; then
        DisplayCommitToLog 'daemon: IS active'
        DisplayCommitToLog "daemon PID: $(<$DAEMON_PID_PATHFILE)"
        return
    fi

    DisplayCommitToLog 'daemon: NOT active'
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

IsPortAvailable()
    {

    # $1 = port to check
    # $? = 0 if available
    # $? = 1 if already used

    [[ -z $1 || $1 -eq 0 ]] && return

    if ($LSOF_CMD -i :"$1" -sTCP:LISTEN >/dev/null 2>&1); then
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

    while ! $CURL_CMD --silent --fail --max-time 1 http://localhost:"$1" >/dev/null; do
        sleep 1
        ((acc+=2))
        DisplayWait "$acc,"

        if [[ $acc -ge $PORT_CHECK_TIMEOUT ]]; then
            DisplayCommitToLog 'failed!'
            CommitErrToSysLog "UI port $1 failed to respond after $acc seconds"
            return 1
        fi
    done

    Display 'OK'
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

    while ! $CURL_CMD --silent --insecure --fail --max-time 1 https://localhost:"$1" >/dev/null; do
        sleep 1
        ((acc+=2))
        DisplayWait "$acc,"

        if [[ $acc -ge $PORT_CHECK_TIMEOUT ]]; then
            DisplayCommitToLog 'failed!'
            CommitErrToSysLog "secure UI port $1 failed to respond after $acc seconds"
            return 1
        fi
    done

    Display 'OK'
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
