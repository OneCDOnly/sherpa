#!/usr/bin/env bash
#
# sherpa.manager.sh - (C)opyright (C) 2017-2021 OneCD [one.cd.only@gmail.com]
#
# This is the management script for the sherpa mini-package-manager.
# It's automatically downloaded via the 'sherpa.loader.sh' script in the 'sherpa' QPKG.
#
# So, blame OneCD if it all goes horribly wrong. ;)
#
# project: https://git.io/sherpa
# forum: https://forum.qnap.com/viewtopic.php?f=320&t=132373
#
# Tested on:
#  GNU bash, version 3.2.57(2)-release (i686-pc-linux-gnu)
#  GNU bash, version 3.2.57(1)-release (aarch64-QNAP-linux-gnu)
#  Copyright (C) 2007 Free Software Foundation, Inc.
#
# ... and periodically on:
#  GNU bash, version 5.0.17(1)-release (aarch64-openwrt-linux-gnu)
#  Copyright (C) 2019 Free Software Foundation, Inc.
#
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/
#
# Project variable and function naming style-guide:
#             functions: CamelCase
#  background functions: _CamelCaseWithLeadingAndTrailingUnderscores_
#             variables: lowercase_with_inline_underscores
#      "object" methods: Capitalised.CamelCase.With.Inline.Periods
#   "object" properties: _lowercase_with_leading_and_inline_and_trailing_underscores_ (these should ONLY be managed via the object's methods)
#             constants: UPPERCASE_WITH_INLINE_UNDERSCORES (also set as readonly)
#               indents: 1 x tab (converted to 4 x spaces to suit GitHub web-display)
#
# Notes:
#   If on-screen line-spacing is required, this should only be done by the next function that outputs to display.
#   Display functions should never finish by putting an empty line on-screen for spacing.

set -o nounset
set -o pipefail
#set -o errexit

readonly USER_ARGS_RAW=$*

Session.Init()
    {

    IsQNAP || return
    DebugFuncEntry

    readonly SCRIPT_STARTSECONDS=$(/bin/date +%s)
    export LC_CTYPE=C

    readonly PROJECT_NAME=sherpa
    local -r SCRIPT_VERSION=210414
    readonly PROJECT_BRANCH=main

    ClaimLockFile /var/run/$PROJECT_NAME.loader.sh.pid || return

    # cherry-pick required binaries
    readonly AWK_CMD=/bin/awk
    readonly CAT_CMD=/bin/cat
    readonly DATE_CMD=/bin/date
    readonly GREP_CMD=/bin/grep
    readonly MD5SUM_CMD=/bin/md5sum
    readonly SED_CMD=/bin/sed
    readonly SH_CMD=/bin/sh
    readonly SLEEP_CMD=/bin/sleep
    readonly TOUCH_CMD=/bin/touch
    readonly UNAME_CMD=/bin/uname
    readonly UNIQ_CMD=/bin/uniq

    readonly CURL_CMD=/sbin/curl

    readonly BASENAME_CMD=/usr/bin/basename
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

    # check required binaries are present
    IsSysFileExist $AWK_CMD || return
    IsSysFileExist $CAT_CMD || return
    IsSysFileExist $DATE_CMD || return
    IsSysFileExist $GREP_CMD || return
    IsSysFileExist $MD5SUM_CMD || return
    IsSysFileExist $SED_CMD || return
    IsSysFileExist $SH_CMD || return
    IsSysFileExist $SLEEP_CMD || return
    IsSysFileExist $TOUCH_CMD || return
    IsSysFileExist $UNAME_CMD || return
    IsSysFileExist $UNIQ_CMD || return

    IsSysFileExist $CURL_CMD || return

    [[ ! -e $SORT_CMD ]] && ln -s /bin/busybox "$SORT_CMD"  # sometimes, 'sort' goes missing from QTS. Don't know why.
    [[ ! -e /dev/fd ]] && ln -s /proc/self/fd /dev/fd       # sometimes, '/dev/fd' isn't created by QTS. Don't know why.

    IsSysFileExist $BASENAME_CMD || return
    IsSysFileExist $DIRNAME_CMD || return
    IsSysFileExist $DU_CMD || return
    IsSysFileExist $HEAD_CMD || return
    IsSysFileExist $READLINK_CMD || return
    IsSysFileExist $TAIL_CMD || return
    IsSysFileExist $TEE_CMD || return
    IsSysFileExist $UNZIP_CMD || return
    IsSysFileExist $UPTIME_CMD || return
    IsSysFileExist $WC_CMD || return

    readonly GNU_FIND_CMD=/opt/bin/find
    readonly GNU_GREP_CMD=/opt/bin/grep
    readonly GNU_SED_CMD=/opt/bin/sed

    readonly BACKUP_LOG_FILE=backup.log
    readonly DEBUG_LOG_FILE=debug.log
    readonly DISABLE_LOG_FILE=disable.log
    readonly DOWNLOAD_LOG_FILE=download.log
    readonly ENABLE_LOG_FILE=enable.log
    readonly INSTALL_LOG_FILE=install.log
    readonly REINSTALL_LOG_FILE=reinstall.log
    readonly RESTART_LOG_FILE=restart.log
    readonly RESTORE_LOG_FILE=restore.log
    readonly START_LOG_FILE=start.log
    readonly STOP_LOG_FILE=stop.log
    readonly UNINSTALL_LOG_FILE=uninstall.log
    readonly UPDATE_LOG_FILE=update.log
    readonly UPGRADE_LOG_FILE=upgrade.log

    local -r PROJECT_PATH=$(/sbin/getcfg $PROJECT_NAME Install_Path -f /etc/config/qpkg.conf)
    readonly WORK_PATH=$PROJECT_PATH/cache
    readonly LOGS_PATH=$PROJECT_PATH/logs
    readonly QPKG_DL_PATH=$WORK_PATH/qpkgs
    readonly IPKG_DL_PATH=$WORK_PATH/ipkgs.downloads
    readonly IPKG_CACHE_PATH=$WORK_PATH/ipkgs
    readonly PIP_CACHE_PATH=$WORK_PATH/pips
    readonly BACKUP_PATH=$(/sbin/getcfg SHARE_DEF defVolMP -f /etc/config/def_share.info)/.qpkg_config_backup

    readonly COMPILED_OBJECTS_URL=https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/$PROJECT_BRANCH/compiled.objects.tar.gz
    readonly EXTERNAL_PACKAGE_ARCHIVE_PATHFILE=/opt/var/opkg-lists/entware
    readonly PREVIOUS_OPKG_PACKAGE_LIST=$WORK_PATH/opkg.prev.installed.list
    readonly PREVIOUS_PIP_MODULE_LIST=$WORK_PATH/pip.prev.installed.list

    readonly COMPILED_OBJECTS_ARCHIVE_PATHFILE=$WORK_PATH/compiled.objects.tar.gz
    readonly COMPILED_OBJECTS_PATHFILE=$WORK_PATH/compiled.objects
    readonly SESSION_ARCHIVE_PATHFILE=$LOGS_PATH/session.archive.log
    readonly SESSION_ACTIVE_PATHFILE=$PROJECT_PATH/session.$$.active.log
    readonly SESSION_LAST_PATHFILE=$LOGS_PATH/session.last.log
    readonly SESSION_TAIL_PATHFILE=$LOGS_PATH/session.tail.log
    readonly EXTERNAL_PACKAGE_LIST_PATHFILE=$WORK_PATH/Packages

    PACKAGE_SCOPES=(All Dependent HasDependents Installable Names Standalone SupportBackup SupportUpdateOnRestart Upgradable)
    PACKAGE_STATES=(BackedUp Downloaded Installed Missing Starting Started Stopping Stopped Restarting)
    PACKAGE_OPERATIONS=(Backup Download Install Rebuild Reinstall Restart Restore Start Stop Uninstall Upgrade)
    PACKAGE_TIERS=(Standalone Addon Dependent)

    readonly PACKAGE_SCOPES
    readonly PACKAGE_STATES
    readonly PACKAGE_OPERATIONS
    readonly PACKAGE_TIERS

    if ! MakePath "$WORK_PATH" work; then
        DebugFuncExit 1; return
    fi

    if ! MakePath "$LOGS_PATH" logs; then
        DebugFuncExit 1; return
    fi

    [[ -d $IPKG_DL_PATH ]] && rm -rf "$IPKG_DL_PATH"
    [[ -d $IPKG_CACHE_PATH ]] && rm -rf "$IPKG_CACHE_PATH"
    [[ -d $PIP_CACHE_PATH ]] && rm -rf "$PIP_CACHE_PATH"

    if ! MakePath "$QPKG_DL_PATH" 'QPKG download'; then
        DebugFuncExit 1; return
    fi

    if ! MakePath "$IPKG_DL_PATH" 'IPKG download'; then
        DebugFuncExit 1; return
    fi

    if ! MakePath "$IPKG_CACHE_PATH" 'IPKG cache'; then
        DebugFuncExit 1; return
    fi

    if ! MakePath "$PIP_CACHE_PATH" 'PIP cache'; then
        DebugFuncExit 1; return
    fi

    if ! MakePath "$BACKUP_PATH" 'QPKG backup'; then
        DebugFuncExit 1; return
    fi

    ArchivePriorSessionLogs

    if [[ $USER_ARGS_RAW == *"reset"* ]]; then
        ResetArchivedLogs
        ResetWorkPath
        ArchiveActiveSessionLog
        ResetActiveSessionLog
        exit 0
    elif [[ $USER_ARGS_RAW == *"clean"* ]]; then
        CleanManagementScript
        exit 0
    fi

    CompileObjects
    Session.Debug.ToArchive.Set
    Session.Debug.ToFile.Set

    if [[ $USER_ARGS_RAW == *"debug"* || $USER_ARGS_RAW == *"dbug"* || $USER_ARGS_RAW == *"verbose"* ]]; then
        Display >&2
        Session.Debug.ToScreen.Set
    fi

    readonly PACKAGE_VERSION=$(QPKG.Local.Version "$PROJECT_NAME")
    readonly MANAGER_SCRIPT_VERSION="$SCRIPT_VERSION$([[ $PROJECT_BRANCH = develop ]] && echo '(d)')"

    DebugInfoMajorSeparator
    DebugScript started "$($DATE_CMD -d @"$SCRIPT_STARTSECONDS" | tr -s ' ')"
    DebugScript version "package: ${PACKAGE_VERSION:-unknown}, manager: ${MANAGER_SCRIPT_VERSION:-unknown}, loader: ${LOADER_SCRIPT_VERSION:-unknown}"
    DebugScript PID "$$"
    DebugInfoMinorSeparator
    DebugInfo 'Markers: (**) detected, (II) information, (WW) warning, (EE) error, (LL) log file, (--) processing,'
    DebugInfo '(==) done, (>>) f entry, (<<) f exit, (vv) variable name & value, ($1) positional argument value'
    DebugInfoMinorSeparator

    Opts.IgFreeSpace.Text = ' --force-space'
    Session.Summary.Set
    Session.LineSpace.NoLogMods
    QPKGs.SkProc.NoLogMods

    readonly NAS_FIRMWARE=$(/sbin/getcfg System Version -f /etc/config/uLinux.conf)
    readonly NAS_BUILD=$(/sbin/getcfg System 'Build Number' -f /etc/config/uLinux.conf)
    readonly INSTALLED_RAM_KB=$($GREP_CMD MemTotal /proc/meminfo | cut -f2 -d':' | $SED_CMD 's|kB||;s| ||g')
    readonly LOG_TAIL_LINES=3000    # a full download and install of everything generates a session around 1600 lines, but include a bunch of opkg updates and it can get much longer
    readonly MIN_PYTHON_VER=392
    code_pointer=0
    pip3_cmd=/opt/bin/pip3
    previous_msg=' '
    [[ ${NAS_FIRMWARE//.} -lt 426 ]] && curl_insecure_arg=' --insecure' || curl_insecure_arg=''
    CalcEntwareType
    CalcQPKGArch

    # supported package details - parallel arrays
    MANAGER_QPKG_NAME=()                    # internal QPKG name
        MANAGER_QPKG_ARCH=()                # QPKG supports this architecture. Use 'all' if every arch is supported
        MANAGER_QPKG_MIN_RAM_KB=()          # QPKG requires at-least this much RAM installed in kB. Use 'any' if any amount is OK
        MANAGER_QPKG_VERSION=()             # QPKG version
        MANAGER_QPKG_URL=()                 # remote QPKG URL
        MANAGER_QPKG_MD5=()                 # remote QPKG MD5
        MANAGER_QPKG_DESC+=()               # QPKG description (applies to all packages with the same name)
        MANAGER_QPKG_ABBRVS=()              # if set, this package is user-installable, and these abbreviations may be used to specify app
        MANAGER_QPKG_DEPENDS_ON=()          # require these QPKGs to be installed first. Use '' if package is standalone
        MANAGER_QPKG_DEPENDED_UPON=()       # true/false: this QPKG is depended-upon by other QPKGs
        MANAGER_QPKG_IPKGS_ADD=()           # require these IPKGs to be installed first
        MANAGER_QPKG_IPKGS_REMOVE=()        # require these IPKGs to be uninstalled first
        MANAGER_QPKG_SUPPORTS_BACKUP=()     # true/false: this QPKG supports configuration 'backup' and 'restore' operations
        MANAGER_QPKG_RESTART_TO_UPDATE=()   # true/false: the internal appplication can be updated by restarting the QPKG

    # pseudo-alpha-sorted name order (i.e. disregard character-case and leading 'O')
    MANAGER_QPKG_NAME+=(ClamAV)
        MANAGER_QPKG_ARCH+=(all)
        MANAGER_QPKG_MIN_RAM_KB+=(1572864)
        MANAGER_QPKG_VERSION+=(210409)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/$PROJECT_BRANCH/QPKGs/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/build/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}.qpkg)
        MANAGER_QPKG_MD5+=(b52b3fcfe429320aea1fcad0dfe68a7b)
        MANAGER_QPKG_DESC+=('replacement for the QTS built-in ClamAV (requires a minimum of 1.5GiB installed RAM)')
        MANAGER_QPKG_ABBRVS+=('av clam clamscan freshclam clamav')
        MANAGER_QPKG_DEPENDS_ON+=(Entware)
        MANAGER_QPKG_DEPENDED_UPON+=(false)
        MANAGER_QPKG_IPKGS_ADD+=('clamav freshclam')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_SUPPORTS_BACKUP+=(false)
        MANAGER_QPKG_RESTART_TO_UPDATE+=(false)

    MANAGER_QPKG_NAME+=(Deluge-server)
        MANAGER_QPKG_ARCH+=(all)
        MANAGER_QPKG_MIN_RAM_KB+=(any)
        MANAGER_QPKG_VERSION+=(210331)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/$PROJECT_BRANCH/QPKGs/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/build/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}.qpkg)
        MANAGER_QPKG_MD5+=(d9b560217201171d188da06420344eb8)
        MANAGER_QPKG_DESC+=('Deluge BitTorrent daemon')
        MANAGER_QPKG_ABBRVS+=('dl deluge del-server deluge-server')
        MANAGER_QPKG_DEPENDS_ON+=(Entware)
        MANAGER_QPKG_DEPENDED_UPON+=(false)
        MANAGER_QPKG_IPKGS_ADD+=('deluge jq')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_SUPPORTS_BACKUP+=(true)
        MANAGER_QPKG_RESTART_TO_UPDATE+=(false)

    MANAGER_QPKG_NAME+=(Deluge-web)
        MANAGER_QPKG_ARCH+=(all)
        MANAGER_QPKG_MIN_RAM_KB+=(any)
        MANAGER_QPKG_VERSION+=(210331)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/$PROJECT_BRANCH/QPKGs/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/build/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}.qpkg)
        MANAGER_QPKG_MD5+=(060dcdf82dcaab7e8d320060ea11ce19)
        MANAGER_QPKG_DESC+=('web UI to access multiple Deluge BitTorrent daemons')
        MANAGER_QPKG_ABBRVS+=('dw del-web deluge-web')
        MANAGER_QPKG_DEPENDS_ON+=(Entware)
        MANAGER_QPKG_DEPENDED_UPON+=(false)
        MANAGER_QPKG_IPKGS_ADD+=('deluge-ui-web jq')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_SUPPORTS_BACKUP+=(true)
        MANAGER_QPKG_RESTART_TO_UPDATE+=(false)

    MANAGER_QPKG_NAME+=(duf)
        MANAGER_QPKG_ARCH+=(a64)
        MANAGER_QPKG_MIN_RAM_KB+=(any)
        MANAGER_QPKG_VERSION+=(210412)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/main/build/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}_arm_64.qpkg)
        MANAGER_QPKG_MD5+=(821bee2dee7e36b2c1226bfce08fdad9)
        MANAGER_QPKG_DESC+=('a nice CLI disk-usage/free-space utility from @muesli')
        MANAGER_QPKG_ABBRVS+=('df duf')
        MANAGER_QPKG_DEPENDS_ON+=('')
        MANAGER_QPKG_DEPENDED_UPON+=(false)
        MANAGER_QPKG_IPKGS_ADD+=('')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_SUPPORTS_BACKUP+=(false)
        MANAGER_QPKG_RESTART_TO_UPDATE+=(false)

    MANAGER_QPKG_NAME+=(duf)
        MANAGER_QPKG_ARCH+=(x41)
        MANAGER_QPKG_MIN_RAM_KB+=(any)
        MANAGER_QPKG_VERSION+=(210412)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/main/build/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}_arm-x41.qpkg)
        MANAGER_QPKG_MD5+=(8c76dd6081108a2a93a1201252a7daa7)
        MANAGER_QPKG_DESC+=('a nice CLI disk-usage/free-space utility from @muesli')
        MANAGER_QPKG_ABBRVS+=('df duf')
        MANAGER_QPKG_DEPENDS_ON+=('')
        MANAGER_QPKG_DEPENDED_UPON+=(false)
        MANAGER_QPKG_IPKGS_ADD+=('')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_SUPPORTS_BACKUP+=(false)
        MANAGER_QPKG_RESTART_TO_UPDATE+=(false)

    MANAGER_QPKG_NAME+=(duf)
        MANAGER_QPKG_ARCH+=(x86)
        MANAGER_QPKG_MIN_RAM_KB+=(any)
        MANAGER_QPKG_VERSION+=(210412)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/main/build/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}_x86.qpkg)
        MANAGER_QPKG_MD5+=(5f84222a2089c5e89201eaa0b396b84c)
        MANAGER_QPKG_DESC+=('a nice CLI disk-usage/free-space utility from @muesli')
        MANAGER_QPKG_ABBRVS+=('df duf')
        MANAGER_QPKG_DEPENDS_ON+=('')
        MANAGER_QPKG_DEPENDED_UPON+=(false)
        MANAGER_QPKG_IPKGS_ADD+=('')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_SUPPORTS_BACKUP+=(false)
        MANAGER_QPKG_RESTART_TO_UPDATE+=(false)

    MANAGER_QPKG_NAME+=(duf)
        MANAGER_QPKG_ARCH+=(x64)
        MANAGER_QPKG_MIN_RAM_KB+=(any)
        MANAGER_QPKG_VERSION+=(210412)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/main/build/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}_x86_64.qpkg)
        MANAGER_QPKG_MD5+=(093032880ed6b60fbeb033e28a3300be)
        MANAGER_QPKG_DESC+=('a nice CLI disk-usage/free-space utility from @muesli')
        MANAGER_QPKG_ABBRVS+=('df duf')
        MANAGER_QPKG_DEPENDS_ON+=('')
        MANAGER_QPKG_DEPENDED_UPON+=(false)
        MANAGER_QPKG_IPKGS_ADD+=('')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_SUPPORTS_BACKUP+=(false)
        MANAGER_QPKG_RESTART_TO_UPDATE+=(false)

    MANAGER_QPKG_NAME+=(Entware)
        MANAGER_QPKG_ARCH+=(all)
        MANAGER_QPKG_MIN_RAM_KB+=(any)
        MANAGER_QPKG_VERSION+=(1.03)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/$PROJECT_BRANCH/QPKGs/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}std.qpkg)
        MANAGER_QPKG_MD5+=(da2d9f8d3442dd665ce04b9b932c9d8e)
        MANAGER_QPKG_DESC+=("provides the 'opkg' command: the OpenWRT package manager")
        MANAGER_QPKG_ABBRVS+=('ew ent opkg entware')
        MANAGER_QPKG_DEPENDS_ON+=('')
        MANAGER_QPKG_DEPENDED_UPON+=(true)
        MANAGER_QPKG_IPKGS_ADD+=('')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_SUPPORTS_BACKUP+=(false)
        MANAGER_QPKG_RESTART_TO_UPDATE+=(false)

    MANAGER_QPKG_NAME+=(HideThatBanner)
        MANAGER_QPKG_ARCH+=(all)
        MANAGER_QPKG_MIN_RAM_KB+=(any)
        MANAGER_QPKG_VERSION+=(201219b)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/main/build/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}.qpkg)
        MANAGER_QPKG_MD5+=(d576993ca2c6ec7585abe24455e19385)
        MANAGER_QPKG_DESC+=('hides the annoying rotating banner at the top of QTS App Center pages')
        MANAGER_QPKG_ABBRVS+=('hb htb hide hidebanner hidethatbanner')
        MANAGER_QPKG_DEPENDS_ON+=('')
        MANAGER_QPKG_DEPENDED_UPON+=(false)
        MANAGER_QPKG_IPKGS_ADD+=('')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_SUPPORTS_BACKUP+=(false)
        MANAGER_QPKG_RESTART_TO_UPDATE+=(false)

    MANAGER_QPKG_NAME+=(LazyLibrarian)
        MANAGER_QPKG_ARCH+=(all)
        MANAGER_QPKG_MIN_RAM_KB+=(any)
        MANAGER_QPKG_VERSION+=(210318)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/$PROJECT_BRANCH/QPKGs/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/build/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}.qpkg)
        MANAGER_QPKG_MD5+=(aa35dab8b3043741da42deab2dc68d74)
        MANAGER_QPKG_DESC+=('follow authors and grab metadata for all your digital reading needs')
        MANAGER_QPKG_ABBRVS+=('ll lazy lazylibrarian')
        MANAGER_QPKG_DEPENDS_ON+=(Entware)
        MANAGER_QPKG_DEPENDED_UPON+=(false)
        MANAGER_QPKG_IPKGS_ADD+=('python3-pyopenssl python3-requests')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_SUPPORTS_BACKUP+=(true)
        MANAGER_QPKG_RESTART_TO_UPDATE+=(true)

    MANAGER_QPKG_NAME+=(OMedusa)
        MANAGER_QPKG_ARCH+=(all)
        MANAGER_QPKG_MIN_RAM_KB+=(any)
        MANAGER_QPKG_VERSION+=(210325)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/$PROJECT_BRANCH/QPKGs/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/build/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}.qpkg)
        MANAGER_QPKG_MD5+=(cd920291f5df7f6febc36db60bbfd323)
        MANAGER_QPKG_DESC+=('another SickBeard fork: manage and search for TV shows')
        MANAGER_QPKG_ABBRVS+=('om med omed medusa omedusa')
        MANAGER_QPKG_DEPENDS_ON+=(Entware)
        MANAGER_QPKG_DEPENDED_UPON+=(false)
        MANAGER_QPKG_IPKGS_ADD+=('mediainfo python3-pyopenssl')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_SUPPORTS_BACKUP+=(true)
        MANAGER_QPKG_RESTART_TO_UPDATE+=(true)

    MANAGER_QPKG_NAME+=(Mylar3)
        MANAGER_QPKG_ARCH+=(all)
        MANAGER_QPKG_MIN_RAM_KB+=(any)
        MANAGER_QPKG_VERSION+=(210318)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/$PROJECT_BRANCH/QPKGs/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/build/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}.qpkg)
        MANAGER_QPKG_MD5+=(1127611fedd01817f952de0ee43f796f)
        MANAGER_QPKG_DESC+=('automated Comic Book (cbr/cbz) downloader program for use with NZB and torrents written in Python')
        MANAGER_QPKG_ABBRVS+=('my omy myl mylar mylar3')
        MANAGER_QPKG_DEPENDS_ON+=(Entware)
        MANAGER_QPKG_DEPENDED_UPON+=(false)
        MANAGER_QPKG_IPKGS_ADD+=('python3-mako python3-pillow python3-pytz python3-requests python3-six python3-urllib3')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_SUPPORTS_BACKUP+=(true)
        MANAGER_QPKG_RESTART_TO_UPDATE+=(true)

    MANAGER_QPKG_NAME+=(NZBGet)
        MANAGER_QPKG_ARCH+=(all)
        MANAGER_QPKG_MIN_RAM_KB+=(any)
        MANAGER_QPKG_VERSION+=(210331)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/$PROJECT_BRANCH/QPKGs/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/build/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}.qpkg)
        MANAGER_QPKG_MD5+=(7c404bcb1ebc4a1b2ae150549ba8ff1f)
        MANAGER_QPKG_DESC+=('lite-and-fast NZB download manager with a simple web UI')
        MANAGER_QPKG_ABBRVS+=('ng nzb nzbg nget nzbget')
        MANAGER_QPKG_DEPENDS_ON+=(Entware)
        MANAGER_QPKG_DEPENDED_UPON+=(false)
        MANAGER_QPKG_IPKGS_ADD+=(nzbget)
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_SUPPORTS_BACKUP+=(true)
        MANAGER_QPKG_RESTART_TO_UPDATE+=(false)

    MANAGER_QPKG_NAME+=(nzbToMedia)
        MANAGER_QPKG_ARCH+=(all)
        MANAGER_QPKG_MIN_RAM_KB+=(any)
        MANAGER_QPKG_VERSION+=(210327)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/$PROJECT_BRANCH/QPKGs/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/build/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}.qpkg)
        MANAGER_QPKG_MD5+=(3d46d56830007f131a457b4fd7f40fb6)
        MANAGER_QPKG_DESC+=('post-processing for NZBs to many services')
        MANAGER_QPKG_ABBRVS+=('n2 nt nzb2 nzb2m nzbto nzbtom nzbtomedia')
        MANAGER_QPKG_DEPENDS_ON+=(Entware)
        MANAGER_QPKG_DEPENDED_UPON+=(false)
        MANAGER_QPKG_IPKGS_ADD+=('')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_SUPPORTS_BACKUP+=(true)
        MANAGER_QPKG_RESTART_TO_UPDATE+=(true)

    MANAGER_QPKG_NAME+=(Par2)
        MANAGER_QPKG_ARCH+=(x86)
        MANAGER_QPKG_MIN_RAM_KB+=(any)
        MANAGER_QPKG_VERSION+=(0.8.1.0)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/$PROJECT_BRANCH/QPKGs/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}_x86.qpkg)
        MANAGER_QPKG_MD5+=(996ffb92d774eb01968003debc171e91)
        MANAGER_QPKG_DESC+=('create and use PAR2 files to detect damage in data files and repair them if necessary')
        MANAGER_QPKG_ABBRVS+=('pr par par2')
        MANAGER_QPKG_DEPENDS_ON+=('')
        MANAGER_QPKG_DEPENDED_UPON+=(true)
        MANAGER_QPKG_IPKGS_ADD+=('')
        MANAGER_QPKG_IPKGS_REMOVE+=(par2cmdline)
        MANAGER_QPKG_SUPPORTS_BACKUP+=(false)
        MANAGER_QPKG_RESTART_TO_UPDATE+=(false)

    MANAGER_QPKG_NAME+=(Par2)
        MANAGER_QPKG_ARCH+=(x64)
        MANAGER_QPKG_MIN_RAM_KB+=(any)
        MANAGER_QPKG_VERSION+=(0.8.1.0)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/$PROJECT_BRANCH/QPKGs/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}_x86_64.qpkg)
        MANAGER_QPKG_MD5+=(520472cc87d301704f975f6eb9948e38)
        MANAGER_QPKG_DESC+=('')
        MANAGER_QPKG_ABBRVS+=('pr par par2')
        MANAGER_QPKG_DEPENDS_ON+=('')
        MANAGER_QPKG_DEPENDED_UPON+=(true)
        MANAGER_QPKG_IPKGS_ADD+=('')
        MANAGER_QPKG_IPKGS_REMOVE+=(par2cmdline)
        MANAGER_QPKG_SUPPORTS_BACKUP+=(false)
        MANAGER_QPKG_RESTART_TO_UPDATE+=(false)

    MANAGER_QPKG_NAME+=(Par2)
        MANAGER_QPKG_ARCH+=(x19)
        MANAGER_QPKG_MIN_RAM_KB+=(any)
        MANAGER_QPKG_VERSION+=(0.8.1.0)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/$PROJECT_BRANCH/QPKGs/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}_arm-x41.qpkg)
        MANAGER_QPKG_MD5+=(516e3f2849aa880c85ee736c2db833a8)
        MANAGER_QPKG_DESC+=('')
        MANAGER_QPKG_ABBRVS+=('pr par par2')
        MANAGER_QPKG_DEPENDS_ON+=('')
        MANAGER_QPKG_DEPENDED_UPON+=(true)
        MANAGER_QPKG_IPKGS_ADD+=('')
        MANAGER_QPKG_IPKGS_REMOVE+=(par2cmdline)
        MANAGER_QPKG_SUPPORTS_BACKUP+=(false)
        MANAGER_QPKG_RESTART_TO_UPDATE+=(false)

    MANAGER_QPKG_NAME+=(Par2)
        MANAGER_QPKG_ARCH+=(x31)
        MANAGER_QPKG_MIN_RAM_KB+=(any)
        MANAGER_QPKG_VERSION+=(0.8.1.0)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/$PROJECT_BRANCH/QPKGs/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}_arm-x31.qpkg)
        MANAGER_QPKG_MD5+=(ce8af2e009eb87733c3b855e41a94f8e)
        MANAGER_QPKG_DESC+=('')
        MANAGER_QPKG_ABBRVS+=('pr par par2')
        MANAGER_QPKG_DEPENDS_ON+=('')
        MANAGER_QPKG_DEPENDED_UPON+=(true)
        MANAGER_QPKG_IPKGS_ADD+=('')
        MANAGER_QPKG_IPKGS_REMOVE+=(par2cmdline)
        MANAGER_QPKG_SUPPORTS_BACKUP+=(false)
        MANAGER_QPKG_RESTART_TO_UPDATE+=(false)

    MANAGER_QPKG_NAME+=(Par2)
        MANAGER_QPKG_ARCH+=(x41)
        MANAGER_QPKG_MIN_RAM_KB+=(any)
        MANAGER_QPKG_VERSION+=(0.8.1.0)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/$PROJECT_BRANCH/QPKGs/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}_arm-x41.qpkg)
        MANAGER_QPKG_MD5+=(8516e45e704875cdd2cd2bb315c4e1e6)
        MANAGER_QPKG_DESC+=('')
        MANAGER_QPKG_ABBRVS+=('pr par par2')
        MANAGER_QPKG_DEPENDS_ON+=('')
        MANAGER_QPKG_DEPENDED_UPON+=(true)
        MANAGER_QPKG_IPKGS_ADD+=('')
        MANAGER_QPKG_IPKGS_REMOVE+=(par2cmdline)
        MANAGER_QPKG_SUPPORTS_BACKUP+=(false)
        MANAGER_QPKG_RESTART_TO_UPDATE+=(false)

    MANAGER_QPKG_NAME+=(Par2)
        MANAGER_QPKG_ARCH+=(a64)
        MANAGER_QPKG_MIN_RAM_KB+=(any)
        MANAGER_QPKG_VERSION+=(0.8.1.0)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/$PROJECT_BRANCH/QPKGs/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}_arm_64.qpkg)
        MANAGER_QPKG_MD5+=(4d8e99f97936a163e411aa8765595f7a)
        MANAGER_QPKG_DESC+=('')
        MANAGER_QPKG_ABBRVS+=('pr par par2')
        MANAGER_QPKG_DEPENDS_ON+=('')
        MANAGER_QPKG_DEPENDED_UPON+=(true)
        MANAGER_QPKG_IPKGS_ADD+=('')
        MANAGER_QPKG_IPKGS_REMOVE+=(par2cmdline)
        MANAGER_QPKG_SUPPORTS_BACKUP+=(false)
        MANAGER_QPKG_RESTART_TO_UPDATE+=(false)

    MANAGER_QPKG_NAME+=(RunLast)
        MANAGER_QPKG_ARCH+=(all)
        MANAGER_QPKG_MIN_RAM_KB+=(any)
        MANAGER_QPKG_VERSION+=(210328)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/main/build/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}.qpkg)
        MANAGER_QPKG_MD5+=(8bc501c43a1041e966c63b4ff242ecb9)
        MANAGER_QPKG_DESC+=('run userscripts and commands after all QPKGs have completed startup reintegration into QTS')
        MANAGER_QPKG_ABBRVS+=('rl run runlast')
        MANAGER_QPKG_DEPENDS_ON+=('')
        MANAGER_QPKG_DEPENDED_UPON+=(false)
        MANAGER_QPKG_IPKGS_ADD+=('')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_SUPPORTS_BACKUP+=(false)
        MANAGER_QPKG_RESTART_TO_UPDATE+=(false)

    MANAGER_QPKG_NAME+=(SABnzbd)
        MANAGER_QPKG_ARCH+=(all)
        MANAGER_QPKG_MIN_RAM_KB+=(any)
        MANAGER_QPKG_VERSION+=(210401)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/$PROJECT_BRANCH/QPKGs/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/build/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}.qpkg)
        MANAGER_QPKG_MD5+=(4b0af600a610424f34f0b82f0f75ddf4)
        MANAGER_QPKG_DESC+=('full-featured NZB download manager with a nice web UI')
        MANAGER_QPKG_ABBRVS+=('sb sb3 sab sab3 sabnzbd3 sabnzbd')
        MANAGER_QPKG_DEPENDS_ON+=('Entware Par2')
        MANAGER_QPKG_DEPENDED_UPON+=(false)
        MANAGER_QPKG_IPKGS_ADD+=('unrar p7zip coreutils-nice ionice ffprobe')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_SUPPORTS_BACKUP+=(true)
        MANAGER_QPKG_RESTART_TO_UPDATE+=(true)

    MANAGER_QPKG_NAME+=(sha3sum)
        MANAGER_QPKG_ARCH+=(x86)
        MANAGER_QPKG_MIN_RAM_KB+=(any)
        MANAGER_QPKG_VERSION+=(201114)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/main/build/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}_x86.qpkg)
        MANAGER_QPKG_MD5+=(87c4ae02c7f95cd2706997047fc9e84d)
        MANAGER_QPKG_DESC+=("the 'sha3sum' and keccak utilities from @maandree (for x86 & x86-64 NAS only)")
        MANAGER_QPKG_ABBRVS+=('s3 sha sha3 sha3sum')
        MANAGER_QPKG_DEPENDS_ON+=('')
        MANAGER_QPKG_DEPENDED_UPON+=(false)
        MANAGER_QPKG_IPKGS_ADD+=('')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_SUPPORTS_BACKUP+=(false)
        MANAGER_QPKG_RESTART_TO_UPDATE+=(false)

    MANAGER_QPKG_NAME+=(sha3sum)
        MANAGER_QPKG_ARCH+=(x64)
        MANAGER_QPKG_MIN_RAM_KB+=(any)
        MANAGER_QPKG_VERSION+=(201114)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/main/build/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}_x86_64.qpkg)
        MANAGER_QPKG_MD5+=(eed8071c43665431d6444cb489636ae5)
        MANAGER_QPKG_DESC+=('')
        MANAGER_QPKG_ABBRVS+=('s3 sha sha3 sha3sum')
        MANAGER_QPKG_DEPENDS_ON+=('')
        MANAGER_QPKG_DEPENDED_UPON+=(false)
        MANAGER_QPKG_IPKGS_ADD+=('')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_SUPPORTS_BACKUP+=(false)
        MANAGER_QPKG_RESTART_TO_UPDATE+=(false)

    MANAGER_QPKG_NAME+=($PROJECT_NAME)
        MANAGER_QPKG_ARCH+=(all)
        MANAGER_QPKG_MIN_RAM_KB+=(any)
        MANAGER_QPKG_VERSION+=(210328)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/$PROJECT_BRANCH/QPKGs/$PROJECT_NAME/build/${PROJECT_NAME}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}.qpkg)
        MANAGER_QPKG_MD5+=(dc3e0cef8c22fe43acc2ad94eadba5cf)
        MANAGER_QPKG_DESC+=("provides the '$PROJECT_NAME' command: the mini-package-manager")
        MANAGER_QPKG_ABBRVS+=("sh $PROJECT_NAME")
        MANAGER_QPKG_DEPENDS_ON+=('')
        MANAGER_QPKG_DEPENDED_UPON+=(false)
        MANAGER_QPKG_IPKGS_ADD+=('')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_SUPPORTS_BACKUP+=(false)
        MANAGER_QPKG_RESTART_TO_UPDATE+=(false)

    MANAGER_QPKG_NAME+=(SickChill)
        MANAGER_QPKG_ARCH+=(all)
        MANAGER_QPKG_MIN_RAM_KB+=(any)
        MANAGER_QPKG_VERSION+=(210326)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/$PROJECT_BRANCH/QPKGs/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/build/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}.qpkg)
        MANAGER_QPKG_MD5+=(fb488f7176bf5656575fa010a9599b63)
        MANAGER_QPKG_DESC+=('another SickBeard fork: manage and search for TV shows and movies')
        MANAGER_QPKG_ABBRVS+=('sc sick sickc chill sickchill')
        MANAGER_QPKG_DEPENDS_ON+=(Entware)
        MANAGER_QPKG_DEPENDED_UPON+=(false)
        MANAGER_QPKG_IPKGS_ADD+=('')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_SUPPORTS_BACKUP+=(true)
        MANAGER_QPKG_RESTART_TO_UPDATE+=(true)

    MANAGER_QPKG_NAME+=(OSickGear)
        MANAGER_QPKG_ARCH+=(all)
        MANAGER_QPKG_MIN_RAM_KB+=(any)
        MANAGER_QPKG_VERSION+=(210318)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/$PROJECT_BRANCH/QPKGs/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/build/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}.qpkg)
        MANAGER_QPKG_MD5+=(5584d751bed1c700f407375e3f56174e)
        MANAGER_QPKG_DESC+=('another SickBeard fork: manage and search for TV shows')
        MANAGER_QPKG_ABBRVS+=('sg os osg sickg gear ogear osickg sickgear osickgear')
        MANAGER_QPKG_DEPENDS_ON+=(Entware)
        MANAGER_QPKG_DEPENDED_UPON+=(false)
        MANAGER_QPKG_IPKGS_ADD+=('')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_SUPPORTS_BACKUP+=(true)
        MANAGER_QPKG_RESTART_TO_UPDATE+=(true)

    MANAGER_QPKG_NAME+=(SortMyQPKGs)
        MANAGER_QPKG_ARCH+=(all)
        MANAGER_QPKG_MIN_RAM_KB+=(any)
        MANAGER_QPKG_VERSION+=(210413)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/main/build/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}.qpkg)
        MANAGER_QPKG_MD5+=(3d97fd57c36f876184446c88b51578a3)
        MANAGER_QPKG_DESC+=('ensure other installed QPKGs start in correct sequence during QTS bootup')
        MANAGER_QPKG_ABBRVS+=('sm smq smqs sort sortmy sortmine sortpackages sortmypackages sortmyqpkgs')
        MANAGER_QPKG_DEPENDS_ON+=('')
        MANAGER_QPKG_DEPENDED_UPON+=(false)
        MANAGER_QPKG_IPKGS_ADD+=('')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_SUPPORTS_BACKUP+=(true)
        MANAGER_QPKG_RESTART_TO_UPDATE+=(false)

    MANAGER_QPKG_NAME+=(OTransmission)
        MANAGER_QPKG_ARCH+=(all)
        MANAGER_QPKG_MIN_RAM_KB+=(any)
        MANAGER_QPKG_VERSION+=(210331b)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/$PROJECT_BRANCH/QPKGs/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/build/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}.qpkg)
        MANAGER_QPKG_MD5+=(8149be0257866b0f237ee0fa63e1c20c)
        MANAGER_QPKG_DESC+=('lite bitorrent download manager with a simple web UI')
        MANAGER_QPKG_ABBRVS+=('tm tr ot trans otrans tmission transmission otransmission')
        MANAGER_QPKG_DEPENDS_ON+=(Entware)
        MANAGER_QPKG_DEPENDED_UPON+=(false)
        MANAGER_QPKG_IPKGS_ADD+=('transmission-web jq')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_SUPPORTS_BACKUP+=(true)
        MANAGER_QPKG_RESTART_TO_UPDATE+=(false)

    # package arrays are now full, so lock them
    readonly MANAGER_QPKG_NAME
        readonly MANAGER_QPKG_ARCH
        readonly MANAGER_QPKG_MIN_RAM_KB
        readonly MANAGER_QPKG_VERSION
        readonly MANAGER_QPKG_URL
        readonly MANAGER_QPKG_MD5
        readonly MANAGER_QPKG_DESC
        readonly MANAGER_QPKG_ABBRVS
        readonly MANAGER_QPKG_DEPENDS_ON
        readonly MANAGER_QPKG_DEPENDED_UPON
        readonly MANAGER_QPKG_IPKGS_ADD
        readonly MANAGER_QPKG_IPKGS_REMOVE
        readonly MANAGER_QPKG_SUPPORTS_BACKUP
        readonly MANAGER_QPKG_RESTART_TO_UPDATE

    QPKGs.ScAll.Add "${MANAGER_QPKG_NAME[*]}"

    readonly MANAGER_BASE_QPKG_CONFLICTS='Optware Optware-NG TarMT Python QPython2 Python3 QPython3'
    readonly MANAGER_BASE_IPKGS_ADD='less sed'
    readonly MANAGER_SHARED_IPKGS_ADD='ca-certificates findutils gcc git git-http grep nano python3-dev python3-pip python3-setuptools'
    readonly MANAGER_SHARED_PIPS_ADD='pip wheel pyopenssl cryptography apprise apscheduler beautifulsoup4 cfscrape cheetah3 cherrypy configobj feedparser pygithub python-levenshtein python-magic random_user_agent sabyenc3 simplejson slugify'

    QPKGs.StandaloneDependent.Build

    # speedup: don't build package lists if only showing basic help
    if [[ -z $USER_ARGS_RAW ]]; then
        Opts.Help.Basic.Set
        QPKGs.SkProc.Set
        DisableDebugToArchiveAndFile
    else
        ParseArguments
    fi

    SmartCR >&2

    if Session.Display.Clean.IsNt && Session.Debug.ToScreen.IsNt; then
        Display "$(FormatAsScriptTitle) $MANAGER_SCRIPT_VERSION • a mini-package-manager for QNAP NAS"
        DisplayLineSpaceIfNoneAlready
    fi

    DebugFuncExit

    }

