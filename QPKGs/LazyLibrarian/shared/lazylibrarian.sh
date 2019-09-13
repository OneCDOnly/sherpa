#!/usr/bin/env bash

Init()
    {

    # package specific
    QPKG_NAME=LazyLibrarian
    local TARGET_SCRIPT=LazyLibrarian.py
    GIT_HTTP_URL='https://gitlab.com/LazyLibrarian/LazyLibrarian.git'

    QPKG_PATH=$(/sbin/getcfg $QPKG_NAME Install_Path -f /etc/config/qpkg.conf)
    STORED_PID_PATHFILE=/tmp/${QPKG_NAME}.pid
    DATA_PATH=${QPKG_PATH}/config

    DAEMON_OPTS="$TARGET_SCRIPT -d --pidfile $STORED_PID_PATHFILE --datadir $DATA_PATH"
    QPKG_GIT_PATH="${QPKG_PATH}/${QPKG_NAME}"
    LOG_PATHFILE=/var/log/${QPKG_NAME}.log
    DAEMON=/opt/bin/python2.7
    export PYTHONPATH=$DAEMON
    export PATH=/opt/bin:/opt/sbin:$PATH

    if [[ -z $LANG ]]; then
        export LANG=en_US.UTF-8
        export LC_ALL=en_US.UTF-8
        export LC_CTYPE=en_US.UTF-8
    fi

    WaitForEntware
    errorcode=0
    [[ ! -f $SETTINGS_PATHFILE && -f $SETTINGS_DEFAULT_PATHFILE ]] && { echo "! no settings file found - using default"; cp "$SETTINGS_DEFAULT_PATHFILE" "$SETTINGS_PATHFILE" ;}
    return 0

    }

QPKGIsActive()
    {

    # $? = 0 if $QPKG_NAME is active
    # $? = 1 if $QPKG_NAME is not active

    if [[ -f $STORED_PID_PATHFILE && -d /proc/$(<$STORED_PID_PATHFILE) ]]; then
        echo "= ($QPKG_NAME) is active" | tee -a $LOG_PATHFILE
    else
        echo "= ($QPKG_NAME) is not active" | tee -a $LOG_PATHFILE
        [[ -f $STORED_PID_PATHFILE ]] && rm $STORED_PID_PATHFILE
    fi

    }

UpdateQpkg()
    {

    local returncode=0
    local msg=''
    local exec_msgs=''
    SysFilePresent "$GIT_CMD" || { errorcode=1; return 1 ;}

    echo -n "* updating ($QPKG_NAME): " | tee -a "$LOG_PATHFILE"
    exec_messages="$({

    [[ -d ${QPKG_GIT_PATH}/.git ]] || $GIT_CMD clone --depth 1 "$GIT_HTTP_URL" "$QPKG_GIT_PATH"
    cd "$QPKG_GIT_PATH" && $GIT_CMD checkout master && $GIT_CMD pull && /bin/sync

    } 2>&1)"
    result=$?

    if [[ $result -eq 0 ]]; then
        msg='OK'
        echo -e "$msg" | tee -a "$LOG_PATHFILE"
        echo -e "${exec_messages}" >> "$LOG_PATHFILE"
    else
        echo -e "failed!\n= result: $result\n= ${FUNCNAME[0]}(): '$exec_msgs'" | tee -a $LOG_PATHFILE
    fi

    cd $olddir

    }

PullGitRepo()
    {

    # $1 = package name
    # $2 = URL to pull/clone from
    # $3 = path to clone into

    local returncode=0
    local exec_msgs=''
    local GIT_CMD=/opt/bin/git

    [[ -z $1 || -z $2 || -z $3 ]] && returncode=1
    SysFilePresent "$GIT_CMD" || { errorcode=1; returncode=1 ;}

    local QPKG_GIT_PATH="$3/$1"

    if [[ $returncode = 0 ]]; then
        local GIT_HTTP_URL="$2"
        local GIT_HTTPS_URL=${GIT_HTTP_URL/http/git}

        echo -n "* updating ($1): " | tee -a $LOG_PATHFILE
        exec_msgs=$({
            [[ ! -d ${QPKG_GIT_PATH}/.git ]] && { $GIT_CMD clone -b master --depth 1 "$GIT_HTTPS_URL" "$QPKG_GIT_PATH" || $GIT_CMD clone -b master --depth 1 "$GIT_HTTP_URL" "$QPKG_GIT_PATH" ;}
            cd "$QPKG_GIT_PATH" && $GIT_CMD pull
        } 2>&1)
        result=$?

        if [[ $result = 0 ]]; then
            echo "OK" | tee -a $LOG_PATHFILE
            echo -e "= result: $result\n= ${FUNCNAME[0]}(): '$exec_msgs'" >> $LOG_PATHFILE
        else
            echo -e "failed!\n= result: $result\n= ${FUNCNAME[0]}(): '$exec_msgs'" | tee -a $LOG_PATHFILE
            returncode=1
        fi
    fi

    return $returncode

    }

