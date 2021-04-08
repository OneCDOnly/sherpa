#!/usr/bin/env bash
####################################################################################
# clamav.sh
#
# Copyright (C) 2021 OneCD [one.cd.only@gmail.com]
#
# so, blame OneCD if it all goes horribly wrong. ;)
#
# For more info: https://forum.qnap.com/viewtopic.php?f=320&t=132373
####################################################################################

Init()
    {

    IsQNAP || return

    # specific environment
    readonly QPKG_NAME=ClamAV
    readonly QPKG_PATH=$(/sbin/getcfg $QPKG_NAME Install_Path -f /etc/config/qpkg.conf)
    readonly MIN_RAM_KB=1572864

    # for online-hosted applications only
    readonly SOURCE_GIT_URL=''
    readonly SOURCE_GIT_BRANCH=''
    # 'shallow' (depth 1) or 'single-branch' (note: 'shallow' implies a 'single-branch' too)
    readonly SOURCE_GIT_DEPTH=''
    readonly TARGET_SCRIPT=''
    readonly PYTHON=''
    readonly QPKG_REPO_PATH=$QPKG_PATH/$QPKG_NAME
    readonly APP_VERSION_PATHFILE=''

    # for Entware binaries only
    readonly ORIG_DAEMON_SERVICE_SCRIPT=''

    # name of file to launch
    readonly DAEMON_PATHFILE=''

    # for local mods only
    readonly TARGET_SERVICE_PATHFILE=/etc/init.d/antivirus.sh
    readonly BACKUP_SERVICE_PATHFILE=$TARGET_SERVICE_PATHFILE.bak

    # remaining environment
    readonly DAEMON_PID_PATHFILE=/var/run/$QPKG_NAME.pid
    readonly APP_VERSION_STORE_PATHFILE=$(/usr/bin/dirname "$APP_VERSION_PATHFILE")/version.stored
    readonly INSTALLED_RAM_KB=$(/bin/grep MemTotal /proc/meminfo | cut -f2 -d':' | /bin/sed 's|kB||;s| ||g')
    readonly QPKG_INI_PATHFILE=''
    readonly QPKG_INI_DEFAULT_PATHFILE=$QPKG_INI_PATHFILE.def
    readonly LAUNCHER=''
    readonly QPKG_VERSION=$(/sbin/getcfg $QPKG_NAME Version -f /etc/config/qpkg.conf)
    readonly SERVICE_STATUS_PATHFILE=/var/run/$QPKG_NAME.last.operation
    readonly SERVICE_LOG_PATHFILE=/var/log/$QPKG_NAME.log
    readonly OPKG_PATH=/opt/bin:/opt/sbin
    local -r BACKUP_PATH=$(/sbin/getcfg SHARE_DEF defVolMP -f /etc/config/def_share.info)/.qpkg_config_backup
    readonly BACKUP_PATHFILE=''
    readonly APPARENT_PATH=/share/$(/sbin/getcfg SHARE_DEF defDownload -d Qdownload -f /etc/config/def_share.info)/$QPKG_NAME
    export PATH="$OPKG_PATH:$(/bin/sed "s|$OPKG_PATH||" <<< "$PATH")"
    [[ -n $PYTHON ]] && export PYTHONPATH=$PYTHON

    if [[ $MIN_RAM_KB != any && $INSTALLED_RAM_KB -lt $MIN_RAM_KB ]]; then
        DisplayErrCommitAllLogs "$(FormatAsPackageName $QPKG_NAME) won't run on this NAS. Not enough RAM. :("
        exit 1
    fi

    # all timeouts are in seconds
    readonly DAEMON_STOP_TIMEOUT=60
    readonly PORT_CHECK_TIMEOUT=60
    readonly GIT_APPEAR_TIMEOUT=300
    readonly LAUNCH_TARGET_APPEAR_TIMEOUT=30
    readonly PID_APPEAR_TIMEOUT=5

    ui_port=0
    ui_port_secure=0
    ui_listening_address=''

    if [[ -z $LANG ]]; then
        export LANG=en_US.UTF-8
        export LC_ALL=en_US.UTF-8
        export LC_CTYPE=en_US.UTF-8
    fi

    UnsetError
    UnsetRestartPending
    EnsureConfigFileExists
    ClearAppCenterNotifier
    [[ -n $ORIG_DAEMON_SERVICE_SCRIPT ]] && DisableOpkgDaemonStart
    LoadAppVersion

    [[ ! -d $BACKUP_PATH ]] && mkdir -p "$BACKUP_PATH"

    return 0

    }

