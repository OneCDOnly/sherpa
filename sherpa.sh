#!/usr/bin/env bash
####################################################################################
# sherpa.sh
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
####################################################################################
# * Style Guide *
# function names: CamelCase
# variable names: lowercase_with_underscores (except for 'returncode' & 'errorcode')
# constants: UPPERCASE_WITH_UNDERSCORES
# indents: 1 x tab (= 4 x spaces)
####################################################################################

USER_ARGS_RAW="$@"

ResetErrorcode()
    {

    errorcode=0

    }

Init()
    {

    SCRIPT_FILE=sherpa.sh
    SCRIPT_VERSION=200323
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

    CURL_CMD=/sbin/curl
    GETCFG_CMD=/sbin/getcfg
    RMCFG_CMD=/sbin/rmcfg
    SERVICE_CMD=/sbin/qpkg_service
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

    ZIP_CMD=/usr/local/sbin/zip

    FIND_CMD=/opt/bin/find
    OPKG_CMD=/opt/bin/opkg
    pip2_cmd=/opt/bin/pip2
    pip3_cmd=/opt/bin/pip3

    # paths and files
    APP_CENTER_CONFIG_PATHFILE=/etc/config/qpkg.conf
    INSTALL_LOG_FILE=install.log
    DOWNLOAD_LOG_FILE=download.log
    START_LOG_FILE=start.log
    STOP_LOG_FILE=stop.log
    RESTART_LOG_FILE=restart.log
    DEFAULT_SHARES_PATHFILE=/etc/config/def_share.info
    ULINUX_PATHFILE=/etc/config/uLinux.conf
    local DEBUG_LOG_FILE=${SCRIPT_FILE%.*}.debug.log

    # check required binaries are present
    IsSysFilePresent $AWK_CMD || return 1
    IsSysFilePresent $CAT_CMD || return 1
    IsSysFilePresent $CHMOD_CMD || return 1
    IsSysFilePresent $DATE_CMD || return 1
    IsSysFilePresent $GREP_CMD || return 1
    IsSysFilePresent $HOSTNAME_CMD || return 1
    IsSysFilePresent $LN_CMD || return 1
    IsSysFilePresent $MD5SUM_CMD || return 1
    IsSysFilePresent $MKDIR_CMD || return 1
    IsSysFilePresent $PING_CMD || return 1
    IsSysFilePresent $SED_CMD || return 1
    IsSysFilePresent $SLEEP_CMD || return 1
    IsSysFilePresent $TOUCH_CMD || return 1
    IsSysFilePresent $TR_CMD || return 1
    IsSysFilePresent $UNAME_CMD || return 1
    IsSysFilePresent $UNIQ_CMD || return 1

    IsSysFilePresent $CURL_CMD || return 1
    IsSysFilePresent $GETCFG_CMD || return 1
    IsSysFilePresent $RMCFG_CMD || return 1
    IsSysFilePresent $SERVICE_CMD || return 1
    IsSysFilePresent $SETCFG_CMD || return 1

    IsSysFilePresent $BASENAME_CMD || return 1
    IsSysFilePresent $CUT_CMD || return 1
    IsSysFilePresent $DIRNAME_CMD || return 1
    IsSysFilePresent $DU_CMD || return 1
    IsSysFilePresent $HEAD_CMD || return 1
    IsSysFilePresent $READLINK_CMD || return 1
    IsSysFilePresent $SORT_CMD || return 1
    IsSysFilePresent $TAIL_CMD || return 1
    IsSysFilePresent $TEE_CMD || return 1
    IsSysFilePresent $UNZIP_CMD || return 1
    IsSysFilePresent $UPTIME_CMD || return 1
    IsSysFilePresent $WC_CMD || return 1

    IsSysFilePresent $ZIP_CMD || return 1

    local DEFAULT_SHARE_DOWNLOAD_PATH=/share/Download
    local DEFAULT_SHARE_PUBLIC_PATH=/share/Public

    # check required system paths are present
    if [[ -L $DEFAULT_SHARE_DOWNLOAD_PATH ]]; then
        SHARE_DOWNLOAD_PATH=$DEFAULT_SHARE_DOWNLOAD_PATH
    else
        SHARE_DOWNLOAD_PATH=/share/$($GETCFG_CMD SHARE_DEF defDownload -d Qdownload -f $DEFAULT_SHARES_PATHFILE)
        IsSysSharePresent "$SHARE_DOWNLOAD_PATH" || return 1
    fi

    if [[ -L $DEFAULT_SHARE_PUBLIC_PATH ]]; then
        SHARE_PUBLIC_PATH=$DEFAULT_SHARE_PUBLIC_PATH
    else
        SHARE_PUBLIC_PATH=/share/$($GETCFG_CMD SHARE_DEF defPublic -d Qpublic -f $DEFAULT_SHARES_PATHFILE)
        IsSysSharePresent "$SHARE_PUBLIC_PATH" || return 1
    fi

    # sherpa-supported package details - parallel arrays
    SHERPA_QPKG_NAME=()         # internal QPKG name
        SHERPA_QPKG_ARCH=()     # QPKG supports this architecture
        SHERPA_QPKG_URL=()      # remote QPKG URL available for download
        SHERPA_QPKG_MD5=()      # remote QPKG MD5
        SHERPA_QPKG_ABBRVS=()   # if set, this package is user-installable, and these abbreviations can be used to specify app
        SHERPA_QPKG_DEPS=()     # this QPKG requires these QPKGs to be installed first
        SHERPA_QPKG_IPKGS=()    # this QPKG requires these IPKGs to be installed first
        SHERPA_QPKG_PIP2S=()    # this QPKG requires these PIPs for Python 2 to be installed first
        SHERPA_QPKG_PIP3S=()    # this QPKG requires these PIPs for Python 3 to be installed first

    SHERPA_QPKG_NAME+=(Entware)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=(http://bin.entware.net/other/Entware_1.02std.qpkg)
        SHERPA_QPKG_MD5+=(dbc82469933ac3049c06d4c8a023bbb9)
        SHERPA_QPKG_ABBRVS+=('opkg ew ent entware')
        SHERPA_QPKG_DEPS+=('')
        SHERPA_QPKG_IPKGS+=('')
        SHERPA_QPKG_PIP2S+=('')
        SHERPA_QPKG_PIP3S+=('')

    SHERPA_QPKG_NAME+=(SABnzbdplus)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/sherpa/master/QPKGs/SABnzbdplus/build/SABnzbdplus_200223.qpkg)
        SHERPA_QPKG_MD5+=(e2ae9ad26e48b4844cdf3ac54955de73)
        SHERPA_QPKG_ABBRVS+=('sb sab sabnzbd sabnzbdplus')
        SHERPA_QPKG_DEPS+=('Entware Par2')
        SHERPA_QPKG_IPKGS+=('python python-pyopenssl python-dev gcc unrar p7zip coreutils-nice ionice ffprobe')
        SHERPA_QPKG_PIP2S+=('sabyenc==3.3.5 cheetah')
        SHERPA_QPKG_PIP3S+=('')

    SHERPA_QPKG_NAME+=(NZBGet)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/sherpa/master/QPKGs/NZBGet/build/NZBGet_190928.qpkg)
        SHERPA_QPKG_MD5+=(baf83cda1c3f44eea6c63a53c88b03ad)
        SHERPA_QPKG_ABBRVS+=('ng nget nzb nzbget')
        SHERPA_QPKG_DEPS+=('Entware')
        SHERPA_QPKG_IPKGS+=('nzbget')
        SHERPA_QPKG_PIP2S+=('')
        SHERPA_QPKG_PIP3S+=('')

    SHERPA_QPKG_NAME+=(SickChill)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/sherpa/master/QPKGs/SickChill/build/SickChill_190928.qpkg)
        SHERPA_QPKG_MD5+=(b690b5815d542936436efac3dc442840)
        SHERPA_QPKG_ABBRVS+=('sc sick sickc chill sickchill')
        SHERPA_QPKG_DEPS+=('Entware')
        SHERPA_QPKG_IPKGS+=('python')
        SHERPA_QPKG_PIP2S+=('')
        SHERPA_QPKG_PIP3S+=('')

    SHERPA_QPKG_NAME+=(LazyLibrarian)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/sherpa/master/QPKGs/LazyLibrarian/build/LazyLibrarian_191105.qpkg)
        SHERPA_QPKG_MD5+=(d06380c0b374f946345ea4087f41a9cf)
        SHERPA_QPKG_ABBRVS+=('ll lazy lazylibrarian')
        SHERPA_QPKG_DEPS+=('Entware')
        SHERPA_QPKG_IPKGS+=('python3-pyopenssl python3-requests')
        SHERPA_QPKG_PIP2S+=('')
        SHERPA_QPKG_PIP3S+=('python-magic')

    SHERPA_QPKG_NAME+=(OMedusa)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/sherpa/master/QPKGs/OMedusa/build/OMedusa_200216.qpkg)
        SHERPA_QPKG_MD5+=(c8e6ec6b711ee785a11994502b802989)
        SHERPA_QPKG_ABBRVS+=('om med omed medusa omedusa')
        SHERPA_QPKG_DEPS+=('Entware')
        SHERPA_QPKG_IPKGS+=('python3 mediainfo')
        SHERPA_QPKG_PIP2S+=('')
        SHERPA_QPKG_PIP3S+=('')

    SHERPA_QPKG_NAME+=(OWatcher3)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/sherpa/master/QPKGs/OWatcher3/build/OWatcher3_191105.qpkg)
        SHERPA_QPKG_MD5+=(b84af7b6bfec6e83ce19a73da1803710)
        SHERPA_QPKG_ABBRVS+=('ow wat owat watch watcher owatcher watcher3 owatcher3')
        SHERPA_QPKG_DEPS+=('Entware')
        SHERPA_QPKG_IPKGS+=('jq')
        SHERPA_QPKG_PIP2S+=('')
        SHERPA_QPKG_PIP3S+=('')

    SHERPA_QPKG_NAME+=(Headphones)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/sherpa/master/QPKGs/Headphones/build/Headphones_190928.qpkg)
        SHERPA_QPKG_MD5+=(3e01dd9c44bcab287f6f105caabd816d)
        SHERPA_QPKG_ABBRVS+=('hp head phones headphones')
        SHERPA_QPKG_DEPS+=('Entware')
        SHERPA_QPKG_IPKGS+=('python')
        SHERPA_QPKG_PIP2S+=('')
        SHERPA_QPKG_PIP3S+=('')

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
        SHERPA_QPKG_ARCH+=(x41)
        SHERPA_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/sherpa/master/QPKGs/Par2/Par2_0.8.1.0_arm-x41.qpkg)
        SHERPA_QPKG_MD5+=(8516e45e704875cdd2cd2bb315c4e1e6)
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
        SHERPA_QPKG_ARCH+=(a64)
        SHERPA_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/sherpa/master/QPKGs/Par2/Par2_0.8.1.0_arm_64.qpkg)
        SHERPA_QPKG_MD5+=(4d8e99f97936a163e411aa8765595f7a)
        SHERPA_QPKG_ABBRVS+=('')
        SHERPA_QPKG_DEPS+=('')
        SHERPA_QPKG_IPKGS+=('')
        SHERPA_QPKG_PIP2S+=('')
        SHERPA_QPKG_PIP3S+=('')

    SHERPA_COMMON_IPKGS='git git-http nano less ca-certificates python-pip python3-pip'
