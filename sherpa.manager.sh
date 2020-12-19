#!/usr/bin/env bash
#
# sherpa.manager.sh - (C)opyright (C) 2017-2020 OneCD [one.cd.only@gmail.com]
#
# This is the management script for the sherpa mini-package-manager.
# It's automatically downloaded via the 'sherpa.loader.sh' script in the 'sherpa' QPKG.
#
# So, blame OneCD if it all goes horribly wrong. ;)
#
# For more info: https://forum.qnap.com/viewtopic.php?f=320&t=132373
#
# Tested on:
#  GNU bash, version 3.2.57(2)-release (i686-pc-linux-gnu)
#  GNU bash, version 3.2.57(1)-release (aarch64-QNAP-linux-gnu)
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
#         variables: lowercase_with_inline_underscores (except for 'returncode', 'resultcode')
# "class" variables: _lowercase_with_leading_and_inline_underscores (these should only be managed via their specific functions)
#         constants: UPPERCASE_WITH_INLINE_UNDERSCORES (these are also set as readonly)
#           indents: 1 x tab (converted to 4 x spaces to suit GitHub web-display)
#
# Notes:
#   If on-screen line-spacing is required, this should only be done by the next function that outputs to display.
#   Display functions should never finish by putting an empty line on-screen for spacing.

readonly USER_ARGS_RAW=$*

Session.Init()
    {

    IsQNAP || return 1
    DebugFuncEntry
    ShowAsProc 'important stuff'
    readonly SCRIPT_STARTSECONDS=$(/bin/date +%s)
    export LC_CTYPE=C

    readonly PROJECT_NAME=sherpa
    readonly MANAGER_SCRIPT_VERSION=201219

    # cherry-pick required binaries
    readonly AWK_CMD=/bin/awk
    readonly BUSYBOX_CMD=/bin/busybox
    readonly CAT_CMD=/bin/cat
    readonly CHMOD_CMD=/bin/chmod
    readonly DATE_CMD=/bin/date
    readonly GREP_CMD=/bin/grep
    readonly HOSTNAME_CMD=/bin/hostname
    readonly MD5SUM_CMD=/bin/md5sum
    readonly PING_CMD=/bin/ping
    readonly SED_CMD=/bin/sed
    readonly SH_CMD=/bin/sh
    readonly SLEEP_CMD=/bin/sleep
    readonly TAR_CMD=/bin/tar
    readonly TOUCH_CMD=/bin/touch
    readonly UNAME_CMD=/bin/uname
    readonly UNIQ_CMD=/bin/uniq

    readonly CURL_CMD=/sbin/curl
    readonly GETCFG_CMD=/sbin/getcfg
    readonly QPKG_SERVICE_CMD=/sbin/qpkg_service
    readonly APP_CENTER_NOTIFIER=/sbin/qpkg_cli     # only needed for QTS 4.5.1-and-later
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

    # check required binaries are present
    IsSysFileExist $AWK_CMD || return 1
    IsSysFileExist $BUSYBOX_CMD || return 1
    IsSysFileExist $CAT_CMD || return 1
    IsSysFileExist $CHMOD_CMD || return 1
    IsSysFileExist $DATE_CMD || return 1
    IsSysFileExist $GREP_CMD || return 1
    IsSysFileExist $HOSTNAME_CMD || return 1
    IsSysFileExist $MD5SUM_CMD || return 1
    IsSysFileExist $PING_CMD || return 1
    IsSysFileExist $SED_CMD || return 1
    IsSysFileExist $SLEEP_CMD || return 1
    IsSysFileExist $TAR_CMD || return 1
    IsSysFileExist $TOUCH_CMD || return 1
    IsSysFileExist $UNAME_CMD || return 1
    IsSysFileExist $UNIQ_CMD || return 1

    IsSysFileExist $CURL_CMD || return 1
    IsSysFileExist $GETCFG_CMD || return 1
    IsSysFileExist $QPKG_SERVICE_CMD || return 1
    IsSysFileExist $RMCFG_CMD || return 1
    IsSysFileExist $SETCFG_CMD || return 1

    IsSysFileExist $BASENAME_CMD || return 1
    IsSysFileExist $CUT_CMD || return 1
    IsSysFileExist $DIRNAME_CMD || return 1
    IsSysFileExist $DU_CMD || return 1
    IsSysFileExist $HEAD_CMD || return 1
    IsSysFileExist $READLINK_CMD || return 1
    [[ ! -e $SORT_CMD ]] && ln -s "$BUSYBOX_CMD" "$SORT_CMD"   # sometimes, 'sort' goes missing from QTS. Don't know why.
    IsSysFileExist $SORT_CMD || return 1
    IsSysFileExist $TAIL_CMD || return 1
    IsSysFileExist $TEE_CMD || return 1
    IsSysFileExist $UNZIP_CMD || return 1
    IsSysFileExist $UPTIME_CMD || return 1
    IsSysFileExist $WC_CMD || return 1

    IsSysFileExist $Z7_CMD || return 1
    IsSysFileExist $ZIP_CMD || return 1

    readonly GNU_FIND_CMD=/opt/bin/find
    readonly GNU_GREP_CMD=/opt/bin/grep
    readonly GNU_LESS_CMD=/opt/bin/less
    readonly GNU_SED_CMD=/opt/bin/sed
    readonly OPKG_CMD=/opt/bin/opkg

    [[ ! -e /dev/fd ]] && ln -s /proc/self/fd /dev/fd   # sometimes, '/dev/fd' isn't created by QTS. Don't know why.

    # paths and files
    local -r LOADER_SCRIPT_FILE=$PROJECT_NAME.loader.sh
    readonly MANAGER_SCRIPT_FILE=$PROJECT_NAME.manager.sh

    Session.LockFile.Claim /var/run/"$LOADER_SCRIPT_FILE".pid || return 1

    local -r DEBUG_LOG_FILE=$PROJECT_NAME.debug.log
    readonly INSTALL_LOG_FILE=install.log
    readonly REINSTALL_LOG_FILE=reinstall.log
    readonly UNINSTALL_LOG_FILE=uninstall.log
    readonly DOWNLOAD_LOG_FILE=download.log
    readonly START_LOG_FILE=start.log
    readonly STOP_LOG_FILE=stop.log
    readonly RESTART_LOG_FILE=restart.log
    readonly UPDATE_LOG_FILE=update.log
    readonly UPGRADE_LOG_FILE=upgrade.log
    readonly BACKUP_LOG_FILE=backup.log
    readonly RESTORE_LOG_FILE=restore.log
    readonly ENABLE_LOG_FILE=enable.log
    readonly DISABLE_LOG_FILE=disable.log
    readonly DEFAULT_SHARES_PATHFILE=/etc/config/def_share.info
    local -r ULINUX_PATHFILE=/etc/config/uLinux.conf
    readonly PLATFORM_PATHFILE=/etc/platform.conf
    readonly EXTERNAL_PACKAGE_ARCHIVE_PATHFILE=/opt/var/opkg-lists/entware
    local -r PROJECT_REPO_URL=https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/main/QPKGs
    readonly APP_CENTER_CONFIG_PATHFILE=/etc/config/qpkg.conf
    local -r PROJECT_PATH=$($GETCFG_CMD "$PROJECT_NAME" Install_Path -f "$APP_CENTER_CONFIG_PATHFILE")
    readonly DEBUG_LOG_PATHFILE=$PROJECT_PATH/$DEBUG_LOG_FILE
    readonly WORK_PATH=$PROJECT_PATH/cache
    readonly COMPILED_OBJECTS_URL=https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/main/compiled.objects
    readonly COMPILED_OBJECTS_PATHFILE=$WORK_PATH/compiled.objects
    readonly EXTERNAL_PACKAGE_LIST_PATHFILE=$WORK_PATH/Packages
    readonly LOGS_PATH=$PROJECT_PATH/logs
    readonly SESSION_LAST_PATHFILE=$LOGS_PATH/session.last.log
    readonly SESSION_TAIL_PATHFILE=$LOGS_PATH/session.tail.log
    readonly PREVIOUS_PIP3_MODULE_LIST=$WORK_PATH/pip3.prev.installed.list
    readonly PREVIOUS_OPKG_PACKAGE_LIST=$WORK_PATH/opkg.prev.installed.list
    readonly QPKG_DL_PATH=$WORK_PATH/qpkgs
    readonly IPKG_DL_PATH=$WORK_PATH/ipkgs.downloads
    readonly IPKG_CACHE_PATH=$WORK_PATH/ipkgs
    readonly PIP_CACHE_PATH=$WORK_PATH/pips
    readonly COMPILED_OBJECTS_HASH=87ae259018a81f04bebaab73bf6147e8
    readonly DEBUG_LOG_DATAWIDTH=92

    if ! MakePath "$WORK_PATH" 'work'; then
        DebugFuncExit; return 1
    fi

    Objects.Compile

    # enable debug mode early if possible
    if [[ $USER_ARGS_RAW == *"debug"* || $USER_ARGS_RAW == *"verbose"* ]]; then
        Session.Debug.To.Screen.Set
    fi

    User.Opts.IgnoreFreeSpace.Text = ' --force-space'
    Session.Summary.Set
    Session.LineSpace.DontLogChanges
    Session.SkipPackageProcessing.DontLogChanges

    if ! MakePath "$LOGS_PATH" 'logs'; then
        DebugFuncExit; return 1
    fi

    Session.Backup.Path = "$($GETCFG_CMD SHARE_DEF defVolMP -f "$DEFAULT_SHARES_PATHFILE")/.qpkg_config_backup"

    if ! MakePath "$QPKG_DL_PATH" 'QPKG download'; then
        DebugFuncExit; return 1
    fi

    # errors can occur due to incompatible IPKGs (tried installing Entware-3x, then Entware-ng), so delete them first
    [[ -d $IPKG_DL_PATH ]] && rm -rf "$IPKG_DL_PATH"

    if ! MakePath "$IPKG_DL_PATH" 'IPKG download'; then
        DebugFuncExit; return 1
    fi

    [[ -d $IPKG_CACHE_PATH ]] && rm -rf "$IPKG_CACHE_PATH"

    if ! MakePath "$IPKG_CACHE_PATH" 'IPKG cache'; then
        DebugFuncExit; return 1
    fi

    [[ -d $PIP_CACHE_PATH ]] && rm -rf "$PIP_CACHE_PATH"

    if ! MakePath "$PIP_CACHE_PATH" 'PIP cache'; then
        DebugFuncExit; return 1
    fi

    readonly NAS_FIRMWARE=$($GETCFG_CMD System Version -f "$ULINUX_PATHFILE")
    readonly PACKAGE_VERSION=$(QPKG.InstalledVersion "$PROJECT_NAME")
    readonly NAS_BUILD=$($GETCFG_CMD System 'Build Number' -f "$ULINUX_PATHFILE")
    readonly INSTALLED_RAM_KB=$($GREP_CMD MemTotal /proc/meminfo | $CUT_CMD -f2 -d':' | $SED_CMD 's|kB||;s| ||g')
    readonly MIN_RAM_KB=1048576
    readonly LOG_TAIL_LINES=3000    # a full download and install of everything generates a session around 1600 lines, but include a bunch of opkg updates and it can get much longer.
    code_pointer=0
    pip3_cmd=/opt/bin/pip3
    local package=''
    [[ ${NAS_FIRMWARE//.} -lt 426 ]] && curl_insecure_arg=' --insecure' || curl_insecure_arg=''

    # sherpa-supported package details - parallel arrays
    SHERPA_QPKG_NAME=()             # internal QPKG name
        SHERPA_QPKG_ARCH=()         # QPKG supports this architecture
        SHERPA_QPKG_URL=()          # remote QPKG URL
        SHERPA_QPKG_MD5=()          # remote QPKG MD5
        SHERPA_QPKG_ABBRVS=()       # if set, this package is user-installable, and these abbreviations may be used to specify app
        SHERPA_QPKG_ESSENTIALS=()   # require these QPKGs to be installed
        SHERPA_QPKG_IPKGS_ADD=()    # require these IPKGs to be installed
        SHERPA_QPKG_IPKGS_REMOVE=() # require these IPKGs to be uninstalled

    SHERPA_QPKG_NAME+=(sherpa)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=("$PROJECT_REPO_URL"/sherpa/build/sherpa_201218.qpkg)
        SHERPA_QPKG_MD5+=(6a84dadf9aae7269eff72166ed0d5f19)
        SHERPA_QPKG_ABBRVS+=(sherpa)
        SHERPA_QPKG_ESSENTIALS+=('')
        SHERPA_QPKG_IPKGS_ADD+=('')
        SHERPA_QPKG_IPKGS_REMOVE+=('')

    SHERPA_QPKG_NAME+=(Entware)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=("$PROJECT_REPO_URL"/Entware/Entware_1.03std.qpkg)
        SHERPA_QPKG_MD5+=(da2d9f8d3442dd665ce04b9b932c9d8e)
        SHERPA_QPKG_ABBRVS+=('ew ent opkg entware')
        SHERPA_QPKG_ESSENTIALS+=('')
        SHERPA_QPKG_IPKGS_ADD+=('')
        SHERPA_QPKG_IPKGS_REMOVE+=('')

    SHERPA_QPKG_NAME+=(Par2)
        SHERPA_QPKG_ARCH+=(x86)
        SHERPA_QPKG_URL+=("$PROJECT_REPO_URL"/Par2/Par2_0.8.1.0_x86.qpkg)
        SHERPA_QPKG_MD5+=(996ffb92d774eb01968003debc171e91)
        SHERPA_QPKG_ABBRVS+=('par par2')        # applies to all 'Par2' packages
        SHERPA_QPKG_ESSENTIALS+=('')
        SHERPA_QPKG_IPKGS_ADD+=('')
        SHERPA_QPKG_IPKGS_REMOVE+=(par2cmdline)

    SHERPA_QPKG_NAME+=(Par2)
        SHERPA_QPKG_ARCH+=(x64)
        SHERPA_QPKG_URL+=("$PROJECT_REPO_URL"/Par2/Par2_0.8.1.0_x86_64.qpkg)
        SHERPA_QPKG_MD5+=(520472cc87d301704f975f6eb9948e38)
        SHERPA_QPKG_ABBRVS+=('')
        SHERPA_QPKG_ESSENTIALS+=('')
        SHERPA_QPKG_IPKGS_ADD+=('')
        SHERPA_QPKG_IPKGS_REMOVE+=(par2cmdline)

    SHERPA_QPKG_NAME+=(Par2)
        SHERPA_QPKG_ARCH+=(x31)
        SHERPA_QPKG_URL+=("$PROJECT_REPO_URL"/Par2/Par2_0.8.1.0_arm-x31.qpkg)
        SHERPA_QPKG_MD5+=(ce8af2e009eb87733c3b855e41a94f8e)
        SHERPA_QPKG_ABBRVS+=('')
        SHERPA_QPKG_ESSENTIALS+=('')
        SHERPA_QPKG_IPKGS_ADD+=('')
        SHERPA_QPKG_IPKGS_REMOVE+=(par2cmdline)

    SHERPA_QPKG_NAME+=(Par2)
        SHERPA_QPKG_ARCH+=(x41)
        SHERPA_QPKG_URL+=("$PROJECT_REPO_URL"/Par2/Par2_0.8.1.0_arm-x41.qpkg)
        SHERPA_QPKG_MD5+=(8516e45e704875cdd2cd2bb315c4e1e6)
        SHERPA_QPKG_ABBRVS+=('')
        SHERPA_QPKG_ESSENTIALS+=('')
        SHERPA_QPKG_IPKGS_ADD+=('')
        SHERPA_QPKG_IPKGS_REMOVE+=(par2cmdline)

    SHERPA_QPKG_NAME+=(Par2)
        SHERPA_QPKG_ARCH+=(a64)
        SHERPA_QPKG_URL+=("$PROJECT_REPO_URL"/Par2/Par2_0.8.1.0_arm_64.qpkg)
        SHERPA_QPKG_MD5+=(4d8e99f97936a163e411aa8765595f7a)
        SHERPA_QPKG_ABBRVS+=('')
        SHERPA_QPKG_ESSENTIALS+=('')
        SHERPA_QPKG_IPKGS_ADD+=('')
        SHERPA_QPKG_IPKGS_REMOVE+=(par2cmdline)

    SHERPA_QPKG_NAME+=(Par2)
        SHERPA_QPKG_ARCH+=(none)
        SHERPA_QPKG_URL+=('')
        SHERPA_QPKG_MD5+=('')
        SHERPA_QPKG_ABBRVS+=('')
        SHERPA_QPKG_ESSENTIALS+=('')
        SHERPA_QPKG_IPKGS_ADD+=(par2cmdline)
        SHERPA_QPKG_IPKGS_REMOVE+=('')

    SHERPA_QPKG_NAME+=(SABnzbd)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=("$PROJECT_REPO_URL"/SABnzbd/build/SABnzbd_201130.qpkg)
        SHERPA_QPKG_MD5+=(dd1723270972c14cdfe017fc0bd51b88)
        SHERPA_QPKG_ABBRVS+=('sb sb3 sab sab3 sabnzbd3 sabnzbd')
        SHERPA_QPKG_ESSENTIALS+=('Entware Par2')
        SHERPA_QPKG_IPKGS_ADD+=('python3-asn1crypto python3-chardet python3-cryptography python3-pyopenssl unrar p7zip coreutils-nice ionice ffprobe')
        SHERPA_QPKG_IPKGS_REMOVE+=('')

    SHERPA_QPKG_NAME+=(nzbToMedia)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=("$PROJECT_REPO_URL"/nzbToMedia/build/nzbToMedia_201215b.qpkg)
        SHERPA_QPKG_MD5+=(91300bd3ff3ad82e8e819905aa30484d)
        SHERPA_QPKG_ABBRVS+=('nzb2 nzb2m nzbto nzbtom nzbtomedia')
        SHERPA_QPKG_ESSENTIALS+=(Entware)
        SHERPA_QPKG_IPKGS_ADD+=('')
        SHERPA_QPKG_IPKGS_REMOVE+=('')

    SHERPA_QPKG_NAME+=(SickChill)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=("$PROJECT_REPO_URL"/SickChill/build/SickChill_201130.qpkg)
        SHERPA_QPKG_MD5+=(47a017ab38094aafde6ce25a69409762)
        SHERPA_QPKG_ABBRVS+=('sc sick sickc chill sickchill')
        SHERPA_QPKG_ESSENTIALS+=(Entware)
        SHERPA_QPKG_IPKGS_ADD+=('')
        SHERPA_QPKG_IPKGS_REMOVE+=('')

    SHERPA_QPKG_NAME+=(LazyLibrarian)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=("$PROJECT_REPO_URL"/LazyLibrarian/build/LazyLibrarian_201130.qpkg)
        SHERPA_QPKG_MD5+=(4317b410cc8cc380218d960a78686f3d)
        SHERPA_QPKG_ABBRVS+=('ll lazy lazylibrarian')
        SHERPA_QPKG_ESSENTIALS+=(Entware)
        SHERPA_QPKG_IPKGS_ADD+=('python3-pyopenssl python3-requests')
        SHERPA_QPKG_IPKGS_REMOVE+=('')

    SHERPA_QPKG_NAME+=(OMedusa)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=("$PROJECT_REPO_URL"/OMedusa/build/OMedusa_201130.qpkg)
        SHERPA_QPKG_MD5+=(afa21ae0ef4b43022d09b2ee8f455176)
        SHERPA_QPKG_ABBRVS+=('om med omed medusa omedusa')
        SHERPA_QPKG_ESSENTIALS+=(Entware)
        SHERPA_QPKG_IPKGS_ADD+=('mediainfo python3-pyopenssl')
        SHERPA_QPKG_IPKGS_REMOVE+=('')

    SHERPA_QPKG_NAME+=(OSickGear)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=("$PROJECT_REPO_URL"/OSickGear/build/OSickGear_201130.qpkg)
        SHERPA_QPKG_MD5+=(c735207d769d54ca375aa6da1ab1babf)
        SHERPA_QPKG_ABBRVS+=('sg os osg sickg gear ogear osickg sickgear osickgear')
        SHERPA_QPKG_ESSENTIALS+=(Entware)
        SHERPA_QPKG_IPKGS_ADD+=('')
        SHERPA_QPKG_IPKGS_REMOVE+=('')

    SHERPA_QPKG_NAME+=(Mylar3)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=("$PROJECT_REPO_URL"/Mylar3/build/Mylar3_201130.qpkg)
        SHERPA_QPKG_MD5+=(ba959d93fa95d0bd5cd95d37a6e131f0)
        SHERPA_QPKG_ABBRVS+=('my omy myl mylar mylar3')
        SHERPA_QPKG_ESSENTIALS+=(Entware)
        SHERPA_QPKG_IPKGS_ADD+=('python3-mako python3-pillow python3-pyopenssl python3-pytz python3-requests python3-six python3-urllib3')
        SHERPA_QPKG_IPKGS_REMOVE+=('')

    SHERPA_QPKG_NAME+=(NZBGet)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=("$PROJECT_REPO_URL"/NZBGet/build/NZBGet_201130.qpkg)
        SHERPA_QPKG_MD5+=(c7114e6e217110bc7490ad867b5bf536)
        SHERPA_QPKG_ABBRVS+=('ng nzb nzbg nget nzbget')
        SHERPA_QPKG_ESSENTIALS+=(Entware)
        SHERPA_QPKG_IPKGS_ADD+=('nzbget')
        SHERPA_QPKG_IPKGS_REMOVE+=('')

    SHERPA_QPKG_NAME+=(OTransmission)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=("$PROJECT_REPO_URL"/OTransmission/build/OTransmission_201130.qpkg)
        SHERPA_QPKG_MD5+=(c39da08668672e53f8d2dfed0f746069)
        SHERPA_QPKG_ABBRVS+=('ot tm tr trans otrans tmission transmission otransmission')
        SHERPA_QPKG_ESSENTIALS+=(Entware)
        SHERPA_QPKG_IPKGS_ADD+=('transmission-web jq')
        SHERPA_QPKG_IPKGS_REMOVE+=('')

    SHERPA_QPKG_NAME+=(Deluge-server)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=("$PROJECT_REPO_URL"/Deluge-server/build/Deluge-server_201130.qpkg)
        SHERPA_QPKG_MD5+=(ec7ee6febaf34d894585afa4dec87798)
        SHERPA_QPKG_ABBRVS+=('deluge del-server deluge-server')
        SHERPA_QPKG_ESSENTIALS+=(Entware)
        SHERPA_QPKG_IPKGS_ADD+=('deluge jq')
        SHERPA_QPKG_IPKGS_REMOVE+=('')

    SHERPA_QPKG_NAME+=(Deluge-web)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=("$PROJECT_REPO_URL"/Deluge-web/build/Deluge-web_201130.qpkg)
        SHERPA_QPKG_MD5+=(2e77b7981360356e6457458b11e759ef)
        SHERPA_QPKG_ABBRVS+=('del-web deluge-web')
        SHERPA_QPKG_ESSENTIALS+=(Entware)
        SHERPA_QPKG_IPKGS_ADD+=('deluge-ui-web jq')
        SHERPA_QPKG_IPKGS_REMOVE+=('')

    # package arrays are now full, so lock them
    readonly SHERPA_QPKG_NAME
        readonly SHERPA_QPKG_ARCH
        readonly SHERPA_QPKG_URL
        readonly SHERPA_QPKG_MD5
        readonly SHERPA_QPKG_ABBRVS
        readonly SHERPA_QPKG_ESSENTIALS
        readonly SHERPA_QPKG_IPKGS_ADD
        readonly SHERPA_QPKG_IPKGS_REMOVE

    QPKGs.Names.Add "${SHERPA_QPKG_NAME[*]}"

    readonly SHERPA_ESSENTIAL_IPKGS_ADD='findutils grep less sed'
    readonly SHERPA_COMMON_IPKGS_ADD='ca-certificates gcc git git-http nano python3-dev python3-pip python3-setuptools'
    readonly SHERPA_COMMON_PIPS_ADD='apscheduler beautifulsoup4 cfscrape cheetah3 cheroot!=8.4.4 cherrypy configobj feedparser portend pygithub python-magic random_user_agent sabyenc3 simplejson slugify'
    readonly SHERPA_COMMON_QPKG_CONFLICTS='Optware Optware-NG TarMT Python QPython2'

    QPKGs.EssentialAndOptional.Build
    QPKGs.InstallationState.Build
    QPKGs.Upgradable.Build
    Session.ParseArguments
    Session.SkipPackageProcessing.IsNot && Session.Debug.To.File.Set
    DebugInfoMajorSeparator
    DebugScript 'started' "$($DATE_CMD -d @"$SCRIPT_STARTSECONDS" | tr -s ' ')"
    DebugScript 'version' "package: $PACKAGE_VERSION, manager: $MANAGER_SCRIPT_VERSION, loader: $LOADER_SCRIPT_VERSION"
    DebugScript 'PID' "$$"
    DebugInfoMinorSeparator
    DebugInfo 'Markers: (**) detected, (II) information, (WW) warning, (EE) error, (LL) log file,'
    DebugInfo '(==) processing, (--) done, (>>) f entry, (<<) f exit, (vv) variable name & value,'
    DebugInfo '($1) positional argument value'
    DebugInfoMinorSeparator
    SmartCR

    if Session.Display.Clean.IsNot; then
        if Session.Debug.To.Screen.IsNot; then
            Display "$(FormatAsScriptTitle) $MANAGER_SCRIPT_VERSION • a mini-package-manager for QNAP NAS"
            DisplayLineSpaceIfNoneAlready
        fi

        User.Opts.Apps.All.Upgrade.IsNot && User.Opts.Apps.All.Uninstall.IsNot && QPKGs.NewVersions.Show
    fi

    DebugFuncExit; return 0

    }

Session.ParseArguments()
    {

    # basic argument syntax:
    #   sherpa [operation] [scope] [options]

    DebugFuncEntry

    if [[ -z $USER_ARGS_RAW ]]; then
        User.Opts.Help.Basic.Set
        Session.SkipPackageProcessing.Set
        code_pointer=1
        DebugFuncExit; return 1
    fi

    local user_args=($(tr 'A-Z' 'a-z' <<< "${USER_ARGS_RAW//,/ }"))
    local arg=''
    local operation=install_    # make 'install' the default action. A user-convenience to emulate the previous script behaviour.
    local operation_force=false
    local scope=''
    local package=''

    for arg in "${user_args[@]/--/}"; do
        DebugVar arg
        DebugVar operation
        DebugVar operation_force

        case $arg in
            abs)
                User.Opts.Help.Abbreviations.Set
                Session.SkipPackageProcessing.Set
                ;;
            actions)
                User.Opts.Help.Actions.Set
                Session.SkipPackageProcessing.Set
                ;;
            all-actions)
                User.Opts.Help.ActionsAll.Set
                Session.SkipPackageProcessing.Set
                ;;
            backup|install|reinstall|remove|restart|restore|start|stop|uninstall|upgrade)
                operation=${arg}_
                ;;
            backups)
                User.Opts.Apps.List.Backups.Set
                User.Opts.Log.Last.View.Clear
                Session.SkipPackageProcessing.Set
                Session.Display.Clean.Clear
                ;;
            check)
                operation=check_        # scope is optional, so set this so a default operation can be executed later
                Session.SkipPackageProcessing.Clear
                User.Opts.Dependencies.Check.Set
                ;;
            clean)
                User.Opts.Clean.Set
                Session.SkipPackageProcessing.Set
                ;;
            debug|verbose)
                Session.Debug.To.Screen.Set
                ;;
            force)
                operation_force=true
                ;;
            help)
                operation=help_         # scope is optional, so set this so a default operation can be executed later
                User.Opts.Help.Basic.Set
                Session.SkipPackageProcessing.Set
                ;;
            ignore-space)
                User.Opts.IgnoreFreeSpace.Set
                ;;
            installable)
                User.Opts.Apps.List.NotInstalled.Set
                Session.Display.Clean.Set
                Session.SkipPackageProcessing.Set
                ;;
            installed)
                User.Opts.Apps.List.Installed.Set
                Session.Display.Clean.Set
                Session.SkipPackageProcessing.Set
                ;;
            l|log|last)
                User.Opts.Log.Last.View.Set
                Session.Display.Clean.Set
                Session.SkipPackageProcessing.Set
                ;;
            list)
                operation=list_         # scope is optional, so set this so a default operation can be executed later
                User.Opts.Apps.List.Installed.Set
                Session.Display.Clean.Set
                Session.SkipPackageProcessing.Set
                ;;
            options)
                User.Opts.Help.Options.Set
                Session.SkipPackageProcessing.Set
                ;;
            packages)
                User.Opts.Help.Packages.Set
                Session.SkipPackageProcessing.Set
                ;;
            paste)
                operation=paste_        # scope is optional, so set this so a default operation can be executed later
                User.Opts.Log.Last.Paste.Set
                Session.SkipPackageProcessing.Set
                ;;
            problems)
                User.Opts.Help.Problems.Set
                Session.SkipPackageProcessing.Set
                ;;
            tips)
                User.Opts.Help.Tips.Set
                Session.SkipPackageProcessing.Set
                ;;
            view)
                operation=view_         # scope is optional, so set this so a default operation can be executed later
                User.Opts.Log.Last.View.Set
                Session.Display.Clean.Set
                Session.SkipPackageProcessing.Set
                ;;
            *)
                case $arg in
                    all|whole|entire|everything)
                        scope=all_
                        ;;
                    abs|actions|all-actions|backups|installable|installed|last|log|options|problems|packages|tips|upgradable|versions)
                        scope=${arg}_
                        ;;
                    essential|essentials)
                        scope=essential_
                        ;;
                    optional|optionals)
                        scope=optional_
                        ;;
                    *)
                        scope=''
                        package=$(QPKG.MatchAbbrv "$arg")
                        [[ -z $package ]] && Args.Unknown.Add "$arg"
                        ;;
                esac

                DebugVar scope

                case $operation in
                    backup_)
                        Session.SkipPackageProcessing.Clear

                        case $scope in
                            all_)
                                User.Opts.Apps.All.Backup.Set
                                operation=''
                                ;;
                            *)
                                QPKGs.ToBackup.Add "$package"
                                ;;
                        esac
                        ;;
                    check_)
                        Session.SkipPackageProcessing.Clear
                        User.Opts.Dependencies.Check.Set
                        ;;
                    help_)
                        Session.SkipPackageProcessing.Set

                        case $scope in
                            abs_)
                                User.Opts.Help.Abbreviations.Set
                                ;;
                            actions_)
                                User.Opts.Help.Actions.Set
                                ;;
                            all-actions_)
                                User.Opts.Help.ActionsAll.Set
                                ;;
                            options_)
                                User.Opts.Help.Options.Set
                                ;;
                            packages_)
                                User.Opts.Help.Packages.Set
                                ;;
                            problems_)
                                User.Opts.Help.Problems.Set
                                ;;
                            tips_)
                                User.Opts.Help.Tips.Set
                                ;;
                            *)
                                User.Opts.Help.Basic.Set
                                ;;
                        esac
                        ;;
                    install_)
                        Session.SkipPackageProcessing.Clear

                        case $scope in
                            all_)
                                User.Opts.Apps.All.Install.Set
                                operation=''
                                ;;
                            *)
                                QPKGs.ToInstall.Add "$package"
                                ;;
                        esac
                        ;;
                    list_)
                        Session.SkipPackageProcessing.Set

                        case $scope in
                            abs_)
                                User.Opts.Help.Abbreviations.Set
                                ;;
                            actions_)
                                User.Opts.Help.Actions.Set
                                ;;
                            all_)
                                User.Opts.Apps.List.All.Set
                                Session.Display.Clean.Set
                                ;;
                            all-actions_)
                                User.Opts.Help.ActionsAll.Set
                                ;;
                            backups_)
                                User.Opts.Apps.List.Backups.Set
                                ;;
                            essential_)
                                User.Opts.Apps.List.Essential.Set
                                Session.Display.Clean.Set
                                ;;
                            installable_)
                                User.Opts.Apps.List.NotInstalled.Set
                                Session.Display.Clean.Set
                                ;;
                            installed_)
                                User.Opts.Apps.List.Installed.Set
                                Session.Display.Clean.Set
                                ;;
                            last_)
                                User.Opts.Log.Last.View.Set
                                Session.Display.Clean.Set
                                ;;
                            log_)
                                User.Opts.Log.Whole.View.Set
                                Session.Display.Clean.Set
                                ;;
                            optional_)
                                User.Opts.Apps.List.Optional.Set
                                Session.Display.Clean.Set
                                ;;
                            options_)
                                User.Opts.Help.Options.Set
                                ;;
                            packages_)
                                User.Opts.Help.Packages.Set
                                ;;
                            problems_)
                                User.Opts.Help.Problems.Set
                                ;;
                            tips_)
                                User.Opts.Help.Tips.Set
                                ;;
                            upgradable_)
                                User.Opts.Apps.List.Upgradable.Set
                                Session.Display.Clean.Set
                                ;;
                            versions_)
                                User.Opts.Versions.View.Set
                                Session.Display.Clean.Set
                                ;;
                        esac
                        ;;
                    paste_)
                        Session.SkipPackageProcessing.Set

                        case $scope in
                            all_)
                                User.Opts.Log.Tail.Paste.Set
                                ;;
                            *)
                                User.Opts.Log.Last.Paste.Set
                                ;;
                        esac
                        ;;
                    reinstall_)
                        Session.SkipPackageProcessing.Clear

                        case $scope in
                            all_)
                                User.Opts.Apps.All.Reinstall.Set
                                operation=''
                                ;;
                            *)
                                QPKGs.ToReinstall.Add "$package"
                                ;;
                        esac
                        ;;
                    restart_)
                        Session.SkipPackageProcessing.Clear

                        case $scope in
                            all_)
                                User.Opts.Apps.All.Restart.Set
                                operation=''
                                ;;
                            *)
                                QPKGs.ToRestart.Add "$package"
                                ;;
                        esac
                        ;;
                    restore_)
                        Session.SkipPackageProcessing.Clear

                        case $scope in
                            all_)
                                User.Opts.Apps.All.Restore.Set
                                operation=''
                                ;;
                            *)
                                QPKGs.ToRestore.Add "$package"
                                ;;
                        esac
                        ;;
                    start_)
                        Session.SkipPackageProcessing.Clear

                        case $scope in
                            all_)
                                User.Opts.Apps.All.Start.Set
                                operation=''
                                ;;
                            essential_)
                                QPKGs.ToStart.Add "$(QPKGs.Essential.Array)"
                                ;;
                            optional_)
                                QPKGs.ToStart.Add "$(QPKGs.Optional.Array)"
                                ;;
                            *)
                                QPKGs.ToStart.Add "$package"
                                ;;
                        esac
                        ;;
                    stop_)
                        Session.SkipPackageProcessing.Clear

                        case $scope in
                            all_)
                                User.Opts.Apps.All.Stop.Set
                                operation=''
                                ;;
                            essential_)
                                QPKGs.ToStop.Add "$(QPKGs.Essential.Array)"
                                ;;
                            optional_)
                                QPKGs.ToStop.Add "$(QPKGs.Optional.Array)"
                                ;;
                            *)
                                QPKGs.ToStop.Add "$package"
                                ;;
                        esac
                        ;;
                    uninstall_|remove_)
                        Session.SkipPackageProcessing.Clear

                        if [[ $operation_force = true ]]; then
                            case $scope in
                                all_)           # this operation is dangerous, so make 'force' a requirement
                                    User.Opts.Apps.All.Uninstall.Set
                                    operation=''
                                    ;;
                                *)
                                    QPKGs.ToUninstall.Add "$package"
                                    ;;
                            esac
                        else
                            QPKGs.ToUninstall.Add "$package"
                        fi
                        ;;
                    upgrade_)
                        Session.SkipPackageProcessing.Clear

                        if [[ $operation_force = true ]]; then
                            case $scope in
                                all_)
                                    User.Opts.Apps.All.ForceUpgrade.Set
                                    operation=''
                                    ;;
                                *)
                                    QPKGs.ToForceUpgrade.Add "$package"
                                    ;;
                            esac
                        else
                            case $scope in
                                all_)
                                    User.Opts.Apps.All.Upgrade.Set
                                    operation=''
                                    ;;
                                *)
                                    QPKGs.ToUpgrade.Add "$package"
                                    ;;
                            esac
                        fi
                        ;;
                    view_)
                        Session.SkipPackageProcessing.Set

                        case $scope in
                            abs_)
                                User.Opts.Help.Abbreviations.Set
                                ;;
                            all_)
                                User.Opts.Log.Whole.View.Set
                                Session.Display.Clean.Set
                                ;;
                            backups_)
                                User.Opts.Apps.List.Backups.Set
                                ;;
                            last_)
                                User.Opts.Log.Last.View.Set
                                Session.Display.Clean.Set
                                ;;
                            options_)
                                User.Opts.Help.Options.Set
                                ;;
                            packages_)
                                User.Opts.Help.Packages.Set
                                ;;
                            problems_)
                                User.Opts.Help.Problems.Set
                                ;;
                            tips_)
                                User.Opts.Help.Tips.Set
                                ;;
                            versions_)
                                User.Opts.Versions.View.Set
                                Session.Display.Clean.Set
                                ;;
                            *)
                                User.Opts.Log.Last.View.Set
                                Session.Display.Clean.Set
                                ;;
                        esac
                        ;;
                esac
                ;;
        esac
    done

    if Args.Unknown.IsAny; then
        Session.SkipPackageProcessing.Set
        Session.Display.Clean.Clear
    fi

    DebugFuncExit; return 0

    }