Session.Validate()
    {

    # This function handles most of the high-level logic for package operations.
    # If a package isn't being processed by the correct operation, odds-are it's due to a logic error in this function.

    ArgumentSuggestions
    QPKGs.SkProc.IsSet && return
    DebugFuncEntry
    local operation=''
    local scope=''
    local state=''
    local prospect=''
    local package=''
    local something_to_do=false
    local -i max_width=70
    local -i trimmed_width=$((max_width-3))
    local version=''

    ShowAsProc 'environment' >&2

    DebugInfoMinorSeparator
    DebugHardwareOK model "$(get_display_name)"

    if [[ -e $GNU_GREP_CMD ]]; then
        DebugHardwareOK CPU "$($GNU_GREP_CMD -m1 '^model name' /proc/cpuinfo | $SED_CMD 's|^.*: ||')"
    else    # QTS 4.5.1 & BusyBox 1.01 don't support '-m' option for 'grep', so need to use a different method
        DebugHardwareOK CPU "$($GREP_CMD '^model name' /proc/cpuinfo | $HEAD_CMD -n1 | $SED_CMD 's|^.*: ||')"
    fi

    DebugHardwareOK RAM "$(FormatAsThousands "$INSTALLED_RAM_KB")kB"

    if [[ ${NAS_FIRMWARE//.} -ge 400 ]]; then
        DebugFirmwareOK version "$NAS_FIRMWARE"
    else
        DebugFirmwareWarning version "$NAS_FIRMWARE"
    fi

    if [[ $NAS_BUILD -lt 20201015 || $NAS_BUILD -gt 20201020 ]]; then   # builds inbetween these won't allow unsigned QPKGs to run at-all
        DebugFirmwareOK build "$NAS_BUILD"
    else
        DebugFirmwareWarning build "$NAS_BUILD"
    fi

    DebugFirmwareOK kernel "$($UNAME_CMD -mr)"
    DebugFirmwareOK platform "$(/sbin/getcfg '' Platform -d unknown -f /etc/platform.conf)"
    DebugUserspaceOK 'OS uptime' "$($UPTIME_CMD | $SED_CMD 's|.*up.||;s|,.*load.*||;s|^\ *||')"
    DebugUserspaceOK 'system load' "$($UPTIME_CMD | $SED_CMD 's|.*load average: ||' | $AWK_CMD -F', ' '{print "1m:"$1", 5m:"$2", 15m:"$3}')"

    if [[ $USER = admin ]]; then
        DebugUserspaceOK '$USER' "$USER"
    else
        DebugUserspaceWarning '$USER' "$USER"
    fi

    if [[ $EUID -eq 0 ]]; then
        DebugUserspaceOK '$EUID' "$EUID"
    else
        DebugUserspaceWarning '$EUID' "$EUID"
    fi

    if [[ $EUID -ne 0 || $USER != admin ]]; then
        ShowAsEror "this script must be run as the 'admin' user. Please login via SSH as 'admin' and try again"
        QPKGs.SkProc.Set
    fi

    DebugUserspaceOK '$BASH_VERSION' "$BASH_VERSION"
    DebugUserspaceOK 'default volume' "$(/sbin/getcfg SHARE_DEF defVolMP -f /etc/config/def_share.info)"

    if [[ -L /opt ]]; then
        DebugUserspaceOK '/opt' "$($READLINK_CMD /opt || echo '<not present>')"
    else
        DebugUserspaceWarning '/opt' '<not present>'
    fi

    if [[ ${#PATH} -le $max_width ]]; then
        DebugUserspaceOK '$PATH' "$PATH"
    else
        DebugUserspaceOK '$PATH' "${PATH:0:trimmed_width}..."
    fi

    CheckPythonPathAndVersion python3
    CheckPythonPathAndVersion python

    if QPKGs.IsInstalled.Exist Entware && ! QPKGs.OpToUninstall.Exist Entware; then
        [[ -e /opt/bin/python3 ]] && version=$(/opt/bin/python3 -V 2>/dev/null | $SED_CMD 's|^Python ||') && [[ ${version//./} -lt $MIN_PYTHON_VER ]] && ShowAsReco "your Python 3 is out-of-date. Suggest reinstalling Entware: '$PROJECT_NAME reinstall ew'"
    fi

    DebugScript 'logs path' "$LOGS_PATH"
    DebugScript 'work path' "$WORK_PATH"
    DebugScript 'objects hash' "$(CompileObjects hash)"
    DebugInfoMinorSeparator

    if QPKGs.SkProc.IsSet; then
        DebugFuncExit 1; return
    fi

    if ! QPKGs.Conflicts.Check; then
        code_pointer=1
        QPKGs.SkProc.Set
        DebugFuncExit 1; return
    fi

    QPKGs.States.Build

    ShowAsProc 'arguments' >&2

    for operation in "${PACKAGE_OPERATIONS[@]}"; do
        if QPKGs.OpTo${operation}.IsAny; then
            something_to_do=true
            break
        fi

        for scope in "${PACKAGE_SCOPES[@]}"; do
            if Opts.Apps.Op${operation}.Sc${scope}.IsSet || Opts.Apps.Op${operation}.ScNt${scope}.IsSet; then
                something_to_do=true
                break 2
            fi
        done

        for state in "${PACKAGE_STATES[@]}"; do
            if Opts.Apps.Op${operation}.Is${state}.IsSet || Opts.Apps.Op${operation}.IsNt${state}.IsSet; then
                something_to_do=true
                break 2
            fi
        done
    done

    if Opts.Deps.Check.IsSet || Opts.IgFreeSpace.IsSet || Opts.Help.Status.IsSet; then
        something_to_do=true
    fi

    if [[ $something_to_do = false ]]; then
        ShowAsEror "I've nothing to do (this usually means the arguments couldn't be run as-specified)"
        Opts.Help.Basic.Set
        QPKGs.SkProc.Set
        DebugFuncExit 1; return
    fi

    if Opts.Deps.Check.IsSet || QPKGs.OpToUpgrade.Exist Entware; then
        IPKGs.ToUpgrade.Set
        IPKGs.ToInstall.Set
    fi

    QPKGs.IsSupportBackup.Build
    QPKGs.IsSupportUpdateOnRestart.Build
    ApplySensibleExceptions

    # meta-operation pre-processing
    if QPKGs.OpToRebuild.IsAny; then
        if QPKGs.IsBackedUp.IsNone; then
            ShowAsWarn 'there are no package backups to rebuild from' >&2
        else
            for package in $(QPKGs.OpToRebuild.Array); do
                if ! QPKGs.IsBackedUp.Exist "$package"; then
                    MarkOperationAsSkipped show "$package" rebuild "does not have a backup to rebuild from"
                else
                    (QPKGs.IsNtInstalled.Exist "$package" || QPKGs.OpToUninstall.Exist "$package") && QPKGs.OpToInstall.Add "$package"
                    QPKGs.OpToRestore.Add "$package"
                    QPKGs.OpToRebuild.Remove "$package"
                fi
            done
        fi
    fi

    # ensure standalone packages are also installed when processing these specific operations
    for operation in Upgrade Reinstall Install Start Restart; do
        for package in $(QPKGs.OpTo${operation}.Array); do
            for prospect in $(QPKG.GetStandalones "$package"); do
                QPKGs.IsNtInstalled.Exist "$prospect" && ! QPKGs.OpToUninstall.Exist "$prospect" && QPKGs.OpToInstall.Add "$prospect"
            done
        done
    done

    # install standalones for started packages only
    for package in $(QPKGs.IsInstalled.Array); do
        if QPKGs.IsStarted.Exist "$package" || QPKGs.OpToStart.Exist "$package"; then
            for prospect in $(QPKG.GetStandalones "$package"); do
                QPKGs.IsNtInstalled.Exist "$prospect" && QPKGs.OpToInstall.Add "$prospect"
            done
        fi
    done

    # if an standalone has been selected for reinstall or restart, need to stop its dependents first, and start them again later
    for package in $(QPKGs.OpToReinstall.Array) $(QPKGs.OpToRestart.Array); do
        if QPKGs.ScStandalone.Exist "$package" && QPKGs.IsStarted.Exist "$package"; then
            for prospect in $(QPKG.GetDependents "$package"); do
                if QPKGs.IsStarted.Exist "$prospect"; then
                    QPKGs.OpToStop.Add "$prospect"
                    QPKGs.OpToStart.Add "$prospect"
                fi
            done
        fi
    done

    # if an standalone has been selected for stop or uninstall, need to stop its dependents first
    for package in $(QPKGs.OpToStop.Array) $(QPKGs.OpToUninstall.Array); do
        if QPKGs.ScStandalone.Exist "$package" && QPKGs.IsInstalled.Exist "$package"; then
            for prospect in $(QPKG.GetDependents "$package"); do
                QPKGs.IsStarted.Exist "$prospect" && QPKGs.OpToStop.Add "$prospect"
            done
        fi
    done

    if QPKGs.OpToReinstall.Exist Entware; then    # Entware is a special case: complete removal and fresh install (to clear all installed IPKGs)
        QPKGs.OpToReinstall.Remove Entware
        QPKGs.OpToUninstall.Add Entware
        QPKGs.OpToInstall.Add Entware
    fi

    # no-need to stop packages that are about to be uninstalled
    if Opts.Apps.OpUninstall.ScAll.IsSet; then
        QPKGs.OpToStop.Init
    else
        QPKGs.OpToStop.Remove "$(QPKGs.OpToUninstall.Array)"
    fi

    # build list containing packages that will require installation QPKGs
    QPKGs.OpToDownload.Add "$(QPKGs.OpToUpgrade.Array) $(QPKGs.OpToReinstall.Array) $(QPKGs.OpToInstall.Array)"

    # check all items
    if Opts.Deps.Check.IsSet; then
        for package in $(QPKGs.ScDependent.Array); do
            if ! QPKGs.ScUpgradable.Exist "$package" && QPKGs.IsStarted.Exist "$package" && QPKGs.ScSupportUpdateOnRestart.Exist "$package"; then
                QPKGs.OpToRestart.Add "$package"
            fi
        done
    fi

    DebugFuncExit

    }

# package processing priorities need to be:

#   _. rebuild dependents           (meta-operation: 'install' QPKG and 'restore' config only if package has a backup file)

#  17. backup all                   (highest: most-important)
#  16. stop dependents
#  15. stop standalones
#  14. uninstall all

#  13. upgrade standalones
#  12. reinstall standalones
#  11. install standalones
#  10. restore standalones
#   9. start standalones
#   8. restart standalones

#   7. upgrade dependents
#   6. reinstall dependents
#   5. install dependents
#   4. restore dependents
#   3. start dependents
#   2. restart dependents

#   1. status                       (lowest: least-important)

Tiers.Processor()
    {

    QPKGs.SkProc.IsSet && return
    DebugFuncEntry
    local tier=''
    local operation=''
    local prospect=''
    local package=''
    local -i index=0

    Tier.Processor Download false All QPKG OpToDownload 'update package cache with' 'updating package cache with' 'updated package cache with' ''

    # -> package 'removal' phase begins here <-

    for ((index=${#PACKAGE_TIERS[@]}-1; index>=0; index--)); do     # process tiered removal operations in-reverse
        tier=${PACKAGE_TIERS[$index]}

        case $tier in
            Standalone|Dependent)
                Tier.Processor Backup false "$tier" QPKG OpToBackup 'backup configuration for' 'backing-up configuration for' 'configuration backed-up for' ''
                Tier.Processor Stop false "$tier" QPKG OpToStop stop stopping stopped ''
                Tier.Processor Uninstall false "$tier" QPKG OpToUninstall uninstall uninstalling uninstalled ''
                ;;
            Addon)
                Tier.Processor Uninstall false "$tier" IPKG OpToUninstall uninstall uninstalling uninstalled ''
        esac
    done

    # -> package 'installation' phase begins here <-

    # just in-case 'python' has disappeared again ... ¯\_(ツ)_/¯

    [[ ! -L /opt/bin/python && -e /opt/bin/python3 ]] && ln -s /opt/bin/python3 /opt/bin/python

    for tier in "${PACKAGE_TIERS[@]}"; do
        case $tier in
            Standalone|Dependent)
                Tier.Processor Upgrade false "$tier" QPKG OpToUpgrade upgrade upgrading upgraded long
                Tier.Processor Reinstall false "$tier" QPKG OpToReinstall reinstall reinstalling reinstalled long
                Tier.Processor Install false "$tier" QPKG OpToInstall install installing installed long
                Tier.Processor Restore false "$tier" QPKG OpToRestore 'restore configuration for' 'restoring configuration for' 'configuration restored for' long

                if [[ $tier = Standalone ]]; then
                    # check for standalone packages that require starting due to dependents being reinstalled/installed/started/restarted
                    for package in $(QPKGs.OpToReinstall.Array) $(QPKGs.OpOkReinstall.Array) $(QPKGs.OpToInstall.Array) $(QPKGs.OpOkInstall.Array) $(QPKGs.OpToStart.Array) $(QPKGs.OpOkStart.Array) $(QPKGs.OpToRestart.Array) $(QPKGs.OpOkRestart.Array); do
                        for prospect in $(QPKG.GetStandalones "$package"); do
                            QPKGs.IsStopped.Exist "$prospect" && QPKGs.OpToStart.Add "$prospect"
                        done
                    done
                fi

                Tier.Processor Start false "$tier" QPKG OpToStart start starting started long

                for operation in Install Restart Start; do
                    QPKGs.OpToRestart.Remove "$(QPKGs.OpOk${operation}.Array)"
                done

                Tier.Processor Restart false "$tier" QPKG OpToRestart restart restarting restarted long

                ;;
            Addon)
                for operation in Install Reinstall Upgrade Start; do
                    if QPKGs.OpTo${operation}.IsAny || QPKGs.OpOk${operation}.IsAny; then
                        IPKGs.ToUpgrade.Set
                        IPKGs.ToInstall.Set
                        break
                    fi
                done

                if QPKGs.IsStarted.Exist Entware; then
                    ModPathToEntware

                    Tier.Processor Upgrade false "$tier" IPKG '' upgrade upgrading upgraded long
                    Tier.Processor Install false "$tier" IPKG '' install installing installed long
                    Tier.Processor Install false "$tier" PIP '' install installing installed long
                fi
        esac
    done

    QPKGs.Operations.List
    QPKGs.States.List
    SmartCR >&2

    DebugFuncExit

    }

Tier.Processor()
    {

    # run a single operation on a group of packages

    # input:
    #   $1 = $TARGET_OPERATION              e.g. 'Start', 'Restart'...
    #   $2 = forced operation?              e.g. 'true', 'false'
    #   $3 = $TIER                          e.g. 'Standalone', 'Dependent', 'Addon', 'All'
    #   $4 = $PACKAGE_TYPE                  e.g. 'QPKG', 'IPKG', 'PIP'
    #   $5 = $TARGET_OBJECT_NAME (optional) e.g. 'OpToStart', 'OpToStop'...
    #   $6 = $ACTION_INTRANSITIVE           e.g. 'start'...
    #   $7 = $ACTION_PRESENT                e.g. 'starting'...
    #   $8 = $ACTION_PAST                   e.g. 'started'...
    #   $9 = $RUNTIME (optional)            e.g. 'long'

    DebugFuncEntry

    local package=''
    local forced_operation=''
    local message_prefix=''
    local target_function=''
    local targets_function=''
    local -i result_code=0
    local -a target_packages=()
    local -i pass_count=0
    local -i fail_count=0
    local -i total_count=0
    local -r TARGET_OPERATION=${1:?empty}
    local -r TIER=${3:?empty}
    local -r PACKAGE_TYPE=${4:?empty}
    local -r TARGET_OBJECT_NAME=${5:-}
    local -r RUNTIME=${9:-}

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
            DebugFuncExit 1; return
    esac

    local -r ACTION_INTRANSITIVE=${message_prefix}${6:?empty}
    local -r ACTION_PRESENT=${message_prefix}${7:?empty}
    local -r ACTION_PAST=${message_prefix}${8:?empty}

    ShowAsProc "$([[ $TIER = All ]] && echo '' || echo "$TIER " | tr 'A-Z' 'a-z')packages to $ACTION_INTRANSITIVE" >&2

    case $PACKAGE_TYPE in
        QPKG)
            if $targets_function.$TARGET_OBJECT_NAME.IsNone; then
                DebugInfo "no $targets_function to process"
                DebugFuncExit; return
            fi

            if [[ $TIER = All ]]; then  # process all tiers
                target_packages=($($targets_function.$TARGET_OBJECT_NAME.Array))
            else                        # only process packages in specified tier, ignoring all others
                for package in $($targets_function.$TARGET_OBJECT_NAME.Array); do
                    $targets_function.Sc${TIER}.Exist "$package" && target_packages+=("$package")
                done
            fi

            total_count=${#target_packages[@]}

            if [[ $total_count -eq 0 ]]; then
                DebugInfo "no$([[ $TIER = All ]] && echo '' || echo " $TIER") $targets_function to process"
                DebugFuncExit; return
            fi

            for package in "${target_packages[@]}"; do
                ShowAsOperationProgress "$TIER" "$PACKAGE_TYPE" "$pass_count" "$fail_count" "$total_count" "$ACTION_PRESENT" "$RUNTIME"

                $target_function.Do${TARGET_OPERATION} "$package" "$forced_operation"
                result_code=$?

                case $result_code in
                    0)  # OK
                        ((pass_count++))
                        ;;
                    2)  # skipped
                        ((total_count--))
                        ;;
                    *)  # failed
                        ShowAsFail "unable to $ACTION_INTRANSITIVE $(FormatAsPackageName "$package") (see log for more details)"
                        ((fail_count++))
                        continue
                esac
            done
            ;;
        IPKG|PIP)
            $targets_function.Do${TARGET_OPERATION}
    esac

    # execute with pass_count > total_count to trigger 100% message
    ShowAsOperationProgress "$TIER" "$PACKAGE_TYPE" "$((total_count+1))" "$fail_count" "$total_count" "$ACTION_PRESENT" "$RUNTIME"
    ShowAsOperationResult "$TIER" "$PACKAGE_TYPE" "$pass_count" "$fail_count" "$total_count" "$ACTION_PAST" "$RUNTIME"

    DebugFuncExit

    }

Session.Results()
    {

    if Args.Unknown.IsNone; then
        if Opts.Help.Actions.IsSet; then
            Help.Actions.Show
        elif Opts.Help.ActionsAll.IsSet; then
            Help.ActionsAll.Show
        elif Opts.Help.Packages.IsSet; then
            Help.Packages.Show
        elif Opts.Help.Options.IsSet; then
            Help.Options.Show
        elif Opts.Help.Problems.IsSet; then
            Help.Problems.Show
        elif Opts.Help.Tips.IsSet; then
            Help.Tips.Show
        elif Opts.Help.Abbreviations.IsSet; then
            Help.PackageAbbreviations.Show
        elif Opts.Versions.View.IsSet; then
            ShowVersions
        elif Opts.Log.All.View.IsSet; then
            Log.All.View
        elif Opts.Log.Last.View.IsSet; then
            Log.Last.View
        elif Opts.Log.Tail.View.IsSet; then
            Log.Tail.View
        elif Opts.Log.All.Paste.IsSet; then
            Log.All.Paste
        elif Opts.Log.Last.Paste.IsSet; then
            Log.Last.Paste
        elif Opts.Log.Tail.Paste.IsSet; then
            Log.Tail.Paste
        elif Opts.Apps.List.ScAll.IsSet; then
            QPKGs.ScAll.Show
        elif Opts.Apps.List.ScInstallable.IsSet; then
            Session.Display.Clean.IsNt && QPKGs.NewVersions.Show
            QPKGs.ScInstallable.Show
        elif Opts.Apps.List.IsNtInstalled.IsSet; then
            Session.Display.Clean.IsNt && QPKGs.NewVersions.Show
            QPKGs.IsNtInstalled.Show
        elif Opts.Apps.List.IsStarted.IsSet; then
            Session.Display.Clean.IsNt && QPKGs.NewVersions.Show
            QPKGs.IsStarted.Show
        elif Opts.Apps.List.IsStopped.IsSet; then
            Session.Display.Clean.IsNt && QPKGs.NewVersions.Show
            QPKGs.IsStopped.Show
        elif Opts.Apps.List.ScUpgradable.IsSet; then
            Session.Display.Clean.IsNt && QPKGs.NewVersions.Show
            QPKGs.ScUpgradable.Show
        elif Opts.Apps.List.ScStandalone.IsSet; then
            Session.Display.Clean.IsNt && QPKGs.NewVersions.Show
            QPKGs.ScStandalone.Show
        elif Opts.Apps.List.ScDependent.IsSet; then
            Session.Display.Clean.IsNt && QPKGs.NewVersions.Show
            QPKGs.ScDependent.Show
        elif Opts.Help.Backups.IsSet; then
            QPKGs.Backups.Show
        elif Opts.Help.Status.IsSet; then
            Session.Display.Clean.IsNt && QPKGs.NewVersions.Show
            QPKGs.Statuses.Show
        elif Opts.Apps.List.IsInstalled.IsSet; then
            Session.Display.Clean.IsNt && QPKGs.NewVersions.Show
            QPKGs.IsInstalled.Show
        fi
    fi

    if Opts.Help.Basic.IsSet; then
        Help.Basic.Show
        Help.Basic.Example.Show
    fi

    Session.ShowBackupLoc.IsSet && Help.BackupLocation.Show
    Session.Summary.IsSet && ShowSummary
    Session.SuggestIssue.IsSet && Help.Issue.Show

    DebugInfoMinorSeparator
    DebugScript 'finished' "$($DATE_CMD)"
    DebugScript 'elapsed time' "$(ConvertSecsToHoursMinutesSecs "$(($($DATE_CMD +%s)-$([[ -n $SCRIPT_STARTSECONDS ]] && echo "$SCRIPT_STARTSECONDS" || echo "1")))")"
    DebugInfoMajorSeparator
    Session.Debug.ToArchive.IsSet && ArchiveActiveSessionLog
    ResetActiveSessionLog
    ReleaseLockFile
    DisplayLineSpaceIfNoneAlready   # final on-screen linespace

    return 0

    }

ParseArguments()
    {

    # basic argument syntax:
    #   script [operation] [scope] [options]

    DebugFuncEntry
    DebugVar USER_ARGS_RAW
    local user_args_fixed=$(tr 'A-Z' 'a-z' <<< "${USER_ARGS_RAW//,/ }")
    local -a user_args=(${user_args_fixed/--/})
    local arg=''
    local arg_identified=false
    local operation=''
    local operation_force=false
    local scope=''
    local scope_identified=false
    local package=''
    local prospect=''

    for arg in "${user_args[@]}"; do
        arg_identified=false

        # identify operation: everytime operation changes, must clear scope
        case $arg in
            backup|check|install|rebuild|reinstall|restart|restore|start|stop|upgrade)
                operation=${arg}_
                arg_identified=true
                scope=''
                scope_identified=false
                Session.Display.Clean.Clear
                QPKGs.SkProc.Clear
                ;;
            rm|remove|uninstall)
                operation=uninstall_
                arg_identified=true
                scope=''
                scope_identified=false
                Session.Display.Clean.Clear
                QPKGs.SkProc.Clear
                ;;
            s|status|statuses)
                operation=status_
                arg_identified=true
                scope=''
                scope_identified=false
                Session.Display.Clean.Clear
                QPKGs.SkProc.Set
                ;;
            paste)
                operation=paste_
                arg_identified=true
                scope=''
                scope_identified=false
                Session.Display.Clean.Clear
                QPKGs.SkProc.Set
                ;;
            display|help|list|show|view)
                operation=help_
                arg_identified=true
                scope=''
                scope_identified=false
                Session.Display.Clean.Clear
                QPKGs.SkProc.Set
        esac

        # identify scope in two stages: first stage is when user didn't supply an operation. Second is after an operation has been defined.

        # stage 1
        if [[ -z $operation ]]; then
            case $arg in
                a|abs|action|actions|actions-all|all-actions|b|backups|dependent|dependents|installable|installed|l|last|log|not-installed|o|option|options|p|package|packages|problems|standalone|standalones|started|stopped|tail|tips|upgradable|v|version|versions|whole)
                    operation=help_
                    arg_identified=true
                    scope=''
                    scope_identified=false
                    QPKGs.SkProc.Set
            esac

            DebugVar operation
        fi

        # stage 2
        if [[ -n $operation ]]; then
            case $arg in
                a|abs)
                    scope=abs_
                    scope_identified=true
                    arg_identified=true
                    ;;
                actions-all|all-actions)
                    scope=all-actions_
                    scope_identified=true
                    arg_identified=true
                    ;;
                action|actions)
                    scope=actions_
                    scope_identified=true
                    arg_identified=true
                    ;;
                all|entire|everything)
                    scope=all_
                    scope_identified=true
                    arg_identified=true
                    ;;
                b|backups)
                    scope=backups_
                    scope_identified=true
                    arg_identified=true
                    ;;
                dependent|dependents)
                    scope=dependent_
                    scope_identified=true
                    arg_identified=true
                    ;;
                installable|installed|not-installed|problems|started|stopped|tail|tips|upgradable)
                    scope=${arg}_
                    scope_identified=true
                    arg_identified=true
                    ;;
                l|last)
                    scope=last_
                    scope_identified=true
                    arg_identified=true
                    ;;
                log|whole)
                    scope=log_
                    scope_identified=true
                    arg_identified=true
                    ;;
                option|options)
                    scope=options_
                    scope_identified=true
                    arg_identified=true
                    ;;
                p|package|packages)
                    scope=packages_
                    scope_identified=true
                    arg_identified=true
                    ;;
                standalone|standalones)
                    scope=standalone_
                    scope_identified=true
                    arg_identified=true
                    ;;
                v|version|versions)
                    scope=versions_
                    scope_identified=true
                    arg_identified=true
            esac
        fi

        # identify options
        case $arg in
            debug|verbose)
                Session.Debug.ToScreen.Set
                arg_identified=true
                scope_identified=true
                ;;
            force)
                operation_force=true
                arg_identified=true
                ;;
            ignore-space)
                Opts.IgFreeSpace.Set
                arg_identified=true
        esac

        # identify package
        package=$(QPKG.MatchAbbrv "$arg")

        if [[ -n $package ]]; then
            scope_identified=true
            arg_identified=true
        fi

        [[ $arg_identified = false ]] && Args.Unknown.Add "$arg"

        case $operation in
            backup_)
                case $scope in
                    all_|installed_)
                        Opts.Apps.OpBackup.ScAll.Set
                        operation=''
                        ;;
                    dependent_)
                        Opts.Apps.OpBackup.ScDependent.Set
                        ;;
                    standalone_)
                        Opts.Apps.OpBackup.ScStandalone.Set
                        ;;
                    started_)
                        QPKGs.OpToBackup.Add "$(QPKGs.IsStarted.Array)"
                        ;;
                    stopped_)
                        QPKGs.OpToBackup.Add "$(QPKGs.IsStopped.Array)"
                        ;;
                    *)
                        QPKGs.OpToBackup.Add "$package"
                esac
                ;;
            check_)
                Opts.Deps.Check.Set
                ;;
            help_)
                case $scope in
                    abs_)
                        Opts.Help.Abbreviations.Set
                        ;;
                    actions_)
                        Opts.Help.Actions.Set
                        ;;
                    all-actions_|all_)
                        Opts.Help.ActionsAll.Set
                        ;;
                    backups_)
                        Opts.Help.Backups.Set
                        ;;
                    installable_)
                        Opts.Apps.List.ScInstallable.Set
                        Session.Display.Clean.Set
                        ;;
                    installed_)
                        Opts.Apps.List.IsInstalled.Set
                        Session.Display.Clean.Set
                        ;;
                    last_)
                        Opts.Log.Last.View.Set
                        Session.Display.Clean.Set
                        ;;
                    log_)
                        Opts.Log.All.View.Set
                        Session.Display.Clean.Set
                        ;;
                    not-installed_)
                        Opts.Apps.List.IsNtInstalled.Set
                        Session.Display.Clean.Set
                        ;;
                    dependent_)
                        Opts.Apps.List.ScDependent.Set
                        Session.Display.Clean.Set
                        ;;
                    options_)
                        Opts.Help.Options.Set
                        ;;
                    packages_)
                        Opts.Help.Packages.Set
                        ;;
                    problems_)
                        Opts.Help.Problems.Set
                        ;;
                    standalone_)
                        Opts.Apps.List.ScStandalone.Set
                        Session.Display.Clean.Set
                        ;;
                    started_)
                        Opts.Apps.List.IsStarted.Set
                        Session.Display.Clean.Set
                        ;;
                    status_)
                        Opts.Help.Status.Set
                        ;;
                    stopped_)
                        Opts.Apps.List.IsStopped.Set
                        Session.Display.Clean.Set
                        ;;
                    tail_)
                        Opts.Log.Tail.View.Set
                        Session.Display.Clean.Set
                        ;;
                    tips_)
                        Opts.Help.Tips.Set
                        ;;
                    upgradable_)
                        Opts.Apps.List.ScUpgradable.Set
                        Session.Display.Clean.Set
                        ;;
                    versions_)
                        Opts.Versions.View.Set
                        Session.Display.Clean.Set
                esac

                QPKGs.SkProc.Set
                ;;
            install_)
                case $scope in
                    all_)
                        Opts.Apps.OpInstall.ScAll.Set
                        operation=''
                        ;;
                    dependent_)
                        Opts.Apps.OpInstall.ScDependent.Set
                        operation=''
                        ;;
                    installable_)
                        Opts.Apps.OpInstall.ScInstallable.Set
                        operation=''
                        ;;
                    not-installed_)
                        Opts.Apps.OpInstall.IsNtInstalled.Set
                        operation=''
                        ;;
                    standalone_)
                        Opts.Apps.OpInstall.ScStandalone.Set
                        operation=''
                        ;;
                    *)
                        QPKGs.OpToInstall.Add "$package"
                esac
                ;;
            paste_)
                case $scope in
                    all_|log_)
                        Opts.Log.All.Paste.Set
                        ;;
                    last_)
                        Opts.Log.Last.Paste.Set
                        ;;
                    tail_)
                        Opts.Log.Tail.Paste.Set
                esac

                QPKGs.SkProc.Set

                if [[ $scope_identified = true ]]; then
                    DebugFuncExit; return
                fi
                ;;
            rebuild_)
                case $scope in
                    all_|installed_)
                        Opts.Apps.OpRebuild.ScAll.Set
                        operation=''
                        ;;
                    dependent_)
                        Opts.Apps.OpRebuild.ScDependent.Set
                        operation=''
                        ;;
                    standalone_)
                        Opts.Apps.OpRebuild.ScStandalone.Set
                        operation=''
                        ;;
                    *)
                        QPKGs.OpToRebuild.Add "$package"
                esac
                ;;
            reinstall_)
                case $scope in
                    all_|installed_)
                        Opts.Apps.OpReinstall.ScAll.Set
                        operation=''
                        ;;
                    dependent_)
                        Opts.Apps.OpReinstall.ScDependent.Set
                        operation=''
                        ;;
                    standalone_)
                        Opts.Apps.OpReinstall.ScStandalone.Set
                        operation=''
                        ;;
                    *)
                        QPKGs.OpToReinstall.Add "$package"
                esac
                ;;
            restart_)
                case $scope in
                    all_|installed_)
                        Opts.Apps.OpRestart.ScAll.Set
                        operation=''
                        ;;
                    dependent_)
                        Opts.Apps.OpRestartScDependent.Set
                        operation=''
                        ;;
                    standalone_)
                        Opts.Apps.OpRestart.ScStandalone.Set
                        operation=''
                        ;;
                    *)
                        QPKGs.OpToRestart.Add "$package"
                esac
                ;;
            restore_)
                case $scope in
                    all_|installed_)
                        Opts.Apps.OpRestore.ScAll.Set
                        operation=''
                        ;;
                    dependent_)
                        Opts.Apps.OpRestore.ScDependent.Set
                        operation=''
                        ;;
                    standalone_)
                        Opts.Apps.OpRestore.ScStandalone.Set
                        operation=''
                        ;;
                    *)
                        QPKGs.OpToRestore.Add "$package"
                esac
                ;;
            start_)
                case $scope in
                    all_|installed_)
                        Opts.Apps.OpStart.ScAll.Set
                        operation=''
                        ;;
                    dependent_)
                        Opts.Apps.OpStart.ScDependent.Set
                        operation=''
                        ;;
                    standalone_)
                        Opts.Apps.OpStart.ScStandalone.Set
                        operation=''
                        ;;
                    stopped_)
                        Opts.Apps.OpStart.IsStopped.Set
                        operation=''
                        ;;
                    *)
                        QPKGs.OpToStart.Add "$package"
                esac
                ;;
            status_)
                Opts.Help.Status.Set
                QPKGs.SkProc.Set
                ;;
            stop_)
                case $scope in
                    all_|installed_)
                        Opts.Apps.OpStop.ScAll.Set
                        operation=''
                        ;;
                    dependent_)
                        Opts.Apps.OpStop.ScDependent.Set
                        operation=''
                        ;;
                    standalone_)
                        Opts.Apps.OpStop.ScStandalone.Set
                        operation=''
                        ;;
                    started_)
                        Opts.Apps.OpStop.IsStarted.Set
                        operation=''
                        ;;
                    *)
                        QPKGs.OpToStop.Add "$package"
                esac
                ;;
            uninstall_)
                case $scope in
                    all_|installed_)   # this scope is dangerous, so make 'force' a requirement
                        if [[ $operation_force = true ]]; then
                            Opts.Apps.OpUninstall.ScAll.Set
                            operation=''
                            operation_force=false
                        fi
                        ;;
                    dependent_)
                        Opts.Apps.OpUninstall.ScDependent.Set
                        operation=''
                        operation_force=false
                        ;;
                    standalone_)
                        Opts.Apps.OpUninstall.ScStandalone.Set
                        operation=''
                        operation_force=false
                        ;;
                    started_)
                        Opts.Apps.OpUninstall.IsStarted.Set
                        operation=''
                        operation_force=false
                        ;;
                    stopped_)
                        Opts.Apps.OpUninstall.IsStopped.Set
                        operation=''
                        operation_force=false
                        ;;
                    *)
                        QPKGs.OpToUninstall.Add "$package"
                esac
                ;;
            upgrade_)
                case $scope in
                    all_)
                        Opts.Apps.OpUpgrade.ScAll.Set
                        operation=''
                        ;;
                    dependent_)
                        Opts.Apps.OpUpgrade.ScDependent.Set
                        operation=''
                        ;;
                    standalone_)
                        Opts.Apps.OpUpgrade.ScStandalone.Set
                        operation=''
                        ;;
                    started_)
                        Opts.Apps.OpUpgrade.IsStarted.Set
                        operation=''
                        ;;
                    stopped_)
                        Opts.Apps.OpUpgrade.IsStopped.Set
                        operation=''
                        ;;
                    upgradable_)
                        Opts.Apps.OpUpgrade.ScUpgradable.Set
                        operation=''
                        ;;
                    *)
                        QPKGs.OpToUpgrade.Add "$package"
                esac
        esac
    done

    if [[ -n $operation && $scope_identified = false ]]; then
        case $operation in
            abs_)
                Opts.Help.Abbreviations.Set
                ;;
            backups_)
                Opts.Help.Backups.Set
                ;;
            help_)
                Opts.Help.Basic.Set
                ;;
            options_)
                Opts.Help.Options.Set
                ;;
            packages_)
                Opts.Help.Packages.Set
                ;;
            problems_)
                Opts.Help.Problems.Set
                ;;
            tips_)
                Opts.Help.Tips.Set
                ;;
            versions_)
                Opts.Versions.View.Set
                Session.Display.Clean.Set
        esac
    fi

    if Args.Unknown.IsAny; then
        Opts.Help.Basic.Set
        QPKGs.SkProc.Set
        Session.Display.Clean.Clear
    fi

    DebugFuncExit

    }

