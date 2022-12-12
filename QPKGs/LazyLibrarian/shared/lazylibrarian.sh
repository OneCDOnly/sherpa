#!/usr/bin/env bash
####################################################################################
# lazylibrarian.sh
#
# Copyright (C) 2017-2022 OneCD [one.cd.only@gmail.com]
#
# so, blame OneCD if it all goes horribly wrong. ;)
#
# This is a type 1 service-script: https://github.com/OneCDOnly/sherpa/blob/main/QPKG-service-script-types.txt
#
# For more info: https://forum.qnap.com/viewtopic.php?f=320&t=132373
####################################################################################

Init()
    {

    IsQNAP || return

    # specific environment
    readonly QPKG_NAME=LazyLibrarian
    readonly SCRIPT_VERSION=221213
    local -r MIN_RAM_KB=any

    # general environment
    readonly QPKG_PATH=$(/sbin/getcfg $QPKG_NAME Install_Path -f /etc/config/qpkg.conf)
    readonly QPKG_VERSION=$(/sbin/getcfg $QPKG_NAME Version -d unknown -f /etc/config/qpkg.conf)
    readonly QPKG_INI_PATHFILE=$QPKG_PATH/config/config.ini
    readonly QPKG_INI_DEFAULT_PATHFILE=$QPKG_INI_PATHFILE.def
    readonly APP_VERSION_STORE_PATHFILE=$QPKG_PATH/config/version.stored
    readonly SERVICE_STATUS_PATHFILE=/var/run/$QPKG_NAME.last.operation
    readonly SERVICE_LOG_PATHFILE=/var/log/$QPKG_NAME.log
    local -r BACKUP_PATH=$(/sbin/getcfg SHARE_DEF defVolMP -f /etc/config/def_share.info)/.qpkg_config_backup
    readonly BACKUP_PATHFILE=$BACKUP_PATH/$QPKG_NAME.config.tar.gz
    local -r INSTALLED_RAM_KB=$(/bin/grep MemTotal /proc/meminfo | cut -f2 -d':' | /bin/sed 's|kB||;s| ||g')
    readonly OPKG_PATH=/opt/bin:/opt/sbin
    export PATH="$OPKG_PATH:$(/bin/sed "s|$OPKG_PATH||" <<< "$PATH")"
    readonly APPARENT_PATH=/share/$(/sbin/getcfg SHARE_DEF defDownload -d Qdownload -f /etc/config/def_share.info)/$QPKG_NAME

    # specific to online-sourced applications only
    readonly SOURCE_GIT_URL=https://gitlab.com/LazyLibrarian/LazyLibrarian.git
    readonly SOURCE_GIT_BRANCH=master
    readonly SOURCE_GIT_DEPTH=shallow     # 'shallow' (depth 1) or 'single-branch' - note: 'shallow' implies a 'single-branch' too
    readonly TARGET_SCRIPT=LazyLibrarian.py

    # general online-sourced applications only
    readonly QPKG_REPO_PATH=$QPKG_PATH/repo-cache
    readonly PIP_CACHE_PATH=$QPKG_PATH/pip-cache
    readonly INTERPRETER=/opt/bin/python3
    readonly VENV_PATH=$QPKG_PATH/venv
    readonly VENV_INTERPRETER=$VENV_PATH/bin/python3
    readonly ALLOW_ACCESS_TO_SYS_PACKAGES=true
    readonly APP_VERSION_PATHFILE=$QPKG_REPO_PATH/lazylibrarian/version.py
    readonly DAEMON_PATHFILE=$QPKG_REPO_PATH/$TARGET_SCRIPT

    # daemonised applications only
    readonly DAEMON_PID_PATHFILE=/var/run/$QPKG_NAME.pid
    readonly LAUNCHER="$DAEMON_PATHFILE --daemon --nolaunch --datadir $(/usr/bin/dirname "$QPKG_INI_PATHFILE") --config $QPKG_INI_PATHFILE --pidfile $DAEMON_PID_PATHFILE"
    readonly PORT_CHECK_TIMEOUT=120
    readonly DAEMON_STOP_TIMEOUT=60

    # Entware binaries only
    readonly ORIG_DAEMON_SERVICE_SCRIPT=''

    # local mods only
    readonly TARGET_SERVICE_PATHFILE=''
    readonly BACKUP_SERVICE_PATHFILE=$TARGET_SERVICE_PATHFILE.bak

    if [[ $MIN_RAM_KB != any && $INSTALLED_RAM_KB -lt $MIN_RAM_KB ]]; then
        DisplayErrCommitAllLogs "$(FormatAsPackageName $QPKG_NAME) won't run on this NAS. Not enough RAM. :("
        exit 1
    fi

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
    DisableOpkgDaemonStart
    LoadAppVersion

    IsSupportBackup && [[ -n $BACKUP_PATH && ! -d $BACKUP_PATH ]] && mkdir -p "$BACKUP_PATH"
    [[ -n $VENV_PATH && ! -d $VENV_PATH ]] && mkdir -p "$VENV_PATH"
    [[ -n $PIP_CACHE_PATH && ! -d $PIP_CACHE_PATH ]] && mkdir -p "$PIP_CACHE_PATH"

    IsAutoUpdateMissing && EnableAutoUpdate >/dev/null

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
    DisplayAsHelp start "launch $(FormatAsPackageName $QPKG_NAME) if not already running."
    DisplayAsHelp stop "shutdown $(FormatAsPackageName $QPKG_NAME) if running."
    DisplayAsHelp restart "stop, then start $(FormatAsPackageName $QPKG_NAME)."
    DisplayAsHelp status "check if $(FormatAsPackageName $QPKG_NAME) daemon is running. Returns \$? = 0 if running, 1 if not."
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

    if IsNotRestart && IsNotRestore && IsNotClean && IsNotReset; then
        CommitOperationToLog
        IsDaemonActive && return
    fi

    if IsNotDaemon; then        # nzbToMedia: when cleaning, ignore restart and start anyway to create repo and restore config
        if IsRestore || IsReset; then
            IsNotRestartPending && return
        fi
    else
        if IsRestore || IsClean || IsReset; then
            IsNotRestartPending && return
        fi
    fi

    DisplayCommitToLog "auto-update: $(IsAutoUpdate && echo TRUE || echo FALSE)"
    PullGitRepo "$QPKG_NAME" "$SOURCE_GIT_URL" "$SOURCE_GIT_BRANCH" "$SOURCE_GIT_DEPTH" "$QPKG_REPO_PATH" || return
    InstallAddons || return

    IsNotDaemon && return

    WaitForLaunchTarget || return
    EnsureConfigFileExists
    LoadUIPorts app || return

    if [[ $ui_port -le 0 && $ui_port_secure -le 0 ]]; then
        DisplayErrCommitAllLogs 'unable to start daemon: no UI port was specified!'
        SetError
        return 1
    elif IsNotPortAvailable $ui_port || IsNotPortAvailable $ui_port_secure; then
        DisplayErrCommitAllLogs "unable to start daemon: ports $ui_port or $ui_port_secure are already in use!"

        portpid=$(/usr/sbin/lsof -i :$ui_port -Fp)
        DisplayErrCommitAllLogs "process details for port $ui_port: \"$([[ -n $portpid ]] && /bin/tr '\000' ' ' </proc/${portpid/p/}/cmdline)\""

        portpid=$(/usr/sbin/lsof -i :$ui_port_secure -Fp)
        DisplayErrCommitAllLogs "process details for secure port $ui_port_secure: \"$([[ -n $portpid ]] && /bin/tr '\000' ' ' </proc/${portpid/p/}/cmdline)\""

        SetError
        return 1
    fi

    if IsNotVirtualEnvironmentExist; then
        DisplayErrCommitAllLogs 'unable to start daemon: virtual environment does not exist!'
        SetError
        return 1
    fi

    ExecuteAndLog 'start daemon' ". $VENV_PATH/bin/activate && cd $QPKG_REPO_PATH && $VENV_INTERPRETER $LAUNCHER" log:everything || return
    WaitForPID || return
    IsDaemonActive || return
    CheckPorts || return

    return 0

    }

