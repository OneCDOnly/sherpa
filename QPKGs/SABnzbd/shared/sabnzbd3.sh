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

    readonly QPKG_NAME=SABnzbd
    readonly SOURCE_URL=http://github.com/sabnzbd/sabnzbd.git
    readonly SOURCE_BRANCH=develop
    readonly SOURCE_DEPTH=shallow               # 'shallow' (depth 1) or 'single-branch' (note: 'shallow' implies a 'single-branch' too)
    readonly PYTHON=/opt/bin/python3
    local -r TARGET_SCRIPT=SABnzbd.py

    # cherry-pick required binaries
    readonly BASENAME_CMD=/usr/bin/basename
    readonly CURL_CMD=/sbin/curl
    readonly DIRNAME_CMD=/usr/bin/dirname
    readonly GETCFG_CMD=/sbin/getcfg
    readonly GREP_CMD=/bin/grep
    readonly LESS_CMD=/opt/bin/less
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
    readonly STORED_PID_PATHFILE=/var/run/$QPKG_NAME.pid
    readonly INIT_LOG_PATHFILE=/var/log/$QPKG_NAME.log
    local -r BACKUP_PATH=$($GETCFG_CMD SHARE_DEF defVolMP -f /etc/config/def_share.info)/.qpkg_config_backup
    readonly BACKUP_PATHFILE=$BACKUP_PATH/$QPKG_NAME.config.tar.gz
    readonly LAUNCHER="$PYTHON $TARGET_SCRIPT --daemon --browser 0 --config-file $QPKG_INI_PATHFILE --pidfile $STORED_PID_PATHFILE"
    export PYTHONPATH=$PYTHON
    export PATH=/opt/bin:/opt/sbin:$PATH
    ui_port=0
    UI_secure=''

    if [[ -z $LANG ]]; then
        export LANG=en_US.UTF-8
        export LC_ALL=en_US.UTF-8
        export LC_CTYPE=en_US.UTF-8
    fi

    WaitForEntware
    errorcode=0

    if [[ ! -f $QPKG_INI_PATHFILE && -f $QPKG_INI_DEFAULT_PATHFILE ]]; then
        FormatAsDisplayErrorWriteToLog 'no settings file found: using default'
        cp $QPKG_INI_DEFAULT_PATHFILE $QPKG_INI_PATHFILE
    fi

    ChoosePort

    [[ ! -d $BACKUP_PATH ]] && mkdir -p $BACKUP_PATH

    return 0

    }

StartQPKG()
    {

    local exec_msgs=''
    local result=0

    DaemonIsActive && return

    PullGitRepo $QPKG_NAME "$SOURCE_URL" "$SOURCE_BRANCH" "$SOURCE_DEPTH" $QPKG_PATH && UpdateLanguages
    PullGitRepo nzbToMedia 'http://github.com/clinton-hall/nzbToMedia.git' master shallow "/share/$($GETCFG_CMD SHARE_DEF defDownload -d Qdownload -f /etc/config/def_share.info)"

    cd $QPKG_PATH/$QPKG_NAME || return 1

    if [[ $ui_port -eq 0 ]]; then
        FormatAsDisplayErrorSystemLog 'unable to start daemon as no UI port was specified'
        return 1
    elif ! PortAvailable $ui_port; then
        FormatAsDisplayErrorSystemLog "unable to start daemon as port $ui_port is already in use"
        return 1
    fi

    $SETCFG_CMD $QPKG_NAME Web_Port $ui_port -f $QTS_QPKG_CONF_PATHFILE

    RunAndLog 'launching' "$LAUNCHER" log:unconditional || return 1

    if PortResponds $ui_port; then
        FormatAsDisplayOutcomeWriteToLog "$(FormatAsPackageName $QPKG_NAME) daemon UI is now listening on HTTP${UI_secure} port: $ui_port"
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
    FormatAsDisplayWriteToLog_SameLine '* stopping daemon with SIGTERM: '
    DisplayWrite_SameLine "(waiting for upto $MAX_WAIT_SECONDS_STOP seconds): "

    while true; do
        while [[ -d /proc/$PID ]]; do
            sleep 1
            ((acc++))
            DisplayWrite_SameLine "$acc, "

            if [[ $acc -ge $MAX_WAIT_SECONDS_STOP ]]; then
                FormatAsDisplayWriteToLog_SameLine "failed! "
                kill -9 $PID 2> /dev/null
                FormatAsDisplayWriteToLog 'sent SIGKILL.'
                rm -f $STORED_PID_PATHFILE
                break 2
            fi
        done

        rm -f $STORED_PID_PATHFILE
        DisplayWrite 'OK'
        LogWrite "stopped OK in $acc seconds"
        break
    done

    }