ArgumentSuggestions()
    {

    DebugFuncEntry
    local arg=''

    if Args.Unknown.IsAny; then
        ShowAsEror "unknown argument$(Plural "$(Args.Unknown.Count)"): \"$(Args.Unknown.List)\""

        for arg in $(Args.Unknown.Array); do
            case $arg in
                all)
                    Display
                    DisplayAsProjectSyntaxExample "please provide a valid $(FormatAsHelpAction) before 'all' like" 'start all'
                    Opts.Help.Basic.Clear
                    ;;
                all-backup|backup-all)
                    Display
                    DisplayAsProjectSyntaxExample 'to backup all installed package configurations, use' 'backup all'
                    Opts.Help.Basic.Clear
                    ;;
                dependent)
                    Display
                    DisplayAsProjectSyntaxExample "please provide a valid $(FormatAsHelpAction) before 'dependent' like" 'start dependents'
                    Opts.Help.Basic.Clear
                    ;;
                all-restart|restart-all)
                    Display
                    DisplayAsProjectSyntaxExample 'to restart all packages, use' 'restart all'
                    Opts.Help.Basic.Clear
                    ;;
                all-restore|restore-all)
                    Display
                    DisplayAsProjectSyntaxExample 'to restore all installed package configurations, use' 'restore all'
                    Opts.Help.Basic.Clear
                    ;;
                standalone)
                    Display
                    DisplayAsProjectSyntaxExample "please provide a valid $(FormatAsHelpAction) before 'standalone' like" 'start standalones'
                    Opts.Help.Basic.Clear
                    ;;
                all-start|start-all)
                    Display
                    DisplayAsProjectSyntaxExample 'to start all packages, use' 'start all'
                    Opts.Help.Basic.Clear
                    ;;
                all-stop|stop-all)
                    Display
                    DisplayAsProjectSyntaxExample 'to stop all packages, use' 'stop all'
                    Opts.Help.Basic.Clear
                    ;;
                all-uninstall|all-remove|uninstall-all|remove-all)
                    Display
                    DisplayAsProjectSyntaxExample 'to uninstall all packages, use' 'force uninstall all'
                    Opts.Help.Basic.Clear
                    ;;
                all-upgrade|upgrade-all)
                    Display
                    DisplayAsProjectSyntaxExample 'to upgrade all packages, use' 'upgrade all'
                    Opts.Help.Basic.Clear
            esac
        done
    fi

    DebugFuncExit

    }

ApplySensibleExceptions()
    {

    DebugFuncEntry
    local operation=''
    local scope=''
    local state=''
    local prospect=''
    local found=false

    for operation in "${PACKAGE_OPERATIONS[@]}"; do
        # process scope-based user-options
        for scope in "${PACKAGE_SCOPES[@]}"; do
            if Opts.Apps.Op${operation}.Sc${scope}.IsSet; then
                # use sensible scope exceptions (for convenience) rather than follow requested scope literally
                case $operation in
                    Install)
                        case $scope in
                            All)
                                found=true
                                QPKGs.OpTo${operation}.Add "$(QPKGs.IsNtInstalled.Array)"
                                ;;
                            Dependent)
                                found=true
                                for prospect in $(QPKGs.IsNtInstalled.Array); do
                                    QPKGs.ScDependent.Exist "$prospect" && QPKGs.OpTo${operation}.Add "$prospect"
                                done
                                ;;
                            Standalone)
                                found=true
                                for prospect in $(QPKGs.IsNtInstalled.Array); do
                                    QPKGs.ScStandalone.Exist "$prospect" && QPKGs.OpTo${operation}.Add "$prospect"
                                done
                        esac
                        ;;
                    Rebuild)
                        case $scope in
                            All)
                                found=true
                                QPKGs.OpTo${operation}.Add "$(QPKGs.ScSupportBackup.Array)"
                                ;;
                            Dependent)
                                found=true
                                for prospect in $(QPKGs.ScSupportBackup.Array); do
                                    QPKGs.ScDependent.Exist "$prospect" && QPKGs.OpTo${operation}.Add "$prospect"
                                done
                                ;;
                            Standalone)
                                found=true
                                for prospect in $(QPKGs.ScSupportBackup.Array); do
                                    QPKGs.ScStandalone.Exist "$prospect" && QPKGs.OpTo${operation}.Add "$prospect"
                                done
                        esac
                        ;;
                    Restart)
                        case $scope in
                            All)
                                found=true
                                QPKGs.OpTo${operation}.Add "$(QPKGs.IsStarted.Array)"
                                ;;
                            Dependent)
                                found=true
                                for prospect in $(QPKGs.IsStarted.Array); do
                                    QPKGs.ScDependent.Exist "$prospect" && QPKGs.OpTo${operation}.Add "$prospect"
                                done
                                ;;
                            Standalone)
                                found=true
                                for prospect in $(QPKGs.IsStarted.Array); do
                                    QPKGs.ScStandalone.Exist "$prospect" && QPKGs.OpTo${operation}.Add "$prospect"
                                done
                        esac
                        ;;
                    Start)
                        case $scope in
                            All)
                                found=true
                                QPKGs.OpTo${operation}.Add "$(QPKGs.IsStopped.Array)"
                                ;;
                            Dependent)
                                found=true
                                for prospect in $(QPKGs.IsStopped.Array); do
                                    QPKGs.ScDependent.Exist "$prospect" && QPKGs.OpTo${operation}.Add "$prospect"
                                done
                                ;;
                            Standalone)
                                found=true
                                for prospect in $(QPKGs.IsStopped.Array); do
                                    QPKGs.ScStandalone.Exist "$prospect" && QPKGs.OpTo${operation}.Add "$prospect"
                                done
                        esac
                        ;;
                    Stop)
                        case $scope in
                            All)
                                found=true
                                QPKGs.OpTo${operation}.Add "$(QPKGs.IsStarted.Array)"
                                ;;
                            Dependent)
                                found=true
                                for prospect in $(QPKGs.IsStarted.Array); do
                                    QPKGs.ScDependent.Exist "$prospect" && QPKGs.OpTo${operation}.Add "$prospect"
                                done
                                ;;
                            Standalone)
                                found=true
                                for prospect in $(QPKGs.IsStarted.Array); do
                                    QPKGs.ScStandalone.Exist "$prospect" && QPKGs.OpTo${operation}.Add "$prospect"
                                done
                        esac
                        ;;
                    Uninstall)
                        case $scope in
                            All)
                                found=true
                                QPKGs.OpTo${operation}.Add "$(QPKGs.IsInstalled.Array)"
                                ;;
                            Dependent)
                                found=true
                                for prospect in $(QPKGs.IsInstalled.Array); do
                                    QPKGs.ScDependent.Exist "$prospect" && QPKGs.OpTo${operation}.Add "$prospect"
                                done
                                ;;
                            Standalone)
                                found=true
                                for prospect in $(QPKGs.IsInstalled.Array); do
                                    QPKGs.ScStandalone.Exist "$prospect" && QPKGs.OpTo${operation}.Add "$prospect"
                                done
                        esac
                        ;;
                    Upgrade)
                        case $scope in
                            All)
                                found=true
                                QPKGs.OpTo${operation}.Add "$(QPKGs.ScUpgradable.Array)"
                                QPKGs.OpToRestart.Add "$(QPKGs.ScSupportUpdateOnRestart.Array)"
                                QPKGs.OpToRestart.Remove "$(QPKGs.IsNtInstalled.Array) $(QPKGs.OpToUpgrade.Array) $(QPKGs.ScStandalone.Array)"
                                ;;
                            Dependent)
                                found=true
                                for prospect in $(QPKGs.IsInstalled.Array); do
                                    QPKGs.ScDependent.Exist "$prospect" && QPKGs.OpTo${operation}.Add "$prospect"
                                done
                                ;;
                            Standalone)
                                found=true
                                for prospect in $(QPKGs.IsInstalled.Array); do
                                    QPKGs.ScStandalone.Exist "$prospect" && QPKGs.OpTo${operation}.Add "$prospect"
                                done
                        esac
                esac

                [[ $found != true ]] && QPKGs.OpTo${operation}.Add "$(QPKGs.Sc${scope}.Array)" || found=false
            elif Opts.Apps.Op${operation}.ScNt${scope}.IsSet; then
                # use sensible scope exceptions (for convenience) rather than follow requested scope literally
                :

                [[ $found != true ]] && QPKGs.OpTo${operation}.Add "$(QPKGs.ScNt${scope}.Array)" || found=false
            fi
        done

        # process state-based user-options
        for state in "${PACKAGE_STATES[@]}"; do
            if Opts.Apps.Op${operation}.Is${state}.IsSet; then
                # use sensible state exceptions (for convenience) rather than follow requested state literally
                case $operation in
                    Uninstall)
                        case $state in
                            Installed)
                                found=true
                                QPKGs.OpTo${operation}.Add "$(QPKGs.IsInstalled.Array)"
                        esac
                esac

                [[ $found != true ]] && QPKGs.OpTo${operation}.Add "$(QPKGs.Is${state}.Array)" || found=false
            elif Opts.Apps.Op${operation}.IsNt${state}.IsSet; then
                # use sensible state exceptions (for convenience) rather than follow requested state literally
                case $operation in
                    Install)
                        case $state in
                            Installed)
                                found=true
                                QPKGs.OpTo${operation}.Add "$(QPKGs.IsNtInstalled.Array)"
                        esac
                esac

                [[ $found != true ]] && QPKGs.OpTo${operation}.Add "$(QPKGs.IsNt${state}.Array)" || found=false
            fi
        done
    done

    DebugFuncExit

    }

