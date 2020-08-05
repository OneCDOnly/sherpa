#!/usr/bin/env bash
####################################################################################
# osickgear.sh
#
# Copyright (C) 2020 OneCD [one.cd.only@gmail.com]
#
# so, blame OneCD if it all goes horribly wrong. ;)
#
# For more info: https://forum.qnap.com/viewtopic.php?f=320&t=132373
####################################################################################

Init()
    {

    # specific environment
        readonly QPKG_NAME=OSickGear
        readonly DEFAULT_UI_PORT=0

    # for Python-based remote apps
        readonly SOURCE_GIT_URL=http://github.com/SickGear/SickGear.git
        readonly SOURCE_GIT_BRANCH=master
        # 'shallow' (depth 1) or 'single-branch' (note: 'shallow' implies a 'single-branch' too)
        readonly SOURCE_GIT_DEPTH=single-branch
        readonly PYTHON=/opt/bin/python3
        local -r TARGET_SCRIPT=sickgear.py

    # for 'opkg'-based local apps
        readonly TARGET_DAEMON=''
        readonly ORIG_DAEMON_SERVICE_SCRIPT=''

    # additional required environment variables
        readonly TRANSMISSION_WEB_HOME=''

    # cherry-pick required binaries
    readonly BASENAME_CMD=/usr/bin/basename
    readonly CURL_CMD=/sbin/curl
    readonly DIRNAME_CMD=/usr/bin/dirname
    readonly GETCFG_CMD=/sbin/getcfg
    readonly GREP_CMD=/bin/grep
    readonly JQ_CMD=/opt/bin/jq
    readonly LESS_CMD=/opt/bin/less
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
    readonly QPKG_VERSION=$($GETCFG_CMD $QPKG_NAME Version -f $QTS_QPKG_CONF_PATHFILE)
    readonly QPKG_INI_PATHFILE=$QPKG_PATH/config/config.ini
    local -r QPKG_INI_DEFAULT_PATHFILE=$QPKG_INI_PATHFILE.def
    readonly STORED_PID_PATHFILE=/var/run/$QPKG_NAME.pid
    readonly INIT_LOG_PATHFILE=/var/log/$QPKG_NAME.log
    local -r BACKUP_PATH=$($GETCFG_CMD SHARE_DEF defVolMP -f /etc/config/def_share.info)/.qpkg_config_backup
    readonly BACKUP_PATHFILE=$BACKUP_PATH/$QPKG_NAME.config.tar.gz
    [[ -n $PYTHON ]] && export PYTHONPATH=$PYTHON
    export PATH=/opt/bin:/opt/sbin:$PATH
    ui_port=0
    ui_port_secure=0
    ui_secure=''

    # specific launch arguments
    if [[ -n $PYTHON && -n $TARGET_SCRIPT ]]; then
        readonly LAUNCHER="$PYTHON $TARGET_SCRIPT --daemon --nolaunch --datadir $($DIRNAME_CMD $QPKG_INI_PATHFILE) --pidfile $STORED_PID_PATHFILE"
    elif [[ -n $ORIG_DAEMON_SERVICE_SCRIPT && -n $TARGET_DAEMON ]]; then
        readonly LAUNCHER="$TARGET_DAEMON --daemon --configfile $QPKG_INI_PATHFILE"
    else
        DisplayErrCommitAllLogs 'found nothing to launch!'
        errorcode=1
        return 1
    fi

    if [[ -z $LANG ]]; then
        export LANG=en_US.UTF-8
        export LC_ALL=en_US.UTF-8
        export LC_CTYPE=en_US.UTF-8
    fi

    WaitForEntware
    errorcode=0

    if [[ ! -f $QPKG_INI_PATHFILE && -f $QPKG_INI_DEFAULT_PATHFILE ]]; then
        DisplayWarnCommitToLog 'no settings file found: using default'
        cp $QPKG_INI_DEFAULT_PATHFILE $QPKG_INI_PATHFILE
    fi

    if [[ -n $ORIG_DAEMON_SERVICE_SCRIPT && -x $ORIG_DAEMON_SERVICE_SCRIPT ]]; then
        $ORIG_DAEMON_SERVICE_SCRIPT stop        # stop default daemon
        chmod -x $ORIG_DAEMON_SERVICE_SCRIPT    # ... and ensure Entware doesn't re-launch it on startup
    fi

    ChoosePort

    [[ ! -d $BACKUP_PATH ]] && mkdir -p $BACKUP_PATH

    return 0

    }

