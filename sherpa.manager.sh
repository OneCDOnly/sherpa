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

# These demonstrate available words for syntax highlighting on Kate (makes it easier to pick a word that stands-out):
# ALERT ATTENTION DANGER HACK SECURITY
# BUG FIXME DEPRECATED TASK TODO TBD WARNING CAUTION NOLINT
# ### NOTE NOTICE TEST TESTING

set -o nounset
set -o pipefail
#set -o errexit

readonly USER_ARGS_RAW=$*

Session.Init()
    {

    IsQNAP || return 1
    DebugFuncEntry
    ShowAsProc 'init' >&2
    readonly SCRIPT_STARTSECONDS=$(/bin/date +%s)
    export LC_CTYPE=C

    readonly PROJECT_NAME=sherpa
    readonly MANAGER_SCRIPT_VERSION=201231

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

    readonly APP_CENTER_NOTIFIER=/sbin/qpkg_cli     # only needed for QTS 4.5.1-and-later
    readonly CURL_CMD=/sbin/curl
    readonly GETCFG_CMD=/sbin/getcfg
    readonly QPKG_SERVICE_CMD=/sbin/qpkg_service
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
    readonly DEBUG_LOG_DATAWIDTH=92
    readonly PACKAGE_VERSION=$(QPKG.Installed.Version "$PROJECT_NAME")

    if ! MakePath "$WORK_PATH" 'work'; then
        DebugFuncExit; return 1
    fi

    Objects.Compile
    Session.Debug.To.File.Set

    # enable debug mode early if possible
    if [[ $USER_ARGS_RAW == *"debug"* || $USER_ARGS_RAW == *"verbose"* ]]; then
        Display >&2
        Session.Debug.To.Screen.Set
    fi

    DebugInfoMajorSeparator
    DebugScript 'started' "$($DATE_CMD -d @"$SCRIPT_STARTSECONDS" | tr -s ' ')"
    DebugScript 'version' "package: $PACKAGE_VERSION, manager: $MANAGER_SCRIPT_VERSION, loader: ${LOADER_SCRIPT_VERSION:-unknown}"
    DebugScript 'PID' "$$"
    DebugInfoMinorSeparator
    DebugInfo 'Markers: (**) detected, (II) information, (WW) warning, (EE) error, (LL) log file,'
    DebugInfo '(==) processing, (--) done, (>>) f entry, (<<) f exit, (vv) variable name & value,'
    DebugInfo '($1) positional argument value'
    DebugInfoMinorSeparator

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
    readonly NAS_BUILD=$($GETCFG_CMD System 'Build Number' -f "$ULINUX_PATHFILE")
    readonly INSTALLED_RAM_KB=$($GREP_CMD MemTotal /proc/meminfo | $CUT_CMD -f2 -d':' | $SED_CMD 's|kB||;s| ||g')
    readonly MIN_RAM_KB=1048576
    readonly LOG_TAIL_LINES=3000    # a full download and install of everything generates a session around 1600 lines, but include a bunch of opkg updates and it can get much longer.
    code_pointer=0
    pip3_cmd=/opt/bin/pip3
    previous_msg=' '
    local package=''
    [[ ${NAS_FIRMWARE//.} -lt 426 ]] && curl_insecure_arg=' --insecure' || curl_insecure_arg=''
    Session.Calc.EntwareType
    Session.Calc.QPKGArch

    # supported package details - parallel arrays
    MANAGER_QPKG_NAME=()                    # internal QPKG name
        MANAGER_QPKG_IS_ESSENTIAL=()        # true/false: this is an essential QPKG. It will be required by one-or-more other QPKGs.
        MANAGER_QPKG_IS_STANDALONE=()       # true/false: this QPKG will run without any other packages
        MANAGER_QPKG_ARCH=()                # QPKG supports this architecture
        MANAGER_QPKG_VERSION=()             # QPKG version
        MANAGER_QPKG_URL=()                 # remote QPKG URL
        MANAGER_QPKG_MD5=()                 # remote QPKG MD5
        MANAGER_QPKG_DESC+=()               # QPKG description
        MANAGER_QPKG_ABBRVS=()              # if set, this package is user-installable, and these abbreviations may be used to specify app
        MANAGER_QPKG_ESSENTIALS=()          # require these QPKGs to be installed first. Use 'none' if package is optional.
        MANAGER_QPKG_IPKGS_ADD=()           # require these IPKGs to be installed first
        MANAGER_QPKG_IPKGS_REMOVE=()        # require these IPKGs to be uninstalled first
        MANAGER_QPKG_BACKUP_SUPPORTED=()    # true/false: this QPKG supports configuration 'backup' and 'restore' operations

    # essential packages here
    MANAGER_QPKG_NAME+=($PROJECT_NAME)
        MANAGER_QPKG_IS_ESSENTIAL+=(true)
        MANAGER_QPKG_IS_STANDALONE+=(true)
        MANAGER_QPKG_ARCH+=(all)
        MANAGER_QPKG_VERSION+=(201224)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/main/QPKGs/$PROJECT_NAME/build/${PROJECT_NAME}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}.qpkg)
        MANAGER_QPKG_MD5+=(9cd9aa88703071441f1b4ff57335d089)
        MANAGER_QPKG_DESC+=("provides the '$PROJECT_NAME' command: the mini-package-manager")
        MANAGER_QPKG_ABBRVS+=($PROJECT_NAME)
        MANAGER_QPKG_ESSENTIALS+=('')
        MANAGER_QPKG_IPKGS_ADD+=('')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_BACKUP_SUPPORTED+=(false)

    MANAGER_QPKG_NAME+=(Entware)
        MANAGER_QPKG_IS_ESSENTIAL+=(true)
        MANAGER_QPKG_IS_STANDALONE+=(true)
        MANAGER_QPKG_ARCH+=(all)
        MANAGER_QPKG_VERSION+=(1.03)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/main/QPKGs/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}std.qpkg)
        MANAGER_QPKG_MD5+=(da2d9f8d3442dd665ce04b9b932c9d8e)
        MANAGER_QPKG_DESC+=("provides the 'opkg' command: the OpenWRT package manager")
        MANAGER_QPKG_ABBRVS+=('ew ent opkg entware')
        MANAGER_QPKG_ESSENTIALS+=('')
        MANAGER_QPKG_IPKGS_ADD+=('')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_BACKUP_SUPPORTED+=(false)

    MANAGER_QPKG_NAME+=(Par2)
        MANAGER_QPKG_IS_ESSENTIAL+=(true)
        MANAGER_QPKG_IS_STANDALONE+=(true)
        MANAGER_QPKG_ARCH+=(x86)
        MANAGER_QPKG_VERSION+=(0.8.1.0)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/main/QPKGs/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}_x86.qpkg)
        MANAGER_QPKG_MD5+=(996ffb92d774eb01968003debc171e91)
        MANAGER_QPKG_DESC+=("provides the 'par2' command to fix downloads")     # applies to all 'Par2' packages
        MANAGER_QPKG_ABBRVS+=('par par2')                                       # applies to all 'Par2' packages
        MANAGER_QPKG_ESSENTIALS+=('')
        MANAGER_QPKG_IPKGS_ADD+=('')
        MANAGER_QPKG_IPKGS_REMOVE+=(par2cmdline)
        MANAGER_QPKG_BACKUP_SUPPORTED+=(false)

    MANAGER_QPKG_NAME+=(Par2)
        MANAGER_QPKG_IS_ESSENTIAL+=(true)
        MANAGER_QPKG_IS_STANDALONE+=(true)
        MANAGER_QPKG_ARCH+=(x64)
        MANAGER_QPKG_VERSION+=(0.8.1.0)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/main/QPKGs/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}_x86_64.qpkg)
        MANAGER_QPKG_MD5+=(520472cc87d301704f975f6eb9948e38)
        MANAGER_QPKG_DESC+=('')
        MANAGER_QPKG_ABBRVS+=('')
        MANAGER_QPKG_ESSENTIALS+=('')
        MANAGER_QPKG_IPKGS_ADD+=('')
        MANAGER_QPKG_IPKGS_REMOVE+=(par2cmdline)
        MANAGER_QPKG_BACKUP_SUPPORTED+=(false)

    MANAGER_QPKG_NAME+=(Par2)
        MANAGER_QPKG_IS_ESSENTIAL+=(true)
        MANAGER_QPKG_IS_STANDALONE+=(true)
        MANAGER_QPKG_ARCH+=(x31)
        MANAGER_QPKG_VERSION+=(0.8.1.0)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/main/QPKGs/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}_arm-x31.qpkg)
        MANAGER_QPKG_MD5+=(ce8af2e009eb87733c3b855e41a94f8e)
        MANAGER_QPKG_DESC+=('')
        MANAGER_QPKG_ABBRVS+=('')
        MANAGER_QPKG_ESSENTIALS+=('')
        MANAGER_QPKG_IPKGS_ADD+=('')
        MANAGER_QPKG_IPKGS_REMOVE+=(par2cmdline)
        MANAGER_QPKG_BACKUP_SUPPORTED+=(false)

    MANAGER_QPKG_NAME+=(Par2)
        MANAGER_QPKG_IS_ESSENTIAL+=(true)
        MANAGER_QPKG_IS_STANDALONE+=(true)
        MANAGER_QPKG_ARCH+=(x41)
        MANAGER_QPKG_VERSION+=(0.8.1.0)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/main/QPKGs/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}_arm-x41.qpkg)
        MANAGER_QPKG_MD5+=(8516e45e704875cdd2cd2bb315c4e1e6)
        MANAGER_QPKG_DESC+=('')
        MANAGER_QPKG_ABBRVS+=('')
        MANAGER_QPKG_ESSENTIALS+=('')
        MANAGER_QPKG_IPKGS_ADD+=('')
        MANAGER_QPKG_IPKGS_REMOVE+=(par2cmdline)
        MANAGER_QPKG_BACKUP_SUPPORTED+=(false)

    MANAGER_QPKG_NAME+=(Par2)
        MANAGER_QPKG_IS_ESSENTIAL+=(true)
        MANAGER_QPKG_IS_STANDALONE+=(true)
        MANAGER_QPKG_ARCH+=(a64)
        MANAGER_QPKG_VERSION+=(0.8.1.0)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/main/QPKGs/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}_arm_64.qpkg)
        MANAGER_QPKG_MD5+=(4d8e99f97936a163e411aa8765595f7a)
        MANAGER_QPKG_DESC+=('')
        MANAGER_QPKG_ABBRVS+=('')
        MANAGER_QPKG_ESSENTIALS+=('')
        MANAGER_QPKG_IPKGS_ADD+=('')
        MANAGER_QPKG_IPKGS_REMOVE+=(par2cmdline)
        MANAGER_QPKG_BACKUP_SUPPORTED+=(false)

    MANAGER_QPKG_NAME+=(Par2)
        MANAGER_QPKG_IS_ESSENTIAL+=(true)
        MANAGER_QPKG_IS_STANDALONE+=(false)
        MANAGER_QPKG_ARCH+=(none)
        MANAGER_QPKG_VERSION+=(0.8.1-1)
        MANAGER_QPKG_URL+=('')
        MANAGER_QPKG_MD5+=('')
        MANAGER_QPKG_DESC+=('')
        MANAGER_QPKG_ABBRVS+=('')
        MANAGER_QPKG_ESSENTIALS+=(Entware)
        MANAGER_QPKG_IPKGS_ADD+=(par2cmdline)
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_BACKUP_SUPPORTED+=(false)

    # only optionals below here in pseudo-alpha-sorted name order (i.e. disregard character-case and leading 'O')
    MANAGER_QPKG_NAME+=(Deluge-server)
        MANAGER_QPKG_IS_ESSENTIAL+=(false)
        MANAGER_QPKG_IS_STANDALONE+=(false)
        MANAGER_QPKG_ARCH+=(all)
        MANAGER_QPKG_VERSION+=(201130)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/main/QPKGs/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/build/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}.qpkg)
        MANAGER_QPKG_MD5+=(ec7ee6febaf34d894585afa4dec87798)
        MANAGER_QPKG_DESC+=("the Deluge bittorrent daemon")
        MANAGER_QPKG_ABBRVS+=('deluge del-server deluge-server')
        MANAGER_QPKG_ESSENTIALS+=(Entware)
        MANAGER_QPKG_IPKGS_ADD+=('deluge jq')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_BACKUP_SUPPORTED+=(true)

    MANAGER_QPKG_NAME+=(Deluge-web)
        MANAGER_QPKG_IS_ESSENTIAL+=(false)
        MANAGER_QPKG_IS_STANDALONE+=(false)
        MANAGER_QPKG_ARCH+=(all)
        MANAGER_QPKG_VERSION+=(201130)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/main/QPKGs/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/build/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}.qpkg)
        MANAGER_QPKG_MD5+=(2e77b7981360356e6457458b11e759ef)
        MANAGER_QPKG_DESC+=("a web UI to access multiple Deluge bittorrent daemons")
        MANAGER_QPKG_ABBRVS+=('del-web deluge-web')
        MANAGER_QPKG_ESSENTIALS+=(Entware)
        MANAGER_QPKG_IPKGS_ADD+=('deluge-ui-web jq')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_BACKUP_SUPPORTED+=(true)

    MANAGER_QPKG_NAME+=(HideThatBanner)
        MANAGER_QPKG_IS_ESSENTIAL+=(false)
        MANAGER_QPKG_IS_STANDALONE+=(true)
        MANAGER_QPKG_ARCH+=(all)
        MANAGER_QPKG_VERSION+=(201219b)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/main/build/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}.qpkg)
        MANAGER_QPKG_MD5+=(d576993ca2c6ec7585abe24455e19385)
        MANAGER_QPKG_DESC+=("hides the annoying rotating banner at the top of QTS App Center pages")
        MANAGER_QPKG_ABBRVS+=('htb hide hidebanner hidethatbanner')
        MANAGER_QPKG_ESSENTIALS+=('')
        MANAGER_QPKG_IPKGS_ADD+=('')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_BACKUP_SUPPORTED+=(false)

    MANAGER_QPKG_NAME+=(LazyLibrarian)
        MANAGER_QPKG_IS_ESSENTIAL+=(false)
        MANAGER_QPKG_IS_STANDALONE+=(false)
        MANAGER_QPKG_ARCH+=(all)
        MANAGER_QPKG_VERSION+=(201130)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/main/QPKGs/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/build/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}.qpkg)
        MANAGER_QPKG_MD5+=(4317b410cc8cc380218d960a78686f3d)
        MANAGER_QPKG_DESC+=("an ebook library manager")
        MANAGER_QPKG_ABBRVS+=('ll lazy lazylibrarian')
        MANAGER_QPKG_ESSENTIALS+=(Entware)
        MANAGER_QPKG_IPKGS_ADD+=('python3-pyopenssl python3-requests')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_BACKUP_SUPPORTED+=(true)

    MANAGER_QPKG_NAME+=(OMedusa)
        MANAGER_QPKG_IS_ESSENTIAL+=(false)
        MANAGER_QPKG_IS_STANDALONE+=(false)
        MANAGER_QPKG_ARCH+=(all)
        MANAGER_QPKG_VERSION+=(201130)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/main/QPKGs/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/build/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}.qpkg)
        MANAGER_QPKG_MD5+=(afa21ae0ef4b43022d09b2ee8f455176)
        MANAGER_QPKG_DESC+=("another SickBeard fork: manage and search for TV shows")
        MANAGER_QPKG_ABBRVS+=('om med omed medusa omedusa')
        MANAGER_QPKG_ESSENTIALS+=(Entware)
        MANAGER_QPKG_IPKGS_ADD+=('mediainfo python3-pyopenssl')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_BACKUP_SUPPORTED+=(true)

    MANAGER_QPKG_NAME+=(Mylar3)
        MANAGER_QPKG_IS_ESSENTIAL+=(false)
        MANAGER_QPKG_IS_STANDALONE+=(false)
        MANAGER_QPKG_ARCH+=(all)
        MANAGER_QPKG_VERSION+=(201130)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/main/QPKGs/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/build/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}.qpkg)
        MANAGER_QPKG_MD5+=(ba959d93fa95d0bd5cd95d37a6e131f0)
        MANAGER_QPKG_DESC+=("an ecomic library manager")
        MANAGER_QPKG_ABBRVS+=('my omy myl mylar mylar3')
        MANAGER_QPKG_ESSENTIALS+=(Entware)
        MANAGER_QPKG_IPKGS_ADD+=('python3-mako python3-pillow python3-pyopenssl python3-pytz python3-requests python3-six python3-urllib3')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_BACKUP_SUPPORTED+=(true)

    MANAGER_QPKG_NAME+=(NZBGet)
        MANAGER_QPKG_IS_ESSENTIAL+=(false)
        MANAGER_QPKG_IS_STANDALONE+=(false)
        MANAGER_QPKG_ARCH+=(all)
        MANAGER_QPKG_VERSION+=(201130)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/main/QPKGs/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/build/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}.qpkg)
        MANAGER_QPKG_MD5+=(c7114e6e217110bc7490ad867b5bf536)
        MANAGER_QPKG_DESC+=("a lite-and-fast NZB download manager with a simple web UI")
        MANAGER_QPKG_ABBRVS+=('ng nzb nzbg nget nzbget')
        MANAGER_QPKG_ESSENTIALS+=(Entware)
        MANAGER_QPKG_IPKGS_ADD+=(nzbget)
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_BACKUP_SUPPORTED+=(true)

    MANAGER_QPKG_NAME+=(nzbToMedia)
        MANAGER_QPKG_IS_ESSENTIAL+=(false)
        MANAGER_QPKG_IS_STANDALONE+=(false)
        MANAGER_QPKG_ARCH+=(all)
        MANAGER_QPKG_VERSION+=(201215b)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/main/QPKGs/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/build/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}.qpkg)
        MANAGER_QPKG_MD5+=(91300bd3ff3ad82e8e819905aa30484d)
        MANAGER_QPKG_DESC+=("post-processing for NZBs to many services")
        MANAGER_QPKG_ABBRVS+=('nzb2 nzb2m nzbto nzbtom nzbtomedia')
        MANAGER_QPKG_ESSENTIALS+=(Entware)
        MANAGER_QPKG_IPKGS_ADD+=('')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_BACKUP_SUPPORTED+=(true)

    MANAGER_QPKG_NAME+=(RunLast)
        MANAGER_QPKG_IS_ESSENTIAL+=(false)
        MANAGER_QPKG_IS_STANDALONE+=(true)
        MANAGER_QPKG_ARCH+=(all)
        MANAGER_QPKG_VERSION+=(201225)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/main/build/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}.qpkg)
        MANAGER_QPKG_MD5+=(2de4bf787afe34405d76ebd8fefddb43)
        MANAGER_QPKG_DESC+=("run user scripts and commands after all QPKGs have completed startup reintegration into QTS")
        MANAGER_QPKG_ABBRVS+=('rl run runlast')
        MANAGER_QPKG_ESSENTIALS+=('')
        MANAGER_QPKG_IPKGS_ADD+=('')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_BACKUP_SUPPORTED+=(false)

    MANAGER_QPKG_NAME+=(SABnzbd)
        MANAGER_QPKG_IS_ESSENTIAL+=(false)
        MANAGER_QPKG_IS_STANDALONE+=(false)
        MANAGER_QPKG_ARCH+=(all)
        MANAGER_QPKG_VERSION+=(201130)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/main/QPKGs/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/build/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}.qpkg)
        MANAGER_QPKG_MD5+=(dd1723270972c14cdfe017fc0bd51b88)
        MANAGER_QPKG_DESC+=("a full-featured NZB download manager with a nice web UI")
        MANAGER_QPKG_ABBRVS+=('sb sb3 sab sab3 sabnzbd3 sabnzbd')
        MANAGER_QPKG_ESSENTIALS+=('Entware Par2')
        MANAGER_QPKG_IPKGS_ADD+=('python3-asn1crypto python3-chardet python3-cryptography python3-pyopenssl unrar p7zip coreutils-nice ionice ffprobe')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_BACKUP_SUPPORTED+=(true)

    MANAGER_QPKG_NAME+=(SickChill)
        MANAGER_QPKG_IS_ESSENTIAL+=(false)
        MANAGER_QPKG_IS_STANDALONE+=(false)
        MANAGER_QPKG_ARCH+=(all)
        MANAGER_QPKG_VERSION+=(201130)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/main/QPKGs/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/build/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}.qpkg)
        MANAGER_QPKG_MD5+=(47a017ab38094aafde6ce25a69409762)
        MANAGER_QPKG_DESC+=("another SickBeard fork: manage and search for TV shows and movies")
        MANAGER_QPKG_ABBRVS+=('sc sick sickc chill sickchill')
        MANAGER_QPKG_ESSENTIALS+=(Entware)
        MANAGER_QPKG_IPKGS_ADD+=('')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_BACKUP_SUPPORTED+=(true)

    MANAGER_QPKG_NAME+=(OSickGear)
        MANAGER_QPKG_IS_ESSENTIAL+=(false)
        MANAGER_QPKG_IS_STANDALONE+=(false)
        MANAGER_QPKG_ARCH+=(all)
        MANAGER_QPKG_VERSION+=(201130)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/main/QPKGs/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/build/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}.qpkg)
        MANAGER_QPKG_MD5+=(c735207d769d54ca375aa6da1ab1babf)
        MANAGER_QPKG_DESC+=("another SickBeard fork: manage and search for TV shows")
        MANAGER_QPKG_ABBRVS+=('sg os osg sickg gear ogear osickg sickgear osickgear')
        MANAGER_QPKG_ESSENTIALS+=(Entware)
        MANAGER_QPKG_IPKGS_ADD+=('')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_BACKUP_SUPPORTED+=(true)

    MANAGER_QPKG_NAME+=(SortMyQPKGs)
        MANAGER_QPKG_IS_ESSENTIAL+=(false)
        MANAGER_QPKG_IS_STANDALONE+=(true)
        MANAGER_QPKG_ARCH+=(all)
        MANAGER_QPKG_VERSION+=(201228)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/main/build/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}.qpkg)
        MANAGER_QPKG_MD5+=(4bf84d42c86952b835ca290e42747e09)
        MANAGER_QPKG_DESC+=("ensure other installed QPKGs start in correct sequence during QTS bootup")
        MANAGER_QPKG_ABBRVS+=('smq smqs sort sortmy sortmine sortpackages sortmypackages sortmyqpkgs')
        MANAGER_QPKG_ESSENTIALS+=('')
        MANAGER_QPKG_IPKGS_ADD+=('')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_BACKUP_SUPPORTED+=(false)

    MANAGER_QPKG_NAME+=(OTransmission)
        MANAGER_QPKG_IS_ESSENTIAL+=(false)
        MANAGER_QPKG_IS_STANDALONE+=(false)
        MANAGER_QPKG_ARCH+=(all)
        MANAGER_QPKG_VERSION+=(201130)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/main/QPKGs/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/build/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}.qpkg)
        MANAGER_QPKG_MD5+=(c39da08668672e53f8d2dfed0f746069)
        MANAGER_QPKG_DESC+=("a lite bitorrent download manager with a simple web UI")
        MANAGER_QPKG_ABBRVS+=('ot tm tr trans otrans tmission transmission otransmission')
        MANAGER_QPKG_ESSENTIALS+=(Entware)
        MANAGER_QPKG_IPKGS_ADD+=('transmission-web jq')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_BACKUP_SUPPORTED+=(true)

    # package arrays are now full, so lock them
    readonly MANAGER_QPKG_NAME
        readonly MANAGER_QPKG_IS_ESSENTIAL
        readonly MANAGER_QPKG_IS_STANDALONE
        readonly MANAGER_QPKG_ARCH
        readonly MANAGER_QPKG_VERSION
        readonly MANAGER_QPKG_URL
        readonly MANAGER_QPKG_MD5
        readonly MANAGER_QPKG_DESC
        readonly MANAGER_QPKG_ABBRVS
        readonly MANAGER_QPKG_ESSENTIALS
        readonly MANAGER_QPKG_IPKGS_ADD
        readonly MANAGER_QPKG_IPKGS_REMOVE
        readonly MANAGER_QPKG_BACKUP_SUPPORTED

    QPKGs.Names.Add "${MANAGER_QPKG_NAME[*]}"

    readonly MANAGER_ESSENTIAL_IPKGS_ADD='findutils grep less sed'
    readonly MANAGER_COMMON_IPKGS_ADD='ca-certificates gcc git git-http nano python3-dev python3-pip python3-setuptools'
    readonly MANAGER_COMMON_PIPS_ADD='apscheduler beautifulsoup4 cfscrape cheetah3 cheroot!=8.4.4 cherrypy configobj feedparser portend pygithub python-magic random_user_agent sabyenc3 simplejson slugify'
    readonly MANAGER_COMMON_QPKG_CONFLICTS='Optware Optware-NG TarMT Python QPython2'

    QPKGs.EssentialOptionalStandalone.Build

    # speedup: don't build package lists if only showing basic help
    if [[ -z $USER_ARGS_RAW ]]; then
        User.Opts.Help.Basic.Set
        Session.SkipPackageProcessing.Set
    else
        Session.Arguments.Parse
    fi

    SmartCR >&2

    if Session.Display.Clean.IsNot; then
        if Session.Debug.To.Screen.IsNot; then
            Display "$(FormatAsScriptTitle) $MANAGER_SCRIPT_VERSION • a mini-package-manager for QNAP NAS"
            DisplayLineSpaceIfNoneAlready
        fi

        User.Opts.Apps.All.Upgrade.IsNot && User.Opts.Apps.All.Uninstall.IsNot && QPKGs.NewVersions.Show
    fi

    DebugFuncExit; return 0

    }

