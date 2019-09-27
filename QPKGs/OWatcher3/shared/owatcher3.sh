#!/usr/bin/env bash

Init()
    {

    QPKG_NAME=OWatcher3
    local TARGET_SCRIPT=watcher.py

    QTS_QPKG_CONF_PATHFILE=/etc/config/qpkg.conf
    QPKG_PATH=$(/sbin/getcfg $QPKG_NAME Install_Path -f $QTS_QPKG_CONF_PATHFILE)
    QPKG_INI_PATHFILE=$QPKG_PATH/config/config.ini
    local QPKG_INI_DEFAULT_PATHFILE=$QPKG_INI_PATHFILE.def
    STORED_PID_PATHFILE=/tmp/$QPKG_NAME.pid
    INIT_LOG_PATHFILE=/var/log/$QPKG_NAME.log
    local DAEMON=/opt/bin/python3
    LAUNCHER="$DAEMON $TARGET_SCRIPT --daemon --userdata $(dirname $QPKG_INI_PATHFILE) --conf $QPKG_INI_PATHFILE --pid $STORED_PID_PATHFILE"
    export PYTHONPATH=$DAEMON
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

    return 0

    }

QPKGIsActive()
    {

    # $? = 0 if $QPKG_NAME is active
    # $? = 1 if $QPKG_NAME is not active

    if [[ -f $STORED_PID_PATHFILE && -d /proc/$(<$STORED_PID_PATHFILE) ]]; then
        echo "= ($QPKG_NAME) is active" | tee -a $INIT_LOG_PATHFILE
        return 0
    else
        echo "= ($QPKG_NAME) is not active" | tee -a $INIT_LOG_PATHFILE
        [[ -f $STORED_PID_PATHFILE ]] && rm $STORED_PID_PATHFILE
        return 1
    fi

    }

UpdateQpkg()
    {

    PullGitRepo $QPKG_NAME 'https://github.com/barbequesauce/Watcher3.git' $QPKG_PATH

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

        echo -n "* updating ($1): " | tee -a $INIT_LOG_PATHFILE
        exec_msgs=$({
            [[ ! -d ${QPKG_GIT_PATH}/.git ]] && { $GIT_CMD clone -b master --depth 1 "$GIT_HTTPS_URL" "$QPKG_GIT_PATH" || $GIT_CMD clone -b master --depth 1 "$GIT_HTTP_URL" "$QPKG_GIT_PATH" ;}
            cd "$QPKG_GIT_PATH" && $GIT_CMD pull
        } 2>&1)
        result=$?

        if [[ $result = 0 ]]; then
            echo "OK" | tee -a $INIT_LOG_PATHFILE
            echo -e "= result: $result\n= ${FUNCNAME[0]}(): '$exec_msgs'" >> $INIT_LOG_PATHFILE
        else
            echo -e "failed!\n= result: $result\n= ${FUNCNAME[0]}(): '$exec_msgs'" | tee -a $INIT_LOG_PATHFILE
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
    local msg=''

    QPKGIsActive && return

    UpdateQpkg

    cd $QPKG_PATH/$QPKG_NAME || return 1

    ui_port=$(UIPort)

    {
        if (PortAvailable $ui_port); then
            if [[ $ui_port -gt 0 ]]; then
                /sbin/setcfg $QPKG_NAME Web_Port $ui_port -f $QTS_QPKG_CONF_PATHFILE

                echo -n "* starting ($QPKG_NAME): "
                exec_msgs=$($LAUNCHER 2>&1)
                result=$?

                if [[ $result = 0 || $result = 2 ]]; then
                    echo "OK"
                    sleep 10             # allow time for daemon to start and claim port
                    ! PortAvailable $ui_port && echo "= service configured for HTTP${secure} port: $ui_port"
                else
                    echo "failed!"
                    echo "= result: $result"
                    echo "= startup messages: '$exec_msgs'"
                    returncode=1
                fi
            else
                msg="unable to start: no UI service port found"
                echo "! $msg"
                /sbin/write_log "[$(basename $0)] $msg" 1
                returncode=2
            fi
        else
            msg="unable to start: UI service port ($ui_port) already in use"
            echo "! $msg"
            /sbin/write_log "[$(basename $0)] $msg" 1
            returncode=2
        fi
    } | tee -a $INIT_LOG_PATHFILE

    return $returncode

    }

StopQPKG()
    {

    local maxwait=100

    ! QPKGIsActive && return

    PID=$(<$STORED_PID_PATHFILE); acc=0

    kill $PID
    echo -n "* stopping ($QPKG_NAME) with SIGTERM: " | tee -a $INIT_LOG_PATHFILE; echo -n "waiting for upto $maxwait seconds: "

    while true; do
        while [[ -d /proc/$PID ]]; do
            sleep 1
            ((acc++))
            echo -n "$acc, "

            if [[ $acc -ge $maxwait ]]; then
                echo -n "failed! " | tee -a $INIT_LOG_PATHFILE
                kill -9 $PID
                echo "sent SIGKILL." | tee -a $INIT_LOG_PATHFILE
                rm -f $STORED_PID_PATHFILE
                break 2
            fi
        done

        rm -f $STORED_PID_PATHFILE
        echo "OK"; echo "stopped OK in $acc seconds" >> $INIT_LOG_PATHFILE
        break
    done

    }

UIPort()
    {

    # get HTTP port
    # stdout = HTTP port (if used) or 0 if none found

    /opt/bin/jq -r .Server.serverport < $QPKG_INI_PATHFILE

    }

PortAvailable()
    {

    # $1 = port to check
    # $? = 0 if available
    # $? = 1 if already used or unspecified

    if [[ -z $1 ]] || (/usr/sbin/lsof -i :$1 2>&1 >/dev/null); then
        return 1
    else
        return 0
    fi

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
                [[ -e /opt/Entware.sh || -e /opt/Entware-3x.sh || -e /opt/Entware-ng.sh ]] && { echo "waited for Entware for $count seconds" >> $INIT_LOG_PATHFILE; true; exit ;}
            done
            false
        )

        if [[ $? -ne 0 ]]; then
            echo "Entware not found! [TIMEOUT = $TIMEOUT seconds]" | tee -a $INIT_LOG_PATHFILE
            /sbin/write_log "[$(basename $0)] can't continue: Entware not found! (timeout)" 1
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
            echo -e "$(SessionSeparator 'start requested')\n= $(date)" >> $INIT_LOG_PATHFILE
            StartQPKG || errorcode=1
            ;;
        stop)
            echo -e "$(SessionSeparator 'stop requested')\n= $(date)" >> $INIT_LOG_PATHFILE
            StopQPKG || errorcode=1
            ;;
        restart)
            echo -e "$(SessionSeparator 'restart requested')\n= $(date)" >> $INIT_LOG_PATHFILE
            StopQPKG; StartQPKG || errorcode=1
            ;;
        *)
            echo "Usage: $0 {start|stop|restart}"
            ;;
    esac
fi

exit $errorcode
