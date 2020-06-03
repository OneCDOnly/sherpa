#!/usr/bin/env bash

Init()
    {

    readonly QPKG_NAME=OMedusa
    readonly REPO_URL=http://github.com/pymedusa/Medusa.git
    local -r PYTHON=/opt/bin/python3
    local -r TARGET_SCRIPT=start.py

    # cherry-pick binaries
    readonly CMD_BASENAME=/usr/bin/basename
    readonly CMD_CURL=/sbin/curl
    readonly CMD_DIRNAME=/usr/bin/dirname
    readonly CMD_GETCFG=/sbin/getcfg
    readonly CMD_LSOF=/usr/sbin/lsof
    readonly CMD_SETCFG=/sbin/setcfg
    readonly CMD_TAR=/bin/tar
    readonly CMD_TEE=/usr/bin/tee
    readonly CMD_WRITE_LOG=/sbin/write_log

    readonly QTS_QPKG_CONF_PATHFILE=/etc/config/qpkg.conf
    readonly QPKG_PATH=$($CMD_GETCFG $QPKG_NAME Install_Path -f $QTS_QPKG_CONF_PATHFILE)
    readonly QPKG_INI_PATHFILE=$QPKG_PATH/config/config.ini
    local -r QPKG_INI_DEFAULT_PATHFILE=$QPKG_INI_PATHFILE.def
    readonly STORED_PID_PATHFILE=/tmp/$QPKG_NAME.pid
    readonly INIT_LOG_PATHFILE=/var/log/$QPKG_NAME.log
    local -r BACKUP_PATH=$(getcfg SHARE_DEF defVolMP -f /etc/config/def_share.info)/.qpkg_config_backup
    readonly BACKUP_PATHFILE=$BACKUP_PATH/$QPKG_NAME.config.tar.gz
    readonly LAUNCHER="$PYTHON $TARGET_SCRIPT --daemon --nolaunch --datadir $($CMD_DIRNAME $QPKG_INI_PATHFILE) --config $QPKG_INI_PATHFILE --pidfile $STORED_PID_PATHFILE"
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
        echo "! no settings file found: using default"
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

    PullGitRepo $QPKG_NAME "$REPO_URL" $QPKG_PATH

    cd $QPKG_PATH/$QPKG_NAME || return 1

    ui_port=$(UIPortSecure)
    if [[ $ui_port -gt 0 ]]; then
        secure='S'
    else
        ui_port=$(UIPort)
    fi

    if [[ $ui_port -eq 0 ]]; then
        echo "! unable to start daemon: no port specified" | $CMD_TEE -a $INIT_LOG_PATHFILE
        WriteErrorToSystemLog "Unable to start daemon as no UI port was specified"
        return 1
    elif ! PortAvailable $ui_port; then
        echo "! unable to start daemon: port $ui_port already in use" | $CMD_TEE -a $INIT_LOG_PATHFILE
        WriteErrorToSystemLog "Unable to start daemon as specified UI port is already in use"
        return 1
    fi

    $CMD_SETCFG $QPKG_NAME Web_Port $ui_port -f $QTS_QPKG_CONF_PATHFILE
    echo -n "* launching: "
    exec_msgs=$($LAUNCHER 2>&1)
    result=$?

    if [[ $result = 0 || $result = 2 ]]; then
        echo "OK"
    else
        echo "failed!"
        echo "= result: $(FormatAsExitcode $result)"
        echo "= daemon startup messages: $(FormatAsStdout "$exec_msgs")"
        return 1
    fi

    echo -n "* checking for daemon UI port $ui_port response: " | $CMD_TEE -a $INIT_LOG_PATHFILE
    echo -n "(waiting for upto $MAX_WAIT_SECONDS_START seconds): "

    while true; do
        while ! PortResponds $ui_port; do
            sleep 1
            ((acc++))
            echo -n "$acc, "

            if [[ $acc -ge $MAX_WAIT_SECONDS_START ]]; then
                echo "failed!" | $CMD_TEE -a $INIT_LOG_PATHFILE
                WriteErrorToSystemLog "Daemon UI port $ui_port failed to respond after $acc seconds"
                return 1
            fi
        done
        echo "OK"; echo "daemon UI responded after $acc seconds" >> $INIT_LOG_PATHFILE
        break
    done

    echo "= $(FormatAsPackageName $QPKG_NAME) daemon UI is now listening on HTTP${secure} port: $ui_port"

    return 0

    }