ShowHelp()
    {

    Display "$(ColourTextBrightWhite "$(/usr/bin/basename "$0")") ($QPKG_VERSION) a service control script for the $(FormatAsPackageName $QPKG_NAME) QPKG"
    Display
    Display "Usage: $0 [OPTION]"
    Display
    Display '[OPTION] may be any one of the following:'
    Display
    DisplayAsHelp 'start' "launch $(FormatAsPackageName $QPKG_NAME) if not already running."
    DisplayAsHelp 'stop' "shutdown $(FormatAsPackageName $QPKG_NAME) if running."
    DisplayAsHelp 'restart' "stop, then start $(FormatAsPackageName $QPKG_NAME)."
    DisplayAsHelp 'status' "check if $(FormatAsPackageName $QPKG_NAME) is still running. Returns \$? = 0 if running, 1 if not."
    [[ -n $BACKUP_PATHFILE ]] && DisplayAsHelp 'backup' "backup the current $(FormatAsPackageName $QPKG_NAME) configuration to persistent storage."
    [[ -n $BACKUP_PATHFILE ]] && DisplayAsHelp 'restore' "restore a previously saved configuration from persistent storage. $(FormatAsPackageName $QPKG_NAME) will be stopped, then restarted."
    [[ -n $QPKG_INI_PATHFILE ]] && DisplayAsHelp 'reset-config' "delete the application configuration, databases and history. $(FormatAsPackageName $QPKG_NAME) will be stopped, then restarted."
    [[ $QPKG_NAME = SABnzbd ]] && DisplayAsHelp 'import' "create a backup of an installed $(FormatAsPackageName SABnzbdplus) config and restore it into $(FormatAsPackageName $QPKG_NAME)."
    [[ -n $SOURCE_GIT_URL ]] && DisplayAsHelp 'clean' "wipe the current local copy of $(FormatAsPackageName $QPKG_NAME), and download it again from remote source. Configuration will be retained."
    DisplayAsHelp 'log' 'display this service script runtime log.'
    DisplayAsHelp 'version' 'display the package version number.'
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

        "$TARGET_SERVICE_PATHFILE" restart
    fi

    /bin/grep -q freshclam /etc/profile || echo "alias freshclam='/opt/sbin/freshclam -u admin --config-file=/etc/config/freshclam.conf --datadir=/share/$(/sbin/getcfg Public path -f /etc/config/smb.conf | cut -d '/' -f 3)/.antivirus/usr/share/clamav -l /tmp/.freshclam.log'" >> /etc/profile

    DisplayCommitToLog 'start package: OK'
    EnableThisQPKGIcon

    return 0

    }

StopQPKG()
    {

    # this function is customised depending on the requirements of the packaged application

    IsError && return

    if [[ -e $BACKUP_SERVICE_PATHFILE ]]; then
        mv "$BACKUP_SERVICE_PATHFILE" "$TARGET_SERVICE_PATHFILE"

        "$TARGET_SERVICE_PATHFILE" restart
    fi

    /bin/sed -i '/freshclam/d' /etc/profile

    DisplayCommitToLog 'stop package: OK'
    DisableThisQPKGIcon

    return 0

    }

BackupConfig()
    {

    CommitOperationToLog
    ExecuteAndLog 'update configuration backup' "/bin/tar --create --gzip --file=$BACKUP_PATHFILE --directory=$QPKG_PATH/config ." log:everything

    }

RestoreConfig()
    {

    CommitOperationToLog

    if [[ ! -f $BACKUP_PATHFILE ]]; then
        DisplayErrCommitAllLogs 'unable to restore configuration: no backup file was found!'
        SetError
        return 1
    fi

    StopQPKG
    ExecuteAndLog 'restore configuration backup' "/bin/tar --extract --gzip --file=$BACKUP_PATHFILE --directory=$QPKG_PATH/config" log:everything
    StartQPKG

    }

ResetConfig()
    {

    CommitOperationToLog

    StopQPKG
    ExecuteAndLog 'reset configuration' "mv $QPKG_INI_DEFAULT_PATHFILE $QPKG_PATH; rm -rf $QPKG_PATH/config/*; mv $QPKG_PATH/$(/usr/bin/basename "$QPKG_INI_DEFAULT_PATHFILE") $QPKG_INI_DEFAULT_PATHFILE" log:everything
    StartQPKG

    }