ResetArchivedLogs()
    {

    if [[ -n $LOGS_PATH && -d $LOGS_PATH ]]; then
        rm -rf "${LOGS_PATH:?}"/*
        ShowAsDone 'logs path reset'
    fi

    return 0

    }

ResetWorkPath()
    {

    if [[ -n $WORK_PATH && -d $WORK_PATH ]]; then
        rm -rf "${WORK_PATH:?}"/*
        ShowAsDone 'work path reset'
    fi

    return 0

    }

CleanManagementScript()
    {

    if [[ -n $WORK_PATH && -d $WORK_PATH ]]; then
        rm -f "${WORK_PATH:?}/$($BASENAME_CMD "$0")"
        ShowAsDone 'management script cleaned'
    fi

    return 0

    }

Quiz()
    {

    # input:
    #   $1 = prompt

    # output:
    #   $? = 0 if "y", 1 if anything else

    local response=''

    ShowAsQuiz "${1:-}"
    read -rn1 response
    DebugVar response
    ShowAsQuizDone "${1:-}: $response"

    case ${response:0:1} in
        y|Y)
            return 0
            ;;
        *)
            return 1
    esac

    }

PatchEntwareService()
    {

    local tab=$'\t'
    local prefix="# the following line was inserted by $PROJECT_NAME: https://git.io/$PROJECT_NAME"
    local find=''
    local insert=''
    local -r PACKAGE_INIT_PATHFILE=$(QPKG.ServicePathFile Entware)

    if $GREP_CMD -q 'opt.orig' "$PACKAGE_INIT_PATHFILE"; then
        DebugInfo 'patch: do the "opt shuffle" - already done'
    else
        # ensure existing files are moved out of the way before creating /opt symlink
        find='# sym-link $QPKG_DIR to /opt'
        insert='opt_path="/opt"; opt_backup_path="/opt.orig"; [[ -d "$opt_path" \&\& ! -L "$opt_path" \&\& ! -e "$opt_backup_path" ]] \&\& mv "$opt_path" "$opt_backup_path"'
        $SED_CMD -i "s|$find|$find\n\n${tab}${prefix}\n${tab}${insert}\n|" "$PACKAGE_INIT_PATHFILE"

        # ... then restored after creating /opt symlink
        find='/bin/ln -sf $QPKG_DIR /opt'
        insert='[[ -L "$opt_path" \&\& -d "$opt_backup_path" ]] \&\& cp "$opt_backup_path"/* --target-directory "$opt_path" \&\& rm -r "$opt_backup_path"'
        $SED_CMD -i "s|$find|$find\n\n${tab}${prefix}\n${tab}${insert}\n|" "$PACKAGE_INIT_PATHFILE"

        DebugAsDone 'patch: do the "opt shuffle"'
    fi

    return 0

    }

UpdateEntware()
    {

    if IsNtSysFileExist /opt/bin/opkg; then
        code_pointer=2
        return 1
    fi

    local -r CHANGE_THRESHOLD_MINUTES=60
    local -r LOG_PATHFILE=$LOGS_PATH/entware.$UPDATE_LOG_FILE
    local msgs=''
    local -i result_code=0

    # if Entware package list was recently updated, don't update again. Examine 'change' time as this is updated even if package list content isn't modified.
    if [[ -e $EXTERNAL_PACKAGE_ARCHIVE_PATHFILE && -e $GNU_FIND_CMD ]]; then
        msgs=$($GNU_FIND_CMD "$EXTERNAL_PACKAGE_ARCHIVE_PATHFILE" -cmin +$CHANGE_THRESHOLD_MINUTES) # no-output if last update was less than $CHANGE_THRESHOLD_MINUTES minutes ago
    else
        msgs='new install'
    fi

    if [[ -n $msgs ]]; then
        DebugAsProc "updating $(FormatAsPackageName Entware) package list"

        RunAndLog "/opt/bin/opkg update" "$LOG_PATHFILE" log:failure-only
        result_code=$?

        if [[ $result_code -eq 0 ]]; then
            DebugAsDone "updated $(FormatAsPackageName Entware) package list"
            CloseIPKGArchive
        else
            DebugAsWarn "Unable to update $(FormatAsPackageName Entware) package list $(FormatAsExitcode $result_code)"
            # no-big-deal
        fi
    else
        DebugInfo "$(FormatAsPackageName Entware) package list updated less-than $CHANGE_THRESHOLD_MINUTES minutes ago: skipping update"
    fi

    [[ ! -f $EXTERNAL_PACKAGE_LIST_PATHFILE ]] && OpenIPKGArchive

    return 0

    }

SavePackageLists()
    {

    if [[ -e $pip3_cmd ]]; then
        $pip3_cmd freeze > "$PREVIOUS_PIP_MODULE_LIST"
        DebugAsDone "saved current $(FormatAsPackageName pip3) module list to $(FormatAsFileName "$PREVIOUS_PIP_MODULE_LIST")"
    fi

    if [[ -e /opt/bin/opkg ]]; then
        /opt/bin/opkg list-installed > "$PREVIOUS_OPKG_PACKAGE_LIST"
        DebugAsDone "saved current $(FormatAsPackageName Entware) IPKG list to $(FormatAsFileName "$PREVIOUS_OPKG_PACKAGE_LIST")"
    fi

    }

CalcIPKGsDepsToInstall()
    {

    # From a specified list of IPKG names, find all dependent IPKGs, exclude those already installed, then generate a total qty to download

    if IsNtSysFileExist /opt/bin/opkg || IsNtSysFileExist $GNU_GREP_CMD; then
        code_pointer=3
        return 1
    fi

    DebugFuncEntry
    local -a this_list=()
    local -a dep_acc=()
    local -i requested_count=0
    local -i pre_exclude_count=0
    local -i iterations=0
    local -r ITERATION_LIMIT=20
    local req_list=''
    local pre_exclude_list=''
    local element=''
    local complete=false

    # remove duplicate entries
    req_list=$(DeDupeWords "$(IPKGs.OpToInstall.List)")
    this_list=($req_list)
    requested_count=$($WC_CMD -w <<< "$req_list")

    if [[ $requested_count -eq 0 ]]; then
        DebugAsWarn 'no IPKGs requested: aborting ...'
        DebugFuncExit 1; return
    fi

    ShowAsProc 'calculating IPKG dependencies'
    DebugInfo "$requested_count IPKG$(Plural "$requested_count") requested" "'$req_list' "

    while [[ $iterations -lt $ITERATION_LIMIT ]]; do
        ((iterations++))

        local IPKG_titles=$(printf '^Package: %s$\|' "${this_list[@]}")
        IPKG_titles=${IPKG_titles%??}       # remove last 2 characters

        this_list=($($GNU_GREP_CMD --word-regexp --after-context 1 --no-group-separator '^Package:\|^Depends:' "$EXTERNAL_PACKAGE_LIST_PATHFILE" | $GNU_GREP_CMD -vG '^Section:\|^Version:' | $GNU_GREP_CMD --word-regexp --after-context 1 --no-group-separator "$IPKG_titles" | $GNU_GREP_CMD -vG "$IPKG_titles" | $GNU_GREP_CMD -vG '^Package: ' | $SED_CMD 's|^Depends: ||;s|, |\n|g' | $SORT_CMD | $UNIQ_CMD))

        if [[ ${#this_list[@]} -eq 0 ]]; then
            complete=true
            break
        else
            dep_acc+=(${this_list[*]})
        fi
    done

    if [[ $complete = true ]]; then
        DebugAsDone "complete in $iterations iteration$(Plural $iterations)"
    else
        DebugAsError "incomplete in $iterations iteration$(Plural $iterations), consider raising \$ITERATION_LIMIT [$ITERATION_LIMIT]"
        Session.SuggestIssue.Set
    fi

    # exclude already installed IPKGs
    pre_exclude_list=$(DeDupeWords "$req_list ${dep_acc[*]}")
    pre_exclude_count=$($WC_CMD -w <<< "$pre_exclude_list")

    if [[ $pre_exclude_count -gt 0 ]]; then
        DebugInfo "$pre_exclude_count IPKG$(Plural "$pre_exclude_count") required (including dependencies)" "'$pre_exclude_list' "

        DebugAsProc 'excluding IPKGs already installed'

        for element in $pre_exclude_list; do
            # KLUDGE: 'ca-certs' appears to be a bogus meta-package, so silently exclude it from attempted installation.
            if [[ $element != 'ca-certs' ]]; then
                # KLUDGE: 'libjpeg' appears to have been replaced by 'libjpeg-turbo', but many packages still list 'libjpeg' as a dependency, so replace it with 'libjpeg-turbo'.
                if [[ $element != 'libjpeg' ]]; then
                    if ! /opt/bin/opkg status "$element" | $GREP_CMD -q "Status:.*installed"; then
                        IPKGs.OpToDownload.Add "$element"
                    fi
                elif ! /opt/bin/opkg status 'libjpeg-turbo' | $GREP_CMD -q "Status:.*installed"; then
                    IPKGs.OpToDownload.Add 'libjpeg-turbo'
                fi
            fi
        done
    else
        DebugAsDone 'no IPKGs to exclude'
    fi

    DebugFuncExit

    }

CalcAllIPKGsToUninstall()
    {

    # From a specified list of IPKG names, exclude those already installed, then generate a total qty to uninstall

    if IsNtSysFileExist /opt/bin/opkg || IsNtSysFileExist $GNU_GREP_CMD; then
        code_pointer=4
        return 1
    fi

    DebugFuncEntry
    local req_list=''
    local element=''

    req_list=$(DeDupeWords "$(IPKGs.OpToUninstall.List)")
    DebugInfo "$($WC_CMD -w <<< "$req_list") IPKG$(Plural "$($WC_CMD -w <<< "$req_list")") requested" "'$req_list' "
    DebugAsProc 'excluding IPKGs not installed'

    for element in $req_list; do
        ! /opt/bin/opkg status "$element" | $GREP_CMD -q "Status:.*installed" && IPKGs.OpToUninstall.Remove "$element"
    done

    if [[ $(IPKGs.OpToUninstall.Count) -gt 0 ]]; then
        DebugAsDone "$(IPKGs.OpToUninstall.Count) IPKG$(Plural "$(IPKGs.OpToUninstall.Count)") to uninstall: '$(IPKGs.OpToUninstall.List)'"
    else
        DebugAsDone 'no IPKGs to uninstall'
    fi

    DebugFuncExit

    }

CalcIPKGsDownloadSize()
    {

    # calculate size of required IPKGs

    DebugFuncEntry

    local -a size_array=()
    local -i size_count=0
    size_count=$(IPKGs.OpToDownload.Count)

    if [[ $size_count -gt 0 ]]; then
        DebugAsDone "$size_count IPKG$(Plural "$size_count") to download: '$(IPKGs.OpToDownload.List)'"
        DebugAsProc "calculating size of IPKG$(Plural "$size_count") to download"
        size_array=($($GNU_GREP_CMD -w '^Package:\|^Size:' "$EXTERNAL_PACKAGE_LIST_PATHFILE" | $GNU_GREP_CMD --after-context 1 --no-group-separator ": $($SED_CMD 's/ /$ /g;s/\$ /\$\\\|: /g' <<< "$(IPKGs.OpToDownload.List)")$" | $GREP_CMD '^Size:' | $SED_CMD 's|^Size: ||'))
        IPKGs.OpToDownload.Size = "$(IFS=+; echo "$((${size_array[*]}))")"   # a neat sizing shortcut found here https://stackoverflow.com/a/13635566/6182835
        DebugAsDone "$(FormatAsThousands "$(IPKGs.OpToDownload.Size)") bytes ($(FormatAsISOBytes "$(IPKGs.OpToDownload.Size)")) to download"
    else
        DebugAsDone 'no IPKGs to size'
    fi

    DebugFuncExit

    }

IPKGs.DoUpgrade()
    {

    # upgrade all installed IPKGs

    QPKGs.SkProc.IsSet && return
    IPKGs.ToUpgrade.IsNt && return
    QPKGs.IsNtInstalled.Exist Entware && return
    QPKGs.IsStopped.Exist Entware && return
    UpdateEntware
    Session.Error.IsSet && return
    DebugFuncEntry
    local -i result_code=0
    IPKGs.OpToUpgrade.Init
    IPKGs.OpToDownload.Init

    IPKGs.OpToUpgrade.Add "$(/opt/bin/opkg list-upgradable | cut -f1 -d' ')"
    IPKGs.OpToDownload.Add "$(IPKGs.OpToUpgrade.Array)"

    CalcIPKGsDownloadSize
    local -i total_count=$(IPKGs.OpToDownload.Count)

    if [[ $total_count -gt 0 ]]; then
        ShowAsProc "downloading & upgrading $total_count IPKG$(Plural "$total_count")"

        CreateDirSizeMonitorFlagFile "$IPKG_DL_PATH"/.monitor
            trap CTRL_C_Captured INT
                _MonitorDirSize_ "$IPKG_DL_PATH" "$(IPKGs.OpToDownload.Size)" &

                RunAndLog "/opt/bin/opkg upgrade$(Opts.IgFreeSpace.IsSet && Opts.IgFreeSpace.Text) --force-overwrite $(IPKGs.OpToDownload.List) --cache $IPKG_CACHE_PATH --tmp-dir $IPKG_DL_PATH" "$LOGS_PATH/ipkgs.$UPGRADE_LOG_FILE" log:failure-only
                result_code=$?
            trap - INT
        RemoveDirSizeMonitorFlagFile

        if [[ $result_code -eq 0 ]]; then
            ShowAsDone "downloaded & upgraded $total_count IPKG$(Plural "$total_count")"
        else
            ShowAsFail "download & upgrade $total_count IPKG$(Plural "$total_count") failed $(FormatAsExitcode $result_code)"
        fi
    fi

    DebugFuncExit

    }

IPKGs.DoInstall()
    {

    # install IPKGs required to support QPKGs

    QPKGs.SkProc.IsSet && return
    IPKGs.ToInstall.IsNt && return
    QPKGs.IsNtInstalled.Exist Entware && return
    QPKGs.IsStopped.Exist Entware && return
    UpdateEntware
    Session.Error.IsSet && return
    DebugFuncEntry
    local -i index=0
    local -i result_code=0
    IPKGs.OpToInstall.Init
    IPKGs.OpToDownload.Init

    IPKGs.OpToInstall.Add "$MANAGER_BASE_IPKGS_ADD"
    IPKGs.OpToInstall.Add "$MANAGER_SHARED_IPKGS_ADD"

    if Opts.Apps.OpInstall.ScAll.IsSet; then
        for index in "${!MANAGER_QPKG_NAME[@]}"; do
            [[ ${MANAGER_QPKG_ARCH[$index]} = "$NAS_QPKG_ARCH" || ${MANAGER_QPKG_ARCH[$index]} = all ]] || continue
            IPKGs.OpToInstall.Add "${MANAGER_QPKG_IPKGS_ADD[$index]}"
        done
    else
        for index in "${!MANAGER_QPKG_NAME[@]}"; do
            QPKGs.OpToInstall.Exist "${MANAGER_QPKG_NAME[$index]}" || (QPKGs.IsInstalled.Exist "${MANAGER_QPKG_NAME[$index]}" && QPKGs.IsStarted.Exist "${MANAGER_QPKG_NAME[$index]}") || QPKGs.OpToReinstall.Exist "${MANAGER_QPKG_NAME[$index]}" || QPKGs.OpToStart.Exist "${MANAGER_QPKG_NAME[$index]}" || continue
            [[ ${MANAGER_QPKG_ARCH[$index]} = "$NAS_QPKG_ARCH" || ${MANAGER_QPKG_ARCH[$index]} = all ]] || continue
            QPKG.MinRAM "${MANAGER_QPKG_NAME[$index]}" &>/dev/null || continue
            IPKGs.OpToInstall.Add "${MANAGER_QPKG_IPKGS_ADD[$index]}"
        done
    fi

    CalcIPKGsDepsToInstall
    CalcIPKGsDownloadSize
    local -i total_count=$(IPKGs.OpToDownload.Count)

    if [[ $total_count -gt 0 ]]; then
        ShowAsProc "downloading & installing $total_count IPKG$(Plural "$total_count")"

        CreateDirSizeMonitorFlagFile "$IPKG_DL_PATH"/.monitor
            trap CTRL_C_Captured INT
                _MonitorDirSize_ "$IPKG_DL_PATH" "$(IPKGs.OpToDownload.Size)" &

                RunAndLog "/opt/bin/opkg install$(Opts.IgFreeSpace.IsSet && Opts.IgFreeSpace.Text) --force-overwrite $(IPKGs.OpToDownload.List) --cache $IPKG_CACHE_PATH --tmp-dir $IPKG_DL_PATH" "$LOGS_PATH/ipkgs.addons.$INSTALL_LOG_FILE" log:failure-only
                result_code=$?
            trap - INT
        RemoveDirSizeMonitorFlagFile

        if [[ $result_code -eq 0 ]]; then
            ShowAsDone "downloaded & installed $total_count IPKG$(Plural "$total_count")"
        else
            ShowAsFail "download & install $total_count IPKG$(Plural "$total_count") failed $(FormatAsExitcode $result_code)"
        fi
    fi

    DebugFuncExit

    }

IPKGs.DoUninstall()
    {

    QPKGs.SkProc.IsSet && return
    QPKGs.IsNtInstalled.Exist Entware && return
    QPKGs.IsStopped.Exist Entware && return
    Session.Error.IsSet && return
    DebugFuncEntry
    local -i index=0
    local -i result_code=0

    if Opts.Apps.OpUninstall.ScAll.IsNt; then
        for index in "${!MANAGER_QPKG_NAME[@]}"; do
            if QPKGs.OpToInstall.Exist "${MANAGER_QPKG_NAME[$index]}" || QPKGs.IsInstalled.Exist "${MANAGER_QPKG_NAME[$index]}" || QPKGs.OpToUpgrade.Exist "${MANAGER_QPKG_NAME[$index]}" || QPKGs.OpToUninstall.Exist "${MANAGER_QPKG_NAME[$index]}"; then
                IPKGs.OpToUninstall.Add "${MANAGER_QPKG_IPKGS_REMOVE[$index]}"
            fi
        done
    fi

    CalcAllIPKGsToUninstall
    local -i total_count=$(IPKGs.OpToUninstall.Count)

    if [[ $total_count -gt 0 ]]; then
        ShowAsProc "uninstalling $total_count IPKG$(Plural "$total_count")"

        RunAndLog "/opt/bin/opkg remove $(IPKGs.OpToUninstall.List) --force-depends" "$LOGS_PATH/ipkgs.$UNINSTALL_LOG_FILE" log:failure-only
        result_code=$?

        if [[ $result_code -eq 0 ]]; then
            ShowAsDone "uninstalled $total_count IPKG$(Plural "$total_count")"
        else
            ShowAsFail "uninstall IPKG$(Plural "$total_count") failed $(FormatAsExitcode $result_code)"
        fi
    fi

    DebugFuncExit

    }

PIPs.DoInstall()
    {

    QPKGs.SkProc.IsSet && return
    QPKGs.IsNtInstalled.Exist Entware && return
    QPKGs.IsStopped.Exist Entware && return
    Session.Error.IsSet && return
    DebugFuncEntry
    local exec_cmd=''
    local -i result_code=0
    local -i pass_count=0
    local -i fail_count=0
    local -i total_count=3
    local -r PACKAGE_TYPE='PIP group'
    local -r ACTION_PRESENT=installing
    local -r ACTION_PAST=installed
    local -r RUNTIME=long

    # sometimes, 'pip3' goes missing from Entware. Don't know why.
    if [[ -e /opt/bin/pip3 ]]; then
        pip3_cmd=/opt/bin/pip3
    elif [[ -e /opt/bin/pip3.9 ]]; then
        pip3_cmd=/opt/bin/pip3.9
    elif [[ -e /opt/bin/pip3.8 ]]; then
        pip3_cmd=/opt/bin/pip3.8
    elif [[ -e /opt/bin/pip3.7 ]]; then
        pip3_cmd=/opt/bin/pip3.7
    else
        if IsNtSysFileExist $pip3_cmd; then
            Display "* Ugh! The usual fix for this is to let $(FormatAsScriptTitle) reinstall $(FormatAsPackageName Entware) at least once."
            Display "\t$0 reinstall ew"
            Display "If it happens again after reinstalling $(FormatAsPackageName Entware), please create a new issue for this on GitHub."
            DebugFuncExit 1; return
        fi
    fi

    ModPathToEntware

    if Opts.Deps.Check.IsSet || QPKGs.OpOkInstall.Exist Entware; then
        ShowAsOperationProgress '' "$PACKAGE_TYPE" "$pass_count" "$fail_count" "$total_count" "$ACTION_PRESENT" "$RUNTIME"

        exec_cmd="$pip3_cmd install --upgrade $MANAGER_SHARED_PIPS_ADD --cache-dir $PIP_CACHE_PATH"
        local desc="'Python3' modules"
        local log_pathfile=$LOGS_PATH/py3-modules.assorted.$INSTALL_LOG_FILE
        DebugAsProc "downloading & installing $desc"

        RunAndLog "$exec_cmd" "$log_pathfile" log:failure-only
        result_code=$?

        if [[ $result_code -eq 0 ]]; then
            DebugAsDone "downloaded & installed $desc"
            ((pass_count++))
        else
            ShowAsFail "download & install $desc failed $(FormatAsResult "$result_code")"
            ((fail_count++))
        fi
    else
        ((total_count--))
    fi

    if (Opts.Deps.Check.IsSet && QPKGs.IsInstalled.Exist SABnzbd) || QPKGs.OpToInstall.Exist SABnzbd || QPKGs.OpToReinstall.Exist SABnzbd; then
        # KLUDGE: force recompilation of 'sabyenc3' package so it's recognised by SABnzbd: https://forums.sabnzbd.org/viewtopic.php?p=121214#p121214
        ShowAsOperationProgress '' "$PACKAGE_TYPE" "$pass_count" "$fail_count" "$total_count" "$ACTION_PRESENT" "$RUNTIME"

        exec_cmd="$pip3_cmd install --force-reinstall --ignore-installed --no-binary :all: sabyenc3 --disable-pip-version-check --cache-dir $PIP_CACHE_PATH"
        desc="'Python3 sabyenc3' module"
        log_pathfile=$LOGS_PATH/py3-modules.sabyenc3.$INSTALL_LOG_FILE
        DebugAsProc "downloading & installing $desc"

        RunAndLog "$exec_cmd" "$log_pathfile" log:failure-only
        result_code=$?

        if [[ $result_code -eq 0 ]]; then
            DebugAsDone "downloaded & installed $desc"
            QPKGs.OpToRestart.Add SABnzbd
            ((pass_count++))
        else
            ShowAsEror "download & install $desc failed $(FormatAsResult "$result_code")"
            ((fail_count++))
        fi
    else
        ((total_count--))
    fi

    if Opts.Deps.Check.IsSet || IPKGs.OpToInstall.Exist python3-cryptography || QPKGs.OpToInstall.Exist SABnzbd || QPKGs.OpToReinstall.Exist SABnzbd; then
        # KLUDGE: must ensure 'cryptography' PIP module is reinstalled if the 'python3-cryptography' IPKG is installed.
        # The 'deluge-ui-web' IPKG pulls-in 'python3-cryptography' IPKG as a dependency, but this then causes a launch-failure for 'deluge-web' due to there already being a later 'cryptography' installed via 'pip'. Prefer to use the 'pip' version, so need to reinstall it so it is seen first.
        # KLUDGE: ensure 'feedparser' is upgraded. This was version-held at 5.2.1 for Python 3.8.5 but from Python 3.9.0 onward there's no-need for version-hold anymore.
        ShowAsOperationProgress '' "$PACKAGE_TYPE" "$pass_count" "$fail_count" "$total_count" "$ACTION_PRESENT" "$RUNTIME"

        exec_cmd="$pip3_cmd install --upgrade --force-reinstall cryptography feedparser --cache-dir $PIP_CACHE_PATH"
        desc="'Python3 cryptography & feedparser' modules"
        log_pathfile=$LOGS_PATH/py3-modules.cryptography-feedparser.$REINSTALL_LOG_FILE
        DebugAsProc "reinstalling $desc"
        RunAndLog "$exec_cmd" "$log_pathfile" log:failure-only
        result_code=$?

        if [[ $result_code -eq 0 ]]; then
            DebugAsDone "reinstalled $desc"
            QPKGs.OpToRestart.Add SABnzbd
            ((pass_count++))
        else
            ShowAsFail "reinstallation of $desc failed $(FormatAsResult "$result_code")"
            ((fail_count++))
        fi
    else
        ((total_count--))
    fi

    # execute with pass_count > total_count to trigger 100% message
    ShowAsOperationProgress '' "$PACKAGE_TYPE" "$((total_count+1))" "$fail_count" "$total_count" "$ACTION_PRESENT" "$RUNTIME"

    ShowAsOperationResult '' "$PACKAGE_TYPE" "$pass_count" "$fail_count" "$total_count" "$ACTION_PAST" "$RUNTIME"
    DebugFuncExit $result_code

    }

OpenIPKGArchive()
    {

    # extract the 'opkg' package list file

    # output:
    #   $? = 0 if successful or 1 if failed

    if [[ ! -e $EXTERNAL_PACKAGE_ARCHIVE_PATHFILE ]]; then
        ShowAsEror 'unable to locate the IPKG list file'
        DebugFuncExit 1; return
    fi

    RunAndLog "/usr/local/sbin/7z e -o$($DIRNAME_CMD "$EXTERNAL_PACKAGE_LIST_PATHFILE") $EXTERNAL_PACKAGE_ARCHIVE_PATHFILE" "$WORK_PATH/ipkg.list.archive.extract" log:failure-only
    result_code=$?

    if [[ ! -e $EXTERNAL_PACKAGE_LIST_PATHFILE ]]; then
        ShowAsEror 'unable to open the IPKG list file'
        DebugFuncExit 1; return
    fi

    return 0

    }

CloseIPKGArchive()
    {

    [[ -f $EXTERNAL_PACKAGE_LIST_PATHFILE ]] && rm -f "$EXTERNAL_PACKAGE_LIST_PATHFILE"

    }

_MonitorDirSize_()
    {

    # * This function runs autonomously *
    # It watches for the existence of $MONITOR_FLAG_PATHFILE
    # If that file is removed, this function dies gracefully

    # input:
    #   $1 = directory to monitor the size of
    #   $2 = total target bytes (100%) for specified path

    # output:
    #   stdout = "percentage downloaded (downloaded bytes/total expected bytes)"

    [[ -z $1 || ! -d $1 || -z $2 || $2 -eq 0 ]] && return
    IsNtSysFileExist $GNU_FIND_CMD && return

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

    while [[ -e $MONITOR_FLAG_PATHFILE ]]; do
        current_bytes=$($GNU_FIND_CMD "$1" -type f -name '*.ipk' -exec $DU_CMD --bytes --total --apparent-size {} + 2>/dev/null | $GREP_CMD total$ | cut -f1)
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
            # append a message showing stalled time
            if [[ $stall_seconds -lt 60 ]]; then
                stall_message=" stalled for $stall_seconds seconds"
            else
                stall_message=" stalled for $(ConvertSecsToHoursMinutesSecs $stall_seconds)"
            fi

            # add a suggestion to cancel if download has stalled for too long
            if [[ $stall_seconds -ge 90 ]]; then
                stall_message+=': cancel with CTRL+C and try again later'
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

    this_clean_msg=$(StripANSI "${1:-}")

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

    [[ -z ${MONITOR_FLAG_PATHFILE:-} ]] && readonly MONITOR_FLAG_PATHFILE=${1:?empty}
    $TOUCH_CMD "$MONITOR_FLAG_PATHFILE"

    }

RemoveDirSizeMonitorFlagFile()
    {

    if [[ -f $MONITOR_FLAG_PATHFILE ]]; then
        rm -f "$MONITOR_FLAG_PATHFILE"
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

    if location=$(command -v "${1:?empty}" 2>&1); then
        DebugUserspaceOK "'$1' path" "$location"

        if version=$($1 -V 2>&1 | $SED_CMD 's|^Python ||'); then
            if [[ ${version//./} -ge $MIN_PYTHON_VER ]]; then
                DebugUserspaceOK "'$1' version" "$version"
            else
                DebugUserspaceWarning "'$1' version" "$version"
            fi
        else
            DebugUserspaceWarning "default '$1' version" ' '
        fi
    else
        DebugUserspaceWarning "'$1' path" ' '
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
    fi

    return 0

    }

IsNtSysFileExist()
    {

    # input:
    #   $1 = pathfile to check

    # output:
    #   $? = 0 (true) or 1 (false)

    ! IsSysFileExist "${1:?empty}"

    }

readonly HELP_DESC_INDENT=3
readonly HELP_SYNTAX_INDENT=6
readonly HELP_PACKAGE_NAME_WIDTH=18
readonly HELP_PACKAGE_VERSION_WIDTH=15
readonly HELP_FILE_NAME_WIDTH=33

DisplayAsProjectSyntaxExample()
    {

    # $1 = description
    # $2 = example syntax

    if [[ ${1: -1} = '!' ]]; then
        printf "* %s \n%${HELP_SYNTAX_INDENT}s# %s\n" "$(tr 'a-z' 'A-Z' <<< "${1:0:1}")${1:1}" '' "$PROJECT_NAME $2"
    else
        printf "* %s:\n%${HELP_SYNTAX_INDENT}s# %s\n" "$(tr 'a-z' 'A-Z' <<< "${1:0:1}")${1:1}" '' "$PROJECT_NAME $2"
    fi

    Session.LineSpace.Clear

    }

DisplayAsProjectSyntaxIndentedExample()
    {

    # $1 = description
    # $2 = example syntax

    if [[ -z ${1:-} ]]; then
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

DisplayAsHelpTitlePackageNamePlusSomething()
    {

    # $1 = package name title
    # $2 = second column title

    printf "* %-${HELP_PACKAGE_NAME_WIDTH}s * %s\n" "$(tr 'a-z' 'A-Z' <<< "${1:0:1}")${1:1}:" "$(tr 'a-z' 'A-Z' <<< "${2:0:1}")${2:1}:"

    }

DisplayAsHelpPackageNamePlusSomething()
    {

    # $1 = package name
    # $2 = second column text

    printf "%${HELP_DESC_INDENT}s%-${HELP_PACKAGE_NAME_WIDTH}s - %s\n" '' "${1:-}" "${2:-}"

    }

DisplayAsHelpTitlePackageNameVersionStatus()
    {

    # $1 = package name title
    # $2 = package version title
    # $3 = package status title

    printf "* %-${HELP_PACKAGE_NAME_WIDTH}s * %-${HELP_PACKAGE_VERSION_WIDTH}s * %s\n" "$(tr 'a-z' 'A-Z' <<< "${1:0:1}")${1:1}:" "$(tr 'a-z' 'A-Z' <<< "${2:0:1}")${2:1}:" "$(tr 'a-z' 'A-Z' <<< "${3:0:1}")${3:1}:"
    }

DisplayAsHelpPackageNameVersionStatus()
    {

    # $1 = package name
    # $2 = package version number
    # $3 = package status

    printf "%${HELP_DESC_INDENT}s%-${HELP_PACKAGE_NAME_WIDTH}s - %-${HELP_PACKAGE_VERSION_WIDTH}s - %s\n" '' "${1:-}" "${2:-}" "${3:-}"

    }

DisplayAsHelpTitleFileNamePlusSomething()
    {

    # $1 = file name title
    # $2 = second column title

    printf "* %-${HELP_FILE_NAME_WIDTH}s * %s\n" "$(tr 'a-z' 'A-Z' <<< "${1:0:1}")${1:1}:" "$(tr 'a-z' 'A-Z' <<< "${2:0:1}")${2:1}:"

    }

DisplayAsHelpTitle()
    {

    # $1 = text (will be capitalised)

    printf "* %s\n" "$(tr 'a-z' 'A-Z' <<< "${1:0:1}")${1:1}"

    }

DisplayAsHelpTitleHighlighted()
    {

    # $1 = text (will be capitalised)

    # shellcheck disable=2059
    printf "$(ColourTextBrightOrange "* %s\n")" "$(tr 'a-z' 'A-Z' <<< "${1:0:1}")${1:1}"

    }

SmartCR()
    {

    # reset cursor to start-of-line, erasing previous characters

    [[ $(type -t Session.Debug.ToScreen.Init) = function ]] && Session.Debug.ToScreen.IsSet && return

    echo -en "\033[1K\r"

    }

Display()
    {

    echo -e "${1:-}"
    [[ $(type -t Session.LineSpace.Init) = function ]] && Session.LineSpace.Clear

    }

DisplayWait()
    {

    echo -en "${1:-} "

    }

Help.Basic.Show()
    {

    SmartCR
    DisplayLineSpaceIfNoneAlready
    Display "Usage: $PROJECT_NAME $(FormatAsHelpAction) $(FormatAsHelpPackages) $(FormatAsHelpAction) $(FormatAsHelpPackages) ... $(FormatAsHelpOptions)"

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

    DisableDebugToArchiveAndFile
    Help.Basic.Show
    DisplayLineSpaceIfNoneAlready
    DisplayAsHelpTitle "$(FormatAsHelpAction) usage examples:"
    DisplayAsProjectSyntaxIndentedExample 'show package statuses' 'status'
    DisplayAsProjectSyntaxIndentedExample 'install these packages' "install $(FormatAsHelpPackages)"
    DisplayAsProjectSyntaxIndentedExample 'uninstall these packages' "uninstall $(FormatAsHelpPackages)"
    DisplayAsProjectSyntaxIndentedExample 'reinstall these packages' "reinstall $(FormatAsHelpPackages)"
    DisplayAsProjectSyntaxIndentedExample "rebuild these packages ('install' packages, then 'restore' configuration backups)" "rebuild $(FormatAsHelpPackages)"
    DisplayAsProjectSyntaxIndentedExample 'upgrade these packages (and internal applications)' "upgrade $(FormatAsHelpPackages)"
    DisplayAsProjectSyntaxIndentedExample 'start these packages' "start $(FormatAsHelpPackages)"
    DisplayAsProjectSyntaxIndentedExample 'stop these packages' "stop $(FormatAsHelpPackages)"
    DisplayAsProjectSyntaxIndentedExample 'restart these packages' "restart $(FormatAsHelpPackages)"
    DisplayAsProjectSyntaxIndentedExample 'backup these application configurations to the backup location' "backup $(FormatAsHelpPackages)"
    DisplayAsProjectSyntaxIndentedExample 'restore these application configurations from the backup location' "restore $(FormatAsHelpPackages)"
    DisplayAsProjectSyntaxIndentedExample 'show application backup files' 'list backups'
    Display
    DisplayAsProjectSyntaxExample "$(FormatAsHelpAction)s to affect all packages can be seen with" 'all-actions'
    Display
    DisplayAsProjectSyntaxExample "multiple $(FormatAsHelpAction)s are supported like this" "$(FormatAsHelpAction) $(FormatAsHelpPackages) $(FormatAsHelpAction) $(FormatAsHelpPackages)"
    DisplayAsProjectSyntaxIndentedExample '' 'install sabnzbd sickchill restart transmission uninstall lazy nzbget upgrade nzbtomedia'

    return 0

    }

Help.ActionsAll.Show()
    {

    DisableDebugToArchiveAndFile
    Help.Basic.Show
    DisplayLineSpaceIfNoneAlready
    Display "* These $(FormatAsHelpAction)s apply to all installed packages. If $(FormatAsHelpAction) is 'install all' then all available packages will be installed."
    DisplayLineSpaceIfNoneAlready
    DisplayAsHelpTitle "$(FormatAsHelpAction) usage examples:"
    DisplayAsProjectSyntaxIndentedExample 'show package statuses' 'status'
    DisplayAsProjectSyntaxIndentedExample 'install everything!' 'install all'
    DisplayAsProjectSyntaxIndentedExample 'uninstall everything!' 'force uninstall all'
    DisplayAsProjectSyntaxIndentedExample 'reinstall all installed packages' 'reinstall all'
    DisplayAsProjectSyntaxIndentedExample "rebuild all packages with backups ('install' packages and 'restore' backups)" 'rebuild all'
    DisplayAsProjectSyntaxIndentedExample 'upgrade all installed packages (and internal applications)' 'upgrade all'
    DisplayAsProjectSyntaxIndentedExample 'start all installed packages (upgrade internal applications, not packages)' 'start all'
    DisplayAsProjectSyntaxIndentedExample 'stop all installed packages' 'stop all'
    DisplayAsProjectSyntaxIndentedExample 'restart packages that are able to upgrade their internal applications' 'restart all'
    DisplayAsProjectSyntaxIndentedExample 'list all available packages' 'list all'
    DisplayAsProjectSyntaxIndentedExample 'list only installed packages' 'list installed'
    DisplayAsProjectSyntaxIndentedExample 'list only packages that can be installed' 'list installable'
    DisplayAsProjectSyntaxIndentedExample 'list only packages that are not installed' 'list not-installed'
    DisplayAsProjectSyntaxIndentedExample 'list only upgradable packages' 'list upgradable'
    DisplayAsProjectSyntaxIndentedExample 'backup all application configurations to the backup location' 'backup all'
    DisplayAsProjectSyntaxIndentedExample 'restore all application configurations from the backup location' 'restore all'

    return 0

    }

Help.Packages.Show()
    {

    local tier=''
    local package=''

    DisableDebugToArchiveAndFile
    Help.Basic.Show
    Display
    DisplayAsHelpTitle "One-or-more $(FormatAsHelpPackages) may be specified at-once"
    Display

    for tier in Standalone Dependent; do
        DisplayAsHelpTitlePackageNamePlusSomething "$tier QPKGs" 'package description'

        for package in $(QPKGs.Sc${tier}.Array); do
            DisplayAsHelpPackageNamePlusSomething "$package" "$(QPKG.Desc "$package")"
        done

        Display
    done

    DisplayAsProjectSyntaxExample "abbreviations may also be used to specify $(FormatAsHelpPackages). To list these" 'list abs'

    return 0

    }

Help.Options.Show()
    {

    DisableDebugToArchiveAndFile
    Help.Basic.Show
    DisplayLineSpaceIfNoneAlready
    DisplayAsHelpTitle "$(FormatAsHelpOptions) usage examples:"
    DisplayAsProjectSyntaxIndentedExample 'process one-or-more packages and show live debugging information' "$(FormatAsHelpAction) $(FormatAsHelpPackages) debug"
    DisplayAsProjectSyntaxIndentedExample "don't check free-space on target filesystem when installing $(FormatAsPackageName Entware) packages" "$(FormatAsHelpAction) $(FormatAsHelpPackages) ignore-space"
    DisplayAsProjectSyntaxIndentedExample 'display helpful tips and shortcuts' 'tips'
    DisplayAsProjectSyntaxIndentedExample 'display troubleshooting options' 'problems'

    return 0

    }

Help.Problems.Show()
    {

    DisableDebugToArchiveAndFile
    Help.Basic.Show
    DisplayLineSpaceIfNoneAlready
    DisplayAsHelpTitle 'usage examples when dealing with problems:'
    DisplayAsProjectSyntaxIndentedExample 'process one-or-more packages and show live debugging information' "$(FormatAsHelpAction) $(FormatAsHelpPackages) debug"
    DisplayAsProjectSyntaxIndentedExample 'ensure all application dependencies are installed' 'check'
    DisplayAsProjectSyntaxIndentedExample "don't check free-space on target filesystem when installing $(FormatAsPackageName Entware) packages" "$(FormatAsHelpAction) $(FormatAsHelpPackages) ignore-space"
    DisplayAsProjectSyntaxIndentedExample "clear the locally cached $(FormatAsScriptTitle) management script" 'clean'
    DisplayAsProjectSyntaxIndentedExample 'clear all downloaded items in local cache and remove all logs' 'reset'
    DisplayAsProjectSyntaxIndentedExample 'restart all installed packages (upgrades the internal applications, not packages)' 'restart all'
    DisplayAsProjectSyntaxIndentedExample 'start these packages and enable package icons' "start $(FormatAsHelpPackages)"
    DisplayAsProjectSyntaxIndentedExample 'stop these packages and disable package icons' "stop $(FormatAsHelpPackages)"
    DisplayAsProjectSyntaxIndentedExample "view only the most recent $(FormatAsScriptTitle) session log" 'l'
    DisplayAsProjectSyntaxIndentedExample "view the entire $(FormatAsScriptTitle) session log" 'log'
    DisplayAsProjectSyntaxIndentedExample "upload the most-recent session in your $(FormatAsScriptTitle) log to the $(FormatAsURL 'https://termbin.com') public pastebin. A URL will be generated afterward" 'p'
    DisplayAsProjectSyntaxIndentedExample "upload the most-recent $(FormatAsThousands "$LOG_TAIL_LINES") entries in your $(FormatAsScriptTitle) log to the $(FormatAsURL 'https://termbin.com') public pastebin. A URL will be generated afterward" 'paste'
    Display
    DisplayAsHelpTitleHighlighted "If you need help, please include a copy of your $(FormatAsScriptTitle) $(ColourTextBrightOrange "log for analysis!")"

    return 0

    }

Help.Issue.Show()
    {

    DisplayLineSpaceIfNoneAlready
    DisplayAsHelpTitle "please consider creating a new issue for this on GitHub:\n\thttps://github.com/OneCDOnly/$PROJECT_NAME/issues"
    Display
    DisplayAsHelpTitle "alternatively, post on the QNAP NAS Community Forum:\n\thttps://forum.qnap.com/viewtopic.php?f=320&t=132373"
    DisplayAsProjectSyntaxIndentedExample "view only the most recent $(FormatAsScriptTitle) session log" 'last'
    DisplayAsProjectSyntaxIndentedExample "view the entire $(FormatAsScriptTitle) session log" 'log'
    DisplayAsProjectSyntaxIndentedExample "upload the most-recent $(FormatAsThousands "$LOG_TAIL_LINES") entries in your $(FormatAsScriptTitle) log to the $(FormatAsURL 'https://termbin.com') public pastebin. A URL will be generated afterward" 'paste'
    Display
    DisplayAsHelpTitleHighlighted "If you need help, please include a copy of your $(FormatAsScriptTitle) $(ColourTextBrightOrange "log for analysis!")"

    return 0

    }

Help.Tips.Show()
    {

    DisableDebugToArchiveAndFile
    Help.Basic.Show
    DisplayLineSpaceIfNoneAlready
    DisplayAsHelpTitle 'helpful tips and shortcuts:'
    DisplayAsProjectSyntaxIndentedExample "install all available $(FormatAsScriptTitle) packages" 'install all'
    DisplayAsProjectSyntaxIndentedExample 'package abbreviations also work. To see these' 'list abs'
    DisplayAsProjectSyntaxIndentedExample 'restart all packages (only upgrades the internal applications, not packages)' 'restart all'
    DisplayAsProjectSyntaxIndentedExample 'list only packages that can be installed' 'list installable'
    DisplayAsProjectSyntaxIndentedExample "view only the most recent $(FormatAsScriptTitle) session log" 'l'
    DisplayAsProjectSyntaxIndentedExample 'start all stopped packages' 'start stopped'
    DisplayAsProjectSyntaxIndentedExample 'upgrade the internal applications only' "restart $(FormatAsHelpPackages)"
    Help.BackupLocation.Show

    return 0

    }

Help.PackageAbbreviations.Show()
    {

    local tier=''
    local package=''
    local abs=''

    DisableDebugToArchiveAndFile
    Help.Basic.Show
    Display
    DisplayAsHelpTitle "$(FormatAsScriptTitle) can recognise various abbreviations as $(FormatAsHelpPackages)"
    Display

    for tier in Standalone Dependent; do
        DisplayAsHelpTitlePackageNamePlusSomething "$tier QPKGs" 'acceptable package name abreviations'

        for package in $(QPKGs.Sc${tier}.Array); do
            abs=$(QPKG.Abbrvs "$package")
            [[ -n $abs ]] && DisplayAsHelpPackageNamePlusSomething "$package" "${abs// /, }"
        done

        Display
    done

    DisplayAsProjectSyntaxExample "example: to install $(FormatAsPackageName SABnzbd), $(FormatAsPackageName Mylar3) and $(FormatAsPackageName nzbToMedia) all-at-once" 'install sab my nzb2'

    return 0

    }

Help.BackupLocation.Show()
    {

    DisplayAsSyntaxExample 'the backup location can be accessed by running' "cd $BACKUP_PATH"

    return 0

    }

Log.All.View()
    {

    # view the entire archived sessions log

    DisableDebugToArchiveAndFile

    if [[ -e $SESSION_ARCHIVE_PATHFILE ]]; then
        if [[ -e /opt/bin/less ]]; then
            LESSSECURE=1 /opt/bin/less +G --quit-on-intr --tilde --LINE-NUMBERS --prompt ' use arrow-keys to scroll up-down left-right, press Q to quit' "$SESSION_ARCHIVE_PATHFILE"
        elif [[ -e /bin/less ]]; then
            /bin/less -N~ "$SESSION_ARCHIVE_PATHFILE"
        else
            $CAT_CMD --number "$SESSION_ARCHIVE_PATHFILE"
        fi
    else
        ShowAsEror 'no session log to display'
    fi

    return 0

    }

Log.Last.View()
    {

    # view only the last session log

    DisableDebugToArchiveAndFile
    ExtractPreviousSessionFromTail

    if [[ -e $SESSION_LAST_PATHFILE ]]; then
        if [[ -e /opt/bin/less ]]; then
            LESSSECURE=1 /opt/bin/less +G --quit-on-intr --tilde --LINE-NUMBERS --prompt ' use arrow-keys to scroll up-down left-right, press Q to quit' "$SESSION_LAST_PATHFILE"
        elif [[ -e /bin/less ]]; then
            /bin/less -N~ "$SESSION_LAST_PATHFILE"
        else
            $CAT_CMD --number "$SESSION_LAST_PATHFILE"
        fi
    else
        ShowAsEror 'no last session log to display'
    fi

    return 0

    }

Log.Tail.View()
    {

    # view only the last session log

    DisableDebugToArchiveAndFile
    ExtractTailFromLog

    if [[ -e $SESSION_TAIL_PATHFILE ]]; then
        if [[ -e /opt/bin/less ]]; then
            LESSSECURE=1 /opt/bin/less +G --quit-on-intr --tilde --LINE-NUMBERS --prompt ' use arrow-keys to scroll up-down left-right, press Q to quit' "$SESSION_TAIL_PATHFILE"
        elif [[ -e /bin/less ]]; then
            /bin/less -N~ "$SESSION_TAIL_PATHFILE"
        else
            $CAT_CMD --number "$SESSION_TAIL_PATHFILE"
        fi
    else
        ShowAsEror 'no session log tail to display'
    fi

    return 0

    }

Log.All.Paste()
    {

    DisableDebugToArchiveAndFile

    if [[ -e $SESSION_ARCHIVE_PATHFILE ]]; then
        if Quiz "Press 'Y' to post your ENTIRE $(FormatAsScriptTitle) log to a public pastebin, or any other key to abort"; then
            ShowAsProc "uploading $(FormatAsScriptTitle) log"
            # with thanks to https://github.com/solusipse/fiche
            link=$($CAT_CMD --number "$SESSION_ARCHIVE_PATHFILE" | (exec 3<>/dev/tcp/termbin.com/9999; $CAT_CMD >&3; $CAT_CMD <&3; exec 3<&-))

            if [[ $? -eq 0 ]]; then
                ShowAsDone "your $(FormatAsScriptTitle) log is now online at $(FormatAsURL "$link") and will be deleted in 1 month"
            else
                ShowAsFail "a link could not be generated. Most likely a problem occurred when talking with $(FormatAsURL 'https://termbin.com')"
            fi
        else
            DebugInfoMinorSeparator
            DebugScript 'user abort'
            Session.Summary.Clear
            return 1
        fi
    else
        ShowAsEror 'no session log found'
    fi

    return 0

    }

Log.Last.Paste()
    {

    DisableDebugToArchiveAndFile
    ExtractPreviousSessionFromTail

    if [[ -e $SESSION_LAST_PATHFILE ]]; then
        if Quiz "Press 'Y' to post the most-recent session in your $(FormatAsScriptTitle) log to a public pastebin, or any other key to abort"; then
            ShowAsProc "uploading $(FormatAsScriptTitle) log"
            # with thanks to https://github.com/solusipse/fiche
            link=$($CAT_CMD --number "$SESSION_LAST_PATHFILE" | (exec 3<>/dev/tcp/termbin.com/9999; $CAT_CMD >&3; $CAT_CMD <&3; exec 3<&-))

            if [[ $? -eq 0 ]]; then
                ShowAsDone "your $(FormatAsScriptTitle) log is now online at $(FormatAsURL "$link") and will be deleted in 1 month"
            else
                ShowAsFail "a link could not be generated. Most likely a problem occurred when talking with $(FormatAsURL 'https://termbin.com')"
            fi
        else
            DebugInfoMinorSeparator
            DebugScript 'user abort'
            Session.Summary.Clear
            return 1
        fi
    else
        ShowAsEror 'no last session log found'
    fi

    return 0

    }

Log.Tail.Paste()
    {

    DisableDebugToArchiveAndFile
    ExtractTailFromLog

    if [[ -e $SESSION_TAIL_PATHFILE ]]; then
        if Quiz "Press 'Y' to post the most-recent $(FormatAsThousands "$LOG_TAIL_LINES") entries in your $(FormatAsScriptTitle) log to a public pastebin, or any other key to abort"; then
            ShowAsProc "uploading $(FormatAsScriptTitle) log"
            # with thanks to https://github.com/solusipse/fiche
            link=$($CAT_CMD --number "$SESSION_TAIL_PATHFILE" | (exec 3<>/dev/tcp/termbin.com/9999; $CAT_CMD >&3; $CAT_CMD <&3; exec 3<&-))

            if [[ $? -eq 0 ]]; then
                ShowAsDone "your $(FormatAsScriptTitle) log is now online at $(FormatAsURL "$link") and will be deleted in 1 month"
            else
                ShowAsFail "a link could not be generated. Most likely a problem occurred when talking with $(FormatAsURL 'https://termbin.com')"
            fi
        else
            DebugInfoMinorSeparator
            DebugScript 'user abort'
            Session.Summary.Clear
            return 1
        fi
    else
        ShowAsEror 'no session log tail found'
    fi

    return 0

    }

GetLogSessionStartLine()
    {

    # $1 = how many sessions back? (optional) default = 1

    local -i linenum=$(($($GREP_CMD -n 'SCRIPT:.*started:' "$SESSION_TAIL_PATHFILE" | $TAIL_CMD -n${1:-1} | $HEAD_CMD -n1 | cut -d':' -f1)-1))
    [[ $linenum -lt 1 ]] && linenum=1
    echo $linenum

    }

GetLogSessionFinishLine()
    {

    # $1 = how many sessions back? (optional) default = 1

    local -i linenum=$(($($GREP_CMD -n 'SCRIPT:.*finished:' "$SESSION_TAIL_PATHFILE" | $TAIL_CMD -n${1:-1} | cut -d':' -f1)+2))
    [[ $linenum -eq 2 ]] && linenum=3
    echo $linenum

    }

ArchiveActiveSessionLog()
    {

    [[ -e $SESSION_ACTIVE_PATHFILE ]] && $CAT_CMD "$SESSION_ACTIVE_PATHFILE" >> "$SESSION_ARCHIVE_PATHFILE"

    }

ArchivePriorSessionLogs()
    {

    # check for incomplete previous session logs (crashed, interrupted?) and save to archive

    local log_pathfile=''

    for log_pathfile in "$PROJECT_PATH/session."*".active.log"; do
        if [[ -f $log_pathfile && $log_pathfile != "$SESSION_ACTIVE_PATHFILE" ]]; then
            $CAT_CMD "$log_pathfile" >> "$SESSION_ARCHIVE_PATHFILE"
            rm -f "$log_pathfile"
        fi
    done

    }

ResetActiveSessionLog()
    {

    [[ -e $SESSION_ACTIVE_PATHFILE ]] && rm -f "$SESSION_ACTIVE_PATHFILE"

    }

ExtractPreviousSessionFromTail()
    {

    local -i start_line=0
    local -i end_line=0
    local -i old_session=1
    local -i old_session_limit=12   # don't try to find 'started:' any further back than this many sessions

    ExtractTailFromLog

    if [[ -e $SESSION_TAIL_PATHFILE ]]; then
        end_line=$(GetLogSessionFinishLine "$old_session")
        start_line=$((end_line+1))      # ensure an invalid condition, to be solved by the loop

        while [[ $start_line -ge $end_line ]]; do
            start_line=$(GetLogSessionStartLine "$old_session")

            ((old_session++))
            [[ $old_session -gt $old_session_limit ]] && break
        done

        $SED_CMD "$start_line,$end_line!d" "$SESSION_TAIL_PATHFILE" > "$SESSION_LAST_PATHFILE"
    else
        [[ -e $SESSION_LAST_PATHFILE ]] && rm -f "$SESSION_LAST_PATHFILE"
    fi

    return 0

    }

ExtractTailFromLog()
    {

    if [[ -e $SESSION_ARCHIVE_PATHFILE ]]; then
        $TAIL_CMD -n${LOG_TAIL_LINES} "$SESSION_ARCHIVE_PATHFILE" > "$SESSION_TAIL_PATHFILE"   # trim main log first so there's less to 'grep'
    else
        [[ -e $SESSION_TAIL_PATHFILE ]] && rm -f "$SESSION_TAIL_PATHFILE"
    fi

    return 0

    }

ShowVersions()
    {

    DisableDebugToArchiveAndFile

    Display "manager: ${MANAGER_SCRIPT_VERSION:-unknown}"
    Display "loader: ${LOADER_SCRIPT_VERSION:-unknown}"
    Display "package: ${PACKAGE_VERSION:-unknown}"
    Display "objects hash: $(CompileObjects hash)"

    return 0

    }

QPKGs.NewVersions.Show()
    {

    # Check installed QPKGs and compare versions against upgradable array. If new versions are available, advise on-screen.

    # $? = 0 if all packages are up-to-date
    # $? = 1 if one-or-more packages can be upgraded

    local -a left_to_upgrade=()
    local -i index=0
    local names_formatted=''
    local msg=''

    QPKGs.States.Build

    if [[ $(QPKGs.ScUpgradable.Count) -eq 0 ]]; then
        return 0
    else
        left_to_upgrade+=($(QPKGs.ScUpgradable.Array))
    fi

    for ((index=0;index<=((${#left_to_upgrade[@]}-1));index++)); do
        names_formatted+=$(ColourTextBrightOrange "${left_to_upgrade[$index]}")

        if [[ $((index+2)) -lt ${#left_to_upgrade[@]} ]]; then
            names_formatted+=', '
        elif [[ $((index+2)) -eq ${#left_to_upgrade[@]} ]]; then
            names_formatted+=' & '
        fi
    done

    if [[ ${#left_to_upgrade[@]} -eq 1 ]]; then
        msg='a new QPKG is'
    else
        msg='new QPKGs are'
    fi

    ShowAsInfo "$msg available for $names_formatted"
    return 1

    }

QPKGs.Conflicts.Check()
    {

    for package in "${MANAGER_BASE_QPKG_CONFLICTS[@]}"; do
        if QPKGs.IsStarted.Exist "$package"; then
            ShowAsEror "'$package' is installed and enabled. One-or-more $(FormatAsScriptTitle) applications are incompatible with this package"
            return 1
        fi
    done

    return 0

    }

QPKGs.Operations.List()
    {

    QPKGs.SkProc.IsSet && return
    DebugFuncEntry
    local operation=''
    local prefix=''
    DebugInfoMinorSeparator

    for operation in "${PACKAGE_OPERATIONS[@]}"; do
        # speedup: only log arrays with more than zero elements
        for prefix in To Ok Er Sk; do
            if QPKGs.Op${prefix}${operation}.IsAny; then
                if [[ $prefix != To ]]; then
                    DebugQPKGInfo "Op${prefix}${operation}" "($(QPKGs.Op${prefix}${operation}.Count)) $(QPKGs.Op${prefix}${operation}.ListCSV) "
                else
                    DebugQPKGWarning "Op${prefix}${operation}" "($(QPKGs.Op${prefix}${operation}.Count)) $(QPKGs.Op${prefix}${operation}.ListCSV) "
                fi
            fi
        done
    done

    DebugInfoMinorSeparator
    DebugFuncExit

    }

QPKGs.States.List()
    {

    DebugFuncEntry
    local state=''
    local prefix=''

    DebugInfoMinorSeparator
    QPKGs.States.Build

    for state in "${PACKAGE_STATES[@]}"; do
        # speedup: only log arrays with more than zero elements
        for prefix in Is IsNt; do
            QPKGs.${prefix}${state}.IsAny && DebugQPKGInfo "${prefix}${state}" "($(QPKGs.${prefix}${state}.Count)) $(QPKGs.${prefix}${state}.ListCSV) "
        done
    done

    DebugInfoMinorSeparator
    DebugFuncExit

    }

QPKGs.StandaloneDependent.Build()
    {

    # there are three tiers of package: 'standalone', 'addon' and 'dependent'
    # ... but only two tiers of QPKG: 'standalone' and 'dependent'

    # 'standalone' QPKGs don't depend on other QPKGs, but may be required for other QPKGs. They should be installed/started before any 'dependent' QPKGs.
    # 'dependent' QPKGs depend on other QPKGs. They should be installed/started after all 'standalone' QPKGs.

    local -i index=0

    for index in "${!MANAGER_QPKG_NAME[@]}"; do
        if [[ -z ${MANAGER_QPKG_DEPENDS_ON[$index]} ]]; then
            QPKGs.ScStandalone.Add "${MANAGER_QPKG_NAME[$index]}"
        else
            QPKGs.ScDependent.Add "${MANAGER_QPKG_NAME[$index]}"
        fi
    done

    return 0

    }

QPKGs.States.Build()
    {

    # Builds several lists of QPKGs:
    #   - can be installed or reinstalled by the user
    #   - can be upgraded
    #   - are installed and enabled or installed and disabled in [/etc/config/qpkg.conf]
    #   - have backup files in backup location
    #   - have config blocks in [/etc/config/qpkg.conf], but no files on-disk
    #   - those in the process of starting, stopping, or restarting

    # NOTE: these lists cannot be rebuilt unless element removal methods are re-added

    QPKGs.States.Built.IsSet && return

    DebugFuncEntry
    local -i index=0
    local package=''
    local previous=''
    ShowAsProc 'stateful lists' >&2

    for index in "${!MANAGER_QPKG_NAME[@]}"; do
        package="${MANAGER_QPKG_NAME[$index]}"
        [[ $package = "$previous" ]] && continue || previous=$package

        if $GREP_CMD -q "^\[$package\]" /etc/config/qpkg.conf; then
            if [[ ! -d $(/sbin/getcfg "$package" Install_Path -f /etc/config/qpkg.conf) ]]; then
                QPKGs.IsMissing.Add "$package"
                continue
            fi

            QPKGs.IsInstalled.Add "$package"

            [[ $(/sbin/getcfg "$package" Version -d unknown -f /etc/config/qpkg.conf) != "${MANAGER_QPKG_VERSION[$index]}" ]] && QPKGs.ScUpgradable.Add "$package"

            if [[ $(/sbin/getcfg "$package" Enable -u -f /etc/config/qpkg.conf) = 'TRUE' ]]; then
                QPKGs.IsStarted.Add "$package"
            elif [[ $(/sbin/getcfg "$package" Enable -u -f /etc/config/qpkg.conf) = 'FALSE' ]]; then
                QPKGs.IsStopped.Add "$package"
            fi

            if [[ -e /var/run/$package.last.operation ]]; then
                case $(</var/run/$package.last.operation) in
                    starting)
                        QPKGs.IsStopped.Remove "$package"
                        QPKGs.IsStarting.Add "$package"
                        ;;
                    restarting)
                        QPKGs.IsRestarting.Add "$package"
                        ;;
                    stopping)
                        QPKGs.IsStarted.Remove "$package"
                        QPKGs.IsStopping.Add "$package"
                esac
            fi

            if ${MANAGER_QPKG_SUPPORTS_BACKUP[$index]}; then
                if [[ -e $BACKUP_PATH/$package.config.tar.gz ]]; then
                    QPKGs.IsBackedUp.Add "$package"
                else
                    QPKGs.IsNtBackedUp.Add "$package"
                fi
            fi
        else
            QPKGs.IsNtInstalled.Add "$package"

            if [[ -n ${MANAGER_QPKG_ABBRVS[$index]} ]]; then
                if [[ ${MANAGER_QPKG_ARCH[$index]} = 'all' || ${MANAGER_QPKG_ARCH[$index]} = "$NAS_QPKG_ARCH" ]]; then
                    if [[ ${MANAGER_QPKG_MIN_RAM_KB[$index]} = any || $INSTALLED_RAM_KB -ge ${MANAGER_QPKG_MIN_RAM_KB[$index]} ]]; then
                        QPKGs.ScInstallable.Add "$package"
                    fi
                fi
            fi

            if ${MANAGER_QPKG_SUPPORTS_BACKUP[$index]}; then
                if [[ -e $BACKUP_PATH/$package.config.tar.gz ]]; then
                    QPKGs.IsBackedUp.Add "$package"
                fi
            fi
        fi
    done

    QPKGs.States.Built.Set
    SmartCR >&2
    DebugFuncExit

    }

QPKGs.IsSupportBackup.Build()
    {

    # Builds a list of QPKGs that do and don't support 'backup' and 'restore' operations

    DebugFuncEntry
    local package=''

    for package in $(QPKGs.ScAll.Array); do
        if QPKG.IsSupportBackup "$package"; then
            QPKGs.ScSupportBackup.Add "$package"
            QPKGs.ScNtSupportBackup.Remove "$package"
        else
            QPKGs.ScNtSupportBackup.Add "$package"
            QPKGs.ScSupportBackup.Remove "$package"
        fi
    done

    DebugFuncExit

    }

QPKGs.IsSupportUpdateOnRestart.Build()
    {

    # Builds a list of QPKGs that do and don't support application updating on QPKG restart

    DebugFuncEntry
    local package=''

    for package in $(QPKGs.ScAll.Array); do
        if QPKG.IsSupportUpdateOnRestart "$package"; then
            QPKGs.ScSupportUpdateOnRestart.Add "$package"
            QPKGs.ScNtSupportUpdateOnRestart.Remove "$package"
        else
            QPKGs.ScNtSupportUpdateOnRestart.Add "$package"
            QPKGs.ScSupportUpdateOnRestart.Remove "$package"
        fi
    done

    DebugFuncExit

    }

QPKGs.ScAll.Show()
    {

    local package=''
    QPKGs.States.Build
    DisableDebugToArchiveAndFile

    for package in $(QPKGs.ScAll.Array); do
        Display "$package"
    done

    return 0

    }

QPKGs.Backups.Show()
    {

    local epochtime=0       # float as seconds have a fractional component
    local filename=''
    local highlight_older_than='2 weeks ago'
    local format=''

    DisableDebugToArchiveAndFile
    SmartCR
    DisplayLineSpaceIfNoneAlready
    DisplayAsHelpTitle "the location for $(FormatAsScriptTitle) backups is: $BACKUP_PATH"
    Display

    if [[ -e $GNU_FIND_CMD ]]; then
        DisplayAsHelpTitle "backups are listed oldest-first, and those $(ColourTextBrightRed 'in red') were updated more than $highlight_older_than"
        Display
        DisplayAsHelpTitleFileNamePlusSomething 'backup file' 'last backup date'

        while read -r epochtime filename; do
            [[ -z $epochtime || -z $filename ]] && break

            if [[ ${epochtime%.*} -lt $($DATE_CMD --date="$highlight_older_than" +%s) ]]; then
                format="$(ColourTextBrightRed "%${HELP_DESC_INDENT}s%-${HELP_FILE_NAME_WIDTH}s - %s\n")"
            else
                format="%${HELP_DESC_INDENT}s%-${HELP_FILE_NAME_WIDTH}s - %s\n"
            fi

            # shellcheck disable=2059
            printf "$format" '' "$filename" "$($DATE_CMD -d @"$epochtime" +%c)"
        done <<< "$($GNU_FIND_CMD "$BACKUP_PATH"/*.config.tar.gz -maxdepth 1 -printf '%C@ %f\n' 2>/dev/null | $SORT_CMD)"

    else
        DisplayAsHelpTitle 'backups are listed oldest-first'
        Display

        (cd "$BACKUP_PATH" && ls -1 ./*.config.tar.gz 2>/dev/null)
    fi

    return 0

    }

QPKGs.Statuses.Show()
    {

    local tier=''
    local package=''
    local -i index=0
    local -a package_notes=()
    local package_display=''
    local version_display=''

    QPKGs.States.Build
    DisplayLineSpaceIfNoneAlready

    for tier in Standalone Dependent; do
        DisplayAsHelpTitlePackageNameVersionStatus "$tier QPKGs" 'QPKG version' 'QPKG status'

        for package in $(QPKGs.Sc$tier.Array); do
            package_notes=()
            package_display=''
            version_display=''

            if ! QPKG.URL "$package" &>/dev/null; then
                DisplayAsHelpPackageNameVersionStatus "$package" "$(QPKG.Available.Version "$package")" 'not installable on this NAS (unsupported arch)'
            elif ! QPKG.MinRAM "$package" &>/dev/null; then
                DisplayAsHelpPackageNameVersionStatus "$package" "$(QPKG.Available.Version "$package")" 'not installable on this NAS (insufficient RAM)'
            elif QPKGs.IsNtInstalled.Exist "$package"; then
                DisplayAsHelpPackageNameVersionStatus "$package" "$(QPKG.Available.Version "$package")" 'not installed'
            else
                QPKGs.IsStarting.Exist "$package" && package_notes+=($(ColourTextBrightOrange starting))
                QPKGs.IsStarted.Exist "$package" && package_notes+=($(ColourTextBrightGreen started))
                QPKGs.IsStopping.Exist "$package" && package_notes+=($(ColourTextBrightOrange stopping))
                QPKGs.IsStopped.Exist "$package" && package_notes+=($(ColourTextBrightRed stopped))
                QPKGs.IsRestarting.Exist "$package" && package_notes+=($(ColourTextBrightOrange restarting))
                QPKGs.IsMissing.Exist "$package" && package_notes=($(ColourTextBrightRedBlink missing))

                if QPKGs.ScUpgradable.Exist "$package"; then
                    package_notes+=("$(ColourTextBrightOrange "upgradable to $(QPKG.Available.Version "$package")")")
                    version_display=$(QPKG.Local.Version "$package")
                else
                    version_display=$(QPKG.Available.Version "$package")
                fi

                for ((index=0;index<=((${#package_notes[@]}-1));index++)); do
                    package_display+=${package_notes[$index]}

                    [[ $((index+2)) -le ${#package_notes[@]} ]] && package_display+=', '
                done

                DisplayAsHelpPackageNameVersionStatus "$package" "$version_display" "$package_display"
            fi
        done

        Display; Session.LineSpace.Set
    done

    QPKGs.Operations.List
    QPKGs.States.List

    return 0

    }

QPKGs.IsInstalled.Show()
    {

    local package=''
    QPKGs.States.Build
    DisableDebugToArchiveAndFile

    for package in $(QPKGs.IsInstalled.Array); do
        Display "$package"
    done

    return 0

    }

QPKGs.ScInstallable.Show()
    {

    local package=''
    QPKGs.States.Build
    DisableDebugToArchiveAndFile

    for package in $(QPKGs.ScInstallable.Array); do
        Display "$package"
    done

    return 0

    }

QPKGs.IsNtInstalled.Show()
    {

    local package=''
    QPKGs.States.Build
    DisableDebugToArchiveAndFile

    for package in $(QPKGs.IsNtInstalled.Array); do
        Display "$package"
    done

    return 0

    }

QPKGs.IsStarted.Show()
    {

    local package=''
    QPKGs.States.Build
    DisableDebugToArchiveAndFile

    for package in $(QPKGs.IsStarted.Array); do
        Display "$package"
    done

    return 0

    }

QPKGs.IsStopped.Show()
    {

    local package=''
    QPKGs.States.Build
    DisableDebugToArchiveAndFile

    for package in $(QPKGs.IsStopped.Array); do
        Display "$package"
    done

    return 0

    }

QPKGs.ScUpgradable.Show()
    {

    local package=''
    QPKGs.States.Build
    DisableDebugToArchiveAndFile

    for package in $(QPKGs.ScUpgradable.Array); do
        Display "$package"
    done

    return 0

    }

QPKGs.ScStandalone.Show()
    {

    local package=''
    QPKGs.States.Build
    DisableDebugToArchiveAndFile

    for package in $(QPKGs.ScStandalone.Array); do
        Display "$package"
    done

    return 0

    }

QPKGs.ScDependent.Show()
    {

    local package=''
    QPKGs.States.Build
    DisableDebugToArchiveAndFile

    for package in $(QPKGs.ScDependent.Array); do
        Display "$package"
    done

    return 0

    }

MarkOperationAsDone()
    {

    # move specified package name from 'To' operation array into associated 'Ok' array

    # input:
    #   $1 = package name
    #   $2 = action

    QPKGs.OpTo"$(tr 'a-z' 'A-Z' <<< "${2:0:1}")${2:1}".Remove "$1"
    QPKGs.OpOk"$(tr 'a-z' 'A-Z' <<< "${2:0:1}")${2:1}".Add "$1"

    return 0

    }

MarkOperationAsError()
    {

    # move specified package name from 'To' operation array into associated 'Er' array

    # input:
    #   $1 = package name
    #   $2 = action
    #   $3 = reason (optional)

    local message="failing request to $2 $(FormatAsPackageName "$1")"

    [[ -n ${3:-} ]] && message+=" as $3"
    DebugAsError "$message" >&2
    QPKGs.OpTo"$(tr 'a-z' 'A-Z' <<< "${2:0:1}")${2:1}".Remove "$1"
    QPKGs.OpEr"$(tr 'a-z' 'A-Z' <<< "${2:0:1}")${2:1}".Add "$1"

    return 0

    }

MarkOperationAsSkipped()
    {

    # move specified package name from 'To' operation array into associated 'Sk' array

    # input:
    #   $1 = show this onscreen: 'show'/'hide'
    #   $2 = package name
    #   $3 = action
    #   $4 = reason (optional)

    local message="ignoring request to $3 $(FormatAsPackageName "$2")"
    [[ -n ${4:-} ]] && message+=" as $4"

    if [[ ${1:-hide} = show ]]; then
        ShowAsInfo "$message" >&2
    else
        DebugAsInfo "$message" >&2
    fi

    QPKGs.OpTo"$(tr 'a-z' 'A-Z' <<< "${3:0:1}")${3:1}".Remove "$2"
    QPKGs.OpSk"$(tr 'a-z' 'A-Z' <<< "${3:0:1}")${3:1}".Add "$2"

    return 0

    }

MarkStateAsInstalled()
    {

    QPKGs.IsInstalled.Add "$1"
    QPKGs.IsNtInstalled.Remove "$1"

    }

MarkStateAsNotInstalled()
    {

    QPKGs.IsInstalled.Remove "$1"
    QPKGs.IsNtInstalled.Add "$1"

    }

MarkStateAsStarted()
    {

    QPKGs.IsStarting.Remove "$1"
    QPKGs.IsStarted.Add "$1"
    QPKGs.IsStopping.Remove "$1"
    QPKGs.IsStopped.Remove "$1"
    QPKGs.IsRestarting.Remove "$1"

    }

MarkStateAsStopped()
    {

    QPKGs.IsStarting.Remove "$1"
    QPKGs.IsStarted.Remove "$1"
    QPKGs.IsStopping.Remove "$1"
    QPKGs.IsStopped.Add "$1"
    QPKGs.IsRestarting.Remove "$1"

    }

CalcQPKGArch()
    {

    # Decide which package arch is suitable for this NAS. Creates a global constant: $NAS_QPKG_ARCH

    case $($UNAME_CMD -m) in
        x86_64)
            [[ ${NAS_FIRMWARE//.} -ge 430 ]] && NAS_QPKG_ARCH=x64 || NAS_QPKG_ARCH=x86
            ;;
        i686|x86)
            NAS_QPKG_ARCH=x86
            ;;
        armv5tel)
            NAS_QPKG_ARCH=x19
            ;;
        armv7l)
            case $(/sbin/getcfg '' Platform -f /etc/platform.conf) in
                ARM_MS)
                    NAS_QPKG_ARCH=x31
                    ;;
                ARM_AL)
                    NAS_QPKG_ARCH=x41
                    ;;
                *)
                    NAS_QPKG_ARCH=none
            esac
            ;;
        aarch64)
            NAS_QPKG_ARCH=a64
            ;;
        *)
            NAS_QPKG_ARCH=none
    esac

    readonly NAS_QPKG_ARCH
    DebugQPKGDetected arch "$NAS_QPKG_ARCH"

    return 0

    }

CalcEntwareType()
    {

    if QPKG.IsInstalled Entware; then
        if [[ -e /opt/etc/passwd ]]; then
            if [[ -L /opt/etc/passwd ]]; then
                ENTWARE_VER=std
            else
                ENTWARE_VER=alt
            fi
        else
            ENTWARE_VER=none
        fi

        DebugQPKGDetected 'Entware installer' $ENTWARE_VER

        [[ $ENTWARE_VER = none ]] && DebugAsWarn "$(FormatAsPackageName Entware) appears to be installed but is not visible"
    fi

    return 0

    }

ModPathToEntware()
    {

    local opkg_prefix=/opt/bin:/opt/sbin
    local temp=''

    if QPKGs.IsStarted.Exist Entware; then
        [[ $PATH =~ $opkg_prefix ]] && return
        temp="$($SED_CMD "s|$opkg_prefix:||" <<< "$PATH:")"     # append colon prior to searching, then remove existing Entware paths
        export PATH="$opkg_prefix:${temp%:}"                    # ... now prepend Entware paths and remove trailing colon
        DebugAsDone 'prepended $PATH to Entware'
        DebugVar PATH
    elif ! QPKGs.IsStarted.Exist Entware; then
        ! [[ $PATH =~ $opkg_prefix ]] && return
        temp="$($SED_CMD "s|$opkg_prefix:||" <<< "$PATH:")"     # append colon prior to searching, then remove existing Entware paths
        export PATH="${temp%:}"                                 # ... now remove trailing colon
        DebugAsDone 'removed $PATH to Entware'
        DebugVar PATH
    fi

    return 0

    }

Session.Error.Set()
    {

    [[ $(type -t QPKGs.SkProc.Init) = function ]] && QPKGs.SkProc.Set
    Session.Error.IsSet && return
    _script_error_flag_=true
    DebugVar _script_error_flag_

    }

Session.Error.IsSet()
    {

    [[ ${_script_error_flag_:-} = true ]]

    }

Session.Error.IsNt()
    {

    [[ ${_script_error_flag_:-} != true ]]

    }

ShowSummary()
    {

    local state=''
    local operation=''

    for state in "${PACKAGE_STATES[@]}"; do
        for operation in "${PACKAGE_OPERATIONS[@]}"; do
            Opts.Apps.Op${operation}.Is${state}.IsSet && QPKGs.OpOk${operation}.IsNone && ShowAsDone "no QPKGs were $(tr 'A-Z' 'a-z' <<< $state)"
        done
    done

    return 0

    }

ClaimLockFile()
    {

    readonly RUNTIME_LOCK_PATHFILE=${1:?empty}

    if [[ -e $RUNTIME_LOCK_PATHFILE && -d /proc/$(<"$RUNTIME_LOCK_PATHFILE") && $(</proc/"$(<"$RUNTIME_LOCK_PATHFILE")"/cmdline) =~ $PROJECT_NAME.manager.sh ]]; then
        ShowAsAbort 'another instance is running'
        return 1
    fi

    echo "$$" > "$RUNTIME_LOCK_PATHFILE"
    return 0

    }

ReleaseLockFile()
    {

    [[ -e ${RUNTIME_LOCK_PATHFILE:?empty} ]] && rm -f "$RUNTIME_LOCK_PATHFILE"

    }

DisableDebugToArchiveAndFile()
    {

    Session.Debug.ToArchive.Clear
    Session.Debug.ToFile.Clear

    }

# QPKG tasks

QPKG.DoDownload()
    {

    # input:
    #   $1 = QPKG name to download

    # output:
    #   $? = 0  : successful
    #   $? = 1  : failed
    #   $? = 2  : skipped (not downloaded: already downloaded)

    Session.Error.IsSet && return
    DebugFuncEntry

    local -r PACKAGE_NAME=${1:?no package name supplied}
    local -i result_code=0
    local -r REMOTE_URL=$(QPKG.URL "$PACKAGE_NAME")
    local -r REMOTE_FILENAME=$($BASENAME_CMD "$REMOTE_URL")
    local -r REMOTE_MD5=$(QPKG.MD5 "$PACKAGE_NAME")
    local -r LOCAL_PATHFILE=$QPKG_DL_PATH/$REMOTE_FILENAME
    local -r LOCAL_FILENAME=$($BASENAME_CMD "$LOCAL_PATHFILE")
    local -r LOG_PATHFILE=$LOGS_PATH/$LOCAL_FILENAME.$DOWNLOAD_LOG_FILE
    local operation=download

    if [[ -z $REMOTE_URL || -z $REMOTE_MD5 ]]; then
        DebugAsWarn "no URL or MD5 found for this package $(FormatAsPackageName "$PACKAGE_NAME") (unsupported arch?)"
        result_code=2
    fi

    if [[ -f $LOCAL_PATHFILE ]]; then
        if FileMatchesMD5 "$LOCAL_PATHFILE" "$REMOTE_MD5"; then
            DebugInfo "local package $(FormatAsFileName "$LOCAL_FILENAME") checksum correct: skipping download"
            result_code=2
        else
            DebugAsError "local package $(FormatAsFileName "$LOCAL_FILENAME") checksum incorrect"

            if [[ -f $LOCAL_PATHFILE ]]; then
                DebugInfo "deleting $(FormatAsFileName "$LOCAL_FILENAME")"
                rm -f "$LOCAL_PATHFILE"
            fi
        fi
    fi

    if [[ $result_code -eq 2 ]]; then
        MarkOperationAsSkipped hide "$PACKAGE_NAME" "$operation"
        DebugFuncExit $result_code; return
    fi

    if [[ ! -f $LOCAL_PATHFILE ]]; then
        DebugAsProc "downloading $(FormatAsFileName "$REMOTE_FILENAME")"

        [[ -e $LOG_PATHFILE ]] && rm -f "$LOG_PATHFILE"

        RunAndLog "$CURL_CMD${curl_insecure_arg} --output $LOCAL_PATHFILE $REMOTE_URL" "$LOG_PATHFILE" log:failure-only
        result_code=$?

        if [[ $result_code -eq 0 ]]; then
            if FileMatchesMD5 "$LOCAL_PATHFILE" "$REMOTE_MD5"; then
                DebugAsDone "downloaded $(FormatAsFileName "$REMOTE_FILENAME")"
                QPKGs.OpOkDownload.Add "$PACKAGE_NAME"
            else
                DebugAsError "downloaded package $(FormatAsFileName "$LOCAL_PATHFILE") checksum incorrect"
                QPKGs.OpErDownload.Add "$PACKAGE_NAME"
                result_code=1
            fi
        else
            ShowAsFail "$operation failed $(FormatAsFileName "$PACKAGE_NAME") $(FormatAsExitcode $result_code)"
            QPKGs.OpErDownload.Add "$PACKAGE_NAME"
            result_code=1    # remap to 1 (last time I checked, 'curl' had 92 return codes)
        fi
    fi

    QPKGs.OpToDownload.Remove "$PACKAGE_NAME"
    DebugFuncExit $result_code

    }

QPKG.DoInstall()
    {

    # input:
    #   $1 = QPKG name

    # output:
    #   $? = 0  : successful
    #   $? = 1  : failed
    #   $? = 2  : skipped (not installed: already installed, or no package available for this NAS arch)

    Session.Error.IsSet && return
    QPKGs.SkProc.IsSet && return
    DebugFuncEntry

    local -r PACKAGE_NAME=${1:?no package name supplied}
    local -i result_code=0
    local operation=install

    if QPKGs.IsInstalled.Exist "$PACKAGE_NAME"; then
        MarkOperationAsSkipped show "$PACKAGE_NAME" "$operation" "it's already installed - use 'reinstall' instead"
        DebugFuncExit 2; return
    fi

    if ! QPKG.URL "$PACKAGE_NAME" &>/dev/null; then
        MarkOperationAsSkipped show "$PACKAGE_NAME" "$operation" 'this NAS has an unsupported arch'
        DebugFuncExit 2; return
    fi

    if ! QPKG.MinRAM "$PACKAGE_NAME" &>/dev/null; then
        MarkOperationAsSkipped show "$PACKAGE_NAME" "$operation" 'this NAS has insufficient RAM'
        DebugFuncExit 2; return
    fi

    local local_pathfile=$(QPKG.PathFilename "$PACKAGE_NAME")

    if [[ ${local_pathfile##*.} = zip ]]; then
        $UNZIP_CMD -nq "$local_pathfile" -d "$QPKG_DL_PATH"
        local_pathfile=${local_pathfile%.*}
    fi

    if [[ -z $local_pathfile ]]; then
        MarkOperationAsSkipped show "$PACKAGE_NAME" "$operation" 'no local file found for processing: this error should be reported.'
        code_pointer=5
        DebugFuncExit 2; return
    fi

    if [[ $PACKAGE_NAME = Entware ]] && ! QPKGs.IsInstalled.Exist Entware && QPKGs.OpToInstall.Exist Entware; then
        local -r OPT_PATH=/opt
        local -r OPT_BACKUP_PATH=/opt.orig

        if [[ -d $OPT_PATH && ! -L $OPT_PATH && ! -e $OPT_BACKUP_PATH ]]; then
            ShowAsProc "backup original /opt" >&2
            mv "$OPT_PATH" "$OPT_BACKUP_PATH"
            DebugAsDone 'complete'
        fi
    fi

    local -r TARGET_FILE=$($BASENAME_CMD "$local_pathfile")

    DebugAsProc "installing $(FormatAsPackageName "$PACKAGE_NAME")"
    RunAndLog "$SH_CMD $local_pathfile" "$LOGS_PATH/$TARGET_FILE.$INSTALL_LOG_FILE" log:failure-only 10
    result_code=$?

    if [[ $result_code -eq 0 || $result_code -eq 10 ]]; then
        DebugAsDone "installed $(FormatAsPackageName "$PACKAGE_NAME")"
        QPKG.StoreServiceStatus "$PACKAGE_NAME"
        MarkOperationAsDone "$PACKAGE_NAME" "$operation"
        MarkStateAsInstalled "$PACKAGE_NAME"

        if QPKG.IsStarted "$PACKAGE_NAME"; then
            MarkStateAsStarted "$PACKAGE_NAME"
        else
            MarkStateAsStopped "$PACKAGE_NAME"
        fi

        if [[ $PACKAGE_NAME = Entware ]]; then
            ModPathToEntware
            PatchEntwareService

            if QPKGs.OpOkInstall.Exist Entware; then
                # copy all files from original [/opt] into new [/opt]
                if [[ -L ${OPT_PATH:-} && -d ${OPT_BACKUP_PATH:-} ]]; then
                    ShowAsProc "restoring original /opt" >&2
                    cp --recursive "$OPT_BACKUP_PATH"/* --target-directory "$OPT_PATH" && rm -rf "$OPT_BACKUP_PATH"
                    DebugAsDone 'complete'
                fi

                # add extra package(s) needed immediately
                DebugAsProc 'installing standalone IPKGs'
                RunAndLog "/opt/bin/opkg install$(Opts.IgFreeSpace.IsSet && Opts.IgFreeSpace.Text) --force-overwrite $MANAGER_BASE_IPKGS_ADD --cache $IPKG_CACHE_PATH --tmp-dir $IPKG_DL_PATH" "$LOGS_PATH/ipkgs.extra.$INSTALL_LOG_FILE" log:failure-only
                DebugAsDone 'installed standalone IPKGs'
            fi
        fi

        result_code=0    # remap to zero (0 or 10 from a QPKG install/reinstall/upgrade is OK)
    else
        ShowAsFail "$operation failed $(FormatAsFileName "$PACKAGE_NAME") $(FormatAsExitcode $result_code)"
        MarkOperationAsError "$PACKAGE_NAME" "$operation"
        result_code=1    # remap to 1
    fi

    QPKG.ClearAppCenterNotifier "$PACKAGE_NAME"
    DebugFuncExit $result_code

    }

QPKG.DoReinstall()
    {

    # input:
    #   $1 = QPKG name

    # output:
    #   $? = 0  : successful
    #   $? = 1  : failed
    #   $? = 2  : skipped (not reinstalled: not already installed, or no package available for this NAS arch)

    Session.Error.IsSet && return
    QPKGs.SkProc.IsSet && return
    DebugFuncEntry

    local -r PACKAGE_NAME=${1:?no package name supplied}
    local -i result_code=0
    local operation=reinstall

    if ! QPKGs.IsInstalled.Exist "$PACKAGE_NAME"; then
        MarkOperationAsSkipped show "$PACKAGE_NAME" "$operation" "it's not installed - use 'install' instead"
        DebugFuncExit 2; return
    fi

    if ! QPKG.URL "$PACKAGE_NAME" &>/dev/null; then
        MarkOperationAsSkipped show "$PACKAGE_NAME" "$operation" 'this NAS has an unsupported arch'
        DebugFuncExit 2; return
    fi

    if ! QPKG.MinRAM "$PACKAGE_NAME" &>/dev/null; then
        MarkOperationAsSkipped show "$PACKAGE_NAME" "$operation" 'this NAS has insufficient RAM'
        DebugFuncExit 2; return
    fi

    local local_pathfile=$(QPKG.PathFilename "$PACKAGE_NAME")

    if [[ ${local_pathfile##*.} = zip ]]; then
        $UNZIP_CMD -nq "$local_pathfile" -d "$QPKG_DL_PATH"
        local_pathfile=${local_pathfile%.*}
    fi

    if [[ -z $local_pathfile ]]; then
        MarkOperationAsSkipped show "$PACKAGE_NAME" "$operation" 'no local file found for processing: this error should be reported.'
        code_pointer=6
        DebugFuncExit 2; return
    fi

    local -r TARGET_FILE=$($BASENAME_CMD "$local_pathfile")
    local -r LOG_PATHFILE=$LOGS_PATH/$TARGET_FILE.$REINSTALL_LOG_FILE

    DebugAsProc "reinstalling $(FormatAsPackageName "$PACKAGE_NAME")"
    RunAndLog "$SH_CMD $local_pathfile" "$LOG_PATHFILE" log:failure-only 10
    result_code=$?

    if [[ $result_code -eq 0 || $result_code -eq 10 ]]; then
        DebugAsDone "reinstalled $(FormatAsPackageName "$PACKAGE_NAME")"
        MarkOperationAsDone "$PACKAGE_NAME" "$operation"
        QPKG.StoreServiceStatus "$PACKAGE_NAME"

        if QPKG.IsStarted "$PACKAGE_NAME"; then
            MarkStateAsStarted "$PACKAGE_NAME"
        else
            MarkStateAsStopped "$PACKAGE_NAME"
        fi

        result_code=0    # remap to zero (0 or 10 from a QPKG install/reinstall/upgrade is OK)
    else
        ShowAsFail "$operation failed $(FormatAsFileName "$PACKAGE_NAME") $(FormatAsExitcode $result_code)"
        MarkOperationAsError "$PACKAGE_NAME" "$operation"
        result_code=1    # remap to 1
    fi

    QPKG.ClearAppCenterNotifier "$PACKAGE_NAME"
    DebugFuncExit $result_code

    }

QPKG.DoUpgrade()
    {

    # Upgrades the QPKG named in $1

    # input:
    #   $1 = QPKG name

    # output:
    #   $? = 0  : successful
    #   $? = 1  : failed
    #   $? = 2  : skipped (not upgraded: not installed, or no package available for this NAS arch)

    Session.Error.IsSet && return
    QPKGs.SkProc.IsSet && return
    DebugFuncEntry

    local -r PACKAGE_NAME=${1:?no package name supplied}
    local -i result_code=0
    local operation=upgrade

    if ! QPKGs.IsInstalled.Exist "$PACKAGE_NAME"; then
        MarkOperationAsSkipped show "$PACKAGE_NAME" "$operation" "it's not installed - use 'install' instead"
        DebugFuncExit 2; return
    fi

    if ! QPKG.URL "$PACKAGE_NAME" &>/dev/null; then
        MarkOperationAsSkipped show "$PACKAGE_NAME" "$operation" 'this NAS has an unsupported arch'
        DebugFuncExit 2; return
    fi

    if ! QPKG.MinRAM "$PACKAGE_NAME" &>/dev/null; then
        MarkOperationAsSkipped show "$PACKAGE_NAME" "$operation" 'this NAS has insufficient RAM'
        DebugFuncExit 2; return
    fi

    if ! QPKGs.ScUpgradable.Exist "$PACKAGE_NAME"; then
        MarkOperationAsSkipped show "$PACKAGE_NAME" "$operation" 'no new package is available'
        DebugFuncExit 2; return
    fi

    local previous_version=null
    local current_version=null
    local local_pathfile=$(QPKG.PathFilename "$PACKAGE_NAME")

    if [[ ${local_pathfile##*.} = zip ]]; then
        $UNZIP_CMD -nq "$local_pathfile" -d "$QPKG_DL_PATH"
        local_pathfile=${local_pathfile%.*}
    fi

    if [[ -z $local_pathfile ]]; then
        MarkOperationAsSkipped show "$PACKAGE_NAME" "$operation" 'no local file found for processing: this error should be reported.'
        code_pointer=7
        DebugFuncExit 2; return
    fi

    local -r TARGET_FILE=$($BASENAME_CMD "$local_pathfile")
    local -r LOG_PATHFILE=$LOGS_PATH/$TARGET_FILE.$UPGRADE_LOG_FILE
    previous_version=$(QPKG.Local.Version "$PACKAGE_NAME")

    DebugAsProc "upgrading $(FormatAsPackageName "$PACKAGE_NAME")"
    RunAndLog "$SH_CMD $local_pathfile" "$LOG_PATHFILE" log:failure-only 10
    result_code=$?

    current_version=$(QPKG.Local.Version "$PACKAGE_NAME")

    if [[ $result_code -eq 0 || $result_code -eq 10 ]]; then
        if [[ $current_version = "$previous_version" ]]; then
            DebugAsDone "upgraded $(FormatAsPackageName "$PACKAGE_NAME") and installed version is $current_version"
        else
            DebugAsDone "upgraded $(FormatAsPackageName "$PACKAGE_NAME") from $previous_version to $current_version"
        fi
        QPKG.StoreServiceStatus "$PACKAGE_NAME"
        QPKGs.ScUpgradable.Remove "$PACKAGE_NAME"
        MarkOperationAsDone "$PACKAGE_NAME" "$operation"

        if QPKG.IsStarted "$PACKAGE_NAME"; then
            MarkStateAsStarted "$PACKAGE_NAME"
        else
            MarkStateAsStopped "$PACKAGE_NAME"
        fi

        result_code=0    # remap to zero (0 or 10 from a QPKG install/reinstall/upgrade is OK)
    else
        ShowAsFail "$operation failed $(FormatAsFileName "$PACKAGE_NAME") $(FormatAsExitcode $result_code)"
        MarkOperationAsError "$PACKAGE_NAME" "$operation"
        result_code=1    # remap to 1
    fi

    QPKG.ClearAppCenterNotifier "$PACKAGE_NAME"
    DebugFuncExit $result_code

    }

QPKG.DoUninstall()
    {

    # input:
    #   $1 = QPKG name

    # output:
    #   $? = 0  : successful
    #   $? = 1  : failed
    #   $? = 2  : skipped (not uninstalled: not already installed)

    Session.Error.IsSet && return
    DebugFuncEntry

    local -r PACKAGE_NAME=${1:?no package name supplied}
    local -i result_code=0
    local operation=uninstall

    if QPKGs.IsNtInstalled.Exist "$PACKAGE_NAME"; then
        MarkOperationAsSkipped show "$PACKAGE_NAME" "$operation" "it's not installed"
        DebugFuncExit 2; return
    fi

    if [[ $PACKAGE_NAME = "$PROJECT_NAME" ]]; then
        MarkOperationAsSkipped show "$PACKAGE_NAME" "$operation" "it's needed here! 😉"
        DebugFuncExit 2; return
    fi

    local -r QPKG_UNINSTALLER_PATHFILE=$(/sbin/getcfg "$PACKAGE_NAME" Install_Path -f /etc/config/qpkg.conf)/.uninstall.sh
    local -r LOG_PATHFILE=$LOGS_PATH/$PACKAGE_NAME.$UNINSTALL_LOG_FILE

    [[ $PACKAGE_NAME = Entware ]] && SavePackageLists

    if [[ -e $QPKG_UNINSTALLER_PATHFILE ]]; then
        DebugAsProc "uninstalling $(FormatAsPackageName "$PACKAGE_NAME")"
        RunAndLog "$SH_CMD $QPKG_UNINSTALLER_PATHFILE" "$LOG_PATHFILE" log:failure-only
        result_code=$?

        if [[ $result_code -eq 0 ]]; then
            DebugAsDone "uninstalled $(FormatAsPackageName "$PACKAGE_NAME")"
            /sbin/rmcfg "$PACKAGE_NAME" -f /etc/config/qpkg.conf
            DebugAsDone 'removed icon information from App Center'
            [[ $PACKAGE_NAME = Entware ]] && ModPathToEntware
            MarkOperationAsDone "$PACKAGE_NAME" "$operation"
            MarkStateAsNotInstalled "$PACKAGE_NAME"
            QPKGs.IsStarted.Remove "$PACKAGE_NAME"
        else
            ShowAsFail "$operation failed $(FormatAsFileName "$PACKAGE_NAME") $(FormatAsExitcode $result_code)"
            MarkOperationAsError "$PACKAGE_NAME" "$operation"
            result_code=1    # remap to 1
        fi
    fi

    QPKG.ClearAppCenterNotifier "$PACKAGE_NAME"
    DebugFuncExit $result_code

    }

QPKG.DoRestart()
    {

    # Restarts the service script for the QPKG named in $1

    # input:
    #   $1 = QPKG name

    # output:
    #   $? = 0  : successful
    #   $? = 1  : failed
    #   $? = 2  : skipped (not restarted: not already installed)

    DebugFuncEntry

    local -r PACKAGE_NAME=${1:?no package name supplied}
    local -i result_code=0
    local operation=restart

    QPKG.ClearServiceStatus "$PACKAGE_NAME"

    if QPKGs.IsNtInstalled.Exist "$PACKAGE_NAME"; then
        MarkOperationAsSkipped show "$PACKAGE_NAME" "$operation" "it's not installed"
        DebugFuncExit 2; return
    fi

    if [[ $PACKAGE_NAME = "$PROJECT_NAME" ]]; then
        MarkOperationAsSkipped show "$PACKAGE_NAME" "$operation" "it's needed here! 😉"
        DebugFuncExit 2; return
    fi

    local -r LOG_PATHFILE=$LOGS_PATH/$PACKAGE_NAME.$RESTART_LOG_FILE

    QPKG.DoEnable "$PACKAGE_NAME"
    result_code=$?

    if [[ $result_code -eq 0 ]]; then
        DebugAsProc "restarting $(FormatAsPackageName "$PACKAGE_NAME")"
        RunAndLog "/sbin/qpkg_service restart $PACKAGE_NAME" "$LOG_PATHFILE" log:failure-only
        result_code=$?
    fi

    if [[ $result_code -eq 0 ]]; then
        DebugAsDone "restarted $(FormatAsPackageName "$PACKAGE_NAME")"
        QPKG.StoreServiceStatus "$PACKAGE_NAME"
        MarkOperationAsDone "$PACKAGE_NAME" "$operation"
    else
        ShowAsFail "$operation failed $(FormatAsFileName "$PACKAGE_NAME") $(FormatAsExitcode $result_code)"
        MarkOperationAsError "$PACKAGE_NAME" "$operation"
        result_code=1    # remap to 1
    fi

    QPKG.ClearAppCenterNotifier "$PACKAGE_NAME"
    DebugFuncExit $result_code

    }

QPKG.DoStart()
    {

    # Starts the service script for the QPKG named in $1

    # input:
    #   $1 = QPKG name

    # output:
    #   $? = 0  : successful
    #   $? = 1  : failed
    #   $? = 2  : skipped (not started: not installed or already started)

    DebugFuncEntry

    local -r PACKAGE_NAME=${1:?no package name supplied}
    local -i result_code=0

    QPKG.ClearServiceStatus "$PACKAGE_NAME"

    if QPKGs.IsNtInstalled.Exist "$PACKAGE_NAME"; then
        MarkOperationAsSkipped show "$PACKAGE_NAME" start "it's not installed"
        DebugFuncExit 2; return
    fi

    if QPKGs.IsStarted.Exist "$PACKAGE_NAME"; then
        MarkOperationAsSkipped show "$PACKAGE_NAME" start "it's already started"
        DebugFuncExit 2; return
    fi

    local -r LOG_PATHFILE=$LOGS_PATH/$PACKAGE_NAME.$START_LOG_FILE

    QPKG.DoEnable "$PACKAGE_NAME"
    result_code=$?

    if [[ $result_code -eq 0 ]]; then
        DebugAsProc "starting $(FormatAsPackageName "$PACKAGE_NAME")"
        RunAndLog "/sbin/qpkg_service start $PACKAGE_NAME" "$LOG_PATHFILE" log:failure-only
        result_code=$?
    fi

    if [[ $result_code -eq 0 ]]; then
        DebugAsDone "started $(FormatAsPackageName "$PACKAGE_NAME")"
        QPKG.StoreServiceStatus "$PACKAGE_NAME"
        MarkOperationAsDone "$PACKAGE_NAME" start
        MarkStateAsStarted "$PACKAGE_NAME"
        [[ $PACKAGE_NAME = Entware ]] && ModPathToEntware
    else
        ShowAsWarn "unable to start $(FormatAsPackageName "$PACKAGE_NAME") $(FormatAsExitcode $result_code)"
        MarkOperationAsError "$PACKAGE_NAME" start
        result_code=1    # remap to 1
    fi

    QPKG.ClearAppCenterNotifier "$PACKAGE_NAME"
    DebugFuncExit $result_code

    }

QPKG.DoStop()
    {

    # Stops the service script for the QPKG named in $1

    # input:
    #   $1 = QPKG name

    # output:
    #   $? = 0  : successful
    #   $? = 1  : failed
    #   $? = 2  : skipped (not stopped: not installed or already stopped)

    DebugFuncEntry

    local -r PACKAGE_NAME=${1:?no package name supplied}
    local -i result_code=0

    QPKG.ClearServiceStatus "$PACKAGE_NAME"

    if QPKGs.IsNtInstalled.Exist "$PACKAGE_NAME"; then
        MarkOperationAsSkipped show "$PACKAGE_NAME" stop "it's not installed"
        DebugFuncExit 2; return
    fi

    if QPKGs.IsStopped.Exist "$PACKAGE_NAME"; then
        MarkOperationAsSkipped show "$PACKAGE_NAME" stop "it's already stopped"
        DebugFuncExit 2; return
    fi

    if [[ $PACKAGE_NAME = "$PROJECT_NAME" ]]; then
        MarkOperationAsSkipped show "$PACKAGE_NAME" stop "it's needed here! 😉"
        DebugFuncExit 2; return
    fi

    local -r LOG_PATHFILE=$LOGS_PATH/$PACKAGE_NAME.$STOP_LOG_FILE

    DebugAsProc "stopping $(FormatAsPackageName "$PACKAGE_NAME")"
    RunAndLog "/sbin/qpkg_service stop $PACKAGE_NAME" "$LOG_PATHFILE" log:failure-only
    result_code=$?

    if [[ $result_code -eq 0 ]]; then
        QPKG.DoDisable "$PACKAGE_NAME"
        result_code=$?
    fi

    if [[ $result_code -eq 0 ]]; then
        DebugAsDone "stopped $(FormatAsPackageName "$PACKAGE_NAME")"
        QPKG.StoreServiceStatus "$PACKAGE_NAME"
        MarkOperationAsDone "$PACKAGE_NAME" stop
        MarkStateAsStopped "$PACKAGE_NAME"
    else
        ShowAsWarn "unable to stop $(FormatAsPackageName "$PACKAGE_NAME") $(FormatAsExitcode $result_code)"
        MarkOperationAsError "$PACKAGE_NAME" stop
        result_code=1    # remap to 1
    fi

    QPKG.ClearAppCenterNotifier "$PACKAGE_NAME"
    DebugFuncExit $result_code

    }

QPKG.DoEnable()
    {

    # $1 = package name to enable

    local -r PACKAGE_NAME=${1:?no package name supplied}
    local -i result_code=0

    RunAndLog "/sbin/qpkg_service enable $PACKAGE_NAME" "$LOGS_PATH/$PACKAGE_NAME.$ENABLE_LOG_FILE" log:failure-only
    result_code=$?

    if [[ $result_code -ne 0 ]]; then
        ShowAsWarn "unable to enable $(FormatAsPackageName "$PACKAGE_NAME") $(FormatAsExitcode $result_code)"
        result_code=1    # remap to 1
    fi

    return $result_code

    }

QPKG.DoDisable()
    {

    # $1 = package name to disable

    local -r PACKAGE_NAME=${1:?no package name supplied}
    local -i result_code=0

    RunAndLog "/sbin/qpkg_service disable $PACKAGE_NAME" "$LOGS_PATH/$PACKAGE_NAME.$DISABLE_LOG_FILE" log:failure-only
    result_code=$?

    if [[ $result_code -ne 0 ]]; then
        ShowAsWarn "unable to disable $(FormatAsPackageName "$PACKAGE_NAME") $(FormatAsExitcode $result_code)"
        result_code=1    # remap to 1
    fi

    return $result_code

    }

QPKG.DoBackup()
    {

    # calls the service script for the QPKG named in $1 and runs a backup operation

    # input:
    #   $1 = QPKG name

    # output:
    #   $? = 0  : successful
    #   $? = 1  : failed
    #   $? = 2  : skipped (not backed-up: not already installed)

    DebugFuncEntry

    local -r PACKAGE_NAME=${1:?no package name supplied}
    local -i result_code=0

    if ! QPKG.IsSupportBackup "$PACKAGE_NAME"; then
        MarkOperationAsSkipped show "$PACKAGE_NAME" backup "it does not support backup"
        DebugFuncExit 2; return
    fi

    if QPKGs.IsNtInstalled.Exist "$PACKAGE_NAME"; then
        MarkOperationAsSkipped show "$PACKAGE_NAME" backup "it's not installed"
        DebugFuncExit 2; return
    fi

    local -r PACKAGE_INIT_PATHFILE=$(QPKG.ServicePathFile "$PACKAGE_NAME")
    local -r LOG_PATHFILE=$LOGS_PATH/$PACKAGE_NAME.$BACKUP_LOG_FILE

    DebugAsProc "backing-up $(FormatAsPackageName "$PACKAGE_NAME") configuration"
    RunAndLog "$SH_CMD $PACKAGE_INIT_PATHFILE backup" "$LOG_PATHFILE" log:failure-only
    result_code=$?

    if [[ $result_code -eq 0 ]]; then
        DebugAsDone "backed-up $(FormatAsPackageName "$PACKAGE_NAME") configuration"
        MarkOperationAsDone "$PACKAGE_NAME" backup
        QPKG.StoreServiceStatus "$PACKAGE_NAME"
        QPKGs.IsNtBackedUp.Remove "$PACKAGE_NAME"
        QPKGs.IsBackedUp.Add "$PACKAGE_NAME"
    else
        DebugAsWarn "unable to backup $(FormatAsPackageName "$PACKAGE_NAME") configuration $(FormatAsExitcode $result_code)"
        MarkOperationAsError "$PACKAGE_NAME" backup
        result_code=1    # remap to 1
    fi

    DebugFuncExit $result_code

    }

QPKG.DoRestore()
    {

    # calls the service script for the QPKG named in $1 and runs a restore operation

    # input:
    #   $1 = QPKG name

    # output:
    #   $? = 0 if successful, 1 if failed

    DebugFuncEntry

    local -r PACKAGE_NAME=${1:?no package name supplied}
    local -i result_code=0

    if ! QPKG.IsSupportBackup "$PACKAGE_NAME"; then
        MarkOperationAsSkipped show "$PACKAGE_NAME" restore "it does not support backup"
        DebugFuncExit 2; return
    fi

    if QPKGs.IsNtInstalled.Exist "$PACKAGE_NAME"; then
        MarkOperationAsSkipped show "$PACKAGE_NAME" restore "it's not installed"
        DebugFuncExit 2; return
    fi

    local -r PACKAGE_INIT_PATHFILE=$(QPKG.ServicePathFile "$PACKAGE_NAME")
    local -r LOG_PATHFILE=$LOGS_PATH/$PACKAGE_NAME.$RESTORE_LOG_FILE

    DebugAsProc "restoring $(FormatAsPackageName "$PACKAGE_NAME") configuration"
    RunAndLog "$SH_CMD $PACKAGE_INIT_PATHFILE restore" "$LOG_PATHFILE" log:failure-only
    result_code=$?

    if [[ $result_code -eq 0 ]]; then
        DebugAsDone "restored $(FormatAsPackageName "$PACKAGE_NAME") configuration"
        MarkOperationAsDone "$PACKAGE_NAME" restore
        QPKG.StoreServiceStatus "$PACKAGE_NAME"
    else
        DebugAsWarn "unable to restore $(FormatAsPackageName "$PACKAGE_NAME") configuration $(FormatAsExitcode $result_code)"
        MarkOperationAsError "$PACKAGE_NAME" restore
    fi

    DebugFuncExit $result_code

    }

QPKG.ClearAppCenterNotifier()
    {

    # $1 = QPKG name to clear from notifier list

    local -r PACKAGE_NAME=${1:?no package name supplied}

    # KLUDGE: 'clean' QTS 4.5.1 App Center notifier status
    [[ -e /sbin/qpkg_cli ]] && /sbin/qpkg_cli --clean "$PACKAGE_NAME" &>/dev/null

    QPKGs.IsNtInstalled.Exist "$PACKAGE_NAME" && return 0

    # KLUDGE: need this for 'Entware' and 'Par2' packages as they don't add a status line to qpkg.conf
    /sbin/setcfg "$PACKAGE_NAME" Status complete -f /etc/config/qpkg.conf

    return 0

    }

QPKG.ClearServiceStatus()
    {

    # input:
    #   $1 = QPKG name

    [[ -e /var/run/${1:-}.last.operation ]] && rm /var/run/"${1:-}".last.operation

    }

QPKG.StoreServiceStatus()
    {

    # input:
    #   $1 = QPKG name

    local -r PACKAGE_NAME=${1:?no package name supplied}

    if ! local status=$(QPKG.GetServiceStatus "$PACKAGE_NAME"); then
        DebugAsWarn "unable to get status of $(FormatAsPackageName "$PACKAGE_NAME") service. It may be a non-$PROJECT_NAME package, or a package earlier than 200816c that doesn't support service results."
        return 1
    fi

    case $status in
        starting|stopping|restarting)
            DebugInfo "$(FormatAsPackageName "$PACKAGE_NAME") service is $status"
            ;;
        ok)
            DebugInfo "$(FormatAsPackageName "$PACKAGE_NAME") service operation completed OK"
            ;;
        failed)
            ShowAsFail "$(FormatAsPackageName "$PACKAGE_NAME") service operation failed.$([[ -e /var/log/$PACKAGE_NAME.log ]] && echo " Check $(FormatAsFileName "/var/log/$PACKAGE_NAME.log") for more information")"
            ;;
        *)
            DebugAsWarn "$(FormatAsPackageName "$PACKAGE_NAME") service status is incorrect"
    esac

    return 0

    }

# QPKG capabilities

QPKG.ServicePathFile()
    {

    # input:
    #   $1 = QPKG name

    # output:
    #   stdout = service pathfile
    #   $? = 0 if found, !0 if not

    /sbin/getcfg "${1:-}" Shell -d unknown -f /etc/config/qpkg.conf

    }

QPKG.Available.Version()
    {

    # Returns the version number of an available QPKG.

    # input:
    #   $1 = QPKG name

    # output:
    #   stdout = package version
    #   $? = 0 if found, !0 if not

    local -i index=0
    local package=''
    local previous=''

    for index in "${!MANAGER_QPKG_NAME[@]}"; do
        package="${MANAGER_QPKG_NAME[$index]}"
        [[ $package = "$previous" ]] && continue || previous=$package

        if [[ $1 = "$package" ]]; then
            echo "${MANAGER_QPKG_VERSION[$index]}"
            return 0
        fi
    done

    return 1

    }

QPKG.Local.Version()
    {

    # Returns the version number of an installed QPKG.

    # input:
    #   $1 = QPKG name

    # output:
    #   stdout = package version
    #   $? = 0 if found, !0 if not

    /sbin/getcfg "${1:-}" Version -d unknown -f /etc/config/qpkg.conf

    }

QPKG.IsSupportBackup()
    {

    # does this QPKG support 'backup' and 'restore' operations?

    # input:
    #   $1 = QPKG name

    # output:
    #   $? = 0 if true, 1 if false

    local -i index=0

    for index in "${!MANAGER_QPKG_NAME[@]}"; do
        if [[ ${MANAGER_QPKG_NAME[$index]} = "${1:?no package name supplied}" ]]; then
            if ${MANAGER_QPKG_SUPPORTS_BACKUP[$index]}; then
                return 0
            else
                return 1
            fi
        fi
    done

    return 1

    }

QPKG.IsSupportUpdateOnRestart()
    {

    # does this QPKG support updating the internal application when the QPKG is restarted?

    # input:
    #   $1 = QPKG name

    # output:
    #   $? = 0 if true, 1 if false

    local -i index=0

    for index in "${!MANAGER_QPKG_NAME[@]}"; do
        if [[ ${MANAGER_QPKG_NAME[$index]} = "${1:?no package name supplied}" ]]; then
            if ${MANAGER_QPKG_RESTART_TO_UPDATE[$index]}; then
                return 0
            else
                return 1
            fi
        fi
    done

    return 1

    }

QPKG.Abbrvs()
    {

    # input:
    #   $1 = QPKG name

    # output:
    #   $? = 0 if successful, 1 if failed
    #   stdout = list of acceptable abbreviations that may be used to specify this package

    local -i index=0

    for index in "${!MANAGER_QPKG_NAME[@]}"; do
        if [[ ${1:?no package name supplied} = "${MANAGER_QPKG_NAME[$index]}" ]]; then
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
    local -i package_index=0
    local -i abb_index=0
    local -i result_code=1

    for package_index in "${!MANAGER_QPKG_NAME[@]}"; do
        abbs=(${MANAGER_QPKG_ABBRVS[$package_index]})

        for abb_index in "${!abbs[@]}"; do
            if [[ ${abbs[$abb_index]} = "$1" ]]; then
                Display "${MANAGER_QPKG_NAME[$package_index]}"
                result_code=0
                break 2
            fi
        done
    done

    return $result_code

    }

QPKG.PathFilename()
    {

    # input:
    #   $1 = QPKG name

    # output:
    #   stdout = QPKG local filename
    #   $? = 0 if successful, 1 if failed

    local -r URL=$(QPKG.URL "${1:-}")

    [[ -n ${URL:-} ]] || return

    echo "$QPKG_DL_PATH/$($BASENAME_CMD "$URL")"

    return 0

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

QPKG.MinRAM()
    {

    # input:
    #   $1 = QPKG name

    # output:
    #   stdout = the minimum kB of installed RAM required by this QPKG
    #   $? = 0 if successful, 1 if failed

    local -i index=0

    for index in "${!MANAGER_QPKG_NAME[@]}"; do
        if [[ $1 = "${MANAGER_QPKG_NAME[$index]}" ]] && [[ ${MANAGER_QPKG_MIN_RAM_KB[$index]} = any || $INSTALLED_RAM_KB -ge ${MANAGER_QPKG_MIN_RAM_KB[$index]} ]]; then
            echo "${MANAGER_QPKG_MIN_RAM_KB[$index]}"
            return 0
        fi
    done

    return 1

    }

QPKG.GetStandalones()
    {

    # input:
    #   $1 = QPKG name to return standalones for

    # output:
    #   $? = 0 if successful, 1 if failed

    local -i index=0

    for index in "${!MANAGER_QPKG_NAME[@]}"; do
        if [[ $1 = "${MANAGER_QPKG_NAME[$index]}" ]] && [[ ${MANAGER_QPKG_ARCH[$index]} = all || ${MANAGER_QPKG_ARCH[$index]} = "$NAS_QPKG_ARCH" ]]; then
            if [[ ${MANAGER_QPKG_DEPENDS_ON[$index]} != none ]]; then
                echo "${MANAGER_QPKG_DEPENDS_ON[$index]}"
                return 0
            fi
        fi
    done

    return 1

    }

QPKG.GetDependents()
    {

    # input:
    #   $1 = standalone QPKG name to return dependents for

    # output:
    #   $? = 0 if successful, 1 if failed

    local -i index=0
    local -a acc=()

    if QPKGs.ScStandalone.Exist "$1"; then
        for index in "${!MANAGER_QPKG_NAME[@]}"; do
            if [[ ${MANAGER_QPKG_DEPENDS_ON[$index]} == *"$1"* ]]; then
                [[ ${acc[*]:-} != "${MANAGER_QPKG_NAME[$index]}" ]] && acc+=(${MANAGER_QPKG_NAME[$index]})
            fi
        done
    fi

    if [[ ${#acc[@]} -gt 0 ]]; then
        echo "${acc[@]}"
        return 0
    fi

    return 1

    }

# QPKG states

QPKG.IsInstalled()
    {

    # input:
    #   $1 = package name to check

    # output:
    #   $? = 0 (true) or 1 (false)

    $GREP_CMD -q "^\[${1:?no package name supplied}\]" /etc/config/qpkg.conf

    }

QPKG.IsStarted()
    {

    # input:
    #   $1 = package name to check

    # output:
    #   $? = 0 (true) or 1 (false)

    [[ $(/sbin/getcfg "${1:?no package name supplied}" Enable -u -f /etc/config/qpkg.conf) = 'TRUE' ]]

    }

QPKG.GetServiceStatus()
    {

    # input:
    #   $1 = QPKG name

    # output:
    #   $stdout = last known package service status
    #   $? = 0 if found, 1 if not found

    local -r PACKAGE_NAME=${1:?no package name supplied}

    [[ -e /var/run/$PACKAGE_NAME.last.operation ]] && echo "$(</var/run/"$PACKAGE_NAME".last.operation)"

    }

MakePath()
    {

    mkdir -p "${1:?empty}" 2>/dev/null; result_code=$?

    if [[ $result_code -ne 0 ]]; then
        ShowAsEror "unable to create ${2:?empty} path $(FormatAsFileName "$1") $(FormatAsExitcode $result_code)"
        [[ $(type -t Session.SuggestIssue.Init) = function ]] && Session.SuggestIssue.Set
        return 1
    fi

    return 0

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

    DebugFuncEntry

    local msgs=/var/log/execd.log
    local -i result_code=0

    FormatAsCommand "${1:?empty}" > "${2:?empty}"
    DebugAsProc "exec: '$1'"

    if Session.Debug.ToScreen.IsSet; then
        $1 > >($TEE_CMD "$msgs") 2>&1   # NOTE: 'tee' buffers stdout here
        result_code=$?
    else
        $1 > "$msgs" 2>&1
        result_code=$?
    fi

    if [[ -e $msgs ]]; then
        FormatAsResultAndStdout "$result_code" "$(<"$msgs")" >> "$2"
        rm -f "$msgs"
    else
        FormatAsResultAndStdout "$result_code" '<null>' >> "$2"
    fi

    if [[ $result_code -eq 0 ]]; then
        [[ ${3:-} != log:failure-only ]] && AddFileToDebug "$2"
    else
        [[ $result_code -ne ${4:-} ]] && AddFileToDebug "$2"
    fi

    DebugFuncExit $result_code

    }

DeDupeWords()
    {

    tr ' ' '\n' <<< "${1:-}" | $SORT_CMD | $UNIQ_CMD | tr '\n' ' ' | $SED_CMD 's|^[[:blank:]]*||;s|[[:blank:]]*$||'

    }

FileMatchesMD5()
    {

    # input:
    #   $1 = pathfile to generate an MD5 checksum for
    #   $2 = MD5 checksum to compare against

    [[ $($MD5SUM_CMD "${1:?pathfile null}" | cut -f1 -d' ') = "${2:?comparison checksum null}" ]]

    }

Plural()
    {

    [[ ${1:-0} -ne 1 ]] && echo s

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

    ColourTextBrightWhite "${PROJECT_NAME:-default project name}"

    }

FormatAsHelpAction()
    {

    ColourTextBrightYellow '[action]'

    }

FormatAsHelpPackages()
    {

    ColourTextBrightOrange '[packages...]'

    }

FormatAsHelpOptions()
    {

    ColourTextBrightRed '[options...]'

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
        echo "= result_code: $(FormatAsExitcode "$1")"
    else
        echo "! result_code: $(FormatAsExitcode "$1")"
    fi

    }

FormatAsScript()
    {

    echo SCRIPT

    }

FormatAsHardware()
    {

    echo HARDWARE

    }

FormatAsFirmware()
    {

    echo FIRMWARE

    }

FormatAsUserspace()
    {

    echo USERSPACE

    }

FormatAsResultAndStdout()
    {

    if [[ ${1:-0} -eq 0 ]]; then
        echo "= result_code: $(FormatAsExitcode "$1") ***** stdout/stderr begins below *****"
    else
        echo "! result_code: $(FormatAsExitcode "$1") ***** stdout/stderr begins below *****"
    fi

    echo "${2:-stdout}"
    echo '= ***** stdout/stderr is complete *****'

    }

DisplayLineSpaceIfNoneAlready()
    {

    if Session.LineSpace.IsNt && Session.Display.Clean.IsNt; then
        echo
        Session.LineSpace.Set
    else
        Session.LineSpace.Clear
    fi

    }

readonly DEBUG_LOG_DATAWIDTH=100
readonly DEBUG_LOG_FIRST_COL_WIDTH=9
readonly DEBUG_LOG_SECOND_COL_WIDTH=17

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

    DebugAsLog "$(eval printf '%0.s-' "{1..$DEBUG_LOG_DATAWIDTH}")"     # 'seq' is unavailable in QTS, so must resort to 'eval' trickery instead

    }

DebugScript()
    {

    DebugDetectedTabulated "$(FormatAsScript)" "${1:-}" "${2:-}"

    }

DebugHardwareOK()
    {

    DebugDetectedTabulated "$(FormatAsHardware)" "${1:-}" "${2:-}"

    }

DebugFirmwareOK()
    {

    DebugDetectedTabulated "$(FormatAsFirmware)" "${1:-}" "${2:-}"

    }

DebugFirmwareWarning()
    {

    DebugWarningTabulated "$(FormatAsFirmware)" "${1:-}" "${2:-}"

    }

DebugUserspaceOK()
    {

    DebugDetectedTabulated "$(FormatAsUserspace)" "${1:-}" "${2:-}"

    }

DebugUserspaceWarning()
    {

    DebugWarningTabulated "$(FormatAsUserspace)" "${1:-}" "${2:-}"

    }

DebugQPKGDetected()
    {

    DebugDetectedTabulated 'QPKG' "${1:-}" "${2:-}"

    }

DebugQPKGInfo()
    {

    DebugInfoTabulated 'QPKG' "${1:-}" "${2:-}"

    }

DebugQPKGWarning()
    {

    DebugWarningTabulated 'QPKG' "${1:-}" "${2:-}"

    }

DebugDetectedTabulated()
    {

    if [[ -z $3 ]]; then                # if $3 is nothing, then assume only 2 fields are required
        DebugAsDetected "$(printf "%${DEBUG_LOG_FIRST_COL_WIDTH}s: %${DEBUG_LOG_SECOND_COL_WIDTH}s\n" "${1:-}" "${2:-}")"
    elif [[ $3 = ' ' ]]; then           # if $3 is only a whitespace then print $2 with trailing colon and 'none' as third field
        DebugAsDetected "$(printf "%${DEBUG_LOG_FIRST_COL_WIDTH}s: %${DEBUG_LOG_SECOND_COL_WIDTH}s: none\n" "${1:-}" "${2:-}")"
    elif [[ ${3: -1} = ' ' ]]; then     # if $3 has a trailing whitespace then print $3 without the trailing whitespace
        DebugAsDetected "$(printf "%${DEBUG_LOG_FIRST_COL_WIDTH}s: %${DEBUG_LOG_SECOND_COL_WIDTH}s: %-s\n" "${1:-}" "${2:-}" "$($SED_CMD 's| *$||' <<< "${3:-}")")"
    else
        DebugAsDetected "$(printf "%${DEBUG_LOG_FIRST_COL_WIDTH}s: %${DEBUG_LOG_SECOND_COL_WIDTH}s: %-s\n" "${1:-}" "${2:-}" "${3:-}")"
    fi

    }

DebugInfoTabulated()
    {

    if [[ -z $3 ]]; then                # if $3 is nothing, then assume only 2 fields are required
        DebugAsInfo "$(printf "%${DEBUG_LOG_FIRST_COL_WIDTH}s: %${DEBUG_LOG_SECOND_COL_WIDTH}s\n" "${1:-}" "${2:-}")"
    elif [[ $3 = ' ' ]]; then           # if $3 is only a whitespace then print $2 with trailing colon and 'none' as third field
        DebugAsInfo "$(printf "%${DEBUG_LOG_FIRST_COL_WIDTH}s: %${DEBUG_LOG_SECOND_COL_WIDTH}s: none\n" "${1:-}" "${2:-}")"
    elif [[ ${3: -1} = ' ' ]]; then     # if $3 has a trailing whitespace then print $3 without the trailing whitespace
        DebugAsInfo "$(printf "%${DEBUG_LOG_FIRST_COL_WIDTH}s: %${DEBUG_LOG_SECOND_COL_WIDTH}s: %-s\n" "${1:-}" "${2:-}" "$($SED_CMD 's| *$||' <<< "${3:-}")")"
    else
        DebugAsInfo "$(printf "%${DEBUG_LOG_FIRST_COL_WIDTH}s: %${DEBUG_LOG_SECOND_COL_WIDTH}s: %-s\n" "${1:-}" "${2:-}" "${3:-}")"
    fi

    }

DebugWarningTabulated()
    {

    if [[ -z $3 ]]; then                # if $3 is nothing, then assume only 2 fields are required
        DebugAsWarn "$(printf "%${DEBUG_LOG_FIRST_COL_WIDTH}s: %${DEBUG_LOG_SECOND_COL_WIDTH}s\n" "${1:-}" "${2:-}")"
    elif [[ $3 = ' ' ]]; then           # if $3 is only a whitespace then print $2 with trailing colon and 'none' as third field
        DebugAsWarn "$(printf "%${DEBUG_LOG_FIRST_COL_WIDTH}s: %${DEBUG_LOG_SECOND_COL_WIDTH}s: none\n" "${1:-}" "${2:-}")"
    elif [[ ${3: -1} = ' ' ]]; then     # if $3 has a trailing whitespace then print $3 without the trailing whitespace
        DebugAsWarn "$(printf "%${DEBUG_LOG_FIRST_COL_WIDTH}s: %${DEBUG_LOG_SECOND_COL_WIDTH}s: %-s\n" "${1:-}" "${2:-}" "$($SED_CMD 's| *$||' <<< "${3:-}")")"
    else
        DebugAsWarn "$(printf "%${DEBUG_LOG_FIRST_COL_WIDTH}s: %${DEBUG_LOG_SECOND_COL_WIDTH}s: %-s\n" "${1:-}" "${2:-}" "${3:-}")"
    fi

    }

DebugVar()
    {

    DebugAsVar "\$${1:-} : '${!1:-}'"

    }

DebugInfo()
    {

    if [[ ${2:-} = ' ' || ${2:-} = "'' " ]]; then   # if $2 has no usable content then print $1 with trailing colon and 'none' as second field
        DebugAsInfo "$1: none"
    elif [[ -n ${2:-} ]]; then
        DebugAsInfo "$1: $2"
    else
        DebugAsInfo "$1"
    fi

    }

DebugFuncEntry()
    {

    local var_name=${FUNCNAME[1]}_STARTSECONDS
    local var_safe_name=${var_name//[.-]/_}
    eval "$var_safe_name=$(/bin/date +%s%N)"    # hardcode 'date' here as this function is called before binaries are cherry-picked.

    DebugThis "(>>) ${FUNCNAME[1]}"

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

    DebugThis "(<<) ${FUNCNAME[1]}|${1:-0}|$code_pointer|$elapsed_time"

    return ${1:-0}

    }

DebugAsProc()
    {

    DebugThis "(--) $1 ..."

    }

DebugAsDone()
    {

    DebugThis "(==) $1"

    }

DebugAsDetected()
    {

    DebugThis "(**) $1"

    }

DebugAsInfo()
    {

    DebugThis "(II) $1"

    }

DebugAsWarn()
    {

    DebugThis "(WW) $1"

    }

DebugAsError()
    {

    DebugThis "(EE) $1"

    }

DebugAsLog()
    {

    DebugThis "(LL) ${1:-}"

    }

DebugAsVar()
    {

    DebugThis "(vv) $1"

    }

DebugThis()
    {

    [[ $(type -t Session.Debug.ToScreen.Init) = function ]] && Session.Debug.ToScreen.IsSet && ShowAsDebug "${1:-}"
    WriteAsDebug "$1"

    }

AddFileToDebug()
    {

    # Add the contents of specified pathfile $1 to the runtime log

    local linebuff=''
    local screen_debug=false

    DebugExtLogMinorSeparator
    DebugAsLog 'adding external log to main log ...'

    if Session.Debug.ToScreen.IsSet; then      # prevent external log contents appearing onscreen again - it's already been seen "live".
        screen_debug=true
        Session.Debug.ToScreen.Clear
    fi

    DebugAsLog "$(FormatAsLogFilename "${1:?no filename supplied}")"

    while read -r linebuff; do
        DebugAsLog "$linebuff"
    done < "$1"

    [[ $screen_debug = true ]] && Session.Debug.ToScreen.Set
    DebugExtLogMinorSeparator

    }

ShowAsProcLong()
    {

    ShowAsProc "$1 (might take a while)" "${2:-}"

    }

ShowAsProc()
    {

    local suffix=''

    [[ -n ${2:-} ]] && suffix=" $2"

    SmartCR
    WriteToDisplayWait "$(ColourTextBrightOrange proc)" "$1 ...$suffix"
    WriteToLog proc "$1 ...$suffix"
    [[ $(type -t Session.Debug.ToScreen.Init) = function ]] && Session.Debug.ToScreen.IsSet && Display

    }

ShowAsDebug()
    {

    WriteToDisplayNew "$(ColourTextBlackOnCyan dbug)" "$1"

    }

ShowAsInfo()
    {

    # note to user

    SmartCR
    WriteToDisplayNew "$(ColourTextBrightYellow note)" "$1"
    WriteToLog note "$1"

    }

ShowAsReco()
    {

    # recommendation

    SmartCR
    WriteToDisplayNew "$(ColourTextBrightOrange reco)" "$1"
    WriteToLog note "$1"

    }

ShowAsQuiz()
    {

    WriteToDisplayWait "$(ColourTextBrightOrangeBlink quiz)" "$1: "
    WriteToLog quiz "$1:"

    }

ShowAsQuizDone()
    {

    WriteToDisplayNew "$(ColourTextBrightOrange quiz)" "$1"

    }

ShowAsDone()
    {

    # process completed OK

    SmartCR
    WriteToDisplayNew "$(ColourTextBrightGreen 'done')" "$1"
    WriteToLog 'done' "$1"

    }

ShowAsWarn()
    {

    # warning only

    SmartCR
    WriteToDisplayNew "$(ColourTextBrightOrange warn)" "$1"
    WriteToLog warn "$1"

    }

ShowAsAbort()
    {

    local capitalised="$(tr 'a-z' 'A-Z' <<< "${1:0:1}")${1:1}"      # use any available 'tr'

    WriteToDisplayNew "$(ColourTextBrightRed eror)" "$capitalised: aborting ..."
    WriteToLog eror "$capitalised: aborting"
    Session.Error.Set

    }

ShowAsFail()
    {

    # non-fatal error

    SmartCR

    local capitalised="$(tr 'a-z' 'A-Z' <<< "${1:0:1}")${1:1}"      # use any available 'tr'

    WriteToDisplayNew "$(ColourTextBrightRed fail)" "$capitalised"
    WriteToLog fail "$capitalised."

    }

ShowAsEror()
    {

    # fatal error

    SmartCR

    local capitalised="$(tr 'a-z' 'A-Z' <<< "${1:0:1}")${1:1}"      # use any available 'tr'

    WriteToDisplayNew "$(ColourTextBrightRed eror)" "$capitalised"
    WriteToLog eror "$capitalised."
    Session.Error.Set

    }

ShowAsOperationProgress()
    {

    # show QPKG operations progress as percent-complete and a fraction of the total

    # $1 = tier (optional)
    # $2 = package type: 'QPKG', 'IPKG', 'PIP', etc ...
    # $3 = pass count
    # $4 = fail count
    # $5 = total count
    # $6 = verb (present)
    # $7 = 'long' (optional)

    if [[ -n $1 && $1 != All ]]; then
        local tier=" $(tr 'A-Z' 'a-z' <<<$1)"
    else
        local tier=''
    fi

    local -r PACKAGE_TYPE=${2:?empty}
    local -i pass_count=${3:-0}
    local -i fail_count=${4:-0}
    local -i total_count=${5:-0}
    local -r ACTION_PRESENT=${6:?empty}
    local -r DURATION=${7:-}
    local -i tweaked_passes=$((pass_count+1))              # never show zero (e.g. 0/8)
    local -i tweaked_total=$((total_count-fail_count))     # auto-adjust upper limit to account for failures

    [[ $tweaked_total -eq 0 ]] && return 1              # no-point showing a fraction of zero

    if [[ $tweaked_passes -gt $tweaked_total ]]; then
        tweaked_passes=$((tweaked_total-fail_count))
        percent='100%'
    else
        percent="$((200*(tweaked_passes)/(tweaked_total+1) % 2 + 100*(tweaked_passes)/(tweaked_total+1)))%"
    fi

    if [[ $DURATION = long ]]; then
        ShowAsProcLong "$ACTION_PRESENT ${tweaked_total}${tier} ${PACKAGE_TYPE}$(Plural "$tweaked_total")" "$percent ($tweaked_passes/$tweaked_total)"
    else
        ShowAsProc "$ACTION_PRESENT ${tweaked_total}${tier} ${PACKAGE_TYPE}$(Plural "$tweaked_total")" "$percent ($tweaked_passes/$tweaked_total)"
    fi

    [[ $percent = '100%' ]] && sleep 1

    return 0

    }

ShowAsOperationResult()
    {

    # $1 = tier (optional)
    # $2 = package type: 'QPKG', 'IPKG', 'PIP', etc ...
    # $3 = pass count
    # $4 = fail count
    # $5 = total count
    # $6 = verb (past)
    # $7 = 'long' (optional)

    if [[ -n $1 && $1 != All ]]; then
        local tier=" $(tr 'A-Z' 'a-z' <<<$1)"
    else
        local tier=''
    fi

    local -r PACKAGE_TYPE=${2:?empty}
    local -i pass_count=${3:-0}
    local -i fail_count=${4:-0}
    local -i total_count=${5:-0}
    local -r ACTION_PAST=${6:?empty}
    local -r DURATION=${7:-}

    [[ $total_count -eq 0 ]] && return 1

    if [[ $pass_count -eq 0 ]]; then
        ShowAsFail "$ACTION_PAST ${fail_count}${tier} ${PACKAGE_TYPE}$(Plural "$fail_count") failed"
    elif [[ $fail_count -gt 0 ]]; then
        ShowAsWarn "$ACTION_PAST ${pass_count}${tier} ${PACKAGE_TYPE}$(Plural "$pass_count"), but ${fail_count}${tier} ${PACKAGE_TYPE}$(Plural "$fail_count") failed"
    elif [[ $pass_count -gt 0 ]]; then
        ShowAsDone "$ACTION_PAST ${pass_count}${tier} ${PACKAGE_TYPE}$(Plural "$pass_count")"
    else
        DebugAsDone "no${tier} ${PACKAGE_TYPE}s processed"
    fi

    return 0

    }

WriteAsDebug()
    {

    WriteToLog dbug "$1"

    }

WriteToDisplayWait()
    {

    # Writes a new message without newline

    # input:
    #   $1 = pass/fail
    #   $2 = message

    # output:
    #   $previous_msg = global and will be used again later

    previous_msg=$(printf "%-10s: %s" "${1:-}" "${2:-}")
    DisplayWait "$previous_msg"

    return 0

    }

WriteToDisplayNew()
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
    local -i this_length=0
    local -i blanking_length=0

    [[ ${previous_msg:-_none_} = _none_ ]] && previous_msg=''

    this_message=$(printf "%-10s: %s" "${1:-}" "${2:-}")

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

    [[ $(type -t Session.Debug.ToFile.Init) = function ]] && Session.Debug.ToFile.IsNt && return
    [[ -n ${SESSION_ACTIVE_PATHFILE:-} ]] && printf "%-4s: %s\n" "$(StripANSI "${1:-}")" "$(StripANSI "${2:-}")" >> "$SESSION_ACTIVE_PATHFILE"

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

    echo -en "${1:-}"'\033[0m'

    }

StripANSI()
    {

    # QTS 4.2.6 BusyBox 'sed' doesn't fully support extended regexes, so this only works with a real 'sed'.

    if [[ -e ${GNU_SED_CMD:-} ]]; then
        $GNU_SED_CMD -r 's/\x1b\[[0-9;]*m//g' <<< "${1:-}"
    else
        echo "${1:-}"
    fi

    }

ConvertSecsToHoursMinutesSecs()
    {

    # http://stackoverflow.com/questions/12199631/convert-seconds-to-hours-minutes-seconds

    # input:
    #   $1 = a time in seconds to convert to 'hh:mm:ss'

    ((h=${1:-0}/3600))
    ((m=(${1:-0}%3600)/60))
    ((s=${1:-0}%60))

    printf "%02dh:%02dm:%02ds\n" "$h" "$m" "$s"

    }

CTRL_C_Captured()
    {

    RemoveDirSizeMonitorFlagFile

    exit

    }

AddListObj()
    {

    # $1 = object name to create

    local public_function_name=${1:?no object name supplied}
    local safe_function_name="$(tr 'A-Z' 'a-z' <<< "${public_function_name//[.-]/_}")"

    _placeholder_size_=_ob_${safe_function_name}_sz_
    _placeholder_array_=_ob_${safe_function_name}_ar_
    _placeholder_array_index_=_ob_${safe_function_name}_arin_

echo $public_function_name'.Add()
{ local ar=(${1}) it='\'\''
[[ ${#ar[@]} -eq 0 ]] && return
for it in "${ar[@]:-}"; do
[[ " ${'$_placeholder_array_'[*]+"${'$_placeholder_array_'[@]}"} " != *"$it"* ]] && '$_placeholder_array_'+=("$it")
done ;}
'$public_function_name'.Array()
{ echo -n "${'$_placeholder_array_'[@]+"${'$_placeholder_array_'[@]}"}" ;}
'$public_function_name'.Count()
{ echo "${#'$_placeholder_array_'[@]}" ;}
'$public_function_name'.Exist()
{ [[ ${'$_placeholder_array_'[*]:-} == *"$1"* ]] ;}
'$public_function_name'.Init()
{ '$_placeholder_size_'=0
'$_placeholder_array_'=()
'$_placeholder_array_index_'=1 ;}
'$public_function_name'.IsAny()
{ [[ ${#'$_placeholder_array_'[@]} -gt 0 ]] ;}
'$public_function_name'.IsNone()
{ [[ ${#'$_placeholder_array_'[@]} -eq 0 ]] ;}
'$public_function_name'.List()
{ echo -n "${'$_placeholder_array_'[*]+"${'$_placeholder_array_'[@]}"}" ;}
'$public_function_name'.ListCSV()
{ echo -n "${'$_placeholder_array_'[*]+"${'$_placeholder_array_'[@]}"}" | tr '\' \'' '\',\'' ;}
'$public_function_name'.Remove()
{ local agar=(${1}) tmar=() ag='\'\'' it='\'\'' m=false
for it in "${'$_placeholder_array_'[@]+"${'$_placeholder_array_'[@]}"}"; do
m=false
for ag in "${agar[@]+"${agar[@]}"}"; do
if [[ $ag = $it ]]; then
m=true; break
fi
done
[[ $m = false ]] && tmar+=("$it")
done
'$_placeholder_array_'=("${tmar[@]+"${tmar[@]}"}")
[[ -z ${'$_placeholder_array_'[*]+"${'$_placeholder_array_'[@]}"} ]] && '$_placeholder_array_'=() ;}
'$public_function_name'.Size()
{ if [[ -n ${1:-} && ${1:-} = "=" ]]; then
'$_placeholder_size_'=$2
else
echo -n $'$_placeholder_size_'
fi ;}
'$public_function_name'.Init' >> "$COMPILED_OBJECTS_PATHFILE"

    return 0

    }

AddFlagObj()
    {

    # $1 = object name to create

    local public_function_name=${1:?no object name supplied}
    local safe_function_name="$(tr 'A-Z' 'a-z' <<< "${public_function_name//[.-]/_}")"

    _placeholder_text_=_ob_${safe_function_name}_tx_
    _placeholder_flag_=_ob_${safe_function_name}_fl_
    _placeholder_log_changes_flag_=_ob_${safe_function_name}_chfl_

echo $public_function_name'.Clear()
{ [[ $'$_placeholder_flag_' != '\'true\'' ]] && return
'$_placeholder_flag_'=false
[[ $'$_placeholder_log_changes_flag_' = '\'true\'' ]] && DebugVar '$_placeholder_flag_' ;}
'$public_function_name'.NoLogMods()
{ [[ $'$_placeholder_log_changes_flag_' != '\'true\'' ]] && return
'$_placeholder_log_changes_flag_'=false ;}
'$public_function_name'.Init()
{ '$_placeholder_text_'='\'\''
'$_placeholder_flag_'=false
'$_placeholder_log_changes_flag_'=true ;}
'$public_function_name'.IsNt()
{ [[ $'$_placeholder_flag_' != '\'true\'' ]] ;}
'$public_function_name'.IsSet()
{ [[ $'$_placeholder_flag_' = '\'true\'' ]] ;}
'$public_function_name'.Set()
{ [[ $'$_placeholder_flag_' = '\'true\'' ]] && return
'$_placeholder_flag_'=true
[[ $'$_placeholder_log_changes_flag_' = '\'true\'' ]] && DebugVar '$_placeholder_flag_' ;}
'$public_function_name'.Text()
{ if [[ -n ${1:-} && $1 = "=" ]]; then
'$_placeholder_text_'=$2
else
echo -n "$'$_placeholder_text_'"
fi ;}
'$public_function_name'.Init' >> "$COMPILED_OBJECTS_PATHFILE"

    return 0

    }

CheckLocalObjects()
    {

    [[ -e $COMPILED_OBJECTS_PATHFILE ]] && FileMatchesMD5 "$COMPILED_OBJECTS_PATHFILE" "$(CompileObjects hash)" && return 0
    rm -f "$COMPILED_OBJECTS_PATHFILE"

    return 1

    }

GetRemoteObjects()
    {

    if [[ ! -e $COMPILED_OBJECTS_PATHFILE ]]; then
        if $CURL_CMD${curl_insecure_arg:-} --silent --fail "$COMPILED_OBJECTS_URL" > "$COMPILED_OBJECTS_ARCHIVE_PATHFILE"; then
            /bin/tar --extract --gzip --file="$COMPILED_OBJECTS_ARCHIVE_PATHFILE" --directory="$($DIRNAME_CMD "$COMPILED_OBJECTS_PATHFILE")"
            [[ -s $COMPILED_OBJECTS_PATHFILE ]] && return 0
        fi
    fi

    rm -f "$COMPILED_OBJECTS_PATHFILE"

    return 1

    }

CompileObjects()
    {

    # builds a new [compiled.objects] file in the local work path

    # $1 = 'hash' (optional) return the internal checksum

    local -r COMPILED_OBJECTS_HASH=7a3bea4b7bc7fb45999c777e5c573f1d
    local element=''
    local operation=''
    local scope=''
    local state=''

    if [[ ${1:-} = hash ]]; then
        echo "$COMPILED_OBJECTS_HASH"
        return
    fi

    if ! CheckLocalObjects; then
        GetRemoteObjects
        CheckLocalObjects
    fi

    if [[ ! -e $COMPILED_OBJECTS_PATHFILE ]]; then
        ShowAsProc 'compiling' >&2

        # session flags
        for element in Display.Clean LineSpace ShowBackupLoc SuggestIssue Summary; do
            AddFlagObj Session.$element
        done

        for element in ToArchive ToFile ToScreen; do
            AddFlagObj Session.Debug.$element
        done

        AddFlagObj QPKGs.States.Built
        AddFlagObj QPKGs.SkProc
        AddFlagObj IPKGs.ToUpgrade
        AddFlagObj IPKGs.ToInstall

        # user option flags
        for element in Deps.Check IgFreeSpace Versions.View; do
            AddFlagObj Opts.$element
        done

        for element in Abbreviations Actions ActionsAll Backups Basic Options Packages Problems Status Tips; do
            AddFlagObj Opts.Help.$element
        done

        for element in All Last Tail; do
            AddFlagObj Opts.Log.$element.Paste
            AddFlagObj Opts.Log.$element.View
        done

        for scope in "${PACKAGE_SCOPES[@]}"; do
            AddFlagObj Opts.Apps.List.Sc${scope}
            AddFlagObj Opts.Apps.List.ScNt${scope}
        done

        for state in "${PACKAGE_STATES[@]}"; do
            AddFlagObj Opts.Apps.List.Is${state}
            AddFlagObj Opts.Apps.List.IsNt${state}
        done

        for scope in "${PACKAGE_SCOPES[@]}"; do
            for operation in "${PACKAGE_OPERATIONS[@]}"; do
                AddFlagObj Opts.Apps.Op${operation}.Sc${scope}
                AddFlagObj Opts.Apps.Op${operation}.ScNt${scope}
            done
        done

        for state in "${PACKAGE_STATES[@]}"; do
            for operation in "${PACKAGE_OPERATIONS[@]}"; do
                AddFlagObj Opts.Apps.Op${operation}.Is${state}
                AddFlagObj Opts.Apps.Op${operation}.IsNt${state}
            done
        done

        # lists
        AddListObj Args.Unknown

        for operation in "${PACKAGE_OPERATIONS[@]}"; do
            AddListObj QPKGs.OpTo${operation}      # to operate on
            AddListObj QPKGs.OpOk${operation}      # operation was tried and succeeded
            AddListObj QPKGs.OpEr${operation}      # operation was tried but failed
            AddListObj QPKGs.OpSk${operation}      # operation was skipped
        done

        for operation in Download Install Uninstall Upgrade; do     # only a subset of package operations are supported by IPKGS for-now
            AddListObj IPKGs.OpTo${operation}
        done

        for scope in "${PACKAGE_SCOPES[@]}"; do
            AddListObj QPKGs.Sc${scope}
            AddListObj QPKGs.ScNt${scope}
        done

        for state in "${PACKAGE_STATES[@]}"; do
            AddListObj QPKGs.Is${state}
            AddListObj QPKGs.IsNt${state}
        done

        /bin/tar --create --gzip --file="$COMPILED_OBJECTS_ARCHIVE_PATHFILE" --directory="$($DIRNAME_CMD "$COMPILED_OBJECTS_PATHFILE")" "$($BASENAME_CMD "$COMPILED_OBJECTS_PATHFILE")"
    fi

    ShowAsProc 'objects' >&2
    . "$COMPILED_OBJECTS_PATHFILE"

    return 0

    }

Session.Init || exit
Session.Validate
Tiers.Processor
Session.Results
Session.Error.IsNt