StopQPKG()
    {

    local -r MAX_WAIT_SECONDS_STOP=100
    local acc=0

    ! QPKGIsActive && return

    PID=$(<$STORED_PID_PATHFILE)

    kill $PID
    echo -n "* stopping daemon with SIGTERM: " | $CMD_TEE -a $INIT_LOG_PATHFILE; echo -n "(waiting for upto $MAX_WAIT_SECONDS_STOP seconds): "

    while true; do
        while [[ -d /proc/$PID ]]; do
            sleep 1
            ((acc++))
            echo -n "$acc, "

            if [[ $acc -ge $MAX_WAIT_SECONDS_STOP ]]; then
                echo -n "failed! " | $CMD_TEE -a $INIT_LOG_PATHFILE
                kill -9 $PID 2> /dev/null
                echo "sent SIGKILL." | $CMD_TEE -a $INIT_LOG_PATHFILE
                rm -f $STORED_PID_PATHFILE
                break 2
            fi
        done

        rm -f $STORED_PID_PATHFILE
        echo "OK"; echo "stopped OK in $acc seconds" >> $INIT_LOG_PATHFILE
        break
    done

    }

BackupQPKGData()
    {

    local returncode=0
    local exec_msgs=''
    local result=0

    echo -n "* creating configuration backup: " | $CMD_TEE -a $INIT_LOG_PATHFILE

    exec_msgs=$($CMD_TAR --create --gzip --file=$BACKUP_PATHFILE --directory=$QPKG_PATH/config . ; echo hi 2>&1)
    result=$?

    if [[ $result = 0 ]]; then
        echo "OK" | $CMD_TEE -a $INIT_LOG_PATHFILE
    else
        {
            echo "failed!"
            echo "= result: $(FormatAsExitcode $result)"
            echo "= messages: $(FormatAsStdout "$exec_msgs")"
        } | $CMD_TEE -a $INIT_LOG_PATHFILE
        WriteErrorToSystemLog "An error occurred while creating configuration backup. Check $(FormatAsFileName "$INIT_LOG_PATHFILE") for more details."
        returncode=1
    fi

    return $returncode

    }

RestoreQPKGData()
    {

    local returncode=0
    local exec_msgs=''
    local result=0

    if [[ -f $BACKUP_PATHFILE ]]; then
        StopQPKG

        echo -n "* restoring configuration backup: " | $CMD_TEE -a $INIT_LOG_PATHFILE

        exec_msgs=$($CMD_TAR --extract --gzip --file=$BACKUP_PATHFILE --directory=$QPKG_PATH/config 2>&1)
        result=$?

        if [[ $result = 0 ]]; then
            echo "OK" | $CMD_TEE -a $INIT_LOG_PATHFILE
            StartQPKG
        else
            {
                echo "failed!"
                echo "= result: $(FormatAsExitcode $result)"
                echo "= messages: $(FormatAsStdout "$exec_msgs")"
            } | $CMD_TEE -a $INIT_LOG_PATHFILE
            WriteErrorToSystemLog "An error occurred while restoring configuration backup. Check $(FormatAsFileName "$INIT_LOG_PATHFILE") for more details."
            returncode=1
        fi
    else
        echo "! unable to restore - no backup file was found!" | $CMD_TEE -a $INIT_LOG_PATHFILE
        WriteErrorToSystemLog "No configuration backup file was found"
        returncode=1
    fi

    return $returncode

    }