Session.Arguments.Parse()
    {

    # basic argument syntax:
    #   script [operation] [scope] [options]

    DebugFuncEntry

    local user_args_fixed=$(tr 'A-Z' 'a-z' <<< "${USER_ARGS_RAW//,/ }")
    local -a user_args=(${user_args_fixed/--/})
    local arg=''
    local arg_identified=false
    local operation=''
    local operation_force=false
    local scope=''
    local scope_incomplete=false    # some operations require a value for scope, so mark all operations as incomplete until scope has been defined.
    local package=''

    for arg in "${user_args[@]}"; do
        DebugVar arg
        arg_identified=false

        # identify operation    note: every time operation changes, clear scope
        case $arg in
            backup|check|install|reinstall|remove|restart|restore|start|stop|uninstall|upgrade)
                operation=${arg}_
                scope=''
                scope_incomplete=true
                arg_identified=true
                Session.Display.Clean.Clear
                Session.SkipPackageProcessing.Clear
                Session.Build.StateLists
                ;;
            status|statuses)
                operation=status_
                scope=''
                scope_incomplete=true
                arg_identified=true
                Session.Display.Clean.Clear
                Session.SkipPackageProcessing.Set
                Session.Build.StateLists
                ;;
            clean|paste)
                operation=${arg}_
                scope=''
                scope_incomplete=true
                arg_identified=true
                Session.Display.Clean.Clear
                Session.SkipPackageProcessing.Set
                ;;
            help|list|view)
                operation=help_
                scope=''
                scope_incomplete=true
                arg_identified=true
                Session.Display.Clean.Clear
                Session.SkipPackageProcessing.Set
                ;;
        esac

        DebugVar operation

        # identify scope in two stages: first stage is when user didn't supply an operation. Second is after an operation has been defined.

        # stage 1
        if [[ -z $operation ]]; then
            DebugAsProc 'no operation set: checking for scopes that will run without an operation'

            case $arg in
                abs|action|actions|all-actions|backups|essentials|installable|installed|l|last|log|option|optionals|options|package|packages|problems|standalone|standalones|started|stopped|tips|upgradable|version|versions)
                    operation=help_
                    scope=''
                    scope_incomplete=true
                    arg_identified=true
                    Session.SkipPackageProcessing.Set
                    ;;
            esac

            DebugVar operation
        fi

        # stage 2
        if [[ -n $operation ]]; then
            DebugAsProc 'operation has been set: checking for valid scope variations'

            case $arg in
                abs|all-actions|backups|installable|installed|log|problems|started|stopped|tips|upgradable)
                    scope=${arg}_
                    scope_incomplete=false
                    arg_identified=true
                    ;;
                action|actions)
                    scope=actions_
                    scope_incomplete=false
                    arg_identified=true
                    ;;
                all|whole|entire|everything)
                    scope=all_
                    scope_incomplete=false
                    arg_identified=true
                    ;;
                essential|essentials)
                    scope=essential_
                    scope_incomplete=false
                    arg_identified=true
                    ;;
                l|last)
                    scope=last_
                    scope_incomplete=false
                    arg_identified=true
                    ;;
                option|options)
                    scope=options_
                    scope_incomplete=false
                    arg_identified=true
                    ;;
                optional|optionals)
                    scope=optional_
                    scope_incomplete=false
                    arg_identified=true
                    ;;
                package|packages)
                    scope=packages_
                    scope_incomplete=false
                    arg_identified=true
                    ;;
                standalone|standalones)
                    scope=standalone_
                    scope_incomplete=false
                    arg_identified=true
                    ;;
                version|versions)
                    scope=versions_
                    scope_incomplete=false
                    arg_identified=true
                    ;;
            esac
        fi

        DebugVar scope

        # identify options
        case $arg in
            debug|verbose)
                Session.Debug.To.Screen.Set
                arg_identified=true
                scope_incomplete=false
                ;;
            force)
                operation_force=true
                arg_identified=true
                ;;
            ignore-space)
                User.Opts.IgnoreFreeSpace.Set
                arg_identified=true
                ;;
        esac

        DebugVar operation_force
        DebugVar scope_incomplete

        # identify package
        package=$(QPKG.MatchAbbrv "$arg")

        DebugVar package

        if [[ -n $package ]]; then
            scope_incomplete=false
            arg_identified=true
        fi

        if [[ $arg_identified = false ]]; then
            DebugAsProc "adding '$arg' as unknown argument"
            Args.Unknown.Add "$arg"
        fi

        case $operation in
            backup_)
                case $scope in
                    all_)
                        User.Opts.Apps.All.Backup.Set
                        operation=''
                        ;;
                    essential_)
                        QPKGs.ToBackup.Add "$(QPKGs.Essential.Array)"
                        ;;
                    optional_)
                        QPKGs.ToBackup.Add "$(QPKGs.Optional.Array)"
                        ;;
                    standalone_)
                        QPKGs.ToBackup.Add "$(QPKGs.Standalone.Array)"
                        ;;
                    started_)
                        QPKGs.ToBackup.Add "$(QPKGs.Enabled.Array)"
                        ;;
                    stopped_)
                        QPKGs.ToBackup.Add "$(QPKGs.Disabled.Array)"
                        ;;
                    *)
                        QPKGs.ToBackup.Add "$package"
                        ;;
                esac
                ;;
            check_)
                User.Opts.Dependencies.Check.Set
                ;;
            clean_)
                User.Opts.Clean.Set
                ;;
            help_)
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
                    backups_)
                        User.Opts.Apps.List.Backups.Set
                        ;;
                    essential_)
                        User.Opts.Apps.List.Essential.Set
                        Session.Display.Clean.Set
                        ;;
                    installable_)
                        Session.Build.StateLists
                        User.Opts.Apps.List.NotInstalled.Set
                        Session.Display.Clean.Set
                        ;;
                    installed_)
                        Session.Build.StateLists
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
                        Session.Build.StateLists
                        User.Opts.Help.Packages.Set
                        ;;
                    problems_)
                        User.Opts.Help.Problems.Set
                        ;;
                    standalone_)
                        User.Opts.Apps.List.Standalone.Set
                        Session.Display.Clean.Set
                        ;;
                    started_)
                        Session.Build.StateLists
                        User.Opts.Apps.List.Started.Set
                        Session.Display.Clean.Set
                        ;;
                    status_)
                        Session.Build.StateLists
                        User.Opts.Apps.All.Status.Set
                        ;;
                    stopped_)
                        Session.Build.StateLists
                        User.Opts.Apps.List.Stopped.Set
                        Session.Display.Clean.Set
                        ;;
                    tips_)
                        User.Opts.Help.Tips.Set
                        ;;
                    upgradable_)
                        Session.Build.StateLists
                        User.Opts.Apps.List.Upgradable.Set
                        Session.Display.Clean.Set
                        ;;
                    versions_)
                        User.Opts.Versions.View.Set
                        Session.Display.Clean.Set
                        ;;
                esac
                ;;
            install_)
                case $scope in
                    all_)
                        User.Opts.Apps.All.Install.Set
                        operation=''
                        ;;
                    essential_)
                        QPKGs.ToInstall.Add "$(QPKGs.Essential.Array)"
                        ;;
                    optional_)
                        QPKGs.ToInstall.Add "$(QPKGs.Optional.Array)"
                        ;;
                    standalone_)
                        QPKGs.ToInstall.Add "$(QPKGs.Standalone.Array)"
                        ;;
                    *)
                        QPKGs.ToInstall.Add "$package"
                        ;;
                esac
                ;;
            paste_)
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
                case $scope in
                    all_)
                        User.Opts.Apps.All.Reinstall.Set
                        operation=''
                        ;;
                    essential_)
                        QPKGs.ToReinstall.Add "$(QPKGs.Essential.Array)"
                        ;;
                    optional_)
                        QPKGs.ToReinstall.Add "$(QPKGs.Optional.Array)"
                        ;;
                    standalone_)
                        QPKGs.ToReinstall.Add "$(QPKGs.Standalone.Array)"
                        ;;
                    *)
                        QPKGs.ToReinstall.Add "$package"
                        ;;
                esac
                ;;
            restart_)
                case $scope in
                    all_)
                        User.Opts.Apps.All.Restart.Set
                        operation=''
                        ;;
                    essential_)
                        QPKGs.ToRestart.Add "$(QPKGs.Essential.Array)"
                        ;;
                    optional_)
                        QPKGs.ToRestart.Add "$(QPKGs.Optional.Array)"
                        ;;
                    standalone_)
                        QPKGs.ToRestart.Add "$(QPKGs.Standalone.Array)"
                        ;;
                    *)
                        QPKGs.ToRestart.Add "$package"
                        ;;
                esac
                ;;
            restore_)
                case $scope in
                    all_)
                        User.Opts.Apps.All.Restore.Set
                        operation=''
                        ;;
                    essential_)
                        QPKGs.ToRestore.Add "$(QPKGs.Essential.Array)"
                        ;;
                    optional_)
                        QPKGs.ToRestore.Add "$(QPKGs.Optional.Array)"
                        ;;
                    standalone_)
                        QPKGs.ToRestore.Add "$(QPKGs.Standalone.Array)"
                        ;;
                    *)
                        QPKGs.ToRestore.Add "$package"
                        ;;
                esac
                ;;
            start_)
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
                    standalone_)
                        QPKGs.ToStart.Add "$(QPKGs.Standalone.Array)"
                        ;;
                    stopped_)
                        QPKGs.ToStart.Add "$(QPKGs.Disabled.Array)"
                        ;;
                    *)
                        QPKGs.ToStart.Add "$package"
                        ;;
                esac
                ;;
            status_)
                case $scope in
                    all_)