BackupConfig()
    {

    RunAndLog 'updating configuration backup' "$TAR_CMD --create --gzip --file=$BACKUP_PATHFILE --directory=$QPKG_PATH/config ." log:unconditional

    }

RestoreConfig()
    {

    if [[ ! -f $BACKUP_PATHFILE ]]; then
        FormatAsDisplayErrorSystemLog 'unable to restore configuration: no backup file was found!'
        return 1
    fi

    StopQPKG
    RunAndLog 'restoring configuration backup' "$TAR_CMD --extract --gzip --file=$BACKUP_PATHFILE --directory=$QPKG_PATH/config" log:unconditional
    StartQPKG

    }

UpdateLanguages()
    {

    # run [tools/make_mo.py] if SABnzbd version number has changed since last run

    local olddir=$PWD
    local version_current_pathfile=$QPKG_PATH/$QPKG_NAME/sabnzbd/version.py
    local version_store_pathfile=$($DIRNAME_CMD $version_current_pathfile)/version.stored
    local version_current_number=$($GREP_CMD '__version__ =' $version_current_pathfile | $SED_CMD 's|^.*"\(.*\)"|\1|')

    [[ -e $version_store_pathfile && $version_current_number = $(<$version_store_pathfile) ]] && return 0

    cd $QPKG_PATH/$QPKG_NAME || return 1

    RunAndLog 'updating language support' "$PYTHON tools/make_mo.py" && echo "$version_current_number" > $version_store_pathfile

    cd $olddir || return 1

    }

DaemonIsActive()
    {

    # $? = 0 if $QPKG_NAME is active
    # $? = 1 if $QPKG_NAME is not active

    if [[ -f $STORED_PID_PATHFILE && -d /proc/$(<$STORED_PID_PATHFILE) ]] && (PortResponds $ui_port); then
        FormatAsDisplayOutcomeWriteToLog 'daemon is active'
        return 0
    else
        FormatAsDisplayOutcomeWriteToLog 'daemon is not active'
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
    local msg="updating $(FormatAsPackageName $1) daemon from remote repository"

    if [[ ! -d ${QPKG_GIT_PATH}/.git ]]; then
        RunAndLog "$msg" "$GIT_CMD clone --branch $3 $depth -c advice.detachedHead=false $GIT_HTTPS_URL $QPKG_GIT_PATH || $GIT_CMD clone --branch $3 $depth -c advice.detachedHead=false $GIT_HTTP_URL $QPKG_GIT_PATH"
    else
        RunAndLog "$msg" "cd $QPKG_GIT_PATH && $GIT_CMD pull"
    fi

    # might need to use these instead of 'git pull' if we keep seeing a 'Tell me who you are' error :(
    #   git fetch
    #   git reset --hard origin/master

    }

CleanLocalClone()
    {

    # for the rare occasions the local repo becomes corrupt, it needs to be deleted and cloned again from source.

    [[ -z $QPKG_PATH || -z $QPKG_NAME ]] && return 1

    RunAndLog 'cleaning local repo' "rm -r $QPKG_PATH/$QPKG_NAME"

    }

RunAndLog()
    {

    # $1 processing message
    # $2 command(s) to run
    # $3 'log:unconditional' (optional) - if specified, the result of the command is recorded in the QTS system log.
    #                                   - if unspecified, only warnings are logged in the QTS system log.

    [[ -z $1 || -z $2 ]] && return 1

    local exec_msgs=''
    local result=0

    FormatAsDisplayWriteToLog_SameLine "* $1: "
    exec_msgs=$(eval "$2" 2>&1)
    result=$?

    if [[ $result = 0 ]]; then
        FormatAsDisplayWriteToLog 'OK'
        [[ $3 = log:unconditional ]] && WriteInfoToSystemLog "$1: OK."
    else
        FormatAsDisplayWriteToLog 'failed!'
        FormatAsDisplayWriteToLog "$(FormatAsFuncMessages "$exec_msgs")"
        FormatAsDisplayWriteToLog "$(FormatAsResult $result)"
        WriteWarningToSystemLog "A problem occurred while $1. Check $(FormatAsFileName "$INIT_LOG_PATHFILE") for more details."
        return 1
    fi

    }

ChoosePort()
    {

    ui_port=$(UIPortSecure)

    if [[ $ui_port -gt 0 ]]; then
        UI_secure='S'
    else
        ui_port=$(UIPort)
    fi

    }

