#!/usr/bin/env bash
####################################################################################
# nzbtomedia.sh
#
# Copyright (C) 2020 OneCD [one.cd.only@gmail.com]
#
# so, blame OneCD if it all goes horribly wrong. ;)
#
# For more info: https://forum.qnap.com/viewtopic.php?f=320&t=132373
####################################################################################

Init()
    {

    # specific environment
        readonly QPKG_NAME=nzbToMedia

    # for Python-based remote apps
        readonly SOURCE_GIT_URL=https://github.com/clinton-hall/nzbToMedia.git
        readonly SOURCE_GIT_BRANCH=master
        # 'shallow' (depth 1) or 'single-branch' (note: 'shallow' implies a 'single-branch' too)
        readonly SOURCE_GIT_DEPTH=shallow

    # cherry-pick required binaries
    readonly BASENAME_CMD=/usr/bin/basename
    readonly CURL_CMD=/sbin/curl
    readonly DIRNAME_CMD=/usr/bin/dirname
    readonly GETCFG_CMD=/sbin/getcfg
    readonly GREP_CMD=/bin/grep
    readonly GNU_LESS_CMD=/opt/bin/less
    readonly LSOF_CMD=/usr/sbin/lsof
    readonly SED_CMD=/bin/sed
    readonly TAR_CMD=/bin/tar
    readonly TAIL_CMD=/usr/bin/tail
    readonly TEE_CMD=/usr/bin/tee
    readonly WRITE_LOG_CMD=/sbin/write_log

    # generic environment
    readonly QTS_QPKG_CONF_PATHFILE=/etc/config/qpkg.conf
    readonly QPKG_PATH=$($GETCFG_CMD $QPKG_NAME Install_Path -f $QTS_QPKG_CONF_PATHFILE)
    readonly QPKG_VERSION=$($GETCFG_CMD $QPKG_NAME Version -f $QTS_QPKG_CONF_PATHFILE)
    readonly QPKG_INI_PATHFILE=$QPKG_PATH/$QPKG_NAME/autoProcessMedia.cfg
    readonly QPKG_INI_DEFAULT_PATHFILE=$QPKG_INI_PATHFILE.spec
    readonly INIT_LOG_PATHFILE=/var/log/$QPKG_NAME.log
    local -r BACKUP_PATH=$($GETCFG_CMD SHARE_DEF defVolMP -f /etc/config/def_share.info)/.qpkg_config_backup
    readonly BACKUP_PATHFILE=$BACKUP_PATH/$QPKG_NAME.config.tar.gz
    readonly APPARENT_PATH=/share/$($GETCFG_CMD SHARE_DEF defDownload -d Qdownload -f /etc/config/def_share.info)/$QPKG_NAME

    if [[ -z $LANG ]]; then
        export LANG=en_US.UTF-8
        export LC_ALL=en_US.UTF-8
        export LC_CTYPE=en_US.UTF-8
    fi

    WaitForEntware
    errorcode=0

    [[ ! -d $BACKUP_PATH ]] && mkdir -p "$BACKUP_PATH"

    return 0

    }

ShowHelp()
    {

    Display " $($BASENAME_CMD "$0") ($QPKG_VERSION)"
    Display " A service control script for the $(FormatAsPackageName $QPKG_NAME) QPKG"
    Display
    Display " Usage: $0 [OPTION]"
    Display
    Display " [OPTION] can be any one of the following:"
    Display
    Display " start      - launch $(FormatAsPackageName $QPKG_NAME) if not already running."
    Display " stop       - shutdown $(FormatAsPackageName $QPKG_NAME) if running."
    Display " restart    - stop, then start $(FormatAsPackageName $QPKG_NAME)."
    Display " status     - check if $(FormatAsPackageName $QPKG_NAME) is still running. Always returns \$? = 0 for this package."
    Display " backup     - backup the current $(FormatAsPackageName $QPKG_NAME) configuration to persistent storage."
    Display " restore    - restore a previously saved configuration from persistent storage. $(FormatAsPackageName $QPKG_NAME) will be stopped, then restarted."
    [[ -n $SOURCE_GIT_URL ]] && Display " clean      - wipe the current local copy of $(FormatAsPackageName $QPKG_NAME), and download it again from remote source. Configuration will be retained."
    Display " log        - display this service script runtime log."
    Display " version    - display the package version number."
    Display

    }

