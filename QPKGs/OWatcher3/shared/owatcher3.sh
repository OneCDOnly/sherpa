#!/usr/bin/env bash
####################################################################################
# owatcher3.sh
#
# Copyright (C) 2019-2020 OneCD [one.cd.only@gmail.com]
#
# so, blame OneCD if it all goes horribly wrong. ;)
#
# For more info: https://forum.qnap.com/viewtopic.php?f=320&t=132373
####################################################################################

Init()
    {

    readonly QPKG_NAME=OWatcher3
    readonly SOURCE_URL=https://github.com/barbequesauce/Watcher3.git
    readonly SOURCE_BRANCH=master
    readonly PYTHON=/opt/bin/python3
    local -r TARGET_SCRIPT=watcher.py

    # cherry-pick required binaries
    readonly BASENAME_CMD=/usr/bin/basename
    readonly CURL_CMD=/sbin/curl
    readonly DIRNAME_CMD=/usr/bin/dirname
    readonly GETCFG_CMD=/sbin/getcfg
    readonly GREP_CMD=/bin/grep
    readonly LSOF_CMD=/usr/sbin/lsof
    readonly SED_CMD=/bin/sed
    readonly SETCFG_CMD=/sbin/setcfg
    readonly TAR_CMD=/bin/tar
    readonly TAIL_CMD=/usr/bin/tail
    readonly TEE_CMD=/usr/bin/tee
    readonly WRITE_LOG_CMD=/sbin/write_log

    readonly QTS_QPKG_CONF_PATHFILE=/etc/config/qpkg.conf
    readonly QPKG_PATH=$($GETCFG_CMD $QPKG_NAME Install_Path -f $QTS_QPKG_CONF_PATHFILE)
    readonly QPKG_INI_PATHFILE=$QPKG_PATH/config/config.ini
    local -r QPKG_INI_DEFAULT_PATHFILE=$QPKG_INI_PATHFILE.def
    readonly STORED_PID_PATHFILE=/tmp/$QPKG_NAME.pid
    readonly INIT_LOG_PATHFILE=/var/log/$QPKG_NAME.log
    local -r BACKUP_PATH=$(getcfg SHARE_DEF defVolMP -f /etc/config/def_share.info)/.qpkg_config_backup
    readonly BACKUP_PATHFILE=$BACKUP_PATH/$QPKG_NAME.config.tar.gz
    readonly LAUNCHER="$PYTHON $TARGET_SCRIPT --daemon --userdata $($DIRNAME_CMD $QPKG_INI_PATHFILE) --conf $QPKG_INI_PATHFILE --pid $STORED_PID_PATHFILE"
    export PYTHONPATH=$PYTHON
    export PATH=/opt/bin:/opt/sbin:$PATH

    if [[ -z $LANG ]]; then
        export LANG=en_US.UTF-8
        export LC_ALL=en_US.UTF-8
        export LC_CTYPE=en_US.UTF-8
    fi

    WaitForEntware
    errorcode=0

    if [[ ! -f $QPKG_INI_PATHFILE && -f $QPKG_INI_DEFAULT_PATHFILE ]]; then
        WriteToDisplayAndLog '! no settings file found: using default'
        cp $QPKG_INI_DEFAULT_PATHFILE $QPKG_INI_PATHFILE
    fi

    [[ ! -d $BACKUP_PATH ]] && mkdir -p $BACKUP_PATH

    return 0

    }

StartQPKG()
    {

    local -r MAX_WAIT_SECONDS_START=100
    local exec_msgs=''
    local result=0
    local ui_port=''
    local secure=''
    local acc=0

    QPKGIsActive && return

    PullGitRepo $QPKG_NAME "$SOURCE_URL" $SOURCE_BRANCH $QPKG_PATH

    cd $QPKG_PATH/$QPKG_NAME || return 1

    ui_port=$(UIPortSecure)
    if [[ $ui_port -gt 0 ]]; then
        secure='S'
    else
        ui_port=$(UIPort)
    fi

    if [[ $ui_port -eq 0 ]]; then
        WriteToDisplayAndLog '! unable to start daemon: no port specified'
        WriteErrorToSystemLog 'Unable to start daemon as no UI port was specified'
        return 1
    elif ! PortAvailable $ui_port; then
        WriteToDisplayAndLog "! unable to start daemon: port $ui_port already in use"
        WriteErrorToSystemLog 'Unable to start daemon as specified UI port is already in use'
        return 1
    fi

    $SETCFG_CMD $QPKG_NAME Web_Port $ui_port -f $QTS_QPKG_CONF_PATHFILE

    WriteToDisplayAndLog_SameLine '* launching: '
    exec_msgs=$($LAUNCHER 2>&1)
    result=$?

    if [[ $result = 0 || $result = 2 ]]; then
        WriteToDisplayAndLog 'OK'
    else
        WriteToDisplayAndLog 'failed!'
        WriteToDisplayAndLog "= result: $(FormatAsExitcode $result)"
        WriteToDisplayAndLog "= daemon startup messages: $(FormatAsStdout "$exec_msgs")"
        WriteErrorToSystemLog "Daemon launch failed. Check $(FormatAsFileName "$INIT_LOG_PATHFILE") for more details."
        return 1
    fi

    WriteToDisplayAndLog_SameLine "* checking for daemon UI port $ui_port response: "
    WriteToDisplay_SameLine "(waiting for upto $MAX_WAIT_SECONDS_START seconds): "

    while true; do
        while ! PortResponds $ui_port; do
            sleep 1
            ((acc++))
            WriteToDisplay_SameLine "$acc, "

            if [[ $acc -ge $MAX_WAIT_SECONDS_START ]]; then
                WriteToDisplayAndLog 'failed!'
                WriteErrorToSystemLog "Daemon UI port $ui_port failed to respond after $acc seconds"
                return 1
            fi
        done
        WriteToDisplay 'OK'
        WriteToLog "daemon UI responded after $acc seconds"
        break
    done

    WriteToDisplayAndLog "= $(FormatAsPackageName $QPKG_NAME) daemon UI is now listening on HTTP${secure} port: $ui_port"

    return 0

    }

