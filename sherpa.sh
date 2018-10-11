#!/usr/bin/env bash
###############################################################################
# sherpa.sh
#
# (C)opyright 2017-2018 OneCD - one.cd.only@gmail.com
#
# So, blame OneCD if it all goes horribly wrong. ;)
#
# For more info [https://forum.qnap.com/viewtopic.php?f=320&t=132373]
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program. If not, see http://www.gnu.org/licenses/.
###############################################################################
# * Style Guide *
# function names: CamelCase
# variable names: lowercase_with_underscores (except for 'returncode' & 'errorcode')
# constants: UPPERCASE_WITH_UNDERSCORES
# indents: tab (4 spaces)
###############################################################################

USER_ARGS_RAW="$@"

ResetErrorcode()
    {

    errorcode=0

    }

ParseArgs()
    {

    if [[ -z $USER_ARGS_RAW ]]; then
        errorcode=1
        return 1
    else
        local user_args=($(echo "$USER_ARGS_RAW" | $TR_CMD '[A-Z]' '[a-z]'))
    fi

    for arg in "${user_args[@]}"; do
        case $arg in
            sab|sabnzbd|sabnzbdplus)
                TARGET_APP=SABnzbdplus
                ;;
            sc|sickc|sickchill)
                TARGET_APP=SickChill
                ;;
            cp|cp2|couch|couchpotato|couchpotato2|couchpotatoserver)
                TARGET_APP=CouchPotato2
                ;;
            ll|lazy|lazylibrarian)
                TARGET_APP=LazyLibrarian
                ;;
            med|medusa|omedusa)
                TARGET_APP=OMedusa
                ;;
            hp|head|phones|headphones)
                TARGET_APP=Headphones
                ;;
            -d|--debug)
                debug=true
                DebugVar debug
                ;;
            *)
                break
                ;;
        esac
    done

    return 0

    }