#                         QPKGs.ToStatus.Add "$(QPKGs.Installable.Array)"
                        User.Opts.Apps.All.Status.Set
                        operation=''
                        Session.SkipPackageProcessing.Set
                        ;;
# TODO: implement selective package status checks
#                     essential_)
#                         QPKGs.ToStatus.Add "$(QPKGs.Essential.Array)"
#                         ;;
#                     optional_)
#                         QPKGs.ToStatus.Add "$(QPKGs.Optional.Array)"
#                         ;;
#                     standalone_)
#                         QPKGs.ToStatus.Add "$(QPKGs.Standalone.Array)"
#                         ;;
#                     *)
#                         QPKGs.ToStatus.Add "$package"
#                         ;;
                esac
                ;;
            stop_)
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
                    standalone_)
                        QPKGs.ToStop.Add "$(QPKGs.Standalone.Array)"
                        ;;
                    started_)
                        QPKGs.ToStop.Add "$(QPKGs.Enabled.Array)"
                        ;;
                    *)
                        QPKGs.ToStop.Add "$package"
                        ;;
                esac
                ;;
            uninstall_|remove_)
                if [[ $operation_force = true ]]; then  # this operation is dangerous, so make 'force' a requirement
                    case $scope in
                        all_)
                            QPKGs.ToUninstall.Add "$(QPKGs.Installed.Array)"
                            User.Opts.Apps.All.Uninstall.Set
                            operation=''
                            operation_force=false
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
                case $scope in
                    all_)
                        User.Opts.Apps.All.Upgrade.Set
                        operation=''
                        ;;
                    essential_)
                        QPKGs.ToUpgrade.Add "$(QPKGs.Essential.Array)"
                        ;;
                    optional_)
                        QPKGs.ToUpgrade.Add "$(QPKGs.Optional.Array)"
                        ;;
                    standalone_)
                        QPKGs.ToUpgrade.Add "$(QPKGs.Standalone.Array)"
                        ;;
                    started_)
                        QPKGs.ToUpgrade.Add "$(QPKGs.Enabled.Array)"
                        ;;
                    stopped_)
                        QPKGs.ToUpgrade.Add "$(QPKGs.Disabled.Array)"
                        ;;
                    *)
                        QPKGs.ToUpgrade.Add "$package"
                        ;;
                esac
                ;;
        esac
    done

    if [[ -n $operation && $scope_incomplete = true ]]; then
        DebugAsProc "processing operation '$operation' with incomplete scope"

        case $operation in
            abs_)
                User.Opts.Help.Abbreviations.Set
                ;;
            backups_)
                User.Opts.Apps.List.Backups.Set
                ;;
            help_)
                User.Opts.Help.Basic.Set
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
            status_)
                User.Opts.Apps.All.Status.Set
                ;;
            tips_)
                User.Opts.Help.Tips.Set
                ;;
            versions_)
                User.Opts.Versions.View.Set
                Session.Display.Clean.Set
                ;;
        esac
    fi

    if Args.Unknown.IsAny; then
        User.Opts.Help.Basic.Set
        Session.Display.Clean.Clear
        Session.SkipPackageProcessing.Set
    fi

    DebugFuncExit; return 0

    }

Session.Arguments.Suggestions()
    {

    DebugFuncEntry
    local arg=''

    if Args.Unknown.IsAny; then
        ShowAsEror "unknown argument$(FormatAsPlural "$(Args.Unknown.Count)"): \"$(Args.Unknown.List)\""

        for arg in $(Args.Unknown.Array); do
            case $arg in
                all)
                    DisplayAsProjectSyntaxExample "please provide an $(FormatAsHelpAction) before 'all' like" 'start all'
                    User.Opts.Help.Basic.Clear
                    ;;
                backup-all)
                    DisplayAsProjectSyntaxExample 'to backup all installed package configurations, use' 'backup all'
                    User.Opts.Help.Basic.Clear
                    ;;
                essential)
                    DisplayAsProjectSyntaxExample "please provide an $(FormatAsHelpAction) before 'essential' like" 'start essential'
                    User.Opts.Help.Basic.Clear
                    ;;
                optional)
                    DisplayAsProjectSyntaxExample "please provide an $(FormatAsHelpAction) before 'optional' like" 'start optional'
                    User.Opts.Help.Basic.Clear
                    ;;
                restart-all)
                    DisplayAsProjectSyntaxExample 'to restart all packages, use' 'restart all'
                    User.Opts.Help.Basic.Clear
                    ;;
                restore-all)
                    DisplayAsProjectSyntaxExample 'to restore all installed package configurations, use' 'restore all'
                    User.Opts.Help.Basic.Clear
                    ;;
                start-all)
                    DisplayAsProjectSyntaxExample 'to start all packages, use' 'start all'
                    User.Opts.Help.Basic.Clear
                    ;;
                stop-all)
                    DisplayAsProjectSyntaxExample 'to stop all packages, use' 'stop all'
                    User.Opts.Help.Basic.Clear
                    ;;
                uninstall-all|remove-all)
                    DisplayAsProjectSyntaxExample 'to uninstall all packages, use' 'force uninstall all'
                    User.Opts.Help.Basic.Clear
                    ;;
                upgrade-all)
                    DisplayAsProjectSyntaxExample 'to upgrade all packages, use' 'upgrade all'
                    User.Opts.Help.Basic.Clear
                    ;;
            esac
        done
    fi

    DebugFuncExit; return 0

    }