ShowHelp()
    {

    Display " $($BASENAME_CMD "$0") ($QPKG_VERSION)"
    Display " A service control script for the $(FormatAsPackageName $QPKG_NAME) QPKG"
    Display
    Display " Usage: $0 [OPTION]"
    Display
    Display " [OPTION] can be any one of the following:"
    Display
    Display " start      - launch $(FormatAsPackageName $QPKG_NAME) if not already running."
    Display " stop       - shutdown $(FormatAsPackageName $QPKG_NAME) if running."
    Display " restart    - stop, then start $(FormatAsPackageName $QPKG_NAME)."
    Display " status     - check if $(FormatAsPackageName $QPKG_NAME) is still running. Returns \$? = 0 if running, 1 if not."
    Display " backup     - backup the current $(FormatAsPackageName $QPKG_NAME) configuration to persistent storage."
    Display " restore    - restore a previously saved configuration from persistent storage. $(FormatAsPackageName $QPKG_NAME) will be stopped, then restarted."
    [[ -n $SOURCE_GIT_URL ]] && Display " clean      - wipe the current local copy of $(FormatAsPackageName $QPKG_NAME), and download it again from remote source. Configuration will be retained."
    Display " log        - display this service script runtime log."
    Display " version    - display the package version number."
    Display

    }

StartQPKG()
    {

    DaemonIsActive && return

    if [[ -n $SOURCE_GIT_URL ]]; then
        PullGitRepo $QPKG_NAME "$SOURCE_GIT_URL" "$SOURCE_GIT_BRANCH" "$SOURCE_GIT_DEPTH" $QPKG_PATH && UpdateLanguages
        cd $QPKG_PATH/$QPKG_NAME || return 1
    else
        cd $QPKG_PATH || return 1
    fi

    if [[ $ui_port -eq 0 ]]; then
        DisplayErrCommitAllLogs 'unable to start daemon as no UI port was specified'
        return 1
    elif ! PortAvailable $ui_port; then
        DisplayErrCommitAllLogs "unable to start daemon as port $ui_port is already in use"
        return 1
    fi

    $SETCFG_CMD $QPKG_NAME Web_Port $ui_port -f $QTS_QPKG_CONF_PATHFILE

    ExecuteAndLog 'starting daemon' "$LAUNCHER" log:everything || return 1

    if PortResponds $ui_port; then
        DisplayDoneCommitToLog "$(FormatAsPackageName $QPKG_NAME) UI is now listening on HTTP${ui_secure} port $ui_port"
    else
        return 1
    fi

    return 0

    }

StopQPKG()
    {

    local -r MAX_WAIT_SECONDS_STOP=100
    local acc=0

    ! DaemonIsActive && return

    PID=$(<$STORED_PID_PATHFILE)

    kill $PID
    DisplayWaitCommitToLog '* stopping daemon with SIGTERM:'
    DisplayWait "(waiting for upto $MAX_WAIT_SECONDS_STOP seconds):"

    while true; do
        while [[ -d /proc/$PID ]]; do
            sleep 1
            ((acc++))
            DisplayWait "$acc,"

            if [[ $acc -ge $MAX_WAIT_SECONDS_STOP ]]; then
                DisplayWaitCommitToLog 'failed!'
                kill -9 $PID 2> /dev/null
                DisplayCommitToLog 'sent SIGKILL.'
                [[ -f $STORED_PID_PATHFILE ]] && rm -f $STORED_PID_PATHFILE
                break 2
            fi
        done

        [[ -f $STORED_PID_PATHFILE ]] && rm -f $STORED_PID_PATHFILE
        Display 'OK'
        CommitLog "stopped OK in $acc seconds"
        break
    done

    }

BackupConfig()
    {

    ExecuteAndLog 'updating configuration backup' "$TAR_CMD --create --gzip --file=$BACKUP_PATHFILE --directory=$QPKG_PATH/config ." log:everything

    }

RestoreConfig()
    {

    if [[ ! -f $BACKUP_PATHFILE ]]; then
        DisplayErrCommitAllLogs 'unable to restore configuration: no backup file was found!'
        return 1
    fi

    StopQPKG
    ExecuteAndLog 'restoring configuration backup' "$TAR_CMD --extract --gzip --file=$BACKUP_PATHFILE --directory=$QPKG_PATH/config" log:everything
    ChoosePort
    StartQPKG

    }