StopQPKG()
    {

    # this function is customised depending on the requirements of the packaged application

    IsError && return

    if IsNotRestore && IsNotClean && IsNotReset; then
        CommitOperationToLog
    fi

    if IsDaemonActive; then
        if IsRestart || IsRestore || IsClean || IsReset; then
            SetRestartPending
        fi

        local acc=0
        local pid=0
        SetRestartPending

        pid=$(<$DAEMON_PID_PATHFILE)
        kill "$pid"
        DisplayWaitCommitToLog 'stop daemon with SIGTERM:'
        DisplayWait "(no-more than $DAEMON_STOP_TIMEOUT seconds):"

        while true; do
            while [[ -d /proc/$pid ]]; do
                sleep 1
                ((acc++))
                DisplayWait "$acc,"

                if [[ $acc -ge $DAEMON_STOP_TIMEOUT ]]; then
                    DisplayCommitToLog 'failed!'
                    DisplayCommitToLog 'stop daemon with SIGKILL'
                    kill -9 "$pid" 2> /dev/null
                    [[ -f $DAEMON_PID_PATHFILE ]] && rm -f $DAEMON_PID_PATHFILE
                    break 2
                fi
            done

            [[ -f $DAEMON_PID_PATHFILE ]] && rm -f $DAEMON_PID_PATHFILE
            Display OK
            CommitLog "stopped OK in $acc seconds"

            CommitInfoToSysLog "stop daemon: OK."
            break
        done

        IsNotDaemonActive || return
    fi

    return 0

    }