StopQPKG()
    {

    local -r MAX_WAIT_SECONDS_STOP=100
    local acc=0

    ! QPKGIsActive && return

    PID=$(<$STORED_PID_PATHFILE)

    kill $PID
    WriteToDisplayAndLog_SameLine '* stopping daemon with SIGTERM: '
    WriteToDisplay_SameLine "(waiting for upto $MAX_WAIT_SECONDS_STOP seconds): "

    while true; do
        while [[ -d /proc/$PID ]]; do
            sleep 1
            ((acc++))
            WriteToDisplay_SameLine "$acc, "

            if [[ $acc -ge $MAX_WAIT_SECONDS_STOP ]]; then
                WriteToDisplayAndLog_SameLine "failed! "
                kill -9 $PID 2> /dev/null
                WriteToDisplayAndLog 'sent SIGKILL.'
                rm -f $STORED_PID_PATHFILE
                break 2
            fi
        done

        rm -f $STORED_PID_PATHFILE
        WriteToDisplay 'OK'
        WriteToLog "stopped OK in $acc seconds"
        break
    done

    }

BackupQPKGData()
    {

    local exec_msgs=''
    local result=0

    WriteToDisplayAndLog_SameLine '* updating configuration backup: '

    exec_msgs=$($TAR_CMD --create --gzip --file=$BACKUP_PATHFILE --directory=$QPKG_PATH/config . 2>&1)
    result=$?

    if [[ $result = 0 ]]; then
        WriteToDisplayAndLog 'OK'
        WriteInfoToSystemLog "updated configuration backup"
    else
        WriteToDisplayAndLog 'failed!'
        WriteToDisplayAndLog "= result: $(FormatAsExitcode $result)"
        WriteToDisplayAndLog "= messages: $(FormatAsStdout "$exec_msgs")"
        WriteWarningToSystemLog "A problem occurred while updating configuration backup. Check $(FormatAsFileName "$INIT_LOG_PATHFILE") for more details."
        return 1
    fi

    }

RestoreQPKGData()
    {

    local exec_msgs=''
    local result=0

    if [[ -f $BACKUP_PATHFILE ]]; then
        StopQPKG

        WriteToDisplayAndLog_SameLine '* restoring configuration backup: '

        exec_msgs=$($TAR_CMD --extract --gzip --file=$BACKUP_PATHFILE --directory=$QPKG_PATH/config 2>&1)
        result=$?

        if [[ $result = 0 ]]; then
            WriteToDisplayAndLog 'OK'
            WriteInfoToSystemLog "configuration restored from backup"
            StartQPKG
        else
            WriteToDisplayAndLog 'failed!'
            WriteToDisplayAndLog "= result: $(FormatAsExitcode $result)"
            WriteToDisplayAndLog "= messages: $(FormatAsStdout "$exec_msgs")"
            WriteWarningToSystemLog "A problem occurred while restoring configuration backup. Check $(FormatAsFileName "$INIT_LOG_PATHFILE") for more details."
            return 1
        fi
    else
        WriteToDisplayAndLog '! unable to restore - no backup file was found!'
        WriteErrorToSystemLog 'Unable to restore configuration. No backup file was found.'
        return 1
    fi

    }

QPKGIsActive()
    {

    # $? = 0 if $QPKG_NAME is active
    # $? = 1 if $QPKG_NAME is not active

    if [[ -f $STORED_PID_PATHFILE && -d /proc/$(<$STORED_PID_PATHFILE) ]]; then
        WriteToDisplayAndLog '= daemon is active'
        return 0
    else
        WriteToDisplayAndLog '= daemon is not active'
        [[ -f $STORED_PID_PATHFILE ]] && rm $STORED_PID_PATHFILE
        return 1
    fi

    }