QPKGIsActive()
    {

    # $? = 0 if $QPKG_NAME is active
    # $? = 1 if $QPKG_NAME is not active

    if [[ -f $STORED_PID_PATHFILE && -d /proc/$(<$STORED_PID_PATHFILE) ]]; then
        echo "= daemon is active" | $CMD_TEE -a $INIT_LOG_PATHFILE
        return 0
    else
        echo "= daemon is not active" | $CMD_TEE -a $INIT_LOG_PATHFILE
        [[ -f $STORED_PID_PATHFILE ]] && rm $STORED_PID_PATHFILE
        return 1
    fi

    }

PullGitRepo()
    {

    # $1 = package name
    # $2 = URL to pull/clone from
    # $3 = path to clone into

    local -r GIT_CMD=/opt/bin/git
    local exec_msgs=''

    [[ -z $1 || -z $2 || -z $3 ]] && return 1
    SysFilePresent "$GIT_CMD" || { errorcode=1; return 1 ;}

    local -r QPKG_GIT_PATH="$3/$1"
    local -r GIT_HTTP_URL="$2"
    local -r GIT_HTTPS_URL=${GIT_HTTP_URL/http/git}

    echo -n "* updating: " | $CMD_TEE -a $INIT_LOG_PATHFILE
    exec_msgs=$({

        [[ ! -d ${QPKG_GIT_PATH}/.git ]] && { $GIT_CMD clone -b master --depth 1 "$GIT_HTTPS_URL" "$QPKG_GIT_PATH" || $GIT_CMD clone -b master --depth 1 "$GIT_HTTP_URL" "$QPKG_GIT_PATH" ;}
        cd "$QPKG_GIT_PATH" && $GIT_CMD pull

        } 2>&1)
    result=$?

    if [[ $result = 0 ]]; then
        echo "OK" | $CMD_TEE -a $INIT_LOG_PATHFILE
        echo -e "= result: $result\n= ${FUNCNAME[0]}(): $(FormatAsStdout "$exec_msgs")" >> $INIT_LOG_PATHFILE
    else
        echo -e "failed!\n= result: $result\n= ${FUNCNAME[0]}(): $(FormatAsStdout "$exec_msgs")" | $CMD_TEE -a $INIT_LOG_PATHFILE
        return 1
    fi

    }

UIPort()
    {

    # get HTTP port
    # stdout = HTTP port (if used) or 0 if none found

    $CMD_GETCFG General web_port -d 0 -f $QPKG_INI_PATHFILE

    }

UIPortSecure()
    {

    # get HTTPS port
    # stdout = HTTPS port (if used) or 0 if none found

    if [[ $($CMD_GETCFG General enable_https -d 0 -f $QPKG_INI_PATHFILE) = 1 ]]; then
        $CMD_GETCFG General web_port -d 0 -f $QPKG_INI_PATHFILE
    else
        echo 0
    fi

    }

PortAvailable()
    {

    # $1 = port to check
    # $? = 0 if available
    # $? = 1 if already used or unspecified

    if [[ -z $1 ]] || ($CMD_LSOF -i :$1 -sTCP:LISTEN 2>&1 >/dev/null); then
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

    $CMD_CURL --silent --fail localhost:$1 >/dev/null

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

WriteErrorToSystemLog()
    {

    # $1 = message to write into QTS system log as an error

    [[ -z $1 ]] && return 1
    $CMD_WRITE_LOG "[$QPKG_NAME] $1" 1

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
                [[ -e /opt/Entware.sh || -e /opt/Entware-3x.sh || -e /opt/Entware-ng.sh ]] && { echo "waited for Entware for $count seconds" >> $INIT_LOG_PATHFILE; true; exit ;}
            done
            false
        )

        if [[ $? -ne 0 ]]; then
            echo "Entware not found! (exceeded timeout: $MAX_WAIT_SECONDS_ENTWARE seconds)" | $CMD_TEE -a $INIT_LOG_PATHFILE
            WriteErrorToSystemLog "Unable to manage daemon: Entware was not found (exceeded timeout)"
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
    echo -e "$(SessionSeparator "$1 requested")\n= $(date)" >> $INIT_LOG_PATHFILE
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
            echo "Usage: $0 {start|stop|restart|backup|restore}"
            ;;
    esac
fi

exit $errorcode