UpdateLanguages()
    {

    # only used by the SABnzbd package(s)
    # run [tools/make_mo.py] if SABnzbd version number has changed since last run

    [[ $QPKG_NAME != SABnzbd ]] && return

    local olddir=$PWD
    local version_current_pathfile=$QPKG_PATH/$QPKG_NAME/sabnzbd/version.py
    local version_store_pathfile=$($DIRNAME_CMD $version_current_pathfile)/version.stored
    local version_current_number=$($GREP_CMD '__version__ =' $version_current_pathfile | $SED_CMD 's|^.*"\(.*\)"|\1|')

    [[ -e $version_store_pathfile && $version_current_number = $(<$version_store_pathfile) ]] && return 0

    cd $QPKG_PATH/$QPKG_NAME || return 1

    ExecuteAndLog "updating $(FormatAsPackageName $QPKG_NAME) language translations" "$PYTHON tools/make_mo.py" && echo "$version_current_number" > $version_store_pathfile

    cd $olddir || return 1

    }

DaemonIsActive()
    {

    # $? = 0 if $QPKG_NAME is active
    # $? = 1 if $QPKG_NAME is not active

    if [[ -f $STORED_PID_PATHFILE && -d /proc/$(<$STORED_PID_PATHFILE) ]] && (PortResponds $ui_port); then
        DisplayDoneCommitToLog 'daemon is active'
        return 0
    elif [[ -n $TARGET_DAEMON ]] && (ps ax | $GREP_CMD $TARGET_DAEMON | $GREP_CMD -vq grep) && (PortResponds $ui_port); then
        DisplayDoneCommitToLog 'daemon is active'
        return 0
    else
        DisplayDoneCommitToLog 'daemon is not active'
        [[ -f $STORED_PID_PATHFILE ]] && rm $STORED_PID_PATHFILE
        return 1
    fi

    }

PullGitRepo()
    {

    # $1 = package name
    # $2 = URL to pull/clone from
    # $3 = remote branch or tag
    # $4 = remote depth: 'shallow' or 'single-branch'
    # $5 = local path to clone into

    local -r GIT_CMD=/opt/bin/git

    [[ -z $1 || -z $2 || -z $3 || -z $4 || -z $5 ]] && return 1
    SysFilePresent "$GIT_CMD" || { errorcode=1; return 1 ;}

    local QPKG_GIT_PATH="$5/$1"
    local GIT_HTTP_URL="$2"
    local GIT_HTTPS_URL=${GIT_HTTP_URL/http/git}
    [[ $4 = shallow ]] && local depth=' --depth 1'
    [[ $4 = single-branch ]] && local depth=' --single-branch'

    if [[ ! -d ${QPKG_GIT_PATH}/.git ]]; then
        ExecuteAndLog "cloning $(FormatAsPackageName $1) from remote repository" "$GIT_CMD clone --branch $3 $depth -c advice.detachedHead=false $GIT_HTTPS_URL $QPKG_GIT_PATH || $GIT_CMD clone --branch $3 $depth -c advice.detachedHead=false $GIT_HTTP_URL $QPKG_GIT_PATH"
    else
        ExecuteAndLog "updating $(FormatAsPackageName $1) from remote repository" "cd $QPKG_GIT_PATH && $GIT_CMD pull"
    fi

    }

CleanLocalClone()
    {

    # for the rare occasions the local repo becomes corrupt, it needs to be deleted and cloned again from source.

    [[ -z $QPKG_PATH || -z $QPKG_NAME || -z $SOURCE_GIT_URL ]] && return 1

    StopQPKG
    ExecuteAndLog 'cleaning local repo' "rm -r $QPKG_PATH/$QPKG_NAME"
    StartQPKG

    }

ExecuteAndLog()
    {

    # $1 processing message
    # $2 command(s) to run
    # $3 'log:everything' (optional) - if specified, the result of the command is recorded in the QTS system log.
    #                                - if unspecified, only warnings are logged in the QTS system log.

    [[ -z $1 || -z $2 ]] && return 1

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
        CommitWarnToSysLog "A problem occurred while $1. Check $(FormatAsFileName "$INIT_LOG_PATHFILE") for more details."
        returncode=1
    fi

    return $returncode

    }

