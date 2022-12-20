#!/usr/bin/env bash
####################################################################################
# clamav.sh
#
# Copyright (C) 2021-2022 OneCD [one.cd.only@gmail.com]
#
# so, blame OneCD if it all goes horribly wrong. ;)
#
# This is a type 4 service-script: https://github.com/OneCDOnly/sherpa/blob/main/QPKG-service-script-types.txt
#
# For more info: https://forum.qnap.com/viewtopic.php?f=320&t=132373
####################################################################################

readonly USER_ARGS_RAW=$*

Init()
    {

    IsQNAP || return

    # service-script environment
    readonly QPKG_NAME=ClamAV
    readonly SCRIPT_VERSION=221221

    # general environment
    readonly QPKG_PATH=$(/sbin/getcfg $QPKG_NAME Install_Path -f /etc/config/qpkg.conf)
    readonly QPKG_VERSION=$(/sbin/getcfg $QPKG_NAME Version -d unknown -f /etc/config/qpkg.conf)
    readonly SERVICE_STATUS_PATHFILE=/var/run/$QPKG_NAME.last.operation
    readonly SERVICE_LOG_PATHFILE=/var/log/$QPKG_NAME.log
    readonly OPKG_PATH=/opt/bin:/opt/sbin
    export PATH="$OPKG_PATH:$(/bin/sed "s|$OPKG_PATH||" <<< "$PATH")"
    readonly DEBUG_LOG_DATAWIDTH=100
    local re=''

    # specific to Entware binaries only
    readonly TARGET_SERVICE_PATHFILE=/etc/init.d/antivirus.sh
    readonly BACKUP_SERVICE_PATHFILE=$TARGET_SERVICE_PATHFILE.bak

    if [[ -z $LANG ]]; then
        export LANG=en_US.UTF-8
        export LC_ALL=en_US.UTF-8
        export LC_CTYPE=en_US.UTF-8
    fi

    UnsetDebug
    UnsetError
    UnsetRestartPending
    LoadAppVersion

    for re in \\bd\\b \\bdebug\\b \\bdbug\\b \\bverbose\\b; do
        if [[ $USER_ARGS_RAW =~ $re ]]; then
            SetDebug
            break
        fi
    done

    IsSupportBackup && [[ -n $BACKUP_PATH && ! -d $BACKUP_PATH ]] && mkdir -p "$BACKUP_PATH"

    return 0

    }

ShowHelp()
    {

    Display "$(ColourTextBrightWhite "$(/usr/bin/basename "$0")") $SCRIPT_VERSION • a service control script for the $(FormatAsPackageName $QPKG_NAME) QPKG"
    Display
    Display "Usage: $0 [OPTION]"
    Display
    Display '[OPTION] may be any one of the following:'
    Display
    DisplayAsHelp start "activate $(FormatAsPackageName $QPKG_NAME) if not already active."
    DisplayAsHelp stop "deactivate $(FormatAsPackageName $QPKG_NAME) if active."
    DisplayAsHelp restart "stop, then start $(FormatAsPackageName $QPKG_NAME)."
    DisplayAsHelp status "check if $(FormatAsPackageName $QPKG_NAME) package is active. Returns \$? = 0 if active, 1 if not."
    IsSupportBackup && DisplayAsHelp backup "backup the current $(FormatAsPackageName $QPKG_NAME) configuration to persistent storage."
    IsSupportBackup && DisplayAsHelp restore "restore a previously saved configuration from persistent storage. $(FormatAsPackageName $QPKG_NAME) will be stopped, then restarted."
    IsSupportReset && DisplayAsHelp reset-config "delete the application configuration, databases and history. $(FormatAsPackageName $QPKG_NAME) will be stopped, then restarted."
    IsSourcedOnline && DisplayAsHelp clean "delete the local copy of $(FormatAsPackageName $QPKG_NAME), and download it again from remote source. Configuration will be retained."
    DisplayAsHelp log 'display the service-script log.'
    IsSourcedOnline && DisplayAsHelp enable-auto-update "auto-update $(FormatAsPackageName $QPKG_NAME) before starting (default)."
    IsSourcedOnline && DisplayAsHelp disable-auto-update "don't auto-update $(FormatAsPackageName $QPKG_NAME) before starting."
    DisplayAsHelp version 'display the package version numbers.'
    Display

    }