#     SHERPA_COMMON_PIP2S='--upgrade pip setuptools'
#     SHERPA_COMMON_PIP3S='--upgrade pip setuptools'
    SHERPA_COMMON_PIP2S='--disable-pip-version-check --upgrade setuptools'
    SHERPA_COMMON_PIP3S='--disable-pip-version-check --upgrade setuptools'
    SHERPA_COMMON_CONFLICTS='Optware Optware-NG'

    # user-specified as arguments at runtime
    QPKGS_to_install=()
    QPKGS_to_uninstall=()
    QPKGS_to_reinstall=()
    QPKGS_to_update=()
    QPKGS_to_backup=()
    QPKGS_to_restore=()

    PREV_QPKG_CONFIG_DIRS=(SAB_CONFIG CONFIG Config config)                 # last element is used as target dirname
    PREV_QPKG_CONFIG_FILES=(sabnzbd.ini settings.ini config.cfg config.ini) # last element is used as target filename
    WORKING_PATH=$SHARE_PUBLIC_PATH/${SCRIPT_FILE%.*}.tmp
    DEBUG_LOG_PATHFILE=$SHARE_PUBLIC_PATH/$DEBUG_LOG_FILE
    SHERPA_PACKAGES_PATHFILE=$WORKING_PATH/packages.conf
    QPKG_DL_PATH=$WORKING_PATH/qpkg-downloads
    IPKG_DL_PATH=$WORKING_PATH/ipkg-downloads
    IPKG_CACHE_PATH=$WORKING_PATH/ipkg-cache

    # internals
    SCRIPT_STARTSECONDS=$($DATE_CMD +%s)
    NAS_FIRMWARE=$($GETCFG_CMD System Version -f $ULINUX_PATHFILE)
    NAS_ARCH=$($UNAME_CMD -m)
    progress_message=''
    previous_length=0
    previous_msg=''
    reinstall_flag=false
    satisfy_dependencies_only=false
    ignore_space_arg=''
    update_all_apps=false
    backup_all_apps=false
    restore_all_apps=false
    [[ ${NAS_FIRMWARE//.} -lt 426 ]] && curl_insecure_arg='--insecure' || curl_insecure_arg=''

    return 0

    }

LogNASDetails()
    {

    local conflicting_qpkg=''
    local test_pathfile=/opt/etc/passwd

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
    DebugNAS 'model' "$($GREP_CMD -v "^$" /etc/issue | $SED_CMD 's|^Welcome to ||;s|(.*||')"
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
    DebugNAS "$SHARE_DOWNLOAD_PATH" "$([[ -L $SHARE_DOWNLOAD_PATH ]] && $READLINK_CMD "$SHARE_DOWNLOAD_PATH" || echo "<not present>")"
    DebugScript 'user arguments' "$USER_ARGS_RAW"
    DebugScript 'app(s) to install' "${QPKGS_to_install[*]} "
    DebugScript 'app(s) to uninstall' "${QPKGS_to_uninstall[*]} "
    DebugScript 'app(s) to reinstall' "${QPKGS_to_reinstall[*]} "
    DebugScript 'app(s) to update' "${QPKGS_to_update[*]} "
    DebugScript 'app(s) to backup' "${QPKGS_to_backup[*]} "
    DebugScript 'app(s) to restore' "${QPKGS_to_restore[*]} "
    DebugScript 'working path' "$WORKING_PATH"
    DebugQPKG 'download path' "$QPKG_DL_PATH"
    DebugIPKG 'download path' "$IPKG_DL_PATH"
    CalcNASQPKGArch
    DebugQPKG 'arch' "$NAS_QPKG_ARCH"

    [[ $errorcode -gt 0 ]] && DisplayHelp

    if [[ $errorcode -eq 0 ]] && [[ $EUID -ne 0 || $USER != admin ]]; then
        ShowError "this script must be run as the 'admin' user. Please login via SSH as 'admin' and try again."
        errorcode=1
    fi

    if [[ $errorcode -eq 0 ]]; then
        $MKDIR_CMD -p "$WORKING_PATH" 2> /dev/null
        result=$?

        if [[ $result -ne 0 ]]; then
            ShowError "unable to create working directory ($WORKING_PATH) [$result]"
            errorcode=2
        else
            cd "$WORKING_PATH"
        fi
    fi

    if [[ $errorcode -eq 0 ]]; then
        $MKDIR_CMD -p "$QPKG_DL_PATH" 2> /dev/null
        result=$?

        if [[ $result -ne 0 ]]; then
            ShowError "unable to create QPKG download directory ($QPKG_DL_PATH) [$result]"
            errorcode=3
        fi
    fi

    if [[ $errorcode -eq 0 ]]; then
        [[ -d $IPKG_DL_PATH ]] && rm -r "$IPKG_DL_PATH"
        $MKDIR_CMD -p "$IPKG_DL_PATH" 2> /dev/null
        result=$?

        if [[ $result -ne 0 ]]; then
            ShowError "unable to create IPKG download directory ($IPKG_DL_PATH) [$result]"
            errorcode=4
        else
            monitor_flag="$IPKG_DL_PATH/.monitor"
        fi
    fi

    if [[ $errorcode -eq 0 ]]; then
        $MKDIR_CMD -p "$IPKG_CACHE_PATH" 2> /dev/null
        result=$?

        if [[ $result -ne 0 ]]; then
            ShowError "unable to create IPKG cache directory ($IPKG_CACHE_PATH) [$result]"
            errorcode=5
        fi
    fi

    if [[ $errorcode -eq 0 ]]; then
        for conflicting_qpkg in ${SHERPA_COMMON_CONFLICTS[@]}; do
            if IsQPKGEnabled $conflicting_qpkg; then
                ShowError "'$conflicting_qpkg' is enabled. This is an unsupported configuration."
                errorcode=6
            fi
        done
    fi

    if [[ $errorcode -eq 0 ]]; then
        if IsQPKGInstalled Entware; then
            [[ -e $test_pathfile ]] && { [[ -L $test_pathfile ]] && ENTWARE_VER=std || ENTWARE_VER=alt ;} || ENTWARE_VER=none
            DebugQPKG 'Entware installer' $ENTWARE_VER

            if [[ $ENTWARE_VER = none ]]; then
                ShowError 'Entware appears to be installed but is not visible.'
                errorcode=7
            fi
        fi
    fi

    if [[ $errorcode -eq 0 ]]; then
        ShowProc "testing Internet access"

        if ($CURL_CMD $curl_insecure_arg --silent --fail https://onecdonly.github.io/sherpa/packages.conf -o $SHERPA_PACKAGES_PATHFILE); then
            ShowDone "Internet is accessible"
        else
            ShowError "no Internet access"
            errorcode=8
        fi
    fi

    DebugInfoThinSeparator
    DebugFuncExit
    return 0

    }

ParseArgs()
    {

    local target_app=''
    local current_operation=''

    if [[ -z $USER_ARGS_RAW ]]; then
        errorcode=9
        return 1
    else
        local user_args=($(echo "$USER_ARGS_RAW" | $TR_CMD '[A-Z]' '[a-z]'))
    fi

    for arg in ${user_args[@]}; do
        case $arg in
            -d|--debug)
                debug=true
                DebugVar debug
                current_operation=''
                ;;
            --check-all)
                satisfy_dependencies_only=true
                DebugVar satisfy_dependencies_only
                current_operation=''
                ;;
            --ignore-space)
                ignore_space_arg='--force-space'
                DebugVar ignore_space_arg
                current_operation=''
                ;;
            --help)
                errorcode=10
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

    TARGET_APP=${QPKGS_to_install[0]}           # keep for compatibility until multi-package rollout is ready

    [[ ${#QPKGS_to_install[@]} -eq 0 && ${#QPKGS_to_uninstall[@]} -eq 0 && ${#QPKGS_to_update[@]} -eq 0 && ${#QPKGS_to_backup[@]} -eq 0 && ${#QPKGS_to_restore[@]} -eq 0 && $satisfy_dependencies_only = false && $update_all_apps = false ]] && errorcode=11
    [[ $backup_all_apps = true && $restore_all_apps = true ]] && errorcode=12               # no-point performing both operations
    return 0

    }

DisplayHelp()
    {

    DebugFuncEntry
    local package=''

    echo -e "* A BASH script to install various Usenet apps into a QNAP NAS.\n"

    echo "- Each application shown below can be installed (or reinstalled) by running:"
    for package in ${SHERPA_QPKG_NAME[@]}; do
        (IsQPKGUserInstallable $package) && echo -e "\t$0 $package"
    done

    echo -e "\n- Ensure all sherpa application dependencies are installed:"
    echo -e "\t$0 --check-all"

    echo -e "\n- Don't check free-space on target filesystem when installing Entware packages:"
    echo -e "\t$0 --ignore-space"

    echo -e "\n- Update all sherpa installed applications:"
    echo -e "\t$0 --update-all"
    echo

    DebugFuncExit
    return 0

    }

DownloadQPKGs()
    {

    [[ $errorcode -gt 0 ]] && return

    DebugFuncEntry
    local returncode=0

    # check user specified install list and built a temp list of QPKGs to install (temp QPKG install list).
    # loop through sherpa QPKG installable list and if names matches entry in temp QPKG install list then:
    #   add package name to final QPKG install list,
    #   add package deps to final QPKG install list,
    #   remove duplicates and installed packages from final QPKG install list.
    # loop through final QPKG install list and if sherpa installable package index matches then:
    #   add package ipks to final IPK install list.

    ! IsQPKGInstalled Entware && DownloadQPKG Entware

    { (IsQPKGInstalled SABnzbdplus) || [[ $TARGET_APP = SABnzbdplus ]] ;} && [[ $NAS_QPKG_ARCH != none ]] && ! IsQPKGInstalled Par2 && DownloadQPKG Par2

    [[ -n $TARGET_APP ]] && DownloadQPKG $TARGET_APP

    DebugFuncExit
    return $returncode

    }

RemoveUnwantedQPKGs()
    {

    [[ $errorcode -gt 0 ]] && return

    DebugFuncEntry

    UninstallQPKG Optware || ResetErrorcode  # ignore Optware uninstall errors
    UninstallQPKG Entware-3x
    UninstallQPKG Entware-ng

    IsQPKGInstalled $TARGET_APP && reinstall_flag=true

    [[ $TARGET_APP = Entware ]] && UninstallQPKG Entware

    DebugFuncExit
    return 0

    }

InstallBase()
    {

    [[ $errorcode -gt 0 ]] && return

    DebugFuncEntry
    local returncode=0

    if ! IsQPKGInstalled Entware; then
        # rename original [/opt]
        opt_path=/opt
        opt_backup_path=/opt.orig
        [[ -d $opt_path && ! -L $opt_path && ! -e $opt_backup_path ]] && mv "$opt_path" "$opt_backup_path"

        InstallQPKG Entware && ReloadProfile

        # copy all files from original [/opt] into new [/opt]
        [[ -L $opt_path && -d $opt_backup_path ]] && cp --recursive "$opt_backup_path"/* --target-directory "$opt_path" && rm -r "$opt_backup_path"
    else
        ! IsQPKGEnabled Entware && EnableQPKG Entware
        ReloadProfile

        [[ $NAS_QPKG_ARCH != none ]] && ($OPKG_CMD list-installed | $GREP_CMD -q par2cmdline) && $OPKG_CMD remove par2cmdline > /dev/null 2>&1
    fi

    PatchBaseInit

    DebugFuncExit
    return $returncode

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

    DebugFuncEntry
    local package_list_file=/opt/var/opkg-lists/entware
    local package_list_age=60
    local result=0
    local log_pathfile="$WORKING_PATH/entware-update.log"

    IsSysFilePresent $OPKG_CMD || return 1
    IsSysFilePresent $FIND_CMD || return 1

    # if Entware package list was updated only recently, don't run another update
    [[ -e $FIND_CMD && -e $package_list_file ]] && result=$($FIND_CMD "$package_list_file" -mmin +$package_list_age) || result='new install'

    if [[ -n $result ]]; then
        ShowProc 'updating Entware package list'

        install_msgs=$($OPKG_CMD update 2>&1)
        result=$?
        echo -e "${install_msgs}\nresult=[$result]" >> "$log_pathfile"

        if [[ $result -eq 0 ]]; then
            ShowDone 'updated Entware package list'
        else
            ShowWarning "Unable to update Entware package list [$result]"
            DebugErrorFile "$log_pathfile"
            # meh, continue anyway with old list ...
        fi
    else
        DebugInfo "Entware package list was updated less than $package_list_age minutes ago"
        ShowDone 'Entware package list is up-to-date'
    fi

    DebugFuncExit
    return 0

    }

InstallBaseAddons()
    {

    [[ $errorcode -gt 0 ]] && return

    DebugFuncEntry

    if { (IsQPKGInstalled SABnzbdplus) || [[ $TARGET_APP = SABnzbdplus ]] ;} && [[ $NAS_QPKG_ARCH != none ]]; then
        if ! IsQPKGInstalled Par2; then
            InstallQPKG Par2
            if [[ $errorcode -gt 0 ]]; then
                ShowWarning "Par2 installation failed - but it's not essential so I'm continuing"
                ResetErrorcode
                DebugVar errorcode
            fi
        fi
    fi

    InstallIPKGs
    InstallPIP2s
#     InstallPIP3s

    [[ $TARGET_APP = Entware || $update_all_apps = true ]] && RestartAllQPKGs

    DebugFuncExit
    return 0

    }

InstallTargetQPKG()
    {

    [[ $errorcode -gt 0 || -z $TARGET_APP ]] && return

    DebugFuncEntry

    [[ $TARGET_APP != Entware ]] && InstallQPKG $TARGET_APP

    DebugFuncExit
    return 0

    }

InstallIPKGs()
    {

    [[ $errorcode -gt 0 ]] && return

    DebugFuncEntry
    local returncode=0
    local install_msgs=''
    local packages="$SHERPA_COMMON_IPKGS"
    local index=0

    if [[ -n $IPKG_DL_PATH && -d $IPKG_DL_PATH ]]; then
        UpdateEntware
        for index in ${!SHERPA_QPKG_NAME[@]}; do
            if (IsQPKGInstalled ${SHERPA_QPKG_NAME[$index]}) || [[ $TARGET_APP = ${SHERPA_QPKG_NAME[$index]} ]]; then
                packages+=" ${SHERPA_QPKG_IPKGS[$index]}"
            fi
        done

        if (IsQPKGInstalled SABnzbdplus) || [[ $TARGET_APP = SABnzbdplus ]]; then
            [[ $NAS_QPKG_ARCH = none ]] && packages+=' par2cmdline'
        fi

        InstallIPKGBatch "$packages"
        DowngradePy3
    else
        ShowError "IPKG download path [$IPKG_DL_PATH] does not exist"
        errorcode=13
        returncode=1
    fi

    DebugFuncExit
    return $returncode

    }

InstallIPKGBatch()
    {

    # $1 = space-separated string containing list of IPKG names to download and install

    DebugFuncEntry
    local result=0
    local returncode=0
    local requested_IPKGs=''
    local log_pathfile="$IPKG_DL_PATH/IPKGs.$INSTALL_LOG_FILE"

    [[ -n $1 ]] && requested_IPKGs="$1" || return 1

    # errors can occur due to incompatible IPKGs (tried installing Entware-3x, then Entware-ng), so delete them first
    [[ -d $IPKG_DL_PATH ]] && rm -f "$IPKG_DL_PATH"/*.ipk
    [[ -d $IPKG_CACHE_PATH ]] && rm -f "$IPKG_CACHE_PATH"/*.ipk

    FindAllIPKGDependencies "$requested_IPKGs"

    if [[ $IPKG_download_count -gt 0 ]]; then
        local IPKG_download_startseconds=$(DebugStageStart)
        ShowProc "downloading & installing $IPKG_download_count IPKGs"

        $TOUCH_CMD "$monitor_flag"
        trap CTRL_C_Captured INT
        _MonitorDirSize_ "$IPKG_DL_PATH" $IPKG_download_size &

        install_msgs=$($OPKG_CMD install $ignore_space_arg --force-overwrite ${IPKG_download_list[*]} --cache "$IPKG_CACHE_PATH" --tmp-dir "$IPKG_DL_PATH" 2>&1)
        result=$?

        [[ -e $monitor_flag ]] && { rm "$monitor_flag"; $SLEEP_CMD 2 ;}
        trap - INT
        echo -e "${install_msgs}\nresult=[$result]" > "$log_pathfile"

        if [[ $result -eq 0 ]]; then
            ShowDone "downloaded & installed $IPKG_download_count IPKGs"
        else
            ShowError "download & install IPKGs failed [$result]"
            DebugErrorFile "$log_pathfile"

            errorcode=14
            returncode=1
        fi
        DebugStageEnd $IPKG_download_startseconds
    fi

    DebugFuncExit
    return $returncode

    }

DowngradePy3()
    {

    # Watcher3 isn't presently compatible with Python 3.8.1 so let's force a downgrade to 3.7.4

    (! IsQPKGInstalled OWatcher3) && [[ $TARGET_APP != OWatcher3 ]] && return
    [[ ! -e /opt/bin/python3 ]] && return
    [[ $(/opt/bin/python3 -V | $SED_CMD 's|[^0-9]*||g') -le 374 ]] && return

    DebugFuncEntry

    [[ -d $IPKG_DL_PATH ]] && rm -f "$IPKG_DL_PATH"/*.ipk

    local source_url=$($GREP_CMD 'http://' /opt/etc/opkg.conf | $SED_CMD 's|^.*\(http://\)|\1|')
    local pkg_base=python3
    local pkg_names=(asyncio base cgi cgitb codecs ctypes dbm decimal dev distutils email gdbm lib2to3 light logging lzma multiprocessing ncurses openssl pydoc sqlite3 unittest urllib xml)
    local pkg_version=3.7.4-2
    local pkg_arch=$($BASENAME_CMD $source_url | $SED_CMD 's|\-k|\-|;s|sf\-|\-|')
    local pkg_name=''
    local ipkg_urls=()
    local dl_log_pathfile="$IPKG_DL_PATH/IPKGs.$DOWNLOAD_LOG_FILE"
    local install_log_pathfile="$IPKG_DL_PATH/IPKGs.$INSTALL_LOG_FILE"

    ShowProc "downgrading to Python $pkg_version"

    for pkg_name in ${pkg_names[@]}; do
        ipkg_urls+=(-O "${source_url}/archive/${pkg_base}-${pkg_name}_${pkg_version}_${pkg_arch}.ipk")
    done

    # and this package too
    ipkg_urls+=(-O "${source_url}/archive/${pkg_base}_${pkg_version}_${pkg_arch}.ipk")

    (cd "$IPKG_DL_PATH" && $CURL_CMD $curl_insecure_arg ${ipkg_urls[@]} >> "$dl_log_pathfile" 2>&1)

    install_msgs=$($OPKG_CMD install --force-downgrade "$IPKG_DL_PATH"/*.ipk 2>&1)
    result=$?
    echo -e "${install_msgs}\nresult=[$result]" > "$install_log_pathfile"

    ShowDone "downgraded to Python $pkg_version"

    DebugFuncExit
    return $returncode

    }

InstallPIP2s()
    {

    [[ $errorcode -gt 0 ]] && return

    DebugFuncEntry
    local install_cmd=''
    local install_msgs=''
    local result=0
    local returncode=0
    local packages=''
    local log_pathfile="$WORKING_PATH/PIP2-modules.$INSTALL_LOG_FILE"

    # sometimes, OpenWRT 'pip' is for Py3, so let's prefer a Py2 version
    if [[ -e /opt/bin/pip2 ]]; then
        pip2_cmd=/opt/bin/pip2
    elif [[ -e /opt/bin/pip2.7 ]]; then
        pip2_cmd=/opt/bin/pip2.7
    elif [[ -e /opt/bin/pip ]]; then
        pip2_cmd=/opt/bin/pip
    else
        IsSysFilePresent $pip2_cmd || return 1
    fi

    for index in ${!SHERPA_QPKG_NAME[@]}; do
        if (IsQPKGInstalled ${SHERPA_QPKG_NAME[$index]}) || [[ $TARGET_APP = ${SHERPA_QPKG_NAME[$index]} ]]; then
            packages+=" ${SHERPA_QPKG_PIP2S[$index]}"
        fi
    done

    ShowProc "downloading & installing PIP2 modules"

    install_cmd="$pip2_cmd install $SHERPA_COMMON_PIP2S 2>&1"
    [[ -n ${packages// /} ]] && install_cmd+=" && $pip2_cmd install $packages 2>&1"

    install_msgs=$(eval "$install_cmd")
    result=$?
    echo -e "command=[${install_cmd}]\nmessages=[${install_msgs}]\nresult=[$result]" > "$log_pathfile"

    if [[ $result -eq 0 ]]; then
        ShowDone "downloaded & installed PIP2 modules"
    else
        ShowError "download & install PIP2 modules failed [$result]"
        DebugErrorFile "$log_pathfile"

        errorcode=15
        returncode=1
    fi

    DebugFuncExit
    return $returncode

    }

InstallPIP3s()
    {

    [[ $errorcode -gt 0 ]] && return

    DebugFuncEntry
    local install_cmd=''
    local install_msgs=''
    local result=0
    local returncode=0
    local packages=''
    local log_pathfile="$WORKING_PATH/PIP3-modules.$INSTALL_LOG_FILE"

    # sometimes, OpenWRT doesn't have a 'pip3'
    if [[ -e /opt/bin/pip3 ]]; then
        pip3_cmd=/opt/bin/pip3
    elif [[ -e /opt/bin/pip3.8 ]]; then
        pip3_cmd=/opt/bin/pip3.8
    else
        IsSysFilePresent $pip3_cmd || return 1
    fi

    for index in ${!SHERPA_QPKG_NAME[@]}; do
        if (IsQPKGInstalled ${SHERPA_QPKG_NAME[$index]}) || [[ $TARGET_APP = ${SHERPA_QPKG_NAME[$index]} ]]; then
            packages+=" ${SHERPA_QPKG_PIP3S[$index]}"
        fi
    done

    ShowProc "downloading & installing PIP3 modules"

    install_cmd="$pip3_cmd install $SHERPA_COMMON_PIP3S 2>&1"
    [[ -n ${packages// /} ]] && install_cmd+=" && $pip3_cmd install $packages 2>&1"

    install_msgs=$(eval "$install_cmd")
    result=$?
    echo -e "command=[${install_cmd}]\nmessages=[${install_msgs}]\nresult=[$result]" > "$log_pathfile"

    if [[ $result -eq 0 ]]; then
        ShowDone "downloaded & installed PIP3 modules"
    else
        ShowError "download & install PIP3 modules failed [$result]"
        DebugErrorFile "$log_pathfile"

        errorcode=16
        returncode=1
    fi

    DebugFuncExit
    return $returncode

    }

RestartAllQPKGs()
    {

    [[ $errorcode -gt 0 ]] && return

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

    [[ $errorcode -gt 0 || -z $1 ]] && return

    local target_file=''
    local install_msgs=''
    local result=0
    local returncode=0
    local local_pathfile="$(GetQPKGPathFilename $1)"

    if [[ ${local_pathfile##*.} = zip ]]; then
        $UNZIP_CMD -nq "$local_pathfile" -d "$QPKG_DL_PATH"
        local_pathfile="${local_pathfile%.*}"
    fi

    local log_pathfile="$local_pathfile.$INSTALL_LOG_FILE"
    target_file=$($BASENAME_CMD "$local_pathfile")
    ShowProcLong "installing file ($target_file)"
    install_msgs=$(eval sh "$local_pathfile" 2>&1)
    result=$?

    echo -e "${install_msgs}\nresult=[$result]" > "$log_pathfile"

    if [[ $result -eq 0 || $result -eq 10 ]]; then
        ShowDone "installed file ($target_file)"
    else
        ShowError "file installation failed ($target_file) [$result]"
        DebugErrorFile "$log_pathfile"

        errorcode=17
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

    [[ $errorcode -gt 0 || -z $1 ]] && return

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
        if [[ $($MD5SUM_CMD "$local_pathfile" | $CUT_CMD -f1 -d' ') = $remote_filename_md5 ]]; then
            DebugInfo "existing QPKG checksum correct ($local_filename)"
        else
            DebugWarning "existing QPKG checksum incorrect ($local_filename)"
            DebugInfo "deleting file ($local_filename)"
            rm -f "$local_pathfile"
        fi
    fi

    if [[ $errorcode -eq 0 && ! -e $local_pathfile ]]; then
        ShowProc "downloading file ($remote_filename)"

        [[ -e $log_pathfile ]] && rm -f "$log_pathfile"

        # keep this one handy for SOCKS5
        # curl http://entware-3x.zyxmon.org/binaries/other/Entware-3x_1.00std.qpkg --socks5 IP:PORT --output target.qpkg

        if [[ $debug = true ]]; then
            $CURL_CMD $curl_insecure_arg --output "$local_pathfile" "$remote_url" 2>&1 | $TEE_CMD -a "$log_pathfile"
            result=$?
        else
            $CURL_CMD $curl_insecure_arg --output "$local_pathfile" "$remote_url" >> "$log_pathfile" 2>&1
            result=$?
        fi

        echo -e "\nresult=[$result]" >> "$log_pathfile"

        if [[ $result -eq 0 ]]; then
            if [[ $($MD5SUM_CMD "$local_pathfile" | $CUT_CMD -f1 -d' ') = $remote_filename_md5 ]]; then
                ShowDone "downloaded file ($remote_filename)"
            else
                ShowError "downloaded file checksum incorrect ($remote_filename)"
                errorcode=18
                returncode=1
            fi
        else
            ShowError "download failed ($local_pathfile) [$result]"
            DebugErrorFile "$log_pathfile"

            errorcode=19
            returncode=1
        fi
    fi

    DebugFuncExit
    return $returncode

    }

CalcNASQPKGArch()
    {

    # Decide which package arch is suitable for this NAS. This is only needed for Stephane's packages.

    case $NAS_ARCH in
        x86_64)
            [[ ${NAS_FIRMWARE//.} -ge 430 ]] && NAS_QPKG_ARCH=x64 || NAS_QPKG_ARCH=x86
            ;;
        i686|x86)
            NAS_QPKG_ARCH=x86
            ;;
        armv7h)
            NAS_QPKG_ARCH=x31
            ;;
        armv7l)
            NAS_QPKG_ARCH=x41
            ;;
        aarch64)
            NAS_QPKG_ARCH=a64
            ;;
        *)
            NAS_QPKG_ARCH=none
            ;;
    esac

    return 0

    }

LoadInstalledQPKGVars()
    {

    # $1 = load variables for this installed package name

    local package_name=$1
    local returncode=0
    local prev_config_dir=''
    local prev_config_file=''
    local package_settings_pathfile=''
    package_installed_path=''
    package_config_path=''

    if [[ -n $package_name ]]; then
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
            errorcode=20
            returncode=1
        fi
    else
        DebugError 'QPKG name unspecified'
        errorcode=21
        returncode=1
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
        errorcode=22
        returncode=1
    else
        qpkg_installed_path="$($GETCFG_CMD "$1" Install_Path -f "$APP_CENTER_CONFIG_PATHFILE")"
        result=$?

        if [[ $result -eq 0 ]]; then
            if [[ -e $qpkg_installed_path/.uninstall.sh ]]; then
                ShowProc "uninstalling '$1'"

                $qpkg_installed_path/.uninstall.sh > /dev/null
                result=$?

                if [[ $result -eq 0 ]]; then
                    ShowDone "uninstalled '$1'"
                else
                    ShowError "unable to uninstall '$1' [$result]"
                    errorcode=23
                    returncode=1
                fi
            fi

            $RMCFG_CMD "$1" -f "$APP_CENTER_CONFIG_PATHFILE"
        else
            DebugQPKG "'$1'" "not installed [$result]"
        fi
    fi

    return $returncode

    }

QPKGServiceCtl()
    {

    # $1 = action (start|stop|restart)
    # $2 = QPKG name

    # this function is used in-place of [qpkg_service] as the QTS 4.2.6 version does not offer returncodes

    local msgs=''
    local result=0
    local init_pathfile=''

    if [[ -z $1 ]]; then
        DebugError 'action unspecified'
        errorcode=24
        return 1
    elif [[ -z $2 ]]; then
        DebugError 'package unspecified'
        errorcode=25
        return 1
    fi

    init_pathfile=$(GetQPKGServiceFile $2)

    case $1 in
        start)
            ShowProcLong "starting service '$2'"
            msgs=$("$init_pathfile" start)
            result=$?
            echo -e "${msgs}\nresult=[$result]" >> "$qpkg_pathfile.$START_LOG_FILE"

            if [[ $result -eq 0 ]]; then
                ShowDone "started service '$2'"
            else
                ShowWarning "Could not start service '$2' [$result]"
                if [[ $debug = true ]]; then
                    DebugInfoThickSeparator
                    $CAT_CMD "$qpkg_pathfile.$START_LOG_FILE"
                    DebugInfoThickSeparator
                else
                    $CAT_CMD "$qpkg_pathfile.$START_LOG_FILE" >> "$DEBUG_LOG_PATHFILE"
                fi
                errorcode=26
                return 1
            fi
            ;;
        stop)
            ShowProc "stopping service '$2'"
            msgs=$("$init_pathfile" stop)
            result=$?
            echo -e "${msgs}\nresult=[$result]" >> "$qpkg_pathfile.$STOP_LOG_FILE"

            if [[ $result -eq 0 ]]; then
                ShowDone "stopped service '$2'"
            else
                ShowWarning "Could not stop service '$2' [$result]"
                if [[ $debug = true ]]; then
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
            ShowProc "restarting service '$2'"
            msgs=$("$init_pathfile" restart)
            result=$?
            echo -e "${msgs}\nresult=[$result]" >> "$qpkg_pathfile.$RESTART_LOG_FILE"

            if [[ $result -eq 0 ]]; then
                ShowDone "restarted service '$2'"
            else
                ShowWarning "Could not restart service '$2' [$result]"
                if [[ $debug = true ]]; then
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
            DebugError "Unrecognised action ($1)"
            errorcode=27
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

    local output=''
    local returncode=0

    if [[ -z $1 ]]; then
        DebugError 'Package unspecified'
        errorcode=28
        returncode=1
    else
        output=$($GETCFG_CMD $1 Shell -f $APP_CENTER_CONFIG_PATHFILE)

        if [[ -z $output ]]; then
            DebugError "No service file configured for package ($1)"
            errorcode=29
            returncode=1
        elif [[ ! -e $output ]]; then
            DebugError "Package service file not found ($output)"
            errorcode=30
            returncode=1
        fi
    fi

    echo "$output"
    return $returncode

    }

GetQPKGPathFilename()
    {

    # $1 = QPKG name
    # stdout = QPKG local filename
    # $? = 0 if successful, 1 if failed

    local output=''
    local returncode=0

    if [[ -z $1 ]]; then
        DebugError 'Package unspecified'
        errorcode=31
        returncode=1
    else
        output="$QPKG_DL_PATH/$($BASENAME_CMD "$(GetQPKGRemoteURL $1)")"
    fi

    echo "$output"
    return $returncode

    }

GetQPKGRemoteURL()
    {

    # $1 = QPKG name
    # stdout = QPKG remote URL
    # $? = 0 if successful, 1 if failed

    local index=0
    local output=''
    local returncode=1

    if [[ -z $1 ]]; then
        DebugError 'Package unspecified'
        errorcode=32
    else
        for index in ${!SHERPA_QPKG_NAME[@]}; do
            if [[ $1 = ${SHERPA_QPKG_NAME[$index]} ]] && [[ ${SHERPA_QPKG_ARCH[$index]} = all || ${SHERPA_QPKG_ARCH[$index]} = $NAS_QPKG_ARCH ]]; then
                output="${SHERPA_QPKG_URL[$index]}"
                returncode=0
                break
            fi
        done
    fi

    echo "$output"
    return $returncode

    }

GetQPKGMD5()
    {

    # $1 = QPKG name
    # stdout = QPKG MD5
    # $? = 0 if successful, 1 if failed

    local index=0
    local output=''
    local returncode=1

    if [[ -z $1 ]]; then
        DebugError 'Package unspecified'
        errorcode=33
    else
        for index in ${!SHERPA_QPKG_NAME[@]}; do
            if [[ $1 = ${SHERPA_QPKG_NAME[$index]} ]] && [[ ${SHERPA_QPKG_ARCH[$index]} = all || ${SHERPA_QPKG_ARCH[$index]} = $NAS_QPKG_ARCH ]]; then
                output="${SHERPA_QPKG_MD5[$index]}"
                returncode=0
                break
            fi
        done
    fi

    echo "$output"
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

    cd "$SHARE_PUBLIC_PATH"

    [[ $errorcode -eq 0 && $debug != true && -d $WORKING_PATH ]] && rm -rf "$WORKING_PATH"

    DebugFuncExit
    return 0

    }

DisplayResult()
    {

    DebugFuncEntry

    local RE=''
    local suggest_issue=false

    if [[ -n $TARGET_APP ]]; then
        [[ $reinstall_flag = true ]] && RE='re' || RE=''

        if [[ $errorcode -eq 0 ]]; then
            [[ $debug = true ]] && emoticon=':DD' || { emoticon=''; echo ;}

            ShowDone "'$TARGET_APP' has been successfully ${RE}installed! $emoticon"
        elif [[ $errorcode -gt 3 ]]; then       # don't display 'failed' when only showing help
            [[ $debug = true ]] && emoticon=':S ' || { emoticon=''; echo ;}
            ShowError "'$TARGET_APP' ${RE}install failed! ${emoticon}[$errorcode]"
            suggest_issue=true
        fi
    fi

    if [[ $satisfy_dependencies_only = true ]]; then
        if [[ $errorcode -eq 0 ]]; then
            [[ $debug = true ]] && emoticon=':DD' || { emoticon=''; echo ;}
            ShowDone "all application dependencies are installed! $emoticon"
        else
            [[ $debug = true ]] && emoticon=':S ' || { emoticon=''; echo ;}
            ShowError "application dependency check failed! ${emoticon}[$errorcode]"
            suggest_issue=true
        fi
    fi

    if [[ $suggest_issue = true ]]; then
        echo -e "\n* Please consider creating a new issue for this on GitHub:\n\thttps://github.com/OneCDOnly/sherpa/issues"
        echo -e "\n* Alternatively, post on the QNAP NAS Community Forum:\n\thttps://forum.qnap.com/viewtopic.php?f=320&t=132373"
        echo -e "\n* Remember to include a copy of your sherpa runtime debug log for analysis."
    fi

    DebugInfoThinSeparator
    DebugScript 'finished' "$($DATE_CMD)"
    DebugScript 'elapsed time' "$(ConvertSecsToMinutes "$(($($DATE_CMD +%s)-$([[ -n $SCRIPT_STARTSECONDS ]] && echo $SCRIPT_STARTSECONDS || echo "1")))")"
    DebugInfoThickSeparator

    [[ -e $DEBUG_LOG_PATHFILE && $debug = false ]] && echo -e "\n- To display the runtime debug log:\n\tcat $(basename $DEBUG_LOG_PATHFILE)\n"

    DebugFuncExit
    return 0

    }

FindAllIPKGDependencies()
    {

    # From a specified list of IPKG names, find all dependent IPKGs, exclude those already installed, then generate a total qty to download and a total download byte-size.
    # input:
    #   $1 = string with space-separated initial IPKG names.
    # output:
    #   $IPKG_download_list = array with complete list of all IPKGs, including those originally specified.
    #   $IPKG_download_count = number of packages to be downloaded.
    #   $IPKG_download_size = byte-count of packages to be downloaded.

    IPKG_download_size=0
    IPKG_download_count=0
    IPKG_download_list=()
    local requested_list=()
    local last_list=()
    local all_list=()
    local dependency_list=''
    local iterations=0
    local iteration_limit=20
    local complete=false
    local result_size=0
    local IPKG_search_startseconds=$(DebugStageStart)

    [[ -z $1 ]] && { DebugError 'No IPKGs were requested'; return 1 ;}

    IsSysFilePresent $OPKG_CMD || return 1

    # remove duplicate entries
    requested_list=$($TR_CMD ' ' '\n' <<< $1 | $SORT_CMD | $UNIQ_CMD | $TR_CMD '\n' ' ')
    last_list=$requested_list

    ShowProc 'calculating number and total size of IPKGs required'
    DebugInfo "requested IPKGs: ${requested_list[*]}"

    DebugProc 'finding all IPKG dependencies'
    while [[ $iterations -lt $iteration_limit ]]; do
        ((iterations++))
        last_list=$($OPKG_CMD depends -A $last_list | $GREP_CMD -v 'depends on:' | $SED_CMD 's|^[[:blank:]]*||;s|[[:blank:]]*$||' | $TR_CMD ' ' '\n' | $SORT_CMD | $UNIQ_CMD)

        if [[ -n $last_list ]]; then
            [[ -n $dependency_list ]] && dependency_list+=$(echo -e "\n$last_list") || dependency_list=$last_list
        else
            DebugDone 'complete'
            DebugInfo "found all IPKG dependencies in $iterations iterations"
            complete=true
            break
        fi
    done

    [[ $complete = false ]] && DebugError "IPKG dependency list is incomplete! Consider raising \$iteration_limit [$iteration_limit]."

    # remove duplicate entries
    all_list=$(echo "$requested_list $dependency_list" | $TR_CMD ' ' '\n' | $SORT_CMD | $UNIQ_CMD | $TR_CMD '\n' ' ')

    DebugProc 'excluding packages already installed'
    for element in ${all_list[@]}; do
        $OPKG_CMD status "$element" | $GREP_CMD -q "Status:.*installed" || IPKG_download_list+=($element)
    done
    DebugDone 'complete'
    DebugInfo "IPKGs to download: ${IPKG_download_list[*]}"
    IPKG_download_count=${#IPKG_download_list[@]}

    if [[ $IPKG_download_count -gt 0 ]]; then
        DebugProc 'calculating size of IPKGs to download'
        for element in ${IPKG_download_list[@]}; do
            result_size=$($OPKG_CMD info $element | $GREP_CMD -F 'Size:' | $SED_CMD 's|^Size: ||')
            ((IPKG_download_size+=result_size))
        done
        DebugDone 'complete'
    fi
    DebugVar IPKG_download_size
    DebugStageEnd $IPKG_search_startseconds

    if [[ $IPKG_download_count -gt 0 ]]; then
        ShowDone "$IPKG_download_count IPKGs ($(Convert2ISO $IPKG_download_size)) to be downloaded"
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

    local target_dir="$1"
    local total_bytes=$2
    local last_bytes=0
    local stall_seconds=0
    local stall_seconds_threshold=4
    local current_bytes=0
    local percent=''

    IsSysFilePresent $FIND_CMD || return 1

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

        percent="$((200*(current_bytes)/(total_bytes) % 2 + 100*(current_bytes)/(total_bytes)))%"
        progress_message=" $percent ($(Convert2ISO $current_bytes)/$(Convert2ISO $total_bytes))"

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

    [[ -n $progress_message ]] && ProgressUpdater " done!"

    }

EnableQPKG()
    {

    # $1 = package name to enable

    [[ -z $1 ]] && return 1

    if [[ $($GETCFG_CMD "$1" Enable -u -f "$APP_CENTER_CONFIG_PATHFILE") != 'TRUE' ]]; then
        DebugProc "enabling QPKG '$1'"
        $SETCFG_CMD "$1" Enable TRUE -f "$APP_CENTER_CONFIG_PATHFILE"
        DebugDone "QPKG '$1' enabled"
    fi

    }

IsQPKGUserInstallable()
    {

    # input:
    #   $1 = package name to check
    # output:
    #   $? = 0 (true) or 1 (false)

    local returncode=1
    local package_index=0

    [[ -z $1 ]] && return 1
    [[ ${#SHERPA_QPKG_NAME[@]} -eq 0 || ${#SHERPA_QPKG_ABBRVS[@]} -eq 0 ]] && return 1

    for package_index in ${!SHERPA_QPKG_NAME[@]}; do
        if [[ ${SHERPA_QPKG_NAME[$package_index]} = $1 && -n ${SHERPA_QPKG_ABBRVS[$package_index]} ]]; then
            returncode=0
            break
        fi
    done

    return $returncode

    }

IsQPKGInstalled()
    {

    # input:
    #   $1 = package name to check
    # output:
    #   $? = 0 (true) or 1 (false)

    [[ -z $1 ]] && return 1

    if [[ $($GETCFG_CMD "$1" RC_Number -d 0 -f "$APP_CENTER_CONFIG_PATHFILE") -eq 0 ]]; then
        return 1
    else
        return 0
    fi

    }

IsQPKGEnabled()
    {

    # input:
    #   $1 = package name to check
    # output:
    #   $? = 0 (true) or 1 (false)

    [[ -z $1 ]] && return 1

    if [[ $($GETCFG_CMD "$1" Enable -u -f "$APP_CENTER_CONFIG_PATHFILE") != 'TRUE' ]]; then
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

IsSysFilePresent()
    {

    # input:
    #   $1 = pathfile to check
    # output:
    #   $? = 0 (true) or 1 (false)

    [[ -z $1 ]] && return 1

    if ! [[ -f $1 || -L $1 ]]; then
        ShowError "a required NAS system file is missing [$1]"
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
        ShowError "a required NAS system share is missing [$1]. Please re-create it via the QTS Control Panel -> Privilege Settings -> Shared Folders."
        errorcode=35
        return 1
    else
        return 0
    fi

    }

MatchAbbrvToQPKGName()
    {

    # input:
    #   $1 = a potential package abbreviation supplied by user
    # output:
    #   stdout = matched installable package name (empty if unmatched)
    #   $? = 0 (matched) or 1 (unmatched)

    local returncode=1
    local abbs=()
    local package_index=0
    local abb_index=0

    [[ -z $1 ]] && return 1
    [[ ${#SHERPA_QPKG_NAME[@]} -eq 0 || ${#SHERPA_QPKG_ABBRVS[@]} -eq 0 ]] && return 1

    for package_index in ${!SHERPA_QPKG_NAME[@]}; do
        abbs=(${SHERPA_QPKG_ABBRVS[$package_index]})
        for abb_index in ${!abbs[@]}; do
            if [[ ${abbs[$abb_index]} = $1 ]]; then
                echo "${SHERPA_QPKG_NAME[$package_index]}"
                returncode=0
                break 2
            fi
        done
    done

    return $returncode

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

ConvertSecsToMinutes()
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

    echo "$1" | $AWK_CMD 'BEGIN{ u[0]="B"; u[1]="kB"; u[2]="MB"; u[3]="GB"} { n = $1; i = 0; while(n > 1000) { i+=1; n= int((n/1000)+0.5) } print n u[i] } '

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

    [[ $debug = true ]] && ShowDebug "$1"
    SaveDebug "$1"

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

    ShowLogLine_write "$(ColourTextBrightWhite info)" "$1"
    SaveLogLine info "$1"

    }

ShowProc()
    {

    ShowLogLine_write "$(ColourTextBrightOrange proc)" "$1 ..."
    SaveLogLine proc "$1 ..."

    }

ShowProcLong()
    {

    ShowProc "$1 - this can take a while"

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

    local buffer="$1"
    local capitalised="$(tr "[a-z]" "[A-Z]" <<< ${buffer:0:1})${buffer:1}"

    ShowLogLine_update "$(ColourTextBrightRed fail)" "$capitalised"
    SaveLogLine fail "$capitalised"

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

    echo -en '\033[1;32m'"$(PrintResetColours "$1")"

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
    ShowError "QTS functions missing. Is this a QNAP NAS?"
    exit 1
fi

Init || exit
LogNASDetails
DownloadQPKGs
RemoveUnwantedQPKGs
InstallBase
InstallBaseAddons
InstallTargetQPKG
Cleanup
DisplayResult

exit $errorcode