InstallAddons()
    {

    local default_requirements_pathfile=$QPKG_PATH/config/requirements.txt
    local default_recommended_pathfile=$QPKG_PATH/config/recommended.txt
    local requirements_pathfile=$QPKG_REPO_PATH/requirements.txt
    local recommended_pathfile=$QPKG_REPO_PATH/recommended.txt
    local pip_conf_pathfile=$VENV_PATH/pip.conf
    local new_env=false
    local sys_packages=' --system-site-packages'

    [[ $ALLOW_ACCESS_TO_SYS_PACKAGES != true ]] && sys_packages=''

    if IsNotVirtualEnvironmentExist; then
        ExecuteAndLog 'create new virtual Python environment' "export PIP_CACHE_DIR=$PIP_CACHE_PATH VIRTUALENV_OVERRIDE_APP_DATA=$PIP_CACHE_PATH; $INTERPRETER -m virtualenv $VENV_PATH $sys_packages" log:everything || SetError
        new_env=true
    fi

    if IsNotVirtualEnvironmentExist; then
        DisplayErrCommitAllLogs 'unable to install addons: virtual environment does not exist!'
        SetError
        return 1
    fi

    if [[ ! -e $pip_conf_pathfile ]]; then
        ExecuteAndLog "create global 'pip' config" "echo -e \"[global]\ncache-dir = $PIP_CACHE_PATH\" > $pip_conf_pathfile" log:everything || SetError
    fi

    IsNotAutoUpdate && [[ $new_env = false ]] && return 0

    [[ ! -e $requirements_pathfile && -e $default_requirements_pathfile ]] && requirements_pathfile=$default_requirements_pathfile

    if [[ -e $requirements_pathfile ]]; then
        ExecuteAndLog 'install required PyPI modules' ". $VENV_PATH/bin/activate && pip install --no-input -r $requirements_pathfile" log:everything || SetError
    fi

    [[ ! -e $recommended_pathfile && -e $default_recommended_pathfile ]] && recommended_pathfile=$default_recommended_pathfile

    if [[ -e $recommended_pathfile ]]; then
        ExecuteAndLog 'install recommended PyPI modules' ". $VENV_PATH/bin/activate && pip install --no-input -r $recommended_pathfile" log:everything || SetError
    fi

    if [[ $QPKG_NAME = SABnzbd && $new_env = true ]]; then
        ExecuteAndLog "KLUDGE: reinstall 'sabyenc3' PyPI module (https://forums.sabnzbd.org/viewtopic.php?p=128567#p128567)" ". $VENV_PATH/bin/activate && pip install --no-input --force-reinstall --no-binary :all: sabyenc3" log:everything || SetError
        UpdateLanguages
    fi

    }

BackupConfig()
    {

    CommitOperationToLog
    ExecuteAndLog 'update configuration backup' "/bin/tar --create --gzip --file=$BACKUP_PATHFILE --directory=$QPKG_PATH/config ." log:everything || SetError

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
    ExecuteAndLog 'restore configuration backup' "/bin/tar --extract --gzip --file=$BACKUP_PATHFILE --directory=$QPKG_PATH/config" log:everything || SetError
    StartQPKG

    }