StartQPKG()
    {

    # this function is customised depending on the requirements of the packaged application

    IsError && return
    WaitForGit || return

    if [[ ! -e $BACKUP_SERVICE_PATHFILE ]]; then
        cp "$TARGET_SERVICE_PATHFILE" "$BACKUP_SERVICE_PATHFILE"

        # mod base references
        /bin/sed -i 's|/usr/local/bin/clamscan|/opt/sbin/clamscan|' "$TARGET_SERVICE_PATHFILE"
        /bin/sed -i 's|/usr/local/bin/freshclam|/opt/sbin/freshclam|' "$TARGET_SERVICE_PATHFILE"

        # disable dryrun. The new ClamAV engine (0.102.4) doesn't support the '--dryrun' or '--countfile=' options.
        # match second occurrence only. First one is used by Mcafee. Solution here: https://unix.stackexchange.com/a/403272
        /bin/sed -i ':a;N;$!ba; s|/bin/sh -c "$AV_SCAN_PATH $DRY_RUN_OPTIONS --dryrun|#/bin/sh -c "$AV_SCAN_PATH $DRY_RUN_OPTIONS --dryrun|2' "$TARGET_SERVICE_PATHFILE"

        # mod 'clamscan' runtime options
        # match second occurrence only. First one is used by Mcafee.
        /bin/sed -i ':a;N;$!ba; s|OPTIONS="$OPTIONS --countfile=/tmp/antivirous.job.$job_id.scanning"|OPTIONS="$OPTIONS --database=$ANTIVIRUS_CLAMAV"|2' "$TARGET_SERVICE_PATHFILE"

        # mod 'freshclam' runtime options
        /bin/sed -i 's|$FRESHCLAM -u admin -l /tmp/.freshclam.log|$FRESHCLAM -u admin --config-file=$FRESHCLAM_CONFIG --datadir=$ANTIVIRUS_CLAMAV -l /tmp/.freshclam.log|' "$TARGET_SERVICE_PATHFILE"

        "$TARGET_SERVICE_PATHFILE" restart 2>/dev/null
    fi

    /bin/grep -q freshclam /etc/profile || echo "alias freshclam='/opt/sbin/freshclam -u admin --config-file=/etc/config/freshclam.conf --datadir=/share/$(/sbin/getcfg Public path -f /etc/config/smb.conf | cut -d '/' -f 3)/.antivirus/usr/share/clamav -l /tmp/.freshclam.log'" >> /etc/profile

    DisplayCommitToLog 'start: OK'

    return 0

    }

StopQPKG()
    {

    # this function is customised depending on the requirements of the packaged application

    IsError && return

    if [[ -e $BACKUP_SERVICE_PATHFILE ]]; then
        mv "$BACKUP_SERVICE_PATHFILE" "$TARGET_SERVICE_PATHFILE"

        "$TARGET_SERVICE_PATHFILE" restart 2>/dev/null
    fi

    /bin/sed -i '/freshclam/d' /etc/profile

    DisplayCommitToLog 'stop: OK'
    return 0

    }

LoadAppVersion()
    {

    # Find the application's internal version number
    # creates a global var: $app_version
    # this is the installed application version (not the QPKG version)

    if [[ -n ${APP_VERSION_PATHFILE:-} && -e $APP_VERSION_PATHFILE ]]; then
        app_version=$(eval "$APP_VERSION_CMD")
        return 0
    else
        app_version='unknown'
        return 1
    fi

    }

StatusQPKG()
    {

    IsNotError || return

    if IsNotPackageActive; then
        SetError
        return 1
    fi

    return 0

    }

WaitForGit()
    {

    if WaitForFileToAppear '/opt/bin/git' 300; then
        export PATH="$OPKG_PATH:$(/bin/sed "s|$OPKG_PATH||" <<< "$PATH")"
        return 0
    else
        return 1
    fi

    }

