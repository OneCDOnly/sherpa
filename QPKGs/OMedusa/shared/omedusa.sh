#!/usr/bin/env bash
####################################################################################
# omedusa.sh
#
# Copyright (C) 2018-2020 OneCD [one.cd.only@gmail.com]
#
# so, blame OneCD if it all goes horribly wrong. ;)
#
# For more info: https://forum.qnap.com/viewtopic.php?f=320&t=132373
####################################################################################

Init()
    {

    # specific environment
        readonly QPKG_NAME=OMedusa

    # for Python-based remote apps
        readonly SOURCE_GIT_URL=http://github.com/pymedusa/Medusa.git
        readonly SOURCE_GIT_BRANCH=master
        # 'shallow' (depth 1) or 'single-branch' (note: 'shallow' implies a 'single-branch' too)
        readonly SOURCE_GIT_DEPTH=shallow
        readonly PYTHON=/opt/bin/python3
        local -r TARGET_SCRIPT=start.py

    if [[ ! -e /etc/init.d/functions ]]; then
        FormatAsDisplayError 'QTS functions missing (is this a QNAP NAS?)'
        SetError
        return 1
    fi

    # cherry-pick required binaries
    readonly BASENAME_CMD=/usr/bin/basename
    readonly CURL_CMD=/sbin/curl
    readonly DIRNAME_CMD=/usr/bin/dirname
    readonly GETCFG_CMD=/sbin/getcfg
    readonly GREP_CMD=/bin/grep
    readonly GNU_LESS_CMD=/opt/bin/less
    readonly LSOF_CMD=/usr/sbin/lsof
    readonly SED_CMD=/bin/sed
    readonly SETCFG_CMD=/sbin/setcfg
    readonly TAR_CMD=/bin/tar
    readonly TAIL_CMD=/usr/bin/tail
    readonly TEE_CMD=/usr/bin/tee
    readonly WRITE_LOG_CMD=/sbin/write_log

    # generic environment
    readonly QTS_QPKG_CONF_PATHFILE=/etc/config/qpkg.conf
    readonly QPKG_PATH=$($GETCFG_CMD $QPKG_NAME Install_Path -f $QTS_QPKG_CONF_PATHFILE)
    readonly QPKG_REPO_PATH=$QPKG_PATH/$QPKG_NAME
    readonly QPKG_VERSION=$($GETCFG_CMD $QPKG_NAME Version -f $QTS_QPKG_CONF_PATHFILE)
    readonly QPKG_INI_PATHFILE=$QPKG_PATH/config/config.ini
    local -r QPKG_INI_DEFAULT_PATHFILE=$QPKG_INI_PATHFILE.def
    readonly SERVICE_STATUS_PATHFILE=/var/run/$QPKG_NAME.last.operation
    readonly SERVICE_LOG_PATHFILE=/var/log/$QPKG_NAME.log
    readonly DAEMON_PID_PATHFILE=/var/run/$QPKG_NAME.pid
    local -r OPKG_PATH=/opt/bin:/opt/sbin
    local -r BACKUP_PATH=$($GETCFG_CMD SHARE_DEF defVolMP -f /etc/config/def_share.info)/.qpkg_config_backup
    readonly BACKUP_PATHFILE=$BACKUP_PATH/$QPKG_NAME.config.tar.gz
    [[ -n $PYTHON ]] && export PYTHONPATH=$PYTHON
    [[ $PATH =~ $OPKG_PATH ]] && export PATH="$OPKG_PATH:$PATH"
    readonly STOP_TIMEOUT=60
    readonly PORT_CHECK_TIMEOUT=20
    ui_port=0
    ui_port_secure=0
    ui_listening_address=''

    # application-specific
    readonly APP_VERSION_PATHFILE=$QPKG_REPO_PATH/medusa/version.py
    readonly APP_VERSION_STORE_PATHFILE=$($DIRNAME_CMD "$APP_VERSION_PATHFILE")/version.stored
    readonly TARGET_SCRIPT_PATHFILE=$QPKG_REPO_PATH/$TARGET_SCRIPT

    if [[ -z $LANG ]]; then
        export LANG=en_US.UTF-8
        export LC_ALL=en_US.UTF-8
        export LC_CTYPE=en_US.UTF-8
    fi

    UnsetError

    # specific launch arguments
    if [[ -n $PYTHON && -n $TARGET_SCRIPT ]]; then
        readonly LAUNCHER="cd $QPKG_REPO_PATH; $PYTHON $TARGET_SCRIPT_PATHFILE --daemon --nolaunch --datadir $($DIRNAME_CMD "$QPKG_INI_PATHFILE") --config $QPKG_INI_PATHFILE --pidfile $DAEMON_PID_PATHFILE"
    else
        DisplayErrCommitAllLogs 'found nothing to launch!'
        SetError
        return 1
    fi

    WaitForEntware

    if IsNotConfigFound && IsDefaultConfigFound; then
        DisplayWarnCommitToLog 'no configuration file found: using default'
        cp "$QPKG_INI_DEFAULT_PATHFILE" "$QPKG_INI_PATHFILE"
    fi

    LoadAppVersion

    [[ ! -d $BACKUP_PATH ]] && mkdir -p "$BACKUP_PATH"

    return 0

    }

