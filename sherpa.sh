#!/usr/bin/env bash
#
# sherpa.sh
#
# A package manager to install various Usenet media-management apps into QNAP NAS
#
# Copyright (C) 2017-2020 OneCD [one.cd.only@gmail.com]
#
# so, blame OneCD if it all goes horribly wrong. ;)
#
# For more info: https://forum.qnap.com/viewtopic.php?f=320&t=132373
#
# Tested on:
#  GNU bash, version 3.2.57(2)-release (i686-pc-linux-gnu)
#  Copyright (C) 2007 Free Software Foundation, Inc.
#
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.
#
# *** Style Guide ***
# functions: CamelCase
# variables: lowercase_with_underscores (except for 'returncode' & 'errorcode')
# constants: UPPERCASE_WITH_UNDERSCORES (also set to readonly)
#   indents: 1 x tab (converted to 4 x spaces to suit GitHub web-display)

readonly USER_ARGS_RAW="$@"

ResetErrorcode()
    {

    errorcode=0

    }

Init()
    {

    DisableDebugMode
    ResetErrorcode

    readonly SCRIPT_FILE=sherpa.sh
    readonly SCRIPT_VERSION=200622

    # cherry-pick required binaries
    readonly AWK_CMD=/bin/awk
    readonly CAT_CMD=/bin/cat
    readonly CHMOD_CMD=/bin/chmod
    readonly DATE_CMD=/bin/date
    readonly GREP_CMD=/bin/grep
    readonly HOSTNAME_CMD=/bin/hostname
    readonly LN_CMD=/bin/ln
    readonly MD5SUM_CMD=/bin/md5sum
    readonly MKDIR_CMD=/bin/mkdir
    readonly PING_CMD=/bin/ping
    readonly SED_CMD=/bin/sed
    readonly SLEEP_CMD=/bin/sleep
    readonly TOUCH_CMD=/bin/touch
    readonly TR_CMD=/bin/tr
    readonly UNAME_CMD=/bin/uname
    readonly UNIQ_CMD=/bin/uniq

    readonly CURL_CMD=/sbin/curl
    readonly GETCFG_CMD=/sbin/getcfg
    readonly RMCFG_CMD=/sbin/rmcfg
    readonly SERVICE_CMD=/sbin/qpkg_service
    readonly SETCFG_CMD=/sbin/setcfg

    readonly BASENAME_CMD=/usr/bin/basename
    readonly CUT_CMD=/usr/bin/cut
    readonly DIRNAME_CMD=/usr/bin/dirname
    readonly DU_CMD=/usr/bin/du
    readonly HEAD_CMD=/usr/bin/head
    readonly READLINK_CMD=/usr/bin/readlink
    readonly SORT_CMD=/usr/bin/sort
    readonly TAIL_CMD=/usr/bin/tail
    readonly TEE_CMD=/usr/bin/tee
    readonly UNZIP_CMD=/usr/bin/unzip
    readonly UPTIME_CMD=/usr/bin/uptime
    readonly WC_CMD=/usr/bin/wc

    readonly ZIP_CMD=/usr/local/sbin/zip

    readonly FIND_CMD=/opt/bin/find
    readonly OPKG_CMD=/opt/bin/opkg
    pip2_cmd=/opt/bin/pip2
    pip3_cmd=/opt/bin/pip3

    # paths and files
    readonly APP_CENTER_CONFIG_PATHFILE=/etc/config/qpkg.conf
    readonly INSTALL_LOG_FILE=install.log
    readonly DOWNLOAD_LOG_FILE=download.log
    readonly START_LOG_FILE=start.log
    readonly STOP_LOG_FILE=stop.log
    readonly RESTART_LOG_FILE=restart.log
    readonly DEFAULT_SHARES_PATHFILE=/etc/config/def_share.info
    readonly ULINUX_PATHFILE=/etc/config/uLinux.conf
    readonly PLATFORM_PATHFILE=/etc/platform.conf
    local -r DEBUG_LOG_FILE=${SCRIPT_FILE%.*}.debug.log

    # check required binaries are present
    IsNotSysFilePresent $AWK_CMD && return 1
    IsNotSysFilePresent $CAT_CMD && return 1
    IsNotSysFilePresent $CHMOD_CMD && return 1
    IsNotSysFilePresent $DATE_CMD && return 1
    IsNotSysFilePresent $GREP_CMD && return 1
    IsNotSysFilePresent $HOSTNAME_CMD && return 1
    IsNotSysFilePresent $LN_CMD && return 1
    IsNotSysFilePresent $MD5SUM_CMD && return 1
    IsNotSysFilePresent $MKDIR_CMD && return 1
    IsNotSysFilePresent $PING_CMD && return 1
    IsNotSysFilePresent $SED_CMD && return 1
    IsNotSysFilePresent $SLEEP_CMD && return 1
    IsNotSysFilePresent $TOUCH_CMD && return 1
    IsNotSysFilePresent $TR_CMD && return 1
    IsNotSysFilePresent $UNAME_CMD && return 1
    IsNotSysFilePresent $UNIQ_CMD && return 1

    IsNotSysFilePresent $CURL_CMD && return 1
    IsNotSysFilePresent $GETCFG_CMD && return 1
    IsNotSysFilePresent $RMCFG_CMD && return 1
    IsNotSysFilePresent $SERVICE_CMD && return 1
    IsNotSysFilePresent $SETCFG_CMD && return 1

    IsNotSysFilePresent $BASENAME_CMD && return 1
    IsNotSysFilePresent $CUT_CMD && return 1
    IsNotSysFilePresent $DIRNAME_CMD && return 1
    IsNotSysFilePresent $DU_CMD && return 1
    IsNotSysFilePresent $HEAD_CMD && return 1
    IsNotSysFilePresent $READLINK_CMD && return 1
    IsNotSysFilePresent $SORT_CMD && return 1
    IsNotSysFilePresent $TAIL_CMD && return 1
    IsNotSysFilePresent $TEE_CMD && return 1
    IsNotSysFilePresent $UNZIP_CMD && return 1
    IsNotSysFilePresent $UPTIME_CMD && return 1
    IsNotSysFilePresent $WC_CMD && return 1

    IsNotSysFilePresent $ZIP_CMD && return 1

    local -r DEFAULT_SHARE_DOWNLOAD_PATH=/share/Download
    local -r DEFAULT_SHARE_PUBLIC_PATH=/share/Public

    # check required system paths are present
    if [[ -L $DEFAULT_SHARE_DOWNLOAD_PATH ]]; then
        readonly SHARE_DOWNLOAD_PATH=$DEFAULT_SHARE_DOWNLOAD_PATH
    else
        readonly SHARE_DOWNLOAD_PATH=/share/$($GETCFG_CMD SHARE_DEF defDownload -d Qdownload -f $DEFAULT_SHARES_PATHFILE)
        IsNotSysSharePresent $SHARE_DOWNLOAD_PATH && return 1
    fi

    if [[ -L $DEFAULT_SHARE_PUBLIC_PATH ]]; then
        readonly SHARE_PUBLIC_PATH=$DEFAULT_SHARE_PUBLIC_PATH
    else
        readonly SHARE_PUBLIC_PATH=/share/$($GETCFG_CMD SHARE_DEF defPublic -d Qpublic -f $DEFAULT_SHARES_PATHFILE)
        IsNotSysSharePresent $SHARE_PUBLIC_PATH && return 1
    fi

    # sherpa-supported package details - parallel arrays
    SHERPA_QPKG_NAME=()         # internal QPKG name
        SHERPA_QPKG_ARCH=()     # QPKG supports this architecture
        SHERPA_QPKG_URL=()      # remote QPKG URL
        SHERPA_QPKG_MD5=()      # remote QPKG MD5
        SHERPA_QPKG_ABBRVS=()   # if set, this package is user-installable, and these abbreviations may be used to specify app
        SHERPA_QPKG_DEPS=()     # require these QPKGs to be installed first
        SHERPA_QPKG_IPKGS=()    # require these IPKGs to be installed first
        SHERPA_QPKG_PIP2S=()    # require these PIPs for Python 2 to be installed first
        SHERPA_QPKG_PIP3S=()    # require these PIPs for Python 3 to be installed first

    SHERPA_QPKG_NAME+=(Entware)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/sherpa/master/QPKGs/Entware/Entware_1.02std.qpkg)
        SHERPA_QPKG_MD5+=(dbc82469933ac3049c06d4c8a023bbb9)
        SHERPA_QPKG_ABBRVS+=('opkg ew ent entware')
        SHERPA_QPKG_DEPS+=('')
        SHERPA_QPKG_IPKGS+=('')
        SHERPA_QPKG_PIP2S+=('')
        SHERPA_QPKG_PIP3S+=('')

#     SHERPA_QPKG_NAME+=(SABnzbdplus)
#         SHERPA_QPKG_ARCH+=(all)
#         SHERPA_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/sherpa/master/QPKGs/SABnzbdplus/build/SABnzbdplus_200617.qpkg)
#         SHERPA_QPKG_MD5+=(8502b642483479dcf6ea6b7c1dc9dae7)
#         SHERPA_QPKG_ABBRVS+=('sb sab sabnzbd sabnzbdplus')
#         SHERPA_QPKG_DEPS+=('Entware Par2')
#         SHERPA_QPKG_IPKGS+=('python python-pip python-pyopenssl python-dev gcc unrar p7zip coreutils-nice ionice ffprobe')
#         SHERPA_QPKG_PIP2S+=('sabyenc==3.3.5 cheetah')
#         SHERPA_QPKG_PIP3S+=('')

    SHERPA_QPKG_NAME+=(SABnzbd)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/sherpa/master/QPKGs/SABnzbd/build/SABnzbd_200617.qpkg)
        SHERPA_QPKG_MD5+=(dea242426d2a4c7f27435a191f7ed592)
        SHERPA_QPKG_ABBRVS+=('sb3 sab3 sabnzbd3')
        SHERPA_QPKG_DEPS+=('Entware Par2')
        SHERPA_QPKG_IPKGS+=('python3 python3-pip python3-pyopenssl python3-cryptography python3-dev gcc unrar p7zip coreutils-nice ionice ffprobe')
        SHERPA_QPKG_PIP2S+=('')
        SHERPA_QPKG_PIP3S+=('sabyenc3 cheetah3 feedparser configobj cherrypy chardet')

    SHERPA_QPKG_NAME+=(NZBGet)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/sherpa/master/QPKGs/NZBGet/build/NZBGet_200607.qpkg)
        SHERPA_QPKG_MD5+=(5648326777a6d7c4f90ef74fc4f7a8f6)
        SHERPA_QPKG_ABBRVS+=('ng nget nzb nzbget')
        SHERPA_QPKG_DEPS+=('Entware')
        SHERPA_QPKG_IPKGS+=('nzbget')
        SHERPA_QPKG_PIP2S+=('')
        SHERPA_QPKG_PIP3S+=('')