ClearAppCenterNotifier()
    {

    # KLUDGE: 'clean' QTS 4.5.1 App Center notifier status as it's frequently incorrect
    [[ -e /sbin/qpkg_cli ]] && /sbin/qpkg_cli --clean "$QPKG_NAME" &>/dev/null

    return 0

    }

LoadUIPorts()
    {

    # If user changes ports via app UI, must first 'stop' application on old ports, then 'start' on new ports

    case $1 in
        app)
            # Read the current application UI ports from application configuration
            DisplayWaitCommitToLog 'load UI ports from application:'
            ui_port=$(/sbin/getcfg '' ControlPort -d 0 -f "$QPKG_INI_PATHFILE")
            ui_port_secure=$(/sbin/getcfg '' SecurePort -d 0 -f "$QPKG_INI_PATHFILE")
            DisplayCommitToLog 'OK'
            ;;
        qts)
            # Read the current application UI ports from QTS App Center
            DisplayWaitCommitToLog 'load UI ports from QPKG icon:'
            ui_port=$(/sbin/getcfg $QPKG_NAME Web_Port -d 0 -f "/etc/config/qpkg.conf")
            ui_port_secure=$(/sbin/getcfg $QPKG_NAME Web_SSL_Port -d 0 -f "/etc/config/qpkg.conf")
            DisplayCommitToLog 'OK'
            ;;
        *)
            DisplayErrCommitAllLogs "unable to load UI ports: action '$1' unrecognised"
            SetError
            return 1
            ;;
    esac

    if [[ $ui_port -eq 0 ]] && IsNotDefaultConfigFound; then
        ui_port=0
        ui_port_secure=0
    fi

    # Always read this from the application configuration
    ui_listening_address=$(/sbin/getcfg '' ControlIP -f "$QPKG_INI_PATHFILE")

    return 0

    }

IsSSLEnabled()
    {

    [[ $(/sbin/getcfg '' SecureControl -d no -f "$QPKG_INI_PATHFILE") = yes ]]

    }

LoadAppVersion()
    {

    # Find the application's internal version number
    # creates a global var: $app_version
    # this is the installed application version (not the QPKG version)

    app_version=''

    if [[ -n $APP_VERSION_PATHFILE && -e $APP_VERSION_PATHFILE ]]; then
        app_version=$(/bin/grep '__version__ =' "$APP_VERSION_PATHFILE" | /bin/sed 's|^.*"\(.*\)"|\1|')
        return
    elif [[ -n $DAEMON_PATHFILE && -e $DAEMON_PATHFILE ]]; then
        app_version=$($DAEMON_PATHFILE --version 2>&1 | /bin/sed 's|nzbget version: ||')
        return
    fi

    return 1

    }

StatusQPKG()
    {

    IsNotError || return

    if IsNotPackageActive; then
        DisableThisQPKGIcon
    else
        EnableThisQPKGIcon
    fi

    }

DisableOpkgDaemonStart()
    {

    if [[ -n $ORIG_DAEMON_SERVICE_SCRIPT && -x $ORIG_DAEMON_SERVICE_SCRIPT ]]; then
        $ORIG_DAEMON_SERVICE_SCRIPT stop        # stop default daemon
        chmod -x $ORIG_DAEMON_SERVICE_SCRIPT    # ... and ensure Entware doesn't re-launch it on startup
    fi

    }

UpdateLanguages()
    {

    # run [tools/make_mo.py] if SABnzbd version number has changed since last run

    LoadAppVersion

    [[ -e $APP_VERSION_STORE_PATHFILE && $(<"$APP_VERSION_STORE_PATHFILE") = "$app_version" && -d $QPKG_REPO_PATH/locale ]] && return 0

    ExecuteAndLog "update $(FormatAsPackageName $QPKG_NAME) language translations" "cd $QPKG_REPO_PATH; $PYTHON $QPKG_REPO_PATH/tools/make_mo.py" && SaveAppVersion

    }