ShowHelp()
    {

    Display " $($BASENAME_CMD "$0") ($QPKG_VERSION)"
    Display " A service control script for the $(FormatAsPackageName $QPKG_NAME) QPKG"
    Display
    Display " Usage: $0 [OPTION]"
    Display
    Display ' [OPTION] can be any one of the following:'
    Display
    Display " start      - launch $(FormatAsPackageName $QPKG_NAME) if not already running."
    Display " stop       - shutdown $(FormatAsPackageName $QPKG_NAME) if running."
    Display " restart    - stop, then start $(FormatAsPackageName $QPKG_NAME)."
    Display " status     - check if $(FormatAsPackageName $QPKG_NAME) is still running. Returns \$? = 0 if running, 1 if not."
    Display " backup     - backup the current $(FormatAsPackageName $QPKG_NAME) configuration to persistent storage."
    Display " restore    - restore a previously saved configuration from persistent storage. $(FormatAsPackageName $QPKG_NAME) will be stopped, then restarted."
    [[ -n $SOURCE_GIT_URL ]] && Display " clean      - wipe the current local copy of $(FormatAsPackageName $QPKG_NAME), and download it again from remote source. Configuration will be retained."
    Display ' log        - display this service script runtime log.'
    Display ' version    - display the package version number.'
    Display

    }

StartQPKG()
    {

    IsNotError || return

    if IsNotRestart && IsNotRestore && IsNotClean; then
        RecordOperationToLog
        IsNotDaemonActive || return
    fi

    [[ -n $SOURCE_GIT_URL ]] && PullGitRepo $QPKG_NAME "$SOURCE_GIT_URL" "$SOURCE_GIT_BRANCH" "$SOURCE_GIT_DEPTH" "$QPKG_PATH"

    LoadUIPorts app || return

    if [[ $ui_port -le 0 && $ui_port_secure -le 0 ]]; then
        DisplayErrCommitAllLogs 'unable to start daemon: no UI port was specified!'
        SetError
        return 1
    elif IsNotPortAvailable $ui_port || IsNotPortAvailable $ui_port_secure; then
        DisplayErrCommitAllLogs "unable to start daemon: ports $ui_port or $ui_port_secure are already in use!"
        SetError
        return 1
    fi

    ExecuteAndLog 'starting daemon' "$LAUNCHER" log:everything || return 1
    [[ -n $TARGET_SCRIPT || -n $TARGET_DAEMON ]] && ExecuteAndLog 'waiting for PID file to be created' 'sleep 5'
    IsDaemonActive || return 1
    CheckPorts || return 1

    return 0

    }