Session.Validate()
    {

    DebugFuncEntry
    Session.Arguments.Suggestions

    if Session.SkipPackageProcessing.IsSet; then
        DebugFuncExit; return 1
    fi

    ShowAsProc 'validating parameters' >&2

    local package=''
    local -i max_width=58
    local -i trimmed_width=$((max_width-3))

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

    DebugUserspace.OK '$BASH_VERSION' "$BASH_VERSION"
    DebugUserspace.OK 'default volume' "$($GETCFG_CMD SHARE_DEF defVolMP -f "$DEFAULT_SHARES_PATHFILE")"

    if [[ -L '/opt' ]]; then
        DebugUserspace.OK '/opt' "$($READLINK_CMD '/opt' || echo '<not present>')"
    else
        DebugUserspace.Warning '/opt' '<not present>'
    fi

    if [[ ${#PATH} -le $max_width ]]; then
        DebugUserspace.OK '$PATH' "$PATH"
    else
        DebugUserspace.OK '$PATH' "${PATH:0:trimmed_width}..."
    fi

    CheckPythonPathAndVersion python2
    CheckPythonPathAndVersion python3
    CheckPythonPathAndVersion python
    DebugUserspace.OK 'raw arguments' "\"$USER_ARGS_RAW\""

    DebugScript 'logs path' "$LOGS_PATH"
    DebugScript 'work path' "$WORK_PATH"
    DebugScript 'object reference hash' "$(Objects.Compile hash)"

    DebugQPKG 'upgradable QPKGs' "$(QPKGs.Upgradable.ListCSV) "
    DebugInfoMinorSeparator

    if Session.SkipPackageProcessing.IsSet; then
        DebugFuncExit; return 1
    fi

    if ! QPKGs.Conflicts.Check; then
        code_pointer=2
        Session.SkipPackageProcessing.Set
        DebugFuncExit; return 1
    fi

    if QPKGs.ToBackup.IsNone && QPKGs.ToUninstall.IsNone && QPKGs.ToUpgrade.IsNone && QPKGs.ToInstall.IsNone && QPKGs.ToReinstall.IsNone && QPKGs.ToRestore.IsNone && QPKGs.ToRestart.IsNone && QPKGs.ToStart.IsNone && QPKGs.ToStop.IsNone; then
        if User.Opts.Apps.All.Install.IsNot && User.Opts.Apps.All.Restart.IsNot && User.Opts.Apps.All.Upgrade.IsNot && User.Opts.Apps.All.Backup.IsNot && User.Opts.Apps.All.Restore.IsNot && User.Opts.Apps.All.Status.IsNot && User.Opts.Apps.All.Start.IsNot && User.Opts.Apps.All.Stop.IsNot; then
            if User.Opts.Dependencies.Check.IsNot && User.Opts.IgnoreFreeSpace.IsNot; then
                ShowAsEror "I've nothing to do (usually means the arguments didn't make sense, or were incomplete)"
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

# package processing priorities need to be:
#  17. backup all                   (highest: most-important)
#  16. stop optionals
#  15. stop essentials
#  14. uninstall all

#  13. upgrade essentials
#  12. reinstall essentials
#  11. install essentials
#  10. restore essentials
#   9. start essentials
#   8. restart essentials

#   7. upgrade optionals
#   6. reinstall optionals
#   5. install optionals
#   4. restore optionals
#   3. start optionals
#   2. restart optionals

#   1. status                       (lowest: least-important)

Tiers.Processor()
    {

    Session.SkipPackageProcessing.IsSet && return
    DebugFuncEntry
    local package=''

    QPKGs.SupportsBackup.Build

    # build an initial download list
    if User.Opts.Apps.All.Upgrade.IsSet; then
        QPKGs.ToUpgrade.Add "$(QPKGs.Upgradable.Array)"
    fi

    if User.Opts.Apps.All.Reinstall.IsSet; then
        QPKGs.ToReinstall.Add "$(QPKGs.Installable.Array)"
    fi

    if User.Opts.Apps.All.Install.IsSet; then
        QPKGs.ToInstall.Add "$(QPKGs.Installable.Array)"
    fi

    Dynamic.Package.Shuffle

    QPKGs.ToDownload.Add "$(QPKGs.ToUpgrade.Array)"
    QPKGs.ToDownload.Add "$(QPKGs.ToReinstall.Array)"
    QPKGs.ToDownload.Add "$(QPKGs.ToInstall.Array)"

    # download all required essentials too
    for package in $(QPKGs.ToDownload.Array); do
        QPKGs.ToDownload.Add "$(QPKG.Get.Essentials "$package")"
    done

    Tier.Processor 'Download' false 'all' 'QPKG' 'ToDownload' 'forward' 'update cache with' 'updating cache with' 'updated cache with' ''

    if User.Opts.Apps.All.Backup.IsSet; then
        QPKGs.ToBackup.Add "$(QPKGs.SupportsBackup.Array)"
    fi

    QPKGs.ToBackup.Remove "$(QPKGs.NotSupportsBackup.Array)"
    QPKGs.ToBackup.Remove "$(QPKGs.NotInstalled.Array)"

    Tier.Processor 'Backup' false 'all' 'QPKG' 'ToBackup' 'forward' 'backup' 'backing-up' 'backed-up' ''

    # check for packages to be stopped or uninstalled, and ensure related packages are stopped
    if User.Opts.Apps.All.Stop.IsSet; then
        QPKGs.ToStop.Add "$(QPKGs.Installed.Array)"
    fi

    # don't stop then start a package. Make it restart instead.
    for package in $(QPKGs.ToStop.Array); do
        if QPKGs.ToStart.Exist "$package"; then
            QPKGs.ToStop.Remove "$package"
            QPKGs.ToStart.Remove "$package"
            QPKGs.ToRestart.Add "$package"
        fi
    done

    if User.Opts.Apps.All.Uninstall.IsSet; then
        QPKGs.ToStop.Init   # no-need to stop all packages, as they are about to be uninstalled
    fi

    if QPKGs.ToReinstall.Exist Entware; then    # treat Entware as a special case: complete removal and fresh install (to clear all installed IPKGs)
        QPKGs.ToUninstall.Add Entware
        QPKGs.ToInstall.Add Entware
        QPKGs.ToReinstall.Remove Entware
    fi

    # if an essential has been selected for stop, need to stop its optionals first
    for package in $(QPKGs.ToStop.Array); do
        if QPKGs.Essential.Exist "$package" && QPKG.Installed "$package"; then
            QPKGs.ToStop.Add "$(QPKG.Get.Optionals "$package")"
        fi
    done

    # if an essential has been selected for uninstall, need to stop its optionals first
    for package in $(QPKGs.ToUninstall.Array); do
        if QPKGs.Essential.Exist "$package" && QPKG.Installed "$package"; then
            QPKGs.ToStop.Add "$(QPKG.Get.Optionals "$package")"
        fi
    done

    # if an essential has been selected for install, need to stop its optionals first, and start them again later
    for package in $(QPKGs.ToInstall.Array); do
        if QPKGs.Essential.Exist "$package" && QPKG.Installed "$package"; then
            QPKGs.ToStop.Add "$(QPKG.Get.Optionals "$package")"
            QPKGs.ToStart.Add "$(QPKG.Get.Optionals "$package")"
        fi
    done

    # if an essential has been selected for reinstall, need to stop its optionals first, and start them again later
    for package in $(QPKGs.ToReinstall.Array); do
        if QPKGs.Essential.Exist "$package" && QPKG.Installed "$package"; then
            QPKGs.ToStop.Add "$(QPKG.Get.Optionals "$package")"
            QPKGs.ToStart.Add "$(QPKG.Get.Optionals "$package")"
        fi
    done

    # don't stop packages that are already stopped
    for package in $(QPKGs.ToStop.Array); do
        if QPKG.NotEnabled "$package"; then
            QPKGs.ToStop.Remove "$package"
        fi
    done

    QPKGs.ToStop.Remove "$(QPKGs.IsStop.Array)"
    QPKGs.ToStop.Remove "$(QPKGs.NotInstalled.Array)"
    QPKGs.ToStop.Remove "$(QPKGs.ToUninstall.Array)"
    QPKGs.ToStop.Remove "$PROJECT_NAME"

    Tier.Processor 'Stop' false 'optional' 'QPKG' 'ToStop' 'backward' 'stop' 'stopping' 'stopped' ''
    Tier.Processor 'Stop' false 'essential' 'QPKG' 'ToStop' 'backward' 'stop' 'stopping' 'stopped' ''

    QPKGs.ToUninstall.Remove "$(QPKGs.NotInstalled.Array)"
    QPKGs.ToUninstall.Remove "$PROJECT_NAME"

    Tier.Processor 'Uninstall' false 'optional' 'QPKG' 'ToUninstall' 'forward' 'uninstall' 'uninstalling' 'uninstalled' ''

    ShowAsProc "checking for addon packages to uninstall" >&2
    QPKG.Installed Entware && IPKGs.Uninstall

    Tier.Processor 'Uninstall' false 'essential' 'QPKG' 'ToUninstall' 'forward' 'uninstall' 'uninstalling' 'uninstalled' ''

    # adjust configuration restore lists to remove essentials (these can't be backed-up or restored for-now)
    if User.Opts.Apps.All.Restore.IsSet; then
        QPKGs.ToRestore.Add "$(QPKGs.Installed.Array)"
    fi

    QPKGs.ToRestore.Remove "$(QPKGs.Essential.Array)"

    if User.Opts.Apps.All.Upgrade.IsSet; then
        QPKGs.ToRestart.Add "$(QPKGs.Optional.Array)"
        QPKGs.ToRestart.Remove "$(QPKGs.Standalone.Array)"
    fi

    for tier in {'essential','addon','optional'}; do
        case $tier in
            essential|optional)
                Tier.Processor 'Upgrade' false "$tier" 'QPKG' 'ToUpgrade' 'forward' 'upgrade' 'upgrading' 'upgraded' 'long'
                Tier.Processor 'Reinstall' false "$tier" 'QPKG' 'ToReinstall' 'forward' 'reinstall' 'reinstalling' 'reinstalled' 'long'
                Tier.Processor 'Install' false "$tier" 'QPKG' 'ToInstall' 'forward' 'install' 'installing' 'installed' 'long'

                if [[ $tier = optional ]]; then
                    Tier.Processor 'Restore' false "$tier" 'QPKG' 'ToRestore' 'forward' 'restore configuration for' 'restoring configuration for' 'configuration restored for' 'long'
                fi

                # adjust lists for start
                if User.Opts.Apps.All.Start.IsSet; then
                    QPKGs.ToStart.Add "$(QPKGs.Installed.Array)"
                else
                    # check for essential packages that require starting due to any optionals being reinstalled
                    for package in $(QPKGs.ToReinstall.Array); do
                        QPKGs.ToStart.Add "$(QPKG.Get.Essentials "$package")"
                    done

                    for package in $(QPKGs.IsReinstall.Array); do
                        QPKGs.ToStart.Add "$(QPKG.Get.Essentials "$package")"
                    done

                    # check for essential packages that require starting due to any optionals being installed
                    for package in $(QPKGs.ToInstall.Array); do
                        QPKGs.ToStart.Add "$(QPKG.Get.Essentials "$package")"
                    done

                    for package in $(QPKGs.IsInstall.Array); do
                        QPKGs.ToStart.Add "$(QPKG.Get.Essentials "$package")"
                    done

                    # check for essential packages that require starting due to any optionals being started
                    for package in $(QPKGs.ToStart.Array); do
                        QPKGs.ToStart.Add "$(QPKG.Get.Essentials "$package")"
                    done

                    for package in $(QPKGs.IsStart.Array); do
                        QPKGs.ToStart.Add "$(QPKG.Get.Essentials "$package")"
                    done

                    # check for essential packages that require starting due to any optionals being restarted
                    for package in $(QPKGs.ToRestart.Array); do
                        QPKGs.ToStart.Add "$(QPKG.Get.Essentials "$package")"
                    done
                fi

                # don't start packages that are already started
                for package in $(QPKGs.ToStart.Array); do
                    if QPKG.Enabled "$package"; then
                        QPKGs.ToStart.Remove "$package"
                    fi
                done

                # no-need to start packages that are unavailable
                QPKGs.ToStart.Remove "$(QPKGs.NotInstalled.Array)"
                QPKGs.ToStart.Remove "$(QPKGs.ToInstall.Array)"
                QPKGs.ToStart.Remove "$PROJECT_NAME"

                Tier.Processor 'Start' false "$tier" 'QPKG' 'ToStart' 'forward' 'start' 'starting' 'started' 'long'

                # check all items
                if User.Opts.Dependencies.Check.IsSet; then
                    for package in $(QPKGs.Optional.Array); do
                        if ! QPKGs.Standalone.Exist "$package" && ! QPKGs.Upgradable.Exist "$package"; then
                            QPKGs.ToRestart.Add "$package"
                        fi
                    done
                fi

                # adjust lists for restart
                if User.Opts.Apps.All.Restart.IsSet; then
                    QPKGs.ToRestart.Add "$(QPKGs.Installed.Array)"
                else
                    # check for optional packages that require restarting due to any essentials being started
                    for package in $(QPKGs.IsStart.Array); do
                        QPKGs.ToRestart.Add "$(QPKG.Get.Optionals "$package")"
                    done

                    # check for optional packages that require restarting due to any essentials being restarted
                    for package in $(QPKGs.ToRestart.Array); do
                        QPKGs.ToRestart.Add "$(QPKG.Get.Optionals "$package")"
                    done

                    # check for optional packages that require restarting due to any essentials being upgraded
                    for package in $(QPKGs.IsUpgrade.Array); do
                        QPKGs.ToRestart.Add "$(QPKG.Get.Optionals "$package")"
                    done

                    # don't restart packages that are not started
                    for package in $(QPKGs.ToRestart.Array); do
                        if QPKG.NotEnabled "$package"; then
                            QPKGs.ToRestart.Remove "$package"
                        fi
                    done

                    # don't restart packages that are not installed
                    for package in $(QPKGs.ToRestart.Array); do
                        if QPKGs.NotInstalled.Exist "$package"; then
                            QPKGs.ToRestart.Remove "$package"
                        fi
                    done
                fi

                Tier.Processor 'Restart' false "$tier" 'QPKG' 'ToRestart' 'forward' 'restart' 'restarting' 'restarted' 'long'
                ;;
            addon)
                if QPKGs.ToInstall.IsAny || QPKGs.IsInstall.IsAny || QPKGs.ToReinstall.IsAny || QPKGs.IsReinstall.IsAny || QPKGs.ToUpgrade.IsAny || QPKGs.IsUpgrade.IsAny; then
                    Session.IPKGs.Install.Set
                fi

                if QPKGs.ToInstall.Exist SABnzbd || QPKGs.ToReinstall.Exist SABnzbd || QPKGs.ToUpgrade.Exist SABnzbd; then
                    Session.PIPs.Install.Set   # must ensure 'sabyenc' and 'feedparser' modules are installed/updated
                fi

                if QPKG.Enabled Entware; then
                    Session.AddPathToEntware
                    Tier.Processor 'Install' false "$tier" 'IPKG' '' 'forward' 'install' 'installing' 'installed' 'long'
                    Tier.Processor 'Install' false "$tier" 'PIP' '' 'forward' 'install' 'installing' 'installed' 'long'
                else
                    : # TODO: test if other packages are to be installed here. If so, and Entware isn't enabled, then abort with error.
                fi
                ;;
        esac
    done

    QPKGs.OperationAssignment.List
    SmartCR >&2

    DebugFuncExit; return 0

    }

Tier.Processor()
    {

    # run a single operation on a group of packages

    # input:
    #   $1 = $TARGET_OPERATION              e.g. 'Start', 'Restart', etc...
    #   $2 = forced operation?              e.g. 'true', 'false'
    #   $3 = $TIER                          e.g. 'essential', 'optional', 'addon', 'all'
    #   $4 = $PACKAGE_TYPE                  e.g. 'QPKG', 'IPKG', 'PIP'
    #   $5 = $TARGET_OBJECT_NAME (optional) e.g. 'ToStart', 'ToStop', etc...
    #   $6 = $PROCESSING_DIRECTION          e.g. 'forward', 'backward'
    #   $7 = $ACTION_INTRANSITIVE           e.g. 'start', etc...
    #   $8 = $ACTION_PRESENT                e.g. 'starting', etc...
    #   $9 = $ACTION_PAST                   e.g. "started', etc...
    #  $10 = $RUNTIME (optional)            e.g. 'long'

    [[ -z $1 || -z $3 || -z $4 || -z $6 || -z $7 || -z $8 || -z $9 ]] && return

    DebugFuncEntry

    local package=''
    local forced_operation=''
    local message_prefix=''
    local target_function=''
    local targets_function=''
    local -i index=0
    local -a target_packages=()
    local -i package_count=0
    local -i pass_count=0
    local -i fail_count=0
    local -r TARGET_OPERATION=$1
    local -r TIER=$3
    local -r PACKAGE_TYPE=$4
    local -r TARGET_OBJECT_NAME=$5
    local -r PROCESSING_DIRECTION=$6
    local -r RUNTIME=${10}

    if [[ $2 = true ]]; then
        forced_operation='--forced'
        message_prefix='force-'
    fi

    case $PACKAGE_TYPE in
        QPKG|IPKG|PIP)
            target_function=$PACKAGE_TYPE
            targets_function=${PACKAGE_TYPE}s
            ;;
        *)
            DebugAsError "unknown \$PACKAGE_TYPE: '$PACKAGE_TYPE'"
            return 1
            ;;
    esac

    local -r ACTION_INTRANSITIVE=${message_prefix}$7
    local -r ACTION_PRESENT=${message_prefix}$8
    local -r ACTION_PAST=${message_prefix}$9

    ShowAsProc "checking for$([[ $TIER = all ]] && echo '' || echo " $TIER") packages to $ACTION_INTRANSITIVE" >&2

    case $PACKAGE_TYPE in
        QPKG)
            if $targets_function.$TARGET_OBJECT_NAME.IsNone; then
                DebugInfo "no $targets_function to process"
                DebugFuncExit; return 0
            fi

            if [[ $TIER = all ]]; then
                target_packages=($($targets_function.$TARGET_OBJECT_NAME.Array))
            else
                for package in $($targets_function.$TARGET_OBJECT_NAME.Array); do
                    $targets_function."$(tr 'a-z' 'A-Z' <<< "${TIER:0:1}")${TIER:1}".Exist "$package" && target_packages+=("$package")
                done
            fi

            package_count=${#target_packages[@]}

            if [[ $package_count -eq 0 ]]; then
                DebugInfo "no$([[ $TIER = all ]] && echo '' || echo " $TIER") $targets_function to process"
                DebugFuncExit; return 0
            fi

            if [[ $PROCESSING_DIRECTION = forward ]]; then
                for package in "${target_packages[@]}"; do                  # process list forwards
                    ShowAsOperationProgress "$TIER" "$package_count" "$fail_count" "$pass_count" "$ACTION_PRESENT" "$RUNTIME"

                    if ! $target_function.$TARGET_OPERATION "$package" "$forced_operation"; then
                        ShowAsFail "unable to $ACTION_INTRANSITIVE $(FormatAsPackageName "$package") (see log for more details)"
                        ((fail_count++))
                        continue
                    fi

                    ((pass_count++))
                done
            else
                for ((index=package_count-1; index>=0; index--)); do       # process list backwards
                    package=${target_packages[$index]}
                    ShowAsOperationProgress "$TIER" "$package_count" "$fail_count" "$pass_count" "$ACTION_PRESENT" "$RUNTIME"

                    if ! $target_function.$TARGET_OPERATION "$package" "$forced_operation"; then
                        ShowAsFail "unable to $ACTION_INTRANSITIVE $(FormatAsPackageName "$package") (see log for more details)"
                        ((fail_count++))
                        continue
                    fi

                    ((pass_count++))
                done
            fi
            ;;
        IPKG|PIP)
            $targets_function.$TARGET_OPERATION
            ;;
    esac

    ShowAsOperationResult "$TIER" "$package_count" "$fail_count" "$pass_count" "$ACTION_PAST" "$RUNTIME"
    DebugFuncExit; return 0

    }