WaitForFileToAppear()
    {

    # input:
    #   $1 = pathfilename to watch for
    #   $2 = timeout in seconds (optional) - default 30

    # output:
    #   $? = 0 (file was found) or 1 (file not found: timeout)

    [[ -z $1 ]] && return

    if [[ -n $2 ]]; then
        MAX_SECONDS=$2
    else
        MAX_SECONDS=30
    fi

    if [[ ! -e $1 ]]; then
        DisplayWaitCommitToLog "wait for $(FormatAsFileName "$1") to appear:"
        DisplayWait "(no-more than $MAX_SECONDS seconds):"

        (
            for ((count=1; count<=MAX_SECONDS; count++)); do
                sleep 1
                DisplayWait "$count,"
                if [[ -e $1 ]]; then
                    Display OK
                    CommitLog "visible in $count second$(FormatAsPlural "$count")"
                    true
                    exit    # only this sub-shell
                fi
            done
            false
        )

        if [[ $? -ne 0 ]]; then
            DisplayCommitToLog 'failed!'
            DisplayErrCommitAllLogs "$(FormatAsFileName "$1") not found! (exceeded timeout: $MAX_SECONDS seconds)"
            return 1
        fi
    fi

    DisplayCommitToLog "file $(FormatAsFileName "$1"): exists"

    return 0

    }

ViewLog()
    {

    if [[ -e $SERVICE_LOG_PATHFILE ]]; then
        if [[ -e /opt/bin/less ]]; then
            LESSSECURE=1 /opt/bin/less +G --quit-on-intr --tilde --LINE-NUMBERS --prompt ' use arrow-keys to scroll up-down left-right, press Q to quit' "$SERVICE_LOG_PATHFILE"
        else
            cat --number "$SERVICE_LOG_PATHFILE"
        fi
    else
        Display "service log not found: $(FormatAsFileName "$SERVICE_LOG_PATHFILE")"
        SetError
        return 1
    fi

    return 0

    }

IsPackageActive()
    {

    # $? = 0 : package is 'started'
    # $? = 1 : package is 'stopped'

    if [[ -e $BACKUP_SERVICE_PATHFILE ]]; then
        DisplayCommitToLog 'package: IS active'
        return
    fi

    DisplayCommitToLog 'package: NOT active'
    return 1

    }

IsNotPackageActive()
    {

    # $? = 1 if $QPKG_NAME is active
    # $? = 0 if $QPKG_NAME is not active

    ! IsPackageActive

    }

IsSysFilePresent()
    {

    # $1 = pathfile to check

    if [[ -z $1 ]]; then
        SetError
        return 1
    fi

    if [[ ! -e $1 ]]; then
        Display "A required NAS system file is missing: $(FormatAsFileName "$1")"
        SetError
        return 1
    else
        return 0
    fi

    }

IsQNAP()
    {

    # returns 0 if this is a QNAP NAS

    if [[ ! -e /etc/init.d/functions ]]; then
        Display 'QTS functions missing (is this a QNAP NAS?)'
        SetError
        return 1
    fi

    return 0

    }

IsQPKGInstalled()
    {

    # input:
    #   $1 = package name to check

    # output:
    #   $? = 0 (true) or 1 (false)

    /bin/grep -q "^\[${1:?no package name supplied}\]" /etc/config/qpkg.conf

    }

IsQPKGEnabled()
    {

    [[ $(/sbin/getcfg $QPKG_NAME Enable -u -d FALSE -f /etc/config/qpkg.conf) = TRUE ]]

    }

IsNotQPKGEnabled()
    {

    ! IsQPKGEnabled

    }

IsSupportBackup()
    {

    [[ -n ${BACKUP_PATHFILE:-} ]]

    }

IsNotSupportBackup()
    {

    ! IsSupportBackup

    }

IsSupportReset()
    {

    [[ -n ${QPKG_INI_PATHFILE:-} ]]

    }

IsNotSupportReset()
    {

    ! IsSupportReset

    }

IsSourcedOnline()
    {

    [[ -n ${SOURCE_GIT_URL:-} ]]

    }

IsNotSourcedOnline()
    {

    ! IsSourcedOnline

    }


