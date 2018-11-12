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
    GIT_CMD=/opt/bin/git
    export PYTHONPATH=$DAEMON
    export PATH=/opt/bin:/opt/sbin:${PATH}

    if [[ -z $LANG ]]; then
        export LANG=en_US.UTF-8
        export LC_ALL=en_US.UTF-8
        export LC_CTYPE=en_US.UTF-8
    fi

    WaitForEntware
    errorcode=0
    return 0

    }

QPKGIsActive()
    {

    # $? = 0 if $QPKG_NAME is active
    # $? = 1 if $QPKG_NAME is not active

    local returncode=0
    local active=false
    local msg=''

    [[ -f $STORED_PID_PATHFILE ]] && { PID=$(cat "$STORED_PID_PATHFILE"); [[ -d /proc/$PID ]] && active=true ;}

    if [[ $active = true ]]; then
        msg="= ($QPKG_NAME) is active"
    else
        msg="= ($QPKG_NAME) is not active"
        returncode=1
    fi

    echo "$msg" | tee -a "$LOG_PATHFILE"
    return $returncode

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
        msg="failed!\nresult=[$result]"
        echo -e "$msg\n${exec_messages}" | tee -a "$LOG_PATHFILE"
        returncode=1
    fi

    return $returncode

    }

StartQPKG()
    {

    local returncode=0
    local msg=''
    local exec_msgs=''

    [[ -e $STORED_PID_PATHFILE ]] && StopQPKG

    cd "$QPKG_GIT_PATH"

    echo -n "* starting ($QPKG_NAME): " | tee -a "$LOG_PATHFILE"
    exec_messages="$(${DAEMON} ${DAEMON_OPTS} 2>&1)"
    result=$?

    if [[ $result -eq 0 ]]; then
        msg='OK'
        echo -e "$msg" | tee -a "$LOG_PATHFILE"
        echo -e "${exec_messages}" >> "$LOG_PATHFILE"
    else
        msg="failed!\nresult=[$result]"
        echo -e "$msg\n${exec_messages}" | tee -a "$LOG_PATHFILE"
        returncode=1
    fi

    return $returncode

    }

StopQPKG()
    {

    [[ ! -e $STORED_PID_PATHFILE ]] && return

    local maxwait=100
    PID=$(<"$STORED_PID_PATHFILE"); i=0

    kill $PID
    echo -n "* stopping ($QPKG_NAME) with SIGTERM: " | tee -a "$LOG_PATHFILE"; echo -n "waiting for upto $maxwait seconds: "

    while true; do
        while [[ -d /proc/$PID ]]; do
            sleep 1
            let i+=1
            echo -n "$i, "
            if [[ $i -ge $maxwait ]]; then
                echo -n "failed! " | tee -a "$LOG_PATHFILE"
                kill -9 $PID
                echo "sent SIGKILL." | tee -a "$LOG_PATHFILE"
                break 2
            fi
        done

        echo "OK"; echo "stopped OK in $i seconds" >> "$LOG_PATHFILE"
        break
    done

    rm -f "$STORED_PID_PATHFILE"

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
                [[ -e /opt/Entware.sh || -e /opt/Entware-3x.sh || -e /opt/Entware-ng.sh ]] && { echo "waited for Entware for $count seconds" >> "$LOG_PATHFILE"; true; exit ;}
            done
            false
        )

        if [[ $? -ne 0 ]]; then
            echo "Entware not found! [TIMEOUT = $TIMEOUT seconds]" | tee -a "$LOG_PATHFILE"
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
    case "$1" in
        start)
            echo -e "$(SessionSeparator "start requested")\n= $(date)" >> "$LOG_PATHFILE"
            ! QPKGIsActive && UpdateQpkg; StartQPKG || errorcode=1
            ;;

        stop)
            echo -e "$(SessionSeparator "stop requested")\n= $(date)" >> "$LOG_PATHFILE"
            QPKGIsActive && StopQPKG || errorcode=1
            ;;

        restart)
            echo -e "$(SessionSeparator "restart requested")\n= $(date)" >> "$LOG_PATHFILE"
            QPKGIsActive && StopQPKG; UpdateQpkg; StartQPKG || errorcode=1
            ;;

        *)
            echo "Usage: $0 {start|stop|restart}"
            ;;
    esac
fi

exit $errorcode

