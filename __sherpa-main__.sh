#!/usr/bin/env bash
#
# __sherpa-main__.sh
#
# This is the management script for the sherpa mini-package-manager.
#
# A BASH script to install various media-management apps into QNAP NAS.
#
# Copyright (C) 2017-2020 OneCD [one.cd.only@gmail.com]
#
# So, blame OneCD if it all goes horribly wrong. ;)
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
# Style Guide:
#         functions: CamelCase
#         variables: lowercase_with_inline_underscores (except for 'returncode')
# "class" variables: _lowercase_with_leading_and_inline_underscores (these should only be managed via their specific functions)
#         constants: UPPERCASE_WITH_INLINE_UNDERSCORES (these are also set as readonly)
#           indents: 1 x tab (converted to 4 x spaces to suit GitHub web-display)
#
# Notes:
#   If on-screen line-spacing is required, this should only be done by the next function that outputs to display.
#   Display functions should never finish by putting an empty line on-screen for spacing.

readonly USER_ARGS_RAW="$*"

Init()
    {

    IsQNAP || return 1

    readonly MANAGER_SCRIPT_VERSION=200905

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
    readonly TAR_CMD=/bin/tar
    readonly TOUCH_CMD=/bin/touch
    readonly TR_CMD=/bin/tr
    readonly UNAME_CMD=/bin/uname
    readonly UNIQ_CMD=/bin/uniq

    readonly CURL_CMD=/sbin/curl
    readonly GETCFG_CMD=/sbin/getcfg
    readonly RMCFG_CMD=/sbin/rmcfg
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

    readonly Z7_CMD=/usr/local/sbin/7z
    readonly ZIP_CMD=/usr/local/sbin/zip

    readonly GNU_FIND_CMD=/opt/bin/find
    readonly GNU_GREP_CMD=/opt/bin/grep
    readonly GNU_LESS_CMD=/opt/bin/less
    readonly GNU_SED_CMD=/opt/bin/sed
    readonly OPKG_CMD=/opt/bin/opkg
    pip3_cmd=/opt/bin/pip3

    # paths and files
    readonly LOADER_SCRIPT_FILE=sherpa.sh
    readonly APP_CENTER_CONFIG_PATHFILE=/etc/config/qpkg.conf
    readonly INSTALL_LOG_FILE=install.log
    readonly DOWNLOAD_LOG_FILE=download.log
    readonly START_LOG_FILE=start.log
    readonly STOP_LOG_FILE=stop.log
    readonly RESTART_LOG_FILE=restart.log
    readonly UPDATE_LOG_FILE=update.log
    readonly DEFAULT_SHARES_PATHFILE=/etc/config/def_share.info
    readonly ULINUX_PATHFILE=/etc/config/uLinux.conf
    readonly PLATFORM_PATHFILE=/etc/platform.conf
    readonly EXTERNAL_PACKAGE_ARCHIVE_PATHFILE=/opt/var/opkg-lists/entware
    readonly REMOTE_REPO_URL=https://raw.githubusercontent.com/OneCDOnly/sherpa/master

    local -r DEBUG_LOG_FILE=${LOADER_SCRIPT_FILE%.*}.debug.log

    IsOnlyInstance || return 1

    # check required binaries are present
    IsSysFileExist $AWK_CMD || return 1
    IsSysFileExist $CAT_CMD || return 1
    IsSysFileExist $CHMOD_CMD || return 1
    IsSysFileExist $DATE_CMD || return 1
    IsSysFileExist $GREP_CMD || return 1
    IsSysFileExist $HOSTNAME_CMD || return 1
    IsSysFileExist $LN_CMD || return 1
    IsSysFileExist $MD5SUM_CMD || return 1
    IsSysFileExist $MKDIR_CMD || return 1
    IsSysFileExist $PING_CMD || return 1
    IsSysFileExist $SED_CMD || return 1
    IsSysFileExist $SLEEP_CMD || return 1
    IsSysFileExist $TAR_CMD || return 1
    IsSysFileExist $TOUCH_CMD || return 1
    IsSysFileExist $TR_CMD || return 1
    IsSysFileExist $UNAME_CMD || return 1
    IsSysFileExist $UNIQ_CMD || return 1

    IsSysFileExist $CURL_CMD || return 1
    IsSysFileExist $GETCFG_CMD || return 1
    IsSysFileExist $RMCFG_CMD || return 1
    IsSysFileExist $SETCFG_CMD || return 1

    IsSysFileExist $BASENAME_CMD || return 1
    IsSysFileExist $CUT_CMD || return 1
    IsSysFileExist $DIRNAME_CMD || return 1
    IsSysFileExist $DU_CMD || return 1
    IsSysFileExist $HEAD_CMD || return 1
    IsSysFileExist $READLINK_CMD || return 1
    IsSysFileExist $SORT_CMD || return 1
    IsSysFileExist $TAIL_CMD || return 1
    IsSysFileExist $TEE_CMD || return 1
    IsSysFileExist $UNZIP_CMD || return 1
    IsSysFileExist $UPTIME_CMD || return 1
    IsSysFileExist $WC_CMD || return 1

    IsSysFileExist $Z7_CMD || return 1
    IsSysFileExist $ZIP_CMD || return 1

    UnsetLogToFile
    UnsetError
    UnsetAbort
    UnsetVisibleDebugging
    UnsetCheckDependencies
    UnsetVersionOnly
    UnsetLogPasteOnly
    UnsetShowAbbreviations
    UnsetSuggestIssue
    UnsetShowHelp
    SetShowInstallerOutcome
    UnsetDevMode

    local -r DEFAULT_SHARE_DOWNLOAD_PATH=/share/Download
    local -r DEFAULT_SHARE_PUBLIC_PATH=/share/Public

    # check required system paths are present
    if [[ -L $DEFAULT_SHARE_DOWNLOAD_PATH ]]; then
        readonly SHARE_DOWNLOAD_PATH=$DEFAULT_SHARE_DOWNLOAD_PATH
    else
        readonly SHARE_DOWNLOAD_PATH=/share/$($GETCFG_CMD SHARE_DEF defDownload -d Qdownload -f $DEFAULT_SHARES_PATHFILE)
        IsSysShareExist "$SHARE_DOWNLOAD_PATH" || return 1
    fi

    if [[ -L $DEFAULT_SHARE_PUBLIC_PATH ]]; then
        readonly SHARE_PUBLIC_PATH=$DEFAULT_SHARE_PUBLIC_PATH
    else
        readonly SHARE_PUBLIC_PATH=/share/$($GETCFG_CMD SHARE_DEF defPublic -d Qpublic -f $DEFAULT_SHARES_PATHFILE)
        IsSysShareExist "$SHARE_PUBLIC_PATH" || return 1
    fi

    # sherpa-supported package details - parallel arrays
    SHERPA_QPKG_NAME=()         # internal QPKG name
        SHERPA_QPKG_ARCH=()     # QPKG supports this architecture
        SHERPA_QPKG_URL=()      # remote QPKG URL
        SHERPA_QPKG_MD5=()      # remote QPKG MD5
        SHERPA_QPKG_ABBRVS=()   # if set, this package is user-installable, and these abbreviations may be used to specify app
        SHERPA_QPKG_DEPS=()     # require these QPKGs to be installed first
        SHERPA_QPKG_IPKGS=()    # require these IPKGs to be installed first

    SHERPA_QPKG_NAME+=(Entware)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=($REMOTE_REPO_URL/QPKGs/Entware/Entware_1.02std.qpkg)
        SHERPA_QPKG_MD5+=(dbc82469933ac3049c06d4c8a023bbb9)
        SHERPA_QPKG_ABBRVS+=('ew ent opkg entware')
        SHERPA_QPKG_DEPS+=('')
        SHERPA_QPKG_IPKGS+=('')

    SHERPA_QPKG_NAME+=(SABnzbd)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=($REMOTE_REPO_URL/QPKGs/SABnzbd/build/SABnzbd_200901b.qpkg)
        SHERPA_QPKG_MD5+=(809d60b4ccbc772a10efeddad76fce35)
        SHERPA_QPKG_ABBRVS+=('sb sb3 sab sab3 sabnzbd3 sabnzbd')
        SHERPA_QPKG_DEPS+=('Entware Par2')
        SHERPA_QPKG_IPKGS+=('python3-asn1crypto python3-chardet python3-cryptography python3-pyopenssl unrar p7zip coreutils-nice ionice ffprobe')

    SHERPA_QPKG_NAME+=(nzbToMedia)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=($REMOTE_REPO_URL/QPKGs/nzbToMedia/build/nzbToMedia_200901b.qpkg)
        SHERPA_QPKG_MD5+=(686b5ab0833b9c5bc09f968163429299)
        SHERPA_QPKG_ABBRVS+=('nzb2 nzb2m nzbto nzbtom nzbtomedia')
        SHERPA_QPKG_DEPS+=('Entware')
        SHERPA_QPKG_IPKGS+=('')

    SHERPA_QPKG_NAME+=(SickChill)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=($REMOTE_REPO_URL/QPKGs/SickChill/build/SickChill_200901b.qpkg)
        SHERPA_QPKG_MD5+=(f48fbaaf091aed3cec257c6fcd9f8904)
        SHERPA_QPKG_ABBRVS+=('sc sick sickc chill sickchill')
        SHERPA_QPKG_DEPS+=('Entware')
        SHERPA_QPKG_IPKGS+=('')

    SHERPA_QPKG_NAME+=(LazyLibrarian)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=($REMOTE_REPO_URL/QPKGs/LazyLibrarian/build/LazyLibrarian_200903.qpkg)
        SHERPA_QPKG_MD5+=(501318c6e94864acb6fd57e2f89bf1a2)
        SHERPA_QPKG_ABBRVS+=('ll lazy lazylibrarian')
        SHERPA_QPKG_DEPS+=('Entware')
        SHERPA_QPKG_IPKGS+=('python3-pyopenssl python3-requests')

    SHERPA_QPKG_NAME+=(OMedusa)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=($REMOTE_REPO_URL/QPKGs/OMedusa/build/OMedusa_200901b.qpkg)
        SHERPA_QPKG_MD5+=(04d4c0694afbc3a85aaa2f6b9424c7bc)
        SHERPA_QPKG_ABBRVS+=('om med omed medusa omedusa')
        SHERPA_QPKG_DEPS+=('Entware')
        SHERPA_QPKG_IPKGS+=('mediainfo python3-pyopenssl')

    SHERPA_QPKG_NAME+=(OSickGear)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=($REMOTE_REPO_URL/QPKGs/OSickGear/build/OSickGear_200901b.qpkg)
        SHERPA_QPKG_MD5+=(770f7430a3a5820a18745264517b6be8)
        SHERPA_QPKG_ABBRVS+=('sg os osg sickg gear ogear osickg sickgear osickgear')
        SHERPA_QPKG_DEPS+=('Entware')
        SHERPA_QPKG_IPKGS+=('')

    SHERPA_QPKG_NAME+=(Mylar3)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=($REMOTE_REPO_URL/QPKGs/Mylar3/build/Mylar3_200903.qpkg)
        SHERPA_QPKG_MD5+=(bea2d34aff5d2dd8fa5481ad9458f306)
        SHERPA_QPKG_ABBRVS+=('my omy myl mylar mylar3')
        SHERPA_QPKG_DEPS+=('Entware')
        SHERPA_QPKG_IPKGS+=('python3-mako python3-pillow python3-pyopenssl python3-pytz python3-requests python3-six python3-urllib3')

    SHERPA_QPKG_NAME+=(NZBGet)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=($REMOTE_REPO_URL/QPKGs/NZBGet/build/NZBGet_200901b.qpkg)
        SHERPA_QPKG_MD5+=(dcd057eadd389717ac1e9647133d595b)
        SHERPA_QPKG_ABBRVS+=('ng nzb nzbg nget nzbget')
        SHERPA_QPKG_DEPS+=('Entware')
        SHERPA_QPKG_IPKGS+=('nzbget')

    SHERPA_QPKG_NAME+=(OTransmission)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=($REMOTE_REPO_URL/QPKGs/OTransmission/build/OTransmission_200903.qpkg)
        SHERPA_QPKG_MD5+=(1d332285e32aa90aabab808ceb023adf)
        SHERPA_QPKG_ABBRVS+=('ot tm tr trans otrans tmission transmission otransmission')
        SHERPA_QPKG_DEPS+=('Entware')
        SHERPA_QPKG_IPKGS+=('transmission-web transmission-daemon-openssl jq')

    SHERPA_QPKG_NAME+=(Deluge-server)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=($REMOTE_REPO_URL/QPKGs/Deluge-server/build/Deluge-server_200903b.qpkg)
        SHERPA_QPKG_MD5+=(c2c2aa696a0009144d70a22d610b85b6)
        SHERPA_QPKG_ABBRVS+=('deluge del-server deluge-server')
        SHERPA_QPKG_DEPS+=('Entware')
        SHERPA_QPKG_IPKGS+=('deluge')

    SHERPA_QPKG_NAME+=(Deluge-web)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=($REMOTE_REPO_URL/QPKGs/Deluge-web/build/Deluge-web_200904.qpkg)
        SHERPA_QPKG_MD5+=(317c340dcf74b6ee5cc9aaa32a5b2f8e)
        SHERPA_QPKG_ABBRVS+=('del-web deluge-web')
        SHERPA_QPKG_DEPS+=('Entware')
        SHERPA_QPKG_IPKGS+=('deluge-ui-web')

    SHERPA_QPKG_NAME+=(Par2)
        SHERPA_QPKG_ARCH+=(x86)
        SHERPA_QPKG_URL+=($REMOTE_REPO_URL/QPKGs/Par2/Par2_0.8.1.0_x86.qpkg)
        SHERPA_QPKG_MD5+=(996ffb92d774eb01968003debc171e91)
        SHERPA_QPKG_ABBRVS+=('')
        SHERPA_QPKG_DEPS+=('')
        SHERPA_QPKG_IPKGS+=('')

    SHERPA_QPKG_NAME+=(Par2)
        SHERPA_QPKG_ARCH+=(x64)
        SHERPA_QPKG_URL+=($REMOTE_REPO_URL/QPKGs/Par2/Par2_0.8.1.0_x86_64.qpkg)
        SHERPA_QPKG_MD5+=(520472cc87d301704f975f6eb9948e38)
        SHERPA_QPKG_ABBRVS+=('')
        SHERPA_QPKG_DEPS+=('')
        SHERPA_QPKG_IPKGS+=('')

    SHERPA_QPKG_NAME+=(Par2)
        SHERPA_QPKG_ARCH+=(x31)
        SHERPA_QPKG_URL+=($REMOTE_REPO_URL/QPKGs/Par2/Par2_0.8.1.0_arm-x31.qpkg)
        SHERPA_QPKG_MD5+=(ce8af2e009eb87733c3b855e41a94f8e)
        SHERPA_QPKG_ABBRVS+=('')
        SHERPA_QPKG_DEPS+=('')
        SHERPA_QPKG_IPKGS+=('')

    SHERPA_QPKG_NAME+=(Par2)
        SHERPA_QPKG_ARCH+=(x41)
        SHERPA_QPKG_URL+=($REMOTE_REPO_URL/QPKGs/Par2/Par2_0.8.1.0_arm-x41.qpkg)
        SHERPA_QPKG_MD5+=(8516e45e704875cdd2cd2bb315c4e1e6)
        SHERPA_QPKG_ABBRVS+=('')
        SHERPA_QPKG_DEPS+=('')
        SHERPA_QPKG_IPKGS+=('')

    SHERPA_QPKG_NAME+=(Par2)
        SHERPA_QPKG_ARCH+=(a64)
        SHERPA_QPKG_URL+=($REMOTE_REPO_URL/QPKGs/Par2/Par2_0.8.1.0_arm_64.qpkg)
        SHERPA_QPKG_MD5+=(4d8e99f97936a163e411aa8765595f7a)
        SHERPA_QPKG_ABBRVS+=('')
        SHERPA_QPKG_DEPS+=('')
        SHERPA_QPKG_IPKGS+=('')

    # package arrays are now full, so lock them
    readonly SHERPA_QPKG_NAME
        readonly SHERPA_QPKG_ARCH
        readonly SHERPA_QPKG_URL
        readonly SHERPA_QPKG_MD5
        readonly SHERPA_QPKG_ABBRVS
        readonly SHERPA_QPKG_DEPS
        readonly SHERPA_QPKG_IPKGS

    readonly SHERPA_COMMON_IPKGS='ca-certificates findutils gcc git git-http less nano python3-dev python3-pip python3-setuptools sed'
    readonly SHERPA_COMMON_PIPS='apscheduler beautifulsoup4 cfscrape cheetah3 "cheroot!=8.4.4" cherrypy configobj feedparser portend pygithub python-magic random_user_agent sabyenc3 simplejson slugify'
    readonly SHERPA_COMMON_CONFLICTS='Optware Optware-NG TarMT'

    # runtime vars
    QPKGS_to_install=()
    QPKGS_to_uninstall=()
    QPKGS_to_restart=()
    QPKGS_to_upgrade=()
    QPKGS_to_backup=()
    QPKGS_to_restore=()
    QPKGS_to_status=()

    readonly PREV_QPKG_CONFIG_DIRS=(SAB_CONFIG CONFIG Config config)                 # last element is used as target dirname
    readonly PREV_QPKG_CONFIG_FILES=(sabnzbd.ini settings.ini config.cfg config.ini) # last element is used as target filename
    readonly WORK_PATH=$SHARE_PUBLIC_PATH/${LOADER_SCRIPT_FILE%.*}.tmp
    readonly DEBUG_LOG_PATHFILE=$SHARE_PUBLIC_PATH/$DEBUG_LOG_FILE
    readonly QPKG_DL_PATH=$WORK_PATH/qpkg.downloads
    readonly IPKG_DL_PATH=$WORK_PATH/ipkg.downloads
    readonly IPKG_CACHE_PATH=$WORK_PATH/ipkg.cache
    readonly PIP_CACHE_PATH=$WORK_PATH/pip.cache
    readonly EXTERNAL_PACKAGE_LIST_PATHFILE=$WORK_PATH/Packages

    # internals
    readonly SCRIPT_STARTSECONDS=$($DATE_CMD +%s)
    readonly NAS_FIRMWARE=$($GETCFG_CMD System Version -f $ULINUX_PATHFILE)
    readonly MIN_RAM_KB=1048576
    readonly INSTALLED_RAM_KB=$($GREP_CMD MemTotal /proc/meminfo | $CUT_CMD -f2 -d':' | $SED_CMD 's|kB||;s| ||g')
    reinstall_flag=false
    ignore_space_arg=''
    [[ ${NAS_FIRMWARE//.} -lt 426 ]] && curl_insecure_arg='--insecure' || curl_insecure_arg=''

    CalcIndependentQPKGs
    CalcDependantQPKGs
    CalcUserInstallableQPKGs
    CalcInstalledQPKGs
    CalcUpgradeableQPKGs
    CalcNASQPKGArch

    return 0

    }

LogRuntimeParameters()
    {

    local conflicting_qpkg=''
    code_pointer=0

    ParseArgs

    IsVersionOnly && return

    if IsNotVisibleDebugging; then
        echo "$(ColourTextBrightWhite "$LOADER_SCRIPT_FILE") ($MANAGER_SCRIPT_VERSION) a mini-package-manager for QNAP NAS"
        DisplayLineSpace
        CheckLoaderAge
    fi

    DisplayNewQPKGVersions

    IsAbort && return

    SetLogToFile
    DebugInfoThickSeparator
    DebugScript 'started' "$($DATE_CMD | $TR_CMD -s ' ')"
    DebugScript 'version' "manager: $MANAGER_SCRIPT_VERSION, loader $LOADER_SCRIPT_VERSION"
    DebugScript 'PID' "$$"
    DebugInfoThinSeparator
    DebugInfo 'Markers: (**) detected, (II) information, (WW) warning, (LL) log file,'
    DebugInfo ' (EE) error, (==) processing, (--) done, (>>) f entry, (<<) f exit,'
    DebugInfo ' (vv) variable name & value, ($1) positional argument value.'
    DebugInfoThinSeparator
    DebugHardware 'model' "$(get_display_name)"
    DebugHardware 'RAM' "$INSTALLED_RAM_KB kB"
    if IsQPKGToBeInstalled SABnzbd || IsQPKGInstalled SABnzbd || IsQPKGInstalled SABnzbdplus; then
        [[ $INSTALLED_RAM_KB -le $MIN_RAM_KB ]] && DebugHardwareWarning 'RAM' "less-than or equal-to $MIN_RAM_KB kB"
    fi
    DebugFirmware 'firmware version' "$NAS_FIRMWARE"
    DebugFirmware 'firmware build' "$($GETCFG_CMD System 'Build Number' -f $ULINUX_PATHFILE)"
    DebugFirmware 'kernel' "$($UNAME_CMD -mr)"
    DebugUserspace 'OS uptime' "$($UPTIME_CMD | $SED_CMD 's|.*up.||;s|,.*load.*||;s|^\ *||')"
    DebugUserspace 'system load' "$($UPTIME_CMD | $SED_CMD 's|.*load average: ||' | $AWK_CMD -F', ' '{print "1 min="$1 ", 5 min="$2 ", 15 min="$3}')"

    if [[ $USER = admin ]]; then
        DebugUserspace '$USER' "$USER"
    else
        DebugUserspaceWarning '$USER' "$USER"
    fi

    if [[ $EUID -eq 0 ]]; then
        DebugUserspace '$EUID' "$EUID"
    else
        DebugUserspaceWarning '$EUID' "$EUID"
    fi

    DebugUserspace 'default volume' "$($GETCFG_CMD SHARE_DEF defVolMP -f $DEFAULT_SHARES_PATHFILE)"
    DebugUserspace '$PATH' "${PATH:0:43}"

    if [[ -L '/opt' ]]; then
        DebugUserspace '/opt' "$($READLINK_CMD '/opt' || echo "<not present>")"
    else
        DebugUserspaceWarning '/opt' '<not present>'
    fi

    if location=$(which python3 2>&1); then
        DebugUserspace 'Python 3 path' "$location"
        DebugUserspace 'Python 3 version' "$(version=$(python3 -V 2>&1) && echo "$version" || echo '<unknown>')"
    else
        DebugUserspaceWarning 'Python 3 path' '<not present>'
    fi

    if [[ -L $SHARE_DOWNLOAD_PATH ]]; then
        DebugUserspace "$SHARE_DOWNLOAD_PATH" "$($READLINK_CMD "$SHARE_DOWNLOAD_PATH")"
    else
        DebugUserspaceWarning "$SHARE_DOWNLOAD_PATH" '<not present>'
    fi

    DebugScript 'unparsed arguments' "$USER_ARGS_RAW"
    DebugScript 'app(s) to install' "${QPKGS_to_install[*]} "
    DebugScript 'app(s) to uninstall' "${QPKGS_to_uninstall[*]} "
    DebugScript 'app(s) to reinstall' "${QPKGS_to_upgrade[*]} "
    DebugScript 'app(s) to update' "${QPKGS_to_upgrade[*]} "
    DebugScript 'app(s) to backup' "${QPKGS_to_backup[*]} "
    DebugScript 'app(s) to restore' "${QPKGS_to_restore[*]} "
    DebugScript 'work path' "$WORK_PATH"
    DebugQPKG 'download path' "$QPKG_DL_PATH"
    DebugIPKG 'download path' "$IPKG_DL_PATH"
    DebugQPKG 'arch' "$NAS_QPKG_ARCH"

    if [[ $EUID -ne 0 || $USER != admin ]]; then
        ShowAsError "this script must be run as the 'admin' user. Please login via SSH as 'admin' and try again"
        return 1
    fi

    if [[ ${#QPKGS_to_install[@]} -eq 0 && ${#QPKGS_to_uninstall[@]} -eq 0 && ${#QPKGS_to_restart[@]} -eq 0 && ${#QPKGS_to_upgrade[@]} -eq 0 && ${#QPKGS_to_backup[@]} -eq 0 && ${#QPKGS_to_restore[@]} -eq 0 && ${#QPKGS_to_status[@]} -eq 0 ]]; then
        if IsNotInstallAllApps && IsNotUninstallAllApps && IsNotRestartAllApps && IsNotUpgradeAllApps && IsNotBackupAllApps && IsNotRestoreAllApps && IsNotStatusAllApps; then
            if IsNotCheckDependencies; then
                ShowAsError 'no valid QPKGs or actions were specified'
                SetShowAbbreviations
                return 1
            fi
        fi
    fi

    if IsBackupAllApps && IsRestoreAllApps; then
        ShowAsError 'no point running a backup then a restore operation'
        code_pointer=1
        return 1
    fi

    $MKDIR_CMD -p "$WORK_PATH" 2> /dev/null; result=$?

    if [[ $result -ne 0 ]]; then
        ShowAsError "unable to create script working directory $(FormatAsFileName "$WORK_PATH") $(FormatAsExitcode $result)"
        SetSuggestIssue
        return 1
    fi

    $MKDIR_CMD -p "$QPKG_DL_PATH" 2> /dev/null; result=$?

    if [[ $result -ne 0 ]]; then
        ShowAsError "unable to create QPKG download directory $(FormatAsFileName "$QPKG_DL_PATH") $(FormatAsExitcode $result)"
        SetSuggestIssue
        return 1
    fi

    $MKDIR_CMD -p "$IPKG_DL_PATH" 2> /dev/null; result=$?

    if [[ $result -ne 0 ]]; then
        ShowAsError "unable to create IPKG download directory $(FormatAsFileName "$IPKG_DL_PATH") $(FormatAsExitcode $result)"
        SetSuggestIssue
        return 1
    fi

    [[ -d $IPKG_CACHE_PATH ]] && rm -rf "$IPKG_CACHE_PATH"
    $MKDIR_CMD -p "$IPKG_CACHE_PATH" 2> /dev/null; result=$?

    if [[ $result -ne 0 ]]; then
        ShowAsError "unable to create IPKG cache directory $(FormatAsFileName "$IPKG_CACHE_PATH") $(FormatAsExitcode $result)"
        SetSuggestIssue
        return 1
    fi

    [[ -d $PIP_CACHE_PATH ]] && rm -rf "$PIP_CACHE_PATH"
    $MKDIR_CMD -p "$PIP_CACHE_PATH" 2> /dev/null; result=$?

    if [[ $result -ne 0 ]]; then
        ShowAsError "unable to create PIP cache directory $(FormatAsFileName "$PIP_CACHE_PATH") $(FormatAsExitcode $result)"
        SetSuggestIssue
        return 1
    fi

    for conflicting_qpkg in "${SHERPA_COMMON_CONFLICTS[@]}"; do
        if IsQPKGEnabled "$conflicting_qpkg"; then
            ShowAsError "'$conflicting_qpkg' is enabled. This is an unsupported configuration"
            return 1
        fi
    done

    if IsQPKGInstalled Entware; then
        [[ -e /opt/etc/passwd ]] && { [[ -L /opt/etc/passwd ]] && ENTWARE_VER=std || ENTWARE_VER=alt ;} || ENTWARE_VER=none
        DebugQPKG 'Entware installer' $ENTWARE_VER

        if [[ $ENTWARE_VER = none ]]; then
            ShowAsError "$(FormatAsPackageName Entware) appears to be installed but is not visible"
            return 1
        fi
    fi

    DebugInfoThinSeparator

    return 0

    }

DisplayNewQPKGVersions()
    {

    # Check installed sherpa packages and compare versions against package arrays. If new versions are available, advise on-screen.

    # $? = 0 if all packages are up-to-date
    # $? = 1 if one or more packages can be upgraded

    local names=''
    local msg=''

    if [[ ${#QPKGS_upgradable[@]} -gt 0 ]]; then
        if [[ ${#QPKGS_upgradable[@]} -eq 1 ]]; then
            msg='An upgraded package is'
        else
            msg='Upgraded packages are'
        fi

        names=${QPKGS_upgradable[*]}
        ShowAsNote "$msg available for $(ColourTextBrightYellow "${names// /, }")"
        return 1
    fi

    return 0

    }

ParseArgs()
    {

    if [[ -z $USER_ARGS_RAW ]]; then
        SetShowHelp
        code_pointer=2
        return 1
    fi

    local user_args=($($TR_CMD '[A-Z]' '[a-z]' <<< "$USER_ARGS_RAW"))
    local arg=''
    local current_operation=''
    local target_app=''

    for arg in "${user_args[@]}"; do
        case $arg in
            -d|d|--debug|debug)
                SetVisibleDebugging
                current_operation=''
                ;;
            -c|c|--check|check)
                SetCheckDependencies
                current_operation=''
                return 1
                ;;
            --ignore-space|ignore-space)
                ignore_space_arg='--force-space'
                DebugVar ignore_space_arg
                current_operation=''
                ;;
            -h|h|--help|help)
                SetShowHelp
                return 1
                ;;
            -p|p|--problem|problem)
                SetShowProblemHelp
                return 1
                ;;
            -t|t|--tips|tips)
                SetShowTipsHelp
                return 1
                ;;
            -l|l|--log|log)
                SetLogViewOnly
                return 1
                ;;
            --paste|paste)
                SetLogPasteOnly
                return 1
                ;;
            --abs|abs)
                SetShowAbbreviations
                return 1
                ;;
            -v|v|--version|version)
                SetVersionOnly
                return 1
                ;;
            --install-all-applications)
                SetInstallAllApps
                current_operation=''
                return 1
                ;;
            --uninstall-all-applications)
                SetUninstallAllApps
                current_operation=''
                return 1
                ;;
            --restart-all|restart-all)
                SetRestartAllApps
                current_operation=''
                ;;
            --upgrade-all|upgrade-all)
                SetUpgradeAllApps
                current_operation=''
                ;;
            --backup-all)
                SetBackupAllApps
                current_operation=''
                return 1
                ;;
            --restore-all)
                SetRestoreAllApps
                current_operation=''
                return 1
                ;;
            --status-all|status-all)
                SetStatusAllApps
                current_operation=''
                return 1
                ;;
            --install)
                current_operation=install
                ;;
            --uninstall)
                current_operation=uninstall
                ;;
            --restart)
                current_operation=restart
                ;;
            --upgrade)
                current_operation=upgrade
                ;;
            --backup)
                current_operation=backup
                ;;
            --restore)
                current_operation=restore
                ;;
            --status)
                current_operation=status
                ;;
            *)
                target_app=$(MatchAbbrvToQPKGName "$arg")
                [[ -z $target_app ]] && continue

                case $current_operation in
                    uninstall)
                        QPKGS_to_uninstall+=($target_app)
                        ;;
                    reinstall)
                        QPKGS_to_upgrade+=($target_app)
                        ;;
                    upgrade)
                        QPKGS_to_upgrade+=($target_app)
                        ;;
                    backup)
                        QPKGS_to_backup+=($target_app)
                        ;;
                    restore)
                        QPKGS_to_restore+=($target_app)
                        ;;
                    status)
                        QPKGS_to_status+=($target_app)
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

    local package=''
    local package_name_message=''
    local package_note_message=''

    DisplayLineSpace
    echo -e "Usage: $(ColourTextBrightWhite "./$LOADER_SCRIPT_FILE") $(FormatAsHelpPackage) $(FormatAsHelpOption)"

    DisplayAsTitleHelpPackage

    for package in "${QPKGS_user_installable[@]}"; do
        if IsQPKGUpgradable "$package"; then
            package_name_message="$(ColourTextBrightYellow "$package")"
        else
            package_name_message="$package"
        fi

        if [[ $package = Entware ]]; then       # kludge: use this until independent package checking works.
            package_note_message='(installed by-default)'
        else
            package_note_message=''
        fi

        DisplayAsHelpPackageNameExample "$package_name_message" "$package_note_message"
    done

    DisplayAsHelpExample 'example: to install, reinstall or upgrade SABnzbd' 'SABnzbd'
    echo
    DisplayAsTitleHelpOption

    DisplayAsHelpExample 'display helpful tips and shortcuts' '--tips'

    DisplayAsHelpExample 'display troubleshooting options' '--problem'

    return 0

    }