#     SHERPA_QPKG_NAME+=(SickChill)
#         SHERPA_QPKG_ARCH+=(all)
#         SHERPA_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/sherpa/master/QPKGs/SickChill/build/SickChill_200607.qpkg)
#         SHERPA_QPKG_MD5+=(8bd1bb89818ecb190a1f8805a9e6e961)
#         SHERPA_QPKG_ABBRVS+=('sc sick sickc chill sickchill')
#         SHERPA_QPKG_DEPS+=('Entware')
#         SHERPA_QPKG_IPKGS+=('python python-pip')
#         SHERPA_QPKG_PIP2S+=('')
#         SHERPA_QPKG_PIP3S+=('')

    SHERPA_QPKG_NAME+=(LazyLibrarian)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/sherpa/master/QPKGs/LazyLibrarian/build/LazyLibrarian_200621.qpkg)
        SHERPA_QPKG_MD5+=(798546bbfff3d6540423c11d1df0b8ec)
        SHERPA_QPKG_ABBRVS+=('ll lazy lazylibrarian')
        SHERPA_QPKG_DEPS+=('Entware')
        SHERPA_QPKG_IPKGS+=('python3-pip python3-pyopenssl python3-requests')
        SHERPA_QPKG_PIP2S+=('')
        SHERPA_QPKG_PIP3S+=('python-magic')

    SHERPA_QPKG_NAME+=(OMedusa)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/sherpa/master/QPKGs/OMedusa/build/OMedusa_200607.qpkg)
        SHERPA_QPKG_MD5+=(1990ee7712134a408f247e176ee83930)
        SHERPA_QPKG_ABBRVS+=('om med omed medusa omedusa')
        SHERPA_QPKG_DEPS+=('Entware')
        SHERPA_QPKG_IPKGS+=('python3 python3-pip mediainfo')
        SHERPA_QPKG_PIP2S+=('')
        SHERPA_QPKG_PIP3S+=('')

    SHERPA_QPKG_NAME+=(OWatcher3)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/sherpa/master/QPKGs/OWatcher3/build/OWatcher3_200607.qpkg)
        SHERPA_QPKG_MD5+=(900843cc3b7b63bcf51c318e52f4e34e)
        SHERPA_QPKG_ABBRVS+=('ow wat owat watch watcher owatcher watcher3 owatcher3')
        SHERPA_QPKG_DEPS+=('Entware')
        SHERPA_QPKG_IPKGS+=('python3 python3-pip jq')
        SHERPA_QPKG_PIP2S+=('')
        SHERPA_QPKG_PIP3S+=('')

#     SHERPA_QPKG_NAME+=(Headphones)
#         SHERPA_QPKG_ARCH+=(all)
#         SHERPA_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/sherpa/master/QPKGs/Headphones/build/Headphones_200607.qpkg)
#         SHERPA_QPKG_MD5+=(417af5c74d8a592248b0bbbee86230f0)
#         SHERPA_QPKG_ABBRVS+=('hp head phones headphones')
#         SHERPA_QPKG_DEPS+=('Entware')
#         SHERPA_QPKG_IPKGS+=('python python-pip')
#         SHERPA_QPKG_PIP2S+=('')
#         SHERPA_QPKG_PIP3S+=('')

    SHERPA_QPKG_NAME+=(Par2)
        SHERPA_QPKG_ARCH+=(x86)
        SHERPA_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/sherpa/master/QPKGs/Par2/Par2_0.8.1.0_x86.qpkg)
        SHERPA_QPKG_MD5+=(996ffb92d774eb01968003debc171e91)
        SHERPA_QPKG_ABBRVS+=('')
        SHERPA_QPKG_DEPS+=('')
        SHERPA_QPKG_IPKGS+=('')
        SHERPA_QPKG_PIP2S+=('')
        SHERPA_QPKG_PIP3S+=('')

    SHERPA_QPKG_NAME+=(Par2)
        SHERPA_QPKG_ARCH+=(x64)
        SHERPA_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/sherpa/master/QPKGs/Par2/Par2_0.8.1.0_x86_64.qpkg)
        SHERPA_QPKG_MD5+=(520472cc87d301704f975f6eb9948e38)
        SHERPA_QPKG_ABBRVS+=('')
        SHERPA_QPKG_DEPS+=('')
        SHERPA_QPKG_IPKGS+=('')
        SHERPA_QPKG_PIP2S+=('')
        SHERPA_QPKG_PIP3S+=('')

    SHERPA_QPKG_NAME+=(Par2)
        SHERPA_QPKG_ARCH+=(x31)
        SHERPA_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/sherpa/master/QPKGs/Par2/Par2_0.8.1.0_arm-x31.qpkg)
        SHERPA_QPKG_MD5+=(ce8af2e009eb87733c3b855e41a94f8e)
        SHERPA_QPKG_ABBRVS+=('')
        SHERPA_QPKG_DEPS+=('')
        SHERPA_QPKG_IPKGS+=('')
        SHERPA_QPKG_PIP2S+=('')
        SHERPA_QPKG_PIP3S+=('')

    SHERPA_QPKG_NAME+=(Par2)
        SHERPA_QPKG_ARCH+=(x41)
        SHERPA_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/sherpa/master/QPKGs/Par2/Par2_0.8.1.0_arm-x41.qpkg)
        SHERPA_QPKG_MD5+=(8516e45e704875cdd2cd2bb315c4e1e6)
        SHERPA_QPKG_ABBRVS+=('')
        SHERPA_QPKG_DEPS+=('')
        SHERPA_QPKG_IPKGS+=('')
        SHERPA_QPKG_PIP2S+=('')
        SHERPA_QPKG_PIP3S+=('')

    SHERPA_QPKG_NAME+=(Par2)
        SHERPA_QPKG_ARCH+=(a64)
        SHERPA_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/sherpa/master/QPKGs/Par2/Par2_0.8.1.0_arm_64.qpkg)
        SHERPA_QPKG_MD5+=(4d8e99f97936a163e411aa8765595f7a)
        SHERPA_QPKG_ABBRVS+=('')
        SHERPA_QPKG_DEPS+=('')
        SHERPA_QPKG_IPKGS+=('')
        SHERPA_QPKG_PIP2S+=('')
        SHERPA_QPKG_PIP3S+=('')

    # package arrays are now full, so lock them
    readonly SHERPA_QPKG_NAME
        readonly SHERPA_QPKG_ARCH
        readonly SHERPA_QPKG_URL
        readonly SHERPA_QPKG_MD5
        readonly SHERPA_QPKG_ABBRVS
        readonly SHERPA_QPKG_DEPS
        readonly SHERPA_QPKG_IPKGS
        readonly SHERPA_QPKG_PIP2S
        readonly SHERPA_QPKG_PIP3S

    readonly SHERPA_COMMON_IPKGS='git git-http nano less ca-certificates'
    readonly SHERPA_COMMON_PIP2S='setuptools'
    readonly SHERPA_COMMON_PIP3S='setuptools'
    readonly SHERPA_COMMON_CONFLICTS='Optware Optware-NG'

    # user-specified as arguments at runtime
    QPKGS_to_install=()
    QPKGS_to_uninstall=()
    QPKGS_to_reinstall=()
    QPKGS_to_update=()
    QPKGS_to_backup=()
    QPKGS_to_restore=()

    readonly PREV_QPKG_CONFIG_DIRS=(SAB_CONFIG CONFIG Config config)                 # last element is used as target dirname
    readonly PREV_QPKG_CONFIG_FILES=(sabnzbd.ini settings.ini config.cfg config.ini) # last element is used as target filename
    readonly WORKING_PATH=$SHARE_PUBLIC_PATH/${SCRIPT_FILE%.*}.tmp
    readonly DEBUG_LOG_PATHFILE=$SHARE_PUBLIC_PATH/$DEBUG_LOG_FILE
    readonly QPKG_DL_PATH=$WORKING_PATH/qpkg-downloads
    readonly IPKG_DL_PATH=$WORKING_PATH/ipkg-downloads
    readonly IPKG_CACHE_PATH=$WORKING_PATH/ipkg-cache

    # internals
    readonly SCRIPT_STARTSECONDS=$($DATE_CMD +%s)
    readonly NAS_FIRMWARE=$($GETCFG_CMD System Version -f $ULINUX_PATHFILE)
    readonly MIN_RAM_KB=1048576
    readonly INSTALLED_RAM_KB=$($GREP_CMD MemTotal /proc/meminfo | $CUT_CMD -f2 -d':' | $SED_CMD 's|kB||;s| ||g')
    reinstall_flag=false
    DisableSatisfyDependenciesOnly
    DisableHelpOnly
    DisableVersionOnly
    DisableSuggestIssue
    ignore_space_arg=''
    update_all_apps=false
    backup_all_apps=false
    restore_all_apps=false
    [[ ${NAS_FIRMWARE//.} -lt 426 ]] && curl_insecure_arg='--insecure' || curl_insecure_arg=''

    return 0

    }

LogRuntimeParameters()
    {

    ParseArgs

    if IsVersionOnly; then
        ShowVersion
        return 1
    fi

    DebugFuncEntry
    local conflicting_qpkg=''

    DebugInfoThickSeparator
    DebugScript 'started' "$($DATE_CMD | $TR_CMD -s ' ')"

    IsDebugMode || echo -e "$(ColourTextBrightWhite "$SCRIPT_FILE") ($SCRIPT_VERSION)\n"

    DebugScript 'version' "$SCRIPT_VERSION"
    DebugInfoThinSeparator
    DebugInfo 'Markers: (**) detected, (II) information, (WW) warning, (LL) log file,'
    DebugInfo ' (EE) error, (==) processing, (--) done, (>>) f entry, (<<) f exit,'
    DebugInfo ' (vv) variable name & value, ($1) positional argument value.'
    DebugInfoThinSeparator
    DebugNAS 'model' "$($GREP_CMD -v "^$" /etc/issue | $SED_CMD 's|^Welcome to ||;s|(.*||')"
    DebugNAS 'RAM' "$INSTALLED_RAM_KB kB"
    if IsQPKGToBeInstalled SABnzbd || IsQPKGToBeInstalled SABnzbdplus || IsQPKGInstalled SABnzbd || IsQPKGInstalled SABnzbdplus; then
        if [[ $INSTALLED_RAM_KB -le $MIN_RAM_KB ]]; then
            DebugNAS 'RAM' "less-than or equal-to $MIN_RAM_KB kB"
            IsNotError && ShowNote "QTS with 1GB RAM or less can lead to unstable SABnzbd uptimes :("
        fi
    fi
    DebugNAS 'firmware version' "$NAS_FIRMWARE"
    DebugNAS 'firmware build' "$($GETCFG_CMD System 'Build Number' -f $ULINUX_PATHFILE)"
    DebugNAS 'kernel' "$($UNAME_CMD -mr)"
    DebugNAS 'OS uptime' "$($UPTIME_CMD | $SED_CMD 's|.*up.||;s|,.*load.*||;s|^\ *||')"
    DebugNAS 'system load' "$($UPTIME_CMD | $SED_CMD 's|.*load average: ||' | $AWK_CMD -F', ' '{print "1 min="$1 ", 5 min="$2 ", 15 min="$3}')"
    DebugNAS 'USER' "$USER"
    DebugNAS 'EUID' "$EUID"
    DebugNAS 'default volume' "$($GETCFG_CMD SHARE_DEF defVolMP -f $DEFAULT_SHARES_PATHFILE)"
    DebugNAS '$PATH' "${PATH:0:43}"
    DebugNAS '/opt' "$([[ -L '/opt' ]] && $READLINK_CMD '/opt' || echo "<not present>")"
    DebugNAS $SHARE_DOWNLOAD_PATH "$([[ -L $SHARE_DOWNLOAD_PATH ]] && $READLINK_CMD $SHARE_DOWNLOAD_PATH || echo "<not present>")"
    DebugScript 'unparsed arguments' "$USER_ARGS_RAW"
    DebugScript 'app(s) to install' "${QPKGS_to_install[*]}"
    DebugScript 'app(s) to uninstall' "${QPKGS_to_uninstall[*]}"
    DebugScript 'app(s) to reinstall' "${QPKGS_to_reinstall[*]}"
    DebugScript 'app(s) to update' "${QPKGS_to_update[*]}"
    DebugScript 'app(s) to backup' "${QPKGS_to_backup[*]}"
    DebugScript 'app(s) to restore' "${QPKGS_to_restore[*]}"
    DebugScript 'working path' "$WORKING_PATH"
    DebugQPKG 'download path' "$QPKG_DL_PATH"
    DebugIPKG 'download path' "$IPKG_DL_PATH"
    CalcNASQPKGArch
    DebugQPKG 'arch' "$NAS_QPKG_ARCH"

    if IsHelpOnly; then
        ShowHelp
        return 1
    fi

    if IsNotError && [[ $EUID -ne 0 || $USER != admin ]]; then
        ShowError "this script must be run as the 'admin' user. Please login via SSH as 'admin' and try again."
        errorcode=1
    fi

    if IsNotError && [[ ${#QPKGS_to_install[@]} -eq 0 && ${#QPKGS_to_uninstall[@]} -eq 0 && ${#QPKGS_to_update[@]} -eq 0 && ${#QPKGS_to_backup[@]} -eq 0 && ${#QPKGS_to_restore[@]} -eq 0 ]] && ! IsSatisfyDependenciesOnly && [[ $update_all_apps = false ]]; then
        ShowError 'no valid QPKGs or actions were specified'
        errorcode=2
    fi

    if [[ $backup_all_apps = true && $restore_all_apps = true ]]; then
        ShowError 'no point running a backup then a restore operation'
        errorcode=3
    fi

    if IsNotError; then
        $MKDIR_CMD -p "$WORKING_PATH" 2> /dev/null
        result=$?

        if [[ $result -ne 0 ]]; then
            ShowError "unable to create working directory $(FormatAsFileName "$WORKING_PATH") $(FormatAsExitcode $result)"
            errorcode=4
        else
            cd "$WORKING_PATH"
        fi
    fi

    if IsNotError; then
        $MKDIR_CMD -p "$QPKG_DL_PATH" 2> /dev/null
        result=$?

        if [[ $result -ne 0 ]]; then
            ShowError "unable to create QPKG download directory $(FormatAsFileName "$QPKG_DL_PATH") $(FormatAsExitcode $result)"
            errorcode=5
        fi
    fi

    if IsNotError; then
        [[ -d $IPKG_DL_PATH ]] && rm -r "$IPKG_DL_PATH"
        $MKDIR_CMD -p "$IPKG_DL_PATH" 2> /dev/null
        result=$?

        if [[ $result -ne 0 ]]; then
            ShowError "unable to create IPKG download directory $(FormatAsFileName "$IPKG_DL_PATH") $(FormatAsExitcode $result)"
            errorcode=6
        else
            monitor_flag="$IPKG_DL_PATH/.monitor"
        fi
    fi

    if IsNotError; then
        $MKDIR_CMD -p "$IPKG_CACHE_PATH" 2> /dev/null
        result=$?

        if [[ $result -ne 0 ]]; then
            ShowError "unable to create IPKG cache directory $(FormatAsFileName "$IPKG_CACHE_PATH") $(FormatAsExitcode $result)"
            errorcode=7
        fi
    fi

    if IsNotError; then
        for conflicting_qpkg in ${SHERPA_COMMON_CONFLICTS[@]}; do
            if IsQPKGEnabled $conflicting_qpkg; then
                ShowError "'$conflicting_qpkg' is enabled. This is an unsupported configuration."
                errorcode=8
            fi
        done
    fi

    if IsNotError; then
        if IsQPKGInstalled Entware; then
            [[ -e /opt/etc/passwd ]] && { [[ -L /opt/etc/passwd ]] && ENTWARE_VER=std || ENTWARE_VER=alt ;} || ENTWARE_VER=none
            DebugQPKG 'Entware installer' $ENTWARE_VER

            if [[ $ENTWARE_VER = none ]]; then
                ShowError 'Entware appears to be installed but is not visible.'
                errorcode=9
            fi
        fi
    fi

    if IsNotError; then
        if ! ($CURL_CMD $curl_insecure_arg --silent --fail https://onecdonly.github.io/sherpa/LICENSE -o LICENSE); then
            ShowError 'no Internet access'
            errorcode=10
        fi
    fi

    DebugInfoThinSeparator
    DebugFuncExit
    return 0

    }

ParseArgs()
    {

    if [[ -z $USER_ARGS_RAW ]]; then
        EnableHelpOnly
        errorcode=11
        return 1
    fi

    local user_args=($($TR_CMD '[A-Z]' '[a-z]' <<< "$USER_ARGS_RAW"))
    local arg=''
    local current_operation=''
    local target_app=''

    for arg in ${user_args[@]}; do
        case $arg in
            -d|--debug)
                EnableDebugMode
                current_operation=''
                ;;
            --check-all)
                EnableSatisfyDependenciesOnly
                current_operation=''
                ;;
            --ignore-space)
                ignore_space_arg='--force-space'
                DebugVar ignore_space_arg
                current_operation=''
                ;;
            --help)
                EnableHelpOnly
                errorcode=12
                return 1
                ;;
            -v|--version)
                EnableVersionOnly
                errorcode=13
                return 1
                ;;
            --install-all)
                install_all_apps=true
                DebugVar install_all_apps
                current_operation=''
                ;;
            --uninstall-all)
                uninstall_all_apps=true
                DebugVar uninstall_all_apps
                current_operation=''
                ;;
            --reinstall-all)
                reinstall_all_apps=true
                DebugVar reinstall_all_apps
                current_operation=''
                ;;
            --update-all)
                update_all_apps=true
                DebugVar update_all_apps
                current_operation=''
                ;;
            --backup-all)
                backup_all_apps=true
                DebugVar backup_all_apps
                current_operation=''
                ;;
            --restore-all)
                restore_all_apps=true
                DebugVar restore_all_apps
                current_operation=''
                ;;
            --install)
                current_operation=install
                ;;
            --uninstall)
                current_operation=uninstall
                ;;
            --reinstall)
                current_operation=reinstall
                ;;
            --update)
                current_operation=update
                ;;
            --backup)
                current_operation=backup
                ;;
            --restore)
                current_operation=restore
                ;;
            *)
                target_app=$(MatchAbbrvToQPKGName "$arg")
                [[ -z $target_app ]] && continue

                case $current_operation in
                    uninstall)
                        QPKGS_to_uninstall+=($target_app)
                        ;;
                    reinstall)
                        QPKGS_to_reinstall+=($target_app)
                        ;;
                    update)
                        QPKGS_to_update+=($target_app)
                        ;;
                    backup)
                        QPKGS_to_backup+=($target_app)
                        ;;
                    restore)
                        QPKGS_to_restore+=($target_app)
                        ;;
                    install|*)  # default
                        QPKGS_to_install+=($target_app)
                        ;;
                esac
        esac
    done

    # kludge: keep this for compatibility until multi-package rollout is ready
    TARGET_APP=${QPKGS_to_install[0]}

    return 0

    }