ChoosePort()
    {

    ui_port=$(UIPortSecure)

    if [[ $ui_port -gt 0 ]]; then
        ui_secure='S'
    else
        ui_port=$(UIPort)
    fi

    }

UIPort()
    {

    # get HTTP port
    # stdout = HTTP port (if used) or default if none found

    $GETCFG_CMD General web_port -d $DEFAULT_UI_PORT -f $QPKG_INI_PATHFILE

    }

UIPortSecure()
    {

    # get HTTPS port
    # stdout = HTTPS port (if used) or 0 if none found

    if [[ $($GETCFG_CMD General enable_https -d 0 -f $QPKG_INI_PATHFILE) = 1 ]]; then
        $GETCFG_CMD General web_port -d 0 -f $QPKG_INI_PATHFILE
    else
        echo 0
    fi

    }

PortAvailable()
    {

    # $1 = port to check
    # $? = 0 if available
    # $? = 1 if already used or unspecified

    if [[ -z $1 ]] || ($LSOF_CMD -i :$1 -sTCP:LISTEN >/dev/null 2>&1); then
        return 1
    else
        return 0
    fi

    }

PortResponds()
    {

    # $1 = port to check
    # $? = 0 if response received
    # $? = 1 if not OK or port unspecified

    [[ -z $1 ]] && return 1

    local -r MAX_WAIT_SECONDS_START=100
    local acc=0

    DisplayWaitCommitToLog "* checking for UI port $ui_port response:"
    DisplayWait "(waiting for upto $MAX_WAIT_SECONDS_START seconds):"

    while true; do
        while ! $CURL_CMD --silent --fail localhost:$1 >/dev/null; do
            sleep 1
            ((acc++))
            DisplayWait "$acc,"

            if [[ $acc -ge $MAX_WAIT_SECONDS_START ]]; then
                DisplayCommitToLog 'failed!'
                CommitErrToSysLog "UI port $ui_port failed to respond after $acc seconds"
                return 1
            fi
        done
        Display 'OK'
        CommitLog "UI port responded after $acc seconds"
        return 0
    done

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

    echo "$1" | $TEE_CMD -a $INIT_LOG_PATHFILE

    }

DisplayWaitCommitToLog()
    {

    DisplayWait "$1" | $TEE_CMD -a $INIT_LOG_PATHFILE

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

    echo "$1" >> $INIT_LOG_PATHFILE

    }

CommitSysLog()
    {

    # $1 = message to append to QTS system log
    # $2 = event type:
    #    1 : Error
    #    2 : Warning
    #    4 : Information

    [[ -z $1 || -z $2 ]] && return 1

    $WRITE_LOG_CMD "[$QPKG_NAME] $1" $2

    }

SessionSeparator()
    {

    # $1 = message

    printf '%0.s-' {1..20}; echo -n " $1 "; printf '%0.s-' {1..20}

    }

SysFilePresent()
    {

    # $1 = pathfile to check

    [[ -z $1 ]] && return 1

    if [[ ! -e $1 ]]; then
        echo "! A required NAS system file is missing [$1]"
        errorcode=1
        return 1
    else
        return 0
    fi

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

if [[ $errorcode -eq 0 ]]; then
    if [[ -n $1 ]]; then
        CommitLog "$(SessionSeparator "'$1' requested")"
        CommitLog "= $(date)"
    fi
    case $1 in
        start)
            StartQPKG || errorcode=1
            ;;
        stop)
            StopQPKG || errorcode=1
            ;;
        r|restart)
            StopQPKG; StartQPKG || errorcode=1
            ;;
        s|status)
            DaemonIsActive $QPKG_NAME >/dev/null || errorcode=1
            ;;
        b|backup)
            BackupConfig || errorcode=1
            ;;
        restore)
            RestoreConfig || errorcode=1
            ;;
        c|clean)
            CleanLocalClone || errorcode=1
            ;;
        l|log)
            if [[ -e $INIT_LOG_PATHFILE ]]; then
                $LESS_CMD -rMK -PM' use arrow-keys to scroll up-down left-right, press Q to quit' $INIT_LOG_PATHFILE
            else
                Display "service log not found: $(FormatAsFileName $INIT_LOG_PATHFILE)"
            fi
            ;;
        v|version)
            Display "$QPKG_VERSION"
            ;;
        *)
            ShowHelp
            ;;
    esac
fi

exit $errorcode