ResetConfig()
    {

    CommitOperationToLog

    StopQPKG
    ExecuteAndLog 'reset configuration' "mv $QPKG_INI_DEFAULT_PATHFILE $QPKG_PATH; rm -rf $QPKG_PATH/config/*; mv $QPKG_PATH/$(/usr/bin/basename "$QPKG_INI_DEFAULT_PATHFILE") $QPKG_INI_DEFAULT_PATHFILE" log:everything || SetError
    StartQPKG

    }

LoadUIPorts()
    {

    # If user changes ports via app UI, must first 'stop' application on old ports, then 'start' on new ports

    case $1 in
        app)
            # Read the current application UI ports from application configuration
            DisplayWaitCommitToLog 'load UI ports from application config:'
            ui_port=5299            # 5299 is the default value for LazyLibrarian, so it won't be found in config file. LL only stores non-default values.
            ui_port_secure=0
            DisplayCommitToLog OK
            ;;
        qts)
            # Read the current application UI ports from QTS App Center
            DisplayWaitCommitToLog 'load UI ports from QPKG icon:'
            ui_port=$(/sbin/getcfg $QPKG_NAME Web_Port -d 0 -f /etc/config/qpkg.conf)
            ui_port_secure=$(/sbin/getcfg $QPKG_NAME Web_SSL_Port -d 0 -f /etc/config/qpkg.conf)
            DisplayCommitToLog OK
            ;;
        *)
            DisplayErrCommitAllLogs "unable to load UI ports: action '$1' is unrecognised"
            SetError
            return 1
            ;;
    esac

    if [[ $ui_port -eq 0 ]] && IsNotDefaultConfigFound; then
        ui_port=0
        ui_port_secure=0
    fi

    # Always read this from the application configuration
    ui_listening_address=$(/sbin/getcfg general http_host -f "$QPKG_INI_PATHFILE")

    return 0

    }

IsSSLEnabled()
    {

    [[ $(/sbin/getcfg general https_enabled -d 0 -f "$QPKG_INI_PATHFILE") -eq 1 ]]

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

    if IsDaemonActive; then
        if IsDaemon || IsSourcedOnline; then
            LoadUIPorts qts
            if ! CheckPorts; then
                SetError
                return 1
            fi
        fi
    else
        SetError
        return 1
    fi

    return 0

    }

DisableOpkgDaemonStart()
    {

    if [[ -n $ORIG_DAEMON_SERVICE_SCRIPT && -x $ORIG_DAEMON_SERVICE_SCRIPT ]]; then
        $ORIG_DAEMON_SERVICE_SCRIPT stop        # stop default daemon
        chmod -x "$ORIG_DAEMON_SERVICE_SCRIPT"  # ... and ensure Entware doesn't re-launch it on startup
    fi

    }

UpdateLanguages()
    {

    # run [tools/make_mo.py] if SABnzbd version number has changed since last run

    LoadAppVersion
    [[ -e $APP_VERSION_STORE_PATHFILE && $(<"$APP_VERSION_STORE_PATHFILE") = "$app_version" && -d $QPKG_REPO_PATH/locale ]] && return 0

    ExecuteAndLog "update $(FormatAsPackageName $QPKG_NAME) language translations" ". $VENV_PATH/bin/activate && cd $QPKG_REPO_PATH; $VENV_INTERPRETER $QPKG_REPO_PATH/tools/make_mo.py"
    [[ ! -e $APP_VERSION_STORE_PATHFILE ]] && return 0

    SaveAppVersion

    }