ImportFromSAB2()
    {

    CommitOperationToLog

    if [[ -e /etc/init.d/sabnzbd.sh ]]; then
        /etc/init.d/sabnzbd.sh stop
    elif [[ -e /etc/init.d/sabnzbd2.sh ]]; then
        /etc/init.d/sabnzbd2.sh stop
    else
        DisplayCommitToLog "can't find a compatible version of $(FormatAsPackageName SABnzbdplus) to import from"
        return 1
    fi

    ExecuteAndLog "update SABnzbd2 configuration backup for SABnzbd3" "/bin/tar --create --gzip --file=$BACKUP_PATHFILE --directory=$(getcfg SABnzbdplus Install_Path -f /etc/config/qpkg.conf)/config ." log:everything
    eval "$0" restore

    return 0

    }

PullGitRepo()
    {

    # $1 = package name
    # $2 = URL to pull/clone from
    # $3 = remote branch or tag
    # $4 = remote depth: 'shallow' or 'single-branch'
    # $5 = local path to clone into

    [[ -z $1 || -z $2 || -z $3 || -z $4 || -z $5 ]] && return 1

    local -r QPKG_GIT_PATH="$5/$1"
    local -r GIT_HTTP_URL="$2"
    local -r GIT_HTTPS_URL=${GIT_HTTP_URL/http/git}
    local installed_branch=''
    local branch_switch=false
    [[ $4 = shallow ]] && local -r DEPTH=' --depth 1'
    [[ $4 = single-branch ]] && local -r DEPTH=' --single-branch'

    if [[ -d $QPKG_GIT_PATH/.git ]]; then
        installed_branch=$(/opt/bin/git -C "$QPKG_GIT_PATH" branch | /bin/grep '^\*' | /bin/sed 's|^\* ||')

        if [[ $installed_branch != "$3" ]]; then
            branch_switch=true
            DisplayCommitToLog "current git branch: $installed_branch, new git branch: $3"
            [[ $QPKG_NAME = nzbToMedia ]] && BackupConfig
            ExecuteAndLog 'new git branch was specified so clean local repository' "cd /tmp; rm -r $QPKG_GIT_PATH"
        fi
    fi

    if [[ ! -d $QPKG_GIT_PATH/.git ]]; then
        ExecuteAndLog "clone $(FormatAsPackageName "$1") from remote repository" "cd /tmp; /opt/bin/git clone --branch $3 $DEPTH -c advice.detachedHead=false $GIT_HTTPS_URL $QPKG_GIT_PATH || /opt/bin/git clone --branch $3 $DEPTH -c advice.detachedHead=false $GIT_HTTP_URL $QPKG_GIT_PATH"
    else
        ExecuteAndLog "update $(FormatAsPackageName "$1") from remote repository" "cd /tmp; /opt/bin/git -C $QPKG_GIT_PATH fetch; /opt/bin/git -C $QPKG_GIT_PATH reset --hard HEAD; /opt/bin/git -C $QPKG_GIT_PATH merge '@{u}'"
    fi

    installed_branch=$(/opt/bin/git -C "$QPKG_GIT_PATH" branch | /bin/grep '^\*' | /bin/sed 's|^\* ||')
    DisplayCommitToLog "current git branch: $installed_branch"

    [[ $branch_switch = true && $QPKG_NAME = nzbToMedia ]] && RestoreConfig

    return 0

    }

CleanLocalClone()
    {

    # for occasions where the local repo needs to be deleted and cloned again from source.

    CommitOperationToLog

    if [[ -z $QPKG_PATH || -z $QPKG_NAME || -z $SOURCE_GIT_URL ]]; then
        SetError
        return 1
    fi

    StopQPKG
    ExecuteAndLog 'clean local repository' "rm -r $QPKG_REPO_PATH"
    StartQPKG

    }

IsQNAP()
    {

    # is this a QNAP NAS?

    if [[ ! -e /etc/init.d/functions ]]; then
        Display 'QTS functions missing (is this a QNAP NAS?)'
        SetError
        return 1
    fi

    return 0

    }

WaitForGit()
    {

    if WaitForFileToAppear "/opt/bin/git" "$GIT_APPEAR_TIMEOUT"; then
        export PATH="$OPKG_PATH:$(/bin/sed "s|$OPKG_PATH||" <<< "$PATH")"
        return 0
    else
        return 1
    fi

    }

WaitForLaunchTarget()
    {

    local launch_target=''

    if [[ -n $PYTHON ]]; then
        launch_target=$PYTHON
    elif [[ -n $DAEMON_PATHFILE ]]; then
        launch_target=$DAEMON_PATHFILE
    else
        return 0
    fi

    if WaitForFileToAppear "$launch_target" "$LAUNCH_TARGET_APPEAR_TIMEOUT"; then
        return 0
    else
        return 1
    fi

    }