Dynamic.Package.Shuffle()
    {

    # this runs before operations for 'download' (and possibly 'install', 'reinstall' and 'upgrade': TBD) to ensure package lists are sane

    local package=''

    # check reinstall for all items that should be installed instead
    for package in $(QPKGs.ToReinstall.Array); do
        if QPKG.NotInstalled "$package"; then
            QPKGs.ToReinstall.Remove "$package"
            QPKGs.ToInstall.Add "$package"
        fi
    done

    # check install list for items that should be reinstalled instead
    for package in $(QPKGs.ToInstall.Array); do
        if QPKG.Installed "$package"; then
            QPKGs.ToInstall.Remove "$package"
            QPKGs.ToReinstall.Add "$package"
        fi
    done

    if User.Opts.Apps.All.Install.IsSet; then
        QPKGs.ToInstall.Add "$(QPKGs.Installable.Array)"
    fi

    # check upgrade for essential items that should be installed
    for package in $(QPKGs.ToUpgrade.Array); do
        QPKGs.ToInstall.Add "$(QPKG.Get.Essentials "$package")"
    done

    # check upgrade list for all items that should be installed
    for package in $(QPKGs.ToUpgrade.Array); do
        if QPKG.NotInstalled "$package"; then
            QPKGs.ToInstall.Add "$package"
        fi
    done

    # check reinstall for essential items that should be installed
    for package in $(QPKGs.ToReinstall.Array); do
        QPKGs.ToInstall.Add "$(QPKG.Get.Essentials "$package")"
    done

    # check install for essential items that should be installed
    for package in $(QPKGs.ToInstall.Array); do
        QPKGs.ToInstall.Add "$(QPKG.Get.Essentials "$package")"
    done

    # check start for essential items that should be installed
    for package in $(QPKGs.ToStart.Array); do
        QPKGs.ToInstall.Add "$(QPKG.Get.Essentials "$package")"
    done

    # check restart for essential items that should be installed
    for package in $(QPKGs.ToRestart.Array); do
        QPKGs.ToInstall.Add "$(QPKG.Get.Essentials "$package")"
    done

    QPKGs.ToInstall.Remove "$(QPKGs.Installed.Array)"

    return 0

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
        elif User.Opts.Apps.List.Started.IsSet; then
            QPKGs.Started.Show
        elif User.Opts.Apps.List.Stopped.IsSet; then
            QPKGs.Stopped.Show
        elif User.Opts.Apps.List.Upgradable.IsSet; then
            QPKGs.Upgradable.Show
        elif User.Opts.Apps.List.Essential.IsSet; then
            QPKGs.Essential.Show
        elif User.Opts.Apps.List.Optional.IsSet; then
            QPKGs.Optional.Show
        elif User.Opts.Apps.List.Standalone.IsSet; then
            QPKGs.Standalone.Show
        elif User.Opts.Apps.List.Backups.IsSet; then
            QPKGs.Backups.Show
        elif User.Opts.Apps.All.Status.IsSet; then
            QPKGs.Statuses.Show
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
        code_pointer=3
        return 1
    fi

    local package_minutes_threshold=60
    local log_pathfile=$LOGS_PATH/entware.$UPDATE_LOG_FILE
    local msgs=''
    local -i resultcode=0

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
            DebugAsWarn "Unable to update $(FormatAsPackageName Entware) package list $(FormatAsExitcode $resultcode)"
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
    local -i resultcode=0

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

    Session.AddPathToEntware

    [[ -n ${MANAGER_COMMON_PIPS_ADD// /} ]] && exec_cmd="$pip3_cmd install $MANAGER_COMMON_PIPS_ADD --disable-pip-version-check --cache-dir $PIP_CACHE_PATH"

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
        code_pointer=4
        return 1
    fi

    DebugFuncEntry
    local -i package_count=0
    local requested_list=''
    local -a this_list=()
    local -a dependency_accumulator=()
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
                IPKGs.ToDownload.Add 'libjpeg-turbo'
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

    IPKGs.Archive.Close
    DebugFuncExit; return 0

    }

CalcAllIPKGDepsToUninstall()
    {

    # From a specified list of IPKG names, exclude those already installed, then generate a total qty to uninstall

    if IsNotSysFileExist $OPKG_CMD || IsNotSysFileExist $GNU_GREP_CMD; then
        code_pointer=5
        return 1
    fi

    DebugFuncEntry
    local requested_list=''
    local -i package_count=0
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
    QPKG.NotEnabled Entware && return
    Entware.Update
    Session.Error.IsSet && return
    DebugFuncEntry
    local -i index=0

    IPKGs.ToInstall.Add "$MANAGER_COMMON_IPKGS_ADD"

    if User.Opts.Apps.All.Install.IsSet; then
        for index in "${!MANAGER_QPKG_NAME[@]}"; do
            [[ ${MANAGER_QPKG_ARCH[$index]} = "$NAS_QPKG_ARCH" || ${MANAGER_QPKG_ARCH[$index]} = all ]] && IPKGs.ToInstall.Add "${MANAGER_QPKG_IPKGS_ADD[$index]}"
        done
    else
        for index in "${!MANAGER_QPKG_NAME[@]}"; do
            if QPKGs.ToInstall.Exist "${MANAGER_QPKG_NAME[$index]}" || QPKG.Installed "${MANAGER_QPKG_NAME[$index]}" || QPKGs.ToReinstall.Exist "${MANAGER_QPKG_NAME[$index]}" || QPKGs.ToUpgrade.Exist "${MANAGER_QPKG_NAME[$index]}"; then
                [[ ${MANAGER_QPKG_ARCH[$index]} = "$NAS_QPKG_ARCH" || ${MANAGER_QPKG_ARCH[$index]} = all ]] && IPKGs.ToInstall.Add "${MANAGER_QPKG_IPKGS_ADD[$index]}"
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
    QPKG.NotEnabled Entware && return
    Session.Error.IsSet && return
    DebugFuncEntry
    local -i index=0

    if User.Opts.Apps.All.Uninstall.IsNot; then
        for index in "${!MANAGER_QPKG_NAME[@]}"; do
            if QPKGs.ToInstall.Exist "${MANAGER_QPKG_NAME[$index]}" || QPKG.Installed "${MANAGER_QPKG_NAME[$index]}" || QPKGs.ToUpgrade.Exist "${MANAGER_QPKG_NAME[$index]}" || QPKGs.ToUninstall.Exist "${MANAGER_QPKG_NAME[$index]}"; then
                IPKGs.ToUninstall.Add "${MANAGER_QPKG_IPKGS_REMOVE[$index]}"
            fi
        done

        # when package arch is 'none', prevent 'par2cmdline' being uninstalled, then installed again later this same session. Noticed this was happening on ARMv5 models.
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
    local -i package_count=0
    local log_pathfile=$LOGS_PATH/ipkgs.$UPGRADE_LOG_FILE
    local -i resultcode=0

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
    local -i package_count=0
    local log_pathfile=$LOGS_PATH/ipkgs.addons.$INSTALL_LOG_FILE
    local -i resultcode=0

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
    local -i package_count=0
    local log_pathfile=$LOGS_PATH/ipkgs.$UNINSTALL_LOG_FILE
    local -i resultcode=0

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

    local -i total_bytes=$2
    local -i last_bytes=0
    local -i stall_seconds=0
    local -i stall_seconds_threshold=4
    local stall_message=''
    local -i current_bytes=0
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

readonly HELP_DESC_INDENT=3
readonly HELP_SYNTAX_INDENT=8
readonly HELP_PACKAGE_NAME_WIDTH=16

DisplayAsProjectSyntaxExample()
    {

    # $1 = description
    # $2 = example syntax

    if [[ ${1: -1} = '!' ]]; then
        printf "\n* %s \n%${HELP_SYNTAX_INDENT}s# %s\n" "$(tr 'a-z' 'A-Z' <<< "${1:0:1}")${1:1}" '' "$PROJECT_NAME $2"
    else
        printf "\n* %s:\n%${HELP_SYNTAX_INDENT}s# %s\n" "$(tr 'a-z' 'A-Z' <<< "${1:0:1}")${1:1}" '' "$PROJECT_NAME $2"
    fi

    Session.LineSpace.Clear

    }

DisplayAsProjectSyntaxIndentedExample()
    {

    # $1 = description
    # $2 = example syntax

    if [[ -z $1 ]]; then
        printf "%${HELP_SYNTAX_INDENT}s# %s\n" '' "$PROJECT_NAME $2"
    elif [[ ${1: -1} = '!' ]]; then
        printf "\n%${HELP_DESC_INDENT}s%s \n%${HELP_SYNTAX_INDENT}s# %s\n" '' "$(tr 'a-z' 'A-Z' <<< "${1:0:1}")${1:1}" '' "$PROJECT_NAME $2"
    else
        printf "\n%${HELP_DESC_INDENT}s%s:\n%${HELP_SYNTAX_INDENT}s# %s\n" '' "$(tr 'a-z' 'A-Z' <<< "${1:0:1}")${1:1}" '' "$PROJECT_NAME $2"
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
        printf "\n* %s \n%${HELP_SYNTAX_INDENT}s# %s\n" "$(tr 'a-z' 'A-Z' <<< "${1:0:1}")${1:1}" '' "$2"
    else
        printf "\n* %s:\n%${HELP_SYNTAX_INDENT}s# %s\n" "$(tr 'a-z' 'A-Z' <<< "${1:0:1}")${1:1}" '' "$2"
    fi

    Session.LineSpace.Clear

    }

DisplayAsHelpPackageNamePlusSomething()
    {

    # $1 = package name
    # $2 = package text

    printf "%${HELP_DESC_INDENT}s%-${HELP_PACKAGE_NAME_WIDTH}s- %s\n" '' "$1" "$2"

    }

DisplayAsHelpTitlePackageNamePlusSomething()
    {

    # $1 = package name
    # $2 = package text

    printf "* %-${HELP_PACKAGE_NAME_WIDTH}s* %s\n" "$1:" "$2:"

    }

SmartCR()
    {

    # reset cursor to start-of-line, erasing previous characters

    [[ $(type -t Session.Debug.To.Screen.Init) = 'function' ]] && Session.Debug.To.Screen.IsSet && return

    echo -en "\033[1K\r"

    }

Display()
    {

    echo -e "${1:-}"
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

    Display "\nThere's also the wiki: $(FormatAsURL "https://github.com/OneCDOnly/$PROJECT_NAME/wiki")"

    return 0

    }

Help.Actions.Show()
    {

    Help.Basic.Show
    DisplayLineSpaceIfNoneAlready
    Display "* $(FormatAsHelpAction) usage examples:"

    DisplayAsProjectSyntaxIndentedExample 'show package statuses' 'status all'

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
    Display "* These $(FormatAsHelpAction)s apply to all installed packages. If $(FormatAsHelpAction) is 'install all' then all available packages will be installed."
    DisplayLineSpaceIfNoneAlready
    Display "* $(FormatAsHelpAction) usage examples:"

    DisplayAsProjectSyntaxIndentedExample 'show package statuses' 'status all'

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

    return 0

    }

Help.Packages.Show()
    {

    local package=''

    Help.Basic.Show
    DisplayLineSpaceIfNoneAlready
    Display "* One-or-more $(FormatAsHelpPackages) may be specified at-once"
    Display

    DisplayAsHelpTitlePackageNamePlusSomething 'essentials' 'package description'

    for package in $(QPKGs.Essential.Array); do
        DisplayAsHelpPackageNamePlusSomething "$package" "$(QPKG.Desc "$package")"
    done

    Display
    DisplayAsHelpTitlePackageNamePlusSomething 'optionals' 'package description'

    for package in $(QPKGs.Optional.Array); do
        DisplayAsHelpPackageNamePlusSomething "$package" "$(QPKG.Desc "$package")"
    done

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
    Display "* Please consider creating a new issue for this on GitHub:\n\thttps://github.com/OneCDOnly/$PROJECT_NAME/issues"

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

    local package=''
    local abs=''
    Help.Basic.Show
    DisplayLineSpaceIfNoneAlready
    Display "* $(FormatAsScriptTitle) recognises various abbreviations as $(FormatAsHelpPackages)"
    Display
    DisplayAsHelpTitlePackageNamePlusSomething 'essentials' 'acceptable abreviations'

    for package in $(QPKGs.Essential.Array); do
        abs=$(QPKG.Abbrvs "$package")
        [[ -n $abs ]] && DisplayAsHelpPackageNamePlusSomething "$package" "${abs// /, }"
    done

    Display
    DisplayAsHelpTitlePackageNamePlusSomething 'optionals' 'acceptable abreviations'

    for package in $(QPKGs.Optional.Array); do
        abs=$(QPKG.Abbrvs "$package")
        [[ -n $abs ]] && DisplayAsHelpPackageNamePlusSomething "$package" "${abs// /, }"
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

    # view only the last runtime session

    ExtractPreviousSessionFromTail

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

    ExtractFixedTailFromLog

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

    ExtractPreviousSessionFromTail

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

GetSessionStart()
    {

    # $1 = count how many back? (optional)

    local -i back=1
    [[ -n $1 ]] && back=$1

    echo $(($($GREP_CMD -n 'SCRIPT:.*started:' "$SESSION_TAIL_PATHFILE" | $TAIL_CMD -n${back} | $HEAD_CMD -n1 | $CUT_CMD -d':' -f1)-1))

    }

GetSessionFinish()
    {

    # $1 = count how many back? (optional)

    local -i back=1
#         [[ -n $1 ]] && back=$1

    echo $(($($GREP_CMD -n 'SCRIPT:.*finished:' "$SESSION_TAIL_PATHFILE" | $TAIL_CMD -n${back} | $CUT_CMD -d':' -f1)+2))

    }

ExtractPreviousSessionFromTail()
    {

    local -i start_line=0
    local -i end_line=0
    local -i old_session=1
    local -i old_session_limit=12   # don't try to find 'started:' any further back than this many sessions

    ExtractFixedTailFromLog

    if [[ -e $SESSION_TAIL_PATHFILE ]]; then
        end_line=$(GetSessionFinish)
        start_line=$((end_line+1))      # ensure an invalid condition, to be solved by the loop

        while [[ $start_line -ge $end_line ]]; do
            start_line=$(GetSessionStart "$old_session")

            ((old_session++))
            [[ $old_session -gt $old_session_limit ]] && break
        done

        $SED_CMD "$start_line,$end_line!d" "$SESSION_TAIL_PATHFILE" > "$SESSION_LAST_PATHFILE"
    else
        [[ -e $SESSION_LAST_PATHFILE ]] && rm -rf "$SESSION_LAST_PATHFILE"
    fi

    return 0

    }

ExtractFixedTailFromLog()
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
    Display "objects hash: $(Objects.Compile hash)"

    return 0

    }

QPKGs.NewVersions.Show()
    {

    # Check installed QPKGs and compare versions against package arrays. If new versions are available, advise on-screen.

    # $? = 0 if all packages are up-to-date
    # $? = 1 if one-or-more packages can be upgraded

    local msg=''
    local -i index=0
    local -a left_to_upgrade=()
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

    for package in "${MANAGER_COMMON_QPKG_CONFLICTS[@]}"; do
        if QPKG.Enabled "$package"; then
            ShowAsEror "'$package' is installed and enabled. One-or-more $(FormatAsScriptTitle) applications are incompatible with this package"
            return 1
        fi
    done

    return 0

    }

QPKGs.OperationAssignment.List()
    {

    DebugFuncEntry

    local array_name=''
    local -a operations_array=(ToDownload IsDownload UnDownload ToBackup IsBackup UnBackup ToStop IsStop UnStop ToUninstall IsUninstall UnUninstall ToUpgrade IsUpgrade UnUpgrade ToReinstall IsReinstall UnReinstall ToInstall IsInstall UnInstall ToRestore IsRestore UnRestore ToStart IsStart UnStart ToRestart IsRestart UnRestart ToStatus Installed NotInstalled Upgradable Missing)

    DebugInfoMinorSeparator

    for array_name in "${operations_array[@]}"; do
        # speedup: only log arrays with more than zero elements
        QPKGs.$array_name.IsAny && DebugQPKG "$array_name" "($(QPKGs.$array_name.Count)) $(QPKGs.$array_name.ListCSV) "
    done

    DebugInfoMinorSeparator
    DebugFuncExit; return 0

    }

QPKGs.EssentialOptionalStandalone.Build()
    {

    # there are three tiers of package: 'essential', 'addon' and 'optional'
    # ... but only two tiers of QPKG: 'essential' and 'optional'

    # 'essential' QPKGs don't depend on other QPKGs, but are required for other QPKGs. They should be installed/started before any 'optional' QPKGs.
    # 'optional' QPKGs may depend on other QPKGs. They should be installed/started after any 'essential' QPKGs.

    # 'standalone' isn't a tier, but a category of package that works without requiring any other package(s). A package may be 'standalone' or-not and can also be 'essential' or 'optional'.

    DebugFuncEntry
    local -i index=0

    for index in "${!MANAGER_QPKG_NAME[@]}"; do
        if [[ ${MANAGER_QPKG_IS_ESSENTIAL[$index]} = true ]]; then
            QPKGs.Essential.Add "${MANAGER_QPKG_NAME[$index]}"
        else
            QPKGs.Optional.Add "${MANAGER_QPKG_NAME[$index]}"
        fi

        if [[ ${MANAGER_QPKG_IS_STANDALONE[$index]} = true ]]; then
            QPKGs.Standalone.Add "${MANAGER_QPKG_NAME[$index]}"
        fi
    done

    DebugFuncExit; return 0

    }

Session.Build.StateLists()
    {

    # Builds several lists of QPKGs:
    #   - can be installed or reinstalled by the user
    #   - can be upgraded
    #   - are installed and enabled or installed and disabled in [/etc/config/qpkg.conf]
    #   - have config blocks in [/etc/config/qpkg.conf], but no files on-disk

    Session.Lists.Built.IsSet && return

    DebugFuncEntry
    ShowAsProc 'building package state lists' >&2

    local package=''
    local installed_version=''
    local remote_version=''

    for package in $(QPKGs.Names.Array); do
        QPKG.UserInstallable "$package" && QPKGs.Installable.Add "$package"

        if QPKG.Installed "$package"; then
            QPKGs.Installed.Add "$package"

            installed_version=$(QPKG.Installed.Version "$package")
            remote_version=$(QPKG.Remote.Version "$package")

            if [[ ${installed_version//./} != "${remote_version//./}" ]]; then
                QPKGs.Upgradable.Add "$package"
            else
                QPKGs.Upgradable.Remove "$package"
            fi

            if QPKG.Enabled "$package"; then
                QPKGs.Enabled.Add "$package"
            else
                QPKGs.Disabled.Add "$package"
            fi

            [[ ! -d $(QPKG.InstallPath "$package") ]] && QPKGs.Missing.Add "$package"
        else
            QPKGs.NotInstalled.Add "$package"
        fi
    done

    Session.Lists.Built.Set
    DebugFuncExit; return 0

    }

QPKGs.SupportsBackup.Build()
    {

    # Builds a list of QPKGs that do and don't support 'backup' and 'restore' operations

    DebugFuncEntry
    local package=''

    for package in $(QPKGs.Names.Array); do
        if QPKG.SupportsBackup "$package"; then
            QPKGs.SupportsBackup.Add "$package"
            QPKGs.NotSupportsBackup.Remove "$package"
        else
            QPKGs.NotSupportsBackup.Add "$package"
            QPKGs.SupportsBackup.Remove "$package"
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
    DisplayLineSpaceIfNoneAlready
    Display "* The location for $(FormatAsScriptTitle) backups is: $(Session.Backup.Path)"
    Display

    if [[ -e $GNU_FIND_CMD ]]; then
        printf '%-33s%-33s\n' '* backup file:' '* last backup date:'
        $GNU_FIND_CMD "$(Session.Backup.Path)"/*.config.tar.gz -maxdepth 1 -printf ' %-33f%Cc\n' 2>/dev/null
    else
        (cd "$(Session.Backup.Path)" && ls -1 ./*.config.tar.gz)
    fi

    return 0

    }

QPKGs.Statuses.Show()
    {

    local -a package_notes=()

    SmartCR
    DisplayLineSpaceIfNoneAlready
    DisplayAsHelpTitlePackageNamePlusSomething 'essentials' 'statuses'

    for package in $(QPKGs.Essential.Array); do
        package_notes=()
        package_note=''

        QPKGs.NotInstalled.Exist "$package" && package_notes+=(not-installed)
        QPKGs.Enabled.Exist "$package" && package_notes+=($(ColourTextBrightGreen started))
        QPKGs.Disabled.Exist "$package" && package_notes+=($(ColourTextBrightRed stopped))
        QPKGs.Upgradable.Exist "$package" && package_notes+=($(ColourTextBrightOrange upgradable))
        QPKGs.Missing.Exist "$package" && package_notes=($(ColourTextBrightRedBlink missing))

        [[ ${#package_notes[@]} -gt 0 ]] && package_note="${package_notes[*]}"

        DisplayAsHelpPackageNamePlusSomething "$package" "${package_note// /, }"
    done

    Display
    DisplayAsHelpTitlePackageNamePlusSomething 'optionals' 'statuses'

    for package in $(QPKGs.Optional.Array); do
        package_notes=()
        package_note=''

        QPKGs.NotInstalled.Exist "$package" && package_notes+=(not-installed)
        QPKGs.Enabled.Exist "$package" && package_notes+=($(ColourTextBrightGreen started))
        QPKGs.Disabled.Exist "$package" && package_notes+=($(ColourTextBrightRed stopped))
        QPKGs.Upgradable.Exist "$package" && package_notes+=($(ColourTextBrightOrange upgradable))
        QPKGs.Missing.Exist "$package" && package_notes=($(ColourTextBrightRedBlink missing))

        [[ ${#package_notes[@]} -gt 0 ]] && package_note="${package_notes[*]}"

        DisplayAsHelpPackageNamePlusSomething "$package" "${package_note// /, }"
    done

    DisplayLineSpaceIfNoneAlready
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

QPKGs.Started.Show()
    {

    local package=''

    for package in $(QPKGs.Enabled.Array); do
        Display "$package"
    done

    return 0

    }

QPKGs.Stopped.Show()
    {

    local package=''

    for package in $(QPKGs.Disabled.Array); do
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

QPKGs.Standalone.Show()
    {

    local package=''

    for package in $(QPKGs.Standalone.Array); do
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
            DebugAsWarn "$(FormatAsPackageName Entware) appears to be installed but is not visible"
        fi
    fi

    }

Session.AddPathToEntware()
    {

    local opkg_prefix=/opt/bin:/opt/sbin

    [[ $PATH =~ opkg_prefix ]] && return

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

    ! [[ $PATH =~ opkg_prefix ]] && return

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

    [[ ${_script_error_flag:-} = true ]]

    }

Session.Error.IsNot()
    {

    [[ ${_script_error_flag:-} != true ]]

    }

Session.Summary.Show()
    {

    local -i index=0
    local -a operations_array=(Backup Stop Uninstall Upgrade Reinstall Install Restore Start Restart)
    local -a messages_array=(backed-up stopped uninstalled upgraded reinstalled installed restored started restarted)

    for index in "${!operations_array[@]}"; do
        User.Opts.Apps.All.${operations_array[$index]}.IsSet && QPKGs.Is${operations_array[$index]}.IsNone && ShowAsDone "no QPKGs were ${messages_array[$index]}"
    done

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

    local output=''

    if output=$($GETCFG_CMD "$1" Shell -f $APP_CENTER_CONFIG_PATHFILE); then
        echo "$output"
        return 0
    else
        echo 'unknown'
        return 1
    fi

    }

QPKG.Installed.Version()
    {

    # Returns the version number of an installed QPKG.

    # input:
    #   $1 = QPKG name

    # output:
    #   stdout = package version
    #   $? = 0 if found, 1 if not

    local output=''

    if output=$($GETCFG_CMD "$1" Version -f $APP_CENTER_CONFIG_PATHFILE); then
        echo "$output"
        return 0
    else
        echo 'unknown'
        return 1
    fi

    }

QPKG.InstallPath()
    {

    # input:
    #   $1 = QPKG name

    # output:
    #   stdout = QPKG installed path
    #   $? = 0 if found, 1 if not

    local output=''

    if output=$($GETCFG_CMD "$1" Install_Path -f $APP_CENTER_CONFIG_PATHFILE); then
        echo "$output"
        return 0
    else
        echo 'unknown'
        return 1
    fi

    }

QPKG.ClearServiceStatus()
    {

    # input:
    #   $1 = QPKG name

    [[ -e /var/run/$1.last.operation ]] && rm /var/run/"$1".last.operation

    }

QPKG.GetServiceStatus()
    {

    # input:
    #   $1 = QPKG name

    if [[ -e /var/run/$1.last.operation ]]; then
        case $(</var/run/"$1".last.operation) in
            ok)
                DebugInfo "$(FormatAsPackageName "$1") service started OK"
                ;;
            failed)
                ShowAsEror "$(FormatAsPackageName "$1") service failed to start.$([[ -e /var/log/$1.log ]] && echo " Check $(FormatAsFileName "/var/log/$1.log") for more information")"
                ;;
            *)
                DebugAsWarn "$(FormatAsPackageName "$1") service status is incorrect"
                ;;
        esac
    else
        DebugAsWarn "unable to get status of $(FormatAsPackageName "$1") service. It may be a non-$PROJECT_NAME package, or a package earlier than 200816c that doesn't support service results."
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

    local -i index=0

    for index in "${!MANAGER_QPKG_NAME[@]}"; do
        if [[ $1 = "${MANAGER_QPKG_NAME[$index]}" ]] && [[ ${MANAGER_QPKG_ARCH[$index]} = all || ${MANAGER_QPKG_ARCH[$index]} = "$NAS_QPKG_ARCH" ]]; then
            echo "${MANAGER_QPKG_URL[$index]}"
            return 0
        fi
    done

    return 1

    }

QPKG.Desc()
    {

    # input:
    #   $1 = QPKG name

    # output:
    #   stdout = QPKG description
    #   $? = 0 if successful, 1 if failed

    local -i index=0

    for index in "${!MANAGER_QPKG_NAME[@]}"; do
        if [[ $1 = "${MANAGER_QPKG_NAME[$index]}" ]]; then
            echo "${MANAGER_QPKG_DESC[$index]}"
            return 0
        fi
    done

    return 1

    }

QPKG.Remote.Version()
    {

    # input:
    #   $1 = QPKG name

    # output:
    #   stdout = QPKG remote version
    #   $? = 0 if successful, 1 if failed

    local -i index=0

    for index in "${!MANAGER_QPKG_NAME[@]}"; do
        if [[ $1 = "${MANAGER_QPKG_NAME[$index]}" ]] && [[ ${MANAGER_QPKG_ARCH[$index]} = all || ${MANAGER_QPKG_ARCH[$index]} = "$NAS_QPKG_ARCH" ]]; then
            echo "${MANAGER_QPKG_VERSION[$index]}"
            return 0
        fi
    done

    return 1

    }

QPKG.MD5()
    {

    # input:
    #   $1 = QPKG name

    # output:
    #   stdout = QPKG MD5
    #   $? = 0 if successful, 1 if failed

    local -i index=0

    for index in "${!MANAGER_QPKG_NAME[@]}"; do
        if [[ $1 = "${MANAGER_QPKG_NAME[$index]}" ]] && [[ ${MANAGER_QPKG_ARCH[$index]} = all || ${MANAGER_QPKG_ARCH[$index]} = "$NAS_QPKG_ARCH" ]]; then
            echo "${MANAGER_QPKG_MD5[$index]}"
            return 0
        fi
    done

    return 1

    }

QPKG.Get.Essentials()
    {

    # input:
    #   $1 = QPKG name to return 'esssential' packages for

    # output:
    #   $? = 0 if successful, 1 if failed

    local -i index=0

    for index in "${!MANAGER_QPKG_NAME[@]}"; do
        if [[ ${MANAGER_QPKG_NAME[$index]} = "$1" ]]; then
            if [[ ${MANAGER_QPKG_ESSENTIALS[$index]} != none ]]; then
                echo "${MANAGER_QPKG_ESSENTIALS[$index]}"
                return 0
            fi
        fi
    done

    return 1

    }

QPKG.Get.Optionals()
    {

    # input:
    #   $1 = 'essential' QPKG name to return optionals for

    # output:
    #   $? = 0 if successful, 1 if failed

    local -i index=0
    local -a acc=()

    if QPKGs.Essential.Exist "$1"; then
        for index in "${!MANAGER_QPKG_NAME[@]}"; do
            if [[ ${MANAGER_QPKG_ESSENTIALS[$index]} == *"$1"* ]]; then
                [[ ${acc[*]:-} != "${MANAGER_QPKG_NAME[$index]}" ]] && acc+=(${MANAGER_QPKG_NAME[$index]})
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
    #   $? = 0 if successful (or package was already downloaded), 1 if failed

    Session.Error.IsSet && return
    DebugFuncEntry

    if [[ -z $1 ]]; then
        DebugFuncExit; return 1
    fi

    local -i resultcode=0
    local remote_url=$(QPKG.URL "$1")
    local remote_filename=$($BASENAME_CMD "$remote_url")
    local remote_md5=$(QPKG.MD5 "$1")
    local local_pathfile=$QPKG_DL_PATH/$remote_filename
    local local_filename=$($BASENAME_CMD "$local_pathfile")
    local log_pathfile=$LOGS_PATH/$local_filename.$DOWNLOAD_LOG_FILE

    if [[ -z $remote_url ]]; then
        DebugAsWarn "no URL found for this package $(FormatAsPackageName "$1")"
        DebugFuncExit; return
    fi

    if [[ -e $local_pathfile ]]; then
        if FileMatchesMD5 "$local_pathfile" "$remote_md5"; then
            DebugInfo "local package $(FormatAsFileName "$local_filename") checksum correct, so skipping download"
        else
            DebugAsWarn "local package $(FormatAsFileName "$local_filename") checksum incorrect"
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
                QPKGs.IsDownload.Add "$1"
            else
                DebugAsError "downloaded package $(FormatAsFileName "$local_pathfile") checksum incorrect"
                resultcode=1
                QPKGs.UnDownload.Add "$1"
            fi
        else
            DebugAsError "download failed $(FormatAsFileName "$local_pathfile") $(FormatAsExitcode $resultcode)"
            QPKGs.UnDownload.Add "$1"
        fi
    fi

    QPKGs.ToDownload.Remove "$1"
    DebugFuncExit; return $resultcode

    }

QPKG.Install()
    {

    # input:
    #   $1 = QPKG name

    Session.Error.IsSet && return
    Session.SkipPackageProcessing.IsSet && return
    DebugFuncEntry

    if [[ -z $1 ]]; then
        DebugFuncExit; return 1
    fi

    local target_file=''
    local -i resultcode=0
    local local_pathfile=$(QPKG.PathFilename "$1")
    local log_pathfile=''

    if [[ ${local_pathfile##*.} = zip ]]; then
        $UNZIP_CMD -nq "$local_pathfile" -d "$QPKG_DL_PATH"
        local_pathfile=${local_pathfile%.*}
    fi

    if [[ $1 = Entware ]] && ! QPKG.Installed Entware && QPKGs.ToInstall.Exist Entware; then
        local opt_path=/opt
        local opt_backup_path=/opt.orig

        if [[ -d $opt_path && ! -L $opt_path && ! -e $opt_backup_path ]]; then
            ShowAsProc "backup original /opt" >&2
            mv "$opt_path" "$opt_backup_path"
            DebugAsDone 'complete'
        fi
    fi

    target_file=$($BASENAME_CMD "$local_pathfile")
    log_pathfile=$LOGS_PATH/$target_file.$INSTALL_LOG_FILE

    DebugAsProc "installing $(FormatAsPackageName "$1")"

    RunAndLog "$SH_CMD $local_pathfile" "$log_pathfile"
    resultcode=$?

    if [[ $resultcode -eq 0 || $resultcode -eq 10 ]]; then
        DebugAsDone "installed $(FormatAsPackageName "$1")"
        QPKG.FixAppCenterStatus "$1"
        QPKG.GetServiceStatus "$1"

        if [[ $1 = Entware ]]; then
            Session.AddPathToEntware
            Entware.Patch.Service

            if QPKGs.ToInstall.Exist Entware; then
                local log_pathfile=$LOGS_PATH/ipkgs.extra.$INSTALL_LOG_FILE

                # copy all files from original [/opt] into new [/opt]
                if [[ -L $opt_path && -d $opt_backup_path ]]; then
                    ShowAsProc "restoring original /opt" >&2
                    cp --recursive "$opt_backup_path"/* --target-directory "$opt_path" && rm -rf "$opt_backup_path"
                    DebugAsDone 'complete'
                fi

                # add extra package(s) needed immediately
                ShowAsProc 'installing essential IPKGs'
                RunAndLog "$OPKG_CMD install$(User.Opts.IgnoreFreeSpace.IsSet && User.Opts.IgnoreFreeSpace.Text) --force-overwrite $MANAGER_ESSENTIAL_IPKGS_ADD --cache $IPKG_CACHE_PATH --tmp-dir $IPKG_DL_PATH" "$log_pathfile"
                ShowAsDone 'installed essential IPKGs'

                Session.PIPs.Install.Set
            fi
        fi

        QPKGs.IsInstall.Add "$1"
        QPKGs.Installed.Add "$1"
        QPKGs.NotInstalled.Remove "$1"
        resultcode=0    # reset this to zero (0 or 10 from a QPKG install is OK)
    else
        DebugAsError "installation failed $(FormatAsFileName "$target_file") $(FormatAsExitcode $resultcode)"
        QPKGs.UnInstall.Add "$1"
    fi

    QPKGs.ToInstall.Remove "$1"
    DebugFuncExit; return $resultcode

    }

QPKG.Reinstall()
    {

    # input:
    #   $1 = QPKG name

    Session.Error.IsSet && return
    Session.SkipPackageProcessing.IsSet && return
    DebugFuncEntry

    if [[ -z $1 ]]; then
        DebugFuncExit; return 1
    fi

    local target_file=''
    local -i resultcode=0
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
        QPKGs.IsReinstall.Add "$1"
        QPKG.GetServiceStatus "$1"
        QPKG.FixAppCenterStatus "$1"
        resultcode=0    # reset this to zero (0 or 10 from a QPKG install is OK)
    else
        ShowAsEror "reinstallation failed $(FormatAsFileName "$target_file") $(FormatAsExitcode $resultcode)"
        QPKGs.UnReinstall.Add "$1"
    fi

    QPKGs.ToReinstall.Remove "$1"
    DebugFuncExit; return $resultcode

    }

QPKG.Upgrade()
    {

    # Upgrades the QPKG named in $1

    # input:
    #   $1 = QPKG name

    # output:
    #   $? = 0 if successful, 1 if failed

    Session.Error.IsSet && return
    Session.SkipPackageProcessing.IsSet && return
    DebugFuncEntry

    if [[ -z $1 ]]; then
        DebugFuncExit; return 1
    fi

    local -i resultcode=0
    local previous_version='null'
    local current_version='null'
    local local_pathfile=$(QPKG.PathFilename "$1")

    if [[ ${local_pathfile##*.} = zip ]]; then
        $UNZIP_CMD -nq "$local_pathfile" -d "$QPKG_DL_PATH"
        local_pathfile=${local_pathfile%.*}
    fi

    local target_file=$($BASENAME_CMD "$local_pathfile")
    local log_pathfile=$LOGS_PATH/$target_file.$UPGRADE_LOG_FILE

    if ! QPKG.Installed "$1"; then
        DebugAsWarn "unable to upgrade $(FormatAsPackageName "$1") as it's not installed"
        QPKGs.ToUpgrade.Remove "$1"
        QPKGs.UnUpgrade.Remove "$1"
        DebugFuncExit; return 0
    fi

    previous_version=$(QPKG.Installed.Version "$1")
    QPKG.FixAppCenterStatus "$1"

    DebugAsProc "upgrading $(FormatAsPackageName "$1")"

    RunAndLog "$SH_CMD $local_pathfile" "$log_pathfile"
    resultcode=$?

    current_version=$(QPKG.Installed.Version "$1")

    if [[ $resultcode -eq 0 || $resultcode -eq 10 ]]; then
        if [[ $current_version = "$previous_version" ]]; then
            DebugAsDone "upgraded $(FormatAsPackageName "$1") and installed version is $current_version"
        else
            DebugAsDone "upgraded $(FormatAsPackageName "$1") from $previous_version to $current_version"
        fi
        QPKG.GetServiceStatus "$1"
        QPKGs.IsUpgrade.Add "$1"
        QPKGs.Upgradable.Remove "$1"
        resultcode=0    # reset this to zero (0 or 10 from a QPKG upgrade is OK)
    else
        ShowAsEror "upgrade failed $(FormatAsFileName "$target_file") $(FormatAsExitcode $resultcode)"
        QPKGs.UnUpgrade.Add "$1"
    fi

    QPKGs.ToUpgrade.Remove "$1"
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

    local -i resultcode=0
    local qpkg_installed_path=$($GETCFG_CMD "$1" Install_Path -f $APP_CENTER_CONFIG_PATHFILE)
    local log_pathfile=$LOGS_PATH/$1.$UNINSTALL_LOG_FILE

    if QPKG.NotInstalled "$1"; then
        DebugAsWarn "unable to uninstall $(FormatAsPackageName "$1") as it's not installed"
        QPKGs.ToUninstall.Remove "$1"
        QPKGs.UnUninstall.Add "$1"
        QPKGs.NotInstalled.Add "$1"
        QPKGs.Installed.Remove "$1"
        DebugFuncExit; return 0
    fi

    [[ $1 = Entware ]] && Package.Save.Lists

    if [[ -e $qpkg_installed_path/.uninstall.sh ]]; then
        DebugAsProc "uninstalling $(FormatAsPackageName "$1")"

        RunAndLog "$SH_CMD $qpkg_installed_path/.uninstall.sh" "$log_pathfile"
        resultcode=$?

        if [[ $resultcode -eq 0 ]]; then
            DebugAsDone "uninstalled $(FormatAsPackageName "$1")"
            $RMCFG_CMD "$1" -f $APP_CENTER_CONFIG_PATHFILE
            DebugAsDone 'removed icon information from App Center'
            [[ $1 = Entware ]] && Session.RemovePathToEntware
            QPKGs.IsUninstall.Add "$1"
            QPKGs.NotInstalled.Add "$1"
            QPKGs.Installed.Remove "$1"
        else
            DebugAsError "unable to uninstall $(FormatAsPackageName "$1") $(FormatAsExitcode $resultcode)"
            QPKGs.UnUninstall.Add "$1"
        fi
    fi

    QPKGs.ToUninstall.Remove "$1"
    QPKG.FixAppCenterStatus "$1"
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

    local -i resultcode=0
    local log_pathfile=$LOGS_PATH/$1.$RESTART_LOG_FILE
    QPKG.ClearServiceStatus "$1"

    if QPKG.NotInstalled "$1"; then
        DebugAsWarn "unable to restart $(FormatAsPackageName "$1") as it's not installed"
        QPKGs.ToRestart.Remove "$1"
        QPKGs.UnRestart.Add "$1"
        DebugFuncExit; return 0
    fi

    QPKG.Enable "$1"
    DebugAsProc "restarting $(FormatAsPackageName "$1")"

    RunAndLog "$QPKG_SERVICE_CMD restart $1" "$log_pathfile"
    resultcode=$?

    if [[ $resultcode -eq 0 ]]; then
        DebugAsDone "restarted $(FormatAsPackageName "$1")"
        QPKG.GetServiceStatus "$1"
        QPKGs.IsRestart.Add "$1"
    else
        ShowAsWarn "unable to restart $(FormatAsPackageName "$1") $(FormatAsExitcode $resultcode)"
        QPKGs.UnRestart.Add "$1"
    fi

    QPKGs.ToRestart.Remove "$1"
    QPKG.FixAppCenterStatus "$1"
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

    local -i resultcode=0
    local log_pathfile=$LOGS_PATH/$1.$START_LOG_FILE
    QPKG.ClearServiceStatus "$1"

    if QPKG.NotInstalled "$1"; then
        DebugAsWarn "unable to start $(FormatAsPackageName "$1") as it's not installed"
        QPKGs.ToStart.Remove "$1"
        QPKGs.UnStart.Add "$1"
        DebugFuncExit; return 0
    fi

    if QPKG.Enabled "$1"; then
        DebugAsWarn "unable to start $(FormatAsPackageName "$1") as it's already started"
        QPKGs.ToStart.Remove "$1"
        QPKGs.UnStart.Add "$1"
        DebugFuncExit; return 0
    fi

    QPKG.Enable "$1"
    DebugAsProc "starting $(FormatAsPackageName "$1")"

    RunAndLog "$QPKG_SERVICE_CMD start $1" "$log_pathfile"
    resultcode=$?

    if [[ $resultcode -eq 0 ]]; then
        DebugAsDone "started $(FormatAsPackageName "$1")"
        QPKG.GetServiceStatus "$1"
        QPKGs.IsStart.Add "$1"
        [[ $1 = Entware ]] && Session.AddPathToEntware
    else
        ShowAsWarn "unable to start $(FormatAsPackageName "$1") $(FormatAsExitcode $resultcode)"
        QPKGs.UnStart.Add "$1"
    fi

    QPKGs.ToStart.Remove "$1"
    QPKG.FixAppCenterStatus "$1"
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

    local -i resultcode=0
    local log_pathfile=$LOGS_PATH/$1.$STOP_LOG_FILE
    QPKG.ClearServiceStatus "$1"

    if QPKG.NotInstalled "$1"; then
        DebugAsWarn "unable to stop $(FormatAsPackageName "$1") as it's not installed"
        QPKGs.ToStop.Remove "$1"
        QPKGs.UnStop.Add "$1"
        DebugFuncExit; return 0
    fi

    DebugAsProc "stopping $(FormatAsPackageName "$1")"

    RunAndLog "$QPKG_SERVICE_CMD stop $1" "$log_pathfile"
    resultcode=$?

    if [[ $resultcode -eq 0 ]]; then
        DebugAsDone "stopped $(FormatAsPackageName "$1")"
        QPKG.GetServiceStatus "$1"
        QPKG.Disable "$1"
        QPKGs.IsStop.Add "$package"
    else
        ShowAsWarn "unable to stop $(FormatAsPackageName "$1") $(FormatAsExitcode $resultcode)"
        QPKGs.UnStop.Add "$1"
    fi

    QPKGs.ToStop.Remove "$package"
    QPKG.FixAppCenterStatus "$1"
    DebugFuncExit; return $resultcode

    }

QPKG.Enable()
    {

    # $1 = package name to enable

    DebugFuncEntry

    if [[ -z $1 ]]; then
        DebugFuncExit; return 1
    fi

    local -i resultcode=0
    local log_pathfile=$LOGS_PATH/$1.$ENABLE_LOG_FILE
    QPKG.ClearServiceStatus "$1"

    if QPKG.NotInstalled "$1"; then
        DebugAsWarn "unable to enable $(FormatAsPackageName "$1") as it's not installed"
        DebugFuncExit; return 0
    fi

    RunAndLog "$QPKG_SERVICE_CMD enable $1" "$log_pathfile"
    resultcode=$?

    if [[ $resultcode -eq 0 ]]; then
        QPKG.GetServiceStatus "$1"
        QPKGs.Enabled.Add "$1"
    else
        ShowAsWarn "unable to enable $(FormatAsPackageName "$1") $(FormatAsExitcode $resultcode)"
        QPKGs.Enabled.Remove "$1"
    fi

    QPKG.FixAppCenterStatus "$1"
    DebugFuncExit; return 0

    }

QPKG.Disable()
    {

    # $1 = package name to disable

    DebugFuncEntry

    if [[ -z $1 ]]; then
        DebugFuncExit; return 1
    fi

    local -i resultcode=0
    local log_pathfile=$LOGS_PATH/$1.$DISABLE_LOG_FILE
    QPKG.ClearServiceStatus "$1"

    if QPKG.NotInstalled "$1"; then
        DebugAsWarn "unable to disable $(FormatAsPackageName "$1") as it's not installed"
        DebugFuncExit; return 0
    fi

    RunAndLog "$QPKG_SERVICE_CMD disable $1" "$log_pathfile"
    resultcode=$?

    if [[ $resultcode -eq 0 ]]; then
        QPKG.GetServiceStatus "$1"
        QPKGs.Enabled.Remove "$1"
    else
        ShowAsWarn "unable to disable $(FormatAsPackageName "$1") $(FormatAsExitcode $resultcode)"
        QPKGs.Enabled.Add "$1"
    fi

    QPKG.FixAppCenterStatus "$1"
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

    local -i resultcode=0
    local package_init_pathfile=$(QPKG.ServicePathFile "$1")
    local log_pathfile=$LOGS_PATH/$1.$BACKUP_LOG_FILE

    DebugAsProc "backing-up $(FormatAsPackageName "$1") configuration"

    RunAndLog "$SH_CMD $package_init_pathfile backup" "$log_pathfile"
    resultcode=$?

    if [[ $resultcode -eq 0 ]]; then
        DebugAsDone "backed-up $(FormatAsPackageName "$1") configuration"
        QPKGs.IsBackup.Add "$1"
        QPKG.GetServiceStatus "$1"
    else
        DebugAsWarn "unable to backup $(FormatAsPackageName "$1") configuration $(FormatAsExitcode $resultcode)"
        QPKGs.UnBackup.Add "$1"
    fi

    QPKGs.ToBackup.Remove "$1"
    DebugFuncExit; return $resultcode

    }

QPKG.SupportsBackup()
    {

    # does this QPKG support 'backup' and 'restore' operations?

    # input:
    #   $1 = QPKG name

    # output:
    #   $? = 0 if true, 1 if false

    local package_index=0

    for package_index in "${!MANAGER_QPKG_NAME[@]}"; do
        if [[ ${MANAGER_QPKG_NAME[$package_index]} = "$1" ]]; then
            if ${MANAGER_QPKG_BACKUP_SUPPORTED[$package_index]}; then
                return 0
            else
                return 1
            fi
        fi
    done

    return 1

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

    local -i resultcode=0
    local package_init_pathfile=$(QPKG.ServicePathFile "$1")
    local log_pathfile=$LOGS_PATH/$1.$RESTORE_LOG_FILE

    DebugAsProc "restoring $(FormatAsPackageName "$1") configuration"

    RunAndLog "$SH_CMD $package_init_pathfile restore" "$log_pathfile"
    resultcode=$?

    if [[ $resultcode -eq 0 ]]; then
        DebugAsDone "restored $(FormatAsPackageName "$1") configuration"
        QPKGs.IsRestore.Add "$1"
        QPKG.GetServiceStatus "$1"
    else
        DebugAsWarn "unable to restore $(FormatAsPackageName "$1") configuration $(FormatAsExitcode $resultcode)"
        QPKGs.UnRestore.Add "$1"
    fi

    QPKGs.ToRestore.Remove "$1"
    DebugFuncExit; return $resultcode

    }

QPKG.UserInstallable()
    {

    # input:
    #   $1 = package name to check

    # output:
    #   $? = 0 (true) or 1 (false)

    [[ ${#MANAGER_QPKG_NAME[@]} -eq 0 || ${#MANAGER_QPKG_ABBRVS[@]} -eq 0 ]] && return 1

    local returncode=1
    local package_index=0

    for package_index in "${!MANAGER_QPKG_NAME[@]}"; do
        if [[ ${MANAGER_QPKG_NAME[$package_index]} = "$1" && -n ${MANAGER_QPKG_ABBRVS[$package_index]} ]]; then
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

    $GREP_CMD -q "^\[$1\]" "$APP_CENTER_CONFIG_PATHFILE"

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

    [[ $($GETCFG_CMD "$1" Enable -u -f $APP_CENTER_CONFIG_PATHFILE) = 'FALSE' ]]

    }

QPKG.Abbrvs()
    {

    # input:
    #   $1 = QPKG name

    # output:
    #   $? = 0 if successful, 1 if failed
    #   stdout = list of acceptable abbreviations that may be used to specify this package

    [[ -z $1 ]] && return 1

    local -i index=0

    for index in "${!MANAGER_QPKG_NAME[@]}"; do
        if [[ $1 = "${MANAGER_QPKG_NAME[$index]}" ]]; then
            echo "${MANAGER_QPKG_ABBRVS[$index]}"
            return 0
        fi
    done

    return 1

    }

QPKG.MatchAbbrv()
    {

    # input:
    #   $1 = a potential package abbreviation supplied by user

    # output:
    #   $? = 0 (matched) or 1 (unmatched)
    #   stdout = matched installable package name (empty if unmatched)

    local -a abbs=()
    local package_index=0
    local -i index=0
    local returncode=1

    for package_index in "${!MANAGER_QPKG_NAME[@]}"; do
        abbs=(${MANAGER_QPKG_ABBRVS[$package_index]})

        for index in "${!abbs[@]}"; do
            if [[ ${abbs[$index]} = "$1" ]]; then
                Display "${MANAGER_QPKG_NAME[$package_index]}"
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

    # KLUDGE: 'clean' QTS 4.5.1 App Center notifier status
    [[ -e $APP_CENTER_NOTIFIER ]] && $APP_CENTER_NOTIFIER --clean "$1" > /dev/null 2>&1

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
    local -i resultcode=0

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

    if [[ $resultcode -eq 0 && ${3:-} != log:failure-only ]] || [[ $resultcode -ne 0 ]]; then
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
        DebugAsWarn "$(printf "%${first_column_width}s: %${second_column_width}s\n" "$1" "$2")"
    elif [[ $3 = ' ' ]]; then           # if $3 is only a whitespace then print $2 with trailing colon and 'none' as third field
        DebugAsWarn "$(printf "%${first_column_width}s: %${second_column_width}s: none\n" "$1" "$2")"
    elif [[ ${3: -1} = ' ' ]]; then     # if $3 has a trailing whitespace then print $3 without the trailing whitespace
        DebugAsWarn "$(printf "%${first_column_width}s: %${second_column_width}s: %-s\n" "$1" "$2" "$($SED_CMD 's| *$||' <<< "$3")")"
    else
        DebugAsWarn "$(printf "%${first_column_width}s: %${second_column_width}s: %-s\n" "$1" "$2" "$3")"
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

    if [[ ${2:-} = ' ' ]]; then           # if $2 is only a whitespace then print $1 with trailing colon and 'none' as second field
        DebugThis "(II) $1: none"
    elif [[ -n ${2:-} ]]; then
        DebugThis "(II) $1: $2"
    else
        DebugThis "(II) $1"
    fi

    }

DebugAsWarn()
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

    ShowAsProc "$1 (this may take a while)" "${2:-}"

    }

ShowAsProc()
    {

    local suffix=''

    [[ -n ${2:-} ]] && suffix=" $2"

    SmartCR
    WriteToDisplay.Wait "$(ColourTextBrightOrange proc)" "$1 ...$suffix"
    WriteToLog proc "$1 ...$suffix"
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

ShowAsOperationProgress()
    {

    # show QPKG operations progress as percent-complete and a fraction of the total

    # $1 = tier (optional)
    # $2 = total count
    # $3 = fail count
    # $4 = pass count
    # $5 = action message (present-tense)
    # $6 = 'long' (optional)

    [[ -z $2 || -z $3 || -z $4 || -z $5 ]] && return 1
    [[ $2 -eq 0 ]] && return 1                  # zero total, so let's get out of here

    local tier=''
    local total=$2
    local fails=$3
    local passes=$4
    local tweaked_passes=$((passes+1))          # so we never show zero (e.g. 0/8)
    local tweaked_total=$((total-fails))        # auto-adjust upper limit to account for failures

    [[ $tweaked_total -eq 0 ]] && return 1      # no-point showing a fraction of zero

    if [[ -n $1 && $1 != all ]]; then
        tier=" $1"
    else
        tier=''
    fi

    if [[ $tweaked_passes -gt $tweaked_total ]]; then
        tweaked_passes=$((tweaked_total-fails))
        percent='100%'
    else
        percent="$((200*(tweaked_passes)/(tweaked_total+1) % 2 + 100*(tweaked_passes)/(tweaked_total+1)))%"
    fi

    if [[ $6 = long ]]; then
        ShowAsProcLong "$5 ${tweaked_total}${tier} QPKG$(FormatAsPlural "$tweaked_total")" "$percent ($tweaked_passes/$tweaked_total)"
    else
        ShowAsProc "$5 ${tweaked_total}${tier} QPKG$(FormatAsPlural "$tweaked_total")" "$percent ($tweaked_passes/$tweaked_total)"
    fi

    [[ $percent = '100%' ]] && sleep 1

    return 0

    }

ShowAsOperationResult()
    {

    # $1 = tier (optional)
    # $2 = total package count
    # $3 = fail count
    # $4 = pass count
    # $5 = action message (past-tense)
    # $6 = 'long' (optional)

    [[ -z $2 || -z $3 || -z $4 || -z $5 ]] && return 1
    [[ $2 -eq 0 ]] && return 1                  # zero total, so let's get out of here

    local tier=''
    local -i total=$2
    local -i fails=$3
    local -i passes=$4

    # execute with passes > total to trigger 100% message
    ShowAsOperationProgress "$1" "$total" "$fails" "$((passes+1))" "$ACTION_PRESENT" "$6"

    if [[ -n $1 && $1 != all ]]; then
        tier=" $1"
    else
        tier=''
    fi

    if [[ $passes -eq 0 ]]; then
        ShowAsFail "$5 ${fails}${tier} QPKG$(FormatAsPlural "$3") failed"
    elif [[ $fails -gt 0 ]]; then
        ShowAsWarn "$5 ${passes}${tier} QPKG$(FormatAsPlural "$passes") OK, but ${fails}${tier} QPKG$(FormatAsPlural "$fails") failed"
    elif [[ $passes -gt 0 ]]; then
        ShowAsDone "$5 ${passes}${tier} QPKG$(FormatAsPlural "$passes") OK"
    else
        DebugAsDone "no${tier} QPKGs processed"
    fi

    return 0

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

    [[ ${previous_msg:-_none_} = _none_ ]] && previous_msg=''

    this_message=$(printf "%-10s: %s" "$1" "$2")

    if [[ $this_message != "${previous_msg}" ]]; then
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

    [[ -z ${DEBUG_LOG_PATHFILE:-} ]] && return 1
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

ColourTextBrightRedBlink()
    {

    echo -en '\033[1;5;31m'"$(ColourReset "$1")"

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

Objects.Add.List()
    {

    # $1: object name to create

    local public_function_name=$1
    local safe_function_name="$(tr 'A-Z' 'a-z' <<< "${public_function_name//[.-]/_}")"

    _placeholder_array_=_object_${safe_function_name}_array_
    _placeholder_array_index_=_object_${safe_function_name}_array_index_

echo $public_function_name'.Add()
    {
    local array=(${1})
    local item='\'\''
    for item in "${array[@]:-}"; do
        [[ " ${'$_placeholder_array_'[*]:-} " != *"$item"* ]] && '$_placeholder_array_'+=("$item")
    done
    }
'$public_function_name'.Array()
    {
    echo -n "${'$_placeholder_array_'[@]:-}"
    }
'$public_function_name'.Count()
    {
    echo "${#'$_placeholder_array_'[@]:-}"
    }
'$public_function_name'.Exist()
    {
    [[ ${'$_placeholder_array_'[*]:-} == *"$1"* ]]
    }
'$public_function_name'.First()
    {
    echo "${'$_placeholder_array_'[0]}"
    }
'$public_function_name'.GetItem()
    {
    local -i index="$1"
    [[ $index -lt 1 ]] && index=1
    [[ $index -gt ${#'$_placeholder_array_'[@]:-} ]] && index=${#'$_placeholder_array_'[@]}
    echo -n "${'$_placeholder_array_'[((index-1))]}"
    }
'$public_function_name'.Init()
    {
    '$_placeholder_array_'=()
    '$_placeholder_array_index_'=1
    }
'$public_function_name'.IsAny()
    {
    [[ ${#'$_placeholder_array_'[@]:-} -gt 0 ]]
    }
'$public_function_name'.IsNone()
    {
    [[ ${#'$_placeholder_array_'[@]:-} -eq 0 ]]
    }
'$public_function_name'.List()
    {
    echo -n "${'$_placeholder_array_'[*]:-}"
    }
'$public_function_name'.ListCSV()
    {
    echo -n "${'$_placeholder_array_'[*]:-}" | tr '\' \'' '\',\''
    }
'$public_function_name'.Remove()
    {
    local argument_array=(${1})
    local temp_array=()
    local argument='\'\''
    local item='\'\''
    local matched=false
    for item in "${'$_placeholder_array_'[@]:-}"; do
        matched=false
        for argument in "${argument_array[@]:-}"; do
            if [[ $argument = $item ]]; then
                matched=true; break
            fi
        done
        [[ $matched = false ]] && temp_array+=("$item")
    done
    '$_placeholder_array_'=("${temp_array[@]:-}")
    [[ -z ${'$_placeholder_array_'[*]} ]] && '$_placeholder_array_'=()
    }
'$public_function_name'.Init
' >> "$COMPILED_OBJECTS_PATHFILE"

    return 0

    }

Objects.Add.Flag()
    {

    # $1: object name to create

    local public_function_name=$1
    local safe_function_name="$(tr 'A-Z' 'a-z' <<< "${public_function_name//[.-]/_}")"

    _placeholder_size_=_object_${safe_function_name}_size_
    _placeholder_text_=_object_${safe_function_name}_text_
    _placeholder_flag_=_object_${safe_function_name}_flag_
    _placeholder_log_changes_flag_=_object_${safe_function_name}_changes_flag_
    _placeholder_enable_=_object_${safe_function_name}_enable_
    _placeholder_path_=_object_${safe_function_name}_path_

echo $public_function_name'.Clear()
    {
    [[ $'$_placeholder_flag_' != '\'true\'' ]] && return
    '$_placeholder_flag_'=false
    [[ $'$_placeholder_log_changes_flag_' = '\'true\'' ]] && DebugVar '$_placeholder_flag_'
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
'$public_function_name'.Init()
    {
    '$_placeholder_size_'=0
    '$_placeholder_text_'='\'\''
    '$_placeholder_flag_'=false
    '$_placeholder_log_changes_flag_'=true
    '$_placeholder_enable_'=false
    '$_placeholder_path_'='\'\''
    }
'$public_function_name'.IsDisabled()
    {
    [[ $'$_placeholder_enable_' != '\'true\'' ]]
    }
'$public_function_name'.IsEnabled()
    {
    [[ $'$_placeholder_enable_' = '\'true\'' ]]
    }
'$public_function_name'.IsNot()
    {
    [[ $'$_placeholder_flag_' != '\'true\'' ]]
    }
'$public_function_name'.IsSet()
    {
    [[ $'$_placeholder_flag_' = '\'true\'' ]]
    }
'$public_function_name'.LogChanges()
    {
    [[ $'$_placeholder_log_changes_flag_' = '\'true\'' ]] && return
    '$_placeholder_log_changes_flag_'=true
    }
'$public_function_name'.Path()
    {
    if [[ -n ${1:-} && ${1:-} = "=" ]]; then
        '$_placeholder_path_'=$2
    else
        echo -n "$'$_placeholder_path_'"
    fi
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

    [[ -e $COMPILED_OBJECTS_PATHFILE ]] && ! FileMatchesMD5 "$COMPILED_OBJECTS_PATHFILE" "$(Objects.Compile hash)" && rm -f "$COMPILED_OBJECTS_PATHFILE"

    }

Objects.CheckRemote()
    {

    [[ ! -e $COMPILED_OBJECTS_PATHFILE ]] && ! $CURL_CMD${curl_insecure_arg:-} --silent --fail "$COMPILED_OBJECTS_URL" > "$COMPILED_OBJECTS_PATHFILE" && [[ ! -s $COMPILED_OBJECTS_PATHFILE ]] && rm -f "$COMPILED_OBJECTS_PATHFILE"

    }

Objects.Compile()
    {

    # builds a new [compiled.objects] file in the work path

    # $1 = 'hash' (optional) - if specified, only return the internal checksum

    local -r COMPILED_OBJECTS_HASH=e1bdff15c65f6f259fb8963f30158825

    if [[ ${1:-} = hash ]]; then
        echo "$COMPILED_OBJECTS_HASH"
        return
    fi

    Objects.CheckLocal
    Objects.CheckRemote
    Objects.CheckLocal

    if [[ ! -e $COMPILED_OBJECTS_PATHFILE ]]; then
        ShowAsProc 'compiling objects' >&2

        # session flags
        Objects.Add.Flag Session.Backup
        Objects.Add.Flag Session.Debug.To.File
        Objects.Add.Flag Session.Debug.To.Screen
        Objects.Add.Flag Session.Display.Clean
        Objects.Add.Flag Session.IPKGs.Install
        Objects.Add.Flag Session.LineSpace
        Objects.Add.Flag Session.Lists.Built
        Objects.Add.Flag Session.PIPs.Install
        Objects.Add.Flag Session.ShowBackupLocation
        Objects.Add.Flag Session.SkipPackageProcessing
        Objects.Add.Flag Session.SuggestIssue
        Objects.Add.Flag Session.Summary

        # user-selected option flags
        Objects.Add.Flag User.Opts.Help.Abbreviations
        Objects.Add.Flag User.Opts.Help.Actions
        Objects.Add.Flag User.Opts.Help.ActionsAll
        Objects.Add.Flag User.Opts.Help.Basic
        Objects.Add.Flag User.Opts.Help.Options
        Objects.Add.Flag User.Opts.Help.Packages
        Objects.Add.Flag User.Opts.Help.Problems
        Objects.Add.Flag User.Opts.Help.Tips

        Objects.Add.Flag User.Opts.Clean
        Objects.Add.Flag User.Opts.Dependencies.Check
        Objects.Add.Flag User.Opts.IgnoreFreeSpace
        Objects.Add.Flag User.Opts.Versions.View

        Objects.Add.Flag User.Opts.Log.Last.Paste
        Objects.Add.Flag User.Opts.Log.Last.View
        Objects.Add.Flag User.Opts.Log.Tail.Paste
        Objects.Add.Flag User.Opts.Log.Whole.View

        Objects.Add.Flag User.Opts.Apps.All.Backup
        Objects.Add.Flag User.Opts.Apps.All.Install
        Objects.Add.Flag User.Opts.Apps.All.Reinstall
        Objects.Add.Flag User.Opts.Apps.All.Restart
        Objects.Add.Flag User.Opts.Apps.All.Restore
        Objects.Add.Flag User.Opts.Apps.All.Start
        Objects.Add.Flag User.Opts.Apps.All.Status
        Objects.Add.Flag User.Opts.Apps.All.Stop
        Objects.Add.Flag User.Opts.Apps.All.Uninstall
        Objects.Add.Flag User.Opts.Apps.All.Upgrade

        Objects.Add.Flag User.Opts.Apps.List.All
        Objects.Add.Flag User.Opts.Apps.List.Backups
        Objects.Add.Flag User.Opts.Apps.List.Essential
        Objects.Add.Flag User.Opts.Apps.List.Installed
        Objects.Add.Flag User.Opts.Apps.List.NotInstalled
        Objects.Add.Flag User.Opts.Apps.List.Optional
        Objects.Add.Flag User.Opts.Apps.List.Standalone
        Objects.Add.Flag User.Opts.Apps.List.Started
        Objects.Add.Flag User.Opts.Apps.List.Stopped
        Objects.Add.Flag User.Opts.Apps.List.Upgradable

        # lists
        Objects.Add.List Args.Unknown

        Objects.Add.List IPKGs.ToDownload
        Objects.Add.List IPKGs.ToInstall
        Objects.Add.List IPKGs.ToUninstall

        Objects.Add.List QPKGs.Disabled
        Objects.Add.List QPKGs.Enabled
        Objects.Add.List QPKGs.Essential
        Objects.Add.List QPKGs.Installable
        Objects.Add.List QPKGs.Installed
        Objects.Add.List QPKGs.Missing
        Objects.Add.List QPKGs.Names
        Objects.Add.List QPKGs.NotInstalled
        Objects.Add.List QPKGs.NotSupportsBackup
        Objects.Add.List QPKGs.Optional
        Objects.Add.List QPKGs.Standalone
        Objects.Add.List QPKGs.SupportsBackup
        Objects.Add.List QPKGs.Upgradable

        # these lists contain package names to operate on
        Objects.Add.List QPKGs.ToBackup
        Objects.Add.List QPKGs.ToDownload
        Objects.Add.List QPKGs.ToInstall
        Objects.Add.List QPKGs.ToReinstall
        Objects.Add.List QPKGs.ToRestart
        Objects.Add.List QPKGs.ToRestore
        Objects.Add.List QPKGs.ToStart
        Objects.Add.List QPKGs.ToStatus
        Objects.Add.List QPKGs.ToStop
        Objects.Add.List QPKGs.ToUninstall
        Objects.Add.List QPKGs.ToUpgrade

        # these lists contain package names where the operation was successful
        Objects.Add.List QPKGs.IsBackup
        Objects.Add.List QPKGs.IsDownload
        Objects.Add.List QPKGs.IsInstall
        Objects.Add.List QPKGs.IsReinstall
        Objects.Add.List QPKGs.IsRestart
        Objects.Add.List QPKGs.IsRestore
        Objects.Add.List QPKGs.IsStart
        Objects.Add.List QPKGs.IsStatus
        Objects.Add.List QPKGs.IsStop
        Objects.Add.List QPKGs.IsUninstall
        Objects.Add.List QPKGs.IsUpgrade

        # these lists contain package names where the operation failed
        Objects.Add.List QPKGs.UnBackup
        Objects.Add.List QPKGs.UnDownload
        Objects.Add.List QPKGs.UnInstall
        Objects.Add.List QPKGs.UnReinstall
        Objects.Add.List QPKGs.UnRestart
        Objects.Add.List QPKGs.UnRestore
        Objects.Add.List QPKGs.UnStart
        Objects.Add.List QPKGs.UnStatus
        Objects.Add.List QPKGs.UnStop
        Objects.Add.List QPKGs.UnUninstall
        Objects.Add.List QPKGs.UnUpgrade
    fi

    . "$COMPILED_OBJECTS_PATHFILE"

    return 0

    }

Session.Init || exit 1
Session.Validate
Tiers.Processor
Session.Results
Session.Error.IsNot