StartQPKG()
    {

    local returncode=0
    local exec_msgs=''
    local ui_port=''
    local secure=''

    QPKGIsActive && return

    UpdateQpkg

    cd "$QPKG_PATH/$QPKG_NAME"

    if [[ $(/sbin/getcfg misc enable_https -d 0 -f "$SETTINGS_PATHFILE") = 1 ]]; then
        ui_port=$(/sbin/getcfg misc https_port -d 0 -f "$SETTINGS_PATHFILE")
        secure='S'
    else
        ui_port=$(/sbin/getcfg misc port -d 0 -f "$SETTINGS_PATHFILE")
    fi

    if [[ $ui_port -gt 0 ]]; then
        /sbin/setcfg $QPKG_NAME Web_Port $ui_port -f "$QPKG_CONF_PATHFILE"

        echo -n "* starting ($QPKG_NAME): " | tee -a $LOG_PATHFILE
        exec_msgs=$(${DAEMON} ${DAEMON_OPTS} 2>&1)
        result=$?

        if [[ $result = 0 || $result = 2 ]]; then
            echo "OK" | tee -a $LOG_PATHFILE
            echo -e "= result: $result\n= ${FUNCNAME[0]}(): '$exec_msgs'" >> $LOG_PATHFILE
        else
            echo -e "failed!\n= result: $result\n= ${FUNCNAME[0]}(): '$exec_msgs'" | tee -a $LOG_PATHFILE
            returncode=1
        fi
        [[ $ui_port -gt 0 ]] && echo "= service configured for HTTP${secure} port: $ui_port" | tee -a $LOG_PATHFILE
    else
        echo "! unable to start - no web service port found" | tee -a $LOG_PATHFILE
        returncode=2
    fi

    return $returncode

    }

StopQPKG()
    {

    local maxwait=100

    ! QPKGIsActive && return

    PID=$(<"$STORED_PID_PATHFILE"); acc=0

    kill $PID
    echo -n "* stopping ($QPKG_NAME) with SIGTERM: " | tee -a $LOG_PATHFILE; echo -n "waiting for upto $maxwait seconds: "

    while true; do
        while [[ -d /proc/$PID ]]; do
            sleep 1
            ((acc++))
            echo -n "$acc, "

            if [[ $acc -ge $maxwait ]]; then
                echo -n "failed! " | tee -a $LOG_PATHFILE
                kill -9 $PID
                echo "sent SIGKILL." | tee -a $LOG_PATHFILE
                rm -f "$STORED_PID_PATHFILE"
                break 2
            fi
        done

        rm -f "$STORED_PID_PATHFILE"
        echo "OK"; echo "stopped OK in $acc seconds" >> $LOG_PATHFILE
        break
    done

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

    local TIMEOUT=300

    if [[ ! -e /opt/Entware.sh && ! -e /opt/Entware-3x.sh && ! -e /opt/Entware-ng.sh ]]; then
        (
            for ((count=1; count<=TIMEOUT; count++)); do
                sleep 1
                [[ -e /opt/Entware.sh || -e /opt/Entware-3x.sh || -e /opt/Entware-ng.sh ]] && { echo "waited for Entware for $count seconds" >> $LOG_PATHFILE; true; exit ;}
            done
            false
        )

        if [[ $? -ne 0 ]]; then
            echo "Entware not found! [TIMEOUT = $TIMEOUT seconds]" | tee -a $LOG_PATHFILE
            write_log "[$(basename $0)] Can't continue: Entware not found! (timeout)" 1
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
    case $1 in
        start)
            echo -e "$(SessionSeparator 'start requested')\n= $(date)" >> $LOG_PATHFILE
            StartQPKG || errorcode=1
            ;;
        stop)
            echo -e "$(SessionSeparator 'stop requested')\n= $(date)" >> $LOG_PATHFILE
            StopQPKG || errorcode=1
            ;;
        restart)
            echo -e "$(SessionSeparator 'restart requested')\n= $(date)" >> $LOG_PATHFILE
            StopQPKG; StartQPKG || errorcode=1
            ;;
        *)
            echo "Usage: $0 {start|stop|restart}"
            ;;
    esac
fi

exit $errorcode