StartQPKG()
    {

    local -r SAB_MIN_VERSION=200809

    if [[ -n $SOURCE_GIT_URL ]]; then
        PullGitRepo $QPKG_NAME "$SOURCE_GIT_URL" "$SOURCE_GIT_BRANCH" "$SOURCE_GIT_DEPTH" "$QPKG_PATH"
        cd "$QPKG_PATH/$QPKG_NAME" || return 1
    fi

    if [[ $($GETCFG_CMD SABnzbdplus Enable -f $QTS_QPKG_CONF_PATHFILE) = TRUE ]]; then
        DisplayErrCommitAllLogs "unable to link from package to target: installed SABnzbdplus QPKG must be replaced with SABnzbd $SAB_MIN_VERSION or later"
        return 1
    fi

    if [[ $($GETCFG_CMD SABnzbd Enable -f $QTS_QPKG_CONF_PATHFILE) = TRUE ]]; then
        local current_version=$($GETCFG_CMD SABnzbd Version -f $QTS_QPKG_CONF_PATHFILE)
        if [[ ${current_version//[!0-9]/} -lt $SAB_MIN_VERSION ]]; then
            DisplayErrCommitAllLogs "unable to link from package to target: installed SABnzbd QPKG must first be upgraded to $SAB_MIN_VERSION or later"
            return 1
        fi
    fi

    if [[ -d $APPARENT_PATH ]]; then
        # save config from original nzbToMedia install (which was created by sherpa SABnzbd QPKGs earlier than 200809)
        cp "$APPARENT_PATH/$($BASENAME_CMD "$QPKG_INI_PATHFILE")" "$QPKG_INI_PATHFILE"

        # destroy original installation
        rm -r "$APPARENT_PATH"
    fi

    [[ ! -L $APPARENT_PATH ]] && ln -s "$QPKG_PATH/$QPKG_NAME" "$APPARENT_PATH"

    if [[ ! -f $QPKG_INI_PATHFILE && -f $QPKG_INI_DEFAULT_PATHFILE ]]; then
        DisplayWarnCommitToLog 'no settings file found: using default'
        cp "$QPKG_INI_DEFAULT_PATHFILE" "$QPKG_INI_PATHFILE"
    fi

    return 0

    }

StopQPKG()
    {

    [[ -L $APPARENT_PATH ]] && rm "$APPARENT_PATH"

    }

BackupConfig()
    {

    ExecuteAndLog 'updating configuration backup' "$TAR_CMD --create --gzip --file=$BACKUP_PATHFILE --directory=$QPKG_PATH/$QPKG_NAME autoProcessMedia.cfg" log:everything

    }

RestoreConfig()
    {

    if [[ ! -f $BACKUP_PATHFILE ]]; then
        DisplayErrCommitAllLogs 'unable to restore configuration: no backup file was found!'
        return 1
    fi

    StopQPKG
    ExecuteAndLog 'restoring configuration backup' "$TAR_CMD --extract --gzip --file=$BACKUP_PATHFILE --directory=$QPKG_PATH/$QPKG_NAME" log:everything
    StartQPKG

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

    if [[ ! -d ${QPKG_GIT_PATH}/.git ]]; then
        ExecuteAndLog "cloning $(FormatAsPackageName "$1") from remote repository" "$GIT_CMD clone --branch $3 $depth -c advice.detachedHead=false $GIT_HTTPS_URL $QPKG_GIT_PATH || $GIT_CMD clone --branch $3 $depth -c advice.detachedHead=false $GIT_HTTP_URL $QPKG_GIT_PATH"
    else
        ExecuteAndLog "updating $(FormatAsPackageName "$1") from remote repository" "cd $QPKG_GIT_PATH && $GIT_CMD pull"
    fi

    }

CleanLocalClone()
    {

    # for the rare occasions the local repo becomes corrupt, it needs to be deleted and cloned again from source.

    [[ -z $QPKG_PATH || -z $QPKG_NAME || -z $SOURCE_GIT_URL ]] && return 1

    StopQPKG
    ExecuteAndLog 'cleaning local repo' "rm -r $QPKG_PATH/$QPKG_NAME"
    StartQPKG

    }

ExecuteAndLog()
    {

    # $1 processing message
    # $2 command(s) to run
    # $3 'log:everything' (optional) - if specified, the result of the command is recorded in the QTS system log.
    #                                - if unspecified, only warnings are logged in the QTS system log.

    [[ -z $1 || -z $2 ]] && return 1

    local exec_msgs=''
    local result=0
    local returncode=0

    DisplayWaitCommitToLog "* $1:"
    exec_msgs=$(eval "$2" 2>&1)
    result=$?

    if [[ $result = 0 ]]; then
        DisplayCommitToLog 'OK'
        [[ $3 = log:everything ]] && CommitInfoToSysLog "$1: OK."
    else
        DisplayCommitToLog 'failed!'
        DisplayCommitToLog "$(FormatAsFuncMessages "$exec_msgs")"
        DisplayCommitToLog "$(FormatAsResult $result)"
        CommitWarnToSysLog "A problem occurred while $1. Check $(FormatAsFileName "$INIT_LOG_PATHFILE") for more details."
        returncode=1
    fi

    return $returncode

    }

DisplayDoneCommitToLog()
    {

    DisplayCommitToLog "$(FormatAsDisplayDone "$1")"

    }

DisplayWarnCommitToLog()
    {

    DisplayCommitToLog "$(FormatAsDisplayWarn "$1")"

    }

DisplayErrCommitAllLogs()
    {

    DisplayErrCommitToLog "$1"
    CommitErrToSysLog "$1"

    }

DisplayErrCommitToLog()
    {

    DisplayCommitToLog "$(FormatAsDisplayError "$1")"

    }

DisplayCommitToLog()
    {

    echo "$1" | $TEE_CMD -a $INIT_LOG_PATHFILE

    }

DisplayWaitCommitToLog()
    {

    DisplayWait "$1" | $TEE_CMD -a $INIT_LOG_PATHFILE

    }

FormatAsStdout()
    {

    FormatAsDisplayDone "output: \"$1\""

    }

FormatAsResult()
    {

    FormatAsDisplayDone "result: $(FormatAsExitcode "$1")"

    }

FormatAsFuncMessages()
    {

    echo "= ${FUNCNAME[1]}()"
    FormatAsStdout "$1"

    }

FormatAsDisplayDone()
    {

    Display "= $1"

    }

FormatAsDisplayWarn()
    {

    Display "> $1"

    }

FormatAsDisplayError()
    {

    Display "! $1"

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

Display()
    {

    echo "$1"

    }

DisplayWait()
    {

    echo -n "$1 "

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

    echo "$1" >> "$INIT_LOG_PATHFILE"

    }

CommitSysLog()
    {

    # $1 = message to append to QTS system log
    # $2 = event type:
    #    1 : Error
    #    2 : Warning
    #    4 : Information

    [[ -z $1 || -z $2 ]] && return 1

    $WRITE_LOG_CMD "[$QPKG_NAME] $1" "$2"

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
                [[ -e /opt/Entware.sh || -e /opt/Entware-3x.sh || -e /opt/Entware-ng.sh ]] && { CommitLog "waited for Entware for $count seconds"; true; exit ;}
            done
            false
        )

        if [[ $? -ne 0 ]]; then
            DisplayErrCommitAllLogs "Entware not found! (exceeded timeout: $MAX_WAIT_SECONDS_ENTWARE seconds)"
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
        CommitLog "$(SessionSeparator "'$1' requested")"
        CommitLog "= $(date)"
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
            # always return OK, as this app is only called on-demand by other apps.
            errorcode=0
            ;;
        b|backup)
            BackupConfig || errorcode=1
            ;;
        restore)
            RestoreConfig || errorcode=1
            ;;
        c|clean)
            CleanLocalClone || errorcode=1
            ;;
        l|log)
            if [[ -e $INIT_LOG_PATHFILE ]]; then
                LESSSECURE=1 $GNU_LESS_CMD +G --quit-on-intr --tilde --prompt' use arrow-keys to scroll up-down left-right, press Q to quit' "$INIT_LOG_PATHFILE"
            else
                Display "service log not found: $(FormatAsFileName "$INIT_LOG_PATHFILE")"
            fi
            ;;
        v|version)
            Display "$QPKG_VERSION"
            ;;
        *)
            ShowHelp
            ;;
    esac
fi

exit $errorcode