Init()
    {

    local SCRIPT_FILE=sherpa.sh
    local SCRIPT_VERSION=181011
    debug=false
    ResetErrorcode

    # cherry-pick required binaries
    AWK_CMD=/bin/awk
    CAT_CMD=/bin/cat
    CHMOD_CMD=/bin/chmod
    DATE_CMD=/bin/date
    GREP_CMD=/bin/grep
    HOSTNAME_CMD=/bin/hostname
    LN_CMD=/bin/ln
    MD5SUM_CMD=/bin/md5sum
    MKDIR_CMD=/bin/mkdir
    PING_CMD=/bin/ping
    SED_CMD=/bin/sed
    SLEEP_CMD=/bin/sleep
    TOUCH_CMD=/bin/touch
    TR_CMD=/bin/tr
    UNAME_CMD=/bin/uname
    UNIQ_CMD=/bin/uniq

    curl_cmd=/sbin/curl         # this will change depending on QTS version
    GETCFG_CMD=/sbin/getcfg
    RMCFG_CMD=/sbin/rmcfg
    SETCFG_CMD=/sbin/setcfg

    BASENAME_CMD=/usr/bin/basename
    CUT_CMD=/usr/bin/cut
    DIRNAME_CMD=/usr/bin/dirname
    DU_CMD=/usr/bin/du
    HEAD_CMD=/usr/bin/head
    READLINK_CMD=/usr/bin/readlink
    SORT_CMD=/usr/bin/sort
    TAIL_CMD=/usr/bin/tail
    TEE_CMD=/usr/bin/tee
    UNZIP_CMD=/usr/bin/unzip
    UPTIME_CMD=/usr/bin/uptime
    WC_CMD=/usr/bin/wc
    WGET_CMD=/usr/bin/wget
    WHICH_CMD=/usr/bin/which
    ZIP_CMD=/usr/local/sbin/zip

    FIND_CMD=/opt/bin/find
    OPKG_CMD=/opt/bin/opkg

    # paths and files
    QPKG_CONFIG_PATHFILE=/etc/config/qpkg.conf
    INSTALL_LOG_FILE=install.log
    DOWNLOAD_LOG_FILE=download.log
    START_LOG_FILE=start.log
    STOP_LOG_FILE=stop.log
    local DEFAULT_SHARES_PATHFILE=/etc/config/def_share.info
    local ULINUX_PATHFILE=/etc/config/uLinux.conf
    local ISSUE_PATHFILE=/etc/issue
    local DEBUG_LOG_FILE="${SCRIPT_FILE%.*}.debug.log"

    # check required binaries are present
    IsSysFilePresent $AWK_CMD || return
    IsSysFilePresent $CAT_CMD || return
    IsSysFilePresent $CHMOD_CMD || return
    IsSysFilePresent $DATE_CMD || return
    IsSysFilePresent $GREP_CMD || return
    IsSysFilePresent $HOSTNAME_CMD || return
    IsSysFilePresent $LN_CMD || return
    IsSysFilePresent $MD5SUM_CMD || return
    IsSysFilePresent $MKDIR_CMD || return
    IsSysFilePresent $PING_CMD || return
    IsSysFilePresent $SED_CMD || return
    IsSysFilePresent $SLEEP_CMD || return
    IsSysFilePresent $TOUCH_CMD || return
    IsSysFilePresent $TR_CMD || return
    IsSysFilePresent $UNAME_CMD || return
    IsSysFilePresent $UNIQ_CMD || return

    IsSysFilePresent $curl_cmd || return
    IsSysFilePresent $GETCFG_CMD || return
    IsSysFilePresent $RMCFG_CMD || return
    IsSysFilePresent $SETCFG_CMD || return

    IsSysFilePresent $BASENAME_CMD || return
    IsSysFilePresent $CUT_CMD || return
    IsSysFilePresent $DIRNAME_CMD || return
    IsSysFilePresent $DU_CMD || return
    IsSysFilePresent $HEAD_CMD || return
    IsSysFilePresent $READLINK_CMD || return
    IsSysFilePresent $SORT_CMD || return
    IsSysFilePresent $TAIL_CMD || return
    IsSysFilePresent $TEE_CMD || return
    IsSysFilePresent $UNZIP_CMD || return
    IsSysFilePresent $UPTIME_CMD || return
    IsSysFilePresent $WC_CMD || return
    IsSysFilePresent $WGET_CMD || return
    IsSysFilePresent $ZIP_CMD || return

    local DEFAULT_SHARE_DOWNLOAD_PATH=/share/Download
    local DEFAULT_SHARE_PUBLIC_PATH=/share/Public
    local DEFAULT_VOLUME="$($GETCFG_CMD SHARE_DEF defVolMP -f "$DEFAULT_SHARES_PATHFILE")"

    if [[ -L $DEFAULT_SHARE_DOWNLOAD_PATH ]]; then
        SHARE_DOWNLOAD_PATH="$DEFAULT_SHARE_DOWNLOAD_PATH"
    else
        SHARE_DOWNLOAD_PATH="/share/$($GETCFG_CMD SHARE_DEF defDownload -d Qdownload -f "$DEFAULT_SHARES_PATHFILE")"
    fi

    if [[ -L $DEFAULT_SHARE_PUBLIC_PATH ]]; then
        SHARE_PUBLIC_PATH="$DEFAULT_SHARE_PUBLIC_PATH"
    else
        SHARE_PUBLIC_PATH="/share/$($GETCFG_CMD SHARE_DEF defPublic -d Qpublic -f "$DEFAULT_SHARES_PATHFILE")"
    fi

    # check required system paths are present
    IsSysSharePresent "$SHARE_DOWNLOAD_PATH" || return
    IsSysSharePresent "$SHARE_PUBLIC_PATH" || return

    WORKING_PATH="${SHARE_PUBLIC_PATH}/${SCRIPT_FILE%.*}.tmp"
    BACKUP_PATH="${WORKING_PATH}/backup"
    SETTINGS_BACKUP_PATH="${BACKUP_PATH}/config"
    SETTINGS_BACKUP_PATHFILE="${SETTINGS_BACKUP_PATH}/config.ini"
    QPKG_DL_PATH="${WORKING_PATH}/qpkg-downloads"
    IPKG_DL_PATH="${WORKING_PATH}/ipkg-downloads"
    IPKG_CACHE_PATH="${WORKING_PATH}/ipkg-cache"
    DEBUG_LOG_PATHFILE="${SHARE_PUBLIC_PATH}/${DEBUG_LOG_FILE}"
    QPKG_BASE_PATH="${DEFAULT_VOLUME}/.qpkg"
    PACKAGES_PATHFILE="${WORKING_PATH}/packages.conf"

    # internals
    secure_web_login=false
    package_port=0
    SCRIPT_STARTSECONDS=$($DATE_CMD +%s)
    queue_paused=false
    FIRMWARE_VERSION="$($GETCFG_CMD System Version -f "$ULINUX_PATHFILE")"
    NAS_ARCH="$($UNAME_CMD -m)"
    progress_message=''
    previous_length=0
    previous_msg=''
    REINSTALL_FLAG=false
    [[ ${FIRMWARE_VERSION//.} -lt 426 ]] && curl_cmd+=' --insecure'
    local result=0

    ParseArgs

    DebugFuncEntry

    DebugInfoThickSeparator
    DebugScript 'started' "$($DATE_CMD | $TR_CMD -s ' ')"

    [[ $debug = false ]] && echo -e "$(ColourTextBrightWhite "$SCRIPT_FILE") ($SCRIPT_VERSION)\n"

    DebugScript 'version' "$SCRIPT_VERSION"
    DebugInfoThinSeparator
    DebugInfo 'Markers: (**) detected, (II) information, (WW) warning, (LL) log file,'
    DebugInfo ' (EE) error, (==) processing, (--) done, (>>) f entry, (<<) f exit,'
    DebugInfo ' (vv) variable name & value, ($1) positional argument value.'
    DebugInfoThinSeparator
    DebugNAS 'model' "$($GREP_CMD -v "^$" "$ISSUE_PATHFILE" | $SED_CMD 's|^Welcome to ||;s|(.*||')"
    DebugNAS 'firmware version' "$FIRMWARE_VERSION"
    DebugNAS 'firmware build' "$($GETCFG_CMD System 'Build Number' -f "$ULINUX_PATHFILE")"
    DebugNAS 'kernel' "$($UNAME_CMD -mr)"
    DebugNAS 'OS uptime' "$($UPTIME_CMD | $SED_CMD 's|.*up.||;s|,.*load.*||;s|^\ *||')"
    DebugNAS 'system load' "$($UPTIME_CMD | $SED_CMD 's|.*load average: ||' | $AWK_CMD -F', ' '{print "1 min="$1 ", 5 min="$2 ", 15 min="$3}')"
    DebugNAS 'EUID' "$EUID"
    DebugNAS 'default volume' "$DEFAULT_VOLUME"
    DebugNAS '$PATH' "${PATH:0:44}"
    DebugNAS '/opt' "$([[ -L '/opt' ]] && $READLINK_CMD '/opt' || echo "not present")"
    DebugNAS "$SHARE_DOWNLOAD_PATH" "$([[ -L $SHARE_DOWNLOAD_PATH ]] && $READLINK_CMD "$SHARE_DOWNLOAD_PATH" || echo "not present!")"
    DebugScript 'user arguments' "$USER_ARGS_RAW"
    DebugScript 'target app' "$TARGET_APP"
    DebugInfoThinSeparator

    [[ $errorcode -eq 1 ]] && DisplayHelp

    CalcQPKGArch
    CalcStephaneQPKGArch
    CalcPrefEntware

    if [[ $errorcode -eq 0 && $EUID -ne 0 ]]; then
        ShowError "This script must be run as the 'admin' user. Please login via SSH as 'admin' and try again."
        errorcode=2
    fi

    if [[ $errorcode -eq 0 ]]; then
        $MKDIR_CMD -p "$WORKING_PATH" 2> /dev/null
        result=$?

        if [[ $result -ne 0 ]]; then
            ShowError "Unable to create working directory ($WORKING_PATH) [$result]"
            errorcode=3
        else
            cd "$WORKING_PATH"
        fi
    fi

    if [[ $errorcode -eq 0 ]]; then
        $MKDIR_CMD -p "$QPKG_DL_PATH" 2> /dev/null
        result=$?

        if [[ $result -ne 0 ]]; then
            ShowError "Unable to create QPKG download directory ($QPKG_DL_PATH) [$result]"
            errorcode=4
        fi
    fi

    if [[ $errorcode -eq 0 ]]; then
        [[ -d $IPKG_DL_PATH ]] && rm -r "$IPKG_DL_PATH"
        $MKDIR_CMD -p "$IPKG_DL_PATH" 2> /dev/null
        result=$?

        if [[ $result -ne 0 ]]; then
            ShowError "Unable to create IPKG download directory ($IPKG_DL_PATH) [$result]"
            errorcode=5
        else
            monitor_flag="$IPKG_DL_PATH/.monitor"
        fi
    fi

    if [[ $errorcode -eq 0 ]]; then
        $MKDIR_CMD -p "$IPKG_CACHE_PATH" 2> /dev/null
        result=$?

        if [[ $result -ne 0 ]]; then
            ShowError "Unable to create IPKG cache directory ($IPKG_CACHE_PATH) [$result]"
            errorcode=6
        fi
    fi

    if [[ $errorcode -eq 0 ]]; then
        if (IsQPKGInstalled $TARGET_APP && ! IsQPKGEnabled $TARGET_APP); then
            ShowError "'$TARGET_APP' is already installed but is disabled. You'll need to enable it first to allow re-installation."
            REINSTALL_FLAG=true
            errorcode=7
        fi
    fi

    if [[ $errorcode -eq 0 ]]; then
        if [[ $TARGET_APP = SABnzbdplus ]] && IsQPKGEnabled QSabNZBdPlus && IsQPKGEnabled SABnzbdplus; then
            ShowError "Both 'SABnzbdplus' and 'QSabNZBdPlus' are installed. This is an unsupported configuration. Please manually uninstall the unused one via the QNAP App Center then re-run this installer."
            REINSTALL_FLAG=true
            errorcode=8
        fi
    fi

    if [[ $errorcode -eq 0 ]]; then
        if IsQPKGEnabled Optware-NG; then
            ShowError "'Optware-NG' is enabled. This is an unsupported configuration."
            #OPKG_CMD=/opt/bin/ipkg
            errorcode=9
        fi
    fi

    if [[ $errorcode -eq 0 ]]; then
        if IsQPKGEnabled Entware-ng && IsQPKGEnabled Entware-3x; then
            ShowError "Both 'Entware-ng' and 'Entware-3x' are enabled. This is an unsupported configuration. Please manually disable (or uninstall) one or both of them via the QNAP App Center then re-run this installer."
            errorcode=10
        fi
    fi

    if [[ $errorcode -eq 0 ]]; then
        if IsQPKGInstalled $PREF_ENTWARE && [[ $PREF_ENTWARE = Entware-3x || $PREF_ENTWARE = Entware ]]; then
            local test_pathfile=/opt/etc/passwd
            [[ -e $test_pathfile ]] && { [[ -L $test_pathfile ]] && ENTWARE_VER=std || ENTWARE_VER=alt ;} || ENTWARE_VER=none
            DebugQPKG 'Entware installer' $ENTWARE_VER

            if [[ $ENTWARE_VER = none ]]; then
                ShowError 'Entware appears to be installed but is not visible.'
                errorcode=11
            fi
        fi
    fi

    if [[ $errorcode -eq 0 ]]; then
        ShowProc "downloading sherpa package list"

        if ($curl_cmd --silent --fail https://raw.githubusercontent.com/onecdonly/sherpa/master/packages.conf -o $PACKAGES_PATHFILE); then
            ShowDone "downloaded sherpa package list"
        else
            ShowError "No Internet access"
            errorcode=12
        fi
    fi

    DebugFuncExit
    return 0

    }

DisplayHelp()
    {

    DebugFuncEntry

    echo -e "- Each application can be (re)installed by running $0 with the name of a single app as an argument.\n\nSome examples are:"
    echo "$0 SABnzbd"
    echo "$0 SickChill"
    echo "$0 CouchPotato2"
    echo "$0 LazyLibrarian"
    echo "$0 OMedusa"
    echo "$0 Headphones"

    DebugFuncExit
    return 0

    }

PauseDownloaders()
    {

    [[ $errorcode -gt 0 ]] && return

    DebugFuncEntry

    # pause local SABnzbd queue so installer downloads will finish faster
    if IsQPKGEnabled SABnzbdplus; then
        LoadQPKGVars SABnzbdplus
        SabQueueControl pause
    elif IsQPKGEnabled QSabNZBdPlus; then
        LoadQPKGVars QSabNZBdPlus
        SabQueueControl pause
    fi

    DebugFuncExit
    return 0

    }

RemoveOther()
    {

    [[ $errorcode -gt 0 ]] && return

    DebugFuncEntry

    # cruft: remove previous x41 Par2cmdline-MT package due to wrong arch - this was corrected on 2017-06-03 - remove this code after 2018-06-03
        # don't use Par2cmdline-MT for x86_64 as multi-thread changes have been merged upstream into Par2cmdline and Par2cmdline-MT has been discontinued
        case $STEPHANE_QPKG_ARCH in
            x86)
                UninstallQPKG Par2
                ;;
            none)
                ;;
            *)
                UninstallQPKG Par2cmdline-MT
                ;;
        esac
    # end cruft

    UninstallQPKG Optware || ResetErrorcode  # ignore Optware uninstall errors

    DebugFuncExit
    return 0

    }

DownloadQPKGs()
    {

    [[ $errorcode -gt 0 ]] && return

    DebugFuncEntry

    local returncode=0
    local SL=''

    ! IsQPKGInstalled $PREF_ENTWARE && DownloadQPKG $PREF_ENTWARE

    if [[ $TARGET_APP = SABnzbdplus ]]; then
        case $STEPHANE_QPKG_ARCH in
            x86)
                ! IsQPKGInstalled Par2cmdline-MT && DownloadQPKG Par2cmdline-MT
                ;;
            none)
                ;;
            *)
                ! IsQPKGInstalled Par2 && DownloadQPKG Par2
                ;;
        esac
    fi

    DownloadQPKG $TARGET_APP

    DebugFuncExit
    return $returncode

    }