ShowHelp()
    {

    DebugFuncEntry
    local package=''

    echo -e "* A package manager to install various Usenet media-management apps into QNAP NAS.\n"

    echo "- Each application shown below can be installed (or reinstalled) by running:"
    for package in ${SHERPA_QPKG_NAME[@]}; do
        (IsQPKGUserInstallable $package) && echo -e "\t$0 $package"
    done

    echo -e "\n- Ensure all sherpa application dependencies are installed:"
    echo -e "\t$0 --check-all"

    echo -e "\n- Don't check free-space on target filesystem when installing Entware packages:"
    echo -e "\t$0 --ignore-space"

    echo -e "\n- Update all sherpa-installed applications:"
    echo -e "\t$0 --update-all"

    DebugFuncExit
    return 0

    }

ShowVersion()
    {

    echo "$SCRIPT_VERSION"

    return 0

    }

DownloadQPKGs()
    {

    IsError && return

    [[ -f $SHARE_PUBLIC_PATH/.sherpa.devmode ]] && EnableDevMode

    DebugFuncEntry
    local QPKGs_to_download=''

    if IsDevMode; then
        [[ ${#QPKGS_to_install[@]} -gt 0 ]] && QPKGs_to_download+="${QPKGS_to_install[*]}"
        [[ ${#QPKGS_to_reinstall[@]} -gt 0 ]] && QPKGs_to_download+=" ${QPKGS_to_reinstall[*]}"

        FindAllQPKGDependencies "$QPKGs_to_download"

        for package in ${QPKG_download_list[@]}; do
            DownloadQPKG $package
        done
    else
        IsNotQPKGInstalled Entware && DownloadQPKG Entware

        (IsQPKGInstalled SABnzbdplus || [[ $TARGET_APP = SABnzbdplus ]];) && [[ $NAS_QPKG_ARCH != none ]] && IsNotQPKGInstalled Par2 && DownloadQPKG Par2

        # kludge: an ugly workaround until QPKG dependency checking works properly
        (IsQPKGInstalled SABnzbd || [[ $TARGET_APP = SABnzbd ]];) && [[ $NAS_QPKG_ARCH != none ]] && IsNotQPKGInstalled Par2 && DownloadQPKG Par2

        [[ -n $TARGET_APP ]] && DownloadQPKG $TARGET_APP
    fi

    DebugFuncExit
    return 0

    }

RemoveUnwantedQPKGs()
    {

    IsError && return

    DebugFuncEntry
    local response=''
    local previous_Entware_package_list=$SHARE_PUBLIC_PATH/Entware.previously.installed.list

    UninstallQPKG Optware || ResetErrorcode  # ignore Optware uninstall errors
    UninstallQPKG Entware-3x
    UninstallQPKG Entware-ng

    IsQPKGInstalled $TARGET_APP && reinstall_flag=true

    if [[ $TARGET_APP = Entware && $reinstall_flag = true ]]; then
        ShowNote 'Reinstalling Entware will revert all IPKGs to defaults and only those required to support your sherpa apps will be reinstalled'
        ShowNote "The currently installed IPKG list will be saved to $(FormatAsFileName $previous_Entware_package_list)"
        ShowWarning "Also, the SABnzbdplus, SickChill and Headphones packages CANNOT BE REINSTALLED as Python 2.7.16 is no-longer available"
        ShowQuiz 'Press (y) if you agree to remove all current Entware IPKGs and their configs, or any other key to abort'
        read -n1 response; echo
        DebugVar response
        case ${response:0:1} in
            y|Y)
                echo -e "# Entware had these IPKGs installed as of: $($DATE_CMD)\n$($OPKG_CMD list-installed)" > $previous_Entware_package_list
                DebugDone "saved current Entware IPKG list to $(FormatAsFileName $previous_Entware_package_list)"
                UninstallQPKG Entware
                ;;
            *)
                DebugInfoThinSeparator
                DebugScript 'user abort'
                DebugInfoThickSeparator
                exit $errorcode
                ;;
        esac
    fi

    DebugFuncExit
    return 0

    }

InstallBase()
    {

    IsError && return

    DebugFuncEntry

    if IsNotQPKGInstalled Entware; then
        # rename original [/opt]
        opt_path=/opt
        opt_backup_path=/opt.orig
        [[ -d $opt_path && ! -L $opt_path && ! -e $opt_backup_path ]] && mv "$opt_path" "$opt_backup_path"

        InstallQPKG Entware && ReloadProfile

        # copy all files from original [/opt] into new [/opt]
        [[ -L $opt_path && -d $opt_backup_path ]] && cp --recursive "$opt_backup_path"/* --target-directory "$opt_path" && rm -r "$opt_backup_path"
    else
        IsNotQPKGEnabled Entware && EnableQPKG Entware
        ReloadProfile

        [[ $NAS_QPKG_ARCH != none ]] && ($OPKG_CMD list-installed | $GREP_CMD -q par2cmdline) && $OPKG_CMD remove par2cmdline > /dev/null 2>&1
    fi

    PatchBaseInit

    DebugFuncExit
    return 0

    }

PatchBaseInit()
    {

    DebugFuncEntry
    local find_text=''
    local insert_text=''
    local package_init_pathfile="$(GetQPKGServiceFile Entware)"

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

    DebugFuncExit
    return 0

    }

UpdateEntware()
    {

    if IsNotSysFilePresent $OPKG_CMD || IsNotSysFilePresent $FIND_CMD; then
        errorcode=14
        return 1
    fi

    DebugFuncEntry
    local package_list_file=/opt/var/opkg-lists/entware
    local package_list_age=60
    local log_pathfile="$WORKING_PATH/entware-update.log"
    local msgs=''
    local result=0

    # if Entware package list was updated only recently, don't run another update
    [[ -e $package_list_file ]] && msgs=$($FIND_CMD "$package_list_file" -mmin +$package_list_age) || msgs='new install'

    if [[ -n $msgs ]]; then
        ShowProc "updating $(FormatAsPackageName Entware) package list"

        RunThisAndLogResults "$OPKG_CMD update" "$log_pathfile"
        result=$?

        if [[ $result -eq 0 ]]; then
            ShowDone "updated $(FormatAsPackageName Entware) package list"
        else
            ShowWarning "Unable to update $(FormatAsPackageName Entware) package list $(FormatAsExitcode $result)"
            DebugErrorFile "$log_pathfile"
            # meh, continue anyway with old list ...
        fi
    else
        DebugInfo "$(FormatAsPackageName Entware) package list was updated less than $package_list_age minutes ago"
        ShowDone "$(FormatAsPackageName Entware) package list is up-to-date"
    fi

    DebugFuncExit
    return 0

    }

InstallBaseAddons()
    {

    IsError && return

    DebugFuncEntry

    if (IsQPKGInstalled SABnzbdplus || [[ $TARGET_APP = SABnzbdplus ]];) && [[ $NAS_QPKG_ARCH != none ]]; then
        if IsNotQPKGInstalled Par2; then
            InstallQPKG Par2
            if IsError; then
                ShowWarning "$(FormatAsPackageName Par2) installation failed - but it's not essential so I'm continuing"
                ResetErrorcode
                DebugVar errorcode
            fi
        fi
    fi

    # kludge: use the same ugly workaround until QPKG dep checking works properly
    if (IsQPKGInstalled SABnzbd || [[ $TARGET_APP = SABnzbd ]];) && [[ $NAS_QPKG_ARCH != none ]]; then
        if IsNotQPKGInstalled Par2; then
            InstallQPKG Par2
            if IsError; then
                ShowWarning "$(FormatAsPackageName Par2) installation failed - but it's not essential so I'm continuing"
                ResetErrorcode
                DebugVar errorcode
            fi
        fi
    fi

    InstallIPKGs
    DowngradePy3
    InstallPy2Modules
    InstallPy3Modules

    [[ $TARGET_APP = Entware || $update_all_apps = true ]] && RestartAllQPKGs

    DebugFuncExit
    return 0

    }

InstallTargetQPKG()
    {

    IsError && return
    [[ -z $TARGET_APP ]] && return 1

    DebugFuncEntry

    [[ $TARGET_APP != Entware ]] && InstallQPKG $TARGET_APP

    DebugFuncExit
    return 0

    }

InstallIPKGs()
    {

    IsError && return

    DebugFuncEntry
    local returncode=0
    local packages="$SHERPA_COMMON_IPKGS"
    local index=0

    if [[ -n $IPKG_DL_PATH && -d $IPKG_DL_PATH ]]; then
        UpdateEntware
        IsError && return
        for index in ${!SHERPA_QPKG_NAME[@]}; do
            if (IsQPKGInstalled ${SHERPA_QPKG_NAME[$index]}) || [[ $TARGET_APP = ${SHERPA_QPKG_NAME[$index]} ]]; then
                packages+=" ${SHERPA_QPKG_IPKGS[$index]}"
            fi
        done

        if (IsQPKGInstalled SABnzbdplus) || [[ $TARGET_APP = SABnzbdplus ]]; then
            [[ $NAS_QPKG_ARCH = none ]] && packages+=' par2cmdline'
        fi

        InstallIPKGBatch "$packages"
    else
        ShowError "IPKG download path [$IPKG_DL_PATH] does not exist"
        errorcode=15
        returncode=1
    fi

    DebugFuncExit
    return $returncode

    }

InstallIPKGBatch()
    {

    # $1 = space-separated string containing list of IPKG names to download and install

    [[ -z $1 ]] && return 1

    DebugFuncEntry
    local returncode=0
    local requested_IPKGs=''
    local log_pathfile="$IPKG_DL_PATH/IPKGs.$INSTALL_LOG_FILE"
    local result=0

    requested_IPKGs="$1"

    # errors can occur due to incompatible IPKGs (tried installing Entware-3x, then Entware-ng), so delete them first
    [[ -d $IPKG_DL_PATH ]] && rm -f "$IPKG_DL_PATH"/*.ipk
    [[ -d $IPKG_CACHE_PATH ]] && rm -f "$IPKG_CACHE_PATH"/*.ipk

    FindAllIPKGDependencies "$requested_IPKGs"

    if [[ $IPKG_download_count -gt 0 ]]; then
        local IPKG_download_startseconds=$(DebugStageStart)
        ShowProc "downloading & installing $IPKG_download_count IPKG$(DisplayPlural $IPKG_download_count)"

        $TOUCH_CMD "$monitor_flag"
        trap CTRL_C_Captured INT
        _MonitorDirSize_ "$IPKG_DL_PATH" $IPKG_download_size &

        RunThisAndLogResults "$OPKG_CMD install $ignore_space_arg --force-overwrite ${IPKG_download_list[*]} --cache $IPKG_CACHE_PATH --tmp-dir $IPKG_DL_PATH" "$log_pathfile"
        result=$?

        [[ -e $monitor_flag ]] && { rm "$monitor_flag"; $SLEEP_CMD 2 ;}
        trap - INT

        if [[ $result -eq 0 ]]; then
            ShowDone "downloaded & installed $IPKG_download_count IPKG$(DisplayPlural $IPKG_download_count)"
        else
            ShowError "download & install IPKG$(DisplayPlural $IPKG_download_count) failed $(FormatAsExitcode $result)"
            DebugErrorFile "$log_pathfile"

            errorcode=16
            returncode=1
        fi
        DebugStageEnd $IPKG_download_startseconds
    fi

    DebugFuncExit
    return $returncode

    }

DowngradePy3()
    {

    IsError && return

    # kludge: Watcher3 isn't presently compatible with Python 3.8.x so let's force a downgrade to 3.7.4

    IsNotQPKGInstalled OWatcher3 && [[ $TARGET_APP != OWatcher3 ]] && return
    [[ ! -e /opt/bin/python3 ]] && return
    [[ $(/opt/bin/python3 -V | $SED_CMD 's|[^0-9]*||g') -le 374 ]] && return

    DebugFuncEntry

    [[ -d $IPKG_DL_PATH ]] && rm -f "$IPKG_DL_PATH"/*.ipk

    local source_url=$($GREP_CMD 'http://' /opt/etc/opkg.conf | $SED_CMD 's|^.*\(http://\)|\1|')
    local pkg_base=python3
    local pkg_names=(asyncio base cgi cgitb codecs ctypes dbm decimal dev distutils email gdbm lib2to3 light logging lzma multiprocessing ncurses openssl pydoc sqlite3 unittest urllib xml)
    local pkg_name=''
    local pkg_version=3.7.4-2
    local pkg_arch=$($BASENAME_CMD $source_url | $SED_CMD 's|\-k|\-|;s|sf\-|\-|')
    local ipkg_urls=()
    local dl_log_pathfile="$IPKG_DL_PATH/IPKGs.$DOWNLOAD_LOG_FILE"
    local log_pathfile="$IPKG_DL_PATH/IPKGs.$INSTALL_LOG_FILE"
    local result=0

    ShowProc "$(FormatAsPackageName Watcher3) selected so downgrading Python 3 IPKGs"

    for pkg_name in ${pkg_names[@]}; do
        ipkg_urls+=(-O "${source_url}/archive/${pkg_base}-${pkg_name}_${pkg_version}_${pkg_arch}.ipk")
    done

    # include base package
    ipkg_urls+=(-O "${source_url}/archive/${pkg_base}_${pkg_version}_${pkg_arch}.ipk")

    # also need to downgrade 'pip3' to prevent 'pip not found' error
    pkg_name=pip
    pkg_version=19.0.3-1
    ipkg_urls+=(-O "${source_url}/archive/${pkg_base}-${pkg_name}_${pkg_version}_${pkg_arch}.ipk")

    # and a specific version of cryptography, so SAB3 will restart correctly
    pkg_name=cryptography
    pkg_version=2.7-2
    ipkg_urls+=(-O "${source_url}/archive/${pkg_base}-${pkg_name}_${pkg_version}_${pkg_arch}.ipk")

    (cd "$IPKG_DL_PATH" && $CURL_CMD $curl_insecure_arg ${ipkg_urls[@]} >> "$dl_log_pathfile" 2>&1)

    RunThisAndLogResults "$OPKG_CMD install --force-downgrade $IPKG_DL_PATH/*.ipk" "$log_pathfile"
    result=$?

    ShowDone "$(FormatAsPackageName Watcher3) selected so downgraded Python 3 IPKGs"

    DebugFuncExit
    return $returncode

    }

InstallPy2Modules()
    {

    IsError && return

    # kludge: Python 2.7.x is no-longer available via Entware/OpenWRT, so disable any PIP2 execution for now
    return

    DebugFuncEntry
    local exec_cmd=''
    local result=0
    local returncode=0
    local packages=''
    local desc='Python 2 modules'
    local log_pathfile="$WORKING_PATH/Py2-modules.$INSTALL_LOG_FILE"

    for index in ${!SHERPA_QPKG_NAME[@]}; do
        if (IsQPKGInstalled ${SHERPA_QPKG_NAME[$index]}) || [[ $TARGET_APP = ${SHERPA_QPKG_NAME[$index]} ]]; then
            packages+=" ${SHERPA_QPKG_PIP2S[$index]}"
        fi
    done

    # sometimes, OpenWRT 'pip' is for Py3, so let's prefer a Py2 version
    if [[ -e /opt/bin/pip2 ]]; then
        pip2_cmd=/opt/bin/pip2
    elif [[ -e /opt/bin/pip2.7 ]]; then
        pip2_cmd=/opt/bin/pip2.7
    elif [[ -e /opt/bin/pip ]]; then
        pip2_cmd=/opt/bin/pip
    else
        if IsNotSysFilePresent $pip2_cmd; then
            errorcode=17
            return 1
        fi
    fi

    [[ -n ${SHERPA_COMMON_PIP2S// /} ]] && exec_cmd="$pip2_cmd install $SHERPA_COMMON_PIP2S --disable-pip-version-check"
    [[ -n ${SHERPA_COMMON_PIP2S// /} && -n ${packages// /} ]] && exec_cmd+=" && "
    [[ -n ${packages// /} ]] && exec_cmd+="$pip2_cmd install $packages --disable-pip-version-check"
    [[ -z $exec_cmd ]] && return

    ShowProc "downloading & installing $desc"

    RunThisAndLogResults "$exec_cmd" "$log_pathfile"
    result=$?

    if [[ $result -eq 0 ]]; then
        ShowDone "downloaded & installed $desc"
    else
        ShowError "download & install $desc failed $(FormatAsResult "$result")"
        DebugErrorFile "$log_pathfile"

        errorcode=18
        returncode=1
    fi

    DebugFuncExit
    return $returncode

    }

InstallPy3Modules()
    {

    IsError && return

    DebugFuncEntry
    local exec_cmd=''
    local result=0
    local returncode=0
    local packages=''
    local desc='Python 3 modules'
    local log_pathfile="$WORKING_PATH/Py3-modules.$INSTALL_LOG_FILE"

    for index in ${!SHERPA_QPKG_NAME[@]}; do
        if (IsQPKGInstalled ${SHERPA_QPKG_NAME[$index]}) || [[ $TARGET_APP = ${SHERPA_QPKG_NAME[$index]} ]]; then
            packages+=" ${SHERPA_QPKG_PIP3S[$index]}"
        fi
    done

    # sometimes, OpenWRT doesn't have a 'pip3'
    if [[ -e /opt/bin/pip3 ]]; then
        pip3_cmd=/opt/bin/pip3
    elif [[ -e /opt/bin/pip3.8 ]]; then
        pip3_cmd=/opt/bin/pip3.8
    else
        if IsNotSysFilePresent $pip3_cmd; then
            echo -e "\n* Ugh! The usual fix is to let sherpa reinstall Entware at least once."
            echo -e "\t./sherpa.sh ew"
            echo -e "If it happens again after reinstalling Entware, please create a new issue for this on GitHub."
            errorcode=19
            return 1
        fi
    fi

    [[ -n ${SHERPA_COMMON_PIP3S// /} ]] && exec_cmd="$pip3_cmd install $SHERPA_COMMON_PIP3S --disable-pip-version-check"
    [[ -n ${SHERPA_COMMON_PIP3S// /} && -n ${packages// /} ]] && exec_cmd+=" && "
    [[ -n ${packages// /} ]] && exec_cmd+="$pip3_cmd install $packages --disable-pip-version-check"

    # kludge: force recompilation of 'sabyenc3' package so it's recognised by SABnzbd. See: https://forums.sabnzbd.org/viewtopic.php?p=121214#p121214
    [[ $exec_cmd =~ .*sabyenc3.* ]] && exec_cmd+=" && $pip3_cmd install --force-reinstall --ignore-installed --no-binary :all: sabyenc3 --disable-pip-version-check"

    [[ -z $exec_cmd ]] && return

    ShowProc "downloading & installing $desc"

    RunThisAndLogResults "$exec_cmd" "$log_pathfile"
    result=$?

    if [[ $result -eq 0 ]]; then
        ShowDone "downloaded & installed $desc"
    else
        ShowError "download & install $desc failed $(FormatAsResult "$result")"
        DebugErrorFile "$log_pathfile"

        errorcode=20
        returncode=1
    fi

    DebugFuncExit
    return $returncode

    }

RestartAllQPKGs()
    {

    IsError && return

    DebugFuncEntry
    local index=0
    local dependent_on=''

    for index in ${!SHERPA_QPKG_NAME[@]}; do
        if (IsQPKGUserInstallable ${SHERPA_QPKG_NAME[$index]}) && (IsQPKGEnabled ${SHERPA_QPKG_NAME[$index]}); then
            if [[ $update_all_apps = true ]]; then
                QPKGServiceCtl restart ${SHERPA_QPKG_NAME[$index]}
            else
                for dependent_on in ${SHERPA_QPKG_DEPS[$index]}; do
                    if [[ $dependent_on = $TARGET_APP ]]; then
                        QPKGServiceCtl restart ${SHERPA_QPKG_NAME[$index]}
                        break
                    fi
                done
            fi
        fi
    done

    DebugFuncExit
    return 0

    }

InstallQPKG()
    {

    # $1 = QPKG name to install

    IsError && return
    [[ -z $1 ]] && return 1

    local target_file=''
    local result=0
    local returncode=0
    local local_pathfile="$(GetQPKGPathFilename $1)"

    if [[ ${local_pathfile##*.} = zip ]]; then
        $UNZIP_CMD -nq "$local_pathfile" -d "$QPKG_DL_PATH"
        local_pathfile="${local_pathfile%.*}"
    fi

    local log_pathfile="$local_pathfile.$INSTALL_LOG_FILE"
    target_file=$($BASENAME_CMD "$local_pathfile")

    ShowProcLong "installing file $(FormatAsFileName "$target_file")"

    RunThisAndLogResults "sh $local_pathfile" "$log_pathfile"
    result=$?

    if [[ $result -eq 0 || $result -eq 10 ]]; then
        ShowDone "installed file $(FormatAsFileName "$target_file")"
    else
        ShowError "file installation failed $(FormatAsFileName "$target_file") $(FormatAsExitcode $result)"
        DebugErrorFile "$log_pathfile"

        errorcode=21
        returncode=1
    fi

    return $returncode

    }

ReloadProfile()
    {

    IsQPKGInstalled Entware && PATH="/opt/bin:/opt/sbin:$PATH"

    DebugDone 'adjusted $PATH'
    DebugVar PATH

    return 0

    }

DownloadQPKG()
    {

    # $1 = QPKG name to download

    IsError && return
    [[ -z $1 ]] && return 1

    DebugFuncEntry
    local result=0
    local returncode=0
    local remote_url=$(GetQPKGRemoteURL $1)
    local remote_filename="$($BASENAME_CMD "$remote_url")"
    local remote_filename_md5="$(GetQPKGMD5 $1)"
    local local_pathfile="$QPKG_DL_PATH/$remote_filename"
    local local_filename="$($BASENAME_CMD "$local_pathfile")"
    local log_pathfile="$local_pathfile.$DOWNLOAD_LOG_FILE"

    if [[ -e $local_pathfile ]]; then
        if FileMatchesMD5 "$local_pathfile" "$remote_filename_md5"; then
            DebugInfo "existing QPKG checksum correct $(FormatAsFileName "$local_filename")"
        else
            DebugWarning "existing QPKG checksum incorrect $(FormatAsFileName "$local_filename")"
            DebugInfo "deleting file $(FormatAsFileName "$local_filename")"
            rm -f "$local_pathfile"
        fi
    fi

    if IsNotError && [[ ! -e $local_pathfile ]]; then
        ShowProc "downloading file $(FormatAsFileName "$remote_filename")"

        [[ -e $log_pathfile ]] && rm -f "$log_pathfile"

        if IsDebugMode; then
            RunThisAndLogResultsRealtime "$CURL_CMD $curl_insecure_arg --output $local_pathfile $remote_url" "$log_pathfile"
            result=$?
        else
            RunThisAndLogResults "$CURL_CMD $curl_insecure_arg --output $local_pathfile $remote_url" "$log_pathfile"
            result=$?
        fi

        if [[ $result -eq 0 ]]; then
            if FileMatchesMD5 "$local_pathfile" "$remote_filename_md5"; then
                ShowDone "downloaded file $(FormatAsFileName "$remote_filename")"
            else
                ShowError "downloaded file checksum incorrect $(FormatAsFileName "$local_pathfile")"
                errorcode=22
                returncode=1
            fi
        else
            ShowError "download failed $(FormatAsFileName "$local_pathfile") $(FormatAsExitcode $result)"
            DebugErrorFile "$log_pathfile"

            errorcode=23
            returncode=1
        fi
    fi

    DebugFuncExit
    return $returncode

    }

CalcNASQPKGArch()
    {

    # Decide which package arch is suitable for this NAS. Only needed for Stephane's packages.
    # creates a global constant: $NAS_QPKG_ARCH

    case $($UNAME_CMD -m) in
        x86_64)
            [[ ${NAS_FIRMWARE//.} -ge 430 ]] && NAS_QPKG_ARCH=x64 || NAS_QPKG_ARCH=x86
            ;;
        i686|x86)
            NAS_QPKG_ARCH=x86
            ;;
        armv7l)
            case $($GETCFG_CMD Platform -f $PLATFORM_PATHFILE) in
                ARM_MS)
                    NAS_QPKG_ARCH=x31
                    ;;
                ARM_AL)
                    NAS_QPKG_ARCH=x41
                    ;;
                *)
                    NAS_QPKG_ARCH=none
                    ;;
            esac
            ;;
        aarch64)
            NAS_QPKG_ARCH=a64
            ;;
        *)
            NAS_QPKG_ARCH=none
            ;;
    esac

    readonly NAS_QPKG_ARCH

    return 0

    }

LoadInstalledQPKGVars()
    {

    # $1 = load variables for this installed package name

    [[ -z $1 ]] && return 1

    local package_name=$1
    local prev_config_dir=''
    local prev_config_file=''
    local package_settings_pathfile=''
    package_installed_path=''
    package_config_path=''

    package_installed_path=$($GETCFG_CMD $package_name Install_Path -f $APP_CENTER_CONFIG_PATHFILE)
    if [[ $? -eq 0 ]]; then
        for prev_config_dir in ${PREV_QPKG_CONFIG_DIRS[@]}; do
            package_config_path=$package_installed_path/$prev_config_dir
            [[ -d $package_config_path ]] && break
        done

        for prev_config_file in ${PREV_QPKG_CONFIG_FILES[@]}; do
            package_settings_pathfile=$package_config_path/$prev_config_file
            [[ -f $package_settings_pathfile ]] && break
        done
    else
        DebugError 'QPKG not installed?'
        errorcode=24
        return 1
    fi

    return 0

    }

UninstallQPKG()
    {

    # $1 = QPKG name

    IsError && return
    [[ -z $1 ]] && return 1

    local result=0

    qpkg_installed_path="$($GETCFG_CMD $1 Install_Path -f $APP_CENTER_CONFIG_PATHFILE)"
    result=$?

    if [[ $result -eq 0 ]]; then
        if [[ -e $qpkg_installed_path/.uninstall.sh ]]; then
            ShowProc "uninstalling $(FormatAsPackageName $1)"

            $qpkg_installed_path/.uninstall.sh > /dev/null
            result=$?

            if [[ $result -eq 0 ]]; then
                ShowDone "uninstalled $(FormatAsPackageName $1)"
            else
                ShowError "unable to uninstall $(FormatAsPackageName $1) $(FormatAsExitcode $result)"
                errorcode=25
                return 1
            fi
        fi

        $RMCFG_CMD $1 -f $APP_CENTER_CONFIG_PATHFILE
    else
        DebugQPKG "$(FormatAsPackageName $1)" "not installed $(FormatAsExitcode $result)"
    fi

    return 0

    }

QPKGServiceCtl()
    {

    # $1 = action (start|stop|restart)
    # $2 = QPKG name

    # this function is used in-place of [qpkg_service] as the QTS 4.2.6 version does not offer returncodes

    if [[ -z $1 ]]; then
        DebugError 'action unspecified'
        errorcode=26
        return 1
    elif [[ -z $2 ]]; then
        DebugError 'QPKG name unspecified'
        errorcode=27
        return 1
    fi

    local result=0
    local init_pathfile=''

    init_pathfile=$(GetQPKGServiceFile $2)

    case $1 in
        start)
            ShowProcLong "starting service $(FormatAsPackageName $2)"
            RunThisAndLogResults "$init_pathfile start" "$qpkg_pathfile.$START_LOG_FILE"
            result=$?

            if [[ $result -eq 0 ]]; then
                ShowDone "started service $(FormatAsPackageName $2)"
            else
                ShowWarning "Could not start service $(FormatAsPackageName $2) $(FormatAsExitcode $result)"
                if IsDebugMode; then
                    DebugInfoThickSeparator
                    $CAT_CMD "$qpkg_pathfile.$START_LOG_FILE"
                    DebugInfoThickSeparator
                else
                    $CAT_CMD "$qpkg_pathfile.$START_LOG_FILE" >> "$DEBUG_LOG_PATHFILE"
                fi
                errorcode=28
                return 1
            fi
            ;;
        stop)
            ShowProc "stopping service $(FormatAsPackageName $2)"
            RunThisAndLogResults "$init_pathfile stop" "$qpkg_pathfile.$STOP_LOG_FILE"
            result=$?

            if [[ $result -eq 0 ]]; then
                ShowDone "stopped service $(FormatAsPackageName $2)"
            else
                ShowWarning "Could not stop service $(FormatAsPackageName $2) $(FormatAsExitcode $result)"
                if IsDebugMode; then
                    DebugInfoThickSeparator
                    $CAT_CMD "$qpkg_pathfile.$STOP_LOG_FILE"
                    DebugInfoThickSeparator
                else
                    $CAT_CMD "$qpkg_pathfile.$STOP_LOG_FILE" >> "$DEBUG_LOG_PATHFILE"
                fi
                # meh, continue anyway...
                return 1
            fi
            ;;
        restart)
            ShowProc "restarting service $(FormatAsPackageName $2)"
            RunThisAndLogResults "$init_pathfile restart" "$qpkg_pathfile.$RESTART_LOG_FILE"
            result=$?

            if [[ $result -eq 0 ]]; then
                ShowDone "restarted service $(FormatAsPackageName $2)"
            else
                ShowWarning "Could not restart service $(FormatAsPackageName $2) $(FormatAsExitcode $result)"
                if IsDebugMode; then
                    DebugInfoThickSeparator
                    $CAT_CMD "$qpkg_pathfile.$RESTART_LOG_FILE"
                    DebugInfoThickSeparator
                else
                    $CAT_CMD "$qpkg_pathfile.$RESTART_LOG_FILE" >> "$DEBUG_LOG_PATHFILE"
                fi
                # meh, continue anyway...
                return 1
            fi
            ;;
        *)
            DebugError "Unrecognised action '$1'"
            errorcode=29
            return 1
            ;;
    esac

    return 0

    }

GetQPKGServiceFile()
    {

    # $1 = QPKG name
    # stdout = QPKG init pathfilename
    # $? = 0 if successful, 1 if failed

    [[ -z $1 ]] && return 1

    local output=''
    local returncode=0

    output=$($GETCFG_CMD $1 Shell -f $APP_CENTER_CONFIG_PATHFILE)

    if [[ -z $output ]]; then
        DebugError "No service file configured for package $(FormatAsPackageName $1)"
        errorcode=30
        returncode=1
    elif [[ ! -e $output ]]; then
        DebugError "Package service file not found $(FormatAsStdout "$output")"
        errorcode=31
        returncode=1
    fi

    echo "$output"
    return $returncode

    }

GetQPKGPathFilename()
    {

    # $1 = QPKG name
    # stdout = QPKG local filename
    # $? = 0 if successful, 1 if failed

    [[ -z $1 ]] && return 1

    echo "$QPKG_DL_PATH/$($BASENAME_CMD "$(GetQPKGRemoteURL $1)")"

    }

GetQPKGRemoteURL()
    {

    # $1 = QPKG name
    # stdout = QPKG remote URL
    # $? = 0 if successful, 1 if failed

    [[ -z $1 ]] && return 1

    local index=0
    local returncode=1

    for index in ${!SHERPA_QPKG_NAME[@]}; do
        if [[ $1 = ${SHERPA_QPKG_NAME[$index]} ]] && [[ ${SHERPA_QPKG_ARCH[$index]} = all || ${SHERPA_QPKG_ARCH[$index]} = $NAS_QPKG_ARCH ]]; then
            echo "${SHERPA_QPKG_URL[$index]}"
            returncode=0
            break
        fi
    done

    return $returncode

    }

GetQPKGMD5()
    {

    # $1 = QPKG name
    # stdout = QPKG MD5
    # $? = 0 if successful, 1 if failed

    [[ -z $1 ]] && return 1

    local index=0
    local returncode=1

    for index in ${!SHERPA_QPKG_NAME[@]}; do
        if [[ $1 = ${SHERPA_QPKG_NAME[$index]} ]] && [[ ${SHERPA_QPKG_ARCH[$index]} = all || ${SHERPA_QPKG_ARCH[$index]} = $NAS_QPKG_ARCH ]]; then
            echo "${SHERPA_QPKG_MD5[$index]}"
            returncode=0
            break
        fi
    done

    return $returncode

    }

CTRL_C_Captured()
    {

    [[ -e $monitor_flag ]] && rm "$monitor_flag"

    $SLEEP_CMD 2

    exit

    }

Cleanup()
    {

    DebugFuncEntry

    cd $SHARE_PUBLIC_PATH

    IsNotError && [[ -d $WORKING_PATH ]] && IsNotDebugMode && IsNotDevMode && rm -rf "$WORKING_PATH"

    DebugFuncExit
    return 0

    }

ShowResult()
    {

    DebugFuncEntry
    local RE=''

    if ! IsHelpOnly && ! IsVersionOnly; then
        if [[ -n $TARGET_APP ]]; then
            [[ $reinstall_flag = true ]] && RE='re' || RE=''

            if IsNotError; then
                IsDebugMode && emoticon=':DD' || { emoticon=''; echo ;}
                ShowDone "$(FormatAsPackageName $TARGET_APP) has been successfully ${RE}installed! $emoticon"
            else
                IsDebugMode && emoticon=':S ' || { emoticon=''; echo ;}
                ShowError "$(FormatAsPackageName $TARGET_APP) ${RE}install failed! ${emoticon}[$errorcode]"
                EnableSuggestIssue
            fi
        fi

        if IsSatisfyDependenciesOnly; then
            if IsNotError; then
                IsDebugMode && emoticon=':DD' || { emoticon=''; echo ;}
                ShowDone "all application dependencies are installed! $emoticon"
            else
                IsDebugMode && emoticon=':S ' || { emoticon=''; echo ;}
                ShowError "application dependency check failed! ${emoticon}[$errorcode]"
                EnableSuggestIssue
            fi
        fi
    fi

    if IsSuggestIssue; then
        echo -e "\n* Please consider creating a new issue for this on GitHub:\n\thttps://github.com/OneCDOnly/sherpa/issues"
        echo -e "\n* Alternatively, post on the QNAP NAS Community Forum:\n\thttps://forum.qnap.com/viewtopic.php?f=320&t=132373"
        echo -e "\n* Remember to include a copy of your sherpa runtime debug log for analysis."
    fi

    DebugInfoThinSeparator
    DebugScript 'finished' "$($DATE_CMD)"
    DebugScript 'elapsed time' "$(ConvertSecsToMinutes "$(($($DATE_CMD +%s)-$([[ -n $SCRIPT_STARTSECONDS ]] && echo $SCRIPT_STARTSECONDS || echo "1")))")"
    DebugInfoThickSeparator

    [[ -e $DEBUG_LOG_PATHFILE ]] && IsNotDebugMode && ! IsVersionOnly && echo -e "\n- To display the runtime debug log:\n\tcat $(basename $DEBUG_LOG_PATHFILE)\n"

    DebugFuncExit
    return 0

    }

GetQPKGDeps()
    {

    # $1 = QPKG name to return dependencies for

    [[ -z $1 ]] && return 1

    local index=0

    for index in ${!SHERPA_QPKG_NAME[@]}; do
        if [[ ${SHERPA_QPKG_NAME[$index]} = $1 ]]; then
            echo ${SHERPA_QPKG_DEPS[$index]}
            return 0
        fi
    done

    return 1

    }

FindAllQPKGDependencies()
    {

    # From a specified list of QPKG names, find all dependent QPKGs then generate a total qty to download.
    # input:
    #   $1 = string with space-separated initial QPKG names.
    # output:
    #   $QPKG_download_list = name-sorted array with complete list of all QPKGs, including those originally specified.
    #   $QPKG_download_count = number of packages to be downloaded.

    [[ -z $1 ]] && return 1

    QPKG_download_list=()
    QPKG_download_count=0
    local requested_list=''
    local dependency_list=''
    local last_list=''
    local all_list=''
    local new_list=''
    local iterations=0
    local -r ITERATION_LIMIT=6
    local complete=false
    local -r SEARCH_STARTSECONDS=$(DebugStageStart)

    requested_list=$(DeDupeWords "$1")
    last_list=$requested_list

    ShowProc 'calculating number of QPKGs required'
    DebugInfo "requested QPKGs: $requested_list"

    DebugProc 'finding QPKG dependencies'
    while [[ $iterations -lt $ITERATION_LIMIT ]]; do
        ((iterations++))
        new_list=''
        for package in ${last_list[@]}; do
            new_list+=$(GetQPKGDeps $package)
        done

        new_list=$(DeDupeWords "$new_list")

        if [[ -n $new_list ]]; then
            dependency_list+=${new_list[*]}
            last_list=$new_list
        else
            DebugDone 'complete'
            DebugInfo "found all QPKG dependencies in $iterations iteration$(DisplayPlural $iterations)"
            complete=true
            break
        fi
    done

    if [[ $complete = false ]]; then
        DebugError "QPKG dependency list is incomplete! Consider raising \$ITERATION_LIMIT [$ITERATION_LIMIT]."
        EnableSuggestIssue
    fi

    all_list=$(DeDupeWords "$requested_list $dependency_list")
    DebugInfo "QPKGs requested + dependencies: $all_list"

    DebugProc 'excluding QPKGs already installed'
    for element in ${all_list[@]}; do
        IsNotQPKGInstalled $element && QPKG_download_list+=($element)
    done
    DebugDone 'complete'
    DebugInfo "QPKGs to download: ${QPKG_download_list[*]}"
    QPKG_download_count=${#QPKG_download_list[@]}

    DebugStageEnd $SEARCH_STARTSECONDS

    if [[ $QPKG_download_count -gt 0 ]]; then
        ShowDone "$QPKG_download_count QPKG$(DisplayPlural $QPKG_download_count) to be downloaded"
    else
        ShowDone 'no QPKGs are required'
    fi

    }

FindAllIPKGDependencies()
    {

    # From a specified list of IPKG names, find all dependent IPKGs, exclude those already installed, then generate a total qty to download and a total download byte-size.
    # input:
    #   $1 = string with space-separated initial IPKG names.
    # output:
    #   $IPKG_download_list = name-sorted array with complete list of all IPKGs, including those originally specified.
    #   $IPKG_download_count = number of packages to be downloaded.
    #   $IPKG_download_size = byte-count of packages to be downloaded.

    [[ -z $1 ]] && return 1

    if IsNotSysFilePresent $OPKG_CMD; then
        errorcode=32
        return 1
    fi

    IPKG_download_list=()
    IPKG_download_count=0
    IPKG_download_size=0
    local requested_list=''
    local dependency_list=''
    local last_list=''
    local all_list=''
    local iterations=0
    local -r ITERATION_LIMIT=20
    local complete=false
    local result_size=0
    local -r SEARCH_STARTSECONDS=$(DebugStageStart)

    # remove duplicate entries
    requested_list=$(DeDupeWords "$1")
    last_list=$requested_list

    ShowProc 'calculating number and total size of IPKGs required'
    DebugInfo "IPKGs requested: $requested_list"

    DebugProc 'finding IPKG dependencies'

    while [[ $iterations -lt $ITERATION_LIMIT ]]; do
        ((iterations++))
        last_list=$($OPKG_CMD depends -A $last_list | $GREP_CMD -v 'depends on:' | $SED_CMD 's|^[[:blank:]]*||;s|[[:blank:]]*$||' | $TR_CMD ' ' '\n' | $SORT_CMD | $UNIQ_CMD)

        if [[ -n $last_list ]]; then
            dependency_list+=" $last_list"
        else
            DebugDone 'complete'
            DebugInfo "found all IPKG dependencies in $iterations iteration$(DisplayPlural $iterations)"
            complete=true
            break
        fi
    done

    if [[ $complete = false ]]; then
        DebugError "IPKG dependency list is incomplete! Consider raising \$ITERATION_LIMIT [$ITERATION_LIMIT]."
        EnableSuggestIssue
    fi

    all_list=$(DeDupeWords "$requested_list $dependency_list")
    DebugInfo "IPKGs requested + dependencies: $all_list"

    DebugProc 'excluding IPKGs already installed'
    for element in ${all_list[@]}; do
        if [[ $element != 'ca-certs' ]]; then   # kludge: 'ca-certs' appears to be a bogus meta-package, so silently exclude it from attempted installation
            if ! $OPKG_CMD status "$element" | $GREP_CMD -q "Status:.*installed"; then
                IPKG_download_list+=($element)
            fi
        fi
    done
    DebugDone 'complete'
    DebugInfo "IPKGs to download: ${IPKG_download_list[*]}"

    IPKG_download_count=${#IPKG_download_list[@]}

    if [[ $IPKG_download_count -gt 0 ]]; then
        DebugProc "calculating size of IPKG$(DisplayPlural $IPKG_download_count) to download"
        for element in ${IPKG_download_list[@]}; do
            result_size=$($OPKG_CMD info $element | $GREP_CMD -F 'Size:' | $SED_CMD 's|^Size: ||')
            ((IPKG_download_size+=result_size))
        done
        DebugDone 'complete'
    fi

    DebugVar IPKG_download_size
    DebugStageEnd $SEARCH_STARTSECONDS

    if [[ $IPKG_download_count -gt 0 ]]; then
        ShowDone "$IPKG_download_count IPKG$(DisplayPlural $IPKG_download_count) ($(FormatAsISO $IPKG_download_size)) to be downloaded"
    else
        ShowDone 'no IPKGs are required'
    fi

    }

_MonitorDirSize_()
    {

    # * This function runs autonomously *
    # It watches for the existence of the pathfile set in $monitor_flag.
    # If that file is removed, this function dies gracefully.

    # $1 = directory to monitor the size of.
    # $2 = total target bytes (100%) for specified path.

    [[ -z $1 || ! -d $1 || -z $2 || $2 -eq 0 ]] && return 1

    if IsNotSysFilePresent $FIND_CMD; then
        errorcode=33
        return 1
    fi

    local target_dir="$1"
    local total_bytes=$2
    local last_bytes=0
    local stall_seconds=0
    local stall_seconds_threshold=4
    local current_bytes=0
    local percent=''

    progress_message=''
    previous_length=0
    previous_msg=''

    while [[ -e $monitor_flag ]]; do
        current_bytes=$($FIND_CMD $target_dir -type f -name '*.ipk' -exec $DU_CMD --bytes --total --apparent-size {} + 2> /dev/null | $GREP_CMD total$ | $CUT_CMD -f1)
        [[ -z $current_bytes ]] && current_bytes=0

        if [[ $current_bytes -ne $last_bytes ]]; then
            stall_seconds=0
            last_bytes=$current_bytes
        else
            ((stall_seconds++))
        fi

        percent="$((200*(current_bytes)/(total_bytes) % 2 + 100*(current_bytes)/(total_bytes)))%"
        progress_message=" $percent ($(FormatAsISO $current_bytes)/$(FormatAsISO $total_bytes))"

        if [[ $stall_seconds -ge $stall_seconds_threshold ]]; then
            if [[ $stall_seconds -lt 60 ]]; then
                progress_message+=" stalled for $stall_seconds seconds"
            else
                progress_message+=" stalled for $(ConvertSecsToMinutes $stall_seconds)"
            fi
        fi

        ProgressUpdater "$progress_message"
        $SLEEP_CMD 1
    done

    [[ -n $progress_message ]] && ProgressUpdater ' done!'

    }

IsSysFilePresent()
    {

    # input:
    #   $1 = pathfile to check
    # output:
    #   $? = 0 (true) or 1 (false)

    [[ -z $1 ]] && return 1

    if ! [[ -f $1 || -L $1 ]]; then
        ShowError "a required NAS system file is missing $(FormatAsFileName $1)"
        errorcode=34
        return 1
    else
        return 0
    fi

    }

IsSysSharePresent()
    {

    # input:
    #   $1 = symlink path to check
    # output:
    #   $? = 0 (true) or 1 (false)

    [[ -z $1 ]] && return 1

    if [[ ! -L $1 ]]; then
        ShowError "a required NAS system share is missing $(FormatAsFileName $1). Please re-create it via the QTS Control Panel -> Privilege Settings -> Shared Folders."
        errorcode=35
        return 1
    else
        return 0
    fi

    }

IsIPKGInstalled()
    {

    # input:
    #   $1 = package name to check
    # output:
    #   $? = 0 (true) or 1 (false)

    [[ -z $1 ]] && return 1

    if ! ($OPKG_CMD list-installed | $GREP_CMD -q -F "$1"); then
        DebugIPKG "'$1'" 'not installed'
        return 1
    else
        DebugIPKG "'$1'" 'installed'
        return 0
    fi

    }

# all functions below here do-not generate global or logged errors

EnableQPKG()
    {

    # $1 = package name to enable

    [[ -z $1 ]] && return 1

    if [[ $($GETCFG_CMD $1 Enable -u -f $APP_CENTER_CONFIG_PATHFILE) != 'TRUE' ]]; then
        DebugProc "enabling QPKG $(FormatAsPackageName $1)"
        $SETCFG_CMD $1 Enable TRUE -f $APP_CENTER_CONFIG_PATHFILE
        DebugDone "QPKG $(FormatAsPackageName $1) enabled"
    fi

    }

IsQPKGUserInstallable()
    {

    # input:
    #   $1 = package name to check
    # output:
    #   $? = 0 (true) or 1 (false)

    [[ -z $1 ]] && return 1
    [[ ${#SHERPA_QPKG_NAME[@]} -eq 0 || ${#SHERPA_QPKG_ABBRVS[@]} -eq 0 ]] && return 1

    local returncode=1
    local package_index=0

    for package_index in ${!SHERPA_QPKG_NAME[@]}; do
        if [[ ${SHERPA_QPKG_NAME[$package_index]} = $1 && -n ${SHERPA_QPKG_ABBRVS[$package_index]} ]]; then
            returncode=0
            break
        fi
    done

    return $returncode

    }

IsQPKGToBeInstalled()
    {

    # input:
    #   $1 = package name to check
    # output:
    #   $? = 0 (true) or 1 (false)

    [[ -z $1 ]] && return 1

    local package=''

    for package in ${QPKGS_to_install[@]}; do
        [[ $package = $1 ]] && return 0
    done

    for package in ${QPKGS_to_reinstall[@]}; do
        [[ $package = $1 ]] && return 0
    done

    return 1

    }

IsQPKGInstalled()
    {

    # input:
    #   $1 = package name to check
    # output:
    #   $? = 0 (true) or 1 (false)

    [[ -z $1 ]] && return 1

    [[ $($GETCFG_CMD $1 RC_Number -d 0 -f $APP_CENTER_CONFIG_PATHFILE) -gt 0 ]]

    }

IsNotQPKGInstalled()
    {

    # input:
    #   $1 = package name to check
    # output:
    #   $? = 0 (true) or 1 (false)

    [[ -z $1 ]] && return 1

    ! IsQPKGInstalled "$1"

    }

IsQPKGEnabled()
    {

    # input:
    #   $1 = package name to check
    # output:
    #   $? = 0 (true) or 1 (false)

    [[ -z $1 ]] && return 1

    [[ $($GETCFG_CMD $1 Enable -u -f $APP_CENTER_CONFIG_PATHFILE) = 'TRUE' ]]

    }

IsNotQPKGEnabled()
    {

    # input:
    #   $1 = package name to check
    # output:
    #   $? = 0 (true) or 1 (false)

    [[ -z $1 ]] && return 1

    ! IsQPKGEnabled "$1"

    }

IsNotSysFilePresent()
    {

    # input:
    #   $1 = pathfile to check
    # output:
    #   $? = 0 (true) or 1 (false)

    [[ -z $1 ]] && return 1

    ! IsSysFilePresent "$1"

    }

IsNotSysSharePresent()
    {

    # input:
    #   $1 = symlink path to check
    # output:
    #   $? = 0 (true) or 1 (false)

    [[ -z $1 ]] && return 1

    ! IsSysSharePresent "$1"

    }

MatchAbbrvToQPKGName()
    {

    # input:
    #   $1 = a potential package abbreviation supplied by user
    # output:
    #   stdout = matched installable package name (empty if unmatched)
    #   $? = 0 (matched) or 1 (unmatched)

    [[ -z $1 ]] && return 1
    [[ ${#SHERPA_QPKG_NAME[@]} -eq 0 || ${#SHERPA_QPKG_ABBRVS[@]} -eq 0 ]] && return 1

    local returncode=1
    local abbs=()
    local package_index=0
    local abb_index=0

    for package_index in ${!SHERPA_QPKG_NAME[@]}; do
        abbs=(${SHERPA_QPKG_ABBRVS[$package_index]})
        for abb_index in ${!abbs[@]}; do
            if [[ ${abbs[$abb_index]} = $1 ]]; then
                echo ${SHERPA_QPKG_NAME[$package_index]}
                returncode=0
                break 2
            fi
        done
    done

    return $returncode

    }

RunThisAndLogResults()
    {

    # Run a command string and log the results
    # input:
    #   $1 = command string to execute
    #   $2 = pathfilename to record this operation in
    # output:
    #   $? = result code of command string

    [[ -z $1 || -z $2 ]] && return 1

    local msgs=''
    local result=0

    FormatAsCommand "$1" >> "$2"
    msgs=$(eval $1 2>&1)
    result=$?
    FormatAsResult "$result" >> "$2"
    FormatAsStdout "$msgs" >> "$2"

    return $result

    }

RunThisAndLogResultsRealtime()
    {

    # Run a command string, show and log the results
    # input:
    #   $1 = command string to execute
    #   $2 = pathfilename to record this operation in
    # output:
    #   $? = result code of command string

    [[ -z $1 || -z $2 ]] && return 1

    local msgs=''
    local result=0

    FormatAsCommand "$1" >> "$2"
    exec 5>&1
    msgs=$(eval $1 2>&1 | $TEE_CMD /dev/fd/5)
    result=$?
    FormatAsResult "$result" >> "$2"
    FormatAsStdout "$msgs" >> "$2"

    return $result

    }

DeDupeWords()
    {

    [[ -z $1 ]] && return 1

    $TR_CMD ' ' '\n' <<< $1 | $SORT_CMD | $UNIQ_CMD | $TR_CMD '\n' ' ' | $SED_CMD 's|^[[:blank:]]*||;s|[[:blank:]]*$||'

    }

DisplayPlural()
    {

    [[ $1 -ne 1 ]] && echo 's'

    }

FileMatchesMD5()
    {

    # $1 = pathfilename to generate an MD5 checksum for
    # $2 = MD5 checksum to compare against

    [[ -z $1 || -z $2 ]] && return 1

    [[ $($MD5SUM_CMD "$1" | $CUT_CMD -f1 -d' ') = $2 ]]

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

EnableHelpOnly()
    {

    help_only=true
    DebugVar help_only

    }

DisableHelpOnly()
    {

    help_only=false
    DebugVar help_only

    }

EnableVersionOnly()
    {

    version_only=true
    DebugVar version_only

    }

DisableVersionOnly()
    {

    version_only=false
    DebugVar version_only

    }

IsError()
    {

    [[ $errorcode -gt 0 ]]

    }

IsNotError()
    {

    [[ $errorcode -eq 0 ]]

    }

IsHelpOnly()
    {

    [[ $help_only = true ]]

    }

IsVersionOnly()
    {

    [[ $version_only = true ]]

    }

EnableSatisfyDependenciesOnly()
    {

    satisfy_dependencies_only=true
    DebugVar satisfy_dependencies_only

    }

DisableSatisfyDependenciesOnly()
    {

    satisfy_dependencies_only=false
    DebugVar satisfy_dependencies_only

    }

IsSatisfyDependenciesOnly()
    {

    [[ $satisfy_dependencies_only = true ]]

    }

EnableDebugMode()
    {

    debug_mode=true
    DebugVar debug_mode

    }

DisableDebugMode()
    {

    debug_mode=false
    DebugVar debug_mode

    }

IsDebugMode()
    {

    [[ $debug_mode = true ]]

    }

IsNotDebugMode()
    {

    [[ $debug_mode != true ]]

    }

EnableDevMode()
    {

    EnableDebugMode

    dev_mode=true
    DebugVar dev_mode

    }

IsDevMode()
    {

    [[ $dev_mode = true ]]

    }

IsNotDevMode()
    {

    [[ $dev_mode != true ]]

    }

EnableSuggestIssue()
    {

    suggest_issue=true
    DebugVar suggest_issue

    }

DisableSuggestIssue()
    {

    suggest_issue=false
    DebugVar suggest_issue

    }

IsSuggestIssue()
    {

    [[ $suggest_issue = true ]]

    }

ConvertSecsToMinutes()
    {

    # http://stackoverflow.com/questions/12199631/convert-seconds-to-hours-minutes-seconds
    # $1 = a time in seconds to convert to 'hh:mm:ss'

    ((h=${1}/3600))
    ((m=(${1}%3600)/60))
    ((s=${1}%60))

    printf "%02dh:%02dm:%02ds\n" $h $m $s

    }

FormatAsISO()
    {

    echo "$1" | $AWK_CMD 'BEGIN{ u[0]="B"; u[1]="kB"; u[2]="MB"; u[3]="GB"} { n = $1; i = 0; while(n > 1000) { i+=1; n= int((n/1000)+0.5) } print n u[i] } '

    }

FormatAsPackageName()
    {

    [[ -z $1 ]] && return 1

    echo "'$1'"

    }

FormatAsFileName()
    {

    [[ -z $1 ]] && return 1

    echo "($1)"

    }

FormatAsCommand()
    {

    [[ -z $1 ]] && return 1

    echo "= command: '$1'"

    }

FormatAsStdout()
    {

    [[ -z $1 ]] && return 1

    echo "= stdout begins next line:"
    echo "$1"
    echo "= stdout complete."

    }

FormatAsExitcode()
    {

    [[ -z $1 ]] && return 1

    echo "[$1]"

    }

FormatAsResult()
    {

    [[ -z $1 ]] && return 1

    if [[ $1 -eq 0 ]]; then
        echo "= result: $(FormatAsExitcode "$1")"
    else
        echo "! result: $(FormatAsExitcode "$1")"
    fi

    }

DebugInfoThickSeparator()
    {

    DebugInfo "$(printf '%0.s=' {1..72})"

    }

DebugInfoThinSeparator()
    {

    DebugInfo "$(printf '%0.s-' {1..72})"

    }

DebugErrorThinSeparator()
    {

    DebugError "$(printf '%0.s-' {1..72})"

    }

DebugLogThinSeparator()
    {

    DebugLog "$(printf '%0.s-' {1..72})"

    }

DebugStageStart()
    {

    # stdout = current time in seconds

    $DATE_CMD +%s
    DebugInfoThinSeparator
    DebugStage 'start stage timer'

    }

DebugStageEnd()
    {

    # $1 = start time in seconds

    DebugStage 'elapsed time' "$(ConvertSecsToMinutes "$(($($DATE_CMD +%s)-$([[ -n $1 ]] && echo "$1" || echo "1")))")"
    DebugInfoThinSeparator

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

    DebugThis "(>>) ${FUNCNAME[1]}()"

    }

DebugFuncExit()
    {

    DebugThis "(<<) ${FUNCNAME[1]}() [$errorcode]"

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

    if [[ -z $3 ]]; then
        DebugThis "(**) $(printf "%-6s: %19s\n" "$1" "$2")"
    else
        DebugThis "(**) $(printf "%-6s: %19s: %-s\n" "$1" "$2" "$3")"
    fi

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

    DebugThis "(vv) \$$1 [${!1}]"

    }

DebugThis()
    {

    IsDebugMode && ShowDebug "$1"
    WriteAsDebug "$1"

    }

DebugErrorFile()
    {

    # add the contents of specified pathfile $1 to the main runtime log

    [[ -z $1 || ! -e $1 ]] && return 1

    local linebuff=''

    DebugLogThinSeparator
    DebugLog "$1"
    DebugLogThinSeparator

    while read -r linebuff; do
        DebugLog "$linebuff"
    done < "$1"

    DebugLogThinSeparator

    }

ShowInfo()
    {

    WriteToDisplay_SameLine "$(ColourTextBrightWhite info)" "$1"
    WriteToLog info "$1"

    }

ShowProc()
    {

    WriteToDisplay_SameLine "$(ColourTextBrightOrange proc)" "$1 ..."
    WriteToLog proc "$1 ..."

    }

ShowProcLong()
    {

    ShowProc "$1 - this can take a while"

    }

ShowDebug()
    {

    WriteToDisplay_SameLine "$(ColourTextBlackOnCyan dbug)" "$1"

    }

ShowNote()
    {

    WriteToDisplay_NewLine "$(ColourTextBrightYellowBlink note)" "$1"
    WriteToLog note "$1"

    }

ShowQuiz()
    {

    WriteToDisplay_SameLine "$(ColourTextBrightYellow quiz)" "$1: "
    WriteToLog quiz "$1"

    }

ShowDone()
    {

    WriteToDisplay_NewLine "$(ColourTextBrightGreen done)" "$1"
    WriteToLog done "$1"

    }

ShowWarning()
    {

    WriteToDisplay_NewLine "$(ColourTextBrightOrange warn)" "$1"
    WriteToLog warn "$1"

    }

ShowError()
    {

    local buffer="$1"
    local capitalised="$(tr "[a-z]" "[A-Z]" <<< ${buffer:0:1})${buffer:1}"      # use any available 'tr' command as we haven't picked one yet

    WriteToDisplay_NewLine "$(ColourTextBrightRed fail)" "$capitalised"
    WriteToLog fail "$capitalised"

    }

WriteAsDebug()
    {

    WriteToLog dbug "$1"

    }

WriteToDisplay_SameLine()
    {

    # writes a new message without newline (unless in debug mode)

    # $1 = pass/fail
    # $2 = message

    previous_msg=$(printf "[ %-10s ] %s" "$1" "$2")

    echo -n "$previous_msg"; IsDebugMode && echo

    return 0

    }

WriteToDisplay_NewLine()
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

WriteToLog()
    {

    # $1 = pass/fail
    # $2 = message

    [[ -n $DEBUG_LOG_PATHFILE ]] && $TOUCH_CMD "$DEBUG_LOG_PATHFILE" && printf "[ %-4s ] %s\n" "$1" "$2" >> "$DEBUG_LOG_PATHFILE"

    }

ColourTextBrightGreen()
    {

    echo -en '\033[1;32m'"$(PrintResetColours "$1")"

    }

ColourTextBrightYellow()
    {

    echo -en '\033[1;33m'"$(PrintResetColours "$1")"

    }

ColourTextBrightYellowBlink()
    {

    echo -en '\033[1;5;33m'"$(PrintResetColours "$1")"

    }

ColourTextBrightOrange()
    {

    echo -en '\033[1;38;5;214m'"$(PrintResetColours "$1")"

    }

ColourTextBrightRed()
    {

    echo -en '\033[1;31m'"$(PrintResetColours "$1")"

    }

ColourTextUnderlinedBlue()
    {

    echo -en '\033[4;94m'"$(PrintResetColours "$1")"

    }

ColourTextBlackOnCyan()
    {

    echo -en '\033[30;46m'"$(PrintResetColours "$1")"

    }

ColourTextBrightWhite()
    {

    echo -en '\033[1;97m'"$(PrintResetColours "$1")"

    }

PrintResetColours()
    {

    echo -en "$1"'\033[0m'

    }

if [[ ! -e /etc/init.d/functions ]]; then
    ShowError 'QTS functions missing. Is this a QNAP NAS?'
    exit 1
fi

Init || exit
LogRuntimeParameters
DownloadQPKGs
RemoveUnwantedQPKGs
InstallBase
InstallBaseAddons
InstallTargetQPKG
Cleanup
ShowResult

exit $errorcode