WaitForPID()
    {

    if WaitForFileToAppear "$DAEMON_PID_PATHFILE" "$PID_APPEAR_TIMEOUT"; then
        sleep 1       # wait one more second to allow file to have PID written into it
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
                    Display 'OK'
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

EnsureConfigFileExists()
    {

    [[ -z $QPKG_INI_PATHFILE ]] && return

    if IsNotConfigFound && IsDefaultConfigFound; then
        DisplayCommitToLog 'no configuration file found: using default'
        cp "$QPKG_INI_DEFAULT_PATHFILE" "$QPKG_INI_PATHFILE"
    fi

    }

SaveAppVersion()
    {

    echo "$app_version" > "$APP_VERSION_STORE_PATHFILE"

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

ExecuteAndLog()
    {

    # $1 processing message
    # $2 command(s) to run
    # $3 'log:everything' (optional) - if specified, the result of the command is recorded in the QTS system log.
    #                                - if unspecified, only warnings are logged in the QTS system log.

    if [[ -z $1 || -z $2 ]]; then
        SetError
        return 1
    fi

    local exec_msgs=''
    local result=0
    local returncode=0

    DisplayWaitCommitToLog "$1:"
    exec_msgs=$(eval "$2" 2>&1)
    result=$?

    if [[ $result = 0 ]]; then
        DisplayCommitToLog 'OK'
        [[ $3 = log:everything ]] && CommitInfoToSysLog "$1: OK."
    else
        DisplayCommitToLog 'failed!'
        DisplayCommitToLog "$(FormatAsFuncMessages "$exec_msgs")"
        DisplayCommitToLog "$(FormatAsResult $result)"
        CommitWarnToSysLog "A problem occurred while $1. Check $(FormatAsFileName "$SERVICE_LOG_PATHFILE") for more details."
        returncode=1
    fi

    return $returncode

    }

ReWriteUIPorts()
    {

    # Write the current application UI ports into the QTS App Center configuration

    # QTS App Center requires 'Web_Port' to always be non-zero

    # 'Web_SSL_Port' behaviour:
    #            < -2 = crashes current QTS session. Starts with non-responsive package icons in App Center
    #   missing or -2 = QTS will fallback from HTTPS to HTTP, with a warning to user
    #              -1 = launch QTS UI again (only if WebUI = '/'), else show "QNAP Error" page
    #               0 = "unable to connect"
    #             > 0 = works if logged-in to QTS UI via HTTPS

    # If SSL is enabled, attempting to access with non-SSL via 'Web_Port' results in "connection was reset"

    DisplayWaitCommitToLog 'update QPKG icon with UI ports:'

    /sbin/setcfg $QPKG_NAME Web_Port "$ui_port" -f /etc/config/qpkg.conf

    if IsSSLEnabled; then
        /sbin/setcfg $QPKG_NAME Web_SSL_Port "$ui_port_secure" -f /etc/config/qpkg.conf
    else
        /sbin/setcfg $QPKG_NAME Web_SSL_Port '-2' -f /etc/config/qpkg.conf
    fi

    DisplayCommitToLog 'OK'

    }

CheckPorts()
    {

    local msg=''

    DisplayCommitToLog "daemon listening address: $ui_listening_address"

    if IsSSLEnabled && IsPortSecureResponds $ui_port_secure; then
        msg="HTTPS port $ui_port_secure"
    fi

    if IsNotSSLEnabled || [[ $ui_port -ne $ui_port_secure ]]; then
        # assume $ui_port should be checked too
        if IsPortResponds $ui_port; then
            if [[ -n $msg ]]; then
                msg+=" and HTTP port $ui_port"
            else
                msg="HTTP port $ui_port"
            fi
        fi
    fi

    if [[ -z $msg ]]; then
        DisplayErrCommitAllLogs 'no response on configured port(s)!'
        SetError
        return 1
    fi

    DisplayCommitToLog "$msg: OK"
    ReWriteUIPorts

    return 0

    }

IsQPKGEnabled()
    {

    # input:
    #   $1 = package name to check

    # output:
    #   $? = 0 (true) or 1 (false)

    [[ $(/sbin/getcfg "$1" Enable -u -f /etc/config/qpkg.conf) = 'TRUE' ]]

    }

IsNotQPKGEnabled()
    {

    # input:
    #   $1 = package name to check

    # output:
    #   $? = 0 (true) or 1 (false)

    ! IsQPKGEnabled "$1"

    }

EnableThisQPKGIcon()
    {

    EnableQPKG "$QPKG_NAME"

    }

DisableThisQPKGIcon()
    {

    DisableQPKG "$QPKG_NAME"

    }

EnableQPKG()
    {

    # $1 = package name to enable

    IsNotQPKGEnabled "$1" && ExecuteAndLog 'enable QPKG icon' "qpkg_service enable $1"
    /sbin/setcfg "$QPKG_NAME" Status complete -f /etc/config/qpkg.conf

    }

DisableQPKG()
    {

    IsQPKGEnabled "$QPKG_NAME" && ExecuteAndLog 'disable QPKG icon' "qpkg_service disable $1"

    }

IsNotSSLEnabled()
    {

    ! IsSSLEnabled

    }

IsPackageActive()
    {

    # $? = 0 : package is 'started'
    # $? = 1 : package is 'stopped'

    if [[ -e $BACKUP_SERVICE_PATHFILE ]]; then
        DisplayCommitToLog "package: IS active"
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

IsDaemonActive()
    {

    # $? = 0 : $DAEMON_PATHFILE is in memory
    # $? = 1 : $DAEMON_PATHFILE is not in memory

    if [[ -e $DAEMON_PID_PATHFILE && -d /proc/$(<$DAEMON_PID_PATHFILE) && -n $DAEMON_PATHFILE && $(</proc/"$(<$DAEMON_PID_PATHFILE)"/cmdline) =~ $DAEMON_PATHFILE ]]; then
        DisplayCommitToLog 'daemon: IS active'
        DisplayCommitToLog "daemon PID: $(<$DAEMON_PID_PATHFILE)"
        return
    fi

    DisplayCommitToLog 'daemon: NOT active'
    [[ -f $DAEMON_PID_PATHFILE ]] && rm "$DAEMON_PID_PATHFILE"
    return 1

    }

IsNotDaemonActive()
    {

    # $? = 1 if $QPKG_NAME is active
    # $? = 0 if $QPKG_NAME is not active

    ! IsDaemonActive

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

IsNotSysFilePresent()
    {

    # $1 = pathfile to check

    ! IsSysFilePresent "$1"

    }

IsPortAvailable()
    {

    # $1 = port to check
    # $? = 0 if available
    # $? = 1 if already used

    [[ -z $1 || $1 -eq 0 ]] && return

    if (/usr/sbin/lsof -i :"$1" -sTCP:LISTEN >/dev/null 2>&1); then
        return 1
    else
        return 0
    fi

    }

IsNotPortAvailable()
    {

    # $1 = port to check
    # $? = 1 if available
    # $? = 0 if already used

    ! IsPortAvailable "$1"

    }

IsPortResponds()
    {

    # $1 = port to check
    # $? = 0 if response received
    # $? = 1 if not OK

    if [[ -z $1 || $1 -eq 0 ]]; then
        SetError
        return 1
    fi

    local acc=0

    DisplayWaitCommitToLog "check for UI port $1 response:"
    DisplayWait "(no-more than $PORT_CHECK_TIMEOUT seconds):"

    while ! /sbin/curl --silent --fail --max-time 1 http://localhost:"$1" >/dev/null; do
        sleep 1
        ((acc+=2))
        DisplayWait "$acc,"

        if [[ $acc -ge $PORT_CHECK_TIMEOUT ]]; then
            DisplayCommitToLog 'failed!'
            CommitErrToSysLog "UI port $1 failed to respond after $acc seconds"
            return 1
        fi
    done

    Display 'OK'
    CommitLog "UI port responded after $acc seconds"

    return 0

    }

IsPortSecureResponds()
    {

    # $1 = port to check
    # $? = 0 if response received
    # $? = 1 if not OK or port unspecified

    if [[ -z $1 || $1 -eq 0 ]]; then
        SetError
        return 1
    fi

    local acc=0

    DisplayWaitCommitToLog "check for secure UI port $1 response:"
    DisplayWait "(no-more than $PORT_CHECK_TIMEOUT seconds):"

    while ! /sbin/curl --silent --insecure --fail --max-time 1 https://localhost:"$1" >/dev/null; do
        sleep 1
        ((acc+=2))
        DisplayWait "$acc,"

        if [[ $acc -ge $PORT_CHECK_TIMEOUT ]]; then
            DisplayCommitToLog 'failed!'
            CommitErrToSysLog "secure UI port $1 failed to respond after $acc seconds"
            return 1
        fi
    done

    Display 'OK'
    CommitLog "secure UI port responded after $acc seconds"

    return 0

    }

IsConfigFound()
    {

    # Is there an application configuration file to read from?

    [[ -e $QPKG_INI_PATHFILE ]]

    }

IsNotConfigFound()
    {

    ! IsConfigFound

    }

IsDefaultConfigFound()
    {

    # Is there a default application configuration file to read from?

    [[ -e $QPKG_INI_DEFAULT_PATHFILE ]]

    }

IsNotDefaultConfigFound()
    {

    ! IsDefaultConfigFound

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

IsClean()
    {

    [[ $service_operation = cleaning ]]

    }

IsNotClean()
    {

    ! IsClean

    }

IsRestore()
    {

    [[ $service_operation = restoring ]]

    }

IsNotRestore()
    {

    ! IsRestore

    }

IsReset()
    {

    [[ $service_operation = 'resetting-config' ]]

    }

IsNotReset()
    {

    ! IsReset

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

FormatAsStdout()
    {

    Display "output: \"$1\""

    }

FormatAsResult()
    {

    Display "result: $(FormatAsExitcode "$1")"

    }

FormatAsFuncMessages()
    {

    echo "= ${FUNCNAME[1]}()"
    FormatAsStdout "$1"

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

    printf "  --%-12s  %s\n" "$1" "$2"

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

    CommitLog "$(SessionSeparator "datetime:'$(date)',request:'$service_operation',QPKG:'$QPKG_VERSION',app:'$app_version'")"

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

    [[ $1 -ne 1 ]] && echo 's'

    }

Init

if IsNotError; then
    case $1 in
        start|--start)
            SetServiceOperation starting
            # ensure those still on SickBeard.py are using the updated repo
            if [[ ! -e $DAEMON_PATHFILE && -e $(/usr/bin/dirname "$DAEMON_PATHFILE")/SickBeard.py ]]; then
                CleanLocalClone
            else
                StartQPKG || SetError
            fi
            ;;
        stop|--stop)
            SetServiceOperation stopping
            StopQPKG || SetError
            ;;
        r|-r|restart|--restart)
            SetServiceOperation restarting
            { StopQPKG; StartQPKG ;} || SetError
            ;;
        s|-s|status|--status)
            SetServiceOperation statusing
            StatusQPKG || SetError
            ;;
        b|-b|backup|--backup|backup-config|--backup-config)
            if [[ -n $BACKUP_PATHFILE ]]; then
                SetServiceOperation backing-up
                BackupConfig || SetError
            else
                SetServiceOperation none
                ShowHelp
            fi
            ;;
        reset-config|--reset-config)
            if [[ -n $QPKG_INI_PATHFILE ]]; then
                SetServiceOperation resetting-config
                ResetConfig || SetError
            else
                SetServiceOperation none
                ShowHelp
            fi
            ;;
        restore|--restore|restore-config|--restore-config)
            if [[ -n $BACKUP_PATHFILE ]]; then
                SetServiceOperation restoring
                RestoreConfig || SetError
            else
                SetServiceOperation none
                ShowHelp
            fi
            ;;
        c|-c|clean|--clean)
            if [[ -n $SOURCE_GIT_URL ]]; then
                SetServiceOperation cleaning

                if [[ $QPKG_NAME = nzbToMedia ]]; then
                    # nzbToMedia stores the config file in the repo location, so save it and restore again after new clone is complete
                    { BackupConfig; CleanLocalClone; RestoreConfig ;} || SetError
                else
                    CleanLocalClone || SetError
                fi
            else
                SetServiceOperation none
                ShowHelp
            fi
            ;;
        l|-l|log|--log)
            SetServiceOperation logging
            ViewLog
            ;;
        v|-v|version|--version)
            SetServiceOperation versioning
            Display "$QPKG_VERSION"
            ;;
        import|--import)
            if [[ $QPKG_NAME = SABnzbd ]]; then
                SetServiceOperation importing
                ImportFromSAB2 || SetError
            else
                SetServiceOperation none
                ShowHelp
            fi
            ;;
        *)
            SetServiceOperation none
            ShowHelp
            ;;
    esac
fi

if IsError; then
    SetServiceOperationResultFailed
    exit 1
fi

SetServiceOperationResultOK
exit