SetServiceOperation()
    {

    service_operation="$1"
    SetServiceOperationResult "$1"

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

SetRestartPending()
    {

    IsRestartPending && return
    _restart_pending_flag=true

    }

UnsetRestartPending()
    {

    IsNotRestartPending && return
    _restart_pending_flag=false

    }

IsRestartPending()
    {

    [[ $_restart_pending_flag = true ]]

    }

IsNotRestartPending()
    {

    [[ $_restart_pending_flag = false ]]

    }

SetDebug()
    {

    debug=true

    }

UnsetDebug()
    {

    debug=false

    }

IsDebug()
    {

    [[ $debug = 'true' ]]

    }

IsNotDebug()
    {

    ! IsDebug

    }

SetError()
    {

    IsError && return
    _error_flag=true

    }

UnsetError()
    {

    IsNotError && return
    _error_flag=false

    }

IsError()
    {

    [[ $_error_flag = true ]]

    }

IsNotError()
    {

    ! IsError

    }

IsRestart()
    {

    [[ $service_operation = restarting ]]

    }

IsNotRestart()
    {

    ! IsRestart

    }

IsNotRestore()
    {

    ! [[ $service_operation = restoring ]]

    }

IsNotLog()
    {

    ! [[ $service_operation = log ]]

    }

IsNotStatus()
    {

    ! [[ $service_operation = status ]]

    }

DisplayErrCommitAllLogs()
    {

    DisplayCommitToLog "$1"
    CommitErrToSysLog "$1"

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

FormatAsLogFilename()
    {

    echo "= log file: '$1'"

    }

FormatAsCommand()
    {

    Display "command: '$1'"

    }

FormatAsStdout()
    {

    Display "output: \"$1\""

    }

FormatAsResult()
    {

    Display "result: $(FormatAsExitcode "$1")"

    }

FormatAsResultAndStdout()
    {

    if [[ ${1:-0} -eq 0 ]]; then
        echo "= result_code: $(FormatAsExitcode "$1") ***** stdout/stderr begins below *****"
    else
        echo "! result_code: $(FormatAsExitcode "$1") ***** stdout/stderr begins below *****"
    fi

    echo "${2:-null}"
    echo '= ***** stdout/stderr is complete *****'

    }

FormatAsFuncMessages()
    {

    echo "= ${FUNCNAME[1]}()"
    FormatAsCommand "$1"
    FormatAsStdout "$2"

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

DisplayAsHelp()
    {

    printf "  --%-19s  %s\n" "$1" "$2"

    }

Display()
    {

    echo "$1"

    }

DisplayWait()
    {

    echo -n "$1 "

    }

CommitOperationToLog()
    {

    CommitLog "$(SessionSeparator "datetime:'$(date)', request:'$service_operation', package:'$QPKG_VERSION', service:'$SCRIPT_VERSION', app:'$app_version'")"

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

    /sbin/write_log "[$QPKG_NAME] $1" "$2"

    }

SessionSeparator()
    {

    # $1 = message

    printf '%0.s>' {1..10}; echo -n " $1 "; printf '%0.s<' {1..10}

    }

ColourTextBrightWhite()
    {

    echo -en '\033[1;97m'"$(ColourReset "$1")"

    }

ColourReset()
    {

    echo -en "$1"'\033[0m'

    }

FormatAsPlural()
    {

    [[ $1 -ne 1 ]] && echo s

    }

Init

if IsNotError; then
    case $1 in
        start|--start)
            if IsNotQPKGEnabled; then
                echo "The $(FormatAsPackageName $QPKG_NAME) QPKG is disabled. Please enable it first with: qpkg_service enable $QPKG_NAME"
                SetError
            fi

            SetServiceOperation starting
            StartQPKG
            ;;
        stop|--stop)
            if IsNotQPKGEnabled; then
                echo "The $(FormatAsPackageName $QPKG_NAME) QPKG is disabled. Please enable it first with: qpkg_service enable $QPKG_NAME"
                SetError
            fi

            SetServiceOperation stopping
            StopQPKG
            ;;
        r|-r|restart|--restart)
            if IsNotQPKGEnabled; then
                echo "The $(FormatAsPackageName $QPKG_NAME) QPKG is disabled. Please enable it first with: qpkg_service enable $QPKG_NAME"
                SetError
            fi

            SetServiceOperation restarting
            StopQPKG
            StartQPKG
            ;;
        s|-s|status|--status)
            SetServiceOperation status
            StatusQPKG
            ;;
        l|-l|log|--log)
            SetServiceOperation logging
            ViewLog
            ;;
        v|-v|version|--version)
            SetServiceOperation versioning
            Display "package: $QPKG_VERSION"
            Display "service: $SCRIPT_VERSION"
            ;;
        *)
            SetServiceOperation none
            ShowHelp
    esac
fi

if IsError; then
    SetServiceOperationResultFailed
    exit 1
fi

SetServiceOperationResultOK
exit
