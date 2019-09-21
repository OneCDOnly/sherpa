#!/usr/bin/env bash

Init()
    {

    QPKG_NAME=NZBGet

    QPKG_CONF_PATHFILE=/etc/config/qpkg.conf
    QPKG_PATH=$(/sbin/getcfg $QPKG_NAME Install_Path -f $QPKG_CONF_PATHFILE)
    SETTINGS_PATHFILE=$QPKG_PATH/config/config.ini
    local SETTINGS_DEFAULT_PATHFILE=$SETTINGS_PATHFILE.def
    local SETTINGS="--configfile $SETTINGS_PATHFILE"
    DAEMON_OPTS="--daemon $SETTINGS"
    LOG_PATHFILE=/var/log/$QPKG_NAME.log
    DAEMON=/opt/bin/nzbget
    export PATH=/opt/bin:/opt/sbin:$PATH

    if [[ -z $LANG ]]; then
        export LANG=en_US.UTF-8
        export LC_ALL=en_US.UTF-8
        export LC_CTYPE=en_US.UTF-8
    fi

    WaitForEntware
    errorcode=0
    [[ ! -f $SETTINGS_PATHFILE && -f $SETTINGS_DEFAULT_PATHFILE ]] && { echo "! no settings file found - using default"; cp "$SETTINGS_DEFAULT_PATHFILE" "$SETTINGS_PATHFILE" ;}
    if [[ -x /opt/etc/init.d/S75nzbget ]]; then
        /opt/etc/init.d/S75nzbget stop          # stop default daemon
        chmod -x /opt/etc/init.d/S75nzbget      # and ensure Entware doesn't relaunch daemon on startup
    fi

    return 0

    }

QPKGIsActive()
    {

    # $? = 0 if $QPKG_NAME is active
    # $? = 1 if $QPKG_NAME is not active

    if ( ps ax | grep $DAEMON | grep -vq grep ); then
        echo "= ($QPKG_NAME) is active" | tee -a $LOG_PATHFILE
        return 0
    else
        echo "= ($QPKG_NAME) is not active" | tee -a $LOG_PATHFILE
        return 1
    fi

    }

StartQPKG()
    {

    local returncode=0
    local exec_msgs=''
    local ui_port=''
    local secure=''

    QPKGIsActive && return

    if [[ $(/sbin/getcfg '' SecureControl -d no -f "$SETTINGS_PATHFILE") = yes ]]; then
        ui_port=$(/sbin/getcfg '' SecurePort -d 0 -f "$SETTINGS_PATHFILE")
        secure='S'
    else
        ui_port=$(/sbin/getcfg '' ControlPort -d 0 -f "$SETTINGS_PATHFILE")
    fi

    {
        if [[ $ui_port -gt 0 ]]; then
            /sbin/setcfg $QPKG_NAME Web_Port $ui_port -f $QPKG_CONF_PATHFILE

            echo -n "* starting ($QPKG_NAME): "
            exec_msgs=$(${DAEMON} ${DAEMON_OPTS} 2>&1)
            result=$?

            if [[ $result = 0 || $result = 2 ]]; then
                echo "OK"
                echo "= service configured for HTTP${secure} port: $ui_port"
            else
                echo "failed!"
                echo "= result: $result"
                echo "= startup messages: '$exec_msgs'"
                returncode=1
            fi
        else
            echo "! unable to start - no web service port found"
            returncode=2
        fi
    } | tee -a "$LOG_PATHFILE"

    return $returncode

    }

StopQPKG()
    {

    local maxwait=100

    ! QPKGIsActive && return

    killall $(basename $DAEMON)
    echo -n "* stopping ($QPKG_NAME) with SIGTERM: " | tee -a $LOG_PATHFILE; echo -n "waiting for upto $maxwait seconds: "

    while true; do
        while ( ps ax | grep $DAEMON | grep -vq grep ); do
            sleep 1
            ((acc++))
            echo -n "$acc, "

            if [[ $acc -ge $maxwait ]]; then
                echo -n "failed! " | tee -a $LOG_PATHFILE
                killall -9 $(basename $DAEMON)
                echo "sent SIGKILL." | tee -a $LOG_PATHFILE
                break 2
            fi
        done

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