PullGitRepo()
    {

    # $1 = package name
    # $2 = URL to pull/clone from
    # $3 = branch
    # $4 = path to clone into

    local -r GIT_CMD=/opt/bin/git
    local exec_msgs=''

    [[ -z $1 || -z $2 || -z $3 || -z $4 ]] && return 1
    SysFilePresent "$GIT_CMD" || { errorcode=1; return 1 ;}

    local QPKG_GIT_PATH="$4/$1"
    local GIT_HTTP_URL="$2"
    local GIT_HTTPS_URL=${GIT_HTTP_URL/http/git}

    WriteToDisplayAndLog_SameLine "* updating application $(FormatAsPackageName $1): "
    exec_msgs=$({
        [[ ! -d ${QPKG_GIT_PATH}/.git ]] && { $GIT_CMD clone -b $3 --depth 1 "$GIT_HTTPS_URL" "$QPKG_GIT_PATH" || $GIT_CMD clone -b $3 --depth 1 "$GIT_HTTP_URL" "$QPKG_GIT_PATH" ;}
        cd "$QPKG_GIT_PATH" && $GIT_CMD pull
    } 2>&1)
    result=$?

    if [[ $result = 0 ]]; then
        WriteToDisplayAndLog 'OK'
        WriteToLog "= result: $(FormatAsExitcode $result)"
        WriteToLog "= ${FUNCNAME[0]}(): $(FormatAsStdout "$exec_msgs")"
    else
        WriteToDisplayAndLog 'failed!'
        WriteToDisplayAndLog "= result: $(FormatAsExitcode $result)"
        WriteToDisplayAndLog "= ${FUNCNAME[0]}(): $(FormatAsStdout "$exec_msgs")"
        WriteErrorToSystemLog "An error occurred while updating $(FormatAsPackageName $1) daemon from remote repository. Check $(FormatAsFileName "$INIT_LOG_PATHFILE") for more details."
        return 1
    fi

    }

UIPort()
    {

    # get HTTP port
    # stdout = HTTP port (if used) or 0 if none found

    /opt/bin/jq -r .Server.serverport < $QPKG_INI_PATHFILE

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

    if [[ -z $1 ]] || ($LSOF_CMD -i :$1 -sTCP:LISTEN 2>&1 >/dev/null); then
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

    $CURL_CMD --silent --fail localhost:$1 >/dev/null

    }

FormatAsPackageName()
    {

    [[ -z $1 ]] && return 1

    echo "'$1'"

    }

FormatAsFileName()
    {

    [[ -z $1 ]] && return 1

    echo "($1)"

    }

FormatAsStdout()
    {

    [[ -z $1 ]] && return 1

    echo "\"$1\""

    }

FormatAsExitcode()
    {

    [[ -z $1 ]] && return 1

    echo "[$1]"

    }

WriteToDisplayAndLog_SameLine()
    {

    echo -n "$1" | $TEE_CMD -a $INIT_LOG_PATHFILE

    }

WriteToDisplayAndLog()
    {

    echo "$1" | $TEE_CMD -a $INIT_LOG_PATHFILE

    }

WriteToDisplay_SameLine()
    {

    echo -n "$1"

    }

WriteToDisplay()
    {

    echo "$1"

    }

WriteToLog()
    {

    echo "$1" >> $INIT_LOG_PATHFILE

    }

WriteInfoToSystemLog()
    {

    [[ -z $1 ]] && return 1

    SystemLogWrite "$1" 4

    }

WriteWarningToSystemLog()
    {

    [[ -z $1 ]] && return 1

    SystemLogWrite "$1" 2

    }

WriteErrorToSystemLog()
    {

    [[ -z $1 ]] && return 1

    SystemLogWrite "$1" 1

    }

SystemLogWrite()
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
                [[ -e /opt/Entware.sh || -e /opt/Entware-3x.sh || -e /opt/Entware-ng.sh ]] && { WriteToLog "waited for Entware for $count seconds"; true; exit ;}
            done
            false
        )

        if [[ $? -ne 0 ]]; then
            WriteToDisplayAndLog "Entware not found! (exceeded timeout: $MAX_WAIT_SECONDS_ENTWARE seconds)"
            WriteErrorToSystemLog 'Unable to manage daemon: Entware was not found (exceeded timeout)'
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
    WriteToLog "$(SessionSeparator "$1 requested")"
    WriteToLog "= $(date)"
    case $1 in
        start)
            StartQPKG || errorcode=1
            ;;
        stop)
            StopQPKG || errorcode=1
            ;;
        restart)
            StopQPKG; StartQPKG || errorcode=1
            ;;
        backup)
            BackupQPKGData || errorcode=1
            ;;
        restore)
            RestoreQPKGData || errorcode=1
            ;;
        *)
            WriteToDisplay "Usage: $0 {start|stop|restart|backup|restore}"
            ;;
    esac
fi

exit $errorcode