InstallEntware()
    {

    [[ $errorcode -gt 0 ]] && return

    DebugFuncEntry

    local returncode=0

    if ! IsQPKGInstalled $PREF_ENTWARE; then
        # rename original [/opt]
        opt_path=/opt
        opt_backup_path=/opt.orig
        [[ -d $opt_path && ! -L $opt_path && ! -e $opt_backup_path ]] && mv "$opt_path" "$opt_backup_path"

        InstallQPKG $PREF_ENTWARE && ReloadProfile

        # copy all files from original [/opt] into new [/opt]
        [[ -L $opt_path && -d $opt_backup_path ]] && cp --recursive "$opt_backup_path"/* --target-directory "$opt_path" && rm -r "$opt_backup_path"
    else
        ! IsQPKGEnabled $PREF_ENTWARE && EnableQPKG $PREF_ENTWARE
        ReloadProfile

        [[ $STEPHANE_QPKG_ARCH != none ]] && ($OPKG_CMD list-installed | $GREP_CMD -q par2cmdline) && $OPKG_CMD remove par2cmdline > /dev/null 2>&1
    fi

    PatchEntwareInit

    DebugFuncExit
    return $returncode

    }

PatchEntwareInit()
    {

    DebugFuncEntry

    local returncode=0
    local find_text=''
    local insert_text=''

    LoadQPKGVars $PREF_ENTWARE

    if [[ ! -e $package_init_pathfile ]]; then
        ShowError "No init file found [$package_init_pathfile]"
        errorcode=13
        returncode=1
    else
        if ($GREP_CMD -q 'opt.orig' "$package_init_pathfile"); then
            DebugInfo 'patch: do the "opt shuffle" - already done'
        else
            find_text='/bin/rm -rf /opt'
            insert_text='opt_path="/opt"; opt_backup_path="/opt.orig"; [ -d "$opt_path" ] \&\& [ ! -L "$opt_path" ] \&\& [ ! -e "$opt_backup_path" ] \&\& mv "$opt_path" "$opt_backup_path"'
            $SED_CMD -i "s|$find_text|$insert_text\n$find_text|" "$package_init_pathfile"

            find_text='/bin/ln -sf $QPKG_DIR /opt'
            insert_text=$(echo -e "\t")'[ -L "$opt_path" ] \&\& [ -d "$opt_backup_path" ] \&\& cp "$opt_backup_path"/* --target-directory "$opt_path" \&\& rm -r "$opt_backup_path"'
            $SED_CMD -i "s|$find_text|$find_text\n$insert_text\n|" "$package_init_pathfile"

            DebugDone 'patch: do the "opt shuffle"'
        fi
    fi

    DebugFuncExit
    return $returncode

    }

UpdateEntware()
    {

    DebugFuncEntry

    local package_list_file=/opt/var/opkg-lists/entware
    local package_list_age=60
    local release_file=/opt/etc/entware_release
    local result=0
    local log_pathfile="${WORKING_PATH}/entware-update.log"

    IsSysFilePresent $OPKG_CMD || return
    IsSysFilePresent $FIND_CMD || return

    # if Entware package list was updated only recently, don't run another update
    [[ -e $FIND_CMD && -e $package_list_file ]] && result=$($FIND_CMD "$package_list_file" -mmin +$package_list_age) || result='new install'

    if [[ -n $result ]]; then
        ShowProc "updating Entware package list"

        install_msgs=$($OPKG_CMD update)
        result=$?
        echo -e "${install_msgs}\nresult=[$result]" >> "$log_pathfile"

        if [[ $PREF_ENTWARE = Entware-3x && ! -e $release_file ]]; then
            DebugProc 'performing Entware-3x upgrade x 2'
            install_msgs=$($OPKG_CMD upgrade; $OPKG_CMD update; $OPKG_CMD upgrade)
            result=$?
            echo -e "${install_msgs}\nresult=[$result]" >> "$log_pathfile"
        fi

        if [[ $result -eq 0 ]]; then
            ShowDone "updated Entware package list"
        else
            ShowWarning "Unable to update Entware package list [$result]"
            # meh, continue anyway with old list ...
        fi
    else
        DebugInfo "Entware package list was updated less than $package_list_age minutes ago"
        ShowDone "Entware package list is up-to-date"
    fi

    DebugFuncExit
    return 0

    }

InstallExtras()
    {

    [[ $errorcode -gt 0 ]] && return

    DebugFuncEntry

    if [[ $TARGET_APP = SABnzbdplus ]]; then
        case $STEPHANE_QPKG_ARCH in
            x86)
                InstallQPKG Par2cmdline-MT
                if [[ $errorcode -gt 0 ]]; then
                    ShowWarning "Par2cmdline-MT installation failed - but it's not essential so I'm continuing"
                    ResetErrorcode
                    DebugVar errorcode
                fi
                ;;
            none)
                ;;
            *)
                InstallQPKG Par2
                if [[ $errorcode -gt 0 ]]; then
                    ShowWarning "Par2 installation failed - but it's not essential so I'm continuing"
                    ResetErrorcode
                    DebugVar errorcode
                fi
                ;;
        esac
    fi

    InstallIPKGs
    InstallPIPs

    DebugFuncExit
    return 0

    }

InstallTargetApp()
    {

    [[ $errorcode -gt 0 ]] && return

    DebugFuncEntry

    case $TARGET_APP in
        SABnzbdplus|SickChill|CouchPotato2|LazyLibrarian|OMedusa|Headphones)
            IsQPKGEnabled $TARGET_APP && BackupConfig && UninstallQPKG $TARGET_APP
            [[ $TARGET_APP = SABnzbdplus ]] && IsQPKGEnabled QSabNZBdPlus && BackupConfig && UninstallQPKG QSabNZBdPlus
            [[ $TARGET_APP = SickChill ]] && IsQPKGEnabled SickRage && BackupConfig && UninstallQPKG SickRage
            ! IsQPKGInstalled $TARGET_APP && InstallQPKG $TARGET_APP && PauseHere && RestoreConfig
            [[ $errorcode -eq 0 ]] && DaemonCtl start "$package_init_pathfile"
            ;;
        *)
            ShowError "Can't install app '$TARGET_APP' as it's unknown"
            ;;
    esac

    DebugFuncExit
    return 0

    }

InstallIPKGs()
    {

    [[ $errorcode -gt 0 ]] && return

    DebugFuncEntry

    local returncode=0
    local install_msgs=''
    local packages=''

    if [[ -n $IPKG_DL_PATH && -d $IPKG_DL_PATH ]]; then
        UpdateEntware
        packages='python python-pip git git-http nano less'

        case $TARGET_APP in
            SABnzbdplus)
                packages+=' python-pyopenssl python-dev gcc unrar p7zip coreutils-nice ionice ffprobe'
                [[ $STEPHANE_QPKG_ARCH = none ]] && packages+=' par2cmdline'
                ;;
            CouchPotato2)
                packages+=' python-pyopenssl python-lxml'
                ;;
            OMedusa)
                packages+=' python-lib2to3'
                ;;
        esac
        InstallIPKGBatch "$packages" 'Python, Git and others'
    else
        ShowError "IPKG download path [$IPKG_DL_PATH] does not exist"
        errorcode=14
        returncode=1
    fi

    DebugFuncExit
    return $returncode

    }

InstallIPKGBatch()
    {

    # $1 = space-separated string containing list of IPKG names to download and install
    # $2 = on-screen description of this package batch

    DebugFuncEntry

    local result=0
    local returncode=0
    local requested_IPKGs=''
    local IPKG_batch_desc=''
    local log_pathfile="${IPKG_DL_PATH}/ipkgs.$INSTALL_LOG_FILE"

    [[ -n $1 ]] && requested_IPKGs="$1" || return 1
    [[ -n $2 ]] && IPKG_batch_desc="$2" || IPKG_batch_desc="$1"

    # errors can occur due to incompatible IPKGs (tried installing Entware-3x, then Entware-ng), so delete them first
    [[ -d $IPKG_DL_PATH ]] && rm -f "$IPKG_DL_PATH"/*.ipk

    FindAllIPKGDependencies "$requested_IPKGs"

    if [[ $IPKG_download_count -gt 0 ]]; then
        IPKG_download_startseconds=$($DATE_CMD +%s)
        ShowProc "downloading & installing $IPKG_download_count IPKGs ($IPKG_batch_desc)"
        $TOUCH_CMD "$monitor_flag"
        trap CTRL_C_Captured INT

        _MonitorDirSize_ "$IPKG_DL_PATH" $IPKG_download_size &
        install_msgs=$($OPKG_CMD install --force-overwrite ${IPKG_download_list[*]} --cache "$IPKG_CACHE_PATH" --tmp-dir "$IPKG_DL_PATH" 2>&1)
        result=$?

        [[ -e $monitor_flag ]] && { rm "$monitor_flag"; $SLEEP_CMD 1 ;}
        trap - INT
        echo -e "${install_msgs}\nresult=[$result]" > "$log_pathfile"

        if [[ $result -eq 0 ]]; then
            ShowDone "downloaded & installed $IPKG_download_count IPKGs ($IPKG_batch_desc)"
            DebugStage 'elapsed time' "$(ConvertSecs "$(($($DATE_CMD +%s)-$([[ -n $IPKG_download_startseconds ]] && echo $IPKG_download_startseconds || echo "1")))")"
        else
            ShowError "Download & install IPKGs failed ($IPKG_batch_desc) [$result]"
            DebugErrorFile "$log_pathfile"

            errorcode=15
            returncode=1
        fi
    fi

    DebugFuncExit
    return $returncode

    }

InstallPIPs()
    {

    [[ $errorcode -gt 0 ]] && return

    DebugFuncEntry

    local install_msgs=''
    local result=0
    local returncode=0
    local op='PIP modules'
    local pip_cmd='pip install setuptools'
    local log_pathfile="${WORKING_PATH}/${op// /_}.$INSTALL_LOG_FILE"

    ShowProc "downloading & installing ($op)"

    case $TARGET_APP in
        SABnzbdplus)
            pip_cmd+=' && pip install sabyenc==3.3.5 cheetah'
            ;;
    esac

    install_msgs=$({ eval $pip_cmd ;} 2>&1)
    result=$?
    echo -e "${install_msgs}\nresult=[$result]" > "$log_pathfile"

    if [[ $result -eq 0 ]]; then
        ShowDone "downloaded & installed ($op)"
    else
        ShowError "Download & install failed ($op) [$result]"
        DebugErrorFile "$log_pathfile"

        errorcode=16
        returncode=1
    fi

    DebugFuncExit
    return $returncode

    }

InstallNG()
    {

    [[ $errorcode -gt 0 ]] && return

    DebugFuncEntry

    if ! IsIPKGInstalled nzbget; then
        local install_msgs=''
        local result=0
        local packages=''
        local package_desc=''
        local returncode=0

        InstallIPKGBatch 'nzbget' 'NZBGet'

        if [[ $? -eq 0 ]]; then
            ShowProc "modifying NZBGet"

            $SED_CMD -i 's|ConfigTemplate=.*|ConfigTemplate=/opt/share/nzbget/nzbget.conf.template|g' /opt/share/nzbget/nzbget.conf
            ShowDone "modified NZBGet"
            /opt/etc/init.d/S75nzbget start
            $CAT_CMD /opt/share/nzbget/nzbget.conf | $GREP_CMD ControlPassword=
            #Go to default router ip address and port 6789 192.168.1.1:6789 and now you should see NZBget interface
        else
            ShowError "Download & install IPKG failed ($package_desc) [$result]"
            errorcode=17
            returncode=1
        fi
    fi

    DebugFuncExit
    return 0

    }

InstallQPKG()
    {

    local target_file=''
    local install_msgs=''
    local result=0
    local returncode=0

    if [[ -z $1 ]]; then
        DebugError 'QPKG name unspecified'
        errorcode=18
        return 1
    fi

    if IsQPKGInstalled $1; then
        DebugInfo "QPKG '$1' is already installed"
        if IsQPKGEnabled $1; then
            DebugInfo "QPKG '$1' is already enabled"
        else
            EnableQPKG $1
        fi
        return 0
    fi

    LoadQPKGFileDetails $1

    if [[ ${qpkg_pathfile##*.} = zip ]]; then
        $UNZIP_CMD -nq "$qpkg_pathfile" -d "$QPKG_DL_PATH"
        qpkg_pathfile="${qpkg_pathfile%.*}"
    fi

    local log_pathfile="$qpkg_pathfile.$INSTALL_LOG_FILE"
    target_file=$($BASENAME_CMD "$qpkg_pathfile")
    ShowProc "installing QPKG ($target_file) - this can take a while"
    install_msgs=$(eval sh "$qpkg_pathfile" 2>&1)
    result=$?

    echo -e "${install_msgs}\nresult=[$result]" > "$log_pathfile"

    if [[ $result -eq 0 || $result -eq 10 ]]; then
        ShowDone "installed QPKG ($target_file)"
    else
        ShowError "QPKG installation failed ($target_file) [$result]"
        DebugErrorFile "$log_pathfile"

        errorcode=19
        returncode=1
    fi

    return $returncode

    }

BackupThisPackage()
    {

    local result=0

    DebugVar package_config_path
    backup_pathfile="${BACKUP_PATH}/config/sherpa.config.backup.zip"
    DebugVar backup_pathfile

    if [[ -d $package_config_path ]]; then
        if [[ ! -d ${BACKUP_PATH}/config ]]; then
            $MKDIR_CMD -p "$BACKUP_PATH" 2> /dev/null
            result=$?

            if [[ $result -eq 0 ]]; then
                DebugDone "backup directory created ($BACKUP_PATH)"
            else
                ShowError "Unable to create backup directory ($BACKUP_PATH) [$result]"
                errorcode=20
                return 1
            fi
        fi

        if [[ ! -d ${BACKUP_PATH}/config ]]; then
            mv "$package_config_path" "$BACKUP_PATH"
            mvresult=$?

            [[ -e $backup_pathfile ]] && rm "$backup_pathfile"

            $ZIP_CMD -q "$backup_pathfile" "${BACKUP_PATH}/config/"*
            zipresult=$?

            if [[ $mvresult -eq 0 && $zipresult -eq 0 ]]; then
                ShowDone "created '$TARGET_APP' settings backup"
            else
                ShowError "Could not create settings backup of ($package_config_path) [$result]"
                errorcode=21
                return 1
            fi
        else
            DebugInfo "a backup set already exists ($BACKUP_PATH)"
        fi

        ConvertSettings
    else
        ShowError "Could not find existing package configuration path. Can't safely continue with backup. Aborting."
        errorcode=22
    fi

    }

BackupConfig()
    {

    [[ $errorcode -gt 0 ]] && return

    DebugFuncEntry

    local returncode=0

    case $TARGET_APP in
        SABnzbdplus)
            if IsQPKGEnabled QSabNZBdPlus; then
                LoadQPKGVars QSabNZBdPlus
                DaemonCtl stop "$package_init_pathfile"
            elif IsQPKGEnabled $TARGET_APP; then
                LoadQPKGVars $TARGET_APP
                DaemonCtl stop "$package_init_pathfile"
            fi

            REINSTALL_FLAG=$package_is_installed
            [[ $package_is_installed = true ]] && BackupThisPackage
            ;;
        SickChill)
            if IsQPKGEnabled SickRage; then
                LoadQPKGVars SickRage
                DaemonCtl stop "$package_init_pathfile"
            elif IsQPKGEnabled $TARGET_APP; then
                LoadQPKGVars $TARGET_APP
                DaemonCtl stop "$package_init_pathfile"
            fi

            REINSTALL_FLAG=$package_is_installed
            [[ $package_is_installed = true ]] && BackupThisPackage
            ;;
        CouchPotato2)
            if IsQPKGEnabled QCouchPotato; then
                LoadQPKGVars QCouchPotato
                DaemonCtl stop "$package_init_pathfile"
            elif IsQPKGEnabled $TARGET_APP; then
                LoadQPKGVars $TARGET_APP
                DaemonCtl stop "$package_init_pathfile"
            fi

            REINSTALL_FLAG=$package_is_installed
            [[ $package_is_installed = true ]] && BackupThisPackage
            ;;
        LazyLibrarian|SickRage|OMedusa|Headphones)
            if IsQPKGEnabled $TARGET_APP; then
                LoadQPKGVars $TARGET_APP
                DaemonCtl stop "$package_init_pathfile"
            fi

            REINSTALL_FLAG=$package_is_installed
            [[ $package_is_installed = true ]] && BackupThisPackage
            ;;
        *)
            ShowError "Can't backup specified app '$TARGET_APP' - unknown!"
            returncode=1
            ;;
    esac

    DebugFuncExit
    return $returncode

    }

ConvertSettings()
    {

    DebugFuncEntry

    local returncode=0

    case $TARGET_APP in
        SABnzbdplus)
            local OLD_BACKUP_PATH="${BACKUP_PATH}/SAB_CONFIG"
            [[ -d $OLD_BACKUP_PATH ]] && { mv "$OLD_BACKUP_PATH" "$SETTINGS_BACKUP_PATH"; DebugDone 'renamed backup config path' ;}

            OLD_BACKUP_PATH="${BACKUP_PATH}/Config"
            [[ -d $OLD_BACKUP_PATH ]] && { mv "$OLD_BACKUP_PATH" "$SETTINGS_BACKUP_PATH"; DebugDone 'renamed backup config path' ;}

            # for converting from Stephane's QPKG and from previous version SAB QPKGs
            local SETTINGS_PREV_BACKUP_PATHFILE="${SETTINGS_BACKUP_PATH}/sabnzbd.ini"

            [[ -f $SETTINGS_PREV_BACKUP_PATHFILE ]] && { mv "$SETTINGS_PREV_BACKUP_PATHFILE" "$SETTINGS_BACKUP_PATHFILE"; DebugDone 'renamed backup config file' ;}

            if [[ -f $SETTINGS_BACKUP_PATHFILE ]]; then
                $SED_CMD -i "s|log_dir = logs|log_dir = ${SHARE_DOWNLOAD_PATH}/sabnzbd/logs|" "$SETTINGS_BACKUP_PATHFILE"
                $SED_CMD -i "s|download_dir = Downloads/incomplete|download_dir = ${SHARE_DOWNLOAD_PATH}/incomplete|" "$SETTINGS_BACKUP_PATHFILE"
                $SED_CMD -i "s|complete_dir = Downloads/complete|complete_dir = ${SHARE_DOWNLOAD_PATH}/complete|" "$SETTINGS_BACKUP_PATHFILE"

                if ($GREP_CMD -q '^enable_https = 1' "$SETTINGS_BACKUP_PATHFILE"); then
                    package_port=$($GREP_CMD '^https_port = ' "$SETTINGS_BACKUP_PATHFILE" | $HEAD_CMD -n1 | $CUT_CMD -f3 -d' ')
                    secure_web_login=true
                else
                    package_port=$($GREP_CMD '^port = ' "$SETTINGS_BACKUP_PATHFILE" | $HEAD_CMD -n1 | $CUT_CMD -f3 -d' ')
                fi
            fi
            ;;
        SickChill)
            # temporary patch - ensure user's config file is patched with the new SickChill URL
            [[ -f $SETTINGS_BACKUP_PATHFILE ]] && setcfg General git_remote_url 'http://github.com/sickchill/sickchill.git' -f  "$SETTINGS_BACKUP_PATHFILE"
            ;;
        LazyLibrarian|OMedusa|Headphones)
            # do nothing - don't need to convert from older versions for these QPKGs as sherpa is the only installer for them.
            ;;
        CouchPotato2)
            ShowWarning "Can't convert settings for '$TARGET_APP' yet!"
            ;;
        *)
            ShowError "Can't convert settings for '$TARGET_APP' - unsupported app!"
            returncode=1
            ;;
    esac

    DebugFuncExit
    return $returncode

    }

ReloadProfile()
    {

    IsQPKGInstalled $PREF_ENTWARE && PATH="/opt/bin:/opt/sbin:$PATH"

    DebugDone 'adjusted $PATH'
    DebugVar PATH

    return 0

    }

RestoreConfig()
    {

    [[ $errorcode -gt 0 ]] && return

    DebugFuncEntry

    local result=0
    local returncode=0

    if IsQPKGInstalled $TARGET_APP; then
        LoadQPKGVars $TARGET_APP

        case $TARGET_APP in
            SABnzbdplus|LazyLibrarian|SickChill|CouchPotato2|OMedusa|Headphones)
                if [[ -d $SETTINGS_BACKUP_PATH ]]; then
                    DaemonCtl stop "$package_init_pathfile"

                    if [[ ! -d $package_config_path ]]; then
                        $MKDIR_CMD -p "$($DIRNAME_CMD "$package_config_path")" 2> /dev/null
                    else
                        rm -r "$package_config_path" 2> /dev/null
                    fi

                    mv "$SETTINGS_BACKUP_PATH" "$($DIRNAME_CMD "$package_config_path")"
                    result=$?

                    if [[ $result -eq 0 ]]; then
                        ShowDone "restored '$TARGET_APP' settings backup"

                        [[ -n $package_port ]] && $SETCFG_CMD "$TARGET_APP" Web_Port $package_port -f "$QPKG_CONFIG_PATHFILE"
                    else
                        ShowError "Could not restore settings backup to ($package_config_path) [$result]"
                        errorcode=23
                        returncode=1
                    fi
                fi
                ;;
            *)
                ShowError "Can't restore settings for '$TARGET_APP' - unsupported app!"
                returncode=1
                ;;
        esac
    else
        ShowError "'$TARGET_APP' is NOT installed so can't restore backups"
        errorcode=24
        returncode=1
    fi

    DebugFuncExit
    return $returncode

    }

DownloadQPKG()
    {

    [[ $errorcode -gt 0 ]] && return

    if [[ -z $1 ]]; then
        DebugError 'QPKG name unspecified'
        errorcode=25
        return 1
    fi

    DebugFuncEntry

    local result=0
    local returncode=0

    LoadQPKGFileDetails $1

    if [[ -e $qpkg_pathfile ]]; then
        file_md5=$($MD5SUM_CMD "$qpkg_pathfile" | $CUT_CMD -f1 -d' ')
        result=$?

        if [[ $result -eq 0 ]]; then
            if [[ $file_md5 = $qpkg_md5 ]]; then
                DebugInfo "existing QPKG checksum correct ($qpkg_file)"
            else
                DebugWarning "existing QPKG checksum incorrect ($qpkg_file) [$result]"
                DebugInfo "deleting ($qpkg_pathfile) [$result]"
                rm -f "$qpkg_pathfile"
            fi
        else
            ShowError "Problem creating checksum from existing QPKG ($qpkg_file) [$result]"
            errorcode=26
            returncode=1
        fi
    fi

    if [[ $errorcode -eq 0 && ! -e $qpkg_pathfile ]]; then
        ShowProc "downloading QPKG ($qpkg_file)"
        local log_pathfile="$qpkg_pathfile.$DOWNLOAD_LOG_FILE"

        [[ -e $log_pathfile ]] && rm -f "$log_pathfile"

        # keep this one handy for SOCKS5
        # curl http://entware-3x.zyxmon.org/binaries/other/Entware-3x_1.00std.qpkg --socks5 IP:PORT --output target.qpkg

        if [[ $debug = true ]]; then
            $curl_cmd --output "$qpkg_pathfile" "$qpkg_url" 2>&1 | $TEE_CMD -a "$log_pathfile"
            result=$?
        else
            $curl_cmd --output "$qpkg_pathfile" "$qpkg_url" >> "$log_pathfile" 2>&1
            result=$?
        fi

        echo -e "\nresult=[$result]" >> "$log_pathfile"

        if [[ $result -eq 0 ]]; then
            file_md5=$($MD5SUM_CMD "$qpkg_pathfile" | $CUT_CMD -f1 -d' ')
            result=$?

            if [[ $result -eq 0 ]]; then
                if [[ $file_md5 = $qpkg_md5 ]]; then
                    ShowDone "downloaded QPKG ($qpkg_file)"
                else
                    ShowError "Downloaded QPKG checksum incorrect ($qpkg_file) [$result]"
                    errorcode=27
                    returncode=1
                fi
            else
                ShowError "Problem creating checksum from downloaded QPKG ($qpkg_pathfile) [$result]"
                errorcode=28
                returncode=1
            fi
        else
            ShowError "Download failed ($qpkg_pathfile) [$result]"
            DebugErrorFile "$log_pathfile"

            errorcode=29
            returncode=1
        fi
    fi

    DebugFuncExit
    return $returncode

    }

CalcStephaneQPKGArch()
    {

    # decide which package arch is suitable for this NAS

    case $NAS_ARCH in
        x86_64)
            [[ ${FIRMWARE_VERSION//.} -ge 430 ]] && STEPHANE_QPKG_ARCH=x64 || STEPHANE_QPKG_ARCH=x86
            ;;
        i686)
            STEPHANE_QPKG_ARCH=x86
            ;;
        armv7l)
            STEPHANE_QPKG_ARCH=x41
            ;;
        *)
            STEPHANE_QPKG_ARCH=none
            ;;
    esac

    DebugVar STEPHANE_QPKG_ARCH
    return 0

    }

CalcQPKGArch()
    {

    # adapt package arch depending on NAS arch

    case $NAS_ARCH in
        x86_64)
            [[ ${FIRMWARE_VERSION//.} -ge 430 ]] && QPKG_ARCH=x64 || QPKG_ARCH=x86
            ;;
        i686)
            QPKG_ARCH=x86
            ;;
        *)
            QPKG_ARCH=$NAS_ARCH
            ;;
    esac

    DebugVar QPKG_ARCH
    return 0

    }

CalcPrefEntware()
    {

    # decide which Entware is suitable for this NAS

    # start with the default preferred variant
    PREF_ENTWARE=Entware

    # then modify according to local environment
    IsQPKGInstalled Entware-ng && PREF_ENTWARE=Entware-ng
    IsQPKGInstalled Entware-3x && PREF_ENTWARE=Entware-3x

    DebugVar PREF_ENTWARE
    return 0

    }

LoadQPKGVars()
    {

    # $1 = installed package name to load variables for

    local package_name=$1
    local result=0
    local returncode=0

    if [[ -z $package_name ]]; then
        DebugError 'QPKG name unspecified'
        errorcode=30
        returncode=1
    else
        package_installed_path=''
        package_init_pathfile=''
        package_config_path=''
        local package_settings_pathfile=''
        package_port=''
        package_api=''
        sab_chartranslator_pathfile=''

        case $package_name in
            SABnzbdplus|QSabNZBdPlus)
                package_installed_path=$($GETCFG_CMD $package_name Install_Path -f $QPKG_CONFIG_PATHFILE)
                result=$?

                if [[ $result -eq 0 ]]; then
                    package_init_pathfile=$($GETCFG_CMD $package_name Shell -f $QPKG_CONFIG_PATHFILE)

                    if [[ $package_name = SABnzbdplus ]]; then
                        if [[ -d ${package_installed_path}/Config ]]; then
                            package_config_path=${package_installed_path}/Config
                        else
                            package_config_path=${package_installed_path}/config
                        fi

                    elif [[ $package_name = QSabNZBdPlus ]]; then
                        package_config_path=${package_installed_path}/SAB_CONFIG
                    fi

                    if [[ -f ${package_config_path}/sabnzbd.ini ]]; then
                        package_settings_pathfile=${package_config_path}/sabnzbd.ini
                    else
                        package_settings_pathfile=${package_config_path}/config.ini
                    fi

                    if [[ -e $SETTINGS_BACKUP_PATHFILE ]]; then
                        if ($GREP_CMD -q '^enable_https = 1' "$SETTINGS_BACKUP_PATHFILE"); then
                            package_port=$($GREP_CMD '^https_port = ' "$SETTINGS_BACKUP_PATHFILE" | $HEAD_CMD -n1 | $CUT_CMD -f3 -d' ')
                            secure_web_login=true
                        else
                            package_port=$($GREP_CMD '^port = ' "$SETTINGS_BACKUP_PATHFILE" | $HEAD_CMD -n1 | $CUT_CMD -f3 -d' ')
                        fi
                    else
                        package_port=$($GETCFG_CMD $package_name Web_Port -f $QPKG_CONFIG_PATHFILE)
                    fi

                    [[ -e $package_settings_pathfile ]] && package_api=$($GREP_CMD -e "^api_key" "$package_settings_pathfile" | $SED_CMD 's|api_key = ||')
                    sab_chartranslator_pathfile=$package_installed_path/scripts/CharTranslator.py
                else
                    returncode=1
                fi
                ;;
            Entware|Entware-3x|Entware-ng|LazyLibrarian|CouchPotato2|QCouchPotato|OMedusa|Headphones|SickChill|SickRage)
                package_installed_path=$($GETCFG_CMD $package_name Install_Path -f $QPKG_CONFIG_PATHFILE)
                result=$?

                if [[ $result -eq 0 ]]; then
                    package_init_pathfile=$($GETCFG_CMD $package_name Shell -f $QPKG_CONFIG_PATHFILE)

                    if [[ -d ${package_installed_path}/Config ]]; then
                        package_config_path=${package_installed_path}/Config
                    else
                        package_config_path=${package_installed_path}/config
                    fi
                else
                    returncode=1
                fi
                ;;
            *)
                ShowError "Can't load details of specified app [$package_name] as it's unknown"
                ;;

        esac
    fi

    return $returncode

    }

LoadQPKGFileDetails()
    {

    # $1 = QPKG name

    qpkg_url=''
    qpkg_md5=''
    qpkg_file=''
    qpkg_pathfile=''
    local returncode=0
    local target_file=''
    local OneCD_url_prefix='https://raw.githubusercontent.com/onecdonly/sherpa/master/QPKGs'
    local Stephane_url_prefix='http://www.qoolbox.fr'

    if [[ -z $1 ]]; then
        DebugError 'QPKG name unspecified'
        errorcode=31
        returncode=1
    else
        qpkg_name=$1
        local base_url=''

        case $1 in
            Entware)
                qpkg_url='http://bin.entware.net/other/Entware_1.00std.qpkg'
                qpkg_md5='0c99cf2cf8ef61c7a18b42651a37da74'
                ;;
            SABnzbdplus)
                qpkg_url="${OneCD_url_prefix}/SABnzbdplus/build/SABnzbdplus_180909.qpkg"
                qpkg_md5='56dbba3f5fa53b25c70ff5f822499ddb'
                ;;
            #SickRage)
            #    qpkg_url="${OneCD_url_prefix}/SickRage/build/SickRage_180709.qpkg"
            #    qpkg_md5='465139467dfa7bf48cfeadf0d019c609'
            #    ;;
            SickChill)
                qpkg_url="${OneCD_url_prefix}/SickChill/build/SickChill_181011.qpkg"
                qpkg_md5='552d3c1fc5ddd832fc8f70327fbcb11f'
                ;;
            CouchPotato2)
                qpkg_url="${OneCD_url_prefix}/CouchPotato2/build/CouchPotato2_180427.qpkg"
                qpkg_md5='395ffdb9c25d0bc07eb24987cc722cdb'
                ;;
            LazyLibrarian)
                qpkg_url="${OneCD_url_prefix}/LazyLibrarian/build/LazyLibrarian_180630.qpkg"
                qpkg_md5='a5f29c2f2d5e5d313104d5e518a60be1'
                ;;
            OMedusa)
                qpkg_url="${OneCD_url_prefix}/OMedusa/build/OMedusa_180427.qpkg"
                qpkg_md5='ec3b193c7931a100067cfaa334caf883'
                ;;
            Headphones)
                qpkg_url="${OneCD_url_prefix}/Headphones/build/Headphones_180429.qpkg"
                qpkg_md5='c1b5ba10f5636b4e951eb57fb2bb1ed5'
                ;;
            Par2cmdline-MT)
                case $STEPHANE_QPKG_ARCH in
                    x86)
                        qpkg_url="${Stephane_url_prefix}/Par2cmdline-MT_0.6.14-MT_x86.qpkg.zip"
                        qpkg_md5='531832a39576e399f646890cc18969bb'
                        ;;
                    x64)
                        qpkg_url="${Stephane_url_prefix}/Par2cmdline-MT_0.6.14-MT_x86_64.qpkg.zip"
                        qpkg_md5='f3b3dd496289510ec0383cf083a50f8e'
                        ;;
                    x41)
                        qpkg_url="${Stephane_url_prefix}/Par2cmdline-MT_0.6.14-MT_arm-x41.qpkg.zip"
                        qpkg_md5='1701b188115758c151f19956388b90cb'
                        ;;
                esac
                ;;
            Par2)
                case $STEPHANE_QPKG_ARCH in
                    x64)
                        qpkg_url="${Stephane_url_prefix}/Par2_0.7.4.0_x86_64.qpkg.zip"
                        qpkg_md5='660882474ab00d4793a674d4b48f89be'
                        ;;
                    x41)
                        qpkg_url="${Stephane_url_prefix}/Par2_0.7.4.0_arm-x41.qpkg.zip"
                        qpkg_md5='9c0c9d3e8512f403f183856fb80091a4'
                        ;;
                esac
                ;;
            *)
                DebugError 'QPKG name not found'
                errorcode=32
                returncode=1
                ;;
        esac

        if [[ -z $qpkg_url || -z $qpkg_md5 ]]; then
            DebugError 'QPKG details not found'
            errorcode=33
            returncode=1
        else
            [[ -z $qpkg_file ]] && qpkg_file=$($BASENAME_CMD "$qpkg_url")
            qpkg_pathfile="${QPKG_DL_PATH}/${qpkg_file}"
        fi
    fi

    return $returncode

    }

UninstallQPKG()
    {

    # $1 = QPKG name

    [[ $errorcode -gt 0 ]] && return

    local result=0
    local returncode=0

    if [[ -z $1 ]]; then
        DebugError 'QPKG name unspecified'
        errorcode=34
        returncode=1
    else
        qpkg_installed_path="$($GETCFG_CMD "$1" Install_Path -f "$QPKG_CONFIG_PATHFILE")"
        result=$?

        if [[ $result -eq 0 ]]; then
            qpkg_installed_path="$($GETCFG_CMD "$1" Install_Path -f "$QPKG_CONFIG_PATHFILE")"

            if [[ -e ${qpkg_installed_path}/.uninstall.sh ]]; then
                ShowProc "uninstalling QPKG '$1'"

                ${qpkg_installed_path}/.uninstall.sh > /dev/null
                result=$?

                if [[ $result -eq 0 ]]; then
                    ShowDone "uninstalled QPKG '$1'"
                else
                    ShowError "Unable to uninstall QPKG \"$1\" [$result]"
                    errorcode=35
                    returncode=1
                fi
            fi

            $RMCFG_CMD "$1" -f "$QPKG_CONFIG_PATHFILE"
        else
            DebugQPKG "'$1'" "not installed [$result]"
        fi
    fi

    return $returncode

    }

DaemonCtl()
    {

    # $1 = action (start|stop)
    # $2 = pathfile of daemon init script

    local msgs=''
    local result=0
    local target_init_pathfile=''
    local init_file=''
    local returncode=0

    if [[ -z $2 ]]; then
        DebugError 'daemon unspecified'
        errorcode=36
        returncode=1
    elif [[ ! -e $2 ]]; then
        DebugError "daemon ($2) not found"
        errorcode=37
        returncode=1
    else
        target_init_pathfile="$2"
        target_init_file=$($BASENAME_CMD "$target_init_pathfile")

        case $1 in
            start)
                ShowProc "starting daemon ($target_init_file) - this can take a while"
                msgs=$("$target_init_pathfile" start)
                result=$?
                echo -e "${msgs}\nresult=[$result]" >> "$qpkg_pathfile.$START_LOG_FILE"

                if [[ $result -eq 0 ]]; then
                    ShowDone "daemon started ($target_init_file)"
                else
                    ShowWarning "could not start daemon ($target_init_file) [$result]"
                    if [[ $debug = true ]]; then
                        DebugInfoThickSeparator
                        $CAT_CMD "$qpkg_pathfile.$START_LOG_FILE"
                        DebugInfoThickSeparator
                    else
                        $CAT_CMD "$qpkg_pathfile.$START_LOG_FILE" >> "$DEBUG_LOG_PATHFILE"
                    fi
                    errorcode=38
                    returncode=1
                fi
                ;;
            stop)
                ShowProc "stopping daemon ($target_init_file)"
                msgs=$("$target_init_pathfile" stop)
                result=$?
                echo -e "${msgs}\nresult=[$result]" >> "$qpkg_pathfile.$STOP_LOG_FILE"

                if [[ $result -eq 0 ]]; then
                    ShowDone "daemon stopped ($target_init_file)"
                else
                    ShowWarning "could not stop daemon ($target_init_file) [$result]"
                    if [[ $debug = true ]]; then
                        DebugInfoThickSeparator
                        $CAT_CMD "$qpkg_pathfile.$STOP_LOG_FILE"
                        DebugInfoThickSeparator
                    else
                        $CAT_CMD "$qpkg_pathfile.$STOP_LOG_FILE" >> "$DEBUG_LOG_PATHFILE"
                    fi
                    # meh, continue anyway...
                    returncode=1
                fi
                ;;
            *)
                DebugError "action unrecognised ($1)"
                errorcode=39
                returncode=1
                ;;
        esac
    fi

    return $returncode

    }

CTRL_C_Captured()
    {

    [[ -e $monitor_flag ]] && rm "$monitor_flag"

    $SLEEP_CMD 1

    exit

    }

Cleanup()
    {

    DebugFuncEntry

    cd "$SHARE_PUBLIC_PATH"

    [[ $errorcode -eq 0 && $debug != true && -d $WORKING_PATH ]] && rm -rf "$WORKING_PATH"

    if [[ $queue_paused = true ]]; then
        if IsQPKGInstalled SABnzbdplus; then
            LoadQPKGVars SABnzbdplus
            SabQueueControl resume
        elif IsQPKGInstalled QSabNZBdPlus; then
            LoadQPKGVars QSabNZBdPlus
            SabQueueControl resume
        fi
    fi

    DebugFuncExit
    return 0

    }

DisplayResult()
    {

    DebugFuncEntry

    local RE=''
    local SL=''

    [[ $REINSTALL_FLAG = true ]] && RE='re' || RE=''
    [[ $secure_web_login = true ]] && SL='s' || SL=''

    if [[ $errorcode -eq 0 ]]; then
        [[ $debug = true ]] && emoticon=':DD' || { emoticon=''; echo ;}
        ShowDone "'$TARGET_APP' has been successfully ${RE}installed! $emoticon"
        #ShowInfo "It should now be accessible on your LAN @ $(ColourTextUnderlinedBlue "http${SL}://$($HOSTNAME_CMD -i | $TR_CMD -d ' '):$package_port")"
    elif [[ $errorcode -gt 1 ]]; then       # don't display 'failed' when only showing help
        [[ $debug = true ]] && emoticon=':S ' || { emoticon=''; echo ;}
        ShowError "'$TARGET_APP' ${RE}install failed! ${emoticon}[$errorcode]"
    fi

    DebugScript 'finished' "$($DATE_CMD)"
    DebugScript 'elapsed time' "$(ConvertSecs "$(($($DATE_CMD +%s)-$([[ -n $SCRIPT_STARTSECONDS ]] && echo $SCRIPT_STARTSECONDS || echo "1")))")"
    DebugInfoThickSeparator

    [[ -e $DEBUG_LOG_PATHFILE && $debug = false ]] && echo -e "\n- To display the debug log:\ncat ${DEBUG_LOG_PATHFILE}\n"

    DebugFuncExit
    return 0

    }

FindAllIPKGDependencies()
    {

    # From a specified list of IPKG names, find all dependent IPKGs, exclude those already installed,then generate a total qty to download and a total download byte-size.
    # input:
    #   $1 = string with space-separated initial IPKG names
    # output:
    #   $IPKG_download_list = array with complete list of all IPKGs including those originally specified
    #   $IPKG_download_count = number of packages needing download
    #   $IPKG_download_size = byte-count of all these packages

    IPKG_download_size=0
    IPKG_download_count=0
    IPKG_download_list=()
    local all_required_packages=()
    local original_list=''
    local all_list_sorted=''
    local dependency_list=''
    local last_list=''
    local iterations=0
    local iteration_limit=20
    local complete=false

    [[ -n $1 ]] && original_list="$1" || { DebugError "No IPKGs were requested"; return 1 ;}

    IsSysFilePresent $OPKG_CMD || return

    ShowProc "calculating number and size of IPKGs required"
    DebugInfo "requested IPKG names: $original_list"

    last_list="$original_list"

    DebugProc 'finding all IPKG dependencies'
    while [[ $iterations -lt $iteration_limit ]]; do
        ((iterations++))
        last_list="$($OPKG_CMD depends -A $last_list | $GREP_CMD -v 'depends on:' | $SED_CMD 's|^[[:blank:]]*||;s|[[:blank:]]*$||' | $TR_CMD ' ' '\n' | $SORT_CMD | $UNIQ_CMD)"

        if [[ -n $last_list ]]; then
            [[ -n $dependency_list ]] && dependency_list+="$(echo -e "\n$last_list")" || dependency_list="$last_list"
        else
            DebugDone 'complete'
            DebugInfo "found all IPKG dependencies in $iterations iterations"
            complete=true
            break
        fi
    done

    [[ $complete = false ]] && DebugError "IPKG dependency list incomplete! Consider raising \$iteration_limit [$iteration_limit]."

    all_list_sorted="$(echo "$original_list $dependency_list" | $TR_CMD ' ' '\n' | $SORT_CMD | $UNIQ_CMD)"
    read -r -a all_required_packages_array <<< $all_list_sorted
    all_required_packages=($(printf '%s\n' "${all_required_packages_array[@]}"))

    DebugProc 'excluding packages already installed'
    for element in ${all_required_packages[@]}; do
        $OPKG_CMD status "$element" | $GREP_CMD -q "Status:.*installed" || IPKG_download_list+=($element)
    done
    DebugDone 'complete'
    DebugInfo "required IPKG names: ${IPKG_download_list[*]}"
    IPKG_download_count=${#IPKG_download_list[@]}

    if [[ $IPKG_download_count -gt 0 ]]; then
        DebugProc 'calculating size of required IPKGs'
        for element in ${IPKG_download_list[@]}; do
            result_size=$($OPKG_CMD info $element | $GREP_CMD -F 'Size:' | $SED_CMD 's|^Size: ||')
            ((IPKG_download_size+=result_size))
        done
        DebugDone 'complete'
    fi

    [[ -z $IPKG_download_size ]] && IPKG_download_size=0

    DebugVar IPKG_download_size
    if [[ $IPKG_download_count -gt 0 ]]; then
        ShowDone "$IPKG_download_count IPKGs ($(Convert2ISO $IPKG_download_size)) are required"
    else
        ShowDone "no IPKGs are required"
    fi

    }

_MonitorDirSize_()
    {

    # * This function runs autonomously *
    # It watches for the existence of the pathfile set in $monitor_flag
    # If this file is removed, this function dies gracefully.

    # $1 = directory to monitor the size of.
    # $2 = total target bytes for $1 directory.

    [[ -z $1 || ! -d $1 ]] && return 1
    [[ -z $2 || $2 -eq 0 ]] && return 1

    local target_dir="$1"
    local total_bytes=$2
    local last_bytes=0
    local stall_seconds=0
    local stall_seconds_threshold=4
    local current_bytes=0
    local percent=''

    IsSysFilePresent $FIND_CMD || return

    InitProgress

    while [[ -e $monitor_flag ]]; do
        current_bytes=$($FIND_CMD $target_dir -type f -name '*.ipk' -exec $DU_CMD --bytes --total --apparent-size {} + 2> /dev/null | $GREP_CMD total$ | $CUT_CMD -f1)
        [[ -z $current_bytes ]] && current_bytes=0

        if [[ $current_bytes -ne $last_bytes ]]; then
            stall_seconds=0
            last_bytes=$current_bytes
        else
            ((stall_seconds++))
        fi

        percent="$((200*($current_bytes)/($total_bytes) % 2 + 100*($current_bytes)/($total_bytes)))%"
        progress_message=" $percent ($(Convert2ISO $current_bytes)/$(Convert2ISO $total_bytes))"

        if [[ $stall_seconds -ge $stall_seconds_threshold ]]; then
            if [[ $stall_seconds -lt 60 ]]; then
                progress_message+=" stalled for $stall_seconds seconds"
            else
                progress_message+=" stalled for $(ConvertSecs $stall_seconds)"
            fi
        fi

        ProgressUpdater "$progress_message"
        $SLEEP_CMD 1
    done

    [[ -n $progress_message ]] && ProgressUpdater " done!"

    }

SabQueueControl()
    {

    # $1 = 'pause' or 'resume'

    local returncode=0

    if [[ -z $1 ]]; then
        returncode=1
    elif [[ $1 != pause && $1 != resume ]]; then
        returncode=1
    else
        [[ $secure_web_login = true ]] && SL='s' || SL=''
        $WGET_CMD --no-check-certificate --quiet "http${SL}://127.0.0.1:${package_port}/sabnzbd/api?mode=${1}&apikey=${package_api}" -O - 2>&1 >/dev/null &
        [[ $1 = pause ]] && queue_paused=true || queue_paused=false
        DebugDone "${1}d existing SABnzbd queue"
    fi

    return $returncode

    }

EnableQPKG()
    {

    # $1 = package name to enable

    [[ -z $1 ]] && return 1

    if [[ $($GETCFG_CMD "$1" Enable -u -f "$QPKG_CONFIG_PATHFILE") != 'TRUE' ]]; then
        DebugProc "enabling QPKG [$1]"
        $SETCFG_CMD "$1" Enable TRUE -f "$QPKG_CONFIG_PATHFILE"
        DebugDone "QPKG [$1] enabled"
    fi

    }

IsQPKGInstalled()
    {

    # input:
    #   $1 = package name to check
    # output:
    #   $package_is_installed = true / false

    package_is_installed=false

    [[ -z $1 ]] && return 1
    [[ $($GETCFG_CMD "$1" RC_Number -d 0 -f "$QPKG_CONFIG_PATHFILE") -eq 0 ]] && return 1

    package_is_installed=true

    }

IsQPKGEnabled()
    {

    # $1 = package name to check

    [[ -z $1 ]] && return 1
    [[ $($GETCFG_CMD "$1" Enable -u -f "$QPKG_CONFIG_PATHFILE") = 'TRUE' ]]

    }

IsIPKGInstalled()
    {

    # $1 = package name to check

    [[ -z $1 ]] && return 1

    if ! ($OPKG_CMD list-installed | $GREP_CMD -q -F "$1"); then
        DebugIPKG "'$1'" 'not installed'
        return 1
    else
        DebugIPKG "'$1'" 'installed'
        return 0
    fi

    }

IsSysFilePresent()
    {

    # $1 = pathfile to check

    [[ -z $1 ]] && return 1

    if ! [[ -f $1 || -L $1 ]]; then
        ShowError "A required NAS system file is missing [$1]"
        errorcode=40
        return 1
    else
        return 0
    fi

    }

IsSysSharePresent()
    {

    # $1 = symlink path to check

    [[ -z $1 ]] && return 1

    if [[ ! -L $1 ]]; then
        ShowError "A required NAS system share is missing [$1]. Please re-create it via QNAP Control Panel -> Privilege Settings -> Shared Folders."
        errorcode=41
        return 1
    else
        return 0
    fi

    }

InitProgress()
    {

    # needs to be called prior to first call of ProgressUpdater

    progress_message=''
    previous_length=0
    previous_msg=''

    }

ProgressUpdater()
    {

    # $1 = message to display

    if [[ $1 != $previous_msg ]]; then
        temp="$1"
        current_length=$((${#temp}+1))

        if [[ $current_length -lt $previous_length ]]; then
            appended_length=$(($current_length-$previous_length))
            # backspace to start of previous msg, print new msg, add additional spaces, then backspace to end of msg
            printf "%${previous_length}s" | $TR_CMD ' ' '\b' ; echo -n "$1 " ; printf "%${appended_length}s" ; printf "%${appended_length}s" | $TR_CMD ' ' '\b'
        else
            # backspace to start of previous msg, print new msg
            printf "%${previous_length}s" | $TR_CMD ' ' '\b' ; echo -n "$1 "
        fi

        previous_length=$current_length
        previous_msg="$1"
    fi

    }

ConvertSecs()
    {

    # http://stackoverflow.com/questions/12199631/convert-seconds-to-hours-minutes-seconds
    # $1 = a time in seconds to convert to 'hh:mm:ss'

    ((h=${1}/3600))
    ((m=(${1}%3600)/60))
    ((s=${1}%60))

    printf "%02dh:%02dm:%02ds\n" $h $m $s

    }

Convert2ISO()
    {

    echo $1 | $AWK_CMD 'BEGIN{ u[0]="B"; u[1]="kB"; u[2]="MB"; u[3]="GB"} { n = $1; i = 0; while(n > 1000) { i+=1; n= int((n/1000)+0.5) } print n u[i] } '

    }

DebugInfoThickSeparator()
    {

    DebugInfo "$(printf '%0.s=' {1..70})"

    }

DebugInfoThinSeparator()
    {

    DebugInfo "$(printf '%0.s-' {1..70})"

    }

DebugErrorThinSeparator()
    {

    DebugError "$(printf '%0.s-' {1..70})"

    }

DebugLogThinSeparator()
    {

    DebugLog "$(printf '%0.s-' {1..70})"

    }

DebugScript()
    {

    DebugDetected 'SCRIPT' "$1" "$2"

    }

DebugStage()
    {

    DebugDetected 'STAGE' "$1" "$2"

    }

DebugNAS()
    {

    DebugDetected 'NAS' "$1" "$2"

    }

DebugQPKG()
    {

    DebugDetected 'QPKG' "$1" "$2"

    }

DebugIPKG()
    {

    DebugDetected 'IPKG' "$1" "$2"

    }

DebugFuncEntry()
    {

    DebugThis "(>>) <${FUNCNAME[1]}>"

    }

DebugFuncExit()
    {

    DebugThis "(<<) <${FUNCNAME[1]}> [$errorcode]"

    }

DebugProc()
    {

    DebugThis "(==) $1 ..."

    }

DebugDone()
    {

    DebugThis "(--) $1"

    }

DebugDetected()
    {

    DebugThis "(**) $(printf "%-7s %17s %-s\n" "$1:" "$2:" "$3")"

    }

DebugInfo()
    {

    DebugThis "(II) $1"

    }

DebugWarning()
    {

    DebugThis "(WW) $1"

    }

DebugError()
    {

    DebugThis "(EE) $1"

    }

DebugLog()
    {

    DebugThis "(LL) $1"

    }

DebugVar()
    {

    DebugThis "(vv) $1 [${!1}]"

    }

DebugThis()
    {

    [[ $debug = true ]] && ShowDebug "$1"
    SaveDebug "$1"

    }

DebugErrorFile()
    {

    # add the contents of specified pathfile $1 to the main runtime log

    [[ -z $1 || ! -e $1 ]] && return 1
    local linebuff=''

    DebugLogThinSeparator
    DebugLog "[$1]"
    DebugLogThinSeparator

    while read linebuff; do
        DebugLog "$linebuff"
    done < "$1"

    DebugLogThinSeparator

    }

ShowInfo()
    {

    ShowLogLine_write "$(ColourTextBrightWhite info)" "$1"
    SaveLogLine info "$1"

    }

ShowProc()
    {

    ShowLogLine_write "$(ColourTextBrightOrange proc)" "$1 ..."
    SaveLogLine proc "$1 ..."

    }

ShowDebug()
    {

    ShowLogLine_write "$(ColourTextBlackOnCyan dbug)" "$1"

    }

ShowDone()
    {

    ShowLogLine_update "$(ColourTextBrightGreen done)" "$1"
    SaveLogLine done "$1"

    }

ShowWarning()
    {

    ShowLogLine_update "$(ColourTextBrightOrange warn)" "$1"
    SaveLogLine warn "$1"

    }

ShowError()
    {

    ShowLogLine_update "$(ColourTextBrightRed fail)" "$1"
    SaveLogLine fail "$1"

    }

SaveDebug()
    {

    SaveLogLine dbug "$1"

    }

ShowLogLine_write()
    {

    # writes a new message without newline (unless in debug mode)

    # $1 = pass/fail
    # $2 = message

    previous_msg=$(printf "[ %-10s ] %s" "$1" "$2")

    echo -n "$previous_msg"; [[ $debug = true ]] && echo

    return 0

    }

ShowLogLine_update()
    {

    # updates the previous message

    # $1 = pass/fail
    # $2 = message

    new_message=$(printf "[ %-10s ] %s" "$1" "$2")

    if [[ $new_message != $previous_msg ]]; then
        previous_length=$((${#previous_msg}+1))
        new_length=$((${#new_message}+1))

        # jump to start of line, print new msg
        strbuffer=$(echo -en "\r$new_message ")

        # if new msg is shorter then add spaces to end to cover previous msg
        [[ $new_length -lt $previous_length ]] && { appended_length=$(($new_length-$previous_length)); strbuffer+=$(printf "%${appended_length}s") ;}

        echo "$strbuffer"
    fi

    return 0

    }

SaveLogLine()
    {

    # $1 = pass/fail
    # $2 = message

    [[ -n $DEBUG_LOG_PATHFILE ]] && $TOUCH_CMD "$DEBUG_LOG_PATHFILE" && printf "[ %-4s ] %s\n" "$1" "$2" >> "$DEBUG_LOG_PATHFILE"

    }

ColourTextBrightGreen()
    {

    echo -en '\E[1;32m'"$(PrintResetColours "$1")"

    }

ColourTextBrightOrange()
    {

    echo -en '\E[1;38;5;214m'"$(PrintResetColours "$1")"

    }

ColourTextBrightRed()
    {

    echo -en '\E[1;31m'"$(PrintResetColours "$1")"

    }

ColourTextUnderlinedBlue()
    {

    echo -en '\E[4;94m'"$(PrintResetColours "$1")"

    }

ColourTextBlackOnCyan()
    {

    echo -en '\E[30;46m'"$(PrintResetColours "$1")"

    }

ColourTextBrightWhite()
    {

    echo -en '\E[1;97m'"$(PrintResetColours "$1")"

    }

PrintResetColours()
    {

    echo -en "$1"'\E[0m'

    }

PauseHere()
    {

    # wait here temporarily

    local wait_seconds=10

    ShowProc "waiting for $wait_seconds seconds"
    $SLEEP_CMD $wait_seconds
    ShowDone "wait complete"

    }

Init
PauseDownloaders
RemoveOther
DownloadQPKGs
InstallEntware
InstallExtras
InstallTargetApp
Cleanup
DisplayResult

exit $errorcode
