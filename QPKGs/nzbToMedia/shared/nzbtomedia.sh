#!/usr/bin/env bash
####################################################################################
# nzbtomedia.sh
#
# Copyright (C) 2020-2022 OneCD [one.cd.only@gmail.com]
#
# so, blame OneCD if it all goes horribly wrong. ;)
#
# This is a type 2 service-script: https://github.com/OneCDOnly/sherpa/blob/main/QPKG-service-script-types.txt
#
# For more info: https://forum.qnap.com/viewtopic.php?f=320&t=132373
####################################################################################

readonly USER_ARGS_RAW=$*

Init()
    {

    IsQNAP || return

    # service-script environment
    readonly QPKG_NAME=nzbToMedia
    readonly SCRIPT_VERSION=221220a

    # general environment
    readonly QPKG_PATH=$(/sbin/getcfg $QPKG_NAME Install_Path -f /etc/config/qpkg.conf)
    readonly QPKG_VERSION=$(/sbin/getcfg $QPKG_NAME Version -d unknown -f /etc/config/qpkg.conf)
    readonly APP_VERSION_STORE_PATHFILE=$QPKG_PATH/config/version.stored
    readonly SERVICE_STATUS_PATHFILE=/var/run/$QPKG_NAME.last.operation
    readonly SERVICE_LOG_PATHFILE=/var/log/$QPKG_NAME.log
    local -r BACKUP_PATH=$(/sbin/getcfg SHARE_DEF defVolMP -f /etc/config/def_share.info)/.qpkg_config_backup
    readonly BACKUP_PATHFILE=$BACKUP_PATH/$QPKG_NAME.config.tar.gz
    readonly OPKG_PATH=/opt/bin:/opt/sbin
    export PATH="$OPKG_PATH:$(/bin/sed "s|$OPKG_PATH||" <<< "$PATH")"
    local -r DEFAULT_DOWNLOAD_SHARE=$(/sbin/getcfg SHARE_DEF defDownload -d unspecified -f /etc/config/def_share.info)
    readonly DEBUG_LOG_DATAWIDTH=100
    local re=''

    if IsQPKGInstalled SABnzbd; then
        readonly APPARENT_PATH=$(/sbin/getcfg misc download_dir -d /share/Public/Downloads -f $(/sbin/getcfg SABnzbd Install_Path -f /etc/config/qpkg.conf)/config/config.ini)/$QPKG_NAME
    elif IsQPKGInstalled NZBGet; then
        readonly APPARENT_PATH=$(/sbin/getcfg '' MainDir -d /share/Public/Downloads -f $(/sbin/getcfg NZBGet Install_Path -f /etc/config/qpkg.conf)/config/config.ini)/$QPKG_NAME
    elif [[ $DEFAULT_DOWNLOAD_SHARE != unspecified ]]; then
        readonly APPARENT_PATH=$DEFAULT_DOWNLOAD_SHARE/$QPKG_NAME
    else
        readonly APPARENT_PATH=/share/Public/Downloads/$QPKG_NAME
    fi

    # specific to online-sourced applications only
    readonly SOURCE_GIT_URL=https://github.com/clinton-hall/nzbToMedia.git
    readonly SOURCE_GIT_BRANCH=master
    # 'shallow' (depth 1) or 'single-branch' ... 'shallow' implies 'single-branch'
    readonly SOURCE_GIT_DEPTH=shallow
    readonly QPKG_REPO_PATH=$QPKG_PATH/repo-cache
    readonly PIP_CACHE_PATH=$QPKG_PATH/pip-cache
    readonly INTERPRETER=/opt/bin/python3
    readonly VENV_PATH=$QPKG_PATH/venv
    readonly VENV_INTERPRETER=$VENV_PATH/bin/python3
    readonly ALLOW_ACCESS_TO_SYS_PACKAGES=false
    readonly QPKG_INI_PATHFILE=$QPKG_REPO_PATH/autoProcessMedia.cfg
    readonly QPKG_INI_DEFAULT_PATHFILE=$QPKG_INI_PATHFILE.spec

    # specific to applications supporting version lookup only
    readonly APP_VERSION_PATHFILE=$QPKG_REPO_PATH/.bumpversion.cfg
    readonly APP_VERSION_CMD="/sbin/getcfg bumpversion current_version -d 0 -f $APP_VERSION_PATHFILE"

    if [[ -z $LANG ]]; then
        export LANG=en_US.UTF-8
        export LC_ALL=en_US.UTF-8
        export LC_CTYPE=en_US.UTF-8
    fi

    UnsetDebug
    UnsetError
    UnsetRestartPending
    EnsureConfigFileExists
    LoadAppVersion

    for re in \\bd\\b \\bdebug\\b \\bdbug\\b \\bverbose\\b; do
        if [[ $USER_ARGS_RAW =~ $re ]]; then
            SetDebug
            break
        fi
    done

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

    if IsNotRestart && IsNotRestore && IsNotClean && IsNotReset; then
        CommitOperationToLog
        IsPackageActive && return
    fi

    if IsRestore || IsClean || IsReset; then
        IsNotRestartPending && return
    fi

    local -r SAB_MIN_VERSION=200809

    DisplayCommitToLog "auto-update: $(IsAutoUpdate && echo TRUE || echo FALSE)"
    PullGitRepo "$QPKG_NAME" "$SOURCE_GIT_URL" "$SOURCE_GIT_BRANCH" "$SOURCE_GIT_DEPTH" "$QPKG_REPO_PATH" || return
    WaitForLaunchTarget || return

    if [[ $(/sbin/getcfg SABnzbdplus Enable -f /etc/config/qpkg.conf) = TRUE ]]; then
        DisplayErrCommitAllLogs "unable to link from package to target: installed $(FormatAsPackageName SABnzbdplus) QPKG must be replaced with $(FormatAsPackageName SABnzbd) $SAB_MIN_VERSION or later"
        return 1
    fi

    if [[ $(/sbin/getcfg SABnzbd Enable -f /etc/config/qpkg.conf) = TRUE ]]; then
        local current_version=$(/sbin/getcfg SABnzbd Version -f /etc/config/qpkg.conf)

        if [[ ${current_version//[!0-9]/} -lt $SAB_MIN_VERSION ]]; then
            DisplayErrCommitAllLogs "unable to link from package to target: installed $(FormatAsPackageName SABnzbd) QPKG must first be upgraded to $SAB_MIN_VERSION or later"
            return 1
        fi
    fi

    # save config from original nzbToMedia install (created by sherpa SABnzbd QPKGs earlier than $SAB_MIN_VERSION)
    if [[ -d $APPARENT_PATH && ! -L $APPARENT_PATH && -e "$APPARENT_PATH/$(/usr/bin/basename "$QPKG_INI_PATHFILE")" ]]; then
        cp "$APPARENT_PATH/$(/usr/bin/basename "$QPKG_INI_PATHFILE")" "$QPKG_INI_PATHFILE"
    fi

    # destroy original installation
    [[ -d $APPARENT_PATH ]] && rm -r "$APPARENT_PATH"

    # need this if [Download] isn't a share on this NAS
    [[ ! -e $(/usr/bin/dirname $APPARENT_PATH) ]] && mkdir -p $(/usr/bin/dirname $APPARENT_PATH)

    ln -s "$QPKG_REPO_PATH" "$APPARENT_PATH"

    DisplayCommitToLog 'start package: OK'
    EnsureConfigFileExists
    IsPackageActive || return

    return 0

    }

StopQPKG()
    {

    # this function is customised depending on the requirements of the packaged application

    IsError && return

    if IsNotRestore && IsNotClean && IsNotReset; then
        CommitOperationToLog
    fi

    if IsPackageActive; then
        if IsRestart || IsRestore || IsClean || IsReset; then
            SetRestartPending
        fi

        [[ -L $APPARENT_PATH ]] && rm "$APPARENT_PATH"
        DisplayCommitToLog 'stop package: OK.'

        IsNotPackageActive || return
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
    local no_pips_installed=true

    [[ $ALLOW_ACCESS_TO_SYS_PACKAGES != true ]] && sys_packages=''

    if IsNotVirtualEnvironmentExist; then
        DisplayRunAndLog 'create new virtual Python environment' "export PIP_CACHE_DIR=$PIP_CACHE_PATH VIRTUALENV_OVERRIDE_APP_DATA=$PIP_CACHE_PATH; $INTERPRETER -m virtualenv $VENV_PATH $sys_packages" log:everything || SetError
        new_env=true
    fi

    if IsNotVirtualEnvironmentExist; then
        DisplayErrCommitAllLogs 'unable to install addons: virtual environment does not exist!'
        SetError
        return 1
    fi

    if [[ ! -e $pip_conf_pathfile ]]; then
        DisplayRunAndLog "create global 'pip' config" "echo -e \"[global]\ncache-dir = $PIP_CACHE_PATH\" > $pip_conf_pathfile" log:everything || SetError
    fi

    IsNotAutoUpdate && [[ $new_env = false ]] && return 0

    [[ ! -e $requirements_pathfile && -e $default_requirements_pathfile ]] && requirements_pathfile=$default_requirements_pathfile

    if [[ -e $requirements_pathfile ]]; then
        DisplayRunAndLog 'install required PyPI modules' ". $VENV_PATH/bin/activate && pip install --no-input -r $requirements_pathfile" log:everything || SetError
        no_pips_installed=false
    fi

    [[ ! -e $recommended_pathfile && -e $default_recommended_pathfile ]] && recommended_pathfile=$default_recommended_pathfile

    if [[ -e $recommended_pathfile ]]; then
        DisplayRunAndLog 'install recommended PyPI modules' ". $VENV_PATH/bin/activate && pip install --no-input -r $recommended_pathfile" log:everything || SetError
        no_pips_installed=false
    fi

    if [[ $no_pips_installed = true ]]; then        # fallback to general installation method
        if [[ -e $QPKG_REPO_PATH/setup.py || -e $QPKG_REPO_PATH/pyproject.toml ]]; then
            DisplayRunAndLog 'install default PyPI modules' ". $VENV_PATH/bin/activate && pip install --no-input $QPKG_REPO_PATH" log:everything || SetError
            no_pips_installed=false
        fi
    fi

    if [[ $QPKG_NAME = SABnzbd && $new_env = true ]]; then
        DisplayRunAndLog "KLUDGE: reinstall 'sabyenc3' PyPI module (https://forums.sabnzbd.org/viewtopic.php?p=128567#p128567)" ". $VENV_PATH/bin/activate && pip install --no-input --force-reinstall --no-binary :all: sabyenc3" log:everything || SetError
        UpdateLanguages
    fi

    }

BackupConfig()
    {

    CommitOperationToLog
    DisplayRunAndLog 'update configuration backup' "/bin/tar --create --gzip --file=$BACKUP_PATHFILE --directory=$QPKG_REPO_PATH autoProcessMedia.cfg" log:everything || SetError

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
    DisplayRunAndLog 'restore configuration backup' "/bin/tar --extract --gzip --file=$BACKUP_PATHFILE --directory=$QPKG_REPO_PATH" log:everything || SetError
    StartQPKG

    }

ResetConfig()
    {

    CommitOperationToLog
    StopQPKG
    DisplayRunAndLog 'reset configuration' "rm $QPKG_INI_PATHFILE" log:everything || SetError
    StartQPKG

    }

LoadAppVersion()
    {

    # Find the application's internal version number
    # creates a global var: $app_version
    # this is the installed application version (not the QPKG version)

    if [[ -n $APP_VERSION_PATHFILE && -e $APP_VERSION_PATHFILE ]]; then
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
            DisplayRunAndLog 'new git branch has been specified, so clean local repository' "cd /tmp; rm -r $QPKG_GIT_PATH"
        fi
    fi

    if [[ ! -d $QPKG_GIT_PATH/.git ]]; then
        DisplayRunAndLog "clone $(FormatAsPackageName "$1") from remote repository" "cd /tmp; /opt/bin/git clone --branch $3 $DEPTH -c advice.detachedHead=false $GIT_HTTPS_URL $QPKG_GIT_PATH"
    else
        if IsAutoUpdate; then
            # latest effort at resolving local corruption, source: https://stackoverflow.com/a/10170195
            DisplayRunAndLog "update $(FormatAsPackageName "$1") from remote repository" "cd /tmp; /opt/bin/git -C $QPKG_GIT_PATH clean -f; /opt/bin/git -C $QPKG_GIT_PATH reset --hard origin/$3; /opt/bin/git -C $QPKG_GIT_PATH pull"
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

    [[ $QPKG_NAME = nzbToMedia ]] && BackupConfig

    CommitOperationToLog

    if [[ -z $QPKG_PATH || -z $QPKG_NAME ]] || IsNotSourcedOnline; then
        SetError
        return 1
    fi

    StopQPKG
    DisplayRunAndLog 'clean local repository' "rm -rf $QPKG_REPO_PATH"
    [[ -d $(/usr/bin/dirname $QPKG_REPO_PATH)/$QPKG_NAME ]] && DisplayRunAndLog 'KLUDGE: remove previous local repository' "rm -r $(/usr/bin/dirname $QPKG_REPO_PATH)/$QPKG_NAME"
    DisplayRunAndLog 'clean virtual environment' "rm -rf $VENV_PATH"
    DisplayRunAndLog 'clean PyPI cache' "rm -rf $PIP_CACHE_PATH"
    StartQPKG

    [[ $QPKG_NAME = nzbToMedia ]] && RestoreConfig

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

    if [[ -n ${INTERPRETER:-} ]]; then
        launch_target=$INTERPRETER
    elif [[ -n ${DAEMON_PATHFILE:-} ]]; then
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

DisplayRunAndLog()
    {

    # Run a commandstring, log the results, and show onscreen if required

    # input:
    #   $1 = processing message
    #   $2 = commandstring to execute
    #   $3 = 'log:failure-only' (optional) - if specified, stdout & stderr are only recorded in the specified log if the command failed
    #                                      - if unspecified, stdout & stderr is always recorded

    local -r LOG_PATHFILE=$(/bin/mktemp -p /var/log ${FUNCNAME[0]}_XXXXXX)
    local -i result_code=0

    DisplayWaitCommitToLog "$1:"

    RunAndLog "$2" "$LOG_PATHFILE" "$3"
    result_code=$?

    if [[ -e $LOG_PATHFILE ]]; then
        rm -f "$LOG_PATHFILE"
    fi

    if [[ $result_code -eq 0 ]]; then
        DisplayCommitToLog OK
        [[ $3 = log:everything ]] && CommitInfoToSysLog "$1: OK."
        return 0
    else
        DisplayCommitToLog 'failed!'
        return 1
    fi

    }

RunAndLog()
    {

    # Run a commandstring, log the results, and show onscreen if required

    # input:
    #   $1 = commandstring to execute
    #   $2 = pathfile to record stdout and stderr for commandstring
    #   $3 = 'log:failure-only' (optional) - if specified, stdout & stderr are only recorded in the specified log if the command failed
    #                                      - if unspecified, stdout & stderr is always recorded
    #   $4 = e.g. '10' (optional) - an additional acceptable result code. Any other result from command (other than zero) will be considered a failure

    # output:
    #   stdout = commandstring stdout and stderr if script is in 'debug' mode
    #   pathfile ($2) = commandstring ($1) stdout and stderr
    #   $? = result_code of commandstring

    local -r LOG_PATHFILE=$(/bin/mktemp -p /var/log ${FUNCNAME[0]}_XXXXXX)
    local -i result_code=0

    FormatAsCommand "${1:?empty}" > "${2:?empty}"

    if IsDebug; then
        Display
        Display "exec: '$1'"
        eval "$1 > >(/usr/bin/tee $LOG_PATHFILE) 2>&1"   # NOTE: 'tee' buffers stdout here
        result_code=$?
    else
        eval "$1" > "$LOG_PATHFILE" 2>&1
        result_code=$?
    fi

    if [[ -e $LOG_PATHFILE ]]; then
        FormatAsResultAndStdout "$result_code" "$(<"$LOG_PATHFILE")" >> "$2"
        rm -f "$LOG_PATHFILE"
    else
        FormatAsResultAndStdout "$result_code" '<null>' >> "$2"
    fi

    if [[ $result_code -eq 0 ]]; then
        [[ ${3:-} != log:failure-only ]] && AddFileToDebug "$2"
    else
        [[ $result_code -ne ${4:-} ]] && AddFileToDebug "$2"
    fi

    return $result_code

    }

AddFileToDebug()
    {

    # Add the contents of specified pathfile $1 to the runtime log

    local debug_was_set=false
    local linebuff=''

    if IsDebug; then      # prevent external log contents appearing onscreen again, as they have already been seen "live"
        debug_was_set=true
        UnsetDebug
    fi

    DebugAsLog ''
    DebugAsLog 'adding external log to main log ...'
    DebugExtLogMinorSeparator
    DebugAsLog "$(FormatAsLogFilename "${1:?no filename supplied}")"

    while read -r linebuff; do
        DebugAsLog "$linebuff"
    done < "$1"

    DebugExtLogMinorSeparator
    [[ $debug_was_set = true ]] && SetDebug

    }

DebugExtLogMinorSeparator()
    {

    DebugAsLog "$(eval printf '%0.s-' "{1..$DEBUG_LOG_DATAWIDTH}")" # 'seq' is unavailable in QTS, so must resort to 'eval' trickery instead

    }

DebugAsLog()
    {

    DebugThis "(LL) ${1:-}"

    }

DebugThis()
    {

    IsDebug && Display "${1:-}"
    WriteAsDebug "${1:-}"

    }

WriteAsDebug()
    {

    WriteToLog dbug "${1:-}"

    }

WriteToLog()
    {

    # input:
    #   $1 = pass/fail
    #   $2 = message

    printf "%-4s: %s\n" "$(StripANSI "${1:-}")" "$(StripANSI "${2:-}")" >> "$SERVICE_LOG_PATHFILE"

    }

StripANSI()
    {

    # QTS 4.2.6 BusyBox 'sed' doesn't fully support extended regexes, so this only works with a real 'sed'

    if [[ -e /opt/bin/sed ]]; then
        /opt/bin/sed -r 's/\x1b\[[0-9;]*m//g' <<< "${1:-}"
    else
        echo "${1:-}"           # can't strip, so pass thru original message unaltered
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

IsPackageActive()
    {

    if [[ -L $APPARENT_PATH ]]; then
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
        clean|--clean)
            if IsSourcedOnline; then
                SetServiceOperation cleaning
                CleanLocalClone
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