UIPort()
    {

    # get HTTP port
    # stdout = HTTP port (if used) or 0 if none found

    $GETCFG_CMD misc port -d 0 -f $QPKG_INI_PATHFILE

    }

UIPortSecure()
    {

    # get HTTPS port
    # stdout = HTTPS port (if used) or 0 if none found

    if [[ $($GETCFG_CMD misc enable_https -d 0 -f $QPKG_INI_PATHFILE) = 1 ]]; then
        $GETCFG_CMD misc https_port -d 0 -f $QPKG_INI_PATHFILE
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

    local -r MAX_WAIT_SECONDS_START=100
    local acc=0

    FormatAsDisplayWriteToLog_SameLine "* checking daemon UI port $ui_port response: "
    DisplayWrite_SameLine "(waiting for upto $MAX_WAIT_SECONDS_START seconds): "

    while true; do
        while ! $CURL_CMD --silent --fail localhost:$1 >/dev/null; do
            sleep 1
            ((acc++))
            DisplayWrite_SameLine "$acc, "

            if [[ $acc -ge $MAX_WAIT_SECONDS_START ]]; then
                FormatAsDisplayWriteToLog 'failed!'
                WriteErrorToSystemLog "Daemon UI port $ui_port failed to respond after $acc seconds"
                return 1
            fi
        done
        DisplayWrite 'OK'
        LogWrite "daemon UI responded after $acc seconds"
        return 0
    done

    }

FormatAsPackageName()
    {

    echo "'$1'"

    }

FormatAsFileName()
    {

    echo "($1)"

    }

FormatAsStdout()
    {

    echo "= output: \"$1\""

    }

FormatAsExitcode()
    {

    echo "[$1]"

    }

FormatAsResult()
    {

    echo "= result: $(FormatAsExitcode "$1")"

    }

FormatAsFuncMessages()
    {

    echo "= ${FUNCNAME[1]}()"
    FormatAsStdout "$1"

    }

FormatAsDisplayOutcomeWriteToLog()
    {

    echo "= $1" | $TEE_CMD -a $INIT_LOG_PATHFILE

    }

FormatAsDisplayErrorWriteToLog()
    {

    FormatAsDisplayWriteToLog "! $1"

    }

FormatAsDisplayErrorSystemLog()
    {

    FormatAsDisplayErrorWriteToLog "$1"
    WriteErrorToSystemLog "$1"

    }

FormatAsDisplayWriteToLog()
    {

    echo "$1" | $TEE_CMD -a $INIT_LOG_PATHFILE

    }

FormatAsDisplayWriteToLog_SameLine()
    {

    echo -n "$1" | $TEE_CMD -a $INIT_LOG_PATHFILE

    }

FormatAsDisplayError()
    {

    DisplayWrite "! $1"

    }

WriteInfoToSystemLog()
    {

    SystemLogWrite "$1" 4

    }

WriteWarningToSystemLog()
    {

    SystemLogWrite "$1" 2

    }

WriteErrorToSystemLog()
    {

    SystemLogWrite "$1" 1

    }

DisplayWrite()
    {

    echo "$1"

    }

DisplayWrite_SameLine()
    {

    echo -n "$1"

    }

LogWrite()
    {

    echo "$1" >> $INIT_LOG_PATHFILE

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
                [[ -e /opt/Entware.sh || -e /opt/Entware-3x.sh || -e /opt/Entware-ng.sh ]] && { LogWrite "waited for Entware for $count seconds"; true; exit ;}
            done
            false
        )

        if [[ $? -ne 0 ]]; then
            FormatAsDisplayErrorSystemLog "Entware not found! (exceeded timeout: $MAX_WAIT_SECONDS_ENTWARE seconds)"
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
        LogWrite "$(SessionSeparator "$1 requested")"
        LogWrite "= $(date)"
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
            DaemonIsActive $QPKG_NAME || errorcode=1
            ;;
        b|backup)
            BackupConfig || errorcode=1
            ;;
        restore)
            RestoreConfig || errorcode=1
            ;;
        clean)
            StopQPKG && CleanLocalClone && StartQPKG || errorcode=1
            ;;
        h|history)
            if [[ -e $INIT_LOG_PATHFILE ]]; then
                $LESS_CMD -rMK -PM' use arrow-keys to scroll up-down left-right, press Q to quit' $INIT_LOG_PATHFILE
            else
                DisplayWrite "Init log not found: $(FormatAsFileName $INIT_LOG_PATHFILE)"
            fi
            ;;
        *)
            DisplayWrite "Usage: $0 {start|stop|restart|status|backup|restore|clean|history}"
            ;;
    esac
fi

exit $errorcode