PullGitRepo()
    {

    # $1 = package name
    # $2 = URL to pull/clone from
    # $3 = remote branch or tag
    # $4 = remote depth: 'shallow' or 'single-branch'
    # $5 = local path to clone into

    [[ -z $1 || -z $2 || -z $3 || -z $4 || -z $5 ]] && return 1

    local -r QPKG_GIT_PATH="$5"
    local -r GIT_HTTPS_URL="$2"
    local installed_branch=''
    local branch_switch=false
    [[ $4 = shallow ]] && local -r DEPTH='--depth 1'
    [[ $4 = single-branch ]] && local -r DEPTH='--single-branch'

    WaitForGit || return 1

    if [[ -d $QPKG_GIT_PATH/.git ]]; then
        installed_branch=$(/opt/bin/git -C "$QPKG_GIT_PATH" branch | /bin/grep '^\*' | /bin/sed 's|^\* ||')

        if [[ $installed_branch != "$3" ]]; then
            branch_switch=true
            DisplayCommitToLog "current git branch: $installed_branch, new git branch: $3"
            [[ $QPKG_NAME = nzbToMedia ]] && BackupConfig
            ExecuteAndLog 'new git branch has been specified, so clean local repository' "cd /tmp; rm -r $QPKG_GIT_PATH"
        fi
    fi

    if [[ ! -d $QPKG_GIT_PATH/.git ]]; then
        ExecuteAndLog "clone $(FormatAsPackageName "$1") from remote repository" "cd /tmp; /opt/bin/git clone --branch $3 $DEPTH -c advice.detachedHead=false $GIT_HTTPS_URL $QPKG_GIT_PATH"
    else
        if IsAutoUpdate; then
            # latest effort at resolving local corruption, source: https://stackoverflow.com/a/10170195
            ExecuteAndLog "update $(FormatAsPackageName "$1") from remote repository" "cd /tmp; /opt/bin/git -C $QPKG_GIT_PATH clean -f; /opt/bin/git -C $QPKG_GIT_PATH reset --hard origin/$3; /opt/bin/git -C $QPKG_GIT_PATH pull"
        fi
    fi

    if IsAutoUpdate; then
        installed_branch=$(/opt/bin/git -C "$QPKG_GIT_PATH" branch | /bin/grep '^\*' | /bin/sed 's|^\* ||')
        DisplayCommitToLog "current git branch: $installed_branch"
    fi

    [[ $branch_switch = true && $QPKG_NAME = nzbToMedia ]] && RestoreConfig

    return 0

    }