ShowProblemHelp()
    {

    DisplayLineSpace
    DisplayAsTitleHelpOption

    DisplayAsHelpExample 'install a package and show debugging information' '[PACKAGE] --debug'

    DisplayAsHelpExample 'ensure all application dependencies are installed' '--check'

    DisplayAsHelpExample "don't check free-space on target filesystem when installing $(FormatAsPackageName Entware) packages" '--ignore-space'

    DisplayAsHelpExample 'restart all applications (only upgrades the internal applications, not the QPKG)' '--restart-all'

    DisplayAsHelpExample 'upgrade all QPKGs (including the internal applications)' '--upgrade-all'

    DisplayAsHelpExample 'view the log' '--log'

    DisplayAsHelpExample "upload the log to the $(FormatAsURL 'https://termbin.com') public pastebin" '--paste'

    echo -e "\n$(ColourTextBrightOrange "* If you need help, please include a copy of your") $(FormatAsScriptTitle) $(ColourTextBrightOrange "log for analysis!")"
    UnsetLineSpace

    return 0

    }

ShowIssueHelp()
    {

    DisplayLineSpace
    echo -e "* Please consider creating a new issue for this on GitHub:\n\thttps://github.com/OneCDOnly/sherpa/issues"

    echo -e "\n* Alternatively, post on the QNAP NAS Community Forum:\n\thttps://forum.qnap.com/viewtopic.php?f=320&t=132373"

    DisplayAsHelpExample 'view the log' '--log'

    DisplayAsHelpExample "upload the log to the $(FormatAsURL 'https://termbin.com') public pastebin" '--paste'

    echo -e "\n$(ColourTextBrightOrange '* If you need help, please include a copy of your') $(FormatAsScriptTitle) $(ColourTextBrightOrange 'log for analysis!')"
    UnsetLineSpace

    return 0

    }

