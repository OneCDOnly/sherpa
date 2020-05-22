#!/usr/bin/env bash
####################################################################################
# sabnzbd3.sh
#
# Copyright (C) 2020 OneCD [one.cd.only@gmail.com]
#
# so, blame OneCD if it all goes horribly wrong. ;)
#
# For more info: https://forum.qnap.com/viewtopic.php?f=320&t=132373
####################################################################################

Init()
    {

    QPKG_NAME=SABnzbd
    local TARGET_SCRIPT=SABnzbd.py

    QTS_QPKG_CONF_PATHFILE=/etc/config/qpkg.conf
    QPKG_PATH=$(/sbin/getcfg $QPKG_NAME Install_Path -f $QTS_QPKG_CONF_PATHFILE)
    NZBMEDIA_PATH=/share/$(/sbin/getcfg SHARE_DEF defDownload -d Qdownload -f /etc/config/def_share.info)
    QPKG_INI_PATHFILE=$QPKG_PATH/config/config.ini
    local QPKG_INI_DEFAULT_PATHFILE=$QPKG_INI_PATHFILE.def
    STORED_PID_PATHFILE=/tmp/$QPKG_NAME.pid
    INIT_LOG_PATHFILE=/var/log/$QPKG_NAME.log
    BACKUP_PATHFILE=$(getcfg SHARE_DEF defVolMP -f /etc/config/def_share.info)/.@backup_config/$QPKG_NAME.userdata.tar.gz
    local DAEMON=/opt/bin/python3
    LAUNCHER="$DAEMON $TARGET_SCRIPT --daemon --browser 0 --config-file $QPKG_INI_PATHFILE --pidfile $STORED_PID_PATHFILE"
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

    PullGitRepo $QPKG_NAME 'http://github.com/sabnzbd/sabnzbd.git' develop $QPKG_PATH && UpdateLanguages
    PullGitRepo nzbToMedia 'http://github.com/clinton-hall/nzbToMedia.git' master $NZBMEDIA_PATH

    }

UpdateLanguages()
    {

    # run [tools/make_mo.py] if SABnzbd version number has changed since last run

    local exec_msgs=''
    local olddir=$PWD
    local version_current_pathfile=$QPKG_PATH/$QPKG_NAME/sabnzbd/version.py
    local version_store_pathfile=$(dirname $version_current_pathfile)/version.stored
    local version_current_number=$(grep '__version__ =' $version_current_pathfile | sed 's|^.*"\(.*\)"|\1|')

    [[ -e $version_store_pathfile && $version_current_number = $(<$version_store_pathfile) ]] && return 0

    echo -n "* updating language support ($QPKG_NAME): " | tee -a $INIT_LOG_PATHFILE
    cd $QPKG_PATH/$QPKG_NAME || return 1
    exec_msgs=$(python3 tools/make_mo.py)
    result=$?

    if [[ $result -eq 0 ]]; then
        echo "$version_current_number" > $version_store_pathfile
        echo "OK" | tee -a $INIT_LOG_PATHFILE
        echo -e "= result: $result\n= ${FUNCNAME[0]}(): '$exec_msgs'" >> $INIT_LOG_PATHFILE
    else
        echo -e "failed!\n= result: $result\n= ${FUNCNAME[0]}(): '$exec_msgs'" | tee -a $INIT_LOG_PATHFILE
    fi

    cd $olddir || return 1

    }

PullGitRepo()
    {

    # $1 = package name
    # $2 = URL to pull/clone from
    # $3 = branch
    # $4 = path to clone into

    local returncode=0
    local exec_msgs=''
    local GIT_CMD=/opt/bin/git

    [[ -z $1 || -z $2 || -z $3 || -z $4 ]] && returncode=1
    SysFilePresent "$GIT_CMD" || { errorcode=1; returncode=1 ;}

    if [[ $returncode = 0 ]]; then
        local QPKG_GIT_PATH="$4/$1"
        local GIT_HTTP_URL="$2"
        local GIT_HTTPS_URL=${GIT_HTTP_URL/http/git}

        echo -n "* updating ($1): " | tee -a $INIT_LOG_PATHFILE
        exec_msgs=$({
            [[ ! -d ${QPKG_GIT_PATH}/.git ]] && { $GIT_CMD clone -b $3 --depth 1 "$GIT_HTTPS_URL" "$QPKG_GIT_PATH" || $GIT_CMD clone -b $3 --depth 1 "$GIT_HTTP_URL" "$QPKG_GIT_PATH" ;}
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

    ui_port=$(UIPortSecure)
    if [[ $ui_port -gt 0 ]]; then
        secure='S'
    else
        ui_port=$(UIPort)
    fi

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

BackupQPKGData()
    {

    echo -n "* creating userdata backup: "
    /bin/tar --create --gzip --file=$BACKUP_PATHFILE --directory=$QPKG_PATH/config .
    [[ $? = 0 ]] && echo "OK" || echo "error!"

    }

RestoreQPKGData()
    {

    echo -n "* restoring userdata backup: "
    if [[ -f $BACKUP_PATHFILE ]]; then
        /bin/tar --extract --gzip --file=$BACKUP_PATHFILE --directory=$QPKG_PATH/config
        [[ $? = 0 ]] && echo "OK" || echo "error!"
    else
        echo "no previous backup file found!"
    fi

    }

UIPort()
    {

    # get HTTP port
    # stdout = HTTP port (if used) or 0 if none found

    /sbin/getcfg misc port -d 0 -f $QPKG_INI_PATHFILE

    }

UIPortSecure()
    {

    # get HTTPS port
    # stdout = HTTPS port (if used) or 0 if none found

    if [[ $(/sbin/getcfg misc enable_https -d 0 -f $QPKG_INI_PATHFILE) = 1 ]]; then
        /sbin/getcfg misc https_port -d 0 -f $QPKG_INI_PATHFILE
    else
        echo 0
    fi

    }

PortAvailable()
    {

    # $1 = port to check
    # $? = 0 if available
    # $? = 1 if already used or unspecified

    if [[ -z $1 ]] || (/usr/sbin/lsof -i :$1 -sTCP:LISTEN 2>&1 >/dev/null); then
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
            StopQPKG; RestoreQPKGData; StartQPKG || errorcode=1
            ;;
        *)
            echo "Usage: $0 {start|stop|restart|backup|restore}"
            ;;
    esac
fi

exit $errorcode