Session.Validate()
    {

    DebugFuncEntry
    local package=''

    if Args.Unknown.IsAny; then
        ShowAsEror "unknown argument$(FormatAsPlural "$(Args.Unknown.Count)"): \"$(Args.Unknown.List)\""
        User.Opts.Help.Basic.Set
    fi

    if Session.SkipPackageProcessing.IsSet; then
        DebugFuncExit; return 1
    fi

    DebugInfoMinorSeparator
    DebugHardware.OK 'model' "$(get_display_name)"
    DebugHardware.OK 'RAM' "$(FormatAsThousands "$INSTALLED_RAM_KB")kB"

    if QPKGs.ToInstall.Exist SABnzbd || QPKG.Installed SABnzbd; then
        [[ $INSTALLED_RAM_KB -le $MIN_RAM_KB ]] && DebugHardware.Warning 'RAM' "less-than or equal-to $(FormatAsThousands "$MIN_RAM_KB")kB"
    fi

    if [[ ${NAS_FIRMWARE//.} -ge 400 ]]; then
        DebugFirmware.OK 'version' "$NAS_FIRMWARE"
    else
        DebugFirmware.Warning 'version' "$NAS_FIRMWARE"
    fi

    if [[ $NAS_BUILD -lt 20201015 || $NAS_BUILD -gt 20201020 ]]; then   # these builds won't allow unsigned QPKGs to run at all
        DebugFirmware.OK 'build' "$NAS_BUILD"
    else
        DebugFirmware.Warning 'build' "$NAS_BUILD"
    fi

    DebugFirmware.OK 'kernel' "$($UNAME_CMD -mr)"
    DebugUserspace.OK 'OS uptime' "$($UPTIME_CMD | $SED_CMD 's|.*up.||;s|,.*load.*||;s|^\ *||')"
    DebugUserspace.OK 'system load' "$($UPTIME_CMD | $SED_CMD 's|.*load average: ||' | $AWK_CMD -F', ' '{print "1 min: "$1 ", 5 min: "$2 ", 15 min: "$3}')"

    if [[ $USER = admin ]]; then
        DebugUserspace.OK '$USER' "$USER"
    else
        DebugUserspace.Warning '$USER' "$USER"
    fi

    if [[ $EUID -eq 0 ]]; then
        DebugUserspace.OK '$EUID' "$EUID"
    else
        DebugUserspace.Warning '$EUID' "$EUID"
    fi

    if [[ $EUID -ne 0 || $USER != admin ]]; then
        ShowAsEror "this script must be run as the 'admin' user. Please login via SSH as 'admin' and try again"
        Session.SkipPackageProcessing.Set
        DebugFuncExit; return 1
    fi

    DebugUserspace.OK 'BASH' "$(bash --version | $HEAD_CMD -n1)"
    DebugUserspace.OK 'default volume' "$($GETCFG_CMD SHARE_DEF defVolMP -f "$DEFAULT_SHARES_PATHFILE")"

    if [[ -L '/opt' ]]; then
        DebugUserspace.OK '/opt' "$($READLINK_CMD '/opt' || echo '<not present>')"
    else
        DebugUserspace.Warning '/opt' '<not present>'
    fi

    max_width=58
    trimmed_width=$max_width-3

    if [[ ${#PATH} -le $max_width ]]; then
        DebugUserspace.OK '$PATH' "$PATH"
    else
        DebugUserspace.OK '$PATH' "${PATH:0:trimmed_width}..."
    fi

    CheckPythonPathAndVersion python2
    CheckPythonPathAndVersion python3
    CheckPythonPathAndVersion python
    DebugUserspace.OK 'unparsed arguments' "\"$USER_ARGS_RAW\""

    DebugScript 'logs path' "$LOGS_PATH"
    DebugScript 'work path' "$WORK_PATH"
    DebugScript 'object reference hash' "$COMPILED_OBJECTS_HASH"

    Session.Calc.EntwareType
    Session.Calc.QPKGArch

    DebugQPKG 'upgradable QPKGs' "$(QPKGs.Upgradable.ListCSV) "
    DebugInfoMinorSeparator
    QPKGs.Assignment.Build
    DebugInfoMinorSeparator

    if ! QPKGs.Conflicts.Check; then
        code_pointer=2
        Session.SkipPackageProcessing.Set
        DebugFuncExit; return 1
    fi

    if QPKGs.ToBackup.IsNone && QPKGs.ToUninstall.IsNone && QPKGs.ToForceUpgrade.IsNone && QPKGs.ToUpgrade.IsNone && QPKGs.ToInstall.IsNone && QPKGs.ToReinstall.IsNone && QPKGs.ToRestore.IsNone && QPKGs.ToRestart.IsNone && QPKGs.ToStart.IsNone && QPKGs.ToStop.IsNone; then
        if User.Opts.Apps.All.Install.IsNot && User.Opts.Apps.All.Restart.IsNot && User.Opts.Apps.All.Upgrade.IsNot && User.Opts.Apps.All.ForceUpgrade.IsNot && User.Opts.Apps.All.Backup.IsNot && User.Opts.Apps.All.Restore.IsNot; then
            if User.Opts.Dependencies.Check.IsNot && User.Opts.IgnoreFreeSpace.IsNot; then
                ShowAsEror 'nothing to do (this usually means the provided arguments could not be decoded)'
                User.Opts.Help.Basic.Set
                Session.SkipPackageProcessing.Set
                DebugFuncExit; return 1
            fi
        fi
    fi

    if User.Opts.Dependencies.Check.IsSet || QPKGs.ToUpgrade.Exist Entware; then
        Session.IPKGs.Install.Set
        Session.PIPs.Install.Set
    fi

    DebugFuncExit; return 0

    }

Packages.Download()
    {

    Session.SkipPackageProcessing.IsSet && return
    DebugFuncEntry
    local package=''
    local package_count=0
    local pass_count=0
    local fail_count=0
    local old_fail_count=-1
    local action_intransitive='update cache image for'
    local action_present='updating cache image for'
    local action_past='updated cache image for'
    local result=0

    if QPKGs.ToDownload.IsNone; then
        DebugInfo "no QPKGs listed"
        DebugFuncExit; return 0
    fi

    package_count=$(QPKGs.ToDownload.Count)

    for package in $(QPKGs.ToDownload.Array); do
        if [[ $fail_count -ne $old_fail_count ]]; then
            ShowAsProc "$action_present $((package_count-fail_count)) QPKG$(FormatAsPlural "$((package_count-fail_count))")"
            old_fail_count=$fail_count
        fi

        QPKG.Download "$package"
        result=$?

        if [[ $result -ne 0 && $result -ne 10 ]]; then
            ShowAsFail "unable to $action_intransitive $(FormatAsPackageName "$package") (see log for more details)"
            ((fail_count++))
            continue
        fi

        ((pass_count++))
    done

    ShowAsOperationResult '' "$package_count" "$fail_count" "$pass_count" "$action_past"
    DebugFuncExit; return 0

    }

Packages.Backup()
    {

    Session.SkipPackageProcessing.IsSet && return
    DebugFuncEntry
    local package=''
    local package_count=0
    local pass_count=0
    local fail_count=0
    local old_fail_count=-1
    local action_intransitive=backup
    local action_present=backing-up
    local action_past=backed-up

    if QPKGs.ToBackup.IsNone; then
        DebugInfo "no QPKGs listed"
        DebugFuncExit; return 0
    fi

    package_count=$(QPKGs.ToBackup.Count)

    for package in $(QPKGs.ToBackup.Array); do
        if [[ $fail_count -ne $old_fail_count ]]; then
            ShowAsProc "$action_present $((package_count-fail_count)) QPKG$(FormatAsPlural "$((package_count-fail_count))")"
            old_fail_count=$fail_count
        fi

        if QPKGs.Essential.Exist "$package"; then
            ShowAsWarn "unable to $action_intransitive $(FormatAsPackageName "$package") as it's unsupported"
            ((fail_count++))
            continue
        fi

        if ! QPKG.Installed "$package"; then
            ShowAsNote "unable to $action_intransitive $(FormatAsPackageName "$package") as it's not installed"
            ((fail_count++))
            continue
        fi

        if ! QPKG.Backup "$package"; then
            ShowAsFail "unable to $action_intransitive $(FormatAsPackageName "$package") (see log for more details)"
            ((fail_count++))
            continue
        fi

        ((pass_count++))
    done

    ShowAsOperationResult '' "$package_count" "$fail_count" "$pass_count" "$action_past"
    DebugFuncExit; return 0

    }

Packages.Stop()
    {

    Packages.Stop.Optionals
    Packages.Stop.Essentials

    }

Packages.Stop.Optionals()
    {

    Session.SkipPackageProcessing.IsSet && return
    DebugFuncEntry
    local package=''
    local index=0
    local target_packages=()
    local package_count=0
    local pass_count=0
    local fail_count=0
    local old_fail_count=-1
    local tier=optional
    local action_intransitive=stop
    local action_present=stopping
    local action_past=stopped

    if QPKGs.ToStop.IsNone; then
        DebugInfo "no QPKGs listed"
        DebugFuncExit; return 0
    fi

    for package in $(QPKGs.Optional.Array); do
        QPKGs.ToStop.Exist "$package" && target_packages+=("$package")
    done

    if [[ ${#target_packages[@]} -eq 0 ]]; then
        DebugInfo "no $tier QPKGs listed"
        DebugFuncExit; return 0
    fi

    package_count=${#target_packages[@]}

    for ((index=package_count-1; index>=0; index--)); do       # process in reverse of declared order
        package=${target_packages[$index]}

        if [[ $fail_count -ne $old_fail_count ]]; then
            ShowAsProcLong "$action_present $((package_count-fail_count)) $tier QPKG$(FormatAsPlural "$((package_count-fail_count))")"
            old_fail_count=$fail_count
        fi

        if ! QPKG.Installed "$package"; then
            ShowAsNote "unable to $action_intransitive $(FormatAsPackageName "$package") as it's not installed"
            ((fail_count++))
            continue
        elif ! QPKG.Stop "$package"; then
            ShowAsFail "unable to $action_intransitive $(FormatAsPackageName "$package") (see log for more details)"
            ((fail_count++))
            continue
        fi

        ((pass_count++))
    done

    ShowAsOperationResult "$tier" "$package_count" "$fail_count" "$pass_count" "$action_past"
    DebugFuncExit; return 0

    }

Packages.Stop.Essentials()
    {

    Session.SkipPackageProcessing.IsSet && return
    DebugFuncEntry
    local package=''
    local index=0
    local target_packages=()
    local package_count=0
    local pass_count=0
    local fail_count=0
    local old_fail_count=-1
    local tier=essential
    local action_intransitive=stop
    local action_present=stopping
    local action_past=stopped

    if QPKGs.ToStop.IsNone; then
        DebugInfo "no QPKGs listed"
        DebugFuncExit; return 0
    fi

    for package in $(QPKGs.Essential.Array); do
        QPKGs.ToStop.Exist "$package" && target_packages+=("$package")
    done

    if [[ ${#target_packages[@]} -eq 0 ]]; then
        DebugInfo "no $tier QPKGs listed"
        DebugFuncExit; return 0
    fi

    package_count=${#target_packages[@]}

    for ((index=package_count-1; index>=0; index--)); do       # process in reverse of declared order
        package=${target_packages[$index]}

        if [[ $fail_count -ne $old_fail_count ]]; then
            ShowAsProcLong "$action_present $((package_count-fail_count)) $tier QPKG$(FormatAsPlural "$((package_count-fail_count))")"
            old_fail_count=$fail_count
        fi

        [[ $package = sherpa ]] && continue     # ignore 'sherpa'

        if ! QPKG.Installed "$package"; then
            ShowAsNote "unable to $action_intransitive $(FormatAsPackageName "$package") as it's not installed"
            ((fail_count++))
            continue
        elif ! QPKG.Stop "$package"; then
            ShowAsFail "unable to $action_intransitive $(FormatAsPackageName "$package") (see log for more details)"
            ((fail_count++))
            continue
        elif ! QPKG.Disable "$package"; then   # essentials don't have the same service scripts as other sherpa packages, so they must be enabled/disabled externally
            ShowAsEror "unable to disable $(FormatAsPackageName "$package") (see log for more details)"
            ((fail_count++))
            continue
        fi

        ((pass_count++))
    done

    ShowAsOperationResult "$tier" "$package_count" "$fail_count" "$pass_count" "$action_past"
    DebugFuncExit; return 0

    }

Packages.Uninstall()
    {

    Packages.Uninstall.Optionals
    Packages.Uninstall.Addons
    Packages.Uninstall.Essentials

    }

Packages.Uninstall.Optionals()
    {

    Session.SkipPackageProcessing.IsSet && return
    DebugFuncEntry
    local package=''
    local index=0
    local target_packages=()
    local package_count=0
    local pass_count=0
    local fail_count=0
    local old_fail_count=-1
    local tier=optional
    local action_intransitive=uninstall
    local action_present=uninstalling
    local action_past=uninstalled

    if QPKGs.ToUninstall.IsNone; then
        DebugInfo "no QPKGs listed"
        DebugFuncExit; return 0
    fi

    for package in $(QPKGs.Optional.Array); do
        QPKGs.ToUninstall.Exist "$package" && target_packages+=("$package")
    done

    if [[ ${#target_packages[@]} -eq 0 ]]; then
        DebugInfo "no $tier QPKGs listed"
        DebugFuncExit; return 0
    fi

    package_count=${#target_packages[@]}

    for ((index=package_count-1; index>=0; index--)); do       # process in reverse of declared order
        package=${target_packages[$index]}

        if [[ $fail_count -ne $old_fail_count ]]; then
            ShowAsProcLong "$action_present $((package_count-fail_count)) $tier QPKG$(FormatAsPlural "$((package_count-fail_count))")"
            old_fail_count=$fail_count
        fi

        if ! QPKG.Installed "$package"; then
            ShowAsNote "unable to $action_intransitive $(FormatAsPackageName "$package") as it's not installed"
            ((fail_count++))
            continue
        elif ! QPKG.Uninstall "$package"; then
            ShowAsFail "unable to $action_intransitive $(FormatAsPackageName "$package") (see log for more details)"
            ((fail_count++))
            continue
        fi

        ((pass_count++))
    done

    ShowAsOperationResult "$tier" "$package_count" "$fail_count" "$pass_count" "$action_past"
    DebugFuncExit; return 0

    }

Packages.Uninstall.Addons()
    {

    Session.SkipPackageProcessing.IsSet && return
    DebugFuncEntry

    QPKG.Installed Entware && IPKGs.Uninstall

    DebugFuncExit; return 0

    }

Packages.Uninstall.Essentials()
    {

    Session.SkipPackageProcessing.IsSet && return
    DebugFuncEntry
    local package=''
    local index=0
    local target_packages=()
    local package_count=0
    local pass_count=0
    local fail_count=0
    local old_fail_count=-1
    local tier=essential
    local action_intransitive=uninstall
    local action_present=uninstalling
    local action_past=uninstalled

    if QPKGs.ToUninstall.IsNone; then
        DebugInfo "no QPKGs listed"
        DebugFuncExit; return 0
    fi

    for package in $(QPKGs.Essential.Array); do
        QPKGs.ToUninstall.Exist "$package" && target_packages+=("$package")
    done

    if [[ ${#target_packages[@]} -eq 0 ]]; then
        DebugInfo "no $tier QPKGs listed"
        DebugFuncExit; return 0
    fi

    package_count=${#target_packages[@]}

    for ((index=package_count-1; index>=0; index--)); do       # process in reverse of declared order
        package=${target_packages[$index]}

        if [[ $fail_count -ne $old_fail_count ]]; then
            ShowAsProcLong "$action_present $((package_count-fail_count)) $tier QPKG$(FormatAsPlural "$((package_count-fail_count))")"
            old_fail_count=$fail_count
        fi

        [[ $package = sherpa ]] && continue     # ignore 'sherpa'

        if ! QPKG.Installed "$package"; then
            ShowAsNote "unable to $action_intransitive $(FormatAsPackageName "$package") as it's not installed"
            ((fail_count++))
            continue
        elif ! QPKG.Uninstall "$package"; then
            ShowAsFail "unable to $action_intransitive $(FormatAsPackageName "$package") (see log for more details)"
            ((fail_count++))
            continue
        fi

        ((pass_count++))
    done

    ShowAsOperationResult "$tier" "$package_count" "$fail_count" "$pass_count" "$action_past"
    ! QPKG.Installed Entware && Session.RemovePathToEntware
    DebugFuncExit; return 0

    }

Packages.Force-upgrade.Essentials()
    {

    Session.SkipPackageProcessing.IsSet && return
    DebugFuncEntry
    local package=''
    local target_packages=()
    local package_count=0
    local pass_count=0
    local fail_count=0
    local old_fail_count=-1
    local tier=essential
    local action_intransitive=force-upgrade
    local action_present=force-upgrading
    local action_past=force-upgraded

    if QPKGs.ToForceUpgrade.IsNone; then
        DebugInfo "no QPKGs listed"
        DebugFuncExit; return 0
    fi

    for package in $(QPKGs.Essential.Array); do
        QPKGs.ToForceUpgrade.Exist "$package" && target_packages+=("$package")
    done

    if [[ ${#target_packages[@]} -eq 0 ]]; then
        DebugInfo "no $tier QPKGs listed"
        DebugFuncExit; return 0
    fi

    package_count=${#target_packages[@]}

    for package in "${target_packages[@]}"; do
        if [[ $fail_count -ne $old_fail_count ]]; then
            ShowAsProcLong "$action_present $((package_count-fail_count)) $tier QPKG$(FormatAsPlural "$((package_count-fail_count))")"
            old_fail_count=$fail_count
        fi

        if ! QPKG.Installed "$package"; then
            ShowAsNote "unable to $action_intransitive $(FormatAsPackageName "$package") as it's not installed"
            ((fail_count++))
            continue
        elif ! QPKG.Upgrade "$package" --forced; then
            ShowAsFail "unable to $action_intransitive $(FormatAsPackageName "$package") (see log for more details)"
            ((fail_count++))
            continue
        fi

        ((pass_count++))
    done

    ShowAsOperationResult "$tier" "$package_count" "$fail_count" "$pass_count" "$action_past"
    DebugFuncExit; return 0

    }

Packages.Upgrade.Essentials()
    {

    Session.SkipPackageProcessing.IsSet && return
    DebugFuncEntry
    local package=''
    local target_packages=()
    local package_count=0
    local pass_count=0
    local fail_count=0
    local old_fail_count=-1
    local tier=essential
    local action_intransitive=upgrade
    local action_present=upgrading
    local action_past=upgraded

    if QPKGs.ToUpgrade.IsNone; then
        DebugInfo "no QPKGs listed"
        DebugFuncExit; return 0
    fi

    for package in $(QPKGs.Essential.Array); do
        QPKGs.ToUpgrade.Exist "$package" && target_packages+=("$package")
    done

    if [[ ${#target_packages[@]} -eq 0 ]]; then
        DebugInfo "no $tier QPKGs listed"
        DebugFuncExit; return 0
    fi

    package_count=${#target_packages[@]}

    for package in "${target_packages[@]}"; do
        if [[ $fail_count -ne $old_fail_count ]]; then
            ShowAsProcLong "$action_present $((package_count-fail_count)) $tier QPKG$(FormatAsPlural "$((package_count-fail_count))")"
            old_fail_count=$fail_count
        fi

        if ! QPKG.Installed "$package"; then
            ShowAsNote "unable to $action_intransitive $(FormatAsPackageName "$package") as it's not installed"
            ((fail_count++))
            continue
        elif ! QPKG.Upgrade "$package"; then
            ShowAsFail "unable to $action_intransitive $(FormatAsPackageName "$package") (see log for more details)"
            ((fail_count++))
            continue
        fi

        ((pass_count++))
    done

    ShowAsOperationResult "$tier" "$package_count" "$fail_count" "$pass_count" "$action_past"
    DebugFuncExit; return 0

    }

Packages.Reinstall.Essentials()
    {

    Session.SkipPackageProcessing.IsSet && return
    DebugFuncEntry
    local package=''
    local target_packages=()
    local package_count=0
    local pass_count=0
    local fail_count=0
    local old_fail_count=-1
    local tier=essential
    local action_intransitive=reinstall
    local action_present=reinstalling
    local action_past=reinstalled

    if QPKGs.ToReinstall.IsNone; then
        DebugInfo "no QPKGs listed"
        DebugFuncExit; return 0
    fi

    for package in $(QPKGs.Essential.Array); do
        QPKGs.ToReinstall.Exist "$package" && target_packages+=("$package")
    done

    if [[ ${#target_packages[@]} -eq 0 ]]; then
        DebugInfo "no $tier QPKGs listed"
        DebugFuncExit; return 0
    fi

    package_count=${#target_packages[@]}

    for package in "${target_packages[@]}"; do
        if [[ $fail_count -ne $old_fail_count ]]; then
            ShowAsProcLong "$action_present $((package_count-fail_count)) $tier QPKG$(FormatAsPlural "$((package_count-fail_count))")"
            old_fail_count=$fail_count
        fi

        if [[ $package = Entware ]]; then
            Display
            ShowAsNote "reinstalling $(FormatAsPackageName Entware) will remove all IPKGs and Python modules, and only those required to support your $PROJECT_NAME apps will be reinstalled."
            ShowAsNote "your installed IPKG list will be saved to $(FormatAsFileName "$PREVIOUS_OPKG_PACKAGE_LIST")"
            ShowAsNote "your installed Python module list will be saved to $(FormatAsFileName "$PREVIOUS_PIP3_MODULE_LIST")"
            (QPKG.Installed SABnzbdplus || QPKG.Installed Headphones) && ShowAsWarn "also, the $(FormatAsPackageName SABnzbdplus) and $(FormatAsPackageName Headphones) packages CANNOT BE REINSTALLED as Python 2.7.16 is no-longer available."

            if AskQuiz "press 'Y' to remove all current $(FormatAsPackageName Entware) IPKGs (and their configurations), or any other key to abort"; then
                ShowAsProc 'reinstalling Entware'
                Package.Save.Lists

                if ! QPKG.Uninstall Entware; then
                    ShowAsFail "unable to uninstall $(FormatAsPackageName "$package") (see log for more details)"
                    ((fail_count++))
                    continue
                elif ! Package.Install.Entware; then
                    ShowAsFail "unable to install $(FormatAsPackageName "$package") (see log for more details)"
                    ((fail_count++))
                    continue
                fi

                QPKGs.ToReinstall.Add Entware   # re-add this back to reinstall list as it was (quite-rightly) removed by the std QPKG.Install() function
                ((pass_count++))
            else
                DebugInfoMinorSeparator
                DebugScript 'user abort'
                Session.SkipPackageProcessing.Set
                Session.Summary.Clear
                DebugFuncExit; return 1
            fi
        else
            if ! QPKG.Installed "$package"; then
                ShowAsNote "unable to $action_intransitive $(FormatAsPackageName "$package") as it's not installed. Use 'install' instead."
                ((fail_count++))
                continue
            elif ! QPKG.Reinstall "$package"; then
                ShowAsFail "unable to $action_intransitive $(FormatAsPackageName "$package") (see log for more details)"
                ((fail_count++))
                continue
            fi

            ((pass_count++))
        fi
    done

    ShowAsOperationResult "$tier" "$package_count" "$fail_count" "$pass_count" "$action_past"
    DebugFuncExit; return 0

    }

Packages.Install.Essentials()
    {

    Session.SkipPackageProcessing.IsSet && return
    DebugFuncEntry
    local package=''
    local target_packages=()
    local package_count=0
    local pass_count=0
    local fail_count=0
    local old_fail_count=-1
    local tier=essential
    local action_intransitive=install
    local action_present=installing
    local action_past=installed

    if QPKGs.ToInstall.IsNone; then
        DebugInfo "no QPKGs listed"
        DebugFuncExit; return 0
    fi

    if User.Opts.Dependencies.Check.IsSet; then
        for package in $(QPKGs.Essential.Array); do
            QPKG.NotInstalled "$package" && QPKGs.ToInstall.Add "$package"
        done
    fi

    for package in $(QPKGs.Essential.Array); do
        QPKGs.ToInstall.Exist "$package" && target_packages+=("$package")
    done

    if [[ ${#target_packages[@]} -eq 0 ]]; then
        DebugInfo "no $tier QPKGs listed"
        DebugFuncExit; return 0
    fi

    package_count=${#target_packages[@]}

    for package in "${target_packages[@]}"; do
        if [[ $fail_count -ne $old_fail_count ]]; then
            ShowAsProcLong "$action_present $((package_count-fail_count)) $tier QPKG$(FormatAsPlural "$((package_count-fail_count))")"
            old_fail_count=$fail_count
        fi

        if [[ $package = Entware ]]; then
            if ! Package.Install.Entware; then
                ShowAsFail "unable to $action_intransitive $(FormatAsPackageName "$package") (see log for more details)"
                ((fail_count++))
                continue
            fi

            ((pass_count++))
        else
            if [[ $NAS_QPKG_ARCH != none ]] && QPKGs.ToInstall.Exist "$package"; then
                if QPKG.Installed "$package"; then
                    ShowAsNote "unable to $action_intransitive $(FormatAsPackageName "$package") as it's already installed. Use 'reinstall' instead."
                    ((fail_count++))
                    continue
                elif ! QPKG.Install "$package"; then
                    ShowAsFail "unable to $action_intransitive $(FormatAsPackageName "$package") (see log for more details)"
                    ((fail_count++))
                    continue
                fi

                ((pass_count++))
            fi
        fi
    done

    ShowAsOperationResult "$tier" "$package_count" "$fail_count" "$pass_count" "$action_past"

    if QPKG.Installed Entware; then
        Session.AddPathToEntware
        Entware.Patch.Service
    fi

    DebugFuncExit; return 0

    }

Packages.Start.Essentials()
    {

    Session.SkipPackageProcessing.IsSet && return
    DebugFuncEntry
    local package=''
    local acc=()
    local target_packages=()
    local package_count=0
    local pass_count=0
    local fail_count=0
    local old_fail_count=-1
    local tier=essential
    local action_intransitive=start
    local action_present=starting
    local action_past=started

    if QPKGs.ToStart.IsNone; then
        DebugInfo "no QPKGs listed"
        DebugFuncExit; return 0
    fi

    # if a optional has been selected for 'start', need to start essentials too
    for package in $(QPKGs.ToStart.Array); do
        acc+=($(QPKG.Get.Essentials "$package"))
    done

    if [[ ${#acc[@]} -gt 0 ]]; then
        for package in "${acc[@]}"; do
            QPKG.Installed "$package" && ! QPKGs.JustInstalled.Exist "$package" && QPKGs.ToStart.Add "$package"
        done
    fi

    for package in $(QPKGs.ToStart.Array); do
        QPKGs.Essential.Exist "$package" && target_packages+=("$package")
    done

    if [[ ${#target_packages[@]} -eq 0 ]]; then
        DebugInfo "no $tier QPKGs listed"
        DebugFuncExit; return 0
    fi

    package_count=${#target_packages[@]}

    for package in "${target_packages[@]}"; do
        if [[ $fail_count -ne $old_fail_count ]]; then
            ShowAsProcLong "$action_present $((package_count-fail_count)) $tier QPKG$(FormatAsPlural "$((package_count-fail_count))")"
            old_fail_count=$fail_count
        fi

        [[ $package = sherpa ]] && continue     # ignore 'sherpa'

        if ! QPKG.Enable "$package"; then       # essentials don't have the same service scripts as other sherpa packages, so they must be enabled/disabled externally
            ShowAsFail "unable to enable $(FormatAsPackageName "$package") (see log for more details)"
            ((fail_count++))
            continue
        elif ! QPKG.Start "$package"; then
            ShowAsFail "unable to $action_intransitive $(FormatAsPackageName "$package") (see log for more details)"
            ((fail_count++))
            continue
        fi

        ((pass_count++))
    done

    ShowAsOperationResult "$tier" "$package_count" "$fail_count" "$pass_count" "$action_past"
    DebugFuncExit; return 0

    }

Packages.Restore.Essentials()
    {

    :   # placeholder function

    }

Packages.Restart.Essentials()
    {

    Session.SkipPackageProcessing.IsSet && return
    DebugFuncEntry
    local package=''
    local acc=()
    local target_packages=()
    local package_count=0
    local pass_count=0
    local fail_count=0
    local old_fail_count=-1
    local tier=essential
    local action_intransitive=restart
    local action_present=restarting
    local action_past=restarted

    if QPKGs.ToRestart.IsNone; then
        DebugInfo "no QPKGs listed"
        DebugFuncExit; return 0
    fi

    for package in $(QPKGs.ToRestart.Array); do
        QPKGs.Essential.Exist "$package" && target_packages+=("$package")
    done

    if [[ ${#target_packages[@]} -eq 0 ]]; then
        DebugInfo "no $tier QPKGs listed"
        DebugFuncExit; return 0
    fi

    package_count=${#target_packages[@]}

    for package in "${target_packages[@]}"; do
        if [[ $fail_count -ne $old_fail_count ]]; then
            ShowAsProcLong "$action_present $((package_count-fail_count)) $tier QPKG$(FormatAsPlural "$((package_count-fail_count))")"
            old_fail_count=$fail_count
        fi

        if [[ $package = sherpa ]]; then
            ((pass_count++))
            continue
        elif ! QPKG.Installed "$package"; then
            ShowAsNote "unable to $action_intransitive $(FormatAsPackageName "$package") as it's not installed"
            ((fail_count++))
            continue
        elif ! QPKG.Restart "$package"; then
            ShowAsFail "unable to $action_intransitive $(FormatAsPackageName "$package") (see log for more details)"
            ((fail_count++))
            continue
        fi

        ((pass_count++))
    done

    ShowAsOperationResult "$tier" "$package_count" "$fail_count" "$pass_count" "$action_past"
    DebugFuncExit; return 0

    }

Packages.Force-upgrade.Addons()
    {

    :   # placeholder function

    }

Packages.Upgrade.Addons()
    {

    :   # placeholder function

    }

Packages.Reinstall.Addons()
    {

    :   # placeholder function

    }

Packages.Install.Addons()
    {

    Session.SkipPackageProcessing.IsSet && return
    DebugFuncEntry

    if QPKGs.ToInstall.IsAny || QPKGs.ToReinstall.IsAny; then
        Session.IPKGs.Install.Set
    fi

    if QPKGs.ToInstall.Exist SABnzbd || QPKGs.ToReinstall.Exist SABnzbd || QPKGs.ToUpgrade.Exist SABnzbd; then
        Session.PIPs.Install.Set   # must ensure 'sabyenc' and 'feedparser' modules are installed/updated
    fi

    if QPKG.Enabled Entware; then
        IPKGs.Install
        PIPs.Install
    else
        : # TODO: test if other packages are to be installed here. If so, and Entware isn't enabled, then abort with error.
    fi

    DebugFuncExit; return 0

    }

Packages.Start.Addons()
    {

    :   # placeholder function

    }

Packages.Restore.Addons()
    {

    :   # placeholder function

    }

Packages.Restart.Addons()
    {

    :   # placeholder function

    }

Packages.Force-upgrade.Optionals()
    {

    Session.SkipPackageProcessing.IsSet && return
    DebugFuncEntry
    local package=''
    local target_packages=()
    local package_count=0
    local pass_count=0
    local fail_count=0
    local old_fail_count=-1
    local tier=optional
    local action_intransitive=force-upgrade
    local action_present=force-upgrading
    local action_past=force-upgraded

    if QPKGs.ToForceUpgrade.IsNone; then
        DebugInfo "no QPKGs listed"
        DebugFuncExit; return 0
    fi

    for package in $(QPKGs.ToForceUpgrade.Array); do
        QPKGs.Optional.Exist "$package" && target_packages+=("$package")
    done

    if [[ ${#target_packages[@]} -eq 0 ]]; then
        DebugInfo "no $tier QPKGs listed"
        DebugFuncExit; return 0
    fi

    package_count=${#target_packages[@]}

    for package in "${target_packages[@]}"; do
        if [[ $fail_count -ne $old_fail_count ]]; then
            ShowAsProcLong "$action_present $((package_count-fail_count)) $tier QPKG$(FormatAsPlural "$((package_count-fail_count))")"
            old_fail_count=$fail_count
        fi

        if ! QPKG.Installed "$package"; then
            ShowAsNote "unable to $action_intransitive $(FormatAsPackageName "$package") as it's not installed"
            ((fail_count++))
            continue
        elif ! QPKG.Upgrade "$package" --forced; then
            ShowAsFail "unable to $action_intransitive $(FormatAsPackageName "$package") (see log for more details)"
            ((fail_count++))
            continue
        fi

        ((pass_count++))
    done

    ShowAsOperationResult "$tier" "$package_count" "$fail_count" "$pass_count" "$action_past"
    DebugFuncExit; return 0

    }

Packages.Upgrade.Optionals()
    {

    Session.SkipPackageProcessing.IsSet && return
    DebugFuncEntry
    local package=''
    local target_packages=()
    local package_count=0
    local pass_count=0
    local fail_count=0
    local old_fail_count=-1
    local tier=optional
    local action_intransitive=upgrade
    local action_present=upgrading
    local action_past=upgraded

    if QPKGs.ToUpgrade.IsNone; then
        DebugInfo "no QPKGs listed"
        DebugFuncExit; return 0
    fi

    for package in $(QPKGs.ToUpgrade.Array); do
        QPKGs.Optional.Exist "$package" && target_packages+=("$package")
    done

    if [[ ${#target_packages[@]} -eq 0 ]]; then
        DebugInfo "no $tier QPKGs listed"
        DebugFuncExit; return 0
    fi

    package_count=${#target_packages[@]}

    for package in "${target_packages[@]}"; do
        if [[ $fail_count -ne $old_fail_count ]]; then
            ShowAsProcLong "$action_present $((package_count-fail_count)) $tier QPKG$(FormatAsPlural "$((package_count-fail_count))")"
            old_fail_count=$fail_count
        fi

        if ! QPKG.Installed "$package"; then
            ShowAsNote "unable to $action_intransitive $(FormatAsPackageName "$package") as it's not installed"
            ((fail_count++))
            continue
        elif ! QPKG.Upgrade "$package"; then
            ShowAsFail "unable to $action_intransitive $(FormatAsPackageName "$package") (see log for more details)"
            ((fail_count++))
            continue
        fi

        ((pass_count++))
    done

    ShowAsOperationResult "$tier" "$package_count" "$fail_count" "$pass_count" "$action_past"
    DebugFuncExit; return 0

    }

Packages.Reinstall.Optionals()
    {

    Session.SkipPackageProcessing.IsSet && return
    DebugFuncEntry
    local package=''
    local target_packages=()
    local package_count=0
    local pass_count=0
    local fail_count=0
    local old_fail_count=-1
    local tier=optional
    local action_intransitive=reinstall
    local action_present=reinstalling
    local action_past=reinstalled

    if QPKGs.ToReinstall.IsNone; then
        DebugInfo "no QPKGs listed"
        DebugFuncExit; return 0
    fi

    for package in $(QPKGs.ToReinstall.Array); do
        QPKGs.Optional.Exist "$package" && target_packages+=("$package")
    done

    if [[ ${#target_packages[@]} -eq 0 ]]; then
        DebugInfo "no $tier QPKGs listed"
        DebugFuncExit; return 0
    fi

    package_count=${#target_packages[@]}

    for package in "${target_packages[@]}"; do
        if [[ $fail_count -ne $old_fail_count ]]; then
            ShowAsProcLong "$action_present $((package_count-fail_count)) $tier QPKG$(FormatAsPlural "$((package_count-fail_count))")"
            old_fail_count=$fail_count
        fi

        if ! QPKG.Installed "$package"; then
            ShowAsNote "unable to $action_intransitive $(FormatAsPackageName "$package") as it's not installed. Use 'install' instead."
            ((fail_count++))
            continue
        elif ! QPKG.Reinstall "$package"; then
            ShowAsFail "unable to $action_intransitive $(FormatAsPackageName "$package") (see log for more details)"
            ((fail_count++))
            QPKGs.ToStart.Remove "$package"
            QPKGs.ToRestart.Remove "$package"
            continue
        fi

        ((pass_count++))
    done

    ShowAsOperationResult "$tier" "$package_count" "$fail_count" "$pass_count" "$action_past"
    DebugFuncExit; return 0

    }

Packages.Install.Optionals()
    {

    Session.SkipPackageProcessing.IsSet && return
    DebugFuncEntry
    local package=''
    local target_packages=()
    local package_count=0
    local pass_count=0
    local fail_count=0
    local old_fail_count=-1
    local tier=optional
    local action_intransitive=install
    local action_present=installing
    local action_past=installed

    if QPKGs.ToInstall.IsNone; then
        DebugInfo "no QPKGs listed"
        DebugFuncExit; return 0
    fi

    for package in $(QPKGs.ToInstall.Array); do
        QPKGs.Optional.Exist "$package" && target_packages+=("$package")
    done

    if [[ ${#target_packages[@]} -eq 0 ]]; then
        DebugInfo "no $tier QPKGs listed"
        DebugFuncExit; return 0
    fi

    package_count=${#target_packages[@]}

    for package in "${target_packages[@]}"; do
        if [[ $fail_count -ne $old_fail_count ]]; then
            ShowAsProcLong "$action_present $((package_count-fail_count)) $tier QPKG$(FormatAsPlural "$((package_count-fail_count))")"
            old_fail_count=$fail_count
        fi

        if QPKG.Installed "$package"; then
            ShowAsNote "unable to $action_intransitive $(FormatAsPackageName "$package") as it's already installed. Use 'reinstall' instead."
            ((fail_count++))
            continue
        elif ! QPKG.Install "$package"; then
            ShowAsFail "unable to $action_intransitive $(FormatAsPackageName "$package") (see log for more details)"
            ((fail_count++))
#             QPKGs.ToStart.Remove "$package"
#             QPKGs.ToRestart.Remove "$package"
            continue
        fi

        ((pass_count++))
    done

    ShowAsOperationResult "$tier" "$package_count" "$fail_count" "$pass_count" "$action_past"
    DebugFuncExit; return 0

    }

Packages.Start.Optionals()
    {

    Session.SkipPackageProcessing.IsSet && return
    DebugFuncEntry
    local package=''
    local target_packages=()
    local package_count=0
    local pass_count=0
    local fail_count=0
    local old_fail_count=-1
    local tier=optional
    local action_intransitive=start
    local action_present=starting
    local action_past=started

    if QPKGs.ToStart.IsNone; then
        DebugInfo "no QPKGs listed"
        DebugFuncExit; return 0
    fi

    for package in $(QPKGs.ToStart.Array); do
        QPKGs.Optional.Exist "$package" && target_packages+=("$package")
    done

    if [[ ${#target_packages[@]} -eq 0 ]]; then
        DebugInfo "no $tier QPKGs listed"
        DebugFuncExit; return 0
    fi

    package_count=${#target_packages[@]}

    for package in "${target_packages[@]}"; do
        if [[ $fail_count -ne $old_fail_count ]]; then
            ShowAsProcLong "$action_present $((package_count-fail_count)) $tier QPKG$(FormatAsPlural "$((package_count-fail_count))")"
            old_fail_count=$fail_count
        fi

        if ! QPKG.Installed "$package"; then
            ShowAsNote "unable to $action_intransitive $(FormatAsPackageName "$package") as it's not installed"
            ((fail_count++))
            continue
        elif ! QPKG.Start "$package"; then
            ShowAsFail "unable to $action_intransitive $(FormatAsPackageName "$package") (see log for more details)"
            ((fail_count++))
            continue
        fi

        ((pass_count++))
    done

    ShowAsOperationResult "$tier" "$package_count" "$fail_count" "$pass_count" "$action_past"
    DebugFuncExit; return 0

    }

Packages.Restore.Optionals()
    {

    Session.SkipPackageProcessing.IsSet && return
    DebugFuncEntry
    local package=''
    local target_packages=()
    local package_count=0
    local pass_count=0
    local fail_count=0
    local old_fail_count=-1
    local tier=optional
    local action_intransitive='restore configuration for'
    local action_present='restoring configuration for'
    local action_past='configuration restored for'

    if QPKGs.ToRestore.IsNone; then
        DebugInfo "no QPKGs listed"
        DebugFuncExit; return 0
    fi

    for package in $(QPKGs.ToRestore.Array); do
        QPKGs.Optional.Exist "$package" && target_packages+=("$package")
    done

    if [[ ${#target_packages[@]} -eq 0 ]]; then
        DebugInfo "no $tier QPKGs listed"
        DebugFuncExit; return 0
    fi

    package_count=${#target_packages[@]}

    for package in "${target_packages[@]}"; do
        if [[ $fail_count -ne $old_fail_count ]]; then
            ShowAsProcLong "$action_present $((package_count-fail_count)) $tier QPKG$(FormatAsPlural "$((package_count-fail_count))")"
            old_fail_count=$fail_count
        fi

        if ! QPKG.Installed "$package"; then
            ShowAsNote "unable to $action_intransitive $(FormatAsPackageName "$package") as it's not installed"
            ((fail_count++))
            continue
        elif ! QPKG.Restore "$package"; then
            ShowAsFail "unable to $action_intransitive $(FormatAsPackageName "$package") (see log for more details)"
            ((fail_count++))
            continue
        fi

        ((pass_count++))
    done

    ShowAsOperationResult "$tier" "$package_count" "$fail_count" "$pass_count" "$action_past"
    DebugFuncExit; return 0

    }

Packages.Restart.Optionals()
    {

    Session.SkipPackageProcessing.IsSet && return
    DebugFuncEntry
    local acc=()
    local package=''
    local target_packages=()
    local package_count=0
    local pass_count=0
    local fail_count=0
    local old_fail_count=-1
    local tier=optional
    local action_intransitive=restart
    local action_present=restarting
    local action_past=restarted

    for package in $(QPKGs.JustInstalled.Array); do
        if QPKGs.Essential.Exist "$package"; then
            acc+=($(QPKG.Get.Dependencies "$package"))
        fi
    done

    if [[ ${#acc[@]} -gt 0 ]]; then
        for package in "${acc[@]}"; do
            QPKG.Installed "$package" && ! QPKGs.JustInstalled.Exist "$package" && ! QPKGs.JustStarted.Exist "$package" && QPKGs.ToRestart.Add "$package"
        done
    fi

    if User.Opts.Apps.All.Upgrade.IsSet; then
        for package in $(QPKGs.Optional.Array); do
            if QPKG.Enabled "$package" && ! QPKGs.Upgradable.Exist "$package"; then
                QPKGs.ToRestart.Add "$package"
            fi
        done
    fi

    for package in $(QPKGs.ToRestart.Array); do
        QPKGs.Optional.Exist "$package" && target_packages+=("$package")
    done

    if QPKGs.ToRestart.IsNone; then
        DebugInfo "no QPKGs listed"
        DebugFuncExit; return 0
    fi

    if [[ ${#target_packages[@]} -eq 0 ]]; then
        DebugInfo "no $tier QPKGs listed"
        DebugFuncExit; return 0
    fi

    package_count=${#target_packages[@]}

    for package in "${target_packages[@]}"; do
        if [[ $fail_count -ne $old_fail_count ]]; then
            ShowAsProcLong "$action_present $((package_count-fail_count)) $tier QPKG$(FormatAsPlural "$((package_count-fail_count))")"
            old_fail_count=$fail_count
        fi

        if ! QPKG.Installed "$package"; then
            ShowAsNote "unable to $action_intransitive $(FormatAsPackageName "$package") as it's not installed"
            ((fail_count++))
            continue
        elif QPKGs.JustInstalled.Exist "$package"; then
            ShowAsNote "no-need to $action_intransitive $(FormatAsPackageName "$package") as it was just installed"
            ((fail_count++))
            continue
        elif QPKGs.JustStarted.Exist "$package"; then
            ShowAsNote "no-need to $action_intransitive $(FormatAsPackageName "$package") as it was just started"
            ((fail_count++))
            continue
        elif ! QPKG.Restart "$package"; then
            ShowAsFail "unable to $action_intransitive $(FormatAsPackageName "$package") (see log for more details)"
            ((fail_count++))
            continue
        fi

        ((pass_count++))
    done

    ShowAsOperationResult "$tier" "$package_count" "$fail_count" "$pass_count" "$action_past"
    DebugFuncExit; return 0

    }

Package.Save.Lists()
    {

    if [[ -e $pip3_cmd ]]; then
        $pip3_cmd freeze > "$PREVIOUS_PIP3_MODULE_LIST"
        DebugAsDone "saved current $(FormatAsPackageName pip3) module list to $(FormatAsFileName "$PREVIOUS_PIP3_MODULE_LIST")"
    fi

    if [[ -e $OPKG_CMD ]]; then
        $OPKG_CMD list-installed > "$PREVIOUS_OPKG_PACKAGE_LIST"
        DebugAsDone "saved current $(FormatAsPackageName Entware) IPKG list to $(FormatAsFileName "$PREVIOUS_OPKG_PACKAGE_LIST")"
    fi

    }

Package.Install.Entware()
    {

    local log_pathfile=$LOGS_PATH/ipkgs.extra.$INSTALL_LOG_FILE

    # rename original [/opt]
    local opt_path=/opt
    local opt_backup_path=/opt.orig
    [[ -d $opt_path && ! -L $opt_path && ! -e $opt_backup_path ]] && mv "$opt_path" "$opt_backup_path"
    QPKG.Install Entware && Session.AddPathToEntware

    DebugAsProc 'swapping /opt'
    # copy all files from original [/opt] into new [/opt]
    [[ -L $opt_path && -d $opt_backup_path ]] && cp --recursive "$opt_backup_path"/* --target-directory "$opt_path" && rm -rf "$opt_backup_path"
    DebugAsDone 'complete'

    DebugAsProc 'installing essential IPKGs'
    # add extra package(s) needed immediately
    RunAndLog "$OPKG_CMD install$(User.Opts.IgnoreFreeSpace.IsSet && User.Opts.IgnoreFreeSpace.Text) --force-overwrite $SHERPA_ESSENTIAL_IPKGS_ADD --cache $IPKG_CACHE_PATH --tmp-dir $IPKG_DL_PATH" "$log_pathfile"
    DebugAsDone 'installed essential IPKGs'

    # ensure PIPs are installed later
    Session.PIPs.Install.Set

    }

Session.Results()
    {

    if User.Opts.Clean.IsSet; then
        Clean.Cache
    fi

    if Args.Unknown.IsNone; then
        if User.Opts.Versions.View.IsSet; then
            Versions.Show
        elif User.Opts.Log.Whole.View.IsSet; then
            Log.Whole.View
        elif User.Opts.Log.Last.View.IsSet; then        # default operation when scope is unspecified
            Log.Last.View
        fi

        if User.Opts.Apps.List.All.IsSet; then
            QPKGs.All.Show
        elif User.Opts.Apps.List.NotInstalled.IsSet; then
            QPKGs.NotInstalled.Show
        elif User.Opts.Apps.List.Upgradable.IsSet; then
            QPKGs.Upgradable.Show
        elif User.Opts.Apps.List.Essential.IsSet; then
            QPKGs.Essential.Show
        elif User.Opts.Apps.List.Optional.IsSet; then
            QPKGs.Optional.Show
        elif User.Opts.Apps.List.Backups.IsSet; then
            QPKGs.Backups.Show
        elif User.Opts.Apps.List.Installed.IsSet; then  # default operation when scope is unspecified
            QPKGs.Installed.Show
        fi

        if User.Opts.Log.Tail.Paste.IsSet; then
            Log.Tail.Paste.Online
        elif User.Opts.Log.Last.Paste.IsSet; then       # default operation when scope is unspecified
            Log.Last.Paste.Online
        fi
    fi

    if User.Opts.Help.Actions.IsSet; then
        Help.Actions.Show
    elif User.Opts.Help.ActionsAll.IsSet; then
        Help.ActionsAll.Show
    elif User.Opts.Help.Packages.IsSet; then
        Help.Packages.Show
    elif User.Opts.Help.Options.IsSet; then
        Help.Options.Show
    elif User.Opts.Help.Problems.IsSet; then
        Help.Problems.Show
    elif User.Opts.Help.Tips.IsSet; then
        Help.Tips.Show
    elif User.Opts.Help.Abbreviations.IsSet; then
        Help.PackageAbbreviations.Show
    elif User.Opts.Help.Basic.IsSet; then               # default operation when scope is unspecified
        Help.Basic.Show
        Help.Basic.Example.Show
    fi

    Session.ShowBackupLocation.IsSet && Help.BackupLocation.Show

    Session.Summary.IsSet && Session.Summary.Show
    Session.SuggestIssue.IsSet && Help.Issue.Show
    DisplayLineSpaceIfNoneAlready       # final on-screen line space

    DebugInfoMinorSeparator
    DebugScript 'finished' "$($DATE_CMD)"
    DebugScript 'elapsed time' "$(ConvertSecsToHoursMinutesSecs "$(($($DATE_CMD +%s)-$([[ -n $SCRIPT_STARTSECONDS ]] && echo "$SCRIPT_STARTSECONDS" || echo "1")))")"
    DebugInfoMajorSeparator

    Session.LockFile.Release

    return 0

    }

Clean.Cache()
    {

    [[ -d $WORK_PATH ]] && rm -rf "$WORK_PATH"
    ShowAsDone 'work path cleaned OK'

    return 0

    }

AskQuiz()
    {

    # input:
    #   $1 = prompt

    # output:
    #   $? = 0 if "y", 1 if anything else

    local response=''

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

Entware.Patch.Service()
    {

    local tab=$'\t'
    local prefix_text="# following line was inserted by $PROJECT_NAME"
    local find_text=''
    local insert_text=''
    local package_init_pathfile=$(QPKG.ServicePathFile Entware)

    if $GREP_CMD -q 'opt.orig' "$package_init_pathfile"; then
        DebugInfo 'patch: do the "opt shuffle" - already done'
    else
        # ensure existing files are moved out of the way before creating /opt symlink
        find_text='# sym-link $QPKG_DIR to /opt'
        insert_text='opt_path="/opt"; opt_backup_path="/opt.orig"; [[ -d "$opt_path" \&\& ! -L "$opt_path" \&\& ! -e "$opt_backup_path" ]] \&\& mv "$opt_path" "$opt_backup_path"'
        $SED_CMD -i "s|$find_text|$find_text\n\n${tab}${prefix_text}\n${tab}${insert_text}\n|" "$package_init_pathfile"

        # ... then restored after creating /opt symlink
        find_text='/bin/ln -sf $QPKG_DIR /opt'
        insert_text='[[ -L "$opt_path" \&\& -d "$opt_backup_path" ]] \&\& cp "$opt_backup_path"/* --target-directory "$opt_path" \&\& rm -r "$opt_backup_path"'
        $SED_CMD -i "s|$find_text|$find_text\n\n${tab}${prefix_text}\n${tab}${insert_text}\n|" "$package_init_pathfile"

        DebugAsDone 'patch: do the "opt shuffle"'
    fi

    return 0

    }

Entware.Update()
    {

    if IsNotSysFileExist $OPKG_CMD; then
        code_pointer=4
        return 1
    fi

    local package_minutes_threshold=60
    local log_pathfile=$LOGS_PATH/entware.$UPDATE_LOG_FILE
    local msgs=''
    local resultcode=0

    # if Entware package list was updated only recently, don't run another update. Examine 'change' time as this is updated even if package list content isn't modified.
    if [[ -e $EXTERNAL_PACKAGE_ARCHIVE_PATHFILE && -e $GNU_FIND_CMD ]]; then
        msgs=$($GNU_FIND_CMD "$EXTERNAL_PACKAGE_ARCHIVE_PATHFILE" -cmin +$package_minutes_threshold)        # no-output if last update was less than $package_minutes_threshold minutes ago
    else
        msgs='new install'
    fi

    if [[ -n $msgs ]]; then
        DebugAsProc "updating $(FormatAsPackageName Entware) package list"

        RunAndLog "$OPKG_CMD update" "$log_pathfile" log:failure-only
        resultcode=$?

        if [[ $resultcode -eq 0 ]]; then
            DebugAsDone "updated $(FormatAsPackageName Entware) package list"
        else
            DebugAsWarning "Unable to update $(FormatAsPackageName Entware) package list $(FormatAsExitcode $resultcode)"
            # meh, continue anyway with existing list
        fi
    else
        DebugInfo "$(FormatAsPackageName Entware) package list was updated less than $package_minutes_threshold minutes ago"
    fi

    return 0

    }

PIPs.Install()
    {

    Session.SkipPackageProcessing.IsSet && return
    Session.PIPs.Install.IsNot && return
    DebugFuncEntry
    local exec_cmd=''
    local resultcode=0

    # sometimes, OpenWRT doesn't have a 'pip3'
    if [[ -e /opt/bin/pip3 ]]; then
        pip3_cmd=/opt/bin/pip3
    elif [[ -e /opt/bin/pip3.9 ]]; then
        pip3_cmd=/opt/bin/pip3.9
    elif [[ -e /opt/bin/pip3.8 ]]; then
        pip3_cmd=/opt/bin/pip3.8
    elif [[ -e /opt/bin/pip3.7 ]]; then
        pip3_cmd=/opt/bin/pip3.7
    else
        if IsNotSysFileExist $pip3_cmd; then
            Display "* Ugh! The usual fix for this is to let $(FormatAsScriptTitle) reinstall $(FormatAsPackageName Entware) at least once."
            Display "\t$0 reinstall ew"
            Display "If it happens again after reinstalling $(FormatAsPackageName Entware), please create a new issue for this on GitHub."
            DebugFuncExit; return 1
        fi
    fi

    [[ -n ${SHERPA_COMMON_PIPS_ADD// /} ]] && exec_cmd="$pip3_cmd install $SHERPA_COMMON_PIPS_ADD --disable-pip-version-check --cache-dir $PIP_CACHE_PATH"

    ShowAsProcLong "downloading & installing PIPs"

    local desc="'Python3' modules"
    local log_pathfile=$LOGS_PATH/py3-modules.assorted.$INSTALL_LOG_FILE
    DebugAsProc "downloading & installing $desc"

    RunAndLog "$exec_cmd" "$log_pathfile"
    resultcode=$?

    if [[ $resultcode -eq 0 ]]; then
        DebugAsDone "downloaded & installed $desc"
    else
        ShowAsEror "download & install $desc failed $(FormatAsResult "$resultcode")"
    fi

    if QPKG.Installed SABnzbd || QPKGs.ToInstall.Exist SABnzbd || QPKGs.ToReinstall.Exist SABnzbd; then
        # KLUDGE: force recompilation of 'sabyenc3' package so it's recognised by SABnzbd: https://forums.sabnzbd.org/viewtopic.php?p=121214#p121214
        exec_cmd="$pip3_cmd install --force-reinstall --ignore-installed --no-binary :all: sabyenc3 --disable-pip-version-check --cache-dir $PIP_CACHE_PATH"

        desc="'Python3 SABnzbd' module"
        log_pathfile=$LOGS_PATH/py3-modules.sabnzbd.$INSTALL_LOG_FILE
        DebugAsProc "downloading & installing $desc"

        RunAndLog "$exec_cmd" "$log_pathfile"
        resultcode=$?

        if [[ $resultcode -eq 0 ]]; then
            DebugAsDone "downloaded & installed $desc"
            QPKGs.ToRestart.Add SABnzbd
        else
            ShowAsEror "download & install $desc failed $(FormatAsResult "$resultcode")"
        fi

        # KLUDGE: ensure 'feedparser' is upgraded. This was version-held at 5.2.1 for Python 3.8.5 but from Python 3.9.0 onward there's no-need for version-hold anymore.
        exec_cmd="$pip3_cmd install --upgrade feedparser --disable-pip-version-check --cache-dir $PIP_CACHE_PATH"

        desc="'Python3 feedparser' module"
        log_pathfile=$LOGS_PATH/py3-modules.feedparser.$INSTALL_LOG_FILE
        DebugAsProc "downloading & installing $desc"
        RunAndLog "$exec_cmd" "$log_pathfile"
        resultcode=$?

        if [[ $resultcode -eq 0 ]]; then
            DebugAsDone "downloaded & installed $desc"
            QPKGs.ToRestart.Add SABnzbd
        else
            ShowAsEror "download & install $desc failed $(FormatAsResult "$resultcode")"
        fi
    fi

    ShowAsDone 'downloaded & installed PIPs OK'

    DebugFuncExit; return $resultcode

    }

CalcAllIPKGDepsToInstall()
    {

    # From a specified list of IPKG names, find all dependent IPKGs, exclude those already installed, then generate a total qty to download and a total download byte-size

    if IsNotSysFileExist $OPKG_CMD || IsNotSysFileExist $GNU_GREP_CMD; then
        code_pointer=5
        return 1
    fi

    DebugFuncEntry
    local package_count=0
    local requested_list=''
    local this_list=()
    local dependency_accumulator=()
    local pre_download_list=''
    local element=''
    local iterations=0
    local -r ITERATION_LIMIT=20
    local complete=false

    # remove duplicate entries
    requested_list=$(DeDupeWords "$(IPKGs.ToInstall.List)")
    this_list=($requested_list)

    DebugAsProc 'calculating IPKGs required'
    DebugInfo 'IPKGs requested' "$requested_list "

    if ! IPKGs.Archive.Open; then
        DebugFuncExit; return 1
    fi

    ShowAsProc 'satisfying IPKG dependencies'

    while [[ $iterations -lt $ITERATION_LIMIT ]]; do
        ((iterations++))

        local IPKG_titles=$(printf '^Package: %s$\|' "${this_list[@]}")
        IPKG_titles=${IPKG_titles%??}       # remove last 2 characters

        this_list=($($GNU_GREP_CMD --word-regexp --after-context 1 --no-group-separator '^Package:\|^Depends:' "$EXTERNAL_PACKAGE_LIST_PATHFILE" | $GNU_GREP_CMD -vG '^Section:\|^Version:' | $GNU_GREP_CMD --word-regexp --after-context 1 --no-group-separator "$IPKG_titles" | $GNU_GREP_CMD -vG "$IPKG_titles" | $GNU_GREP_CMD -vG '^Package: ' | $SED_CMD 's|^Depends: ||;s|, |\n|g' | $SORT_CMD | $UNIQ_CMD))

        if [[ ${#this_list[@]} -eq 0 ]]; then
            DebugAsDone 'complete'
            DebugInfo "found all IPKG dependencies in $iterations iteration$(FormatAsPlural $iterations)"
            complete=true
            break
        else
            dependency_accumulator+=(${this_list[*]})
        fi
    done

    if [[ $complete = false ]]; then
        DebugAsError "IPKG dependency list is incomplete! Consider raising \$ITERATION_LIMIT [$ITERATION_LIMIT]."
        Session.SuggestIssue.Set
    fi

    pre_download_list=$(DeDupeWords "$requested_list ${dependency_accumulator[*]}")
    DebugInfo 'IPKGs requested + dependencies' "$pre_download_list "
    DebugAsProc 'excluding IPKGs already installed'

    for element in $pre_download_list; do
        # KLUDGE: 'ca-certs' appears to be a bogus meta-package, so silently exclude it from attempted installation.
        if [[ $element != 'ca-certs' ]]; then
            # KLUDGE: 'libjpeg' appears to have been replaced by 'libjpeg-turbo', but many packages still list 'libjpeg' as a dependency, so replace it with 'libjpeg-turbo'.
            if [[ $element != 'libjpeg' ]]; then
                if ! $OPKG_CMD status "$element" | $GREP_CMD -q "Status:.*installed"; then
                    IPKGs.ToDownload.Add "$element"
                fi
            elif ! $OPKG_CMD status 'libjpeg-turbo' | $GREP_CMD -q "Status:.*installed"; then
                IPKGs.ToDownload.Add libjpeg-turbo
            fi
        fi
    done

    DebugAsDone 'complete'
    DebugInfo 'IPKGs to download' "$(IPKGs.ToDownload.List) "
    package_count=$(IPKGs.ToDownload.Count)

    if [[ $package_count -gt 0 ]]; then
        DebugAsProc "determining size of IPKG$(FormatAsPlural "$package_count") to download"
        size_array=($($GNU_GREP_CMD -w '^Package:\|^Size:' "$EXTERNAL_PACKAGE_LIST_PATHFILE" | $GNU_GREP_CMD --after-context 1 --no-group-separator ": $($SED_CMD 's/ /$ /g;s/\$ /\$\\\|: /g' <<< "$(IPKGs.ToDownload.List)")$" | $GREP_CMD '^Size:' | $SED_CMD 's|^Size: ||'))
        IPKGs.ToDownload.Size = "$(IFS=+; echo "$((${size_array[*]}))")"   # a neat sizing shortcut found here https://stackoverflow.com/a/13635566/6182835
        DebugAsDone 'complete'
        DebugInfo "IPKG download size: $(IPKGs.ToDownload.Size)"
        DebugAsDone "$package_count IPKG$(FormatAsPlural "$package_count") ($(FormatAsISOBytes "$(IPKGs.ToDownload.Size)")) to be downloaded"
    else
        DebugAsDone 'no IPKGs are required'
    fi

    ShowAsDone 'satisfied IPKG dependencies OK'
    IPKGs.Archive.Close
    DebugFuncExit; return 0

    }

CalcAllIPKGDepsToUninstall()
    {

    # From a specified list of IPKG names, exclude those already installed, then generate a total qty to uninstall

    if IsNotSysFileExist $OPKG_CMD || IsNotSysFileExist $GNU_GREP_CMD; then
        code_pointer=6
        return 1
    fi

    DebugFuncEntry
    local requested_list=''
    local package_count=0
    local element=''

    requested_list=$(DeDupeWords "$(IPKGs.ToUninstall.List)")

    DebugInfo 'IPKGs requested' "$requested_list "
    DebugAsProc 'excluding IPKGs not installed'

    for element in $requested_list; do
        ! $OPKG_CMD status "$element" | $GREP_CMD -q "Status:.*installed" && IPKGs.ToUninstall.Remove "$element"
    done

    DebugAsDone 'complete'
    DebugInfo 'IPKGs to uninstall' "$(IPKGs.ToUninstall.ListCSV) "
    package_count=$(IPKGs.ToUninstall.Count)

    if [[ $package_count -gt 0 ]]; then
        DebugAsDone 'complete'
        DebugAsDone "$package_count IPKG$(FormatAsPlural "$package_count") to be uninstalled"
    fi

    DebugFuncExit; return 0

    }

IPKGs.Install()
    {

    Session.SkipPackageProcessing.IsSet && return
    Session.IPKGs.Install.IsNot && return
    ! QPKG.Enabled Entware && return
    Entware.Update
    Session.Error.IsSet && return
    DebugFuncEntry
    local index=0

    IPKGs.ToInstall.Add "$SHERPA_COMMON_IPKGS_ADD"

    if User.Opts.Apps.All.Install.IsSet; then
        for index in "${!SHERPA_QPKG_NAME[@]}"; do
            [[ ${SHERPA_QPKG_ARCH[$index]} = "$NAS_QPKG_ARCH" || ${SHERPA_QPKG_ARCH[$index]} = all ]] && IPKGs.ToInstall.Add "${SHERPA_QPKG_IPKGS_ADD[$index]}"
        done
    else
        for index in "${!SHERPA_QPKG_NAME[@]}"; do
            if QPKGs.ToInstall.Exist "${SHERPA_QPKG_NAME[$index]}" || QPKG.Installed "${SHERPA_QPKG_NAME[$index]}" || QPKGs.ToUpgrade.Exist "${SHERPA_QPKG_NAME[$index]}" || QPKGs.ToForceUpgrade.Exist "${SHERPA_QPKG_NAME[$index]}"; then
                [[ ${SHERPA_QPKG_ARCH[$index]} = "$NAS_QPKG_ARCH" || ${SHERPA_QPKG_ARCH[$index]} = all ]] && IPKGs.ToInstall.Add "${SHERPA_QPKG_IPKGS_ADD[$index]}"
            fi
        done
    fi

    IPKGs.Upgrade.Batch
    IPKGs.Install.Batch

    # in-case 'python' has disappeared again ...
    [[ ! -L /opt/bin/python && -e /opt/bin/python3 ]] && ln -s /opt/bin/python3 /opt/bin/python

    DebugFuncExit; return 0

    }

IPKGs.Uninstall()
    {

    Session.SkipPackageProcessing.IsSet && return
    ! QPKG.Enabled Entware && return
    Session.Error.IsSet && return
    DebugFuncEntry
    local index=0

    if User.Opts.Apps.All.Uninstall.IsNot; then
        for index in "${!SHERPA_QPKG_NAME[@]}"; do
            if QPKGs.ToInstall.Exist "${SHERPA_QPKG_NAME[$index]}" || QPKG.Installed "${SHERPA_QPKG_NAME[$index]}" || QPKGs.ToUpgrade.Exist "${SHERPA_QPKG_NAME[$index]}" || QPKGs.ToUninstall.Exist "${SHERPA_QPKG_NAME[$index]}"; then
                IPKGs.ToUninstall.Add "${SHERPA_QPKG_IPKGS_REMOVE[$index]}"
            fi
        done

        # when package ARCH is 'none', prevent 'par2cmdline' being uninstalled, then installed again later this same session. Noticed this was happening on ARMv5 models.
        [[ $NAS_QPKG_ARCH = none ]] && IPKGs.ToUninstall.Remove par2cmdline

        IPKGs.Uninstall.Batch
    fi

    DebugFuncExit; return 0

    }

IPKGs.Upgrade.Batch()
    {

    # upgrade all installed IPKGs

    # output:
    #   $? = 0 (success) or 1 (failed)

    DebugFuncEntry
    local package_count=0
    local log_pathfile=$LOGS_PATH/ipkgs.$UPGRADE_LOG_FILE
    local resultcode=0

    IPKGs.ToDownload.Add "$($OPKG_CMD list-upgradable | $CUT_CMD -f1 -d' ')"
    package_count=$(IPKGs.ToDownload.Count)

    if [[ $package_count -gt 0 ]]; then
        ShowAsProc "downloading & upgrading $package_count IPKG$(FormatAsPlural "$package_count")"

        CreateDirSizeMonitorFlagFile "$IPKG_DL_PATH"/.monitor
            trap CTRL_C_Captured INT
                _MonitorDirSize_ "$IPKG_DL_PATH" "$(IPKGs.ToDownload.Size)" &

                RunAndLog "$OPKG_CMD upgrade$(User.Opts.IgnoreFreeSpace.IsSet && User.Opts.IgnoreFreeSpace.Text) --force-overwrite $(IPKGs.ToDownload.List) --cache $IPKG_CACHE_PATH --tmp-dir $IPKG_DL_PATH" "$log_pathfile"
                resultcode=$?
            trap - INT
        RemoveDirSizeMonitorFlagFile

        if [[ $resultcode -eq 0 ]]; then
            ShowAsDone "downloaded & upgraded $package_count IPKG$(FormatAsPlural "$package_count") OK"
        else
            ShowAsEror "download & upgrade $package_count IPKG$(FormatAsPlural "$package_count") failed $(FormatAsExitcode $resultcode)"
        fi
    fi

    DebugFuncExit; return $resultcode

    }

IPKGs.Install.Batch()
    {

    # output:
    #   $? = 0 (success) or 1 (failed)

    DebugFuncEntry
    local package_count=0
    local log_pathfile=$LOGS_PATH/ipkgs.addons.$INSTALL_LOG_FILE
    local resultcode=0

    CalcAllIPKGDepsToInstall || return 1
    package_count=$(IPKGs.ToDownload.Count)

    if [[ $package_count -gt 0 ]]; then
        ShowAsProc "downloading & installing $package_count IPKG$(FormatAsPlural "$package_count")"

        CreateDirSizeMonitorFlagFile "$IPKG_DL_PATH"/.monitor
            trap CTRL_C_Captured INT
                _MonitorDirSize_ "$IPKG_DL_PATH" "$(IPKGs.ToDownload.Size)" &

                RunAndLog "$OPKG_CMD install$(User.Opts.IgnoreFreeSpace.IsSet && User.Opts.IgnoreFreeSpace.Text) --force-overwrite $(IPKGs.ToDownload.List) --cache $IPKG_CACHE_PATH --tmp-dir $IPKG_DL_PATH" "$log_pathfile"
                resultcode=$?
            trap - INT
        RemoveDirSizeMonitorFlagFile

        if [[ $resultcode -eq 0 ]]; then
            ShowAsDone "downloaded & installed $package_count IPKG$(FormatAsPlural "$package_count") OK"
        else
            ShowAsEror "download & install $package_count IPKG$(FormatAsPlural "$package_count") failed $(FormatAsExitcode $resultcode)"
        fi
    fi

    DebugFuncExit; return $resultcode

    }

IPKGs.Uninstall.Batch()
    {

    # output:
    #   $? = 0 (success) or 1 (failed)

    DebugFuncEntry
    local package_count=0
    local log_pathfile=$LOGS_PATH/ipkgs.$UNINSTALL_LOG_FILE
    local resultcode=0

    CalcAllIPKGDepsToUninstall || return 1
    package_count=$(IPKGs.ToUninstall.Count)

    if [[ $package_count -gt 0 ]]; then
        ShowAsProc "uninstalling $package_count IPKG$(FormatAsPlural "$package_count")"

        RunAndLog "$OPKG_CMD remove $(IPKGs.ToUninstall.List)" "$log_pathfile"
        resultcode=$?

        if [[ $resultcode -eq 0 ]]; then
            ShowAsDone "uninstalled $package_count IPKG$(FormatAsPlural "$package_count") OK"
        else
            ShowAsEror "uninstall IPKG$(FormatAsPlural "$package_count") failed $(FormatAsExitcode $resultcode)"
        fi
    fi

    DebugFuncExit; return $resultcode

    }

IPKGs.Archive.Open()
    {

    # extract the 'opkg' package list file

    # output:
    #   $? = 0 (success) or 1 (failed)

    DebugFuncEntry

    if [[ ! -e $EXTERNAL_PACKAGE_ARCHIVE_PATHFILE ]]; then
        ShowAsEror 'unable to locate the IPKG list file'
        DebugFuncExit; return 1
    fi

    IPKGs.Archive.Close

    RunAndLog "$Z7_CMD e -o$($DIRNAME_CMD "$EXTERNAL_PACKAGE_LIST_PATHFILE") $EXTERNAL_PACKAGE_ARCHIVE_PATHFILE" "$WORK_PATH/ipkg.list.archive.extract" log:failure-only
    resultcode=$?

    if [[ ! -e $EXTERNAL_PACKAGE_LIST_PATHFILE ]]; then
        ShowAsEror 'unable to open the IPKG list file'
        DebugFuncExit; return 1
    fi

    DebugFuncExit; return 0

    }

IPKGs.Archive.Close()
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

    # output:
    #   stdout = "percentage downloaded (downloaded bytes/total expected bytes)"

    [[ -z $1 || ! -d $1 || -z $2 || $2 -eq 0 ]] && return
    IsNotSysFileExist $GNU_FIND_CMD && return

    local total_bytes=$2
    local last_bytes=0
    local stall_seconds=0
    local stall_seconds_threshold=4
    local stall_message=''
    local current_bytes=0
    local percent=''

    progress_message=''
    previous_length=0
    previous_clean_msg=''

    while [[ -e $monitor_flag_pathfile ]]; do
        current_bytes=$($GNU_FIND_CMD "$1" -type f -name '*.ipk' -exec $DU_CMD --bytes --total --apparent-size {} + 2> /dev/null | $GREP_CMD total$ | $CUT_CMD -f1)
        [[ -z $current_bytes ]] && current_bytes=0

        if [[ $current_bytes -ne $last_bytes ]]; then
            stall_seconds=0
            last_bytes=$current_bytes
        else
            ((stall_seconds++))
        fi

        percent="$((200*(current_bytes)/(total_bytes) % 2 + 100*(current_bytes)/(total_bytes)))%"
        [[ $current_bytes -lt $total_bytes && $percent = '100%' ]] && percent='99%' # ensure we don't hit 100% until the last byte is downloaded
        progress_message="$percent ($(FormatAsISOBytes "$current_bytes")/$(FormatAsISOBytes "$total_bytes"))"

        if [[ $stall_seconds -ge $stall_seconds_threshold ]]; then
            # append a message showing time that download has stalled for
            if [[ $stall_seconds -lt 60 ]]; then
                stall_message=" stalled for $stall_seconds seconds"
            else
                stall_message=" stalled for $(ConvertSecsToHoursMinutesSecs $stall_seconds)"
            fi

            # add a suggestion to cancel if download has stalled for too long
            if [[ $stall_seconds -ge 90 ]]; then
                stall_message+=": cancel with CTRL+C and try again later"
            fi

            # colourise if required
            if [[ $stall_seconds -ge 90 ]]; then
                stall_message=$(ColourTextBrightRed "$stall_message")
            elif [[ $stall_seconds -ge 45 ]]; then
                stall_message=$(ColourTextBrightOrange "$stall_message")
            elif [[ $stall_seconds -ge 20 ]]; then
                stall_message=$(ColourTextBrightYellow "$stall_message")
            fi

            progress_message+=$stall_message
        fi

        ProgressUpdater "$progress_message"
        $SLEEP_CMD 1
    done

    [[ -n $progress_message ]] && ProgressUpdater 'done!'

    }

ProgressUpdater()
    {

    # input:
    #   $1 = message to display

    this_clean_msg=$(StripANSI "$1")

    if [[ $this_clean_msg != "$previous_clean_msg" ]]; then
        this_length=$((${#this_clean_msg}+1))

        if [[ $this_length -lt $previous_length ]]; then
            blanking_length=$((this_length-previous_length))
            # backspace to start of previous msg, print new msg, add additional spaces, then backspace to end of msg
            printf "%${previous_length}s" | tr ' ' '\b'; DisplayWait "$1"; printf "%${blanking_length}s"; printf "%${blanking_length}s" | tr ' ' '\b'
        else
            # backspace to start of previous msg, print new msg
            printf "%${previous_length}s" | tr ' ' '\b'; DisplayWait "$1"
        fi

        previous_length=$this_length
        previous_clean_msg=$this_clean_msg
    fi

    }

CreateDirSizeMonitorFlagFile()
    {

    [[ -z $1 ]] && return 1
    monitor_flag_pathfile=$1
    $TOUCH_CMD "$monitor_flag_pathfile"

    }

RemoveDirSizeMonitorFlagFile()
    {

    if [[ -n $monitor_flag_pathfile && -e $monitor_flag_pathfile ]]; then
        rm -f "$monitor_flag_pathfile"
        $SLEEP_CMD 2
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

CheckPythonPathAndVersion()
    {

    [[ -z $1 ]] && return

    if location=$(command -v "$1" 2>&1); then
        DebugUserspace.OK "'$1' path" "$location"
        if version=$($1 -V 2>&1); then
            DebugUserspace.OK "'$1' version" "$version"
        else
            DebugUserspace.Warning "default '$1' version" ' '
        fi
    else
        DebugUserspace.Warning "'$1' path" ' '
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
        ShowAsAbort "a required NAS system file is missing $(FormatAsFileName "$1")"
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

DisplayAsProjectSyntaxExample()
    {

    # $1 = description
    # $2 = example syntax

    if [[ ${1: -1} = '!' ]]; then
        printf "\n* %s \n       # %s\n" "$(tr 'a-z' 'A-Z' <<< "${1:0:1}")${1:1}" "$PROJECT_NAME $2"
    else
        printf "\n* %s:\n       # %s\n" "$(tr 'a-z' 'A-Z' <<< "${1:0:1}")${1:1}" "$PROJECT_NAME $2"
    fi

    Session.LineSpace.Clear

    }

DisplayAsProjectSyntaxIndentedExample()
    {

    # $1 = description
    # $2 = example syntax

    if [[ -z $2 ]]; then
        printf "\n   %s \n" "$(tr 'a-z' 'A-Z' <<< "${1:0:1}")${1:1}"
    elif [[ -z $1 ]]; then
        printf "       # %s\n" "$PROJECT_NAME $2"
    elif [[ ${1: -1} = '!' ]]; then
        printf "\n   %s \n       # %s\n" "$(tr 'a-z' 'A-Z' <<< "${1:0:1}")${1:1}" "$PROJECT_NAME $2"
    else
        printf "\n   %s:\n       # %s\n" "$(tr 'a-z' 'A-Z' <<< "${1:0:1}")${1:1}" "$PROJECT_NAME $2"
    fi

    Session.LineSpace.Clear

    }

DisplayAsSyntaxExample()
    {

    # $1 = description
    # $2 = example syntax

    if [[ -z $2 && ${1: -1} = ':' ]]; then
        printf "\n* %s\n" "$1"
    elif [[ ${1: -1} = '!' ]]; then
        printf "\n* %s \n       # %s\n" "$(tr 'a-z' 'A-Z' <<< "${1:0:1}")${1:1}" "$2"
    else
        printf "\n* %s:\n       # %s\n" "$(tr 'a-z' 'A-Z' <<< "${1:0:1}")${1:1}" "$2"
    fi

    Session.LineSpace.Clear

    }

DisplayAsHelpPackageNameExample()
    {

    # $1 = description
    # $2 = example syntax

    printf "   %-20s %s\n" "$1" "$2"

    }

SmartCR()
    {

    # reset cursor to start-of-line, erasing previous characters

    [[ $(type -t Session.Debug.To.Screen.Init) = 'function' ]] && Session.Debug.To.Screen.IsNot && echo -en "\033[1K\r"

    }

Display()
    {

    echo -e "$1"
    [[ $(type -t Session.LineSpace.Init) = 'function' ]] && Session.LineSpace.Clear

    }

DisplayWait()
    {

    echo -en "$1 "

    }

Help.Basic.Show()
    {

    SmartCR
    DisplayLineSpaceIfNoneAlready
    Display "Usage: $(FormatAsScriptTitle) $(FormatAsHelpAction) $(FormatAsHelpPackages) $(FormatAsHelpOptions)"

    return 0

    }

Help.Basic.Example.Show()
    {

    DisplayAsProjectSyntaxIndentedExample "to list available $(FormatAsHelpAction)s, type" 'list actions'

    DisplayAsProjectSyntaxIndentedExample "to list available $(FormatAsHelpPackages), type" 'list packages'

    DisplayAsProjectSyntaxIndentedExample "or, for more $(FormatAsHelpOptions), type" 'list options'

    Display "\nThere's also the wiki: $(FormatAsURL 'https://github.com/OneCDOnly/sherpa/wiki')"

    return 0

    }

Help.Actions.Show()
    {

    Help.Basic.Show
    DisplayLineSpaceIfNoneAlready
    Display "* $(FormatAsHelpAction) usage examples:"

    DisplayAsProjectSyntaxIndentedExample 'install these packages' "install $(FormatAsHelpPackages)"

    DisplayAsProjectSyntaxIndentedExample 'uninstall these packages' "uninstall $(FormatAsHelpPackages)"

    DisplayAsProjectSyntaxIndentedExample 'reinstall these packages' "reinstall $(FormatAsHelpPackages)"

    DisplayAsProjectSyntaxIndentedExample 'upgrade these packages (and internal applications)' "upgrade $(FormatAsHelpPackages)"

    DisplayAsProjectSyntaxIndentedExample 'start these packages' "start $(FormatAsHelpPackages)"

    DisplayAsProjectSyntaxIndentedExample 'stop these packages (and internal applications)' "stop $(FormatAsHelpPackages)"

    DisplayAsProjectSyntaxIndentedExample 'restart these packages (and internal applications)' "restart $(FormatAsHelpPackages)"

    DisplayAsProjectSyntaxIndentedExample 'backup these application configurations to the backup location' "backup $(FormatAsHelpPackages)"

    DisplayAsProjectSyntaxIndentedExample 'restore these application configurations from the backup location' "restore $(FormatAsHelpPackages)"

    DisplayAsProjectSyntaxIndentedExample 'show application backup files' 'list backups'

    DisplayAsProjectSyntaxExample "$(FormatAsHelpAction) to affect all packages can be seen with" 'all-actions'

    DisplayAsProjectSyntaxExample "multiple $(FormatAsHelpAction)s are supported like this" "$(FormatAsHelpAction) $(FormatAsHelpPackages) $(FormatAsHelpAction) $(FormatAsHelpPackages)"
    DisplayAsProjectSyntaxIndentedExample '' 'install sabnzbd sickchill restart transmission uninstall lazy nzbget upgrade nzbtomedia'

    return 0

    }

Help.ActionsAll.Show()
    {

    Help.Basic.Show
    DisplayLineSpaceIfNoneAlready
    Display "* These $(FormatAsHelpAction)s apply to all installed packages. If $(FormatAsHelpAction) is 'install all' then all available packages will be affected."
    DisplayLineSpaceIfNoneAlready
    Display "* $(FormatAsHelpAction) usage examples:"

    DisplayAsProjectSyntaxIndentedExample 'install everything!' 'install all'

    DisplayAsProjectSyntaxIndentedExample "uninstall everything!" 'force uninstall all'

    DisplayAsProjectSyntaxIndentedExample "reinstall all installed packages" 'reinstall all'

    DisplayAsProjectSyntaxIndentedExample 'upgrade all installed packages (and internal applications)' 'upgrade all'

    DisplayAsProjectSyntaxIndentedExample 'start all installed packages (upgrade internal applications, not packages)' 'start all'

    DisplayAsProjectSyntaxIndentedExample 'stop all installed packages' 'stop all'

    DisplayAsProjectSyntaxIndentedExample 'restart all installed packages (upgrade internal applications, not packages)' 'restart all'

    DisplayAsProjectSyntaxIndentedExample 'list all available packages' 'list all'

    DisplayAsProjectSyntaxIndentedExample 'list only installed packages' 'list installed'

    DisplayAsProjectSyntaxIndentedExample 'list only installable packages' 'list installable'

    DisplayAsProjectSyntaxIndentedExample 'list only upgradable packages' 'list upgradable'

    DisplayAsProjectSyntaxIndentedExample 'backup all application configurations to the backup location' 'backup all'

    DisplayAsProjectSyntaxIndentedExample 'restore all application configurations from the backup location' 'restore all'

    Help.BackupLocation.Show

    return 0

    }

Help.Packages.Show()
    {

    local package=''
    local package_note=''

    Help.Basic.Show
    DisplayLineSpaceIfNoneAlready
    Display "* $(FormatAsHelpPackages) may be one-or-more of the following (space-separated):\n"

    for package in $(QPKGs.Installable.Array); do
        if QPKGs.Upgradable.Exist "$package"; then
            package_note='(upgradable)'
        elif QPKGs.Installed.Exist "$package"; then
            package_note='(installed)'
        else
            package_note=''
        fi

        DisplayAsHelpPackageNameExample "$package" "$package_note"
    done

    DisplayAsProjectSyntaxExample "example: to install $(FormatAsPackageName SABnzbd)" 'install SABnzbd'

    DisplayAsProjectSyntaxExample "example: to install both $(FormatAsPackageName SABnzbd) and $(FormatAsPackageName SickChill)" 'install SABnzbd SickChill'

    DisplayAsProjectSyntaxExample "abbreviations may also be used to specify $(FormatAsHelpPackages). To list these" 'list abs'

    return 0

    }

Help.Options.Show()
    {

    Help.Basic.Show
    DisplayLineSpaceIfNoneAlready
    Display "* $(FormatAsHelpOptions) usage examples:"

    DisplayAsProjectSyntaxIndentedExample 'process one-or-more packages and show live debugging information' "$(FormatAsHelpAction) $(FormatAsHelpPackages) debug"

    DisplayAsProjectSyntaxIndentedExample "don't check free-space on target filesystem when installing $(FormatAsPackageName Entware) packages" "$(FormatAsHelpAction) $(FormatAsHelpPackages) ignore-space"

    DisplayAsProjectSyntaxIndentedExample 'display helpful tips and shortcuts' 'tips'

    DisplayAsProjectSyntaxIndentedExample 'display troubleshooting options' 'problems'

    return 0

    }

Help.Problems.Show()
    {

    Help.Basic.Show
    DisplayLineSpaceIfNoneAlready
    Display '* usage examples when dealing with problems:'

    DisplayAsProjectSyntaxIndentedExample 'process one-or-more packages and show live debugging information' "$(FormatAsHelpAction) $(FormatAsHelpPackages) debug"

    DisplayAsProjectSyntaxIndentedExample 'ensure all application dependencies are installed' 'check all'

    DisplayAsProjectSyntaxIndentedExample "don't check free-space on target filesystem when installing $(FormatAsPackageName Entware) packages" "$(FormatAsHelpAction) $(FormatAsHelpPackages) ignore-space"

    DisplayAsProjectSyntaxIndentedExample "clean the $(FormatAsScriptTitle) cache" 'clean'

    DisplayAsProjectSyntaxIndentedExample 'force-upgrade these packages and the internal applications' "force upgrade $(FormatAsHelpPackages)"

    DisplayAsProjectSyntaxIndentedExample 'restart all installed packages (upgrades the internal applications, not packages)' 'restart all'

    DisplayAsProjectSyntaxIndentedExample 'start these packages and enable package icons' "start $(FormatAsHelpPackages)"

    DisplayAsProjectSyntaxIndentedExample 'stop these packages and disable package icons' "stop $(FormatAsHelpPackages)"

    DisplayAsProjectSyntaxIndentedExample "view only the most recent $(FormatAsScriptTitle) session log" 'l'

    DisplayAsProjectSyntaxIndentedExample "view the entire $(FormatAsScriptTitle) session log" 'log'

    DisplayAsProjectSyntaxIndentedExample "upload the most-recent session in your $(FormatAsScriptTitle) log to the $(FormatAsURL 'https://termbin.com') public pastebin. A URL will be generated afterward" 'p'

    DisplayAsProjectSyntaxIndentedExample "upload the most-recent $(FormatAsThousands "$LOG_TAIL_LINES") entries in your $(FormatAsScriptTitle) log to the $(FormatAsURL 'https://termbin.com') public pastebin. A URL will be generated afterward" 'paste'

    Display "\n$(ColourTextBrightOrange "* If you need help, please include a copy of your") $(FormatAsScriptTitle) $(ColourTextBrightOrange "log for analysis!")"

    return 0

    }

Help.Issue.Show()
    {

    DisplayLineSpaceIfNoneAlready
    Display "* Please consider creating a new issue for this on GitHub:\n\thttps://github.com/OneCDOnly/sherpa/issues"

    Display "\n* Alternatively, post on the QNAP NAS Community Forum:\n\thttps://forum.qnap.com/viewtopic.php?f=320&t=132373"

    DisplayAsProjectSyntaxIndentedExample "view only the most recent $(FormatAsScriptTitle) session log" 'last'

    DisplayAsProjectSyntaxIndentedExample "view the entire $(FormatAsScriptTitle) session log" 'log'

    DisplayAsProjectSyntaxIndentedExample "upload the most-recent $(FormatAsThousands "$LOG_TAIL_LINES") entries in your $(FormatAsScriptTitle) log to the $(FormatAsURL 'https://termbin.com') public pastebin. A URL will be generated afterward" 'paste'

    Display "\n$(ColourTextBrightOrange '* If you need help, please include a copy of your') $(FormatAsScriptTitle) $(ColourTextBrightOrange 'log for analysis!')"

    return 0

    }

Help.Tips.Show()
    {

    Help.Basic.Show
    DisplayLineSpaceIfNoneAlready
    Display '* helpful tips and shortcuts:'

    DisplayAsProjectSyntaxIndentedExample "install all available $(FormatAsScriptTitle) packages" 'install all'

    DisplayAsProjectSyntaxIndentedExample 'package abbreviations also work. To see these' 'list abs'

    DisplayAsProjectSyntaxIndentedExample 'restart all packages (only upgrades the internal applications, not packages)' 'restart all'

    DisplayAsProjectSyntaxIndentedExample 'list only packages that are not installed' 'list installable'

    DisplayAsProjectSyntaxIndentedExample "view only the most recent $(FormatAsScriptTitle) session log" 'l'

    DisplayAsProjectSyntaxIndentedExample 'upgrade the internal applications only' "restart $(FormatAsHelpPackages)"

    Help.BackupLocation.Show

    return 0

    }

Help.PackageAbbreviations.Show()
    {

    [[ ${#SHERPA_QPKG_NAME[@]} -eq 0 || ${#SHERPA_QPKG_ABBRVS[@]} -eq 0 ]] && return 1

    local package_index=0
    Help.Basic.Show
    DisplayLineSpaceIfNoneAlready
    Display "* $(FormatAsScriptTitle) recognises these abbreviations as $(FormatAsHelpPackages):"

    for package_index in "${!SHERPA_QPKG_NAME[@]}"; do
        if [[ -n ${SHERPA_QPKG_ABBRVS[$package_index]} ]]; then
            if QPKGs.Upgradable.Exist "${SHERPA_QPKG_NAME[$package_index]}"; then
                printf "%32s: %s\n" "$(ColourTextBrightOrange "${SHERPA_QPKG_NAME[$package_index]}")" "$($SED_CMD 's| |, |g' <<< "${SHERPA_QPKG_ABBRVS[$package_index]}")"
            else
                printf "%15s: %s\n" "${SHERPA_QPKG_NAME[$package_index]}" "$($SED_CMD 's| |, |g' <<< "${SHERPA_QPKG_ABBRVS[$package_index]}")"
            fi
        fi
    done

    DisplayAsProjectSyntaxExample "example: to install $(FormatAsPackageName SABnzbd), $(FormatAsPackageName Mylar3) and $(FormatAsPackageName nzbToMedia) all-at-once" 'install sab my nzb2'

    return 0

    }

Help.BackupLocation.Show()
    {

    DisplayAsSyntaxExample 'the backup location can be accessed by running' "cd $(Session.Backup.Path)"

    return 0

    }

Log.Whole.View()
    {

    if [[ -e $DEBUG_LOG_PATHFILE ]]; then
        if [[ -e $GNU_LESS_CMD ]]; then
            LESSSECURE=1 $GNU_LESS_CMD +G --quit-on-intr --tilde --LINE-NUMBERS --prompt ' use arrow-keys to scroll up-down left-right, press Q to quit' "$DEBUG_LOG_PATHFILE"
        else
            $CAT_CMD --number "$DEBUG_LOG_PATHFILE"
        fi
    else
        ShowAsEror 'no session log to display'
    fi

    return 0

    }

Log.Last.View()
    {

    # view only the last sherpa session

    ExtractLastSessionFromTail

    if [[ -e $SESSION_LAST_PATHFILE ]]; then
        if [[ -e $GNU_LESS_CMD ]]; then
            LESSSECURE=1 $GNU_LESS_CMD +G --quit-on-intr --tilde --LINE-NUMBERS --prompt ' use arrow-keys to scroll up-down left-right, press Q to quit' "$SESSION_LAST_PATHFILE"
        else
            $CAT_CMD --number "$SESSION_LAST_PATHFILE"
        fi
    else
        ShowAsEror 'no last session log to display'
    fi

    return 0

    }

Log.Tail.Paste.Online()
    {

    ExtractTailFromLog

    if [[ -e $SESSION_TAIL_PATHFILE ]]; then
        if AskQuiz "Press 'Y' to post the most-recent $(FormatAsThousands "$LOG_TAIL_LINES") entries in your $(FormatAsScriptTitle) log to a public pastebin, or any other key to abort"; then
            ShowAsProc "uploading $(FormatAsScriptTitle) log"
            # with thanks to https://github.com/solusipse/fiche
            link=$($CAT_CMD -n "$SESSION_TAIL_PATHFILE" | (exec 3<>/dev/tcp/termbin.com/9999; $CAT_CMD >&3; $CAT_CMD <&3; exec 3<&-))

            if [[ $? -eq 0 ]]; then
                ShowAsDone "your $(FormatAsScriptTitle) log is now online at $(FormatAsURL "$($SED_CMD 's|http://|http://l.|;s|https://|https://l.|' <<< "$link")") and will be deleted in 1 month"
            else
                ShowAsEror "a link could not be generated. Most likely a problem occurred when talking with $(FormatAsURL 'https://termbin.com')"
            fi
        else
            DebugInfoMinorSeparator
            DebugScript 'user abort'
            Session.Summary.Clear
            return 1
        fi
    else
        ShowAsEror 'no tail log to paste'
    fi

    return 0

    }

Log.Last.Paste.Online()
    {

    ExtractLastSessionFromTail

    if [[ -e $SESSION_LAST_PATHFILE ]]; then
        if AskQuiz "Press 'Y' to post the most-recent session in your $(FormatAsScriptTitle) log to a public pastebin, or any other key to abort"; then
            ShowAsProc "uploading $(FormatAsScriptTitle) log"
            # with thanks to https://github.com/solusipse/fiche
            link=$($CAT_CMD "$SESSION_LAST_PATHFILE" | (exec 3<>/dev/tcp/termbin.com/9999; $CAT_CMD >&3; $CAT_CMD <&3; exec 3<&-))

            if [[ $? -eq 0 ]]; then
                ShowAsDone "your $(FormatAsScriptTitle) log is now online at $(FormatAsURL "$($SED_CMD 's|http://|http://l.|;s|https://|https://l.|' <<< "$link")") and will be deleted in 1 month"
            else
                ShowAsEror "a link could not be generated. Most likely a problem occurred when talking with $(FormatAsURL 'https://termbin.com')"
            fi
        else
            DebugInfoMinorSeparator
            DebugScript 'user abort'
            Session.Summary.Clear
            return 1
        fi
    else
        ShowAsEror 'no last session log to paste'
    fi

    return 0

    }

ExtractLastSessionFromTail()
    {

    local -i start_line=0
    local -i end_line=0

    ExtractTailFromLog

    if [[ -e $SESSION_TAIL_PATHFILE ]]; then
        start_line=$(($($GREP_CMD -n 'SCRIPT:.*started:' "$SESSION_TAIL_PATHFILE" | $TAIL_CMD -n1 | $CUT_CMD -d':' -f1)-1))
        end_line=$(($($GREP_CMD -n 'SCRIPT:.*finished:' "$SESSION_TAIL_PATHFILE" | $TAIL_CMD -n1 | $CUT_CMD -d':' -f1)+2))
        [[ $start_line -gt $end_line ]] && end_line=$($WC_CMD -l "$SESSION_TAIL_PATHFILE" | $CUT_CMD -d' ' -f1)

        $SED_CMD "$start_line,$end_line!d" "$SESSION_TAIL_PATHFILE" > "$SESSION_LAST_PATHFILE"
    else
        [[ -e $SESSION_LAST_PATHFILE ]] && rm -rf "$SESSION_LAST_PATHFILE"
    fi

    return 0

    }

ExtractTailFromLog()
    {

    if [[ -e $DEBUG_LOG_PATHFILE ]]; then
        $TAIL_CMD -n${LOG_TAIL_LINES} "$DEBUG_LOG_PATHFILE" > "$SESSION_TAIL_PATHFILE"   # trim main log first so there's less to 'grep'
    else
        [[ -e $SESSION_TAIL_PATHFILE ]] && rm -rf "$SESSION_TAIL_PATHFILE"
    fi

    return 0

    }

Versions.Show()
    {

    Display "manager: $MANAGER_SCRIPT_VERSION"
    Display "loader: $LOADER_SCRIPT_VERSION"
    Display "package: $PACKAGE_VERSION"
    Display "objects hash: $COMPILED_OBJECTS_HASH"

    return 0

    }

QPKGs.NewVersions.Show()
    {

    # Check installed QPKGs and compare versions against package arrays. If new versions are available, advise on-screen.

    # $? = 0 if all packages are up-to-date
    # $? = 1 if one-or-more packages can be upgraded

    local msg=''
    local index=0
    local left_to_upgrade=()
    local names_formatted=''

    for package in $(QPKGs.Upgradable.Array); do
        # only show upgradable packages if they haven't been selected for upgrade in current session
        if ! QPKGs.ToUpgrade.Exist "$package" && ! QPKGs.ToReinstall.Exist "$package"; then
            left_to_upgrade+=("$package")
        fi
    done

    [[ ${#left_to_upgrade[@]} -eq 0 ]] && return 0

    for ((index=0;index<=((${#left_to_upgrade[@]}-1));index++)); do
        names_formatted+=$(ColourTextBrightOrange "${left_to_upgrade[$index]}")

        if [[ $((index+2)) -lt ${#left_to_upgrade[@]} ]]; then
            names_formatted+=', '
        elif [[ $((index+2)) -eq ${#left_to_upgrade[@]} ]]; then
            names_formatted+=' & '
        fi
    done

    if [[ ${#left_to_upgrade[@]} -eq 1 ]]; then
        msg='an upgraded QPKG is'
    else
        msg='upgraded QPKGs are'
    fi

    ShowAsNote "$msg available for $names_formatted"
    return 1

    }

QPKGs.Conflicts.Check()
    {

    for package in "${SHERPA_COMMON_QPKG_CONFLICTS[@]}"; do
        if QPKG.Enabled "$package"; then
            ShowAsEror "'$package' is installed and enabled. One-or-more $(FormatAsScriptTitle) applications are incompatible with this package"
            return 1
        fi
    done

    return 0

    }

QPKGs.Assignment.Build()
    {

    # Ensure packages are assigned to the correct lists

    # As a package manager, package importance should always be:
    #  10. backup           (highest: most-important)
    #   9. restore
    #   8. force-upgrade
    #   7. upgrade
    #   6. reinstall
    #   5. install
    #   4. start
    #   3. restart
    #   2. stop
    #   1. uninstall        (lowest: least-important)

    # However, package processing priorities need to be:
    #  16. backup                   (highest: most-important)
    #  15. stop dependants
    #  14. stop essentials
    #  13. uninstall
    #  12. force-upgrade essentials
    #  11. upgrade essentials
    #  10. reinstall essentials
    #   9. install essentials
    #   8. start essentials
    #   7. force-upgrade dependants
    #   6. upgrade dependants
    #   5. reinstall dependants
    #   4. install dependants
    #   3. restore dependants
    #   2. start dependants
    #   1. restart                  (lowest: least-important)

    Session.SkipPackageProcessing.IsSet && return
    DebugFuncEntry
    local package=''
    local installer_acc=()
    local stop_acc=()

    # start by adding packages to lists as required

    if User.Opts.Apps.All.Backup.IsSet; then
        QPKGs.ToBackup.Add "$(QPKGs.Installed.Array)"
        QPKGs.ToBackup.Remove "$(QPKGs.Essential.Array)"
    fi

    User.Opts.Apps.All.Stop.IsSet && QPKGs.ToStop.Add "$(QPKGs.Installed.Array)"
    User.Opts.Apps.All.Uninstall.IsSet && QPKGs.ToUninstall.Add "$(QPKGs.Installed.Array)"

    if User.Opts.Apps.All.Uninstall.IsSet; then
        QPKGs.ToStop.Init   # no-need to 'stop' all packages, as they are about to be 'uninstalled'
    else
        # if an essential has been selected for 'stop', need to stop all 'optionals' first
        for package in $(QPKGs.ToStop.Array); do
            if QPKGs.Essential.Exist "$package" && QPKG.Installed "$package"; then
                stop_acc+=($(QPKG.Get.Dependencies "$package"))
            fi
        done

        # if an essential has been selected for 'uninstall', need to stop all 'optionals' first
        for package in $(QPKGs.ToUninstall.Array); do
            if QPKGs.Essential.Exist "$package" && QPKG.Installed "$package"; then
                stop_acc+=($(QPKG.Get.Dependencies "$package"))
            fi
        done

        if [[ ${#stop_acc[@]} -gt 0 ]]; then
            for package in "${stop_acc[@]}"; do
                ! QPKGs.ToUninstall.Exist "$package" && QPKG.Installed "$package" && QPKGs.ToStop.Add "$package"
            done
        fi
    fi

    QPKGs.ToStop.Remove sherpa
    QPKGs.ToUninstall.Remove sherpa

    User.Opts.Apps.All.ForceUpgrade.IsSet && QPKGs.ToForceUpgrade.Add "$(QPKGs.Installed.Array)"
    User.Opts.Apps.All.Upgrade.IsSet && QPKGs.ToUpgrade.Add "$(QPKGs.Upgradable.Array)"
    User.Opts.Apps.All.Reinstall.IsSet && QPKGs.ToReinstall.Add "$(QPKGs.Installed.Array)"
    User.Opts.Apps.All.Install.IsSet && QPKGs.ToInstall.Add "$(QPKGs.Installable.Array)"

    # check for essential packages that require installation
    for package in $(QPKGs.Installed.Array); do
        ! QPKGs.ToUninstall.Exist "$package" && installer_acc+=($(QPKG.Get.Essentials "$package"))
    done

    for package in $(QPKGs.ToInstall.Array); do
        installer_acc+=($(QPKG.Get.Essentials "$package"))
    done

    for package in $(QPKGs.ToReinstall.Array); do
        installer_acc+=($(QPKG.Get.Essentials "$package"))
    done

    for package in $(QPKGs.ToUpgrade.Array); do
        installer_acc+=($(QPKG.Get.Essentials "$package"))
    done

    for package in $(QPKGs.ToForceUpgrade.Array); do
        installer_acc+=($(QPKG.Get.Essentials "$package"))
    done

    for package in "${installer_acc[@]}"; do
        ! QPKG.Installed "$package" && QPKGs.ToInstall.Add "$package"
    done

    if User.Opts.Apps.All.Restore.IsSet; then
        QPKGs.ToRestore.Add "$(QPKGs.Installed.Array)"
        QPKGs.ToRestore.Remove "$(QPKGs.Essential.Array)"
    fi

    if User.Opts.Apps.All.Start.IsSet; then
        QPKGs.ToStart.Add "$(QPKGs.Installed.Array)"
    else
        # check for essential packages that require starting
        for package in $(QPKGs.ToStart.Array); do
            if ! QPKGs.ToUninstall.Exist "$package" && ! QPKGs.ToStop.Exist "$package"; then
                QPKGs.ToStart.Add "$(QPKG.Get.Essentials "$package")"
            fi
        done

        for package in $(QPKGs.ToInstall.Array); do
            QPKGs.ToStart.Add "$(QPKG.Get.Essentials "$package")"
        done

        for package in $(QPKGs.ToReinstall.Array); do
            QPKGs.ToStart.Add "$(QPKG.Get.Essentials "$package")"
        done

        for package in $(QPKGs.ToUpgrade.Array); do
            QPKGs.ToStart.Add "$(QPKG.Get.Essentials "$package")"
        done

        for package in $(QPKGs.ToForceUpgrade.Array); do
            QPKGs.ToStart.Add "$(QPKG.Get.Essentials "$package")"
        done
    fi

    User.Opts.Apps.All.Restart.IsSet && QPKGs.ToRestart.Add "$(QPKGs.Installed.Array)"

    # build an initial package download list. Items on this list will be skipped at download-time if they can be found in local cache.
    if User.Opts.Dependencies.Check.IsSet; then
        QPKGs.ToDownload.Add "$(QPKGs.Installed.Array)"
    else
        QPKGs.ToDownload.Add "$(QPKGs.ToForceUpgrade.Array)"
        QPKGs.ToDownload.Add "$(QPKGs.ToUpgrade.Array)"
        QPKGs.ToDownload.Add "$(QPKGs.ToReinstall.Array)"
        QPKGs.ToDownload.Add "$(QPKGs.ToInstall.Array)"
    fi

    QPKGs.Assignment.List
    DebugFuncExit; return 0

    }

QPKGs.Assignment.List()
    {

    DebugFuncEntry

    DebugQPKG 'to download' "$(QPKGs.ToDownload.ListCSV) "
    DebugQPKG 'to backup' "$(QPKGs.ToBackup.ListCSV) "
    DebugQPKG 'to uninstall' "$(QPKGs.ToUninstall.ListCSV) "
    DebugQPKG 'to stop' "$(QPKGs.ToStop.ListCSV) "
    DebugQPKG 'to force-upgrade' "$(QPKGs.ToForceUpgrade.ListCSV) "
    DebugQPKG 'to upgrade' "$(QPKGs.ToUpgrade.ListCSV) "
    DebugQPKG 'to reinstall' "$(QPKGs.ToReinstall.ListCSV) "
    DebugQPKG 'to install' "$(QPKGs.ToInstall.ListCSV) "
    DebugQPKG 'to restore' "$(QPKGs.ToRestore.ListCSV) "
    DebugQPKG 'to start' "$(QPKGs.ToStart.ListCSV) "
    DebugQPKG 'to restart' "$(QPKGs.ToRestart.ListCSV) "

    DebugFuncExit; return 0

    }

QPKGs.EssentialAndOptional.Build()
    {

    # there are three tiers of package: 'essential', 'addon' and 'optional'
    # ... but only two tiers of QPKG: 'essential' and 'optional'

    # 'essential' QPKGs don't depend on other QPKGs. They should be installed/started before any 'optional' QPKGs.
    # 'optional' QPKGs depend on other QPKGs. They should be installed/started after any 'essential' QPKGs.

    DebugFuncEntry
    local index=0

    for index in "${!SHERPA_QPKG_NAME[@]}"; do
        if [[ -n ${SHERPA_QPKG_ESSENTIALS[$index]} ]]; then
            QPKGs.Optional.Add "${SHERPA_QPKG_NAME[$index]}"    # if the 'SHERPA_QPKG_ESSENTIALS' field has some value, then this package is 'optional'
        else
            QPKGs.Essential.Add "${SHERPA_QPKG_NAME[$index]}"   # if the 'SHERPA_QPKG_ESSENTIALS' field is empty, then this package is 'essential'
        fi
    done

    DebugFuncExit; return 0

    }

QPKGs.InstallationState.Build()
    {

    # Builds a list of QPKGs that can be installed or reinstalled by the user

    DebugFuncEntry
    local package=''

    for package in $(QPKGs.Names.Array); do
        QPKG.UserInstallable "$package" && QPKGs.Installable.Add "$package"

        if QPKG.Installed "$package"; then
            QPKGs.Installed.Add "$package"
        else
            QPKGs.NotInstalled.Add "$package"
        fi
    done

    DebugFuncExit; return 0

    }

QPKGs.Upgradable.Build()
    {

    # Builds a list of QPKGs that can be upgraded

    DebugFuncEntry
    local package=''
    local installed_version=''
    local remote_version=''

    for package in $(QPKGs.Installed.Array); do
        # KLUDGE: ignore 'Entware' as package filename version doesn't match the QTS App Center version string
        [[ $package = Entware || $package = Par2 ]] && continue

        installed_version=$(QPKG.InstalledVersion "$package")
        remote_version=$(QPKG.URLVersion "$package")

        if [[ $installed_version != "$remote_version" ]]; then
            #QPKGs.Upgradable.Add "$package $installed_version $remote_version"
            QPKGs.Upgradable.Add "$package"
        fi
    done

    DebugFuncExit; return 0

    }

QPKGs.All.Show()
    {

    local package=''

    for package in $(QPKGs.Names.Array); do
        Display "$package"
    done

    return 0

    }

QPKGs.Backups.Show()
    {

    SmartCR
    Display "* The location for $(FormatAsScriptTitle) backups is: $(Session.Backup.Path)"
    Display

    if [[ -e $GNU_FIND_CMD ]]; then
        printf '%-33s%s\n' '* backup file:' '* last backup date:'
        $GNU_FIND_CMD "$(Session.Backup.Path)"/*.config.tar.gz -maxdepth 1 -printf '%-33f%Cc\n' 2>/dev/null
    else
        (cd "$(Session.Backup.Path)" && ls -1 ./*.config.tar.gz)
    fi

    return 0

    }

QPKGs.Installed.Show()
    {

    local package=''

    for package in $(QPKGs.Installed.Array); do
        Display "$package"
    done

    return 0

    }

QPKGs.NotInstalled.Show()
    {

    local package=''

    for package in $(QPKGs.NotInstalled.Array); do
        Display "$package"
    done

    return 0

    }

QPKGs.Upgradable.Show()
    {

    local package=''

    for package in $(QPKGs.Upgradable.Array); do
        Display "$package"
    done

    return 0

    }

QPKGs.Essential.Show()
    {

    local package=''

    for package in $(QPKGs.Essential.Array); do
        Display "$package"
    done

    return 0

    }

QPKGs.Optional.Show()
    {

    local package=''

    for package in $(QPKGs.Optional.Array); do
        Display "$package"
    done

    return 0

    }

Session.Calc.QPKGArch()
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
    DebugQPKG 'arch' "$NAS_QPKG_ARCH"

    return 0

    }

Session.Calc.EntwareType()
    {

    if QPKG.Installed Entware; then
        if [[ -e /opt/etc/passwd ]]; then
            if [[ -L /opt/etc/passwd ]]; then
                ENTWARE_VER=std
            else
                ENTWARE_VER=alt
            fi
        else
            ENTWARE_VER=none
        fi

        DebugQPKG 'Entware installer' $ENTWARE_VER

        if [[ $ENTWARE_VER = none ]]; then
            DebugAsWarning "$(FormatAsPackageName Entware) appears to be installed but is not visible"
        fi
    fi

    }

Session.AddPathToEntware()
    {

    local opkg_prefix=/opt/bin:/opt/sbin

    if QPKG.Installed Entware; then
        export PATH="$opkg_prefix:$($SED_CMD "s|$opkg_prefix||" <<< "$PATH")"
        DebugAsDone 'added $PATH to Entware'
        DebugVar PATH
    fi

    return 0

    }

Session.RemovePathToEntware()
    {

    local opkg_prefix=/opt/bin:/opt/sbin

    if QPKG.Installed Entware; then
        export PATH="$($SED_CMD "s|$opkg_prefix||" <<< "$PATH")"
        DebugAsDone 'removed $PATH to Entware'
        DebugVar PATH
    fi

    return 0

    }

Session.Error.Set()
    {

    [[ $(type -t Session.SkipPackageProcessing.Init) = 'function' ]] && Session.SkipPackageProcessing.Set
    Session.Error.IsSet && return
    _script_error_flag=true
    DebugVar _script_error_flag

    }

Session.Error.IsSet()
    {

    [[ $_script_error_flag = true ]]

    }

Session.Error.IsNot()
    {

    [[ $_script_error_flag != true ]]

    }

Session.Summary.Show()
    {

    if User.Opts.Apps.All.Upgrade.IsSet; then
        if QPKGs.Upgradable.IsNone; then
            ShowAsDone 'no QPKGs needed upgrading'
        elif Session.Error.IsNot; then
            ShowAsDone 'all upgradable QPKGs were upgraded OK'
        else
            ShowAsEror "upgrade failed! [$code_pointer]"
            Session.SuggestIssue.Set
        fi
    fi

    return 0

    }

Session.LockFile.Claim()
    {

    [[ -z $1 ]] && return 1
    readonly RUNTIME_LOCK_PATHFILE=$1

    if [[ -e $RUNTIME_LOCK_PATHFILE && -d /proc/$(<"$RUNTIME_LOCK_PATHFILE") && $(</proc/"$(<"$RUNTIME_LOCK_PATHFILE")"/cmdline) =~ $MANAGER_SCRIPT_FILE ]]; then
        ShowAsAbort 'another instance is running'
        return 1
    else
        echo "$$" > "$RUNTIME_LOCK_PATHFILE"
    fi

    return 0

    }

Session.LockFile.Release()
    {

    [[ -z $RUNTIME_LOCK_PATHFILE ]] && return 1
    [[ -e $RUNTIME_LOCK_PATHFILE ]] && rm -f "$RUNTIME_LOCK_PATHFILE"

    }

QPKG.ServicePathFile()
    {

    # input:
    #   $1 = QPKG name

    # output:
    #   stdout = service pathfilename
    #   $? = 0 if found, 1 if not

    QPKG.NotInstalled "$1" && return 1
    local output=''

    if output=$($GETCFG_CMD "$1" Shell -f $APP_CENTER_CONFIG_PATHFILE); then
        echo "$output"
        return 0
    else
        echo 'unknown'
        return 1
    fi

    }

QPKG.InstalledVersion()
    {

    # Returns the version number of an installed QPKG.

    # input:
    #   $1 = QPKG name

    # output:
    #   stdout = package version
    #   $? = 0 if found, 1 if not

    QPKG.NotInstalled "$1" && return 1
    local output=''

    if output=$($GETCFG_CMD "$1" Version -f $APP_CENTER_CONFIG_PATHFILE); then
        echo "$output"
        return 0
    else
        echo 'unknown'
        return 1
    fi

    }

QPKG.ServiceStatus()
    {

    # $1 = QPKG name to install

    if [[ -e /var/run/$1.last.operation ]]; then
        case $(</var/run/"$1".last.operation) in
            ok)
                DebugInfo "$(FormatAsPackageName "$1") service started OK"
                ;;
            failed)
                ShowAsEror "$(FormatAsPackageName "$1") service failed to start.$([[ -e /var/log/$1.log ]] && echo " Check $(FormatAsFileName "/var/log/$1.log") for more information")"
                ;;
            *)
                DebugAsWarning "$(FormatAsPackageName "$1") service status is incorrect"
                ;;
        esac
    else
        DebugAsWarning "unable to get status of $(FormatAsPackageName "$1") service. It may be a non-sherpa package, or a package earlier than 200816c that doesn't support service results."
    fi

    }

QPKG.PathFilename()
    {

    # input:
    #   $1 = QPKG name

    # output:
    #   stdout = QPKG local filename
    #   $? = 0 if successful, 1 if failed

    echo "$QPKG_DL_PATH/$($BASENAME_CMD "$(QPKG.URL "$1")")"

    }

QPKG.URL()
    {

    # input:
    #   $1 = QPKG name

    # output:
    #   stdout = QPKG remote URL
    #   $? = 0 if successful, 1 if failed

    local index=0

    for index in "${!SHERPA_QPKG_NAME[@]}"; do
        if [[ $1 = "${SHERPA_QPKG_NAME[$index]}" ]] && [[ ${SHERPA_QPKG_ARCH[$index]} = all || ${SHERPA_QPKG_ARCH[$index]} = "$NAS_QPKG_ARCH" ]]; then
            echo "${SHERPA_QPKG_URL[$index]}"
            return 0
        fi
    done

    return 1

    }

QPKG.URLVersion()
    {

    # input:
    #   $1 = QPKG name

    # output:
    #   stdout = QPKG remote version
    #   $? = 0 if successful, 1 if failed

    local url=''
    local version=''

    if url=$(QPKG.URL "$1"); then
        version=${url#*_}; version=${version%.*}
        echo "$version"
        return 0
    else
        echo 'unknown'
        return 1
    fi

    }

QPKG.MD5()
    {

    # input:
    #   $1 = QPKG name

    # output:
    #   stdout = QPKG MD5
    #   $? = 0 if successful, 1 if failed

    local index=0

    for index in "${!SHERPA_QPKG_NAME[@]}"; do
        if [[ $1 = "${SHERPA_QPKG_NAME[$index]}" ]] && [[ ${SHERPA_QPKG_ARCH[$index]} = all || ${SHERPA_QPKG_ARCH[$index]} = "$NAS_QPKG_ARCH" ]]; then
            echo "${SHERPA_QPKG_MD5[$index]}"
            return 0
        fi
    done

    return 1

    }

QPKG.Get.Essentials()
    {

    # input:
    #   $1 = user QPKG name to return esssential packages for

    # output:
    #   $? = 0 if successful, 1 if failed

    local index=0

    for index in "${!SHERPA_QPKG_NAME[@]}"; do
        if [[ ${SHERPA_QPKG_NAME[$index]} = "$1" ]]; then
            echo "${SHERPA_QPKG_ESSENTIALS[$index]}"
            return 0
        fi
    done

    return 1

    }

QPKG.Get.Dependencies()
    {

    # input:
    #   $1 = essential QPKG name to return dependants for

    # output:
    #   $? = 0 if successful, 1 if failed

    local index=0
    local acc=()

    if QPKGs.Essential.Exist "$1"; then
        for index in "${!SHERPA_QPKG_NAME[@]}"; do
            if [[ ${SHERPA_QPKG_ESSENTIALS[$index]} == *"$1"* ]]; then
                [[ ${acc[*]} != "${SHERPA_QPKG_NAME[$index]}" ]] && acc+=(${SHERPA_QPKG_NAME[$index]})
            fi
        done
    fi

    if [[ ${#acc[@]} -gt 0 ]]; then
        echo "${acc[@]}"
        return 0
    else
        return 1
    fi

    }

QPKG.Download()
    {

    # input:
    #   $1 = QPKG name to download

    # output:
    #   $? = 0 if successful, 1 if failed, 10 if package was already downloaded

    Session.Error.IsSet && return
    DebugFuncEntry

    if [[ -z $1 ]]; then
        DebugFuncExit; return 1
    fi

    local resultcode=0
    local remote_url=$(QPKG.URL "$1")
    local remote_filename=$($BASENAME_CMD "$remote_url")
    local remote_md5=$(QPKG.MD5 "$1")
    local local_pathfile=$QPKG_DL_PATH/$remote_filename
    local local_filename=$($BASENAME_CMD "$local_pathfile")
    local log_pathfile=$LOGS_PATH/$local_filename.$DOWNLOAD_LOG_FILE

    if [[ -z $remote_url ]]; then
        DebugAsWarning "no URL found for this package $(FormatAsPackageName "$1")"
        DebugFuncExit; return
    fi

    if [[ -e $local_pathfile ]]; then
        if FileMatchesMD5 "$local_pathfile" "$remote_md5"; then
            DebugInfo "local package $(FormatAsFileName "$local_filename") checksum correct, so skipping download"
            resultcode=10
        else
            DebugAsWarning "local package $(FormatAsFileName "$local_filename") checksum incorrect"
            DebugInfo "deleting $(FormatAsFileName "$local_filename")"
            rm -f "$local_pathfile"
        fi
    fi

    if Session.Error.IsNot && [[ ! -e $local_pathfile ]]; then
        DebugAsProc "downloading $(FormatAsFileName "$remote_filename")"

        [[ -e $log_pathfile ]] && rm -f "$log_pathfile"

        RunAndLog "$CURL_CMD${curl_insecure_arg} --output $local_pathfile $remote_url" "$log_pathfile"
        resultcode=$?

        if [[ $resultcode -eq 0 ]]; then
            if FileMatchesMD5 "$local_pathfile" "$remote_md5"; then
                DebugAsDone "downloaded $(FormatAsFileName "$remote_filename")"
            else
                DebugAsError "downloaded package $(FormatAsFileName "$local_pathfile") checksum incorrect"
                resultcode=1
            fi
        else
            DebugAsError "download failed $(FormatAsFileName "$local_pathfile") $(FormatAsExitcode $resultcode)"
        fi
    fi

    DebugFuncExit; return $resultcode

    }

QPKG.Install()
    {

    # $1 = QPKG name to install

    Session.Error.IsSet && return
    Session.SkipPackageProcessing.IsSet && return
    DebugFuncEntry

    if [[ -z $1 ]]; then
        DebugFuncExit; return 1
    fi

    local target_file=''
    local resultcode=0
    local local_pathfile=$(QPKG.PathFilename "$1")
    local log_pathfile=''

    if [[ ${local_pathfile##*.} = zip ]]; then
        $UNZIP_CMD -nq "$local_pathfile" -d "$QPKG_DL_PATH"
        local_pathfile=${local_pathfile%.*}
    fi

    target_file=$($BASENAME_CMD "$local_pathfile")
    log_pathfile=$LOGS_PATH/$target_file.$INSTALL_LOG_FILE

    DebugAsProc "installing $(FormatAsPackageName "$1")"

    RunAndLog "$SH_CMD $local_pathfile" "$log_pathfile"
    resultcode=$?

    if [[ $resultcode -eq 0 || $resultcode -eq 10 ]]; then
        DebugAsDone "installed $(FormatAsPackageName "$1")"
        QPKG.FixAppCenterStatus "$1"
        QPKG.ServiceStatus "$1"
        QPKGs.JustInstalled.Add "$1"
        QPKGs.JustStarted.Add "$1"
        resultcode=0    # reset this to zero (0 or 10 from a QPKG install is OK)
    else
        DebugAsError "installation failed $(FormatAsFileName "$target_file") $(FormatAsExitcode $resultcode)"
        QPKGs.JustInstalled.Remove "$1"
        QPKGs.JustStarted.Remove "$1"
    fi

    QPKGs.ToStart.Remove "$1"
    QPKGs.ToReinstall.Remove "$1"
    QPKGs.ToRestart.Remove "$1"

    DebugFuncExit; return $resultcode

    }

QPKG.Reinstall()
    {

    # $1 = QPKG name to install

    Session.Error.IsSet && return
    Session.SkipPackageProcessing.IsSet && return
    DebugFuncEntry

    if [[ -z $1 ]]; then
        DebugFuncExit; return 1
    fi

    local target_file=''
    local resultcode=0
    local local_pathfile=$(QPKG.PathFilename "$1")
    local log_pathfile=''

    if [[ ${local_pathfile##*.} = zip ]]; then
        $UNZIP_CMD -nq "$local_pathfile" -d "$QPKG_DL_PATH"
        local_pathfile=${local_pathfile%.*}
    fi

    target_file=$($BASENAME_CMD "$local_pathfile")
    log_pathfile=$LOGS_PATH/$target_file.$REINSTALL_LOG_FILE

    DebugAsProc "reinstalling $(FormatAsPackageName "$1")"

    RunAndLog "$SH_CMD $local_pathfile" "$log_pathfile"
    resultcode=$?

    if [[ $resultcode -eq 0 || $resultcode -eq 10 ]]; then
        DebugAsDone "reinstalled $(FormatAsPackageName "$1")"
        QPKG.FixAppCenterStatus "$1"
        QPKG.ServiceStatus "$1"
        QPKGs.JustInstalled.Add "$1"
        QPKGs.JustStarted.Add "$1"
        QPKGs.ToStart.Remove "$1"
        QPKGs.ToInstall.Remove "$1"
        QPKGs.ToRestart.Remove "$1"
    else
        ShowAsEror "reinstallation failed $(FormatAsFileName "$target_file") $(FormatAsExitcode $resultcode)"
    fi

    DebugFuncExit; return $resultcode

    }

QPKG.Upgrade()
    {

    # $1 = QPKG name to upgrade

    Session.Error.IsSet && return
    Session.SkipPackageProcessing.IsSet && return
    DebugFuncEntry

    if [[ -z $1 ]]; then
        DebugFuncExit; return 1
    fi

    local prefix=''
    local resultcode=0
    local previous_version='null'
    local current_version='null'
    local local_pathfile=$(QPKG.PathFilename "$1")
    [[ -n $2 && $2 = '--forced' ]] && prefix='force-'

    if [[ ${local_pathfile##*.} = zip ]]; then
        $UNZIP_CMD -nq "$local_pathfile" -d "$QPKG_DL_PATH"
        local_pathfile=${local_pathfile%.*}
    fi

    local target_file=$($BASENAME_CMD "$local_pathfile")
    local log_pathfile=$LOGS_PATH/$target_file.$UPGRADE_LOG_FILE
    QPKG.Installed "$1" && previous_version=$(QPKG.InstalledVersion "$1")
    QPKG.FixAppCenterStatus "$1"

    DebugAsProc "${prefix}upgrading $(FormatAsPackageName "$1")"

    RunAndLog "$SH_CMD $local_pathfile" "$log_pathfile"
    resultcode=$?

    current_version=$(QPKG.InstalledVersion "$1")

    if [[ $resultcode -eq 0 || $resultcode -eq 10 ]]; then
        if [[ $current_version = "$previous_version" ]]; then
            DebugAsDone "${prefix}upgraded $(FormatAsPackageName "$1") and installed version is $current_version"
        else
            DebugAsDone "${prefix}upgraded $(FormatAsPackageName "$1") from $previous_version to $current_version"
        fi
        QPKG.ServiceStatus "$1"
        QPKGs.JustInstalled.Add "$1"
        QPKGs.JustStarted.Add "$1"
        QPKGs.ToStart.Remove "$1"
        QPKGs.ToInstall.Remove "$1"
        QPKGs.ToReinstall.Remove "$1"
        QPKGs.ToRestart.Remove "$1"
        resultcode=0    # reset this to zero (0 or 10 from a QPKG upgrade is OK)
    else
        ShowAsEror "${prefix}upgrade failed $(FormatAsFileName "$target_file") $(FormatAsExitcode $resultcode)"
    fi

    DebugFuncExit; return $resultcode

    }

QPKG.Uninstall()
    {

    # input:
    #   $1 = QPKG name

    # output:
    #   $? = 0 if successful, 1 if failed

    Session.Error.IsSet && return
    DebugFuncEntry

    if [[ -z $1 ]]; then
        DebugFuncExit; return 1
    fi

    local resultcode=0
    local qpkg_installed_path=$($GETCFG_CMD "$1" Install_Path -f $APP_CENTER_CONFIG_PATHFILE)
    local log_pathfile=$LOGS_PATH/$1.$UNINSTALL_LOG_FILE

    if [[ -e $qpkg_installed_path/.uninstall.sh ]]; then
        DebugAsProc "uninstalling $(FormatAsPackageName "$1")"

        RunAndLog "$SH_CMD $qpkg_installed_path/.uninstall.sh" "$log_pathfile"
        resultcode=$?

        if [[ $resultcode -eq 0 ]]; then
            DebugAsDone "uninstalled $(FormatAsPackageName "$1")"
            $RMCFG_CMD "$1" -f $APP_CENTER_CONFIG_PATHFILE
            DebugAsDone 'removed icon information from App Center'
        else
            DebugAsError "unable to uninstall $(FormatAsPackageName "$1") $(FormatAsExitcode $resultcode)"
        fi
    fi

    DebugFuncExit; return $resultcode

    }

QPKG.Restart()
    {

    # Restarts the service script for the QPKG named in $1

    # input:
    #   $1 = QPKG name

    # output:
    #   $? = 0 if successful, 1 if failed

    DebugFuncEntry

    if [[ -z $1 ]]; then
        DebugFuncExit; return 1
    fi

    local resultcode=0
    local log_pathfile=$LOGS_PATH/$1.$RESTART_LOG_FILE

    QPKG.FixAppCenterStatus "$1"

    DebugAsProc "restarting $(FormatAsPackageName "$1")"

    RunAndLog "$QPKG_SERVICE_CMD restart $1" "$log_pathfile"
    resultcode=$?

    if [[ $resultcode -eq 0 ]]; then
        DebugAsDone "restarted $(FormatAsPackageName "$1")"
        QPKG.ServiceStatus "$1"
        QPKGs.JustStarted.Add "$1"
        QPKGs.ToStart.Remove "$1"
    else
        ShowAsWarn "unable to restart $(FormatAsPackageName "$1") $(FormatAsExitcode $resultcode)"
    fi

    DebugFuncExit; return $resultcode

    }

QPKG.Start()
    {

    # Starts the service script for the QPKG named in $1

    # input:
    #   $1 = QPKG name

    # output:
    #   $? = 0 if successful, 1 if failed

    DebugFuncEntry

    if [[ -z $1 ]]; then
        DebugFuncExit; return 1
    fi

    local resultcode=0
    local log_pathfile=$LOGS_PATH/$1.$START_LOG_FILE

    QPKG.FixAppCenterStatus "$1"

    DebugAsProc "starting $(FormatAsPackageName "$1")"

    RunAndLog "$QPKG_SERVICE_CMD start $1" "$log_pathfile"
    resultcode=$?

    if [[ $resultcode -eq 0 ]]; then
        DebugAsDone "started $(FormatAsPackageName "$1")"
        QPKG.FixAppCenterStatus "$1"
        QPKG.ServiceStatus "$1"
        QPKGs.JustStarted.Add "$1"
        QPKGs.ToRestart.Remove "$1"
    else
        ShowAsWarn "unable to start $(FormatAsPackageName "$1") $(FormatAsExitcode $resultcode)"
    fi

    DebugFuncExit; return $resultcode

    }

QPKG.Stop()
    {

    # Stops the service script for the QPKG named in $1

    # input:
    #   $1 = QPKG name

    # output:
    #   $? = 0 if successful, 1 if failed

    DebugFuncEntry

    if [[ -z $1 ]]; then
        DebugFuncExit; return 1
    fi

    local resultcode=0
    local log_pathfile=$LOGS_PATH/$1.$STOP_LOG_FILE

    DebugAsProc "stopping $(FormatAsPackageName "$1")"

    RunAndLog "$QPKG_SERVICE_CMD stop $1" "$log_pathfile"
    resultcode=$?

    if [[ $resultcode -eq 0 ]]; then
        DebugAsDone "stopped $(FormatAsPackageName "$1")"
        QPKG.ServiceStatus "$1"
        QPKGs.JustStarted.Remove "$1"
    else
        ShowAsWarn "unable to stop $(FormatAsPackageName "$1") $(FormatAsExitcode $resultcode)"
    fi

    DebugFuncExit; return $resultcode

    }

QPKG.Enable()
    {

    # $1 = package name to enable

    DebugFuncEntry

    if [[ -z $1 ]]; then
        DebugFuncExit; return 1
    fi

    local resultcode=0
    local log_pathfile=$LOGS_PATH/$1.$ENABLE_LOG_FILE

    QPKG.FixAppCenterStatus "$1"

    if QPKG.NotEnabled "$1"; then
        RunAndLog "$QPKG_SERVICE_CMD enable $1" "$log_pathfile"
        resultcode=$?

        if [[ $resultcode -eq 0 ]]; then
            QPKG.ServiceStatus "$1"
        else
            ShowAsWarn "unable to enable $(FormatAsPackageName "$1") $(FormatAsExitcode $resultcode)"
        fi
    fi

    DebugFuncExit; return 0

    }

QPKG.Disable()
    {

    # $1 = package name to disable

    DebugFuncEntry

    if [[ -z $1 ]]; then
        DebugFuncExit; return 1
    fi

    local resultcode=0
    local log_pathfile=$LOGS_PATH/$1.$DISABLE_LOG_FILE

    if QPKG.Enabled "$1"; then
        RunAndLog "$QPKG_SERVICE_CMD disable $1" "$log_pathfile"
        resultcode=$?

        if [[ $resultcode -eq 0 ]]; then
            QPKG.ServiceStatus "$1"
        else
            ShowAsWarn "unable to disable $(FormatAsPackageName "$1") $(FormatAsExitcode $resultcode)"
        fi
    fi

    DebugFuncExit; return 0

    }

QPKG.Backup()
    {

    # calls the service script for the QPKG named in $1 and runs a backup operation

    # input:
    #   $1 = QPKG name

    # output:
    #   $? = 0 if successful, 1 if failed

    DebugFuncEntry

    if [[ -z $1 ]]; then
        DebugFuncExit; return 1
    fi

    local resultcode=0
    local package_init_pathfile=$(QPKG.ServicePathFile "$1")
    local log_pathfile=$LOGS_PATH/$1.$BACKUP_LOG_FILE

    DebugAsProc "backing-up $(FormatAsPackageName "$1") configuration"

    RunAndLog "$SH_CMD $package_init_pathfile backup" "$log_pathfile"
    resultcode=$?

    if [[ $resultcode -eq 0 ]]; then
        DebugAsDone "backed-up $(FormatAsPackageName "$1") configuration"
        QPKG.ServiceStatus "$1"
    else
        DebugAsWarning "unable to backup $(FormatAsPackageName "$1") configuration $(FormatAsExitcode $resultcode)"
    fi

    DebugFuncExit; return $resultcode

    }

QPKG.Restore()
    {

    # calls the service script for the QPKG named in $1 and runs a restore operation

    # input:
    #   $1 = QPKG name

    # output:
    #   $? = 0 if successful, 1 if failed

    DebugFuncEntry

    if [[ -z $1 ]]; then
        DebugFuncExit; return 1
    fi

    local resultcode=0
    local package_init_pathfile=$(QPKG.ServicePathFile "$1")
    local log_pathfile=$LOGS_PATH/$1.$RESTORE_LOG_FILE

    DebugAsProc "restoring $(FormatAsPackageName "$1") configuration"

    RunAndLog "$SH_CMD $package_init_pathfile restore" "$log_pathfile"
    resultcode=$?

    if [[ $resultcode -eq 0 ]]; then
        DebugAsDone "restored $(FormatAsPackageName "$1") configuration"
        QPKG.ServiceStatus "$1"
    else
        DebugAsWarning "unable to restore $(FormatAsPackageName "$1") configuration $(FormatAsExitcode $resultcode)"
    fi

    DebugFuncExit; return $resultcode

    }

QPKG.UserInstallable()
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

QPKG.Installed()
    {

    # input:
    #   $1 = package name to check

    # output:
    #   $? = 0 (true) or 1 (false)

    [[ $($GETCFG_CMD "$1" RC_Number -d 0 -f $APP_CENTER_CONFIG_PATHFILE) -gt 0 ]]

    }

QPKG.NotInstalled()
    {

    # input:
    #   $1 = package name to check

    # output:
    #   $? = 0 (true) or 1 (false)

    ! QPKG.Installed "$1"

    }

QPKG.Enabled()
    {

    # input:
    #   $1 = package name to check

    # output:
    #   $? = 0 (true) or 1 (false)

    [[ $($GETCFG_CMD "$1" Enable -u -f $APP_CENTER_CONFIG_PATHFILE) = 'TRUE' ]]

    }

QPKG.NotEnabled()
    {

    # input:
    #   $1 = package name to check

    # output:
    #   $? = 0 (true) or 1 (false)

    ! QPKG.Enabled "$1"

    }

QPKG.MatchAbbrv()
    {

    # input:
    #   $1 = a potential package abbreviation supplied by user

    # output:
    #   $? = 0 (matched) or 1 (unmatched)
    #   stdout = matched installable package name (empty if unmatched)

    local abbs=()
    local package_index=0
    local index=0
    local returncode=1

    for package_index in "${!SHERPA_QPKG_NAME[@]}"; do
        abbs=(${SHERPA_QPKG_ABBRVS[$package_index]})

        for index in "${!abbs[@]}"; do
            if [[ ${abbs[$index]} = "$1" ]]; then
                Display "${SHERPA_QPKG_NAME[$package_index]}"
                returncode=0
                break 2
            fi
        done
    done

    return $returncode

    }

QPKG.FixAppCenterStatus()
    {

    # $1 = QPKG name to fix

    [[ -z $1 ]] && return 1
    QPKG.NotInstalled "$1" && return 0

    # KLUDGE: force-cancel QTS 4.5.1 App Center notifier status as it's often wrong. :(
    [[ -e $APP_CENTER_NOTIFIER ]] && $APP_CENTER_NOTIFIER -c "$1" > /dev/null 2>&1

    # KLUDGE: need this for 'Entware' and 'Par2' packages as they don't add a status line to qpkg.conf
    $SETCFG_CMD "$1" Status complete -f "$APP_CENTER_CONFIG_PATHFILE"

    return 0

    }

MakePath()
    {

    [[ -z $1 || -z $2 ]] && return 1

    mkdir -p "$1" 2> /dev/null; resultcode=$?

    if [[ $resultcode -ne 0 ]]; then
        ShowAsEror "unable to create $2 path $(FormatAsFileName "$1") $(FormatAsExitcode $resultcode)"
        [[ $(type -t Session.SuggestIssue.Init) = 'function' ]] && Session.SuggestIssue.Set
        return 1
    fi

    return 0

    }

RunAndLog()
    {

    # Run a command string, log the results, and show onscreen if required

    # input:
    #   $1 = command string to execute
    #   $2 = pathfilename to record command string ($1) stdout and stderr
    #   $3 = 'log:failure-only' (optional) - if specified, stdout & stderr are only recorded in the specified log if the command failed
    #                                      - if unspecified, stdout & stderr is always recorded

    # output:
    #   stdout = command string stdout and stderr if script is in 'debug' mode
    #   pathfilename ($2) = command string ($1) stdout and stderr
    #   $? = resultcode of command string

    [[ -z $1 || -z $2 ]] && return 1
    DebugFuncEntry

    local msgs=/var/log/execd.log
    local resultcode=0

    FormatAsCommand "$1" > "$2"

    if Session.Debug.To.Screen.IsSet; then
        DebugCommand.Proc "$1"
        $1 > >($TEE_CMD "$msgs") 2>&1
        resultcode=$?
    else
        $1 > "$msgs" 2>&1
        resultcode=$?
    fi

    if [[ -e $msgs ]]; then
        FormatAsResultAndStdout "$resultcode" "$(<"$msgs")" >> "$2"
        rm -f "$msgs"
    else
        FormatAsResultAndStdout "$resultcode" "<null>" >> "$2"
    fi

    if [[ $resultcode -eq 0 && $3 != log:failure-only ]] || [[ $resultcode -ne 0 ]]; then
        AddFileToDebug "$2"
    fi

    DebugFuncExit; return $resultcode

    }

DeDupeWords()
    {

    [[ -z $1 ]] && return 1

    tr ' ' '\n' <<< "$1" | $SORT_CMD | $UNIQ_CMD | tr '\n' ' ' | $SED_CMD 's|^[[:blank:]]*||;s|[[:blank:]]*$||'

    }

FileMatchesMD5()
    {

    # input:
    #   $1 = pathfilename to generate an MD5 checksum for
    #   $2 = MD5 checksum to compare against

    [[ -z $1 || -z $2 ]] && return 1
    [[ $($MD5SUM_CMD "$1" | $CUT_CMD -f1 -d' ') = "$2" ]]

    }

#### FormatAs... functions always output formatted info to be used as part of another string. These shouldn't be used for direct screen output.

FormatAsPlural()
    {

    [[ $1 -ne 1 ]] && echo 's'

    }

FormatAsThousands()
    {

    LC_NUMERIC=en_US.utf8 printf "%'.f" "$1"

    }

FormatAsISOBytes()
    {

    echo "$1" | $AWK_CMD 'BEGIN{ u[0]="B"; u[1]="kB"; u[2]="MB"; u[3]="GB"} { n = $1; i = 0; while(n > 1000) { i+=1; n= int((n/1000)+0.5) } print n u[i] } '

    }

FormatAsScriptTitle()
    {

    ColourTextBrightWhite "$PROJECT_NAME"

    }

FormatAsHelpAction()
    {

    ColourTextBrightYellow '[action]'

    }

FormatAsHelpPackages()
    {

    ColourTextBrightOrange '[packages]'

    }

FormatAsHelpOptions()
    {

    ColourTextBrightRed '[options]'

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

    ColourTextUnderlinedCyan "$1"

    }

FormatAsExitcode()
    {

    echo "[$1]"

    }

FormatAsLogFilename()
    {

    echo "= log file: '$1'"

    }

FormatAsCommand()
    {

    echo "= command: '$1'"

    }

FormatAsResult()
    {

    if [[ $1 -eq 0 ]]; then
        echo "= resultcode: $(FormatAsExitcode "$1")"
    else
        echo "! resultcode: $(FormatAsExitcode "$1")"
    fi

    }

FormatAsScript()
    {

    echo 'SCRIPT'

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
        echo "= resultcode: $(FormatAsExitcode "$1") ***** stdout/stderr begins below *****"
    else
        echo "! resultcode: $(FormatAsExitcode "$1") ***** stdout/stderr begins below *****"
    fi

    echo "$2"
    echo '= ***** stdout/stderr is complete *****'

    }

DisplayLineSpaceIfNoneAlready()
    {

    if Session.LineSpace.IsNot && Session.Debug.To.Screen.IsNot && Session.Display.Clean.IsNot; then
        echo
        Session.LineSpace.Set
    else
        Session.LineSpace.Clear
    fi

    }

#### Debug... functions are used for formatted debug information output. This may be to screen, file or both.

DebugInfoMajorSeparator()
    {

    DebugInfo "$(eval printf '%0.s=' "{1..$DEBUG_LOG_DATAWIDTH}")"    # 'seq' is unavailable in QTS, so must resort to 'eval' trickery instead

    }

DebugInfoMinorSeparator()
    {

    DebugInfo "$(eval printf '%0.s-' "{1..$DEBUG_LOG_DATAWIDTH}")"    # 'seq' is unavailable in QTS, so must resort to 'eval' trickery instead

    }

DebugExtLogMinorSeparator()
    {

    DebugLog "$(eval printf '%0.s-' "{1..$DEBUG_LOG_DATAWIDTH}")"     # 'seq' is unavailable in QTS, so must resort to 'eval' trickery instead

    }

DebugScript()
    {

    DebugDetected.OK "$(FormatAsScript)" "$1" "$2"

    }

DebugHardware.OK()
    {

    DebugDetected.OK "$(FormatAsHardware)" "$1" "$2"

    }

DebugHardware.Warning()
    {

    DebugDetected.Warning "$(FormatAsHardware)" "$1" "$2"

    }

DebugFirmware.OK()
    {

    DebugDetected.OK "$(FormatAsFirmware)" "$1" "$2"

    }

DebugFirmware.Warning()
    {

    DebugDetected.Warning "$(FormatAsFirmware)" "$1" "$2"

    }

DebugUserspace.OK()
    {

    DebugDetected.OK "$(FormatAsUserspace)" "$1" "$2"

    }

DebugUserspace.Warning()
    {

    DebugDetected.Warning "$(FormatAsUserspace)" "$1" "$2"

    }

DebugDetected.Warning()
    {

    first_column_width=9
    second_column_width=21

    if [[ -z $3 ]]; then                # if $3 is nothing, then assume only 2 fields are required
        DebugAsWarning "$(printf "%${first_column_width}s: %${second_column_width}s\n" "$1" "$2")"
    elif [[ $3 = ' ' ]]; then           # if $3 is only a whitespace then print $2 with trailing colon and 'none' as third field
        DebugAsWarning "$(printf "%${first_column_width}s: %${second_column_width}s: none\n" "$1" "$2")"
    elif [[ ${3: -1} = ' ' ]]; then     # if $3 has a trailing whitespace then print $3 without the trailing whitespace
        DebugAsWarning "$(printf "%${first_column_width}s: %${second_column_width}s: %-s\n" "$1" "$2" "$($SED_CMD 's| *$||' <<< "$3")")"
    else
        DebugAsWarning "$(printf "%${first_column_width}s: %${second_column_width}s: %-s\n" "$1" "$2" "$3")"
    fi

    }

DebugDetected.OK()
    {

    first_column_width=9
    second_column_width=21

    if [[ -z $3 ]]; then                # if $3 is nothing, then assume only 2 fields are required
        DebugDetected "$(printf "%${first_column_width}s: %${second_column_width}s\n" "$1" "$2")"
    elif [[ $3 = ' ' ]]; then           # if $3 is only a whitespace then print $2 with trailing colon and 'none' as third field
        DebugDetected "$(printf "%${first_column_width}s: %${second_column_width}s: none\n" "$1" "$2")"
    elif [[ ${3: -1} = ' ' ]]; then     # if $3 has a trailing whitespace then print $3 without the trailing whitespace
        DebugDetected "$(printf "%${first_column_width}s: %${second_column_width}s: %-s\n" "$1" "$2" "$($SED_CMD 's| *$||' <<< "$3")")"
    else
        DebugDetected "$(printf "%${first_column_width}s: %${second_column_width}s: %-s\n" "$1" "$2" "$3")"
    fi

    }

DebugCommand.Proc()
    {

    DebugAsProc "executing '$1'"

    }

DebugQPKG()
    {

    DebugDetected.OK 'QPKG' "$1" "$2"

    }

DebugFuncEntry()
    {

    local var_name=${FUNCNAME[1]}_STARTSECONDS
    local var_safe_name=${var_name//[.-]/_}
    eval "$var_safe_name=$(/bin/date +%s%N)"    # hardcode 'date' here as this function is called before binaries are cherry-picked.

    DebugThis "(>>) ${FUNCNAME[1]}()"

    }

DebugFuncExit()
    {

    local var_name=${FUNCNAME[1]}_STARTSECONDS
    local var_safe_name=${var_name//[.-]/_}
    local diff_milliseconds=$((($($DATE_CMD +%s%N) - ${!var_safe_name})/1000000))
    local elapsed_time=''

    if [[ $diff_milliseconds -lt 30000 ]]; then
        elapsed_time="$(FormatAsThousands "$diff_milliseconds")ms"
    else
        elapsed_time=$(ConvertSecsToHoursMinutesSecs "$((diff_milliseconds/1000))")
    fi

    DebugThis "(<<) ${FUNCNAME[1]}()|$code_pointer|$elapsed_time"

    }

DebugAsProc()
    {

    DebugThis "(==) $1 ..."

    }

DebugAsDone()
    {

    DebugThis "(--) $1"

    }

DebugDetected()
    {

    DebugThis "(**) $1"

    }

DebugInfo()
    {

    if [[ $2 = ' ' ]]; then           # if $2 is only a whitespace then print $1 with trailing colon and 'none' as second field
        DebugThis "(II) $1: none"
    elif [[ -n $2 ]]; then
        DebugThis "(II) $1: $2"
    else
        DebugThis "(II) $1"
    fi

    }

DebugAsWarning()
    {

    DebugThis "(WW) $1"

    }

DebugAsError()
    {

    DebugThis "(EE) $1"

    }

DebugLog()
    {

    DebugThis "(LL) $1"

    }

DebugVar()
    {

    DebugThis "(vv) \$$1 : '${!1}'"

    }

DebugThis()
    {

    [[ $(type -t Session.Debug.To.Screen.Init) = 'function' ]] && Session.Debug.To.Screen.IsSet && ShowAsDebug "$1"
    WriteAsDebug "$1"

    }

AddFileToDebug()
    {

    # Add the contents of specified pathfile $1 to the runtime log

    local linebuff=''
    local screen_debug=false

    DebugExtLogMinorSeparator
    DebugLog 'adding external log to main log ...'

    if Session.Debug.To.Screen.IsSet; then      # prevent external log contents appearing onscreen again - it's already been seen "live".
        screen_debug=true
        Session.Debug.To.Screen.Clear
    fi

    DebugLog "$(FormatAsLogFilename "$1")"

    while read -r linebuff; do
        DebugLog "$linebuff"
    done < "$1"

    [[ $screen_debug = true ]] && Session.Debug.To.Screen.Set
    DebugExtLogMinorSeparator

    }

#### ShowAs... functions output formatted info to screen and (usually) to debug log.

ShowAsProcLong()
    {

    ShowAsProc "$1 (this may take a while)"

    }

ShowAsProc()
    {

    SmartCR
    WriteToDisplay.Wait "$(ColourTextBrightOrange proc)" "$1 ..."
    WriteToLog proc "$1 ..."
    [[ $(type -t Session.Debug.To.Screen.Init) = 'function' ]] && Session.Debug.To.Screen.IsSet && Display

    }

ShowAsDebug()
    {

    WriteToDisplay.New "$(ColourTextBlackOnCyan dbug)" "$1"

    }

ShowAsNote()
    {

    SmartCR
    WriteToDisplay.New "$(ColourTextBrightYellow note)" "$1"
    WriteToLog note "$1"

    }

ShowAsQuiz()
    {

    WriteToDisplay.Wait "$(ColourTextBrightOrangeBlink quiz)" "$1: "
    WriteToLog quiz "$1:"

    }

ShowAsQuizDone()
    {

    WriteToDisplay.New "$(ColourTextBrightOrange quiz)" "$1"

    }

ShowAsDone()
    {

    # process completed OK

    SmartCR
    WriteToDisplay.New "$(ColourTextBrightGreen 'done')" "$1"
    WriteToLog 'done' "$1"

    }

ShowAsWarn()
    {

    # warning only

    SmartCR
    WriteToDisplay.New "$(ColourTextBrightOrange warn)" "$1"
    WriteToLog warn "$1"

    }

ShowAsAbort()
    {

    local capitalised="$(tr 'a-z' 'A-Z' <<< "${1:0:1}")${1:1}"      # use any available 'tr'

    WriteToDisplay.New "$(ColourTextBrightRed eror)" "$capitalised: aborting ..."
    WriteToLog eror "$capitalised: aborting"
    Session.Error.Set

    }

ShowAsFail()
    {

    # non-fatal error

    SmartCR

    local capitalised="$(tr 'a-z' 'A-Z' <<< "${1:0:1}")${1:1}"      # use any available 'tr'

    WriteToDisplay.New "$(ColourTextBrightRed fail)" "$capitalised"
    WriteToLog fail "$capitalised."

    }

ShowAsEror()
    {

    # fatal error

    SmartCR

    local capitalised="$(tr 'a-z' 'A-Z' <<< "${1:0:1}")${1:1}"      # use any available 'tr'

    WriteToDisplay.New "$(ColourTextBrightRed eror)" "$capitalised"
    WriteToLog eror "$capitalised."
    Session.Error.Set

    }

ShowAsOperationResult()
    {

    # $1 = tier (optional)
    # $2 = total package count
    # $3 = fail count
    # $4 = pass count
    # $5 = action message (past-tense)

    local tier=''

    [[ -z $2 || -z $3 || -z $4 || -z $5 ]] && return 1

    if [[ -n $1 ]]; then
        tier=" $1"
    else
        tier=''
    fi

    if [[ $3 -eq $2 ]]; then
        ShowAsFail "$5 $3$tier QPKG$(FormatAsPlural "$3") failed"
    elif [[ $3 -gt 0 ]]; then
        ShowAsWarn "$5 $4$tier QPKG$(FormatAsPlural "$4") OK, but $3$tier QPKG$(FormatAsPlural "$3") failed"
    elif [[ $4 -gt 0 ]]; then
        ShowAsDone "$5 $4$tier QPKG$(FormatAsPlural "$4") OK"
    else
        DebugAsDone "no$tier QPKGs processed"
    fi

    }

### WriteAs... functions - to be determined.

WriteAsDebug()
    {

    WriteToLog dbug "$1"

    }

WriteToDisplay.Wait()
    {

    # Writes a new message without newline

    # input:
    #   $1 = pass/fail
    #   $2 = message

    previous_msg=$(printf "%-10s: %s" "$1" "$2")
    DisplayWait "$previous_msg"

    return 0

    }

WriteToDisplay.New()
    {

    # Updates the previous message

    # input:
    #   $1 = pass/fail
    #   $2 = message

    # output:
    #   stdout = overwrites previous message with updated message
    #   $previous_length

    local this_message=''
    local strbuffer=''
    local this_length=0
    local blanking_length=0

    this_message=$(printf "%-10s: %s" "$1" "$2")

    if [[ $this_message != "$previous_msg" ]]; then
        previous_length=$((${#previous_msg}+1))
        this_length=$((${#this_message}+1))

        # jump to start of line, print new msg
        strbuffer=$(echo -en "\r$this_message ")

        # if new msg is shorter then add spaces to end to cover previous msg
        if [[ $this_length -lt $previous_length ]]; then
            blanking_length=$((this_length-previous_length))
            strbuffer+=$(printf "%${blanking_length}s")
        fi

        Display "$strbuffer"
    fi

    return 0

    }

WriteToLog()
    {

    # input:
    #   $1 = pass/fail
    #   $2 = message

    [[ -z $DEBUG_LOG_PATHFILE ]] && return 1
    [[ $(type -t Session.Debug.To.File.Init) = 'function' ]] && Session.Debug.To.File.IsNot && return

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

ColourTextUnderlinedCyan()
    {

    echo -en '\033[4;36m'"$(ColourReset "$1")"

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

    # QTS 4.2.6 BusyBox 'sed' doesn't fully support extended regexes, so this only works with a real 'sed'.

    if [[ -e $GNU_SED_CMD ]]; then
        $GNU_SED_CMD -r 's/\x1b\[[0-9;]*m//g' <<< "$1"
    else
        echo "$1"
    fi

    }

ConvertSecsToHoursMinutesSecs()
    {

    # http://stackoverflow.com/questions/12199631/convert-seconds-to-hours-minutes-seconds

    # input:
    #   $1 = a time in seconds to convert to 'hh:mm:ss'

    ((h=${1}/3600))
    ((m=(${1}%3600)/60))
    ((s=${1}%60))

    printf "%02dh:%02dm:%02ds\n" "$h" "$m" "$s"

    }

CTRL_C_Captured()
    {

    RemoveDirSizeMonitorFlagFile

    exit

    }

Objects.Add()
    {

    # $1: object name to create

    local public_function_name=$1
    local safe_function_name="$(tr 'A-Z' 'a-z' <<< "${public_function_name//[.-]/_}")"

    _placeholder_size_=_object_${safe_function_name}_size_
    _placeholder_text_=_object_${safe_function_name}_text_
    _placeholder_flag_=_object_${safe_function_name}_flag_
    _placeholder_log_changes_flag_=_object_${safe_function_name}_changes_flag_
    _placeholder_enable_=_object_${safe_function_name}_enable_
    _placeholder_array_=_object_${safe_function_name}_array_
    _placeholder_array_index_=_object_${safe_function_name}_array_index_
    _placeholder_path_=_object_${safe_function_name}_path_

echo $public_function_name'.Add()
    {
    local array=(${1})
    local item='\'\''
    for item in "${array[@]}"; do
        [[ " ${'$_placeholder_array_'[*]} " != *"$item"* ]] && '$_placeholder_array_'+=("$item")
    done
    }
'$public_function_name'.Array()
    {
    echo -n "${'$_placeholder_array_'[@]}"
    }
'$public_function_name'.Clear()
    {
    [[ $'$_placeholder_flag_' != '\'true\'' ]] && return
    '$_placeholder_flag_'=false
    [[ $'$_placeholder_log_changes_flag_' = '\'true\'' ]] && DebugVar '$_placeholder_flag_'
    }
'$public_function_name'.Count()
    {
    echo "${#'$_placeholder_array_'[@]}"
    }
'$public_function_name'.Disable()
    {
    [[ $'$_placeholder_enable_' != '\'true\'' ]] && return
    '$_placeholder_enable_'=false
    [[ $'$_placeholder_log_changes_flag_' = '\'true\'' ]] && DebugVar '$_placeholder_enable_'
    }
'$public_function_name'.DontLogChanges()
    {
    [[ $'$_placeholder_log_changes_flag_' != '\'true\'' ]] && return
    '$_placeholder_log_changes_flag_'=false
    }
'$public_function_name'.Enable()
    {
    [[ $'$_placeholder_enable_' = '\'true\'' ]] && return
    '$_placeholder_enable_'=true
    [[ $'$_placeholder_log_changes_flag_' = '\'true\'' ]] && DebugVar '$_placeholder_enable_'
    }
'$public_function_name'.Exist()
    {
    [[ ${'$_placeholder_array_'[*]} == *"$1"* ]]
    }
'$public_function_name'.First()
    {
    echo "${'$_placeholder_array_'[0]}"
    }
'$public_function_name'.GetItem()
    {
    local -i index="$1"
    [[ $index -lt 1 ]] && index=1
    [[ $index -gt ${#'$_placeholder_array_'[@]} ]] && index=${#'$_placeholder_array_'[@]}
    echo -n "${'$_placeholder_array_'[((index-1))]}"
    }
'$public_function_name'.Init()
    {
    '$_placeholder_size_'=0
    '$_placeholder_text_'='\'\''
    '$_placeholder_flag_'=false
    '$_placeholder_log_changes_flag_'=true
    '$_placeholder_enable_'=false
    '$_placeholder_array_'=()
    '$_placeholder_array_index_'=1
    '$_placeholder_path_'='\'\''
    }
'$public_function_name'.IsAny()
    {
    [[ ${#'$_placeholder_array_'[@]} -gt 0 ]]
    }
'$public_function_name'.IsDisabled()
    {
    [[ $'$_placeholder_enable_' != '\'true\'' ]]
    }
'$public_function_name'.IsEnabled()
    {
    [[ $'$_placeholder_enable_' = '\'true\'' ]]
    }
'$public_function_name'.IsNone()
    {
    [[ ${#'$_placeholder_array_'[@]} -eq 0 ]]
    }
'$public_function_name'.IsNot()
    {
    [[ $'$_placeholder_flag_' != '\'true\'' ]]
    }
'$public_function_name'.IsSet()
    {
    [[ $'$_placeholder_flag_' = '\'true\'' ]]
    }
'$public_function_name'.List()
    {
    echo -n "${'$_placeholder_array_'[*]}"
    }
'$public_function_name'.ListCSV()
    {
    echo -n "${'$_placeholder_array_'[*]}" | tr '\' \'' '\',\''
    }
'$public_function_name'.LogChanges()
    {
    [[ $'$_placeholder_log_changes_flag_' = '\'true\'' ]] && return
    '$_placeholder_log_changes_flag_'=true
    }
'$public_function_name'.Path()
    {
    if [[ -n $1 && $1 = "=" ]]; then
        '$_placeholder_path_'=$2
    else
        echo -n "$'$_placeholder_path_'"
    fi
    }
'$public_function_name'.Remove()
    {
    local argument_array=(${1})
    local temp_array=()
    local argument='\'\''
    local item='\'\''
    local matched=false
    for item in "${'$_placeholder_array_'[@]}"; do
        matched=false
        for argument in "${argument_array[@]}"; do
            if [[ $argument = $item ]]; then
                matched=true; break
            fi
        done
        [[ $matched = false ]] && temp_array+=("$item")
    done
    '$_placeholder_array_'=("${temp_array[@]}")
    [[ -z ${'$_placeholder_array_'[*]} ]] && '$_placeholder_array_'=()
    }
'$public_function_name'.Set()
    {
    [[ $'$_placeholder_flag_' = '\'true\'' ]] && return
    '$_placeholder_flag_'=true
    [[ $'$_placeholder_log_changes_flag_' = '\'true\'' ]] && DebugVar '$_placeholder_flag_'
    }
'$public_function_name'.Size()
    {
    if [[ -n $1 && $1 = "=" ]]; then
        '$_placeholder_size_'=$2
    else
        echo -n $'$_placeholder_size_'
    fi
    }
'$public_function_name'.Text()
    {
    if [[ -n $1 && $1 = "=" ]]; then
        '$_placeholder_text_'=$2
    else
        echo -n "$'$_placeholder_text_'"
    fi
    }
'$public_function_name'.Init
' >> "$COMPILED_OBJECTS_PATHFILE"

    return 0

    }

Objects.CheckLocal()
    {

    [[ -e $COMPILED_OBJECTS_PATHFILE ]] && ! FileMatchesMD5 "$COMPILED_OBJECTS_PATHFILE" "$COMPILED_OBJECTS_HASH" && rm -f "$COMPILED_OBJECTS_PATHFILE"

    }

Objects.CheckRemote()
    {

    [[ ! -e $COMPILED_OBJECTS_PATHFILE ]] && ! $CURL_CMD${curl_insecure_arg} --silent --fail "$COMPILED_OBJECTS_URL" > "$COMPILED_OBJECTS_PATHFILE" && [[ ! -s $COMPILED_OBJECTS_PATHFILE ]] && rm -f "$COMPILED_OBJECTS_PATHFILE"

    }

Objects.Compile()
    {

    Objects.CheckLocal
    Objects.CheckRemote
    Objects.CheckLocal

    if [[ ! -e $COMPILED_OBJECTS_PATHFILE ]]; then
        ShowAsProc 'compiling objects'

        # user-selected options
        Objects.Add User.Opts.Help.Abbreviations
        Objects.Add User.Opts.Help.Actions
        Objects.Add User.Opts.Help.ActionsAll
        Objects.Add User.Opts.Help.Basic
        Objects.Add User.Opts.Help.Options
        Objects.Add User.Opts.Help.Packages
        Objects.Add User.Opts.Help.Problems
        Objects.Add User.Opts.Help.Tips

        Objects.Add User.Opts.Clean
        Objects.Add User.Opts.Dependencies.Check
        Objects.Add User.Opts.IgnoreFreeSpace
        Objects.Add User.Opts.Versions.View

        Objects.Add User.Opts.Log.Last.Paste
        Objects.Add User.Opts.Log.Last.View
        Objects.Add User.Opts.Log.Tail.Paste
        Objects.Add User.Opts.Log.Whole.View

        Objects.Add User.Opts.Apps.All.Backup
        Objects.Add User.Opts.Apps.All.ForceUpgrade
        Objects.Add User.Opts.Apps.All.Install
        Objects.Add User.Opts.Apps.All.Reinstall
        Objects.Add User.Opts.Apps.All.Restart
        Objects.Add User.Opts.Apps.All.Restore
        Objects.Add User.Opts.Apps.All.Start
        Objects.Add User.Opts.Apps.All.Stop
        Objects.Add User.Opts.Apps.All.Uninstall
        Objects.Add User.Opts.Apps.All.Upgrade

        Objects.Add User.Opts.Apps.List.All
        Objects.Add User.Opts.Apps.List.Backups
        Objects.Add User.Opts.Apps.List.Essential
        Objects.Add User.Opts.Apps.List.Installed
        Objects.Add User.Opts.Apps.List.NotInstalled
        Objects.Add User.Opts.Apps.List.Optional
        Objects.Add User.Opts.Apps.List.Upgradable

        # lists
        Objects.Add Args.Unknown

        Objects.Add IPKGs.ToDownload
        Objects.Add IPKGs.ToInstall
        Objects.Add IPKGs.ToUninstall

        Objects.Add QPKGs.Essential
        Objects.Add QPKGs.Installable
        Objects.Add QPKGs.Installed
        Objects.Add QPKGs.JustInstalled
        Objects.Add QPKGs.JustStarted
        Objects.Add QPKGs.Names
        Objects.Add QPKGs.NotInstalled
        Objects.Add QPKGs.Optional
        Objects.Add QPKGs.Upgradable

        Objects.Add QPKGs.ToBackup
        Objects.Add QPKGs.ToDownload
        Objects.Add QPKGs.ToForceUpgrade
        Objects.Add QPKGs.ToInstall
        Objects.Add QPKGs.ToReinstall
        Objects.Add QPKGs.ToRestart
        Objects.Add QPKGs.ToRestore
        Objects.Add QPKGs.ToStart
        Objects.Add QPKGs.ToStop
        Objects.Add QPKGs.ToUninstall
        Objects.Add QPKGs.ToUpgrade

        # flags
        Objects.Add Session.Backup
        Objects.Add Session.Debug.To.File
        Objects.Add Session.Debug.To.Screen
        Objects.Add Session.Display.Clean
        Objects.Add Session.IPKGs.Install
        Objects.Add Session.LineSpace
        Objects.Add Session.PIPs.Install
        Objects.Add Session.ShowBackupLocation
        Objects.Add Session.SkipPackageProcessing
        Objects.Add Session.SuggestIssue
        Objects.Add Session.Summary
    fi

    . "$COMPILED_OBJECTS_PATHFILE"

    return 0

    }

Process.Tier.Actions()
    {

    # $1 = 'essential', 'addon' or 'optional'

    local tier=''

    if [[ $1 = essential ]]; then
        tier=Essentials
    elif [[ $1 = addon ]]; then
        tier=Addons
    elif [[ $1 = optional ]]; then
        tier=Optionals
    else
        return 1
    fi

    Packages.Force-upgrade."$tier"
    Packages.Upgrade."$tier"
    Packages.Reinstall."$tier"
    Packages.Install."$tier"
    Packages.Start."$tier"
    Packages.Restore."$tier"
    Packages.Restart."$tier"

    }

Session.Init || exit 1
Session.Validate
Packages.Download
Packages.Backup
Packages.Stop
Packages.Uninstall
Process.Tier.Actions essential
Process.Tier.Actions addon
Process.Tier.Actions optional
Session.Results
Session.Error.IsNot