ShowTipsHelp()
    {

    DisplayLineSpace
    DisplayAsTitleHelpOption
    DisplayAsHelpExample 'install everything!' '--install-all-applications'

    DisplayAsHelpExample 'package abbreviations may also be used. To see these' '--abs'

    DisplayAsHelpExample 'ensure all application dependencies are installed' '--check'

    DisplayAsHelpExample 'restart all applications (only upgrades the internal applications, not the QPKG)' '--restart-all'

    DisplayAsHelpExample 'upgrade all QPKGs (including the internal applications)' '--upgrade-all'

    DisplayAsHelpExample "upload the log to the $(FormatAsURL 'https://termbin.com') public pastebin" '--paste'

    DisplayAsHelpExample 'display the package manager script versions' '--version'

    echo -e "\n$(ColourTextBrightOrange "* If you need help, please include a copy of your") $(FormatAsScriptTitle) $(ColourTextBrightOrange "log for analysis!")"
    UnsetLineSpace

    return 0

    }

ShowPackageAbbreviations()
    {

    [[ ${#SHERPA_QPKG_NAME[@]} -eq 0 || ${#SHERPA_QPKG_ABBRVS[@]} -eq 0 ]] && return 1

    local package_index=0

    DisplayLineSpace
    echo -e "* $(FormatAsScriptTitle) recognises these package names and abbreviations:"

    for package_index in "${!SHERPA_QPKG_NAME[@]}"; do
        if [[ -n ${SHERPA_QPKG_ABBRVS[$package_index]} ]]; then
            if IsQPKGUpgradable "${SHERPA_QPKG_NAME[$package_index]}"; then
                printf "%26s: %s\n" "$(ColourTextBrightYellow "${SHERPA_QPKG_NAME[$package_index]}")" "$($SED_CMD 's| |, |g' <<< "${SHERPA_QPKG_ABBRVS[$package_index]}")"
            else
                printf "%15s: %s\n" "${SHERPA_QPKG_NAME[$package_index]}" "$($SED_CMD 's| |, |g' <<< "${SHERPA_QPKG_ABBRVS[$package_index]}")"
            fi
        fi
    done

    DisplayAsHelpExample 'example: to install, reinstall or upgrade SABnzbd' 'sab'

    return 0

    }

ShowLogViewer()
    {

    if [[ -n $DEBUG_LOG_PATHFILE && -e $DEBUG_LOG_PATHFILE ]]; then
        if [[ -e $GNU_LESS_CMD ]]; then
            LESSSECURE=1 $GNU_LESS_CMD +G --quit-on-intr --tilde --LINE-NUMBERS --prompt ' use arrow-keys to scroll up-down left-right, press Q to quit' "$DEBUG_LOG_PATHFILE"
        else
            $CAT_CMD --number "$DEBUG_LOG_PATHFILE"
        fi
    else
        ShowAsError 'no log to display'
    fi

    return 0

    }

PasteLogOnline()
    {

    # with thanks to https://github.com/solusipse/fiche

    if [[ -n $DEBUG_LOG_PATHFILE && -e $DEBUG_LOG_PATHFILE ]]; then
        if AskQuiz "Press 'Y' to post your sherpa log in a public pastebin, or any other key to abort"; then
            ShowAsProc 'uploading sherpa log'
            link=$($TAIL_CMD -n 1000 -q "$DEBUG_LOG_PATHFILE" | (exec 3<>/dev/tcp/termbin.com/9999; $CAT_CMD >&3; $CAT_CMD <&3; exec 3<&-))

            if [[ $? -eq 0 ]]; then
                ShowAsDone "your sherpa log is now online at $(FormatAsURL "$($SED_CMD 's|http://|http://l.|;s|https://|https://l.|' <<< "$link")") and will be deleted in 1 month"
            else
                ShowAsError "a link could not be generated. Most likely a problem occurred when talking with $(FormatAsURL 'https://termbin.com')"
            fi
        else
            SetAbort
            UnsetShowInstallerOutcome
            DebugInfoThinSeparator
            DebugScript 'user abort'
            DebugInfoThickSeparator
            return 1
        fi
    else
        ShowAsError 'no log to paste'
    fi

    return 0

    }

ShowInstallerOutcome()
    {

    if IsUpgradeAllApps; then
        if [[ ${#QPKGS_upgradable[@]} -eq 0 ]]; then
            ShowAsDone "no QPKGs need upgrading!"
        elif IsNotError; then
            ShowAsDone "all upgradable QPKGs were successfully upgraded!"
        else
            ShowAsError "upgrade failed! [$code_pointer]"
            SetSuggestIssue
        fi
    elif [[ -n $TARGET_APP ]]; then
        [[ $reinstall_flag = true ]] && RE='re' || RE=''

        if IsNotError; then
            ShowAsDone "$(FormatAsPackageName "$TARGET_APP") has been successfully ${RE}installed!"
        else
            ShowAsError "$(FormatAsPackageName "$TARGET_APP") ${RE}install failed! [$code_pointer]"
            SetSuggestIssue
        fi
    fi

    if IsCheckDependencies; then
        if IsNotError; then
            ShowAsDone "all application dependencies are installed!"
        else
            ShowAsError "application dependency check failed! [$code_pointer]"
            SetSuggestIssue
        fi
    fi

    return 0

    }

AskQuiz()
    {

    # input:
    #   $1 = prompt

    # output:
    #   $? = 0 if "yes", 1 if "no"

    ShowAsQuiz "$1"
    read -rn1 response
    DebugVar response
    ShowAsQuizDone "$1: $response"

    case ${response:0:1} in
        y|Y)
            return 0
            ;;
        *)
            return 1
            ;;
    esac

    }

DownloadQPKGs()
    {

    IsAbort && return

    [[ -f $SHARE_PUBLIC_PATH/.sherpa.devmode ]] && SetDevMode

    DebugFuncEntry
    local QPKGs_to_download=''

    if IsDevMode; then
        [[ ${#QPKGS_to_install[@]} -gt 0 ]] && QPKGs_to_download+="${QPKGS_to_install[*]}"
        [[ ${#QPKGS_to_upgrade[@]} -gt 0 ]] && QPKGs_to_download+=" ${QPKGS_to_upgrade[*]}"

        FindAllQPKGDependants "$QPKGs_to_download"

        for package in "${QPKG_download_list[@]}"; do
            DownloadQPKG "$package"
        done

        exit
    else
        if IsNotQPKGInstalled Entware; then
            if [[ $TARGET_APP = Entware ]]; then
                ShowAsNote "It's not necessary to install $(FormatAsPackageName Entware) first. It will be installed on-demand with your other sherpa packages. :)"
                SetAbort
                UnsetShowInstallerOutcome
                return 1
            else
                DownloadQPKG Entware
            fi
        fi

        if IsInstallAllApps; then
            for package in "${QPKGS_user_installable[@]}"; do
                DownloadQPKG "$package"
            done
        elif IsUpgradeAllApps; then
            for package in "${QPKGS_upgradable[@]}"; do
                DownloadQPKG "$package"
            done
        else

            [[ -n $TARGET_APP ]] && DownloadQPKG "$TARGET_APP"
        fi

        # kludge: an ugly workaround until QPKG dependency checking works properly
        (IsQPKGInstalled SABnzbd || [[ $TARGET_APP = SABnzbd ]] ) && [[ $NAS_QPKG_ARCH != none ]] && IsNotQPKGInstalled Par2 && DownloadQPKG Par2
    fi

    DebugFuncExit
    return 0

    }

RemoveUnwantedQPKGs()
    {

    IsAbort && return

    local response=''
    local previous_pip3_module_list=$SHARE_PUBLIC_PATH/pip3.prev.installed.list
    local previous_opkg_package_list=$SHARE_PUBLIC_PATH/opkg.prev.installed.list

    UninstallQPKG Optware
    UninstallQPKG Entware-3x
    UninstallQPKG Entware-ng

    IsQPKGInstalled "$TARGET_APP" && reinstall_flag=true

    if [[ $TARGET_APP = Entware && $reinstall_flag = true ]]; then
        ShowAsNote "Reinstalling $(FormatAsPackageName Entware) will remove all IPKGs and Python modules, and only those required to support your sherpa apps will be reinstalled."
        ShowAsNote "Your installed IPKG list will be saved to $(FormatAsFileName "$previous_opkg_package_list")"
        ShowAsNote "Your installed Python module list will be saved to $(FormatAsFileName "$previous_pip3_module_list")"
        (IsQPKGInstalled SABnzbdplus || IsQPKGInstalled Headphones) && ShowAsWarning "Also, the $(FormatAsPackageName SABnzbdplus) and $(FormatAsPackageName Headphones) packages CANNOT BE REINSTALLED as Python 2.7.16 is no-longer available."

        if AskQuiz "Press 'Y' to remove all current $(FormatAsPackageName Entware) IPKGs (and their configurations), or any other key to abort"; then
            ShowAsProc 'saving package and Python module lists'

            $pip3_cmd freeze > "$previous_pip3_module_list"
            DebugDone "saved current $(FormatAsPackageName pip3) module list to $(FormatAsFileName "$previous_pip3_module_list")"

            $OPKG_CMD list-installed > "$previous_opkg_package_list"
            DebugDone "saved current $(FormatAsPackageName Entware) IPKG list to $(FormatAsFileName "$previous_opkg_package_list")"

            ShowAsDone 'package and Python module lists saved'
            UninstallQPKG Entware
        else
            SetAbort
            UnsetShowInstallerOutcome
            DebugInfoThinSeparator
            DebugScript 'user abort'
            DebugInfoThickSeparator
            return 1
        fi
    fi

    return 0

    }

InstallQPKGIndeps()
    {

    IsAbort && return

    DebugFuncEntry

    if IsNotQPKGInstalled Entware; then
        # rename original [/opt]
        local opt_path=/opt
        local opt_backup_path=/opt.orig
        [[ -d $opt_path && ! -L $opt_path && ! -e $opt_backup_path ]] && mv "$opt_path" "$opt_backup_path"

        InstallQPKG Entware && ReloadProfile

        # copy all files from original [/opt] into new [/opt]
        [[ -L $opt_path && -d $opt_backup_path ]] && cp --recursive "$opt_backup_path"/* --target-directory "$opt_path" && rm -rf "$opt_backup_path"
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

    local find_text=''
    local insert_text=''
    local package_init_pathfile=$(GetInstalledQPKGServicePathFile Entware)

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

    return 0

    }

UpdateEntware()
    {

    if IsNotSysFileExist $OPKG_CMD || IsNotSysFileExist $GNU_FIND_CMD; then
        code_pointer=3
        return 1
    fi

    local package_minutes_threshold=60
    local log_pathfile="$WORK_PATH/entware.$UPDATE_LOG_FILE"
    local msgs=''
    local result=0

    # if Entware package list was updated only recently, don't run another update. Examine 'change' time as this is updated even if package list content isn't modified.
    if [[ -e $EXTERNAL_PACKAGE_ARCHIVE_PATHFILE ]]; then
        msgs=$($GNU_FIND_CMD "$EXTERNAL_PACKAGE_ARCHIVE_PATHFILE" -cmin +$package_minutes_threshold)        # no-output if last update was less than $package_minutes_threshold minutes ago
    else
        msgs='new install'
    fi

    if [[ -n $msgs ]]; then
        ShowAsProc "updating $(FormatAsPackageName Entware) package list"

        RunThisAndLogResults "$OPKG_CMD update" "$log_pathfile"
        result=$?

        if [[ $result -eq 0 ]]; then
            ShowAsDone "updated $(FormatAsPackageName Entware) package list"
        else
            ShowAsWarning "Unable to update $(FormatAsPackageName Entware) package list $(FormatAsExitcode $result)"
            DebugErrorFile "$log_pathfile"
            # meh, continue anyway with old list ...
        fi
    else
        DebugInfo "$(FormatAsPackageName Entware) package list was updated less than $package_minutes_threshold minutes ago"
        ShowAsDone "$(FormatAsPackageName Entware) package list is up-to-date"
    fi

    return 0

    }

InstallQPKGIndepsAddons()
    {

    IsAbort && return

    DebugFuncEntry

    if IsQPKGInstalled SABnzbdplus && [[ $NAS_QPKG_ARCH != none ]]; then
        if IsNotQPKGInstalled Par2; then
            InstallQPKG Par2
            IsError && ShowAsWarning "$(FormatAsPackageName Par2) installation failed - but it's not essential so I'm continuing"
        fi
    fi

    # kludge: use the same ugly workaround until QPKG dep checking works properly
    if (IsQPKGInstalled SABnzbd || [[ $TARGET_APP = SABnzbd ]] ) && [[ $NAS_QPKG_ARCH != none ]]; then
        if IsNotQPKGInstalled Par2; then
            InstallQPKG Par2
            IsError && ShowAsWarning "$(FormatAsPackageName Par2) installation failed - but it's not essential so I'm continuing"
        fi
    fi

    InstallIPKGs
    InstallPy3Modules

    if [[ $TARGET_APP = Entware ]] || IsRestartAllApps; then
        RestartAllDepQPKGs
    fi

    DebugFuncExit
    return 0

    }

InstallIPKGs()
    {

    IsAbort && return

    DebugFuncEntry
    local returncode=0
    local packages="$SHERPA_COMMON_IPKGS"
    local index=0

    if [[ -n $IPKG_DL_PATH && -d $IPKG_DL_PATH ]]; then
        UpdateEntware
        IsError && return
        for index in "${!SHERPA_QPKG_NAME[@]}"; do
            if IsQPKGInstalled "${SHERPA_QPKG_NAME[$index]}" || [[ $TARGET_APP = "${SHERPA_QPKG_NAME[$index]}" ]]; then
                packages+=" ${SHERPA_QPKG_IPKGS[$index]}"
            fi
        done

        if IsQPKGInstalled SABnzbd || [[ $TARGET_APP = SABnzbd ]]; then
            [[ $NAS_QPKG_ARCH = none ]] && packages+=' par2cmdline'
        fi

        InstallIPKGBatch "$packages"
    else
        ShowAsError "IPKG download path [$IPKG_DL_PATH] does not exist"
        returncode=1
    fi

    # in-case 'python' has disappeared again ...
    [[ ! -L /opt/bin/python && -e /opt/bin/python3 ]] && $LN_CMD -s /opt/bin/python3 /opt/bin/python

    DebugFuncExit
    return $returncode

    }

InstallIPKGBatch()
    {

    # input:
    #   $1 = whitespace-separated string containing list of IPKG names to download and install

    # output:
    #   $? = 0 (true) or 1 (false)

    DebugFuncEntry
    local returncode=0
    local requested_IPKGs=''
    local log_pathfile="$IPKG_DL_PATH/ipkgs.$INSTALL_LOG_FILE"
    local result=0

    requested_IPKGs="$1"

    # errors can occur due to incompatible IPKGs (tried installing Entware-3x, then Entware-ng), so delete them first
    [[ -d $IPKG_DL_PATH ]] && rm -f "$IPKG_DL_PATH"/*.ipk
    [[ -d $IPKG_CACHE_PATH ]] && rm -f "$IPKG_CACHE_PATH"/*.ipk

    FindAllIPKGDependencies "$requested_IPKGs" || return 1

    if [[ $IPKG_download_count -gt 0 ]]; then
        local -r STARTSECONDS=$(DebugTimerStageStart)
        ShowAsProc "downloading & installing $IPKG_download_count IPKG$(FormatAsPlural "$IPKG_download_count")"

        CreateDirSizeMonitorFlagFile
            trap CTRL_C_Captured INT
                _MonitorDirSize_ "$IPKG_DL_PATH" "$IPKG_download_size" &

                RunThisAndLogResults "$OPKG_CMD install$ignore_space_arg --force-overwrite ${IPKG_download_list[*]} --cache $IPKG_CACHE_PATH --tmp-dir $IPKG_DL_PATH" "$log_pathfile"
                result=$?
            trap - INT
        RemoveDirSizeMonitorFlagFile

        if [[ $result -eq 0 ]]; then
            ShowAsDone "downloaded & installed $IPKG_download_count IPKG$(FormatAsPlural "$IPKG_download_count")"
            # if 'python3-pip' was installed, the install all 'pip' modules too
            [[ ${IPKG_download_list[*]} =~ python3-pip ]] && SetPIPInstall
        else
            ShowAsError "download & install IPKG$(FormatAsPlural "$IPKG_download_count") failed $(FormatAsExitcode $result)"
            DebugErrorFile "$log_pathfile"
            returncode=1
        fi
        DebugTimerStageEnd "$STARTSECONDS"
    fi

    DebugFuncExit
    return $returncode

    }

InstallPy3Modules()
    {

    IsAbort && return
    IsNotPIPInstall && return

    DebugFuncEntry
    local exec_cmd=''
    local result=0
    local returncode=0
    local packages=''
    local desc="'Python 3' modules"
    local log_pathfile="$WORK_PATH/py3-modules.$INSTALL_LOG_FILE"

    # sometimes, OpenWRT doesn't have a 'pip3'
    if [[ -e /opt/bin/pip3 ]]; then
        pip3_cmd=/opt/bin/pip3
    elif [[ -e /opt/bin/pip3.8 ]]; then
        pip3_cmd=/opt/bin/pip3.8
    elif [[ -e /opt/bin/pip3.7 ]]; then
        pip3_cmd=/opt/bin/pip3.7
    else
        if IsNotSysFileExist $pip3_cmd; then
            echo "* Ugh! The usual fix for this is to let sherpa reinstall $(FormatAsPackageName Entware) at least once."
            echo -e "\t$0 ew"
            echo "If it happens again after reinstalling $(FormatAsPackageName Entware), please create a new issue for this on GitHub."
            return 1
        fi
    fi

    [[ -n ${SHERPA_COMMON_PIPS// /} ]] && exec_cmd="$pip3_cmd install $SHERPA_COMMON_PIPS --disable-pip-version-check --cache-dir $PIP_CACHE_PATH"
    [[ -n ${SHERPA_COMMON_PIPS// /} && -n ${packages// /} ]] && exec_cmd+=" && "
    [[ -n ${packages// /} ]] && exec_cmd+="$pip3_cmd install $packages --disable-pip-version-check --cache-dir $PIP_CACHE_PATH"

    # kludge: force recompilation of 'sabyenc3' package so it's recognised by SABnzbd. See: https://forums.sabnzbd.org/viewtopic.php?p=121214#p121214
    [[ $exec_cmd =~ sabyenc3 ]] && exec_cmd+=" && $pip3_cmd install --force-reinstall --ignore-installed --no-binary :all: sabyenc3 --disable-pip-version-check --cache-dir $PIP_CACHE_PATH"

    [[ -z $exec_cmd ]] && return

    ShowAsProcLong "downloading & installing $desc"

    RunThisAndLogResults "$exec_cmd" "$log_pathfile"
    result=$?

    if [[ $result -eq 0 ]]; then
        ShowAsDone "downloaded & installed $desc"
    else
        ShowAsError "download & install $desc failed $(FormatAsResult "$result")"
        DebugErrorFile "$log_pathfile"
        returncode=1
    fi

    DebugFuncExit
    return $returncode

    }

RestartAllDepQPKGs()
    {

    # restart all sherpa QPKGs except independents. Needed if user has requested each QPKG update itself, or Python 3 was downgraded.

    IsAbort && return

    [[ -z ${SHERPA_DEP_QPKGs[*]} || ${#SHERPA_DEP_QPKGs[@]} -eq 0 ]] && return

    DebugFuncEntry
    local package=''

    for package in "${SHERPA_DEP_QPKGs[@]}"; do
        IsQPKGEnabled "$package" && RestartQPKGService "$package"
    done

    DebugFuncExit
    return 0

    }

Cleanup()
    {

    [[ -d $WORK_PATH ]] && IsNotError && IsNotVisibleDebugging && IsNotDevMode && rm -rf "$WORK_PATH"

    return 0

    }

ShowResult()
    {

    local RE=''

    if IsVersionOnly; then
        echo "loader: $LOADER_SCRIPT_VERSION"
        echo "manager: $MANAGER_SCRIPT_VERSION"
    elif IsLogViewOnly; then
        ShowLogViewer
    elif IsShowHelp; then
        ShowHelp
    elif IsShowProblemHelp; then
        ShowProblemHelp
    elif IsShowTipsHelp; then
        ShowTipsHelp
    elif IsShowAbbreviations; then
        ShowPackageAbbreviations
    fi

    IsLogPasteOnly && PasteLogOnline
    IsShowInstallerOutcome && ShowInstallerOutcome
    IsSuggestIssue && ShowIssueHelp

    DebugInfoThinSeparator
    DebugScript 'finished' "$($DATE_CMD)"
    DebugScript 'elapsed time' "$(ConvertSecsToMinutes "$(($($DATE_CMD +%s)-$([[ -n $SCRIPT_STARTSECONDS ]] && echo "$SCRIPT_STARTSECONDS" || echo "1")))")"
    DebugInfoThickSeparator

    return 0

    }






ReloadProfile()
    {

    local opkg_prefix=/opt/bin:/opt/sbin

    if IsQPKGInstalled Entware; then
        export PATH="$opkg_prefix:$($SED_CMD "s|$opkg_prefix||" <<< $PATH)"
        DebugDone 'adjusted $PATH for Entware'
        DebugVar PATH
    fi

    return 0

    }

DownloadQPKG()
    {

    # input:
    #   $1 = QPKG name to download

    # output:
    #   $? = 0 if successful, 1 if failed

    IsError && return

    DebugFuncEntry
    local result=0
    local returncode=0
    local remote_url=$(GetQPKGRemoteURL "$1")
    local remote_filename="$($BASENAME_CMD "$remote_url")"
    local remote_filename_md5="$(GetQPKGMD5 "$1")"
    local local_pathfile="$QPKG_DL_PATH/$remote_filename"
    local local_filename="$($BASENAME_CMD "$local_pathfile")"
    local log_pathfile="$local_pathfile.$DOWNLOAD_LOG_FILE"

    if [[ -e $local_pathfile ]]; then
        if FileMatchesMD5 "$local_pathfile" "$remote_filename_md5"; then
            DebugInfo "existing QPKG checksum correct $(FormatAsFileName "$local_filename")"
        else
            DebugWarning "existing QPKG checksum incorrect $(FormatAsFileName "$local_filename")"
            DebugInfo "deleting QPKG $(FormatAsFileName "$local_filename")"
            rm -f "$local_pathfile"
        fi
    fi

    if IsNotError && [[ ! -e $local_pathfile ]]; then
        ShowAsProc "downloading QPKG $(FormatAsFileName "$remote_filename")"

        [[ -e $log_pathfile ]] && rm -f "$log_pathfile"

        if IsVisibleDebugging; then
            RunThisAndLogResultsRealtime "$CURL_CMD $curl_insecure_arg --output $local_pathfile $remote_url" "$log_pathfile"
            result=$?
        else
            RunThisAndLogResults "$CURL_CMD $curl_insecure_arg --output $local_pathfile $remote_url" "$log_pathfile"
            result=$?
        fi

        if [[ $result -eq 0 ]]; then
            if FileMatchesMD5 "$local_pathfile" "$remote_filename_md5"; then
                ShowAsDone "downloaded QPKG $(FormatAsFileName "$remote_filename")"
            else
                ShowAsError "downloaded QPKG checksum incorrect $(FormatAsFileName "$local_pathfile")"
                returncode=1
            fi
        else
            ShowAsError "download failed $(FormatAsFileName "$local_pathfile") $(FormatAsExitcode $result)"
            DebugErrorFile "$log_pathfile"
            returncode=1
        fi
    fi

    DebugFuncExit
    return $returncode

    }

InstallQPKG()
    {

    # $1 = QPKG name to install

    IsError && return
    IsAbort && return

    local target_file=''
    local result=0
    local returncode=0
    local local_pathfile="$(GetQPKGPathFilename "$1")"

    if [[ ${local_pathfile##*.} = zip ]]; then
        $UNZIP_CMD -nq "$local_pathfile" -d "$QPKG_DL_PATH"
        local_pathfile="${local_pathfile%.*}"
    fi

    local log_pathfile="$local_pathfile.$INSTALL_LOG_FILE"
    target_file=$($BASENAME_CMD "$local_pathfile")

    ShowAsProcLong "installing QPKG $(FormatAsFileName "$target_file")"

    sh "$local_pathfile" > "$log_pathfile" 2>&1
    result=$?

    if [[ $result -eq 0 || $result -eq 10 ]]; then
        ShowAsDone "installed QPKG $(FormatAsFileName "$target_file")"
        GetQPKGServiceStatus "$1"
    else
        ShowAsError "QPKG installation failed $(FormatAsFileName "$target_file") $(FormatAsExitcode $result)"
        DebugErrorFile "$log_pathfile"
        returncode=1
    fi

    return $returncode

    }

InstallTargetQPKG()
    {

    IsAbort && return

    local package=''

    if IsInstallAllApps; then
        if [[ -n ${QPKGS_user_installable[*]} ]]; then
            for package in "${QPKGS_user_installable[@]}"; do
                InstallQPKG "$package"
            done
        fi
    elif IsUpgradeAllApps; then
        if [[ -n ${QPKGS_upgradable[*]} ]]; then
            for package in "${QPKGS_upgradable[@]}"; do
                InstallQPKG "$package"
            done
        fi
    else
        [[ -z $TARGET_APP ]] && return 1
        [[ $TARGET_APP != Entware ]] && InstallQPKG "$TARGET_APP"
    fi

    DebugFuncExit
    return 0

    }

#### Calc... function are each run only once.

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
            case $($GETCFG_CMD '' Platform -f $PLATFORM_PATHFILE) in
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

CalcIndependentQPKGs()
    {

    # Returns a list of QPKGs that don't depend on other QPKGs. These are therefore independent. They should be installed/started before any dependant QPKGs.
    # creates a global constant array: $SHERPA_INDEP_QPKGs()

    SHERPA_INDEP_QPKGs=()
    local index=0

    for index in "${!SHERPA_QPKG_NAME[@]}"; do
        [[ -z ${SHERPA_QPKG_DEPS[$index]} && ! ${SHERPA_INDEP_QPKGs[*]} =~ ${SHERPA_QPKG_NAME[$index]} ]] && SHERPA_INDEP_QPKGs+=(${SHERPA_QPKG_NAME[$index]})
    done

    readonly SHERPA_INDEP_QPKGs

    return 0

    }

CalcDependantQPKGs()
    {

    # Returns a list of QPKGs that depend on other QPKGs. These are therefore dependant. They should be installed/started after any independent QPKGs.
    # creates a global constant array: $SHERPA_DEP_QPKGs()

    SHERPA_DEP_QPKGs=()
    local index=0

    for index in "${!SHERPA_QPKG_NAME[@]}"; do
        [[ -n ${SHERPA_QPKG_DEPS[$index]} && ! ${SHERPA_DEP_QPKGs[*]} =~ ${SHERPA_QPKG_NAME[$index]} ]] && SHERPA_DEP_QPKGs+=(${SHERPA_QPKG_NAME[$index]})
    done

    readonly SHERPA_DEP_QPKGs

    return 0

    }

CalcUserInstallableQPKGs()
    {

    # Returns a list of QPKGs that can be installed or reinstalled by the user.
    # creates a global variable array: $QPKGS_user_installable()

    QPKGS_user_installable=()
    local package=''

    for package in "${SHERPA_QPKG_NAME[@]}"; do
        IsQPKGUserInstallable "$package" && QPKGS_user_installable+=($package)
    done

    return 0

    }

CalcInstalledQPKGs()
    {

    # Returns a list of QPKGs that are installed.
    # creates a global variable array: $QPKGS_installed()

    QPKGS_installed=()
    local package=''

    for package in "${QPKGS_user_installable[@]}"; do
        IsQPKGInstalled "$package" && QPKGS_installed+=($package)
    done

    return 0

    }

CalcUpgradeableQPKGs()
    {

    # Returns a list of QPKGs that can be upgraded.
    # creates a global variable array: $QPKGS_upgradable()

    QPKGS_upgradable=()
    local package=''
    local installed_version=''
    local remote_version=''

    for package in "${QPKGS_installed[@]}"; do
        [[ $package = Entware ]] && continue        # kludge: ignore 'Entware' as package filename version doesn't match the QTS App Center version string
        installed_version=$(GetInstalledQPKGVersion "$package")
        remote_version=$(GetQPKGRemoteVersion "$package")

        if [[ $installed_version != "$remote_version" ]]; then
            #QPKGS_upgradable+=("$package $installed_version $remote_version")
            QPKGS_upgradable+=($package)
        fi
    done

    return 0

    }

UninstallQPKG()
    {

    # input:
    #   $1 = QPKG name

    # output:
    #   $? = 0 if successful, 1 if failed

    IsError && return

    local result=0

    qpkg_installed_path="$($GETCFG_CMD "$1" Install_Path -f $APP_CENTER_CONFIG_PATHFILE)"
    result=$?

    if [[ $result -eq 0 ]]; then
        if [[ -e $qpkg_installed_path/.uninstall.sh ]]; then
            ShowAsProc "uninstalling $(FormatAsPackageName "$1")"

            "$qpkg_installed_path"/.uninstall.sh > /dev/null
            result=$?

            if [[ $result -eq 0 ]]; then
                ShowAsDone "uninstalled $(FormatAsPackageName "$1")"
            else
                ShowAsError "unable to uninstall $(FormatAsPackageName "$1") $(FormatAsExitcode $result)"
                return 1
            fi
        fi

        $RMCFG_CMD "$1" -f $APP_CENTER_CONFIG_PATHFILE
    else
        DebugQPKG "$(FormatAsPackageName "$1")" "not installed $(FormatAsExitcode $result)"
    fi

    return 0

    }

RestartQPKGService()
    {

    # Restarts the service script for the QPKG named in $1

    # input:
    #   $1 = QPKG name

    # output:
    #   $? = 0 if successful, 1 if failed

    local result=0
    local package_init_pathfile=$(GetInstalledQPKGServicePathFile "$1")
    local log_file=$WORK_PATH/$1.$RESTART_LOG_FILE

    ShowAsProc "restarting $(FormatAsPackageName "$1")"
    RunThisAndLogResults "$package_init_pathfile restart" "$log_file"
    result=$?

    if [[ $result -eq 0 ]]; then
        ShowAsDone "restarted $(FormatAsPackageName "$1")"
        GetQPKGServiceStatus "$1"
    else
        ShowAsWarning "Could not restart $(FormatAsPackageName "$1") $(FormatAsExitcode $result)"
        if IsVisibleDebugging; then
            DebugInfoThickSeparator
            $CAT_CMD "$log_file"
            DebugInfoThickSeparator
        else
            $CAT_CMD "$log_file" >> "$DEBUG_LOG_PATHFILE"
        fi
        # meh, continue anyway...
        return 1
    fi

    return 0

    }

GetInstalledQPKGVars()
    {

    # Load variables for specified package

    # input:
    #   $1 = QPKG name

    # output:
    #   $? = 0 if successful, 1 if failed
    #   $package_installed_path
    #   $package_config_path

    local package_name=$1
    local prev_config_dir=''
    local prev_config_file=''
    local package_settings_pathfile=''
    package_installed_path=''
    package_config_path=''

    package_installed_path=$($GETCFG_CMD "$package_name" Install_Path -f $APP_CENTER_CONFIG_PATHFILE)
    if [[ $? -eq 0 ]]; then
        for prev_config_dir in "${PREV_QPKG_CONFIG_DIRS[@]}"; do
            package_config_path=$package_installed_path/$prev_config_dir
            [[ -d $package_config_path ]] && break
        done

        for prev_config_file in "${PREV_QPKG_CONFIG_FILES[@]}"; do
            package_settings_pathfile=$package_config_path/$prev_config_file
            [[ -f $package_settings_pathfile ]] && break
        done
    else
        DebugError 'QPKG not installed?'
        return 1
    fi

    return 0

    }

GetInstalledQPKGServicePathFile()
    {

    # input:
    #   $1 = QPKG name

    # output:
    #   stdout = service pathfilename
    #   $? = 0 if found, 1 if not

    IsNotQPKGInstalled "$1" && return 1

    local output=''

    if output=$($GETCFG_CMD "$1" Shell -f $APP_CENTER_CONFIG_PATHFILE); then
        echo "$output"
        return 0
    else
        echo 'unknown'
        return 1
    fi

    }

GetInstalledQPKGVersion()
    {

    # Returns the version number of an installed QPKG.

    # input:
    #   $1 = QPKG name

    # output:
    #   stdout = package version
    #   $? = 0 if found, 1 if not

    IsNotQPKGInstalled "$1" && return 1

    local output=''

    if output=$($GETCFG_CMD "$1" Version -f $APP_CENTER_CONFIG_PATHFILE); then
        echo "$output"
        return 0
    else
        echo 'unknown'
        return 1
    fi

    }

GetQPKGServiceStatus()
    {

    # $1 = QPKG name to install

    if [[ -e /var/run/$1.last.operation ]]; then
        case $(</var/run/"$1".last.operation) in
            ok)
                DebugInfo "$(FormatAsPackageName "$1") service started OK"
                ;;
            failed)
                ShowAsError "$(FormatAsPackageName "$1") service failed to start.$([[ -e /var/log/$1.log ]] && echo " Check $(FormatAsFileName "/var/log/$1.log") for more information")"
                ;;
            *)
                DebugWarning "$(FormatAsPackageName "$1") service status is incorrect"
                ;;
        esac
    else
        DebugWarning "unable to determine status of $(FormatAsPackageName "$1") service. It may be a package earlier than 200816c that doesn't support service operation results."
    fi

    }

GetQPKGPathFilename()
    {

    # input:
    #   $1 = QPKG name

    # output:
    #   stdout = QPKG local filename
    #   $? = 0 if successful, 1 if failed

    echo "$QPKG_DL_PATH/$($BASENAME_CMD "$(GetQPKGRemoteURL "$1")")"

    }

GetQPKGRemoteURL()
    {

    # input:
    #   $1 = QPKG name

    # output:
    #   stdout = QPKG remote URL
    #   $? = 0 if successful, 1 if failed

    local index=0
    local returncode=1

    for index in "${!SHERPA_QPKG_NAME[@]}"; do
        if [[ $1 = "${SHERPA_QPKG_NAME[$index]}" ]] && [[ ${SHERPA_QPKG_ARCH[$index]} = all || ${SHERPA_QPKG_ARCH[$index]} = "$NAS_QPKG_ARCH" ]]; then
            echo "${SHERPA_QPKG_URL[$index]}"
            returncode=0
            break
        fi
    done

    return $returncode

    }

GetQPKGRemoteVersion()
    {

    # input:
    #   $1 = QPKG name

    # output:
    #   stdout = QPKG remote version
    #   $? = 0 if successful, 1 if failed

    local url=''
    local version=''

    if url=$(GetQPKGRemoteURL "$1"); then
        version=${url#*_}; version=${version%.*}
        echo "$version"
        return 0
    else
        echo "unknown"
        return 1
    fi

    }

GetQPKGMD5()
    {

    # input:
    #   $1 = QPKG name

    # output:
    #   stdout = QPKG MD5
    #   $? = 0 if successful, 1 if failed

    local index=0
    local returncode=1

    for index in "${!SHERPA_QPKG_NAME[@]}"; do
        if [[ $1 = "${SHERPA_QPKG_NAME[$index]}" ]] && [[ ${SHERPA_QPKG_ARCH[$index]} = all || ${SHERPA_QPKG_ARCH[$index]} = "$NAS_QPKG_ARCH" ]]; then
            echo "${SHERPA_QPKG_MD5[$index]}"
            returncode=0
            break
        fi
    done

    return $returncode

    }

GetQPKGDeps()
    {

    # input:
    #   $1 = QPKG name to return dependencies for

    # output:
    #   $? = 0 if successful, 1 if failed

    local index=0

    for index in "${!SHERPA_QPKG_NAME[@]}"; do
        if [[ ${SHERPA_QPKG_NAME[$index]} = "$1" ]]; then
            echo "${SHERPA_QPKG_DEPS[$index]}"
            return 0
        fi
    done

    return 1

    }

FindAllQPKGDependants()
    {

    # From a specified list of QPKG names, find all dependent QPKGs then generate a total qty to download.

    # input:
    #   $1 = string with space-separated initial QPKG names.

    # output:
    #   $QPKG_download_list = name-sorted array with complete list of all QPKGs, including those originally specified.
    #   $QPKG_download_count = number of packages to be downloaded.

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
    local -r STARTSECONDS=$(DebugTimerStageStart)

    requested_list=$(DeDupeWords "$1")
    last_list=$requested_list

    ShowAsProc 'determining QPKGs required'
    DebugInfo "requested QPKGs: $requested_list"

    DebugProc 'finding QPKG dependencies'
    while [[ $iterations -lt $ITERATION_LIMIT ]]; do
        ((iterations++))
        new_list=''
        for package in "${last_list[@]}"; do
            new_list+=$(GetQPKGDeps "$package")
        done

        new_list=$(DeDupeWords "$new_list")

        if [[ -n $new_list ]]; then
            dependency_list+=${new_list[*]}
            last_list=$new_list
        else
            DebugDone 'complete'
            DebugInfo "found all QPKG dependencies in $iterations iteration$(FormatAsPlural $iterations)"
            complete=true
            break
        fi
    done

    if [[ $complete = false ]]; then
        DebugError "QPKG dependency list is incomplete! Consider raising \$ITERATION_LIMIT [$ITERATION_LIMIT]."
        SetSuggestIssue
    fi

    all_list=$(DeDupeWords "$requested_list $dependency_list")
    DebugInfo "QPKGs requested + dependencies: $all_list"

    DebugProc 'excluding QPKGs already installed'
    for element in "${all_list[@]}"; do
        IsNotQPKGInstalled "$element" && QPKG_download_list+=($element)
    done
    DebugDone 'complete'
    DebugInfo "QPKGs to download: ${QPKG_download_list[*]}"
    QPKG_download_count=${#QPKG_download_list[@]}

    DebugTimerStageEnd "$STARTSECONDS"

    if [[ $QPKG_download_count -gt 0 ]]; then
        ShowAsDone "$QPKG_download_count QPKG$(FormatAsPlural "$QPKG_download_count") to be downloaded"
    else
        ShowAsDone 'no QPKGs are required'
    fi

    }

FindAllIPKGDependencies()
    {

    # From a specified list of IPKG names, find all dependent IPKGs, exclude those already installed, then generate a total qty to download and a total download byte-size

    # input:
    #   $1 = string with space-separated initial IPKG names

    # output:
    #   $IPKG_download_list = name-sorted array with complete list of all IPKGs, including those originally specified
    #   $IPKG_download_count = number of packages to be downloaded
    #   $IPKG_download_size = byte-count of packages to be downloaded

    if IsNotSysFileExist $OPKG_CMD || IsNotSysFileExist $GNU_GREP_CMD; then
        code_pointer=5
        return 1
    fi

    IPKG_download_list=()
    IPKG_download_count=0
    IPKG_download_size=0
    local requested_list=''
    local dependency_list=''
    local last_list=''
    local all_list=''
    local element=''
    local iterations=0
    local -r ITERATION_LIMIT=20
    local complete=false
    local -r STARTSECONDS=$(DebugTimerStageStart)

    # remove duplicate entries
    requested_list=$(DeDupeWords "$1")
    last_list=$requested_list

    ShowAsProc 'determining IPKGs required'
    DebugInfo "IPKGs requested: $requested_list"

    OpenIPKGArchive || return 1

    DebugProc 'finding IPKG dependencies'
    while [[ $iterations -lt $ITERATION_LIMIT ]]; do
        ((iterations++))
        # shellcheck disable=SC2086
        last_list=$($OPKG_CMD depends -A $last_list | $GREP_CMD -v 'depends on:' | $SED_CMD 's|^[[:blank:]]*||;s|[[:blank:]]*$||' | $TR_CMD ' ' '\n' | $SORT_CMD | $UNIQ_CMD)

        if [[ -n $last_list ]]; then
            dependency_list+=" $last_list"
        else
            DebugDone 'complete'
            DebugInfo "found all IPKG dependencies in $iterations iteration$(FormatAsPlural $iterations)"
            complete=true
            break
        fi
    done

    if [[ $complete = false ]]; then
        DebugError "IPKG dependency list is incomplete! Consider raising \$ITERATION_LIMIT [$ITERATION_LIMIT]."
        SetSuggestIssue
    fi

    all_list=$(DeDupeWords "$requested_list $dependency_list")
    DebugInfo "IPKGs requested + dependencies: $all_list"

    DebugTimerStageEnd "$STARTSECONDS"

    DebugProc 'excluding IPKGs already installed'
    # shellcheck disable=SC2068
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
        DebugProc "determining size of IPKG$(FormatAsPlural "$IPKG_download_count") to download"
        size_array=($($GNU_GREP_CMD -w '^Package:\|^Size:' "$EXTERNAL_PACKAGE_LIST_PATHFILE" | $GNU_GREP_CMD --after-context 1 --no-group-separator ": $($SED_CMD 's/ /$ /g;s/\$ /\$\\\|: /g' <<< "${IPKG_download_list[*]}")$" | $GREP_CMD '^Size:' | $SED_CMD 's|^Size: ||'))
        IPKG_download_size=$(IFS=+; echo "$((${size_array[*]}))")       # a neat trick found here https://stackoverflow.com/a/13635566/6182835
        DebugDone 'complete'
        DebugVar IPKG_download_size
        ShowAsDone "$IPKG_download_count IPKG$(FormatAsPlural "$IPKG_download_count") ($(FormatAsISO "$IPKG_download_size")) to be downloaded"
    else
        ShowAsDone 'no IPKGs are required ... woohoo!'
    fi

    CloseIPKGArchive

    }

OpenIPKGArchive()
    {

    # extract the 'opkg' package list file

    if [[ ! -e $EXTERNAL_PACKAGE_ARCHIVE_PATHFILE ]]; then
        ShowAsError 'could not locate the IPKG list file'
        return 1
    fi

    CloseIPKGArchive

    RunThisAndLogResults "$Z7_CMD e -o$($DIRNAME_CMD "$EXTERNAL_PACKAGE_LIST_PATHFILE") $EXTERNAL_PACKAGE_ARCHIVE_PATHFILE" "$WORK_PATH/ipkg.list.archive.extract"

    if [[ ! -e $EXTERNAL_PACKAGE_LIST_PATHFILE ]]; then
        ShowAsError 'could not open the IPKG list file'
        return 1
    fi

    return 0

    }

CloseIPKGArchive()
    {

    [[ -e $EXTERNAL_PACKAGE_LIST_PATHFILE ]] && rm -f "$EXTERNAL_PACKAGE_LIST_PATHFILE"

    }

_MonitorDirSize_()
    {

    # * This function runs autonomously *
    # It watches for the existence of $monitor_flag_pathfile
    # If that file is removed, this function dies gracefully

    # input:
    #   $1 = directory to monitor the size of
    #   $2 = total target bytes (100%) for specified path

    [[ -z $1 || ! -d $1 || -z $2 || $2 -eq 0 ]] && return
    IsNotSysFileExist $GNU_FIND_CMD && return

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

    while [[ -e $monitor_flag_pathfile ]]; do
        current_bytes=$($GNU_FIND_CMD "$target_dir" -type f -name '*.ipk' -exec $DU_CMD --bytes --total --apparent-size {} + 2> /dev/null | $GREP_CMD total$ | $CUT_CMD -f1)
        [[ -z $current_bytes ]] && current_bytes=0

        if [[ $current_bytes -ne $last_bytes ]]; then
            stall_seconds=0
            last_bytes=$current_bytes
        else
            ((stall_seconds++))
        fi

        percent="$((200*(current_bytes)/(total_bytes) % 2 + 100*(current_bytes)/(total_bytes)))%"
        progress_message=" $percent ($(FormatAsISO "$current_bytes")/$(FormatAsISO "$total_bytes"))"

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

CreateDirSizeMonitorFlagFile()
    {

    monitor_flag_pathfile=$IPKG_DL_PATH/.monitor

    $TOUCH_CMD "$monitor_flag_pathfile"

    }

RemoveDirSizeMonitorFlagFile()
    {

    if [[ -n $monitor_flag_pathfile && -e $monitor_flag_pathfile ]]; then
        rm -f "$monitor_flag_pathfile"
        $SLEEP_CMD 2
    fi

    }

CreateLock()
    {

    [[ -n $RUNTIME_LOCK_PATHFILE ]] && echo "$$" > "$RUNTIME_LOCK_PATHFILE"

    }

RemoveLock()
    {

    [[ -n $RUNTIME_LOCK_PATHFILE && -e $RUNTIME_LOCK_PATHFILE ]] && rm -f "$RUNTIME_LOCK_PATHFILE"

    }

EnableQPKG()
    {

    # $1 = package name to enable

    if [[ $($GETCFG_CMD "$1" Enable -u -f $APP_CENTER_CONFIG_PATHFILE) != 'TRUE' ]]; then
        DebugProc "enabling QPKG $(FormatAsPackageName "$1")"
        $SETCFG_CMD "$1" Enable TRUE -f $APP_CENTER_CONFIG_PATHFILE
        DebugDone "QPKG $(FormatAsPackageName "$1") enabled"
    fi

    }

IsQNAP()
    {

    # is this a QNAP NAS?

    if [[ ! -e /etc/init.d/functions ]]; then
        ShowAsAbort 'QTS functions missing (is this a QNAP NAS?)'
        return 1
    fi

    return 0

    }

IsOnlyInstance()
    {

    readonly RUNTIME_LOCK_PATHFILE=/var/run/$LOADER_SCRIPT_FILE.pid

    if [[ -e $RUNTIME_LOCK_PATHFILE && -d /proc/$(<$RUNTIME_LOCK_PATHFILE) && -n $LOADER_SCRIPT_FILE && $(</proc/"$(<$RUNTIME_LOCK_PATHFILE)"/cmdline) =~ $LOADER_SCRIPT_FILE ]]; then
        ShowAsAbort "another instance of $(ColourTextBrightWhite "$LOADER_SCRIPT_FILE") is running"
        return 1
    else
        CreateLock
    fi

    return 0

    }

CheckLoaderAge()
    {

    # Has the loader script been downloaded only in the last 5 minutes?

    [[ -e $GNU_FIND_CMD ]] || return          # can only do this with GNU 'find'. The old BusyBox 'find' in QTS 4.2.6 doesn't support '-cmin'.

    if [[ -e "$LOADER_SCRIPT_FILE" && -z $($GNU_FIND_CMD "$LOADER_SCRIPT_FILE" -cmin +5) ]]; then
        ShowAsNote "The $(ColourTextBrightWhite 'sherpa.sh') script does not need updating anymore. It now downloads all the latest information from the Internet everytime it's run. ;)"
    fi

    return 0

    }

IsSysFileExist()
    {

    # input:
    #   $1 = pathfile to check

    # output:
    #   $? = 0 (true) or 1 (false)

    if ! [[ -f $1 || -L $1 ]]; then
        ShowAsError "a required NAS system file is missing $(FormatAsFileName "$1")"
        return 1
    else
        return 0
    fi

    }

IsNotSysFileExist()
    {

    # input:
    #   $1 = pathfile to check

    # output:
    #   $? = 0 (true) or 1 (false)

    ! IsSysFileExist "$1"

    }

IsSysShareExist()
    {

    # input:
    #   $1 = symlink path to check

    # output:
    #   $? = 0 (true) or 1 (false)

    if [[ ! -L $1 ]]; then
        ShowAsError "a required NAS system share is missing $(FormatAsFileName "$1"). Please re-create it via the QTS Control Panel -> Privilege Settings -> Shared Folders"
        return 1
    else
        return 0
    fi

    }

IsNotSysShareExist()
    {

    # input:
    #   $1 = symlink path to check

    # output:
    #   $? = 0 (true) or 1 (false)

    ! IsSysShareExist "$1"

    }

IsIPKGInstalled()
    {

    # input:
    #   $1 = package name to check

    # output:
    #   $? = 0 (true) or 1 (false)

    if ! ($OPKG_CMD list-installed | $GREP_CMD -q -F "$1"); then
        DebugIPKG "'$1'" 'not installed'
        return 1
    else
        DebugIPKG "'$1'" 'installed'
        return 0
    fi

    }

# all functions below here do-not generate global or logged errors

#### DisplayAs... functions are for direct screen output only.

DisplayAsTitleHelpPackage()
    {

    # $1 = description
    # $2 = example syntax

    echo -e "\n$(FormatAsHelpPackage) is ONE of the following:\n"
    UnsetLineSpace

    }

DisplayAsTitleHelpOption()
    {

    # $1 = description
    # $2 = example syntax

    echo -e "$(FormatAsHelpOption) usage examples:"
    UnsetLineSpace

    }

DisplayAsHelpExample()
    {

    # $1 = description
    # $2 = example syntax

    if [[ ${1: -1} = '!' ]]; then
        printf "\n  - %s \n       ./%s\n" "$(tr "[a-z]" "[A-Z]" <<< "${1:0:1}")${1:1}" "$LOADER_SCRIPT_FILE $2"
    else
        printf "\n  - %s:\n       ./%s\n" "$(tr "[a-z]" "[A-Z]" <<< "${1:0:1}")${1:1}" "$LOADER_SCRIPT_FILE $2"
    fi

    UnsetLineSpace

    }

DisplayAsHelpPackageNameExample()
    {

    # $1 = description
    # $2 = example syntax

    printf "    %s\t%s\n" "$1" "$2"

    }

IsQPKGUserInstallable()
    {

    # input:
    #   $1 = package name to check

    # output:
    #   $? = 0 (true) or 1 (false)

    [[ ${#SHERPA_QPKG_NAME[@]} -eq 0 || ${#SHERPA_QPKG_ABBRVS[@]} -eq 0 ]] && return 1

    local returncode=1
    local package_index=0

    for package_index in "${!SHERPA_QPKG_NAME[@]}"; do
        if [[ ${SHERPA_QPKG_NAME[$package_index]} = "$1" && -n ${SHERPA_QPKG_ABBRVS[$package_index]} ]]; then
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

    local package=''

    for package in "${QPKGS_to_install[@]}"; do
        [[ $package = "$1" ]] && return 0
    done

    for package in "${QPKGS_to_upgrade[@]}"; do
        [[ $package = "$1" ]] && return 0
    done

    return 1

    }

IsQPKGInstalled()
    {

    # input:
    #   $1 = package name to check

    # output:
    #   $? = 0 (true) or 1 (false)

    [[ $($GETCFG_CMD "$1" RC_Number -d 0 -f $APP_CENTER_CONFIG_PATHFILE) -gt 0 ]]

    }

IsNotQPKGInstalled()
    {

    # input:
    #   $1 = package name to check

    # output:
    #   $? = 0 (true) or 1 (false)

    ! IsQPKGInstalled "$1"

    }

IsQPKGEnabled()
    {

    # input:
    #   $1 = package name to check

    # output:
    #   $? = 0 (true) or 1 (false)

    [[ $($GETCFG_CMD "$1" Enable -u -f $APP_CENTER_CONFIG_PATHFILE) = 'TRUE' ]]

    }

IsNotQPKGEnabled()
    {

    # input:
    #   $1 = package name to check

    # output:
    #   $? = 0 (true) or 1 (false)

    ! IsQPKGEnabled "$1"

    }

IsQPKGUpgradable()
    {

    # input:
    #   $1 = QPKG name to check if upgrade available

    # output:
    #   $? = 0 (true) or 1 (false)

    [[ -n $1 && ${#QPKGS_upgradable[@]} -gt 0 && ${QPKGS_upgradable[*]} =~ "$1" ]]

    }

IsNotQPKGUpgradable()
    {

    ! IsQPKGUpgradable "$1"

    }

MatchAbbrvToQPKGName()
    {

    # input:
    #   $1 = a potential package abbreviation supplied by user

    # output:
    #   $? = 0 (matched) or 1 (unmatched)
    #   stdout = matched installable package name (empty if unmatched)

    [[ ${#SHERPA_QPKG_NAME[@]} -eq 0 || ${#SHERPA_QPKG_ABBRVS[@]} -eq 0 ]] && return 1

    local returncode=1
    local abbs=()
    local package_index=0
    local abb_index=0

    for package_index in "${!SHERPA_QPKG_NAME[@]}"; do
        abbs=(${SHERPA_QPKG_ABBRVS[$package_index]})
        for abb_index in "${!abbs[@]}"; do
            if [[ ${abbs[$abb_index]} = "$1" ]]; then
                echo "${SHERPA_QPKG_NAME[$package_index]}"
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
    msgs=$(eval "$1" 2>&1)
    result=$?
    FormatAsResultAndStdout "$result" "$msgs" >> "$2"

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
    msgs=$(eval "$1" 2>&1 | $TEE_CMD /dev/fd/5)
    result=$?
    FormatAsResultAndStdout "$result" "$msgs" >> "$2"

    return $result

    }

DeDupeWords()
    {

    [[ -z $1 ]] && return 1

    $TR_CMD ' ' '\n' <<< "$1" | $SORT_CMD | $UNIQ_CMD | $TR_CMD '\n' ' ' | $SED_CMD 's|^[[:blank:]]*||;s|[[:blank:]]*$||'

    }

FileMatchesMD5()
    {

    # input:
    #   $1 = pathfilename to generate an MD5 checksum for
    #   $2 = MD5 checksum to compare against

    [[ -z $1 || -z $2 ]] && return 1

    [[ $($MD5SUM_CMD "$1" | $CUT_CMD -f1 -d' ') = "$2" ]]

    }

ProgressUpdater()
    {

    # input:
    #   $1 = message to display

    if [[ $1 != "$previous_msg" ]]; then
        temp="$1"
        current_length=$((${#temp}+1))

        if [[ $current_length -lt $previous_length ]]; then
            appended_length=$((current_length-previous_length))
            # backspace to start of previous msg, print new msg, add additional spaces, then backspace to end of msg
            printf "%${previous_length}s" | $TR_CMD ' ' '\b'; echo -n "$1 "; printf "%${appended_length}s"; printf "%${appended_length}s" | $TR_CMD ' ' '\b'
        else
            # backspace to start of previous msg, print new msg
            printf "%${previous_length}s" | $TR_CMD ' ' '\b'; echo -n "$1 "
        fi

        previous_length=$current_length
        previous_msg="$1"
    fi

    }

SetShowHelp()
    {

    SetAbort

    IsShowHelp && return

    _show_help_flag=true
    DebugVar _show_help_flag

    }

UnsetShowHelp()
    {

    IsNotShowHelp && return

    _show_help_flag=false
    DebugVar _show_help_flag

    }

IsShowHelp()
    {

    [[ $_show_help_flag = true ]]

    }

IsNotShowHelp()
    {

    [[ $_show_help_flag != true ]]

    }

SetShowProblemHelp()
    {

    SetAbort

    IsShowProblemHelp && return

    _show_problem_help_flag=true
    DebugVar _show_problem_help_flag

    }

UnsetShowProblemHelp()
    {

    IsNotShowProblemHelp && return

    _show_problem_help_flag=false
    DebugVar _show_problem_help_flag

    }

IsShowProblemHelp()
    {

    [[ $_show_problem_help_flag = true ]]

    }

IsNotShowProblemHelp()
    {

    [[ $_show_problem_help_flag != true ]]

    }

SetShowTipsHelp()
    {

    SetAbort

    IsShowTipsHelp && return

    _show_tips_help_flag=true
    DebugVar _show_tips_help_flag

    }

UnsetShowTipsHelp()
    {

    IsNotShowTipsHelp && return

    _show_tips_help_flag=false
    DebugVar _show_tips_help_flag

    }

IsShowTipsHelp()
    {

    [[ $_show_tips_help_flag = true ]]

    }

IsNotShowTipsHelp()
    {

    [[ $_show_tips_help_flag != true ]]

    }

SetLogViewOnly()
    {

    SetAbort

    IsLogViewOnly && return

    _logview_only_flag=true
    DebugVar _logview_only_flag

    }

UnsetLogViewOnly()
    {

    IsNotLogViewOnly && return

    _logview_only_flag=false
    DebugVar _logview_only_flag

    }

IsLogViewOnly()
    {

    [[ $_logview_only_flag = true ]]

    }

IsNotLogViewOnly()
    {

    [[ $_logview_only_flag != true ]]

    }

SetVersionOnly()
    {

    SetAbort

    IsVersionOnly && return

    _version_only_flag=true
    DebugVar _version_only_flag

    }

UnsetVersionOnly()
    {

    IsNotVersionOnly && return

    _version_only_flag=false
    DebugVar _version_only_flag

    }

IsVersionOnly()
    {

    [[ $_version_only_flag = true ]]

    }

IsNotVersionOnly()
    {

    [[ $_version_only_flag != true ]]

    }

SetLogPasteOnly()
    {

    SetAbort

    IsLogPasteOnly && return

    _logpaste_only_flag=true
    DebugVar _logpaste_only_flag

    }

UnsetLogPasteOnly()
    {

    IsNotLogPasteOnly && return

    _logpaste_only_flag=false
    DebugVar _logpaste_only_flag

    }

IsLogPasteOnly()
    {

    [[ $_logpaste_only_flag = true ]]

    }

IsNotLogPasteOnly()
    {

    [[ $_logpaste_only_flag != true ]]

    }

SetPIPInstall()
    {

    IsPIPInstall && return

    _pip_install_flag=true
    DebugVar _pip_install_flag

    }

UnsetPIPInstall()
    {

    IsNotPIPInstall && return

    _pip_install_flag=false
    DebugVar _pip_install_flag

    }

IsPIPInstall()
    {

    [[ $_pip_install_flag = true ]]

    }

IsNotPIPInstall()
    {

    [[ $_pip_install_flag != true ]]

    }

SetError()
    {

    SetAbort

    IsError && return

    _script_error_flag=true
    DebugVar _script_error_flag

    }

UnsetError()
    {

    IsNotError && return

    _script_error_flag=false
    DebugVar _script_error_flag

    }

IsError()
    {

    [[ $_script_error_flag = true ]]

    }

IsNotError()
    {

    [[ $_script_error_flag != true ]]

    }

SetAbort()
    {

    IsAbort && return

    _script_abort_flag=true
    DebugVar _script_abort_flag

    }

UnsetAbort()
    {

    IsNotAbort && return

    _script_abort_flag=false
    DebugVar _script_abort_flag

    }

IsAbort()
    {

    [[ $_script_abort_flag = true ]]

    }

IsNotAbort()
    {

    [[ $_script_abort_flag != true ]]

    }

SetCheckDependencies()
    {

    IsCheckDependencies && return

    _check_dependencies_flag=true
    DebugVar _check_dependencies_flag

    }

UnsetCheckDependencies()
    {

    IsNotCheckDependencies && return

    _check_dependencies_flag=false
    DebugVar _check_dependencies_flag

    }

IsCheckDependencies()
    {

    [[ $_check_dependencies_flag = true ]]

    }

IsNotCheckDependencies()
    {

    [[ $_check_dependencies_flag != true ]]

    }

SetShowAbbreviations()
    {

    SetAbort

    IsShowAbbreviations && return

    _show_abbreviations_flag=true
    DebugVar _show_abbreviations_flag

    }

UnsetShowAbbreviations()
    {

    IsNotShowAbbreviations && return

    _show_abbreviations_flag=false
    DebugVar _show_abbreviations_flag

    }

IsShowAbbreviations()
    {

    [[ $_show_abbreviations_flag = true ]]

    }

IsNotShowAbbreviations()
    {

    [[ $_show_abbreviations_flag != true ]]

    }

SetShowInstallerOutcome()
    {

    IsShowInstallerOutcome && return

    _show_installer_outcome_flag=true
    DebugVar _show_installer_outcome_flag

    }

UnsetShowInstallerOutcome()
    {

    IsNotShowInstallerOutcome && return

    _show_installer_outcome_flag=false
    DebugVar _show_installer_outcome_flag

    }

IsShowInstallerOutcome()
    {

    [[ $_show_installer_outcome_flag = true ]]

    }

IsNotShowInstallerOutcome()
    {

    [[ $_show_installer_outcome_flag != true ]]

    }

SetLogToFile()
    {

    IsLogToFile && return

    _log_to_file=true
    DebugVar _log_to_file

    }

UnsetLogToFile()
    {

    IsNotLogToFile && return

    _log_to_file=false
    DebugVar _log_to_file

    }

IsLogToFile()
    {

    [[ $_log_to_file = true ]]

    }

IsNotLogToFile()
    {

    [[ $_log_to_file != true ]]

    }

SetVisibleDebugging()
    {

    IsVisibleDebugging && return

    _show_debugging_flag=true
    DebugVar _show_debugging_flag

    }

UnsetVisibleDebugging()
    {

    IsNotVisibleDebugging && return

    _show_debugging_flag=false
    DebugVar _show_debugging_flag

    }

IsVisibleDebugging()
    {

    [[ $_show_debugging_flag = true ]]

    }

IsNotVisibleDebugging()
    {

    [[ $_show_debugging_flag != true ]]

    }

SetDevMode()
    {

    SetVisibleDebugging

    IsDevMode && return

    _dev_mode_flag=true
    DebugVar _dev_mode_flag

    }

UnsetDevMode()
    {

    UnsetVisibleDebugging

    IsNotDevMode && return

    _dev_mode_flag=false
    DebugVar _dev_mode_flag

    }

IsDevMode()
    {

    [[ $_dev_mode_flag = true ]]

    }

IsNotDevMode()
    {

    [[ $_dev_mode_flag != true ]]

    }

SetSuggestIssue()
    {

    IsSuggestIssue && return

    _suggest_issue_flag=true
    DebugVar _suggest_issue_flag

    }

UnsetSuggestIssue()
    {

    IsNotSuggestIssue && return

    _suggest_issue_flag=false
    DebugVar _suggest_issue_flag

    }

IsSuggestIssue()
    {

    [[ $_suggest_issue_flag = true ]]

    }

IsNotSuggestIssue()
    {

    [[ $_suggest_issue_flag != true ]]

    }

SetInstallAllApps()
    {

    IsInstallAllApps && return

    _install_all_apps_flag=true
    DebugVar _install_all_apps_flag

    }

UnsetInstallAllApps()
    {

    IsNotInstallAllApps && return

    _install_all_apps_flag=false
    DebugVar _install_all_apps_flag

    }

IsInstallAllApps()
    {

    [[ $_install_all_apps_flag = true ]]

    }

IsNotInstallAllApps()
    {

    [[ $_install_all_apps_flag != true ]]

    }

SetUninstallAllApps()
    {

    IsUninstallAllApps && return

    _uninstall_all_apps_flag=true
    DebugVar _uninstall_all_apps_flag

    }

UnsetUninstallAllApps()
    {

    IsNotUninstallAllApps && return

    _uninstall_all_apps_flag=false
    DebugVar _uninstall_all_apps_flag

    }

IsUninstallAllApps()
    {

    [[ $_uninstall_all_apps_flag = true ]]

    }

IsNotUninstallAllApps()
    {

    [[ $_uninstall_all_apps_flag != true ]]

    }

SetRestartAllApps()
    {

    IsRestartAllApps && return

    _restart_all_apps_flag=true
    DebugVar _restart_all_apps_flag

    }

UnsetRestartAllApps()
    {

    IsNotRestartAllApps && return

    _restart_all_apps_flag=false
    DebugVar _restart_all_apps_flag

    }

IsRestartAllApps()
    {

    [[ $_restart_all_apps_flag = true ]]

    }

IsNotRestartAllApps()
    {

    [[ $_restart_all_apps_flag != true ]]

    }

SetUpgradeAllApps()
    {

    IsUpgradeAllApps && return

    _upgrade_all_apps_flag=true
    DebugVar _upgrade_all_apps_flag

    }

UnsetUpgradeAllApps()
    {

    IsNotUpgradeAllApps && return

    _upgrade_all_apps_flag=false
    DebugVar _upgrade_all_apps_flag

    }

IsUpgradeAllApps()
    {

    [[ $_upgrade_all_apps_flag = true ]]

    }

IsNotUpgradeAllApps()
    {

    [[ $_upgrade_all_apps_flag != true ]]

    }

SetBackupAllApps()
    {

    IsBackupAllApps && return

    _backup_all_apps_flag=true
    DebugVar _backup_all_apps_flag

    }

UnsetBackupAllApps()
    {

    IsNotBackupAllApps && return

    _backup_all_apps_flag=false
    DebugVar _backup_all_apps_flag

    }

IsBackupAllApps()
    {

    [[ $_backup_all_apps_flag = true ]]

    }

IsNotBackupAllApps()
    {

    [[ $_backup_all_apps_flag != true ]]

    }

SetRestoreAllApps()
    {

    IsRestoreAllApps && return

    _restore_all_apps_flag=true
    DebugVar _restore_all_apps_flag

    }

UnsetRestoreAllApps()
    {

    IsNotRestoreAllApps && return

    _restore_all_apps_flag=false
    DebugVar _restore_all_apps_flag

    }

IsRestoreAllApps()
    {

    [[ $_restore_all_apps_flag = true ]]

    }

IsNotRestoreAllApps()
    {

    [[ $_restore_all_apps_flag != true ]]

    }

SetStatusAllApps()
    {

    IsStatusAllApps && return

    _status_all_apps_flag=true
    DebugVar _status_all_apps_flag

    }

UnsetStatusAllApps()
    {

    IsNotStatusAllApps && return

    _status_all_apps_flag=false
    DebugVar _status_all_apps_flag

    }

IsStatusAllApps()
    {

    [[ $_status_all_apps_flag = true ]]

    }

IsNotStatusAllApps()
    {

    [[ $_status_all_apps_flag != true ]]

    }

SetLineSpace()
    {

    IsLineSpace && return

    _line_space_flag=true

    }

UnsetLineSpace()
    {

    IsNotLineSpace && return

    _line_space_flag=false

    }

IsLineSpace()
    {

    [[ $_line_space_flag = true ]]

    }

IsNotLineSpace()
    {

    [[ $_line_space_flag != true ]]

    }

#### FormatAs... functions always output formatted info to be used as part of another string. These shouldn't be used for direct screen output.

FormatAsPlural()
    {

    [[ $1 -ne 1 ]] && echo 's'

    }

FormatAsISO()
    {

    echo "$1" | $AWK_CMD 'BEGIN{ u[0]="B"; u[1]="kB"; u[2]="MB"; u[3]="GB"} { n = $1; i = 0; while(n > 1000) { i+=1; n= int((n/1000)+0.5) } print n u[i] } '

    }

FormatAsScriptTitle()
    {

    ColourTextBrightWhite sherpa

    }

FormatAsHelpPackage()
    {

    ColourTextBrightYellow '[PACKAGE]'

    }

FormatAsHelpOption()
    {

    ColourTextBrightOrange '[OPTION]'

    }

FormatAsPackageName()
    {

    echo "'$1'"

    }

FormatAsFileName()
    {

    echo "($1)"

    }

FormatAsURL()
    {

    ColourTextUnderlinedBlue "$1"

    }

FormatAsExitcode()
    {

    echo "[$1]"

    }

FormatAsCommand()
    {

    echo "= command: '$1'"

    }

FormatAsStdout()
    {

    echo '= / / / / / stdout begins below \ \ \ \ \'
    echo "$1"
    echo '= \ \ \ \ \ stdout is complete / / / / /'

    }

FormatAsResult()
    {

    if [[ $1 -eq 0 ]]; then
        echo "= result: $(FormatAsExitcode "$1")"
    else
        echo "! result: $(FormatAsExitcode "$1")"
    fi

    }

FormatAsScript()
    {

    echo 'SCRIPT'

    }

FormatAsStage()
    {

    echo 'STAGE'

    }

FormatAsHardware()
    {

    echo 'HARDWARE'

    }

FormatAsFirmware()
    {

    echo 'FIRMWARE'

    }

FormatAsUserspace()
    {

    echo 'USERSPACE'

    }

FormatAsResultAndStdout()
    {

    if [[ $1 -eq 0 ]]; then
        echo "= result: $(FormatAsExitcode "$1") / / / / / stdout begins below \ \ \ \ \ "
    else
        echo "! result: $(FormatAsExitcode "$1") / / / / / stdout begins below \ \ \ \ \ "
    fi

    echo "$2"
    echo '= \ \ \ \ \ stdout is complete / / / / /'

    }

DisplayLineSpace()
    {

    if IsNotLineSpace; then
        if IsNotVisibleDebugging && IsNotVersionOnly; then
            SetLineSpace
            echo
        fi
    fi

    }

#### Debug... functions are used for formatted debug information output. This may be to screen, file or both.

DebugInfoThickSeparator()
    {

    DebugInfo "$(printf '%0.s=' {1..76})"

    }

DebugInfoThinSeparator()
    {

    DebugInfo "$(printf '%0.s-' {1..76})"

    }

DebugErrorThinSeparator()
    {

    DebugError "$(printf '%0.s-' {1..76})"

    }

DebugLogThinSeparator()
    {

    DebugLog "$(printf '%0.s-' {1..76})"

    }

DebugTimerStageStart()
    {

    # output:
    #   stdout = current time in seconds

    $DATE_CMD +%s

    if IsNotVisibleDebugging; then
        DebugInfoThinSeparator
        DebugStage 'start stage timer'
    fi

    }

DebugTimerStageEnd()
    {

    # input:
    #   $1 = start time in seconds

    DebugStage 'elapsed time' "$(ConvertSecsToMinutes "$(($($DATE_CMD +%s)-$([[ -n $1 ]] && echo "$1" || echo "1")))")"
    DebugInfoThinSeparator

    }

DebugScript()
    {

    DebugDetected $(FormatAsScript) "$1" "$2"

    }

DebugStage()
    {

    DebugDetected $(FormatAsStage) "$1" "$2"

    }

DebugHardware()
    {

    DebugDetected $(FormatAsHardware) "$1" "$2"

    }

DebugHardwareWarning()
    {

    DebugDetectedWarning $(FormatAsHardware) "$1" "$2"

    }

DebugFirmware()
    {

    DebugDetected $(FormatAsFirmware) "$1" "$2"

    }

DebugUserspace()
    {

    DebugDetected $(FormatAsUserspace) "$1" "$2"

    }

DebugUserspaceWarning()
    {

    DebugDetectedWarning $(FormatAsUserspace) "$1" "$2"

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

    DebugThis "(<<) ${FUNCNAME[1]}() [$code_pointer]"

    }

DebugProc()
    {

    DebugThis "(==) $1 ..."

    }

DebugDone()
    {

    DebugThis "(--) $1"

    }

DebugDetectedWarning()
    {

    if [[ -z $3 ]]; then
        DebugThis "(WW) $(printf "%9s: %19s\n" "$1" "$2")"
    else
        DebugThis "(WW) $(printf "%9s: %19s: %-s\n" "$1" "$2" "$3")"
    fi

    }

DebugDetected()
    {

    if [[ -z $3 ]]; then
        DebugThis "(**) $(printf "%9s: %19s\n" "$1" "$2")"
    else
        DebugThis "(**) $(printf "%9s: %19s: %-s\n" "$1" "$2" "$3")"
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

    IsVisibleDebugging && ShowAsDebug "$1"
    WriteAsDebug "$1"

    }

DebugErrorFile()
    {

    # Add the contents of specified pathfile $1 to the runtime log

    local linebuff=''

    DebugLogThinSeparator
    DebugLog "$1"
    DebugLogThinSeparator

    while read -r linebuff; do
        DebugLog "$linebuff"
    done < "$1"

    DebugLogThinSeparator

    }

#### ShowAs... functions output formatted info to screen and (usually) to debug log.

ShowAsInfo()
    {

    WriteToDisplay_SameLine "$(ColourTextBrightWhite info)" "$1"
    WriteToLog info "$1"

    }

ShowAsProc()
    {

    WriteToDisplay_SameLine "$(ColourTextBrightOrange proc)" "$1 ..."
    WriteToLog proc "$1 ..."

    }

ShowAsProcLong()
    {

    ShowAsProc "$1 - this may take a while"

    }

ShowAsDebug()
    {

    WriteToDisplay_SameLine "$(ColourTextBlackOnCyan dbug)" "$1"

    }

ShowAsNote()
    {

    WriteToDisplay_NewLine "$(ColourTextBrightYellow note)" "$1"
    WriteToLog note "$1"

    }

ShowAsQuiz()
    {

    WriteToDisplay_SameLine "$(ColourTextBrightOrangeBlink quiz)" "$1: "
    WriteToLog quiz "$1:"

    }

ShowAsQuizDone()
    {

    WriteToDisplay_NewLine "$(ColourTextBrightOrange quiz)" "$1"

    }

ShowAsDone()
    {

    WriteToDisplay_NewLine "$(ColourTextBrightGreen 'done')" "$1"
    WriteToLog 'done' "$1"

    }

ShowAsWarning()
    {

    WriteToDisplay_NewLine "$(ColourTextBrightOrangeBlink warn)" "$1"
    WriteToLog warn "$1"

    }

ShowAsAbort()
    {

    local capitalised="$(tr "[a-z]" "[A-Z]" <<< "${1:0:1}")${1:1}"      # use any available 'tr'

    SetError
    WriteToDisplay_NewLine "$(ColourTextBrightRed fail)" "$capitalised: aborting ..."
    WriteToLog fail "$capitalised: aborting"

    }

ShowAsError()
    {

    local capitalised="$(tr "[a-z]" "[A-Z]" <<< "${1:0:1}")${1:1}"      # use any available 'tr'

    SetError
    WriteToDisplay_NewLine "$(ColourTextBrightRed fail)" "$capitalised"
    WriteToLog fail "$capitalised."

    }

### WriteAs... functions - to be determined.

WriteAsDebug()
    {

    WriteToLog dbug "$1"

    }

WriteToDisplay_SameLine()
    {

    # Writes a new message without newline (unless in debug mode)

    # input:
    #   $1 = pass/fail
    #   $2 = message

    previous_msg=$(printf "%-10s: %s" "$1" "$2")

    echo -n "$previous_msg"; IsVisibleDebugging && echo
    UnsetLineSpace

    return 0

    }

WriteToDisplay_NewLine()
    {

    # Updates the previous message

    # input:
    #   $1 = pass/fail
    #   $2 = message

    # output:
    #   stdout = overwrites previous message with updated message
    #   $previous_length
    #   $appended_length

    local new_message=''
    local strbuffer=''
    local new_length=0

    new_message=$(printf "%-10s: %s" "$1" "$2")

    if [[ $new_message != "$previous_msg" ]]; then
        previous_length=$((${#previous_msg}+1))
        new_length=$((${#new_message}+1))

        # jump to start of line, print new msg
        strbuffer=$(echo -en "\r$new_message ")

        # if new msg is shorter then add spaces to end to cover previous msg
        if [[ $new_length -lt $previous_length ]]; then
            appended_length=$((new_length-previous_length))
            strbuffer+=$(printf "%${appended_length}s")
        fi

        echo "$strbuffer"
        UnsetLineSpace
    fi

    return 0

    }

WriteToLog()
    {

    # input:
    #   $1 = pass/fail
    #   $2 = message

    [[ -z $DEBUG_LOG_PATHFILE ]] && return 1
    IsNotLogToFile && return

    printf "%-4s: %s\n" "$(StripANSI "$1")" "$(StripANSI "$2")" >> "$DEBUG_LOG_PATHFILE"

    }

ColourTextBrightGreen()
    {

    echo -en '\033[1;32m'"$(ColourReset "$1")"

    }

ColourTextBrightYellow()
    {

    echo -en '\033[1;33m'"$(ColourReset "$1")"

    }

ColourTextBrightYellowBlink()
    {

    echo -en '\033[1;5;33m'"$(ColourReset "$1")"

    }

ColourTextBrightOrange()
    {

    echo -en '\033[1;38;5;214m'"$(ColourReset "$1")"

    }

ColourTextBrightOrangeBlink()
    {

    echo -en '\033[1;5;38;5;214m'"$(ColourReset "$1")"

    }

ColourTextBrightRed()
    {

    echo -en '\033[1;31m'"$(ColourReset "$1")"

    }

ColourTextUnderlinedBlue()
    {

    echo -en '\033[4;94m'"$(ColourReset "$1")"

    }

ColourTextBlackOnCyan()
    {

    echo -en '\033[30;46m'"$(ColourReset "$1")"

    }

ColourTextBrightWhite()
    {

    echo -en '\033[1;97m'"$(ColourReset "$1")"

    }

ColourReset()
    {

    echo -en "$1"'\033[0m'

    }

StripANSI()
    {

    # found here: https://www.commandlinefu.com/commands/view/3584/remove-color-codes-special-characters-with-sed
    # QTS 4.2.6 BusyBox 'sed' doesn't fully support extended regexes, so this only works with a real 'sed'.

    if [[ -e $GNU_SED_CMD ]]; then
        $GNU_SED_CMD -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" <<< "$1"
    else
        echo "$1"
    fi

    }

ConvertSecsToMinutes()
    {

    # http://stackoverflow.com/questions/12199631/convert-seconds-to-hours-minutes-seconds

    # input:
    #   $1 = a time in seconds to convert to 'hh:mm:ss'

    ((h=${1}/3600))
    ((m=(${1}%3600)/60))
    ((s=${1}%60))

    printf "%02dh:%02dm:%02ds\n" $h $m $s

    }

CTRL_C_Captured()
    {

    RemoveDirSizeMonitorFlagFile

    exit

    }

Init || exit 1

LogRuntimeParameters
DownloadQPKGs
RemoveUnwantedQPKGs
InstallQPKGIndeps
InstallQPKGIndepsAddons
InstallTargetQPKG
Cleanup
ShowResult
RemoveLock
IsNotVersionOnly && IsNotVisibleDebugging && DisplayLineSpace

IsError && exit 1

exit