CleanLocalClone()
    {

    # for occasions where the local repo needs to be deleted and cloned again from source.

    CommitOperationToLog

    if [[ -z $QPKG_PATH || -z $QPKG_NAME ]] || IsNotSourcedOnline; then
        SetError
        return 1
    fi

    StopQPKG
    ExecuteAndLog 'clean local repository' "rm -rf $QPKG_REPO_PATH"
    [[ -d $(dirname $QPKG_REPO_PATH)/$QPKG_NAME ]] && ExecuteAndLog 'KLUDGE: remove previous local repository' "rm -r $(dirname $QPKG_REPO_PATH)/$QPKG_NAME"
    ExecuteAndLog 'clean virtual environment' "rm -rf $VENV_PATH"
    ExecuteAndLog 'clean PyPI cache' "rm -rf $PIP_CACHE_PATH"
    StartQPKG

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

WaitForGit()
    {

    if WaitForFileToAppear '/opt/bin/git' 300; then
        export PATH="$OPKG_PATH:$(/bin/sed "s|$OPKG_PATH||" <<< "$PATH")"
        return 0
    else
        return 1
    fi

    }

WaitForLaunchTarget()
    {

    local launch_target=''

    if [[ -n $INTERPRETER ]]; then
        launch_target=$INTERPRETER
    elif [[ -n $DAEMON_PATHFILE ]]; then
        launch_target=$DAEMON_PATHFILE
    else
        return 0
    fi

    if WaitForFileToAppear "$launch_target" 30; then
        return 0
    else
        return 1
    fi

    }

WaitForPID()
    {

    if WaitForFileToAppear "$DAEMON_PID_PATHFILE" 60; then
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

EnsureConfigFileExists()
    {

    IsNotSupportReset && return

    if IsNotConfigFound && IsDefaultConfigFound; then
        DisplayCommitToLog 'no configuration file found: using default'
        cp "$QPKG_INI_DEFAULT_PATHFILE" "$QPKG_INI_PATHFILE"
    fi

    }

SaveAppVersion()
    {

    [[ -z $APP_VERSION_STORE_PATHFILE ]] && return

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
    # $3 'log:everything' (optional) - if specified, the processing message and successful results are recorded in the QTS system log.
    #                                - if unspecified, only warnings/ errors are recorded in the QTS system log.

    if [[ -z $1 || -z $2 ]]; then
        SetError
        return 1
    fi

    local exec_msgs=''
    local result=0

    DisplayWaitCommitToLog "$1:"
    exec_msgs=$(eval "$2" 2>&1)
    result=$?

    if [[ $result = 0 ]]; then
        DisplayCommitToLog OK
        [[ $3 = log:everything ]] && CommitInfoToSysLog "$1: OK."
        return 0
    else
        DisplayCommitToLog 'failed!'
        DisplayCommitToLog "$(FormatAsFuncMessages "$exec_msgs")"
        DisplayCommitToLog "$(FormatAsResult $result)"
        CommitWarnToSysLog "A problem occurred while $1. Check $(FormatAsFileName "$SERVICE_LOG_PATHFILE") for more details."
        SetError
        return 1
    fi

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

    DisplayCommitToLog OK

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

    [[ $(/sbin/getcfg $QPKG_NAME Enable -u -d FALSE -f /etc/config/qpkg.conf) = TRUE ]]

    }

IsNotQPKGEnabled()
    {

    ! IsQPKGEnabled

    }

IsSupportBackup()
    {

    [[ -n $BACKUP_PATHFILE ]]

    }

IsNotSupportBackup()
    {

    ! IsSupportBackup

    }

IsSupportReset()
    {

    [[ -n $QPKG_INI_PATHFILE ]]

    }

IsNotSupportReset()
    {

    ! IsSupportReset

    }

IsSourcedOnline()
    {

    [[ -n $SOURCE_GIT_URL ]]

    }

IsNotSourcedOnline()
    {

    ! IsSourcedOnline

    }

IsNotSSLEnabled()
    {

    ! IsSSLEnabled

    }

IsPackageActive()
    {

    if [[ -e $BACKUP_SERVICE_PATHFILE ]]; then
        DisplayCommitToLog 'package: IS active'
        return
    fi

    DisplayCommitToLog 'package: NOT active'
    return 1

    }

IsNotPackageActive()
    {

    ! IsPackageActive

    }

IsDaemon()
    {

    [[ -n $DAEMON_PID_PATHFILE ]]

    }

IsNotDaemon()
    {

    ! IsDaemon

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

    Display OK
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

    Display OK
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

IsVirtualEnvironmentExist()
    {

    # Is there a virtual environment to run the application in?

    [[ -e $VENV_PATH/bin/activate ]]

    }

IsNotVirtualEnvironmentExist()
    {

    ! IsVirtualEnvironmentExist

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

IsAutoUpdateMissing()
    {

    [[ $(/sbin/getcfg $QPKG_NAME Auto_Update -u -f /etc/config/qpkg.conf) = '' ]]

    }

IsAutoUpdate()
    {

    [[ $(/sbin/getcfg $QPKG_NAME Auto_Update -u -f /etc/config/qpkg.conf) = TRUE ]]

    }

IsNotAutoUpdate()
    {

    ! IsAutoUpdate

    }

EnableAutoUpdate()
    {

    StoreAutoUpdateSelection TRUE

    }

DisableAutoUpdate()
    {

    StoreAutoUpdateSelection FALSE

    }

StoreAutoUpdateSelection()
    {

    /sbin/setcfg "$QPKG_NAME" Auto_Update "$1" -f /etc/config/qpkg.conf
    DisplayCommitToLog "auto-update: $1"

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
        b|-b|backup|--backup|backup-config|--backup-config)
            if IsSupportBackup; then
                SetServiceOperation backing-up
                BackupConfig
            else
                SetServiceOperation none
                ShowHelp
            fi
            ;;
        reset-config|--reset-config)
            if IsSupportReset; then
                SetServiceOperation resetting-config
                ResetConfig
            else
                SetServiceOperation none
                ShowHelp
            fi
            ;;
        restore|--restore|restore-config|--restore-config)
            if IsSupportBackup; then
                SetServiceOperation restoring
                RestoreConfig
            else
                SetServiceOperation none
                ShowHelp
            fi
            ;;
        c|-c|clean|--clean)
            if IsSourcedOnline; then
                SetServiceOperation cleaning

                if [[ $QPKG_NAME = nzbToMedia ]]; then
                    # nzbToMedia stores the config file in the repo location, so save it and restore again after new clone is complete
                    BackupConfig && CleanLocalClone && RestoreConfig
                else
                    CleanLocalClone
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
        disable-auto-update|--disable-auto-update)
            SetServiceOperation disable-auto-update
            DisableAutoUpdate
            ;;
        enable-auto-update|--enable-auto-update)
            SetServiceOperation enable-auto-update
            EnableAutoUpdate
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