StopQPKG()
    {

    IsNotError || return

    if IsNotRestore && IsNotClean; then
        RecordOperationToLog
    fi

    IsDaemonActive || return

    local acc=0
    local pid=0

    pid=$(<$DAEMON_PID_PATHFILE)
    kill "$pid"
    DisplayWaitCommitToLog '* stopping daemon with SIGTERM:'
    DisplayWait "(no-more than $STOP_TIMEOUT seconds):"

    while true; do
        while [[ -d /proc/$pid ]]; do
            sleep 1
            ((acc++))
            DisplayWait "$acc,"

            if [[ $acc -ge $STOP_TIMEOUT ]]; then
                DisplayCommitToLog 'failed!'
                DisplayCommitToLog '* stopping daemon with SIGKILL'
                kill -9 "$pid" 2> /dev/null
                [[ -f $DAEMON_PID_PATHFILE ]] && rm -f $DAEMON_PID_PATHFILE
                break 2
            fi
        done

        [[ -f $DAEMON_PID_PATHFILE ]] && rm -f $DAEMON_PID_PATHFILE
        Display 'OK'
        CommitLog "stopped OK in $acc seconds"

        CommitInfoToSysLog "stopping daemon: OK."
        break
    done

    IsNotDaemonActive || return 1

    }

StatusQPKG()
    {

    IsNotError || return
    IsDaemonActive || return
    LoadUIPorts qts
    CheckPorts || SetError

    }

#### functions specific to this app appear below ###

BackupConfig()
    {

    RecordOperationToLog
    ExecuteAndLog 'updating configuration backup' "$TAR_CMD --create --gzip --file=$BACKUP_PATHFILE --directory=$QPKG_PATH/config ." log:everything

    }

RestoreConfig()
    {

    RecordOperationToLog

    if [[ ! -f $BACKUP_PATHFILE ]]; then
        DisplayErrCommitAllLogs 'unable to restore configuration: no backup file was found!'
        SetError
        return 1
    fi

    StopQPKG
    ExecuteAndLog 'restoring configuration backup' "$TAR_CMD --extract --gzip --file=$BACKUP_PATHFILE --directory=$QPKG_PATH/config" log:everything
    StartQPKG

    }

LoadUIPorts()
    {

    # If user changes ports via app UI, must first 'stop' application on old ports, then 'start' on new ports

    case $1 in
        app)
            # Read the current application UI ports from application configuration
            ui_port=$($GETCFG_CMD general web_port -d 0 -f "$QPKG_INI_PATHFILE")
            ui_port_secure=$($GETCFG_CMD general web_port -d 0 -f "$QPKG_INI_PATHFILE")
            ;;
        qts)
            # Read the current application UI ports from QTS App Center
            ui_port=$($GETCFG_CMD $QPKG_NAME Web_Port -d 0 -f "$QTS_QPKG_CONF_PATHFILE")
            ui_port_secure=$($GETCFG_CMD $QPKG_NAME Web_SSL_Port -d 0 -f "$QTS_QPKG_CONF_PATHFILE")
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
    ui_listening_address=$($GETCFG_CMD general web_host -f "$QPKG_INI_PATHFILE")

    }

IsSSLEnabled()
    {

    [[ $($GETCFG_CMD general enable_https -d 0 -f "$QPKG_INI_PATHFILE") -eq 1 ]]

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

#### functions specific to this app appear above ###

SaveAppVersion()
    {

    echo "$app_version" > "$APP_VERSION_STORE_PATHFILE"

    }

PullGitRepo()
    {

    # $1 = package name
    # $2 = URL to pull/clone from
    # $3 = remote branch or tag
    # $4 = remote depth: 'shallow' or 'single-branch'
    # $5 = local path to clone into

    [[ -z $1 || -z $2 || -z $3 || -z $4 || -z $5 ]] && return 1

    local -r GIT_CMD=/opt/bin/git

    if IsNotSysFilePresent "$GIT_CMD"; then
        SetError
        return 1
    fi

    local QPKG_GIT_PATH="$5/$1"
    local GIT_HTTP_URL="$2"
    local GIT_HTTPS_URL=${GIT_HTTP_URL/http/git}
    [[ $4 = shallow ]] && local depth=' --depth 1'
    [[ $4 = single-branch ]] && local depth=' --single-branch'

    if [[ ! -d ${QPKG_GIT_PATH}/.git ]]; then
        ExecuteAndLog "cloning $(FormatAsPackageName "$1") from remote repository" "$GIT_CMD clone --branch $3 $depth -c advice.detachedHead=false $GIT_HTTPS_URL $QPKG_GIT_PATH || $GIT_CMD clone --branch $3 $depth -c advice.detachedHead=false $GIT_HTTP_URL $QPKG_GIT_PATH"
    else
        ExecuteAndLog "updating $(FormatAsPackageName "$1") from remote repository" "$GIT_CMD -C $QPKG_GIT_PATH pull"
    fi

    }

CleanLocalClone()
    {

    # for the rare occasions the local repo becomes corrupt, it needs to be deleted and cloned again from source.

    RecordOperationToLog

    if [[ -z $QPKG_PATH || -z $QPKG_NAME || -z $SOURCE_GIT_URL ]]; then
        SetError
        return 1
    fi

    StopQPKG
    ExecuteAndLog 'cleaning local repo' "rm -r $QPKG_REPO_PATH"
    StartQPKG

    }

ViewLog()
    {

    if [[ -e $SERVICE_LOG_PATHFILE ]]; then
        LESSSECURE=1 $GNU_LESS_CMD +G --quit-on-intr --tilde --LINE-NUMBERS --prompt ' use arrow-keys to scroll up-down left-right, press Q to quit' "$SERVICE_LOG_PATHFILE"
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

    DisplayWaitCommitToLog "* $1:"
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
    # 'Web_SSL_Port' behaviour: -1 (launch QTS UI again), 0 ("unable to connect") or > 0 (only works if logged-in to QTS UI via SSL)
    # If SSL is enabled, attempting to access with non-SSL via 'Web_Port' results in "connection was reset"

    $SETCFG_CMD $QPKG_NAME Web_Port "$ui_port" -f $QTS_QPKG_CONF_PATHFILE

    if IsSSLEnabled; then
        $SETCFG_CMD $QPKG_NAME Web_SSL_Port "$ui_port_secure" -f $QTS_QPKG_CONF_PATHFILE
    else
        $SETCFG_CMD $QPKG_NAME Web_SSL_Port 0 -f $QTS_QPKG_CONF_PATHFILE
    fi

    DisplayDoneCommitToLog 'App Center configuration updated with current port information'

    }

CheckPorts()
    {

    local msg=''

    DisplayDoneCommitToLog "daemon listening address: $ui_listening_address"

    if IsSSLEnabled && IsPortSecureResponds $ui_port_secure; then
        msg="$(FormatAsPackageName $QPKG_NAME) IS listening on HTTPS port $ui_port_secure"
    fi

    if IsNotSSLEnabled || [[ $ui_port -ne $ui_port_secure ]]; then
        # assume $ui_port should be checked too
        if IsPortResponds $ui_port; then
            if [[ -n $msg ]]; then
                msg+=" and on HTTP port $ui_port"
            else
                msg="$(FormatAsPackageName $QPKG_NAME) IS listening on HTTP port $ui_port"
            fi
        fi
    fi

    ReWriteUIPorts

    if [[ -z $msg ]]; then
        DisplayErrCommitAllLogs 'no response on configured port(s)!'
        SetError
        return 1
    fi

    DisplayDoneCommitToLog "$msg"

    return 0

    }

IsNotSSLEnabled()
    {

    ! IsSSLEnabled

    }

IsDaemonActive()
    {

    # $? = 0 : $TARGET_SCRIPT_PATHFILE is in memory
    # $? = 1 : $TARGET_SCRIPT_PATHFILE is not in memory

    if [[ -e $DAEMON_PID_PATHFILE && -d /proc/$(<$DAEMON_PID_PATHFILE) && -n $TARGET_SCRIPT_PATHFILE && $(</proc/"$(<$DAEMON_PID_PATHFILE)"/cmdline) =~ $TARGET_SCRIPT_PATHFILE ]]; then
        DisplayDoneCommitToLog "daemon IS active: PID $(<$DAEMON_PID_PATHFILE)"
        return
    fi

    DisplayDoneCommitToLog 'daemon NOT active'
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
        FormatAsDisplayError "A required NAS system file is missing: $(FormatAsFileName "$1")"
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

    if [[ -z $1 || $1 -eq 0 ]]; then
        SetError
        return 1
    fi

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
    # $? = 0 if already used or unspecified

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

    DisplayWaitCommitToLog "* checking for UI port $1 response:"
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

    DisplayWaitCommitToLog "* checking for secure UI port $1 response:"
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

SetError()
    {

    IsError && return

    error_flag=true

    }

UnsetError()
    {

    IsNotError && return

    error_flag=false

    }

IsError()
    {

    [[ $error_flag = true ]]

    }

IsNotError()
    {

    [[ $error_flag = false ]]

    }

IsNotRestart()
    {

    ! [[ $service_operation = restart ]]

    }

IsNotRestore()
    {

    ! [[ $service_operation = restore ]]

    }

IsNotLog()
    {

    ! [[ $service_operation = log ]]

    }

IsNotClean()
    {

    ! [[ $service_operation = clean ]]

    }

IsNotStatus()
    {

    ! [[ $service_operation = status ]]

    }

DisplayDoneCommitToLog()
    {

    DisplayCommitToLog "$(FormatAsDisplayDone "$1")"

    }

DisplayWarnCommitToLog()
    {

    DisplayCommitToLog "$(FormatAsDisplayWarn "$1")"

    }

DisplayErrCommitAllLogs()
    {

    DisplayErrCommitToLog "$1"
    CommitErrToSysLog "$1"

    }

DisplayErrCommitToLog()
    {

    DisplayCommitToLog "$(FormatAsDisplayError "$1")"

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

    FormatAsDisplayDone "output: \"$1\""

    }

FormatAsResult()
    {

    FormatAsDisplayDone "result: $(FormatAsExitcode "$1")"

    }

FormatAsFuncMessages()
    {

    echo "= ${FUNCNAME[1]}()"
    FormatAsStdout "$1"

    }

FormatAsDisplayDone()
    {

    Display "= $1"

    }

FormatAsDisplayWarn()
    {

    Display "> $1"

    }

FormatAsDisplayError()
    {

    Display "! $1"

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

Display()
    {

    echo "$1"

    }

DisplayWait()
    {

    echo -n "$1 "

    }

RecordOperationToLog()
    {

    CommitLog "$(SessionSeparator "'$service_operation' requested")"
    CommitLog "= $(date), QPKG: $QPKG_VERSION, application: $app_version"

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

    printf '%0.s-' {1..20}; echo -n " $1 "; printf '%0.s-' {1..20}

    }

WaitForEntware()
    {

    local -r MAX_WAIT_SECONDS_ENTWARE=300

    if [[ ! -e /opt/Entware.sh && ! -e /opt/Entware-3x.sh && ! -e /opt/Entware-ng.sh ]]; then
        (
            for ((count=1; count<=MAX_WAIT_SECONDS_ENTWARE; count++)); do
                sleep 1
                [[ -e /opt/Entware.sh || -e /opt/Entware-3x.sh || -e /opt/Entware-ng.sh ]] && { CommitLog "waited for Entware for $count seconds"; true; exit ;}
            done
            false
        )

        if [[ $? -ne 0 ]]; then
            DisplayErrCommitAllLogs "Entware not found! (exceeded timeout: $MAX_WAIT_SECONDS_ENTWARE seconds)"
            false
            exit
        else
            # if here, then testfile has appeared, so reload environment
            . /etc/profile &>/dev/null
            . /root/.profile &>/dev/null
        fi
    fi

    }

Init

if IsNotError; then
    case $1 in
        start)
            SetServiceOperation "$1"
            StartQPKG || SetError
            ;;
        stop)
            SetServiceOperation "$1"
            StopQPKG || SetError
            ;;
        r|restart)
            SetServiceOperation restart
            { StopQPKG; StartQPKG ;} || SetError
            ;;
        s|status)
            SetServiceOperation status
            StatusQPKG || SetError
            ;;
        b|backup)
            SetServiceOperation backup
            BackupConfig || SetError
            ;;
        restore)
            SetServiceOperation "$1"
            RestoreConfig || SetError
            ;;
        c|clean)
            SetServiceOperation clean
            CleanLocalClone || SetError
            ;;
        l|log)
            SetServiceOperation log
            ViewLog
            ;;
        v|version)
            SetServiceOperation version
            Display "$QPKG_VERSION"
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
