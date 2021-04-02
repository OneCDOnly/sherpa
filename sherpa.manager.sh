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
    readonly MANAGER_SCRIPT_VERSION=210403

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

    readonly COMPILED_OBJECTS_URL=https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/main/compiled.objects
    readonly EXTERNAL_PACKAGE_ARCHIVE_PATHFILE=/opt/var/opkg-lists/entware
    readonly PREVIOUS_OPKG_PACKAGE_LIST=$WORK_PATH/opkg.prev.installed.list
    readonly PREVIOUS_PIP_MODULE_LIST=$WORK_PATH/pip.prev.installed.list

    readonly COMPILED_OBJECTS_PATHFILE=$WORK_PATH/compiled.objects
    readonly SESSION_ARCHIVE_PATHFILE=$LOGS_PATH/session.archive.log
    readonly SESSION_ACTIVE_PATHFILE=$PROJECT_PATH/session.$$.active.log
    readonly SESSION_LAST_PATHFILE=$LOGS_PATH/session.last.log
    readonly SESSION_TAIL_PATHFILE=$LOGS_PATH/session.tail.log
    readonly EXTERNAL_PACKAGE_LIST_PATHFILE=$WORK_PATH/Packages

    ShowAsProc init >&2

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

    if [[ $USER_ARGS_RAW == *"clean"* ]]; then
        CleanArchivedLogs
        CleanWorkPath
        ArchiveActiveSessionLog
        CleanActiveSessionLog
        exit 0
    fi

    CompileObjects
    Session.Debug.ToArchive.Set
    Session.Debug.ToFile.Set

    if [[ $USER_ARGS_RAW == *"debug"* || $USER_ARGS_RAW == *"verbose"* ]]; then
        Display >&2
        Session.Debug.ToScreen.Set
    fi

    readonly PACKAGE_VERSION=$(QPKG.Local.Version "$PROJECT_NAME")

    DebugInfoMajorSeparator
    DebugScript started "$($DATE_CMD -d @"$SCRIPT_STARTSECONDS" | tr -s ' ')"
    DebugScript version "package: ${PACKAGE_VERSION:-unknown}, manager: ${MANAGER_SCRIPT_VERSION:-unknown}, loader: ${LOADER_SCRIPT_VERSION:-unknown}"
    DebugScript PID "$$"
    DebugInfoMinorSeparator
    DebugInfo 'Markers: (**) detected, (II) information, (WW) warning, (EE) error, (LL) log file, (--) processing,'
    DebugInfo '(==) done, (>>) f entry, (<<) f exit, (vv) variable name & value, ($1) positional argument value'
    DebugInfoMinorSeparator

    Opts.IgnoreFreeSpace.Text = ' --force-space'
    Session.Summary.Set
    Session.LineSpace.DontLogChanges
    QPKGs.SkipProcessing.DontLogChanges

    readonly NAS_FIRMWARE=$(/sbin/getcfg System Version -f /etc/config/uLinux.conf)
    readonly NAS_BUILD=$(/sbin/getcfg System 'Build Number' -f /etc/config/uLinux.conf)
    readonly INSTALLED_RAM_KB=$($GREP_CMD MemTotal /proc/meminfo | cut -f2 -d':' | $SED_CMD 's|kB||;s| ||g')
    readonly LOG_TAIL_LINES=3000    # a full download and install of everything generates a session around 1600 lines, but include a bunch of opkg updates and it can get much longer.
    readonly MIN_PYTHON_VER=392
    code_pointer=0
    pip3_cmd=/opt/bin/pip3
    previous_msg=' '
    [[ ${NAS_FIRMWARE//.} -lt 426 ]] && curl_insecure_arg=' --insecure' || curl_insecure_arg=''
    CalcEntwareType
    CalcQPKGArch

    # supported package details - parallel arrays
    MANAGER_QPKG_NAME=()                    # internal QPKG name
        MANAGER_QPKG_ARCH=()                # QPKG supports this architecture
        MANAGER_QPKG_MINRAM=()              # QPKG requires at-least this much RAM installed in kB. Use 'any' if any amount is OK.
        MANAGER_QPKG_VERSION=()             # QPKG version
        MANAGER_QPKG_URL=()                 # remote QPKG URL
        MANAGER_QPKG_MD5=()                 # remote QPKG MD5
        MANAGER_QPKG_DESC+=()               # QPKG description (applies to all packages with the same name)
        MANAGER_QPKG_ABBRVS=()              # if set, this package is user-installable, and these abbreviations may be used to specify app
        MANAGER_QPKG_DEPENDS_ON=()          # require these QPKGs to be installed first. Use '' if package is standalone.
        MANAGER_QPKG_IPKGS_ADD=()           # require these IPKGs to be installed first
        MANAGER_QPKG_IPKGS_REMOVE=()        # require these IPKGs to be uninstalled first
        MANAGER_QPKG_BACKUP_SUPPORTED=()    # true/false: this QPKG supports configuration 'backup' and 'restore' operations
        MANAGER_QPKG_UPDATE_ON_RESTART=()   # true/false: the internal appplication can be updated by restarting the QPKG

    # pseudo-alpha-sorted name order (i.e. disregard character-case and leading 'O')
    MANAGER_QPKG_NAME+=(ClamAV)
        MANAGER_QPKG_ARCH+=(all)
        MANAGER_QPKG_MINRAM+=(1578040)
        MANAGER_QPKG_VERSION+=(210402)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/main/QPKGs/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/build/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}.qpkg)
        MANAGER_QPKG_MD5+=(8108dc9373c2c9779e9da6f76dde2800)
        MANAGER_QPKG_DESC+=('replacement for the QTS built-in ClamAV (requires a minimum of 1.5GB RAM)')
        MANAGER_QPKG_ABBRVS+=('av clam clamscan freshclam clamav')
        MANAGER_QPKG_DEPENDS_ON+=(Entware)
        MANAGER_QPKG_IPKGS_ADD+=('clamav freshclam')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_BACKUP_SUPPORTED+=(false)
        MANAGER_QPKG_UPDATE_ON_RESTART+=(false)

    MANAGER_QPKG_NAME+=(Deluge-server)
        MANAGER_QPKG_ARCH+=(all)
        MANAGER_QPKG_MINRAM+=(any)
        MANAGER_QPKG_VERSION+=(210331)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/main/QPKGs/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/build/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}.qpkg)
        MANAGER_QPKG_MD5+=(d9b560217201171d188da06420344eb8)
        MANAGER_QPKG_DESC+=('Deluge BitTorrent daemon')
        MANAGER_QPKG_ABBRVS+=('deluge del-server deluge-server')
        MANAGER_QPKG_DEPENDS_ON+=(Entware)
        MANAGER_QPKG_IPKGS_ADD+=('deluge jq')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_BACKUP_SUPPORTED+=(true)
        MANAGER_QPKG_UPDATE_ON_RESTART+=(false)

    MANAGER_QPKG_NAME+=(Deluge-web)
        MANAGER_QPKG_ARCH+=(all)
        MANAGER_QPKG_MINRAM+=(any)
        MANAGER_QPKG_VERSION+=(210331)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/main/QPKGs/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/build/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}.qpkg)
        MANAGER_QPKG_MD5+=(060dcdf82dcaab7e8d320060ea11ce19)
        MANAGER_QPKG_DESC+=('web UI to access multiple Deluge BitTorrent daemons')
        MANAGER_QPKG_ABBRVS+=('del-web deluge-web')
        MANAGER_QPKG_DEPENDS_ON+=(Entware)
        MANAGER_QPKG_IPKGS_ADD+=('deluge-ui-web jq')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_BACKUP_SUPPORTED+=(true)
        MANAGER_QPKG_UPDATE_ON_RESTART+=(false)

    MANAGER_QPKG_NAME+=(duf)
        MANAGER_QPKG_ARCH+=(a64)
        MANAGER_QPKG_MINRAM+=(any)
        MANAGER_QPKG_VERSION+=(210330)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/main/build/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}_arm_64.qpkg)
        MANAGER_QPKG_MD5+=(03bdcee03ca1580c20edc012628965a7)
        MANAGER_QPKG_DESC+=('a nice CLI disk-usage/free-space utility from @muesli')
        MANAGER_QPKG_ABBRVS+=('duf')
        MANAGER_QPKG_DEPENDS_ON+=('')
        MANAGER_QPKG_IPKGS_ADD+=('')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_BACKUP_SUPPORTED+=(false)
        MANAGER_QPKG_UPDATE_ON_RESTART+=(false)

    MANAGER_QPKG_NAME+=(duf)
        MANAGER_QPKG_ARCH+=(x41)
        MANAGER_QPKG_MINRAM+=(any)
        MANAGER_QPKG_VERSION+=(210330)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/main/build/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}_arm-x41.qpkg)
        MANAGER_QPKG_MD5+=(a91c79d797545b67854443866549dd6d)
        MANAGER_QPKG_DESC+=('a nice CLI disk-usage/free-space utility from @muesli')
        MANAGER_QPKG_ABBRVS+=('duf')
        MANAGER_QPKG_DEPENDS_ON+=('')
        MANAGER_QPKG_IPKGS_ADD+=('')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_BACKUP_SUPPORTED+=(false)
        MANAGER_QPKG_UPDATE_ON_RESTART+=(false)

    MANAGER_QPKG_NAME+=(duf)
        MANAGER_QPKG_ARCH+=(x86)
        MANAGER_QPKG_MINRAM+=(any)
        MANAGER_QPKG_VERSION+=(210330)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/main/build/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}_x86.qpkg)
        MANAGER_QPKG_MD5+=(8fac3d3df25e7570a5fbcd51f2e0371d)
        MANAGER_QPKG_DESC+=('a nice CLI disk-usage/free-space utility from @muesli')
        MANAGER_QPKG_ABBRVS+=('duf')
        MANAGER_QPKG_DEPENDS_ON+=('')
        MANAGER_QPKG_IPKGS_ADD+=('')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_BACKUP_SUPPORTED+=(false)
        MANAGER_QPKG_UPDATE_ON_RESTART+=(false)

    MANAGER_QPKG_NAME+=(duf)
        MANAGER_QPKG_ARCH+=(x64)
        MANAGER_QPKG_MINRAM+=(any)
        MANAGER_QPKG_VERSION+=(210330)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/main/build/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}_x86_64.qpkg)
        MANAGER_QPKG_MD5+=(5d3b1c6eeeb7d5c0025a7f09c695fe9b)
        MANAGER_QPKG_DESC+=('a nice CLI disk-usage/free-space utility from @muesli')
        MANAGER_QPKG_ABBRVS+=('duf')
        MANAGER_QPKG_DEPENDS_ON+=('')
        MANAGER_QPKG_IPKGS_ADD+=('')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_BACKUP_SUPPORTED+=(false)
        MANAGER_QPKG_UPDATE_ON_RESTART+=(false)

    MANAGER_QPKG_NAME+=(Entware)
        MANAGER_QPKG_ARCH+=(all)
        MANAGER_QPKG_MINRAM+=(any)
        MANAGER_QPKG_VERSION+=(1.03)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/main/QPKGs/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}std.qpkg)
        MANAGER_QPKG_MD5+=(da2d9f8d3442dd665ce04b9b932c9d8e)
        MANAGER_QPKG_DESC+=("provides the 'opkg' command: the OpenWRT package manager")
        MANAGER_QPKG_ABBRVS+=('ew ent opkg entware')
        MANAGER_QPKG_DEPENDS_ON+=('')
        MANAGER_QPKG_IPKGS_ADD+=('')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_BACKUP_SUPPORTED+=(false)
        MANAGER_QPKG_UPDATE_ON_RESTART+=(false)

    MANAGER_QPKG_NAME+=(HideThatBanner)
        MANAGER_QPKG_ARCH+=(all)
        MANAGER_QPKG_MINRAM+=(any)
        MANAGER_QPKG_VERSION+=(201219b)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/main/build/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}.qpkg)
        MANAGER_QPKG_MD5+=(d576993ca2c6ec7585abe24455e19385)
        MANAGER_QPKG_DESC+=('hides the annoying rotating banner at the top of QTS App Center pages')
        MANAGER_QPKG_ABBRVS+=('htb hide hidebanner hidethatbanner')
        MANAGER_QPKG_DEPENDS_ON+=('')
        MANAGER_QPKG_IPKGS_ADD+=('')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_BACKUP_SUPPORTED+=(false)
        MANAGER_QPKG_UPDATE_ON_RESTART+=(false)

    MANAGER_QPKG_NAME+=(LazyLibrarian)
        MANAGER_QPKG_ARCH+=(all)
        MANAGER_QPKG_MINRAM+=(any)
        MANAGER_QPKG_VERSION+=(210318)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/main/QPKGs/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/build/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}.qpkg)
        MANAGER_QPKG_MD5+=(aa35dab8b3043741da42deab2dc68d74)
        MANAGER_QPKG_DESC+=('follow authors and grab metadata for all your digital reading needs')
        MANAGER_QPKG_ABBRVS+=('ll lazy lazylibrarian')
        MANAGER_QPKG_DEPENDS_ON+=(Entware)
        MANAGER_QPKG_IPKGS_ADD+=('python3-requests')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_BACKUP_SUPPORTED+=(true)
        MANAGER_QPKG_UPDATE_ON_RESTART+=(true)

    MANAGER_QPKG_NAME+=(OMedusa)
        MANAGER_QPKG_ARCH+=(all)
        MANAGER_QPKG_MINRAM+=(any)
        MANAGER_QPKG_VERSION+=(210325)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/main/QPKGs/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/build/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}.qpkg)
        MANAGER_QPKG_MD5+=(cd920291f5df7f6febc36db60bbfd323)
        MANAGER_QPKG_DESC+=('another SickBeard fork: manage and search for TV shows')
        MANAGER_QPKG_ABBRVS+=('om med omed medusa omedusa')
        MANAGER_QPKG_DEPENDS_ON+=(Entware)
        MANAGER_QPKG_IPKGS_ADD+=('mediainfo')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_BACKUP_SUPPORTED+=(true)
        MANAGER_QPKG_UPDATE_ON_RESTART+=(true)

    MANAGER_QPKG_NAME+=(Mylar3)
        MANAGER_QPKG_ARCH+=(all)
        MANAGER_QPKG_MINRAM+=(any)
        MANAGER_QPKG_VERSION+=(210318)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/main/QPKGs/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/build/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}.qpkg)
        MANAGER_QPKG_MD5+=(1127611fedd01817f952de0ee43f796f)
        MANAGER_QPKG_DESC+=('automated Comic Book (cbr/cbz) downloader program for use with NZB and torrents written in Python')
        MANAGER_QPKG_ABBRVS+=('my omy myl mylar mylar3')
        MANAGER_QPKG_DEPENDS_ON+=(Entware)
        MANAGER_QPKG_IPKGS_ADD+=('python3-mako python3-pillow python3-pytz python3-requests python3-six python3-urllib3')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_BACKUP_SUPPORTED+=(true)
        MANAGER_QPKG_UPDATE_ON_RESTART+=(true)

    MANAGER_QPKG_NAME+=(NZBGet)
        MANAGER_QPKG_ARCH+=(all)
        MANAGER_QPKG_MINRAM+=(any)
        MANAGER_QPKG_VERSION+=(210331)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/main/QPKGs/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/build/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}.qpkg)
        MANAGER_QPKG_MD5+=(7c404bcb1ebc4a1b2ae150549ba8ff1f)
        MANAGER_QPKG_DESC+=('lite-and-fast NZB download manager with a simple web UI')
        MANAGER_QPKG_ABBRVS+=('ng nzb nzbg nget nzbget')
        MANAGER_QPKG_DEPENDS_ON+=(Entware)
        MANAGER_QPKG_IPKGS_ADD+=(nzbget)
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_BACKUP_SUPPORTED+=(true)
        MANAGER_QPKG_UPDATE_ON_RESTART+=(false)

    MANAGER_QPKG_NAME+=(nzbToMedia)
        MANAGER_QPKG_ARCH+=(all)
        MANAGER_QPKG_MINRAM+=(any)
        MANAGER_QPKG_VERSION+=(210327)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/main/QPKGs/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/build/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}.qpkg)
        MANAGER_QPKG_MD5+=(3d46d56830007f131a457b4fd7f40fb6)
        MANAGER_QPKG_DESC+=('post-processing for NZBs to many services')
        MANAGER_QPKG_ABBRVS+=('nzb2 nzb2m nzbto nzbtom nzbtomedia')
        MANAGER_QPKG_DEPENDS_ON+=(Entware)
        MANAGER_QPKG_IPKGS_ADD+=('')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_BACKUP_SUPPORTED+=(true)
        MANAGER_QPKG_UPDATE_ON_RESTART+=(true)

    MANAGER_QPKG_NAME+=(Par2)
        MANAGER_QPKG_ARCH+=(x86)
        MANAGER_QPKG_MINRAM+=(any)
        MANAGER_QPKG_VERSION+=(0.8.1.0)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/main/QPKGs/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}_x86.qpkg)
        MANAGER_QPKG_MD5+=(996ffb92d774eb01968003debc171e91)
        MANAGER_QPKG_DESC+=('create and use PAR2 files to detect damage in data files and repair them if necessary')
        MANAGER_QPKG_ABBRVS+=('par par2')
        MANAGER_QPKG_DEPENDS_ON+=('')
        MANAGER_QPKG_IPKGS_ADD+=('')
        MANAGER_QPKG_IPKGS_REMOVE+=(par2cmdline)
        MANAGER_QPKG_BACKUP_SUPPORTED+=(false)
        MANAGER_QPKG_UPDATE_ON_RESTART+=(false)

    MANAGER_QPKG_NAME+=(Par2)
        MANAGER_QPKG_ARCH+=(x64)
        MANAGER_QPKG_MINRAM+=(any)
        MANAGER_QPKG_VERSION+=(0.8.1.0)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/main/QPKGs/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}_x86_64.qpkg)
        MANAGER_QPKG_MD5+=(520472cc87d301704f975f6eb9948e38)
        MANAGER_QPKG_DESC+=('')
        MANAGER_QPKG_ABBRVS+=('par par2')
        MANAGER_QPKG_DEPENDS_ON+=('')
        MANAGER_QPKG_IPKGS_ADD+=('')
        MANAGER_QPKG_IPKGS_REMOVE+=(par2cmdline)
        MANAGER_QPKG_BACKUP_SUPPORTED+=(false)
        MANAGER_QPKG_UPDATE_ON_RESTART+=(false)

    MANAGER_QPKG_NAME+=(Par2)
        MANAGER_QPKG_ARCH+=(x31)
        MANAGER_QPKG_MINRAM+=(any)
        MANAGER_QPKG_VERSION+=(0.8.1.0)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/main/QPKGs/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}_arm-x31.qpkg)
        MANAGER_QPKG_MD5+=(ce8af2e009eb87733c3b855e41a94f8e)
        MANAGER_QPKG_DESC+=('')
        MANAGER_QPKG_ABBRVS+=('par par2')
        MANAGER_QPKG_DEPENDS_ON+=('')
        MANAGER_QPKG_IPKGS_ADD+=('')
        MANAGER_QPKG_IPKGS_REMOVE+=(par2cmdline)
        MANAGER_QPKG_BACKUP_SUPPORTED+=(false)
        MANAGER_QPKG_UPDATE_ON_RESTART+=(false)

    MANAGER_QPKG_NAME+=(Par2)
        MANAGER_QPKG_ARCH+=(x41)
        MANAGER_QPKG_MINRAM+=(any)
        MANAGER_QPKG_VERSION+=(0.8.1.0)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/main/QPKGs/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}_arm-x41.qpkg)
        MANAGER_QPKG_MD5+=(8516e45e704875cdd2cd2bb315c4e1e6)
        MANAGER_QPKG_DESC+=('')
        MANAGER_QPKG_ABBRVS+=('par par2')
        MANAGER_QPKG_DEPENDS_ON+=('')
        MANAGER_QPKG_IPKGS_ADD+=('')
        MANAGER_QPKG_IPKGS_REMOVE+=(par2cmdline)
        MANAGER_QPKG_BACKUP_SUPPORTED+=(false)
        MANAGER_QPKG_UPDATE_ON_RESTART+=(false)

    MANAGER_QPKG_NAME+=(Par2)
        MANAGER_QPKG_ARCH+=(a64)
        MANAGER_QPKG_MINRAM+=(any)
        MANAGER_QPKG_VERSION+=(0.8.1.0)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/main/QPKGs/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}_arm_64.qpkg)
        MANAGER_QPKG_MD5+=(4d8e99f97936a163e411aa8765595f7a)
        MANAGER_QPKG_DESC+=('')
        MANAGER_QPKG_ABBRVS+=('par par2')
        MANAGER_QPKG_DEPENDS_ON+=('')
        MANAGER_QPKG_IPKGS_ADD+=('')
        MANAGER_QPKG_IPKGS_REMOVE+=(par2cmdline)
        MANAGER_QPKG_BACKUP_SUPPORTED+=(false)
        MANAGER_QPKG_UPDATE_ON_RESTART+=(false)

#     MANAGER_QPKG_NAME+=(Par2)
#         MANAGER_QPKG_ARCH+=(none)
#         MANAGER_QPKG_MINRAM+=(any)
#         MANAGER_QPKG_VERSION+=(0.8.1-1)
#         MANAGER_QPKG_URL+=('')
#         MANAGER_QPKG_MD5+=('')
#         MANAGER_QPKG_DESC+=('')
#         MANAGER_QPKG_ABBRVS+=('par par2')
#         MANAGER_QPKG_DEPENDS_ON+=(Entware)
#         MANAGER_QPKG_IPKGS_ADD+=(par2cmdline)
#         MANAGER_QPKG_IPKGS_REMOVE+=('')
#         MANAGER_QPKG_BACKUP_SUPPORTED+=(false)
#         MANAGER_QPKG_UPDATE_ON_RESTART+=(false)
#
    MANAGER_QPKG_NAME+=(RunLast)
        MANAGER_QPKG_ARCH+=(all)
        MANAGER_QPKG_MINRAM+=(any)
        MANAGER_QPKG_VERSION+=(210328)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/main/build/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}.qpkg)
        MANAGER_QPKG_MD5+=(8bc501c43a1041e966c63b4ff242ecb9)
        MANAGER_QPKG_DESC+=('run userscripts and commands after all QPKGs have completed startup reintegration into QTS')
        MANAGER_QPKG_ABBRVS+=('rl run runlast')
        MANAGER_QPKG_DEPENDS_ON+=('')
        MANAGER_QPKG_IPKGS_ADD+=('')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_BACKUP_SUPPORTED+=(false)
        MANAGER_QPKG_UPDATE_ON_RESTART+=(false)

    MANAGER_QPKG_NAME+=(SABnzbd)
        MANAGER_QPKG_ARCH+=(all)
        MANAGER_QPKG_MINRAM+=(any)
        MANAGER_QPKG_VERSION+=(210401)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/main/QPKGs/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/build/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}.qpkg)
        MANAGER_QPKG_MD5+=(4b0af600a610424f34f0b82f0f75ddf4)
        MANAGER_QPKG_DESC+=('full-featured NZB download manager with a nice web UI')
        MANAGER_QPKG_ABBRVS+=('sb sb3 sab sab3 sabnzbd3 sabnzbd')
        MANAGER_QPKG_DEPENDS_ON+=('Entware Par2')
        MANAGER_QPKG_IPKGS_ADD+=('python3-asn1crypto python3-chardet python3-cryptography unrar p7zip coreutils-nice ionice ffprobe')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_BACKUP_SUPPORTED+=(true)
        MANAGER_QPKG_UPDATE_ON_RESTART+=(true)

    MANAGER_QPKG_NAME+=(sha3sum)
        MANAGER_QPKG_ARCH+=(x86)
        MANAGER_QPKG_MINRAM+=(any)
        MANAGER_QPKG_VERSION+=(201114)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/main/build/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}_x86.qpkg)
        MANAGER_QPKG_MD5+=(87c4ae02c7f95cd2706997047fc9e84d)
        MANAGER_QPKG_DESC+=("the 'sha3sum' and keccak utilities from @maandree (for x86 & x86-64 NAS only)")
        MANAGER_QPKG_ABBRVS+=('sha sha3 sha3sum')
        MANAGER_QPKG_DEPENDS_ON+=('')
        MANAGER_QPKG_IPKGS_ADD+=('')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_BACKUP_SUPPORTED+=(false)
        MANAGER_QPKG_UPDATE_ON_RESTART+=(false)

    MANAGER_QPKG_NAME+=(sha3sum)
        MANAGER_QPKG_ARCH+=(x64)
        MANAGER_QPKG_MINRAM+=(any)
        MANAGER_QPKG_VERSION+=(201114)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/main/build/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}_x86_64.qpkg)
        MANAGER_QPKG_MD5+=(eed8071c43665431d6444cb489636ae5)
        MANAGER_QPKG_DESC+=('')
        MANAGER_QPKG_ABBRVS+=('sha sha3 sha3sum')
        MANAGER_QPKG_DEPENDS_ON+=('')
        MANAGER_QPKG_IPKGS_ADD+=('')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_BACKUP_SUPPORTED+=(false)
        MANAGER_QPKG_UPDATE_ON_RESTART+=(false)

    MANAGER_QPKG_NAME+=($PROJECT_NAME)
        MANAGER_QPKG_ARCH+=(all)
        MANAGER_QPKG_MINRAM+=(any)
        MANAGER_QPKG_VERSION+=(210328)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/main/QPKGs/$PROJECT_NAME/build/${PROJECT_NAME}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}.qpkg)
        MANAGER_QPKG_MD5+=(dc3e0cef8c22fe43acc2ad94eadba5cf)
        MANAGER_QPKG_DESC+=("provides the '$PROJECT_NAME' command: the mini-package-manager")
        MANAGER_QPKG_ABBRVS+=($PROJECT_NAME)
        MANAGER_QPKG_DEPENDS_ON+=('')
        MANAGER_QPKG_IPKGS_ADD+=('')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_BACKUP_SUPPORTED+=(false)
        MANAGER_QPKG_UPDATE_ON_RESTART+=(false)

    MANAGER_QPKG_NAME+=(SickChill)
        MANAGER_QPKG_ARCH+=(all)
        MANAGER_QPKG_MINRAM+=(any)
        MANAGER_QPKG_VERSION+=(210326)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/main/QPKGs/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/build/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}.qpkg)
        MANAGER_QPKG_MD5+=(fb488f7176bf5656575fa010a9599b63)
        MANAGER_QPKG_DESC+=('another SickBeard fork: manage and search for TV shows and movies')
        MANAGER_QPKG_ABBRVS+=('sc sick sickc chill sickchill')
        MANAGER_QPKG_DEPENDS_ON+=(Entware)
        MANAGER_QPKG_IPKGS_ADD+=('')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_BACKUP_SUPPORTED+=(true)
        MANAGER_QPKG_UPDATE_ON_RESTART+=(true)

    MANAGER_QPKG_NAME+=(OSickGear)
        MANAGER_QPKG_ARCH+=(all)
        MANAGER_QPKG_MINRAM+=(any)
        MANAGER_QPKG_VERSION+=(210318)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/main/QPKGs/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/build/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}.qpkg)
        MANAGER_QPKG_MD5+=(5584d751bed1c700f407375e3f56174e)
        MANAGER_QPKG_DESC+=('another SickBeard fork: manage and search for TV shows')
        MANAGER_QPKG_ABBRVS+=('sg os osg sickg gear ogear osickg sickgear osickgear')
        MANAGER_QPKG_DEPENDS_ON+=(Entware)
        MANAGER_QPKG_IPKGS_ADD+=('')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_BACKUP_SUPPORTED+=(true)
        MANAGER_QPKG_UPDATE_ON_RESTART+=(true)

    MANAGER_QPKG_NAME+=(SortMyQPKGs)
        MANAGER_QPKG_ARCH+=(all)
        MANAGER_QPKG_MINRAM+=(any)
        MANAGER_QPKG_VERSION+=(210328)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/main/build/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}.qpkg)
        MANAGER_QPKG_MD5+=(4a8a8662d27aa110ae096e68e0a2e293)
        MANAGER_QPKG_DESC+=('ensure other installed QPKGs start in correct sequence during QTS bootup')
        MANAGER_QPKG_ABBRVS+=('smq smqs sort sortmy sortmine sortpackages sortmypackages sortmyqpkgs')
        MANAGER_QPKG_DEPENDS_ON+=('')
        MANAGER_QPKG_IPKGS_ADD+=('')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_BACKUP_SUPPORTED+=(false)
        MANAGER_QPKG_UPDATE_ON_RESTART+=(false)

    MANAGER_QPKG_NAME+=(OTransmission)
        MANAGER_QPKG_ARCH+=(all)
        MANAGER_QPKG_MINRAM+=(any)
        MANAGER_QPKG_VERSION+=(210331b)
        MANAGER_QPKG_URL+=(https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/main/QPKGs/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}/build/${MANAGER_QPKG_NAME[${#MANAGER_QPKG_NAME[@]}-1]}_${MANAGER_QPKG_VERSION[${#MANAGER_QPKG_VERSION[@]}-1]}.qpkg)
        MANAGER_QPKG_MD5+=(8149be0257866b0f237ee0fa63e1c20c)
        MANAGER_QPKG_DESC+=('lite bitorrent download manager with a simple web UI')
        MANAGER_QPKG_ABBRVS+=('ot tm tr trans otrans tmission transmission otransmission')
        MANAGER_QPKG_DEPENDS_ON+=(Entware)
        MANAGER_QPKG_IPKGS_ADD+=('transmission-web jq')
        MANAGER_QPKG_IPKGS_REMOVE+=('')
        MANAGER_QPKG_BACKUP_SUPPORTED+=(true)
        MANAGER_QPKG_UPDATE_ON_RESTART+=(false)

    # package arrays are now full, so lock them
    readonly MANAGER_QPKG_NAME
        readonly MANAGER_QPKG_ARCH
        readonly MANAGER_QPKG_MINRAM
        readonly MANAGER_QPKG_VERSION
        readonly MANAGER_QPKG_URL
        readonly MANAGER_QPKG_MD5
        readonly MANAGER_QPKG_DESC
        readonly MANAGER_QPKG_ABBRVS
        readonly MANAGER_QPKG_DEPENDS_ON
        readonly MANAGER_QPKG_IPKGS_ADD
        readonly MANAGER_QPKG_IPKGS_REMOVE
        readonly MANAGER_QPKG_BACKUP_SUPPORTED
        readonly MANAGER_QPKG_UPDATE_ON_RESTART

    QPKGs.Names.Add "${MANAGER_QPKG_NAME[*]}"

    readonly MANAGER_BASE_QPKG_CONFLICTS='Optware Optware-NG TarMT Python QPython2 Python3 QPython3'
    readonly MANAGER_BASE_IPKGS_ADD='findutils grep less sed'
    readonly MANAGER_SHARED_IPKGS_ADD='ca-certificates gcc git git-http nano python3-dev python3-pip python3-setuptools'
    readonly MANAGER_SHARED_PIPS_ADD='apprise apscheduler beautifulsoup4 cfscrape cheetah3 cheroot!=8.4.4 cherrypy configobj feedparser portend pygithub pyopenssl python-levenshtein python-magic random_user_agent sabyenc3 simplejson slugify'

    QPKGs.StandaloneDependent.Build

    # speedup: don't build package lists if only showing basic help
    if [[ -z $USER_ARGS_RAW ]]; then
        Opts.Help.Basic.Set
        QPKGs.SkipProcessing.Set
        DisableDebugToArchiveAndFile
    else
        ParseArguments
    fi

    SmartCR >&2

    if Session.Display.Clean.IsNot; then
        if Session.Debug.ToScreen.IsNot; then
            Display "$(FormatAsScriptTitle) $MANAGER_SCRIPT_VERSION • a mini-package-manager for QNAP NAS"
            DisplayLineSpaceIfNoneAlready
        fi

        Opts.Apps.All.Upgrade.IsNot && Opts.Apps.All.Uninstall.IsNot && QPKGs.NewVersions.Show
    fi

    DebugFuncExit

    }

Session.Validate()
    {

    DebugFuncEntry
    ArgumentSuggestions

    if QPKGs.SkipProcessing.IsSet; then
        DebugFuncExit 1; return
    fi

    ShowAsProc 'validating parameters' >&2

    ListEnvironment

    if QPKGs.SkipProcessing.IsSet; then
        DebugFuncExit 1; return
    fi

    if ! QPKGs.Conflicts.Check; then
        code_pointer=1
        QPKGs.SkipProcessing.Set
        DebugFuncExit 1; return
    fi

    if QPKGs.ToBackup.IsNone && QPKGs.ToUninstall.IsNone && QPKGs.ToUpgrade.IsNone && QPKGs.ToInstall.IsNone && QPKGs.ToReinstall.IsNone && QPKGs.ToRestore.IsNone && QPKGs.ToRestart.IsNone && QPKGs.ToStart.IsNone && QPKGs.ToStop.IsNone && QPKGs.ToRebuild.IsNone; then
        if Opts.Apps.All.Install.IsNot && Opts.Apps.All.Uninstall.IsNot && Opts.Apps.All.Restart.IsNot && Opts.Apps.All.Upgrade.IsNot && Opts.Apps.All.Backup.IsNot && Opts.Apps.All.Restore.IsNot && Opts.Apps.All.Start.IsNot && Opts.Apps.All.Stop.IsNot && Opts.Apps.All.Rebuild.IsNot; then
            if Opts.Apps.Standalone.Install.IsNot && Opts.Apps.Standalone.Uninstall.IsNot && Opts.Apps.Standalone.Restart.IsNot && Opts.Apps.Standalone.Upgrade.IsNot && Opts.Apps.Standalone.Backup.IsNot && Opts.Apps.Standalone.Restore.IsNot && Opts.Apps.Standalone.Start.IsNot && Opts.Apps.Standalone.Stop.IsNot && Opts.Apps.Standalone.Rebuild.IsNot; then
                if Opts.Apps.Dependent.Install.IsNot && Opts.Apps.Dependent.Uninstall.IsNot && Opts.Apps.Dependent.Restart.IsNot && Opts.Apps.Dependent.Upgrade.IsNot && Opts.Apps.Dependent.Backup.IsNot && Opts.Apps.Dependent.Restore.IsNot && Opts.Apps.Dependent.Start.IsNot && Opts.Apps.Dependent.Stop.IsNot && Opts.Apps.Dependent.Rebuild.IsNot; then
                    if Opts.Dependencies.Check.IsNot && Opts.IgnoreFreeSpace.IsNot && Opts.Help.Status.IsNot; then
                        ShowAsEror "I've nothing to do (this usually means the arguments couldn't be run as-specified)"
                        Opts.Help.Basic.Set
                        QPKGs.SkipProcessing.Set
                        DebugFuncExit 1; return
                    fi
                fi
            fi
        fi
    fi

    if Opts.Dependencies.Check.IsSet || QPKGs.ToUpgrade.Exist Entware; then
        IPKGs.Upgrade.Set
        IPKGs.Install.Set
        PIPs.Install.Set
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

    # This function is a bit of a dog's breakfast. It handles all the high-level logic for package operations.
    # If a package isn't being processed by the correct operation, odds-are it's a logic error in this function.
    # It's been ongoing work trying to find the most sensible process to follow, given the multiple actions and packages available.

    QPKGs.SkipProcessing.IsSet && return
    DebugFuncEntry
    local package=''
    local prospect=''

    QPKGs.IsSupportBackup.Build
    QPKGs.IsSupportUpdateOnRestart.Build

    Opts.Apps.All.Upgrade.IsSet && QPKGs.ToUpgrade.Add "$(QPKGs.IsUpgradable.Array)"
    Opts.Apps.All.Reinstall.IsSet && QPKGs.ToReinstall.Add "$(QPKGs.IsInstalled.Array)"
    Opts.Apps.All.Install.IsSet && QPKGs.ToInstall.Add "$(QPKGs.IsInstallable.Array)"

    ### 'rebuild' meta-operation pre-processing ###

        if Opts.Apps.All.Rebuild.IsSet || QPKGs.ToRebuild.IsAny; then
            if QPKGs.IsBackedUp.IsNone; then
                ShowAsWarn 'there are no package backups to rebuild from' >&2
            else
                if Opts.Apps.All.Rebuild.IsSet; then
                    QPKGs.ToInstall.Add "$(QPKGs.IsBackedUp.Array)"
                    QPKGs.ToRestore.Add "$(QPKGs.IsBackedUp.Array)"
                else
                    for package in $(QPKGs.ToRebuild.Array); do
                        if ! QPKGs.IsBackedUp.Exist "$package"; then
                            MarkOpAsSkipped show "$PACKAGE_NAME" rebuild "does not have a backup to rebuild from"
                        else
                            QPKGs.ToRebuild.Remove "$package"
                            (QPKGs.IsNotInstalled.Exist "$package" || QPKGs.ToUninstall.Exist "$package") && QPKGs.ToInstall.Add "$package"
                            QPKGs.ToRestore.Add "$package"
                        fi
                    done
                fi
            fi
        fi

    ### pre-'download' fixes ###

        # check reinstall for items to install instead
        for package in $(QPKGs.ToReinstall.Array); do
            if QPKGs.IsNotInstalled.Exist "$package"; then
                QPKGs.ToReinstall.Remove "$package"
                QPKGs.ToInstall.Add "$package"
            fi
        done

        # check upgrade for standalone items to be installed first
        for package in $(QPKGs.ToUpgrade.Array); do
            for prospect in $(QPKG.Standalones "$package"); do
                QPKGs.IsNotInstalled.Exist "$prospect" && QPKGs.ToInstall.Add "$prospect"
            done
        done

        # check start for standalone items to be installed first
        for package in $(QPKGs.ToStart.Array); do
            for prospect in $(QPKG.Standalones "$package"); do
                QPKGs.IsNotInstalled.Exist "$prospect" && QPKGs.ToInstall.Add "$prospect"
            done
        done

        # check restart for standalone items to be installed first
        for package in $(QPKGs.ToRestart.Array); do
            for prospect in $(QPKG.Standalones "$package"); do
                QPKGs.IsNotInstalled.Exist "$prospect" && QPKGs.ToInstall.Add "$prospect"
            done
        done

        # check reinstall for standalone items to be installed first
        for package in $(QPKGs.ToReinstall.Array); do
            for prospect in $(QPKG.Standalones "$package"); do
                QPKGs.IsNotInstalled.Exist "$prospect" && QPKGs.ToInstall.Add "$prospect"
            done
        done

        # check install for standalone items to be installed first
        for package in $(QPKGs.ToInstall.Array); do
            for prospect in $(QPKG.Standalones "$package"); do
                QPKGs.IsNotInstalled.Exist "$prospect" && QPKGs.ToInstall.Add "$prospect"
            done
        done

    ### 'download' operation ###

        QPKGs.ToDownload.Add "$(QPKGs.ToUpgrade.Array)"
        QPKGs.ToDownload.Add "$(QPKGs.ToReinstall.Array)"
        QPKGs.ToDownload.Add "$(QPKGs.ToInstall.Array)"

        # download all required standalones too
        for package in $(QPKGs.ToDownload.Array); do
            QPKGs.ToDownload.Add "$(QPKG.Standalones "$package")"
        done

    Tier.Processor Download false all QPKG ToDownload 'update package cache with' 'updating package cache with' 'updated package cache with' ''

    ### 'backup' operation ###

        if Opts.Apps.All.Backup.IsSet; then
            for prospect in $(QPKGs.IsSupportBackup.Array); do
                QPKGs.IsInstalled.Exist "$prospect" && QPKGs.ToBackup.Add "$prospect"
            done
        elif Opts.Apps.Standalone.Backup.IsSet; then
            for prospect in $(QPKGs.IsSupportBackup.Array); do
                QPKGs.IsStandalone.Exist "$prospect" && QPKGs.IsInstalled.Exist "$prospect" && QPKGs.ToBackup.Add "$prospect"
            done
        elif Opts.Apps.Dependent.Backup.IsSet; then
            for prospect in $(QPKGs.IsSupportBackup.Array); do
                QPKGs.IsDependent.Exist "$prospect" && QPKGs.IsInstalled.Exist "$prospect" && QPKGs.ToBackup.Add "$prospect"
            done
        fi

    Tier.Processor Backup false all QPKG ToBackup 'backup configuration for' 'backing-up configuration for' 'configuration backed-up for' ''

    ### 'stop' operation ###

        if Opts.Apps.All.Stop.IsSet; then
            QPKGs.ToStop.Add "$(QPKGs.IsStarted.Array)"
        elif Opts.Apps.Standalone.Stop.IsSet; then
            for prospect in $(QPKGs.IsStarted.Array); do
                QPKGs.IsStandalone.Exist "$prospect" && QPKGs.ToStop.Add "$prospect"
            done
        elif Opts.Apps.Dependent.Stop.IsSet; then
            for prospect in $(QPKGs.IsStarted.Array); do
                QPKGs.IsDependent.Exist "$prospect" && QPKGs.ToStop.Add "$prospect"
            done
        fi

        # if an standalone has been selected for stop, need to stop its dependents first
        for package in $(QPKGs.ToStop.Array); do
            if QPKGs.IsStandalone.Exist "$package" && QPKGs.IsInstalled.Exist "$package"; then
                for prospect in $(QPKG.Dependents "$package"); do
                    QPKGs.IsStarted.Exist "$prospect" && QPKGs.ToStop.Add "$prospect"
                done
            fi
        done

        # if an standalone has been selected for uninstall, need to stop its dependents first
        for package in $(QPKGs.ToUninstall.Array); do
            if QPKGs.IsStandalone.Exist "$package" && QPKGs.IsInstalled.Exist "$package"; then
                for prospect in $(QPKG.Dependents "$package"); do
                    QPKGs.IsStarted.Exist "$prospect" && QPKGs.ToStop.Add "$prospect"
                done
            fi
        done

        # if an standalone has been selected for reinstall, need to stop its dependents first, and start them again later
        for package in $(QPKGs.ToReinstall.Array); do
            if QPKGs.IsStandalone.Exist "$package" && QPKGs.IsInstalled.Exist "$package" && QPKGs.IsStarted.Exist "$package"; then
                for prospect in $(QPKG.Dependents "$package"); do
                    if QPKGs.IsStarted.Exist "$prospect"; then
                        QPKGs.ToStop.Add "$prospect"
                        QPKGs.ToStart.Add "$prospect"
                    fi
                done
            fi
        done

        # no-need to stop packages that are about to be uninstalled
        if Opts.Apps.All.Uninstall.IsSet; then
            QPKGs.ToStop.Init
        else
            QPKGs.ToStop.Remove "$(QPKGs.ToUninstall.Array)"
        fi

    Tier.Processor Stop false dependent QPKG ToStop stop stopping stopped ''
    Tier.Processor Stop false standalone QPKG ToStop stop stopping stopped ''

    ### 'uninstall' operation ###

        if Opts.Apps.All.Uninstall.IsSet; then
            QPKGs.ToUninstall.Add "$(QPKGs.IsInstalled.Array)"
        elif Opts.Apps.Standalone.Uninstall.IsSet; then
            for prospect in $(QPKGs.IsInstalled.Array); do
                QPKGs.IsStandalone.Exist "$prospect" && QPKGs.ToUninstall.Add "$prospect"
            done
        elif Opts.Apps.Dependent.Uninstall.IsSet; then
            for prospect in $(QPKGs.IsInstalled.Array); do
                QPKGs.IsDependent.Exist "$prospect" && QPKGs.ToUninstall.Add "$prospect"
            done
        fi

        if QPKGs.ToReinstall.Exist Entware; then    # Entware is a special case: complete removal and fresh install (to clear all installed IPKGs)
            QPKGs.ToUninstall.Add Entware
            QPKGs.ToInstall.Add Entware
            QPKGs.ToReinstall.Remove Entware
        fi

    Tier.Processor Uninstall false dependent QPKG ToUninstall uninstall uninstalling uninstalled ''
    Tier.Processor Uninstall false addon IPKG ToUninstall uninstall uninstalling uninstalled ''
    Tier.Processor Uninstall false standalone QPKG ToUninstall uninstall uninstalling uninstalled ''

    # the fixes below must be completed before entering tier loop

    ### pre-'install' fixes ###

        # install standalones for started packages only
        for package in $(QPKGs.IsInstalled.Array); do
            if QPKGs.IsStarted.Exist "$package" || QPKGs.ToStart.Exist "$package"; then
                for prospect in $(QPKG.Standalones "$package"); do
                    QPKGs.IsNotInstalled.Exist "$prospect" && QPKGs.ToInstall.Add "$prospect"
                done
            fi
        done

    ### pre-'restore' fixes ###
        if Opts.Apps.All.Restore.IsSet; then
            for prospect in $(QPKGs.IsSupportBackup.Array); do
                QPKGs.IsInstalled.Exist "$prospect" && QPKGs.ToRestore.Add "$prospect"
            done
        fi

    ### pre-'start' fixes ###

        # adjust lists for start
        if Opts.Apps.All.Start.IsSet; then
            QPKGs.ToStart.Add "$(QPKGs.IsStopped.Array)"
        elif Opts.Apps.Standalone.Start.IsSet; then
            for prospect in $(QPKGs.IsStopped.Array); do
                QPKGs.IsStandalone.Exist "$prospect" && QPKGs.ToStart.Add "$prospect"
            done
        elif Opts.Apps.Dependent.Start.IsSet; then
            for prospect in $(QPKGs.IsStopped.Array); do
                QPKGs.IsDependent.Exist "$prospect" && QPKGs.ToStart.Add "$prospect"
            done
        fi

    ### pre-'restart' fixes ###

        if Opts.Apps.All.Upgrade.IsSet; then
            QPKGs.ToRestart.Add "$(QPKGs.IsSupportUpdateOnRestart.Array)"
            QPKGs.ToRestart.Remove "$(QPKGs.IsNotInstalled.Array)"
            QPKGs.ToRestart.Remove "$(QPKGs.ToUpgrade.Array)"
            QPKGs.ToRestart.Remove "$(QPKGs.IsStandalone.Array)"
        fi

    # in-case 'python' has disappeared again ...
    [[ ! -L /opt/bin/python && -e /opt/bin/python3 ]] && ln -s /opt/bin/python3 /opt/bin/python

    for tier in standalone addon dependent; do
        case $tier in
            standalone|dependent)
                ### 'upgrade' operation ###

                Tier.Processor Upgrade false "$tier" QPKG ToUpgrade upgrade upgrading upgraded long

                ### 'reinstall' operation ###

                Tier.Processor Reinstall false "$tier" QPKG ToReinstall reinstall reinstalling reinstalled long

                ### 'install' operation ###

                Tier.Processor Install false "$tier" QPKG ToInstall install installing installed long

                ### 'restore' operation ###

                Tier.Processor Restore false "$tier" QPKG ToRestore 'restore configuration for' 'restoring configuration for' 'configuration restored for' long

                ### 'start' operation ###

                    if [[ $tier = standalone ]]; then
                        # check for standalone packages that require starting due to dependents being reinstalled
                        for package in $(QPKGs.ToReinstall.Array); do
                            for prospect in $(QPKG.Standalones "$package"); do
                                QPKGs.IsStopped.Exist "$prospect" && QPKGs.ToStart.Add "$prospect"
                            done
                        done

                        for package in $(QPKGs.OkReinstall.Array); do
                            for prospect in $(QPKG.Standalones "$package"); do
                                QPKGs.IsStopped.Exist "$prospect" && QPKGs.ToStart.Add "$prospect"
                            done
                        done

                        # check for standalone packages that require starting due to dependents being installed
                        for package in $(QPKGs.ToInstall.Array); do
                            for prospect in $(QPKG.Standalones "$package"); do
                                QPKGs.IsStopped.Exist "$prospect" && QPKGs.ToStart.Add "$prospect"
                            done
                        done

                        for package in $(QPKGs.OkInstall.Array); do
                            for prospect in $(QPKG.Standalones "$package"); do
                                QPKGs.IsStopped.Exist "$prospect" && QPKGs.ToStart.Add "$prospect"
                            done
                        done

                        # check for standalone packages that require starting due to dependents being started
                        for package in $(QPKGs.ToStart.Array); do
                            for prospect in $(QPKG.Standalones "$package"); do
                                QPKGs.IsStopped.Exist "$prospect" && QPKGs.ToStart.Add "$prospect"
                            done
                        done

                        for package in $(QPKGs.OkStart.Array); do
                            for prospect in $(QPKG.Standalones "$package"); do
                                QPKGs.IsStopped.Exist "$prospect" && QPKGs.ToStart.Add "$prospect"
                            done
                        done

                        # check for standalone packages that require starting due to dependents being restarted
                        for package in $(QPKGs.ToRestart.Array); do
                            for prospect in $(QPKG.Standalones "$package"); do
                                QPKGs.IsStopped.Exist "$prospect" && QPKGs.ToStart.Add "$prospect"
                            done
                        done

                        for package in $(QPKGs.OkRestart.Array); do
                            for prospect in $(QPKG.Standalones "$package"); do
                                QPKGs.IsStopped.Exist "$prospect" && QPKGs.ToStart.Add "$prospect"
                            done
                        done
                    fi

                Tier.Processor Start false "$tier" QPKG ToStart start starting started long

                ### 'restart' operation ###

                    # check all items
                    if Opts.Dependencies.Check.IsSet; then
                        for package in $(QPKGs.IsDependent.Array); do
                            if ! QPKGs.IsStandalone.Exist "$package" && ! QPKGs.IsUpgradable.Exist "$package" && QPKGs.IsInstalled.Exist "$package" && QPKGs.IsStarted.Exist "$package"; then
                                QPKGs.ToRestart.Add "$package"
                            fi
                        done
                    fi

                    # adjust lists for restart
                    if Opts.Apps.All.Restart.IsSet; then
                        QPKGs.ToRestart.Add "$(QPKGs.IsInstalled.Array)"
                    else
                        # check for dependent packages to restart due to standalones being reinstalled
                        for package in $(QPKGs.OkReinstall.Array); do
                            for prospect in $(QPKG.Dependents "$package"); do
                                QPKGs.IsInstalled.Exist "$prospect" && QPKGs.ToRestart.Add "$prospect"
                            done
                        done

                        # check for dependent packages to restart due to standalones being started
                        for package in $(QPKGs.OkStart.Array); do
                            for prospect in $(QPKG.Dependents "$package"); do
                                QPKGs.IsStarted.Exist "$prospect" && QPKGs.ToRestart.Add "$prospect"
                            done
                        done

                        # check for dependent packages to restart due to standalones being restarted
                        for package in $(QPKGs.OkRestart.Array); do
                            for prospect in $(QPKG.Dependents "$package"); do
                                QPKGs.IsInstalled.Exist "$prospect" && QPKGs.ToRestart.Add "$prospect"
                            done
                        done

                        # check for dependent packages to restart due to standalones being upgraded
                        for package in $(QPKGs.OkUpgrade.Array); do
                            for prospect in $(QPKG.Dependents "$package"); do
                                QPKGs.IsInstalled.Exist "$prospect" && QPKGs.ToRestart.Add "$prospect"
                            done
                        done
                    fi

                    QPKGs.ToRestart.Remove "$(QPKGs.OkUpgrade.Array)"
                    QPKGs.ToRestart.Remove "$(QPKGs.OkReinstall.Array)"
                    QPKGs.ToRestart.Remove "$(QPKGs.OkInstall.Array)"
                    QPKGs.ToRestart.Remove "$(QPKGs.OkStart.Array)"
                    QPKGs.ToRestart.Remove "$(QPKGs.OkRestart.Array)"
                    QPKGs.ToRestart.Remove "$(QPKGs.OkRestore.Array)"

                Tier.Processor Restart false "$tier" QPKG ToRestart restart restarting restarted long

                ;;
            addon)
                    if QPKGs.ToInstall.IsAny || QPKGs.OkInstall.IsAny || QPKGs.ToReinstall.IsAny || QPKGs.OkReinstall.IsAny || QPKGs.ToUpgrade.IsAny || QPKGs.OkUpgrade.IsAny || QPKGs.ToStart.IsAny; then
                        IPKGs.Upgrade.Set
                        IPKGs.Install.Set
                    fi

                    if QPKGs.ToInstall.Exist SABnzbd || QPKGs.ToReinstall.Exist SABnzbd || QPKGs.ToUpgrade.Exist SABnzbd; then
                        PIPs.Install.Set   # must ensure 'sabyenc' and 'feedparser' modules are installed/updated
                    fi

                    if QPKGs.IsStarted.Exist Entware; then
                        ModPathToEntware

                Tier.Processor Upgrade false "$tier" IPKG '' upgrade upgrading upgraded long
                Tier.Processor Install false "$tier" IPKG '' install installing installed long
                Tier.Processor Install false "$tier" PIP '' install installing installed long

                    else
                        : # TODO: test if other packages are to be installed here. If so, and Entware isn't enabled, then abort with error.
                    fi
                    ;;
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
    #   $3 = $TIER                          e.g. 'standalone', 'dependent', 'addon', 'all'
    #   $4 = $PACKAGE_TYPE                  e.g. 'QPKG', 'IPKG', 'PIP'
    #   $5 = $TARGET_OBJECT_NAME (optional) e.g. 'ToStart', 'ToStop'...
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
    local -i index=0
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
            ;;
    esac

    local -r ACTION_INTRANSITIVE=${message_prefix}${6:?empty}
    local -r ACTION_PRESENT=${message_prefix}${7:?empty}
    local -r ACTION_PAST=${message_prefix}${8:?empty}

    ShowAsProc "checking for$([[ $TIER = all ]] && echo '' || echo " $TIER") packages to $ACTION_INTRANSITIVE" >&2

    case $PACKAGE_TYPE in
        QPKG)
            if $targets_function.$TARGET_OBJECT_NAME.IsNone; then
                DebugInfo "no $targets_function to process"
                DebugFuncExit; return
            fi

            if [[ $TIER = all ]]; then  # process all tiers
                target_packages=($($targets_function.$TARGET_OBJECT_NAME.Array))
            else                        # only process packages in specified tier, ignoring all others
                for package in $($targets_function.$TARGET_OBJECT_NAME.Array); do
                    $targets_function.Is"$(tr 'a-z' 'A-Z' <<< "${TIER:0:1}")${TIER:1}".Exist "$package" && target_packages+=("$package")
                done
            fi

            total_count=${#target_packages[@]}

            if [[ $total_count -eq 0 ]]; then
                DebugInfo "no$([[ $TIER = all ]] && echo '' || echo " $TIER") $targets_function to process"
                DebugFuncExit; return
            fi

            for package in "${target_packages[@]}"; do
                ShowAsOperationProgress "$TIER" "$PACKAGE_TYPE" "$pass_count" "$fail_count" "$total_count" "$ACTION_PRESENT" "$RUNTIME"

                $target_function.$TARGET_OPERATION "$package" "$forced_operation"
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
                        ;;
                esac
            done
            ;;
        IPKG|PIP)
            $targets_function.$TARGET_OPERATION
            ;;
    esac

    # execute with pass_count > total_count to trigger 100% message
    ShowAsOperationProgress "$TIER" "$PACKAGE_TYPE" "$((total_count+1))" "$fail_count" "$total_count" "$ACTION_PRESENT" "$RUNTIME"
    ShowAsOperationResult "$TIER" "$PACKAGE_TYPE" "$pass_count" "$fail_count" "$total_count" "$ACTION_PAST" "$RUNTIME"

    DebugFuncExit

    }

Session.Results()
    {

#     Session.Debug.ToArchive.IsSet && ReleaseLockFile # release lock early if possible so other instances can run

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
        elif Opts.Apps.List.All.IsSet; then
            QPKGs.All.Show
        elif Opts.Apps.List.Installable.IsSet; then
            QPKGs.IsInstallable.Show
        elif Opts.Apps.List.NotInstalled.IsSet; then
            QPKGs.IsNotInstalled.Show
        elif Opts.Apps.List.Started.IsSet; then
            QPKGs.IsStarted.Show
        elif Opts.Apps.List.Stopped.IsSet; then
            QPKGs.IsStopped.Show
        elif Opts.Apps.List.Upgradable.IsSet; then
            QPKGs.IsUpgradable.Show
        elif Opts.Apps.List.Standalone.IsSet; then
            QPKGs.IsStandalone.Show
        elif Opts.Apps.List.Dependent.IsSet; then
            QPKGs.IsDependent.Show
        elif Opts.Apps.List.Standalone.IsSet; then
            QPKGs.IsStandalone.Show
        elif Opts.Help.Backups.IsSet; then
            QPKGs.Backups.Show
        elif Opts.Help.Status.IsSet; then
            QPKGs.Statuses.Show
        elif Opts.Apps.List.Installed.IsSet; then
            QPKGs.IsInstalled.Show
        fi
    fi

    if Opts.Help.Basic.IsSet; then
        Help.Basic.Show
        Help.Basic.Example.Show
    fi

    Session.ShowBackupLocation.IsSet && Help.BackupLocation.Show
    Session.Summary.IsSet && ShowSummary
    Session.SuggestIssue.IsSet && Help.Issue.Show

    DebugInfoMinorSeparator
    DebugScript 'finished' "$($DATE_CMD)"
    DebugScript 'elapsed time' "$(ConvertSecsToHoursMinutesSecs "$(($($DATE_CMD +%s)-$([[ -n $SCRIPT_STARTSECONDS ]] && echo "$SCRIPT_STARTSECONDS" || echo "1")))")"
    DebugInfoMajorSeparator
    Session.Debug.ToArchive.IsSet && ArchiveActiveSessionLog
    CleanActiveSessionLog
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
                QPKGs.SkipProcessing.Clear
                QPKGs.States.Build
                ;;
            rm|remove|uninstall)
                operation=uninstall_
                arg_identified=true
                scope=''
                scope_identified=false
                Session.Display.Clean.Clear
                QPKGs.SkipProcessing.Clear
                QPKGs.States.Build
                ;;
            s|status|statuses)
                operation=status_
                arg_identified=true
                scope=''
                scope_identified=false
                Session.Display.Clean.Clear
                QPKGs.SkipProcessing.Set
                QPKGs.States.Build
                ;;
            paste)
                operation=paste_
                arg_identified=true
                scope=''
                scope_identified=false
                Session.Display.Clean.Clear
                QPKGs.SkipProcessing.Set
                ;;
            display|help|list|show|view)
                operation=help_
                arg_identified=true
                scope=''
                scope_identified=false
                Session.Display.Clean.Clear
                QPKGs.SkipProcessing.Set
                ;;
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
                    QPKGs.SkipProcessing.Set
                    ;;
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
                    ;;
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
                Opts.IgnoreFreeSpace.Set
                arg_identified=true
                ;;
        esac

        # identify package
        package=$(QPKG.MatchAbbrv "$arg")

        if [[ -n $package ]]; then
            scope_identified=true
            arg_identified=true
        fi

        if [[ $arg_identified = false ]]; then
            Args.Unknown.Add "$arg"
        fi

        case $operation in
            backup_)
                case $scope in
                    all_|installed_)
                        Opts.Apps.All.Backup.Set
                        operation=''
                        ;;
                    dependent_)
                        Opts.Apps.Dependent.Backup.Set
                        ;;
                    standalone_)
                        Opts.Apps.Standalone.Backup.Set
                        ;;
                    started_)
                        QPKGs.ToBackup.Add "$(QPKGs.IsStarted.Array)"
                        ;;
                    stopped_)
                        QPKGs.ToBackup.Add "$(QPKGs.IsStopped.Array)"
                        ;;
                    *)
                        QPKGs.ToBackup.Add "$package"
                        ;;
                esac
                ;;
            check_)
                Opts.Dependencies.Check.Set
                DebugFuncExit; return
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
                        QPKGs.States.Build
                        Opts.Apps.List.Installable.Set
                        Session.Display.Clean.Set
                        ;;
                    installed_)
                        QPKGs.States.Build
                        Opts.Apps.List.Installed.Set
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
                        QPKGs.States.Build
                        Opts.Apps.List.NotInstalled.Set
                        Session.Display.Clean.Set
                        ;;
                    dependent_)
                        Opts.Apps.List.Dependent.Set
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
                        Opts.Apps.List.Standalone.Set
                        Session.Display.Clean.Set
                        ;;
                    started_)
                        QPKGs.States.Build
                        Opts.Apps.List.Started.Set
                        Session.Display.Clean.Set
                        ;;
                    status_)
                        QPKGs.States.Build
                        Opts.Help.Status.Set
                        ;;
                    stopped_)
                        QPKGs.States.Build
                        Opts.Apps.List.Stopped.Set
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
                        QPKGs.States.Build
                        Opts.Apps.List.Upgradable.Set
                        Session.Display.Clean.Set
                        ;;
                    versions_)
                        Opts.Versions.View.Set
                        Session.Display.Clean.Set
                        ;;
                esac

                QPKGs.SkipProcessing.Set

                if [[ $scope_identified = true ]]; then
                    DebugFuncExit; return
                fi
                ;;
            install_)
                case $scope in
                    all_)
                        Opts.Apps.All.Install.Set
                        operation=''
                        ;;
                    dependent_)
                        Opts.Apps.Dependent.Install.Set
                        ;;
                    not-installed_)
                        QPKGs.ToInstall.Add "$(QPKGs.IsNotInstalled.Array)"
                        ;;
                    standalone_)
                        Opts.Apps.Standalone.Install.Set
                        ;;
                    *)
                        QPKGs.ToInstall.Add "$package"
                        ;;
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
                        ;;
                esac

                QPKGs.SkipProcessing.Set

                if [[ $scope_identified = true ]]; then
                    DebugFuncExit; return
                fi
                ;;
            rebuild_)
                case $scope in
                    all_|installed_)
                        Opts.Apps.All.Rebuild.Set
                        operation=''
                        ;;
                    dependent_)
                        Opts.Apps.Dependent.Rebuild.Set
                        ;;
                    standalone_)
                        Opts.Apps.Standalone.Rebuild.Set
                        ;;
                    *)
                        QPKGs.ToRebuild.Add "$package"
                        ;;
                esac
                ;;
            reinstall_)
                case $scope in
                    all_|installed_)
                        Opts.Apps.All.Reinstall.Set
                        operation=''
                        ;;
                    dependent_)
                        Opts.Apps.Dependent.Reinstall.Set
                        ;;
                    standalone_)
                        Opts.Apps.Standalone.Reinstall.Set
                        ;;
                    *)
                        QPKGs.ToReinstall.Add "$package"
                        ;;
                esac
                ;;
            restart_)
                case $scope in
                    all_|installed_)
                        Opts.Apps.All.Restart.Set
                        operation=''
                        ;;
                    dependent_)
                        Opts.Apps.Dependent.Restart.Set
#                         QPKGs.ToRestart.Add "$(QPKGs.IsDependent.Array)"
                        ;;
                    standalone_)
                        Opts.Apps.Standalone.Restart.Set
#                         QPKGs.ToRestart.Add "$(QPKGs.IsStandalone.Array)"
                        ;;
                    *)
                        QPKGs.ToRestart.Add "$package"
                        ;;
                esac
                ;;
            restore_)
                case $scope in
                    all_|installed_)
                        Opts.Apps.All.Restore.Set
                        operation=''
                        ;;
                    dependent_)
                        Opts.Apps.Dependent.Restore.Set
#                         QPKGs.ToRestore.Add "$(QPKGs.IsDependent.Array)"
                        ;;
                    standalone_)
                        Opts.Apps.Standalone.Restore.Set
#                         QPKGs.ToRestore.Add "$(QPKGs.IsStandalone.Array)"
                        ;;
                    *)
                        QPKGs.ToRestore.Add "$package"
                        ;;
                esac
                ;;
            start_)
                case $scope in
                    all_|installed_)
                        Opts.Apps.All.Start.Set
                        operation=''
                        ;;
                    dependent_)
                        Opts.Apps.Dependent.Start.Set
                        operation=''
                        ;;
                    standalone_)
                        Opts.Apps.Standalone.Start.Set
                        operation=''
                        ;;
                    stopped_)
                        QPKGs.ToStart.Add "$(QPKGs.IsStopped.Array)"
                        operation=''
                        ;;
                    *)
                        QPKGs.ToStart.Add "$package"
                        ;;
                esac
                ;;
            status_)
                Opts.Help.Status.Set
                QPKGs.SkipProcessing.Set
                DebugFuncExit; return
                ;;
            stop_)
                case $scope in
                    all_|installed_)
                        Opts.Apps.All.Stop.Set
                        operation=''
                        ;;
                    dependent_)
                        Opts.Apps.Dependent.Stop.Set
                        operation=''
                        ;;
                    standalone_)
                        Opts.Apps.Standalone.Stop.Set
                        operation=''
                        ;;
                    started_)
                        QPKGs.ToStop.Add "$(QPKGs.IsStarted.Array)"
                        operation=''
                        ;;
                    *)
                        QPKGs.ToStop.Add "$package"
                        ;;
                esac
                ;;
            uninstall_)
                case $scope in
                    all_|installed_)   # this scope is dangerous, so make 'force' a requirement
                        if [[ $operation_force = true ]]; then
                            Opts.Apps.All.Uninstall.Set
                            operation=''
                            operation_force=false
                        fi
                        ;;
                    dependent_)
                        Opts.Apps.Dependent.Uninstall.Set
                        operation=''
                        operation_force=false
                        ;;
                    standalone_)
                        Opts.Apps.Standalone.Uninstall.Set
                        operation=''
                        operation_force=false
                        ;;
                    started_)
                        QPKGs.ToUninstall.Add "$(QPKGs.IsStarted.Array)"
                        operation=''
                        operation_force=false
                        ;;
                    stopped_)
                        QPKGs.ToUninstall.Add "$(QPKGs.IsStopped.Array)"
                        operation=''
                        operation_force=false
                        ;;
                    *)
                        QPKGs.ToUninstall.Add "$package"
                        ;;
                esac
                ;;
            upgrade_)
                case $scope in
                    all_)
                        Opts.Apps.All.Upgrade.Set
                        operation=''
                        ;;
                    dependent_)
                        Opts.Apps.Dependent.Upgrade.Set
                        ;;
                    standalone_)
                        Opts.Apps.Standalone.Upgrade.Set
                        ;;
                    started_)
                        QPKGs.ToUpgrade.Add "$(QPKGs.IsStarted.Array)"
                        ;;
                    stopped_)
                        QPKGs.ToUpgrade.Add "$(QPKGs.IsStopped.Array)"
                        ;;
                    upgradable_)
                        QPKGs.ToUpgrade.Add "$(QPKGs.IsUpgradable.Array)"
                        ;;
                    *)
                        QPKGs.ToUpgrade.Add "$package"
                        ;;
                esac
                ;;
        esac
    done

    if [[ -n $operation && $scope_identified = false ]]; then
        case $operation in
            abs_)
                Opts.Help.Abbreviations.Set
                DebugFuncExit; return
                ;;
            backups_)
                Opts.Help.Backups.Set
                DebugFuncExit; return
                ;;
            help_)
                Opts.Help.Basic.Set
                DebugFuncExit; return
                ;;
            options_)
                Opts.Help.Options.Set
                DebugFuncExit; return
                ;;
            packages_)
                Opts.Help.Packages.Set
                DebugFuncExit; return
                ;;
            problems_)
                Opts.Help.Problems.Set
                DebugFuncExit; return
                ;;
            tips_)
                Opts.Help.Tips.Set
                DebugFuncExit; return
                ;;
            versions_)
                Opts.Versions.View.Set
                Session.Display.Clean.Set
                DebugFuncExit; return
                ;;
        esac
    fi

    if Args.Unknown.IsAny; then
        Opts.Help.Basic.Set
        Session.Display.Clean.Clear
        QPKGs.SkipProcessing.Set
        DebugFuncExit; return   # ... and stop processing any further arguments
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
                    DisplayAsProjectSyntaxExample "please provide an $(FormatAsHelpAction) before 'all' like" 'start all'
                    Opts.Help.Basic.Clear
                    ;;
                all-backup|backup-all)
                    Display
                    DisplayAsProjectSyntaxExample 'to backup all installed package configurations, use' 'backup all'
                    Opts.Help.Basic.Clear
                    ;;
                dependent)
                    Display
                    DisplayAsProjectSyntaxExample "please provide an $(FormatAsHelpAction) before 'dependent' like" 'start dependent'
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
                    DisplayAsProjectSyntaxExample "please provide an $(FormatAsHelpAction) before 'standalone' like" 'start standalone'
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
                    ;;
            esac
        done
    fi

    DebugFuncExit

    }

ListEnvironment()
    {

    DebugFuncEntry

    local -i max_width=70
    local -i trimmed_width=$((max_width-3))
    local version=''

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

    if [[ $NAS_BUILD -lt 20201015 || $NAS_BUILD -gt 20201020 ]]; then   # builds in between won't allow unsigned QPKGs to run at-all
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
        QPKGs.SkipProcessing.Set
        DebugFuncExit 1; return
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

    if QPKGs.IsInstalled.Exist Entware && ! QPKGs.ToUninstall.Exist Entware; then
        [[ -e /opt/bin/python3 ]] && version=$(/opt/bin/python3 -V 2>/dev/null | $SED_CMD 's|^Python ||') && [[ ${version//./} -lt $MIN_PYTHON_VER ]] && ShowAsReco "your Python 3 is out-of-date. Suggest reinstalling Entware: '$PROJECT_NAME reinstall ew'"
    fi

    DebugScript 'logs path' "$LOGS_PATH"
    DebugScript 'work path' "$WORK_PATH"
    DebugScript 'objects hash' "$(CompileObjects hash)"
    DebugInfoMinorSeparator

    DebugFuncExit

    }

CleanArchivedLogs()
    {

    if [[ -n $LOGS_PATH && -d $LOGS_PATH ]]; then
        rm -rf "${LOGS_PATH:?}"/*
        ShowAsDone 'logs path cleaned'
    fi

    return 0

    }

CleanWorkPath()
    {

    if [[ -n $WORK_PATH && -d $WORK_PATH ]]; then
        rm -rf "${WORK_PATH:?}"/*
        ShowAsDone 'work path cleaned'
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
            ;;
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

    if IsNotSysFileExist /opt/bin/opkg; then
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
        else
            DebugAsWarn "Unable to update $(FormatAsPackageName Entware) package list $(FormatAsExitcode $result_code)"
            # no-big-deal
        fi
    else
        DebugInfo "$(FormatAsPackageName Entware) package list updated less-than $CHANGE_THRESHOLD_MINUTES minutes ago: skipping update"
    fi

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

    if IsNotSysFileExist /opt/bin/opkg || IsNotSysFileExist $GNU_GREP_CMD; then
        code_pointer=3
        return 1
    fi

    DebugFuncEntry
    local -a this_list=()
    local -a dependency_accumulator=()
    local -i requested_count=0
    local -i pre_exclude_count=0
    local -i iterations=0
    local -r ITERATION_LIMIT=20
    local requested_list=''
    local pre_exclude_list=''
    local element=''
    local complete=false

    # remove duplicate entries
    requested_list=$(DeDupeWords "$(IPKGs.ToInstall.List)")
    this_list=($requested_list)
    requested_count=$($WC_CMD -w <<< "$requested_list")

    if [[ $requested_count -eq 0 ]]; then
        DebugAsWarn 'no IPKGs requested: aborting ...'
        DebugFuncExit 1; return
    fi

    if ! OpenIPKGArchive; then
        DebugFuncExit 1; return
    fi

    ShowAsProc 'calculating IPKG dependencies'
    DebugInfo "$requested_count IPKG$(Plural "$requested_count") requested" "'$requested_list' "

    while [[ $iterations -lt $ITERATION_LIMIT ]]; do
        ((iterations++))

        local IPKG_titles=$(printf '^Package: %s$\|' "${this_list[@]}")
        IPKG_titles=${IPKG_titles%??}       # remove last 2 characters

        this_list=($($GNU_GREP_CMD --word-regexp --after-context 1 --no-group-separator '^Package:\|^Depends:' "$EXTERNAL_PACKAGE_LIST_PATHFILE" | $GNU_GREP_CMD -vG '^Section:\|^Version:' | $GNU_GREP_CMD --word-regexp --after-context 1 --no-group-separator "$IPKG_titles" | $GNU_GREP_CMD -vG "$IPKG_titles" | $GNU_GREP_CMD -vG '^Package: ' | $SED_CMD 's|^Depends: ||;s|, |\n|g' | $SORT_CMD | $UNIQ_CMD))

        if [[ ${#this_list[@]} -eq 0 ]]; then
            complete=true
            break
        else
            dependency_accumulator+=(${this_list[*]})
        fi
    done

    if [[ $complete = true ]]; then
        DebugAsDone "complete in $iterations iteration$(Plural $iterations)"
    else
        DebugAsError "incomplete in $iterations iteration$(Plural $iterations), consider raising \$ITERATION_LIMIT [$ITERATION_LIMIT]"
        Session.SuggestIssue.Set
    fi

    # exclude already installed IPKGs
    pre_exclude_list=$(DeDupeWords "$requested_list ${dependency_accumulator[*]}")
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
                        IPKGs.ToDownload.Add "$element"
                    fi
                elif ! /opt/bin/opkg status 'libjpeg-turbo' | $GREP_CMD -q "Status:.*installed"; then
                    IPKGs.ToDownload.Add 'libjpeg-turbo'
                fi
            fi
        done
    else
        DebugAsDone 'no IPKGs to exclude'
    fi

    CloseIPKGArchive
    DebugFuncExit

    }

CalcAllIPKGDepsToUninstall()
    {

    # From a specified list of IPKG names, exclude those already installed, then generate a total qty to uninstall

    if IsNotSysFileExist /opt/bin/opkg || IsNotSysFileExist $GNU_GREP_CMD; then
        code_pointer=4
        return 1
    fi

    DebugFuncEntry
    local requested_list=''
    local element=''

    requested_list=$(DeDupeWords "$(IPKGs.ToUninstall.List)")
    DebugInfo "$($WC_CMD -w <<< "$requested_list") IPKG$(Plural "$($WC_CMD -w <<< "$requested_list")") requested" "'$requested_list' "
    DebugAsProc 'excluding IPKGs not installed'

    for element in $requested_list; do
        ! /opt/bin/opkg status "$element" | $GREP_CMD -q "Status:.*installed" && IPKGs.ToUninstall.Remove "$element"
    done

    if [[ $(IPKGs.ToUninstall.Count) -gt 0 ]]; then
        DebugAsDone "$(IPKGs.ToUninstall.Count) IPKG$(Plural "$(IPKGs.ToUninstall.Count)") to uninstall: '$(IPKGs.ToUninstall.List)'"
    else
        DebugAsDone 'no IPKGs to uninstall'
    fi

    DebugFuncExit

    }

CalcIPKGsDownloadSize()
    {

    # calculate size of required IPKGs

    DebugFuncEntry

    if ! OpenIPKGArchive; then
        DebugFuncExit 1; return
    fi

    local -a size_array=()
    local -i size_count=0
    size_count=$(IPKGs.ToDownload.Count)

    if [[ $size_count -gt 0 ]]; then
        DebugAsDone "$size_count IPKG$(Plural "$size_count") to download: '$(IPKGs.ToDownload.List)'"
        DebugAsProc "calculating size of IPKG$(Plural "$size_count") to download"
        size_array=($($GNU_GREP_CMD -w '^Package:\|^Size:' "$EXTERNAL_PACKAGE_LIST_PATHFILE" | $GNU_GREP_CMD --after-context 1 --no-group-separator ": $($SED_CMD 's/ /$ /g;s/\$ /\$\\\|: /g' <<< "$(IPKGs.ToDownload.List)")$" | $GREP_CMD '^Size:' | $SED_CMD 's|^Size: ||'))
        IPKGs.ToDownload.Size = "$(IFS=+; echo "$((${size_array[*]}))")"   # a neat sizing shortcut found here https://stackoverflow.com/a/13635566/6182835
        DebugAsDone "$(FormatAsThousands "$(IPKGs.ToDownload.Size)") bytes ($(FormatAsISOBytes "$(IPKGs.ToDownload.Size)")) to download"
    else
        DebugAsDone 'no IPKGs to size'
    fi

    CloseIPKGArchive
    DebugFuncExit

    }

IPKGs.Upgrade()
    {

    # upgrade all installed IPKGs

    QPKGs.SkipProcessing.IsSet && return
    IPKGs.Upgrade.IsNot && return
    QPKGs.IsNotInstalled.Exist Entware && return
    QPKGs.IsStopped.Exist Entware && return
    UpdateEntware
    Session.Error.IsSet && return
    DebugFuncEntry
    local -i result_code=0
    IPKGs.ToUpgrade.Init
    IPKGs.ToDownload.Init

    IPKGs.ToUpgrade.Add "$(/opt/bin/opkg list-upgradable | cut -f1 -d' ')"
    IPKGs.ToDownload.Add "$(IPKGs.ToUpgrade.Array)"

    CalcIPKGsDownloadSize
    local -i total_count=$(IPKGs.ToDownload.Count)

    if [[ $total_count -gt 0 ]]; then
        ShowAsProc "downloading & upgrading $total_count IPKG$(Plural "$total_count")"

        CreateDirSizeMonitorFlagFile "$IPKG_DL_PATH"/.monitor
            trap CTRL_C_Captured INT
                _MonitorDirSize_ "$IPKG_DL_PATH" "$(IPKGs.ToDownload.Size)" &

                RunAndLog "/opt/bin/opkg upgrade$(Opts.IgnoreFreeSpace.IsSet && Opts.IgnoreFreeSpace.Text) --force-overwrite $(IPKGs.ToDownload.List) --cache $IPKG_CACHE_PATH --tmp-dir $IPKG_DL_PATH" "$LOGS_PATH/ipkgs.$UPGRADE_LOG_FILE" log:failure-only
                result_code=$?
            trap - INT
        RemoveDirSizeMonitorFlagFile

        if [[ $result_code -eq 0 ]]; then
            ShowAsDone "downloaded & upgraded $total_count IPKG$(Plural "$total_count")"
        else
            ShowAsEror "download & upgrade $total_count IPKG$(Plural "$total_count") failed $(FormatAsExitcode $result_code)"
        fi
    fi

    DebugFuncExit

    }

IPKGs.Install()
    {

    # install IPKGs required to support QPKGs

    QPKGs.SkipProcessing.IsSet && return
    IPKGs.Install.IsNot && return
    QPKGs.IsNotInstalled.Exist Entware && return
    QPKGs.IsStopped.Exist Entware && return
    UpdateEntware
    Session.Error.IsSet && return
    DebugFuncEntry
    local -i index=0
    local -i result_code=0
    IPKGs.ToInstall.Init
    IPKGs.ToDownload.Init

    IPKGs.ToInstall.Add "$MANAGER_BASE_IPKGS_ADD"
    IPKGs.ToInstall.Add "$MANAGER_SHARED_IPKGS_ADD"

    if Opts.Apps.All.Install.IsSet; then
        for index in "${!MANAGER_QPKG_NAME[@]}"; do
            [[ ${MANAGER_QPKG_ARCH[$index]} = "$NAS_QPKG_ARCH" || ${MANAGER_QPKG_ARCH[$index]} = all ]] || continue
            IPKGs.ToInstall.Add "${MANAGER_QPKG_IPKGS_ADD[$index]}"
        done
    else
        for index in "${!MANAGER_QPKG_NAME[@]}"; do
            QPKGs.ToInstall.Exist "${MANAGER_QPKG_NAME[$index]}" || (QPKGs.IsInstalled.Exist "${MANAGER_QPKG_NAME[$index]}" && QPKGs.IsStarted.Exist "${MANAGER_QPKG_NAME[$index]}") || QPKGs.ToReinstall.Exist "${MANAGER_QPKG_NAME[$index]}" || QPKGs.ToStart.Exist "${MANAGER_QPKG_NAME[$index]}" || continue
            [[ ${MANAGER_QPKG_ARCH[$index]} = "$NAS_QPKG_ARCH" || ${MANAGER_QPKG_ARCH[$index]} = all ]] || continue
            QPKG.MinRAM "${MANAGER_QPKG_NAME[$index]}" &>/dev/null || continue
            IPKGs.ToInstall.Add "${MANAGER_QPKG_IPKGS_ADD[$index]}"
        done
    fi

    CalcIPKGsDepsToInstall
    CalcIPKGsDownloadSize
    local -i total_count=$(IPKGs.ToDownload.Count)

    if [[ $total_count -gt 0 ]]; then
        ShowAsProc "downloading & installing $total_count IPKG$(Plural "$total_count")"

        CreateDirSizeMonitorFlagFile "$IPKG_DL_PATH"/.monitor
            trap CTRL_C_Captured INT
                _MonitorDirSize_ "$IPKG_DL_PATH" "$(IPKGs.ToDownload.Size)" &

                RunAndLog "/opt/bin/opkg install$(Opts.IgnoreFreeSpace.IsSet && Opts.IgnoreFreeSpace.Text) --force-overwrite $(IPKGs.ToDownload.List) --cache $IPKG_CACHE_PATH --tmp-dir $IPKG_DL_PATH" "$LOGS_PATH/ipkgs.addons.$INSTALL_LOG_FILE" log:failure-only
                result_code=$?
            trap - INT
        RemoveDirSizeMonitorFlagFile

        if [[ $result_code -eq 0 ]]; then
            ShowAsDone "downloaded & installed $total_count IPKG$(Plural "$total_count")"
        else
            ShowAsEror "download & install $total_count IPKG$(Plural "$total_count") failed $(FormatAsExitcode $result_code)"
        fi
    fi

    DebugFuncExit

    }

IPKGs.Uninstall()
    {

    QPKGs.SkipProcessing.IsSet && return
    QPKGs.IsNotInstalled.Exist Entware && return
    QPKGs.IsStopped.Exist Entware && return
    Session.Error.IsSet && return
    DebugFuncEntry
    local -i index=0
    local -i result_code=0

    if Opts.Apps.All.Uninstall.IsNot; then
        for index in "${!MANAGER_QPKG_NAME[@]}"; do
            if QPKGs.ToInstall.Exist "${MANAGER_QPKG_NAME[$index]}" || QPKGs.IsInstalled.Exist "${MANAGER_QPKG_NAME[$index]}" || QPKGs.ToUpgrade.Exist "${MANAGER_QPKG_NAME[$index]}" || QPKGs.ToUninstall.Exist "${MANAGER_QPKG_NAME[$index]}"; then
                IPKGs.ToUninstall.Add "${MANAGER_QPKG_IPKGS_REMOVE[$index]}"
            fi
        done
    fi

    # KLUDGE: when package arch is 'none', prevent 'par2cmdline' being uninstalled, then installed again later this same session. Noticed this was happening on ARMv5 models.
    [[ $NAS_QPKG_ARCH = none ]] && IPKGs.ToUninstall.Remove par2cmdline

    # KLUDGE: switched-to the PIP package instead. Ref: https://forums.sabnzbd.org/viewtopic.php?p=123862#p123862
    IPKGs.ToUninstall.Remove python3-pyopenssl

    CalcAllIPKGDepsToUninstall
    local -i total_count=$(IPKGs.ToUninstall.Count)

    if [[ $total_count -gt 0 ]]; then
        ShowAsProc "uninstalling $total_count IPKG$(Plural "$total_count")"

        RunAndLog "/opt/bin/opkg remove $(IPKGs.ToUninstall.List)" "$LOGS_PATH/ipkgs.$UNINSTALL_LOG_FILE" log:failure-only
        result_code=$?

        if [[ $result_code -eq 0 ]]; then
            ShowAsDone "uninstalled $total_count IPKG$(Plural "$total_count")"
        else
            ShowAsEror "uninstall IPKG$(Plural "$total_count") failed $(FormatAsExitcode $result_code)"
        fi
    fi

    DebugFuncExit

    }

PIPs.Install()
    {

    QPKGs.SkipProcessing.IsSet && return
    QPKGs.IsNotInstalled.Exist Entware && return
    QPKGs.IsStopped.Exist Entware && return
    PIPs.Install.IsNot && return
    Session.Error.IsSet && return
    DebugFuncEntry
    local exec_cmd=''
    local -i result_code=0
    local -i pass_count=0
    local -i fail_count=0
    local -i total_count=0
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
        if IsNotSysFileExist $pip3_cmd; then
            Display "* Ugh! The usual fix for this is to let $(FormatAsScriptTitle) reinstall $(FormatAsPackageName Entware) at least once."
            Display "\t$0 reinstall ew"
            Display "If it happens again after reinstalling $(FormatAsPackageName Entware), please create a new issue for this on GitHub."
            DebugFuncExit 1; return
        fi
    fi

    ModPathToEntware

    [[ -n ${MANAGER_SHARED_PIPS_ADD// /} ]] && exec_cmd="$pip3_cmd install $MANAGER_SHARED_PIPS_ADD --disable-pip-version-check --cache-dir $PIP_CACHE_PATH"
    ((total_count++))

    ShowAsOperationProgress '' "$PACKAGE_TYPE" "$pass_count" "$fail_count" "$total_count" "$ACTION_PRESENT" "$RUNTIME"

    local desc="'Python3' modules"
    local log_pathfile=$LOGS_PATH/py3-modules.assorted.$INSTALL_LOG_FILE
    DebugAsProc "downloading & installing $desc"

    RunAndLog "$exec_cmd" "$log_pathfile" log:failure-only
    result_code=$?

    if [[ $result_code -eq 0 ]]; then
        DebugAsDone "downloaded & installed $desc"
        ((pass_count++))
    else
        ShowAsEror "download & install $desc failed $(FormatAsResult "$result_code")"
        ((fail_count++))
    fi

    if QPKGs.ToInstall.Exist SABnzbd || QPKGs.ToReinstall.Exist SABnzbd || (Opts.Dependencies.Check.IsSet && QPKGs.IsInstalled.Exist SABnzbd); then
        ((total_count+=2))

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
            QPKGs.ToRestart.Add SABnzbd
            ((pass_count++))
        else
            ShowAsEror "download & install $desc failed $(FormatAsResult "$result_code")"
            ((fail_count++))
        fi

        # KLUDGE: ensure 'feedparser' is upgraded. This was version-held at 5.2.1 for Python 3.8.5 but from Python 3.9.0 onward there's no-need for version-hold anymore.
        ShowAsOperationProgress '' "$PACKAGE_TYPE" "$pass_count" "$fail_count" "$total_count" "$ACTION_PRESENT" "$RUNTIME"

        exec_cmd="$pip3_cmd install --upgrade feedparser --disable-pip-version-check --cache-dir $PIP_CACHE_PATH"
        desc="'Python3 feedparser' module"
        log_pathfile=$LOGS_PATH/py3-modules.feedparser.$INSTALL_LOG_FILE
        DebugAsProc "downloading & installing $desc"
        RunAndLog "$exec_cmd" "$log_pathfile" log:failure-only
        result_code=$?

        if [[ $result_code -eq 0 ]]; then
            DebugAsDone "downloaded & installed $desc"
            QPKGs.ToRestart.Add SABnzbd
            ((pass_count++))
        else
            ShowAsEror "download & install $desc failed $(FormatAsResult "$result_code")"
            ((fail_count++))
        fi
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

    CloseIPKGArchive

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

IsNotSysFileExist()
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

DisplayAsHelpPackageNamePlusSomething()
    {

    # $1 = package name
    # $2 = additional text

    printf "%${HELP_DESC_INDENT}s%-${HELP_PACKAGE_NAME_WIDTH}s - %s\n" '' "${1:-}" "${2:-}"

    }

DisplayAsHelpTitlePackageNamePlusSomething()
    {

    # $1 = package name
    # $2 = additional text

    printf "* %-${HELP_PACKAGE_NAME_WIDTH}s * %s\n" "$(tr 'a-z' 'A-Z' <<< "${1:0:1}")${1:1}:" "$(tr 'a-z' 'A-Z' <<< "${2:0:1}")${2:1}:"

    }

DisplayAsHelpTitleFileNamePlusSomething()
    {

    # $1 = file name
    # $2 = additional text

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
    DisplayAsProjectSyntaxIndentedExample "uninstall everything!" 'force uninstall all'
    DisplayAsProjectSyntaxIndentedExample "reinstall all installed packages" 'reinstall all'
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

    local package=''
    local tier=''

    DisableDebugToArchiveAndFile
    Help.Basic.Show
    Display
    DisplayAsHelpTitle "One-or-more $(FormatAsHelpPackages) may be specified at-once"
    Display

    for tier in Standalone Dependent; do
        DisplayAsHelpTitlePackageNamePlusSomething "${tier} QPKGs" 'package description'

        for package in $(QPKGs.Is$tier.Array); do
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
    DisplayAsProjectSyntaxIndentedExample "clean the $(FormatAsScriptTitle) cache" 'clean'
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
    DisplayAsProjectSyntaxIndentedExample "start all stopped packages" 'start stopped'
    DisplayAsProjectSyntaxIndentedExample 'upgrade the internal applications only' "restart $(FormatAsHelpPackages)"
    Help.BackupLocation.Show

    return 0

    }

Help.PackageAbbreviations.Show()
    {

    local package=''
    local tier=''
    local abs=''

    DisableDebugToArchiveAndFile
    Help.Basic.Show
    Display
    DisplayAsHelpTitle "$(FormatAsScriptTitle) recognises various abbreviations as $(FormatAsHelpPackages)"
    Display

    for tier in Standalone Dependent; do
        DisplayAsHelpTitlePackageNamePlusSomething "${tier} QPKGs" 'acceptable abreviations'

        for package in $(QPKGs.Is$tier.Array); do
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
                ShowAsEror "a link could not be generated. Most likely a problem occurred when talking with $(FormatAsURL 'https://termbin.com')"
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
                ShowAsEror "a link could not be generated. Most likely a problem occurred when talking with $(FormatAsURL 'https://termbin.com')"
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
                ShowAsEror "a link could not be generated. Most likely a problem occurred when talking with $(FormatAsURL 'https://termbin.com')"
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

CleanActiveSessionLog()
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

    # Check installed QPKGs and compare versions against package arrays. If new versions are available, advise on-screen.

    # $? = 0 if all packages are up-to-date
    # $? = 1 if one-or-more packages can be upgraded

    local msg=''
    local -i index=0
    local -a left_to_upgrade=()
    local names_formatted=''

    for package in $(QPKGs.IsUpgradable.Array); do
        # only show upgradable packages if they haven't been selected for upgrade in active session
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

    QPKGs.SkipProcessing.IsSet && return
    DebugFuncEntry
    local array_name=''
    local state_name=''
    DebugInfoMinorSeparator

    for array_name in Download Backup Stop Uninstall Upgrade Reinstall Install Restore Start Restart; do
        # speedup: only log arrays with more than zero elements
        for state_name in To Ok Er Sk; do
            if QPKGs.${state_name}${array_name}.IsAny; then
                if [[ $state_name != To ]]; then
                    DebugQPKGInfo "${state_name}${array_name}" "($(QPKGs.${state_name}${array_name}.Count)) $(QPKGs.${state_name}${array_name}.ListCSV) "
                else
                    DebugQPKGWarning "${state_name}${array_name}" "($(QPKGs.${state_name}${array_name}.Count)) $(QPKGs.${state_name}${array_name}.ListCSV) "
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
    local array_name=''
    local state_name=''
    DebugInfoMinorSeparator

    QPKGs.States.Built.IsNot && QPKGs.States.Build

    for array_name in Installed Starting Started Stopping Stopped Restarting BackedUp Upgradable Missing; do
        # speedup: only log arrays with more than zero elements
        for state_name in Is IsNot; do
            QPKGs.${state_name}${array_name}.IsAny && DebugQPKGInfo "${state_name}${array_name}" "($(QPKGs.${state_name}${array_name}.Count)) $(QPKGs.${state_name}${array_name}.ListCSV) "
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
            QPKGs.IsStandalone.Add "${MANAGER_QPKG_NAME[$index]}"
        else
            QPKGs.IsDependent.Add "${MANAGER_QPKG_NAME[$index]}"
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
    ShowAsProc 'checking installed QPKGs' >&2

    local package=''
    local installed_version=''
    local remote_version=''

    for package in $(QPKGs.Names.Array); do
        QPKG.IsInstallable "$package" && QPKGs.IsInstallable.Add "$package"

        if QPKG.IsInstalled "$package"; then
            QPKGs.IsInstalled.Add "$package"

            installed_version=$(QPKG.Local.Version "$package")
            remote_version=$(QPKG.Remote.Version "$package")
            [[ ${installed_version//./} != "${remote_version//./}" ]] && QPKGs.IsUpgradable.Add "$package"

            case $(QPKG.GetServiceStatus "$package") in
                starting)
                    QPKGs.IsStarting.Add "$package"
                    ;;
                restarting)
                    QPKGs.IsRestarting.Add "$package"
                    ;;
                stopping)
                    QPKGs.IsStopping.Add "$package"
                    ;;
                *)
                    if QPKG.IsStarted "$package"; then
                        QPKGs.IsStarted.Add "$package"
                    elif QPKG.IsStopped "$package"; then
                        QPKGs.IsStopped.Add "$package"
                    fi
                    ;;
            esac

            [[ ! -d $(QPKG.InstallPath "$package") ]] && QPKGs.IsMissing.Add "$package"
        else
            QPKGs.IsNotInstalled.Add "$package"
        fi

        if QPKG.IsSupportBackup "$package"; then
            if [[ -e $BACKUP_PATH/$package.config.tar.gz ]]; then
                QPKGs.IsBackedUp.Add "$package"
            else
                QPKG.IsInstalled "$package" && QPKGs.IsNotBackedUp.Add "$package"
            fi
        fi
    done

    QPKGs.States.Built.Set
    DebugFuncExit

    }

QPKGs.IsSupportBackup.Build()
    {

    # Builds a list of QPKGs that do and don't support 'backup' and 'restore' operations

    DebugFuncEntry
    local package=''

    for package in $(QPKGs.Names.Array); do
        if QPKG.IsSupportBackup "$package"; then
            QPKGs.IsSupportBackup.Add "$package"
            QPKGs.IsNotSupportBackup.Remove "$package"
        else
            QPKGs.IsNotSupportBackup.Add "$package"
            QPKGs.IsSupportBackup.Remove "$package"
        fi
    done

    DebugFuncExit

    }

QPKGs.IsSupportUpdateOnRestart.Build()
    {

    # Builds a list of QPKGs that do and don't support application updating on QPKG restart

    DebugFuncEntry
    local package=''

    for package in $(QPKGs.Names.Array); do
        if QPKG.IsSupportUpdateOnRestart "$package"; then
            QPKGs.IsSupportUpdateOnRestart.Add "$package"
            QPKGs.IsNotSupportUpdateOnRestart.Remove "$package"
        else
            QPKGs.IsNotSupportUpdateOnRestart.Add "$package"
            QPKGs.IsSupportUpdateOnRestart.Remove "$package"
        fi
    done

    DebugFuncExit

    }

QPKGs.All.Show()
    {

    local package=''

    DisableDebugToArchiveAndFile

    for package in $(QPKGs.Names.Array); do
        Display "$package"
    done

    return 0

    }

QPKGs.Backups.Show()
    {

    local epochtime=0
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

    local -a package_notes=()
    local tier=''

    SmartCR
    DisplayLineSpaceIfNoneAlready

    for tier in Standalone Dependent; do
        DisplayAsHelpTitlePackageNamePlusSomething "${tier} QPKGs" 'statuses'

        for package in $(QPKGs.Is$tier.Array); do
            package_notes=()
            package_note=''

            if ! QPKG.URL "$package" &>/dev/null; then
                DisplayAsHelpPackageNamePlusSomething "$package" 'not installable on this NAS (unsupported arch)'
            elif ! QPKG.MinRAM "$package" &>/dev/null; then
                DisplayAsHelpPackageNamePlusSomething "$package" 'not installable on this NAS (insufficient RAM)'
            elif QPKGs.IsNotInstalled.Exist "$package"; then
                DisplayAsHelpPackageNamePlusSomething "$package" 'not installed'
            else
                QPKGs.IsStarting.Exist "$package" && package_notes+=($(ColourTextBrightOrange starting))
                QPKGs.IsStarted.Exist "$package" && package_notes+=($(ColourTextBrightGreen started))
                QPKGs.IsStopping.Exist "$package" && package_notes+=($(ColourTextBrightOrange stopping))
                QPKGs.IsStopped.Exist "$package" && package_notes+=($(ColourTextBrightRed stopped))
                QPKGs.IsRestarting.Exist "$package" && package_notes+=($(ColourTextBrightOrange restarting))
                QPKGs.IsUpgradable.Exist "$package" && package_notes+=($(ColourTextBrightOrange upgradable))
                QPKGs.IsMissing.Exist "$package" && package_notes=($(ColourTextBrightRedBlink missing))

                [[ ${#package_notes[@]} -gt 0 ]] && package_note="${package_notes[*]}"

                DisplayAsHelpPackageNamePlusSomething "$package" "${package_note// /, }"
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

    DisableDebugToArchiveAndFile

    for package in $(QPKGs.IsInstalled.Array); do
        Display "$package"
    done

    return 0

    }

QPKGs.IsInstallable.Show()
    {

    local package=''

    DisableDebugToArchiveAndFile

    for package in $(QPKGs.IsInstallable.Array); do
        Display "$package"
    done

    return 0

    }

QPKGs.IsNotInstalled.Show()
    {

    local package=''

    DisableDebugToArchiveAndFile

    for package in $(QPKGs.IsNotInstalled.Array); do
        Display "$package"
    done

    return 0

    }

QPKGs.IsStarted.Show()
    {

    local package=''

    DisableDebugToArchiveAndFile

    for package in $(QPKGs.IsStarted.Array); do
        Display "$package"
    done

    return 0

    }

QPKGs.IsStopped.Show()
    {

    local package=''

    DisableDebugToArchiveAndFile

    for package in $(QPKGs.IsStopped.Array); do
        Display "$package"
    done

    return 0

    }

QPKGs.IsUpgradable.Show()
    {

    local package=''

    DisableDebugToArchiveAndFile

    for package in $(QPKGs.IsUpgradable.Array); do
        Display "$package"
    done

    return 0

    }

QPKGs.IsStandalone.Show()
    {

    local package=''

    DisableDebugToArchiveAndFile

    for package in $(QPKGs.IsStandalone.Array); do
        Display "$package"
    done

    return 0

    }

QPKGs.IsDependent.Show()
    {

    local package=''

    DisableDebugToArchiveAndFile

    for package in $(QPKGs.IsDependent.Array); do
        Display "$package"
    done

    return 0

    }

MarkOpAsDone()
    {

    # move specified package name from 'To' operation array into associated 'Ok' array

    # input:
    #   $1 = package name
    #   $2 = action

    QPKGs.To"$(tr 'a-z' 'A-Z' <<< "${2:0:1}")${2:1}".Remove "$1"
    QPKGs.Ok"$(tr 'a-z' 'A-Z' <<< "${2:0:1}")${2:1}".Add "$1"

    return 0

    }

MarkOpAsError()
    {

    # move specified package name from 'To' operation array into associated 'Er' array

    # input:
    #   $1 = package name
    #   $2 = action
    #   $3 = reason (optional)

    local message="failing request to $2 $(FormatAsPackageName "$1")"

    [[ -n ${3:-} ]] && message+=" as $3"
    DebugAsError "$message" >&2
    QPKGs.To"$(tr 'a-z' 'A-Z' <<< "${2:0:1}")${2:1}".Remove "$1"
    QPKGs.Er"$(tr 'a-z' 'A-Z' <<< "${2:0:1}")${2:1}".Add "$1"

    return 0

    }

MarkOpAsSkipped()
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

    QPKGs.To"$(tr 'a-z' 'A-Z' <<< "${3:0:1}")${3:1}".Remove "$2"
    QPKGs.Sk"$(tr 'a-z' 'A-Z' <<< "${3:0:1}")${3:1}".Add "$2"

    return 0

    }

MarkStateAsInstalled()
    {

    QPKGs.IsNotInstalled.Remove "$1"
    QPKGs.IsInstalled.Add "$1"

    }

MarkStateAsNotInstalled()
    {

    QPKGs.IsInstalled.Remove "$1"
    QPKGs.IsNotInstalled.Add "$1"

    }

MarkStateAsStarted()
    {

    QPKGs.IsStopped.Remove "$1"
    QPKGs.IsStarted.Add "$1"

    }

MarkStateAsStopped()
    {

    QPKGs.IsStarted.Remove "$1"
    QPKGs.IsStopped.Add "$1"

    }

CalcQPKGArch()
    {

    # Decide which package arch is suitable for this NAS.
    # creates a global constant: $NAS_QPKG_ARCH

    case $($UNAME_CMD -m) in
        x86_64)
            [[ ${NAS_FIRMWARE//.} -ge 430 ]] && NAS_QPKG_ARCH=x64 || NAS_QPKG_ARCH=x86
            ;;
        i686|x86)
            NAS_QPKG_ARCH=x86
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

    [[ $(type -t QPKGs.SkipProcessing.Init) = function ]] && QPKGs.SkipProcessing.Set
    Session.Error.IsSet && return
    _script_error_flag_=true
    DebugVar _script_error_flag_

    }

Session.Error.IsSet()
    {

    [[ ${_script_error_flag_:-} = true ]]

    }

Session.Error.IsNot()
    {

    [[ ${_script_error_flag_:-} != true ]]

    }

ShowSummary()
    {

    local -i index=0
    local -a operations_array=(Backup Stop Uninstall Upgrade Reinstall Install Restore Start Restart)
    local -a messages_array=(backed-up stopped uninstalled upgraded reinstalled installed restored started restarted)

    for index in "${!operations_array[@]}"; do
        Opts.Apps.All.${operations_array[$index]}.IsSet && QPKGs.Ok${operations_array[$index]}.IsNone && ShowAsDone "no QPKGs were ${messages_array[$index]}"
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

QPKG.Download()
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
        MarkOpAsSkipped hide "$PACKAGE_NAME" download
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
                QPKGs.OkDownload.Add "$PACKAGE_NAME"
            else
                DebugAsError "downloaded package $(FormatAsFileName "$LOCAL_PATHFILE") checksum incorrect"
                QPKGs.ErDownload.Add "$PACKAGE_NAME"
                result_code=1
            fi
        else
            DebugAsError "download failed $(FormatAsFileName "$LOCAL_PATHFILE") $(FormatAsExitcode $result_code)"
            QPKGs.ErDownload.Add "$PACKAGE_NAME"
            result_code=1    # remap to 1 (last time I checked, 'curl' had 92 return codes)
        fi
    fi

    QPKGs.ToDownload.Remove "$PACKAGE_NAME"
    DebugFuncExit $result_code

    }

QPKG.Install()
    {

    # input:
    #   $1 = QPKG name

    # output:
    #   $? = 0  : successful
    #   $? = 1  : failed
    #   $? = 2  : skipped (not installed: already installed, or no package available for this NAS arch)

    Session.Error.IsSet && return
    QPKGs.SkipProcessing.IsSet && return
    DebugFuncEntry

    local -r PACKAGE_NAME=${1:?no package name supplied}
    local -i result_code=0

    if QPKGs.IsInstalled.Exist "$PACKAGE_NAME"; then
        MarkOpAsSkipped show "$PACKAGE_NAME" install "it's already installed - use 'reinstall' instead"
        MarkStateAsInstalled "$PACKAGE_NAME"
        DebugFuncExit 2; return
    fi

    if ! QPKG.URL "$PACKAGE_NAME" &>/dev/null; then
        MarkOpAsSkipped show "$PACKAGE_NAME" install 'this NAS has an unsupported arch'
        DebugFuncExit 2; return
    fi

    if ! QPKG.MinRAM "$PACKAGE_NAME" &>/dev/null; then
        MarkOpAsSkipped show "$PACKAGE_NAME" install 'this NAS has insufficient RAM'
        DebugFuncExit 2; return
    fi

    local local_pathfile=$(QPKG.PathFilename "$PACKAGE_NAME")

    if [[ ${local_pathfile##*.} = zip ]]; then
        $UNZIP_CMD -nq "$local_pathfile" -d "$QPKG_DL_PATH"
        local_pathfile=${local_pathfile%.*}
    fi

    if [[ $PACKAGE_NAME = Entware ]] && ! QPKGs.IsInstalled.Exist Entware && QPKGs.ToInstall.Exist Entware; then
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
        MarkOpAsDone "$PACKAGE_NAME" install
        MarkStateAsInstalled "$PACKAGE_NAME"

        if QPKGs.IsStarted.Exist "$PACKAGE_NAME"; then
            MarkStateAsStarted "$PACKAGE_NAME"
        else
            MarkStateAsStopped "$PACKAGE_NAME"
        fi

        if [[ $PACKAGE_NAME = Entware ]]; then
            ModPathToEntware
            PatchEntwareService

            if QPKGs.OkInstall.Exist Entware; then
                # copy all files from original [/opt] into new [/opt]
                if [[ -L ${OPT_PATH:-} && -d ${OPT_BACKUP_PATH:-} ]]; then
                    ShowAsProc "restoring original /opt" >&2
                    cp --recursive "$OPT_BACKUP_PATH"/* --target-directory "$OPT_PATH" && rm -rf "$OPT_BACKUP_PATH"
                    DebugAsDone 'complete'
                fi

                # add extra package(s) needed immediately
                DebugAsProc 'installing standalone IPKGs'
                RunAndLog "/opt/bin/opkg install$(Opts.IgnoreFreeSpace.IsSet && Opts.IgnoreFreeSpace.Text) --force-overwrite $MANAGER_BASE_IPKGS_ADD --cache $IPKG_CACHE_PATH --tmp-dir $IPKG_DL_PATH" "$LOGS_PATH/ipkgs.extra.$INSTALL_LOG_FILE" log:failure-only
                DebugAsDone 'installed standalone IPKGs'

                PIPs.Install.Set
            fi
        fi

        result_code=0    # remap to zero (0 or 10 from a QPKG install/reinstall/upgrade is OK)
    else
        DebugAsError "installation failed $(FormatAsFileName "$TARGET_FILE") $(FormatAsExitcode $result_code)"
        MarkOpAsError "$PACKAGE_NAME" install
        result_code=1    # remap to 1
    fi

    QPKG.ClearAppCenterNotifier "$PACKAGE_NAME"
    DebugFuncExit $result_code

    }

QPKG.Reinstall()
    {

    # input:
    #   $1 = QPKG name

    # output:
    #   $? = 0  : successful
    #   $? = 1  : failed
    #   $? = 2  : skipped (not reinstalled: not already installed, or no package available for this NAS arch)

    Session.Error.IsSet && return
    QPKGs.SkipProcessing.IsSet && return
    DebugFuncEntry

    local -r PACKAGE_NAME=${1:?no package name supplied}
    local -i result_code=0

    if ! QPKGs.IsInstalled.Exist "$PACKAGE_NAME"; then
        MarkOpAsSkipped show "$PACKAGE_NAME" reinstall "it's not installed - use 'install' instead"
        MarkStateAsNotInstalled "$PACKAGE_NAME"
        DebugFuncExit 2; return
    fi

    if ! QPKG.URL "$PACKAGE_NAME" &>/dev/null; then
        MarkOpAsSkipped show "$PACKAGE_NAME" reinstall 'this NAS has an unsupported arch'
        DebugFuncExit 2; return
    fi

    if ! QPKG.MinRAM "$PACKAGE_NAME" &>/dev/null; then
        MarkOpAsSkipped show "$PACKAGE_NAME" reinstall 'this NAS has insufficient RAM'
        DebugFuncExit 2; return
    fi

    local local_pathfile=$(QPKG.PathFilename "$PACKAGE_NAME")

    if [[ ${local_pathfile##*.} = zip ]]; then
        $UNZIP_CMD -nq "$local_pathfile" -d "$QPKG_DL_PATH"
        local_pathfile=${local_pathfile%.*}
    fi

    local -r TARGET_FILE=$($BASENAME_CMD "$local_pathfile")
    local -r LOG_PATHFILE=$LOGS_PATH/$TARGET_FILE.$REINSTALL_LOG_FILE

    DebugAsProc "reinstalling $(FormatAsPackageName "$PACKAGE_NAME")"
    RunAndLog "$SH_CMD $local_pathfile" "$LOG_PATHFILE" log:failure-only 10
    result_code=$?

    if [[ $result_code -eq 0 || $result_code -eq 10 ]]; then
        DebugAsDone "reinstalled $(FormatAsPackageName "$PACKAGE_NAME")"
        MarkOpAsDone "$PACKAGE_NAME" reinstall
        QPKG.StoreServiceStatus "$PACKAGE_NAME"

        if QPKGs.IsStarted.Exist "$PACKAGE_NAME"; then
            MarkStateAsStarted "$PACKAGE_NAME"
        else
            MarkStateAsStopped "$PACKAGE_NAME"
        fi

        result_code=0    # remap to zero (0 or 10 from a QPKG install/reinstall/upgrade is OK)
    else
        ShowAsEror "reinstallation failed $(FormatAsFileName "$TARGET_FILE") $(FormatAsExitcode $result_code)"
        MarkOpAsError "$PACKAGE_NAME" reinstall
        result_code=1    # remap to 1
    fi

    QPKG.ClearAppCenterNotifier "$PACKAGE_NAME"
    DebugFuncExit $result_code

    }

QPKG.Upgrade()
    {

    # Upgrades the QPKG named in $1

    # input:
    #   $1 = QPKG name

    # output:
    #   $? = 0  : successful
    #   $? = 1  : failed
    #   $? = 2  : skipped (not upgraded: not installed, or no package available for this NAS arch)

    Session.Error.IsSet && return
    QPKGs.SkipProcessing.IsSet && return
    DebugFuncEntry

    local -r PACKAGE_NAME=${1:?no package name supplied}
    local -i result_code=0

    if ! QPKGs.IsInstalled.Exist "$PACKAGE_NAME"; then
        MarkOpAsSkipped show "$PACKAGE_NAME" upgrade "it's not installed - use 'install' instead"
        MarkStateAsNotInstalled "$PACKAGE_NAME"
        DebugFuncExit 2; return
    fi

    if ! QPKG.URL "$PACKAGE_NAME" &>/dev/null; then
        MarkOpAsSkipped show "$PACKAGE_NAME" upgrade 'this NAS has an unsupported arch'
        DebugFuncExit 2; return
    fi

    if ! QPKG.MinRAM "$PACKAGE_NAME" &>/dev/null; then
        MarkOpAsSkipped show "$PACKAGE_NAME" upgrade 'this NAS has insufficient RAM'
        DebugFuncExit 2; return
    fi

    if ! QPKGs.IsUpgradable.Exist "$PACKAGE_NAME"; then
        MarkOpAsSkipped show "$PACKAGE_NAME" upgrade 'no new package is available'
        DebugFuncExit 2; return
    fi

    local previous_version=null
    local current_version=null
    local local_pathfile=$(QPKG.PathFilename "$PACKAGE_NAME")

    if [[ ${local_pathfile##*.} = zip ]]; then
        $UNZIP_CMD -nq "$local_pathfile" -d "$QPKG_DL_PATH"
        local_pathfile=${local_pathfile%.*}
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
        QPKGs.IsUpgradable.Remove "$PACKAGE_NAME"
        MarkOpAsDone "$PACKAGE_NAME" upgrade

        if QPKGs.IsStarted.Exist "$PACKAGE_NAME"; then
            MarkStateAsStarted "$PACKAGE_NAME"
        else
            MarkStateAsStopped "$PACKAGE_NAME"
        fi

        result_code=0    # remap to zero (0 or 10 from a QPKG install/reinstall/upgrade is OK)
    else
        ShowAsEror "upgrade failed $(FormatAsFileName "$TARGET_FILE") $(FormatAsExitcode $result_code)"
        MarkOpAsError "$PACKAGE_NAME" upgrade
        result_code=1    # remap to 1
    fi

    QPKG.ClearAppCenterNotifier "$PACKAGE_NAME"
    DebugFuncExit $result_code

    }

QPKG.Uninstall()
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

    if QPKGs.IsNotInstalled.Exist "$PACKAGE_NAME"; then
        MarkOpAsSkipped show "$PACKAGE_NAME" uninstall "it's not installed"
        MarkStateAsNotInstalled "$PACKAGE_NAME"
        QPKGs.IsStarted.Remove "$PACKAGE_NAME"
        DebugFuncExit 2; return
    fi

    if [[ $PACKAGE_NAME = "$PROJECT_NAME" ]]; then
        MarkOpAsSkipped show "$PACKAGE_NAME" uninstall "it's needed here"
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
            MarkOpAsDone "$PACKAGE_NAME" uninstall
            MarkStateAsNotInstalled "$PACKAGE_NAME"
            QPKGs.IsStarted.Remove "$PACKAGE_NAME"
        else
            DebugAsError "unable to uninstall $(FormatAsPackageName "$PACKAGE_NAME") $(FormatAsExitcode $result_code)"
            MarkOpAsError "$PACKAGE_NAME" uninstall
            result_code=1    # remap to 1
        fi
    fi

    QPKG.ClearAppCenterNotifier "$PACKAGE_NAME"
    DebugFuncExit $result_code

    }

QPKG.Restart()
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

    QPKG.ClearServiceStatus "$PACKAGE_NAME"

    if QPKGs.IsNotInstalled.Exist "$PACKAGE_NAME"; then
        MarkOpAsSkipped show "$PACKAGE_NAME" restart "it's not installed"
        MarkStateAsNotInstalled "$PACKAGE_NAME"
        DebugFuncExit 2; return
    fi

    if [[ $PACKAGE_NAME = "$PROJECT_NAME" ]]; then
        MarkOpAsSkipped show "$PACKAGE_NAME" restart "it's needed here"
        DebugFuncExit 2; return
    fi

    local -r LOG_PATHFILE=$LOGS_PATH/$PACKAGE_NAME.$RESTART_LOG_FILE

    QPKG.Enable "$PACKAGE_NAME"
    result_code=$?

    if [[ $result_code -eq 0 ]]; then
        DebugAsProc "restarting $(FormatAsPackageName "$PACKAGE_NAME")"
        RunAndLog "/sbin/qpkg_service restart $PACKAGE_NAME" "$LOG_PATHFILE" log:failure-only
        result_code=$?
    fi

    if [[ $result_code -eq 0 ]]; then
        DebugAsDone "restarted $(FormatAsPackageName "$PACKAGE_NAME")"
        QPKG.StoreServiceStatus "$PACKAGE_NAME"
        MarkOpAsDone "$PACKAGE_NAME" restart
    else
        ShowAsWarn "unable to restart $(FormatAsPackageName "$PACKAGE_NAME") $(FormatAsExitcode $result_code)"
        MarkOpAsError "$PACKAGE_NAME" restart
        result_code=1    # remap to 1
    fi

    QPKG.ClearAppCenterNotifier "$PACKAGE_NAME"
    DebugFuncExit $result_code

    }

QPKG.Start()
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

    if QPKGs.IsNotInstalled.Exist "$PACKAGE_NAME"; then
        MarkOpAsSkipped show "$PACKAGE_NAME" start "it's not installed"
        DebugFuncExit 2; return
    fi

    if QPKGs.IsStarted.Exist "$PACKAGE_NAME"; then
        MarkOpAsSkipped show "$PACKAGE_NAME" start "it's already started"
        DebugFuncExit 2; return
    fi

    local -r LOG_PATHFILE=$LOGS_PATH/$PACKAGE_NAME.$START_LOG_FILE

    QPKG.Enable "$PACKAGE_NAME"
    result_code=$?

    if [[ $result_code -eq 0 ]]; then
        DebugAsProc "starting $(FormatAsPackageName "$PACKAGE_NAME")"
        RunAndLog "/sbin/qpkg_service start $PACKAGE_NAME" "$LOG_PATHFILE" log:failure-only
        result_code=$?
    fi

    if [[ $result_code -eq 0 ]]; then
        DebugAsDone "started $(FormatAsPackageName "$PACKAGE_NAME")"
        QPKG.StoreServiceStatus "$PACKAGE_NAME"
        MarkOpAsDone "$PACKAGE_NAME" start
        MarkStateAsStarted "$PACKAGE_NAME"
        [[ $PACKAGE_NAME = Entware ]] && ModPathToEntware
    else
        ShowAsWarn "unable to start $(FormatAsPackageName "$PACKAGE_NAME") $(FormatAsExitcode $result_code)"
        MarkOpAsError "$PACKAGE_NAME" start
        result_code=1    # remap to 1
    fi

    QPKG.ClearAppCenterNotifier "$PACKAGE_NAME"
    DebugFuncExit $result_code

    }

QPKG.Stop()
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

    if QPKGs.IsNotInstalled.Exist "$PACKAGE_NAME"; then
        MarkOpAsSkipped show "$PACKAGE_NAME" stop "it's not installed"
        DebugFuncExit 2; return
    fi

    if QPKGs.IsStopped.Exist "$PACKAGE_NAME"; then
        MarkOpAsSkipped show "$PACKAGE_NAME" stop "it's already stopped"
        DebugFuncExit 2; return
    fi

    if [[ $PACKAGE_NAME = "$PROJECT_NAME" ]]; then
        MarkOpAsSkipped show "$PACKAGE_NAME" stop "it's needed here"
        DebugFuncExit 2; return
    fi

    local -r LOG_PATHFILE=$LOGS_PATH/$PACKAGE_NAME.$STOP_LOG_FILE

    DebugAsProc "stopping $(FormatAsPackageName "$PACKAGE_NAME")"
    RunAndLog "/sbin/qpkg_service stop $PACKAGE_NAME" "$LOG_PATHFILE" log:failure-only
    result_code=$?

    if [[ $result_code -eq 0 ]]; then
        QPKG.Disable "$PACKAGE_NAME"
        result_code=$?
    fi

    if [[ $result_code -eq 0 ]]; then
        DebugAsDone "stopped $(FormatAsPackageName "$PACKAGE_NAME")"
        QPKG.StoreServiceStatus "$PACKAGE_NAME"
        MarkOpAsDone "$PACKAGE_NAME" stop
        MarkStateAsStopped "$PACKAGE_NAME"
    else
        ShowAsWarn "unable to stop $(FormatAsPackageName "$PACKAGE_NAME") $(FormatAsExitcode $result_code)"
        MarkOpAsError "$PACKAGE_NAME" stop
        result_code=1    # remap to 1
    fi

    QPKG.ClearAppCenterNotifier "$PACKAGE_NAME"
    DebugFuncExit $result_code

    }

QPKG.Enable()
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

QPKG.Disable()
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

QPKG.Backup()
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
        MarkOpAsSkipped show "$PACKAGE_NAME" backup "it does not support backup"
        DebugFuncExit 2; return
    fi

    if QPKGs.IsNotInstalled.Exist "$PACKAGE_NAME"; then
        MarkOpAsSkipped show "$PACKAGE_NAME" backup "it's not installed"
        DebugFuncExit 2; return
    fi

    local -r PACKAGE_INIT_PATHFILE=$(QPKG.ServicePathFile "$PACKAGE_NAME")
    local -r LOG_PATHFILE=$LOGS_PATH/$PACKAGE_NAME.$BACKUP_LOG_FILE

    DebugAsProc "backing-up $(FormatAsPackageName "$PACKAGE_NAME") configuration"
    RunAndLog "$SH_CMD $PACKAGE_INIT_PATHFILE backup" "$LOG_PATHFILE" log:failure-only
    result_code=$?

    if [[ $result_code -eq 0 ]]; then
        DebugAsDone "backed-up $(FormatAsPackageName "$PACKAGE_NAME") configuration"
        MarkOpAsDone "$PACKAGE_NAME" backup
        QPKG.StoreServiceStatus "$PACKAGE_NAME"
        QPKGs.IsNotBackedUp.Remove "$PACKAGE_NAME"
        QPKGs.IsBackedUp.Add "$PACKAGE_NAME"
    else
        DebugAsWarn "unable to backup $(FormatAsPackageName "$PACKAGE_NAME") configuration $(FormatAsExitcode $result_code)"
        MarkOpAsError "$PACKAGE_NAME" backup
        result_code=1    # remap to 1
    fi

    DebugFuncExit $result_code

    }

QPKG.Restore()
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
        MarkOpAsSkipped show "$PACKAGE_NAME" restore "it does not support backup"
        DebugFuncExit 2; return
    fi

    if QPKGs.IsNotInstalled.Exist "$PACKAGE_NAME"; then
        MarkOpAsSkipped show "$PACKAGE_NAME" restore "it's not installed"
        DebugFuncExit 2; return
    fi

    local -r PACKAGE_INIT_PATHFILE=$(QPKG.ServicePathFile "$PACKAGE_NAME")
    local -r LOG_PATHFILE=$LOGS_PATH/$PACKAGE_NAME.$RESTORE_LOG_FILE

    DebugAsProc "restoring $(FormatAsPackageName "$PACKAGE_NAME") configuration"
    RunAndLog "$SH_CMD $PACKAGE_INIT_PATHFILE restore" "$LOG_PATHFILE" log:failure-only
    result_code=$?

    if [[ $result_code -eq 0 ]]; then
        DebugAsDone "restored $(FormatAsPackageName "$PACKAGE_NAME") configuration"
        MarkOpAsDone "$PACKAGE_NAME" restore
        QPKG.StoreServiceStatus "$PACKAGE_NAME"
    else
        DebugAsWarn "unable to restore $(FormatAsPackageName "$PACKAGE_NAME") configuration $(FormatAsExitcode $result_code)"
        MarkOpAsError "$PACKAGE_NAME" restore
    fi

    DebugFuncExit $result_code

    }

QPKG.ClearAppCenterNotifier()
    {

    # $1 = QPKG name to clear from notifier list

    local -r PACKAGE_NAME=${1:?no package name supplied}

    # KLUDGE: 'clean' QTS 4.5.1 App Center notifier status
    [[ -e /sbin/qpkg_cli ]] && /sbin/qpkg_cli --clean "$PACKAGE_NAME" &>/dev/null

    QPKGs.IsNotInstalled.Exist "$PACKAGE_NAME" && return 0

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
            ShowAsEror "$(FormatAsPackageName "$PACKAGE_NAME") service operation failed.$([[ -e /var/log/$PACKAGE_NAME.log ]] && echo " Check $(FormatAsFileName "/var/log/$PACKAGE_NAME.log") for more information")"
            ;;
        *)
            DebugAsWarn "$(FormatAsPackageName "$PACKAGE_NAME") service status is incorrect"
            ;;
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
    #   $? = 0 if found, 1 if not

    local output=''

    if output=$(/sbin/getcfg "${1:-}" Shell -f /etc/config/qpkg.conf); then
        echo "$output"
        return 0
    fi

    echo 'unknown'
    return 1

    }

QPKG.Local.Version()
    {

    # Returns the version number of an installed QPKG.

    # input:
    #   $1 = QPKG name

    # output:
    #   stdout = package version
    #   $? = 0 if found, 1 if not

    local output=''

    if output=$(/sbin/getcfg "${1:-}" Version -f /etc/config/qpkg.conf); then
        echo "$output"
        return 0
    fi

    echo 'unknown'
    return 1

    }

QPKG.InstallPath()
    {

    # input:
    #   $1 = QPKG name

    # output:
    #   stdout = QPKG installed path
    #   $? = 0 if found, 1 if not

    local output=''

    if output=$(/sbin/getcfg "$1" Install_Path -f /etc/config/qpkg.conf); then
        echo "$output"
        return 0
    fi

    echo 'unknown'
    return 1

    }

QPKG.IsSupportBackup()
    {

    # does this QPKG support 'backup' and 'restore' operations?

    # input:
    #   $1 = QPKG name

    # output:
    #   $? = 0 if true, 1 if false

    local package_index=0

    for package_index in "${!MANAGER_QPKG_NAME[@]}"; do
        if [[ ${MANAGER_QPKG_NAME[$package_index]} = "${1:?no package name supplied}" ]]; then
            if ${MANAGER_QPKG_BACKUP_SUPPORTED[$package_index]}; then
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

    local package_index=0

    for package_index in "${!MANAGER_QPKG_NAME[@]}"; do
        if [[ ${MANAGER_QPKG_NAME[$package_index]} = "${1:?no package name supplied}" ]]; then
            if ${MANAGER_QPKG_UPDATE_ON_RESTART[$package_index]}; then
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
    local package_index=0
    local -i index=0
    local result_code=1

    for package_index in "${!MANAGER_QPKG_NAME[@]}"; do
        abbs=(${MANAGER_QPKG_ABBRVS[$package_index]})

        for index in "${!abbs[@]}"; do
            if [[ ${abbs[$index]} = "$1" ]]; then
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

QPKG.MinRAM()
    {

    # input:
    #   $1 = QPKG name

    # output:
    #   stdout = the minimum kB of installed RAM required by this QPKG
    #   $? = 0 if successful, 1 if failed

    local -i index=0

    for index in "${!MANAGER_QPKG_NAME[@]}"; do
        if [[ $1 = "${MANAGER_QPKG_NAME[$index]}" ]] && [[ ${MANAGER_QPKG_MINRAM[$index]} = any || $INSTALLED_RAM_KB -ge ${MANAGER_QPKG_MINRAM[$index]} ]]; then
            echo "${MANAGER_QPKG_MINRAM[$index]}"
            return 0
        fi
    done

    return 1

    }

QPKG.Standalones()
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

QPKG.Dependents()
    {

    # input:
    #   $1 = standalone QPKG name to return dependents for

    # output:
    #   $? = 0 if successful, 1 if failed

    local -i index=0
    local -a acc=()

    if QPKGs.IsStandalone.Exist "$1"; then
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

QPKG.IsInstallable()
    {

    # input:
    #   $1 = package name to check

    # output:
    #   $? = 0 (true) or 1 (false)

    [[ ${#MANAGER_QPKG_NAME[@]} -eq 0 || ${#MANAGER_QPKG_ABBRVS[@]} -eq 0 ]] && return 1

    local -r PACKAGE_NAME=${1:?no package name supplied}
    local result_code=1
    local index=0

    for index in "${!MANAGER_QPKG_NAME[@]}"; do
        [[ ${MANAGER_QPKG_NAME[$index]} = "$PACKAGE_NAME" ]] || continue
        [[ -n ${MANAGER_QPKG_ABBRVS[$index]} ]] || continue
        QPKG.IsInstalled "$PACKAGE_NAME" && break
        QPKG.MinRAM "$1" &>/dev/null || continue

        if [[ ${MANAGER_QPKG_ARCH[$index]} = 'all' || ${MANAGER_QPKG_ARCH[$index]} = "$NAS_QPKG_ARCH" ]]; then
            result_code=0
            break
        fi
    done

    return $result_code

    }

QPKG.IsInstalled()
    {

    # input:
    #   $1 = package name to check

    # output:
    #   $? = 0 (true) or 1 (false)

    $GREP_CMD -q "^\[${1:?no package name supplied}\]" /etc/config/qpkg.conf

    }

QPKG.IsNotInstalled()
    {

    # input:
    #   $1 = package name to check

    # output:
    #   $? = 0 (true) or 1 (false)

    ! QPKG.IsInstalled "${1:?no package name supplied}"

    }

QPKG.IsStarted()
    {

    # input:
    #   $1 = package name to check

    # output:
    #   $? = 0 (true) or 1 (false)

    [[ $(/sbin/getcfg "${1:?no package name supplied}" Enable -u -f /etc/config/qpkg.conf) = 'TRUE' ]]

    }

QPKG.IsStopped()
    {

    # input:
    #   $1 = package name to check

    # output:
    #   $? = 0 (true) or 1 (false)

    [[ $(/sbin/getcfg "${1:?no package name supplied}" Enable -u -f /etc/config/qpkg.conf) = 'FALSE' ]]

    }

QPKG.IsStarting()
    {

    # input:
    #   $1 = package name to check

    # output:
    #   $? = 0 (true) or 1 (false)

    [[ $(QPKG.GetServiceStatus "$1") = starting ]]

    }

QPKG.IsStopping()
    {

    # input:
    #   $1 = package name to check

    # output:
    #   $? = 0 (true) or 1 (false)

    [[ $(QPKG.GetServiceStatus "$1") = stopping ]]

    }

QPKG.IsRestarting()
    {

    # input:
    #   $1 = package name to check

    # output:
    #   $? = 0 (true) or 1 (false)

    [[ $(QPKG.GetServiceStatus "$1") = restarting ]]

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

    if Session.LineSpace.IsNot && Session.Display.Clean.IsNot; then
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

DebugHardwareWarning()
    {

    DebugWarningTabulated "$(FormatAsHardware)" "${1:-}" "${2:-}"

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

    if [[ -n $1 && $1 != all ]]; then
        local tier=" $1"
    else
        local tier=''
    fi

    local -r PACKAGE_TYPE=${2:?empty}
    local -i pass_count=${3:-0}
    local -i fail_count=${4:-0}
    local -i total_count=${5:-0}
    local -r ACTION_PRESENT=${6:?empty}
    local -r DURATION=${7:-}

    local tweaked_passes=$((pass_count+1))              # never show zero (e.g. 0/8)
    local tweaked_total=$((total_count-fail_count))     # auto-adjust upper limit to account for failures

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

    if [[ -n $1 && $1 != all ]]; then
        local tier=" $1"
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
    local this_length=0
    local blanking_length=0

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

    [[ $(type -t Session.Debug.ToFile.Init) = function ]] && Session.Debug.ToFile.IsNot && return
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

    _placeholder_size_=_obj_${safe_function_name}_size_
    _placeholder_array_=_obj_${safe_function_name}_array_
    _placeholder_array_index_=_obj_${safe_function_name}_array_index_

echo $public_function_name'.Add()
    {
    local array=(${1})
    [[ ${#array[@]} -eq 0 ]] && return
    local item='\'\''
    for item in "${array[@]:-}"; do
        if [[ " ${'$_placeholder_array_'[*]+"${'$_placeholder_array_'[@]}"} " != *"$item"* ]]; then
            '$_placeholder_array_'+=("$item")
        fi
    done
    }
'$public_function_name'.Array()
    {
    echo -n "${'$_placeholder_array_'[@]+"${'$_placeholder_array_'[@]}"}"
    }
'$public_function_name'.Count()
    {
    echo "${#'$_placeholder_array_'[@]}"
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
    [[ $index -gt ${#'$_placeholder_array_'[@]} ]] && index=${#'$_placeholder_array_'[@]}
    echo -n "${'$_placeholder_array_'[((index-1))]}"
    }
'$public_function_name'.Init()
    {
    '$_placeholder_size_'=0
    '$_placeholder_array_'=()
    '$_placeholder_array_index_'=1
    }
'$public_function_name'.IsAny()
    {
    [[ ${#'$_placeholder_array_'[@]} -gt 0 ]]
    }
'$public_function_name'.IsNone()
    {
    [[ ${#'$_placeholder_array_'[@]} -eq 0 ]]
    }
'$public_function_name'.List()
    {
    echo -n "${'$_placeholder_array_'[*]+"${'$_placeholder_array_'[@]}"}"
    }
'$public_function_name'.ListCSV()
    {
    echo -n "${'$_placeholder_array_'[*]+"${'$_placeholder_array_'[@]}"}" | tr '\' \'' '\',\''
    }
'$public_function_name'.Remove()
    {
    local argument_array=(${1})
    local temp_array=()
    local argument='\'\''
    local item='\'\''
    local matched=false
    for item in "${'$_placeholder_array_'[@]+"${'$_placeholder_array_'[@]}"}"; do
        matched=false
        for argument in "${argument_array[@]+"${argument_array[@]}"}"; do
            if [[ $argument = $item ]]; then
                matched=true; break
            fi
        done
        [[ $matched = false ]] && temp_array+=("$item")
    done
    '$_placeholder_array_'=("${temp_array[@]+"${temp_array[@]}"}")
    [[ -z ${'$_placeholder_array_'[*]+"${'$_placeholder_array_'[@]}"} ]] && '$_placeholder_array_'=()
    }
'$public_function_name'.Size()
    {
    if [[ -n ${1:-} && ${1:-} = "=" ]]; then
        '$_placeholder_size_'=$2
    else
        echo -n $'$_placeholder_size_'
    fi
    }
'$public_function_name'.Init
' >> "$COMPILED_OBJECTS_PATHFILE"

    return 0

    }

AddFlagObj()
    {

    # $1 = object name to create

    local public_function_name=${1:?no object name supplied}
    local safe_function_name="$(tr 'A-Z' 'a-z' <<< "${public_function_name//[.-]/_}")"

    _placeholder_text_=_obj_${safe_function_name}_text_
    _placeholder_flag_=_obj_${safe_function_name}_flag_
    _placeholder_log_changes_flag_=_obj_${safe_function_name}_changes_flag_
    _placeholder_enable_=_obj_${safe_function_name}_enable_

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
    '$_placeholder_text_'='\'\''
    '$_placeholder_flag_'=false
    '$_placeholder_log_changes_flag_'=true
    '$_placeholder_enable_'=false
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
'$public_function_name'.Set()
    {
    [[ $'$_placeholder_flag_' = '\'true\'' ]] && return
    '$_placeholder_flag_'=true
    [[ $'$_placeholder_log_changes_flag_' = '\'true\'' ]] && DebugVar '$_placeholder_flag_'
    }
'$public_function_name'.Text()
    {
    if [[ -n ${1:-} && $1 = "=" ]]; then
        '$_placeholder_text_'=$2
    else
        echo -n "$'$_placeholder_text_'"
    fi
    }
'$public_function_name'.Init
' >> "$COMPILED_OBJECTS_PATHFILE"

    return 0

    }

CheckLocalObjects()
    {

    [[ -e $COMPILED_OBJECTS_PATHFILE ]] && ! FileMatchesMD5 "$COMPILED_OBJECTS_PATHFILE" "$(CompileObjects hash)" && rm -f "$COMPILED_OBJECTS_PATHFILE"

    }

CheckRemoteObjects()
    {

    [[ ! -e $COMPILED_OBJECTS_PATHFILE ]] && ! $CURL_CMD${curl_insecure_arg:-} --silent --fail "$COMPILED_OBJECTS_URL" > "$COMPILED_OBJECTS_PATHFILE" && [[ ! -s $COMPILED_OBJECTS_PATHFILE ]] && rm -f "$COMPILED_OBJECTS_PATHFILE"

    }

CompileObjects()
    {

    # builds a new [compiled.objects] file in the local work path

    # $1 = 'hash' (optional) return the internal checksum

    local -r COMPILED_OBJECTS_HASH=f94c5346e4a1bc45377d5361a86e71e1
    local array_name=''

    if [[ ${1:-} = hash ]]; then
        echo "$COMPILED_OBJECTS_HASH"
        return
    fi

    CheckLocalObjects
    CheckRemoteObjects
    CheckLocalObjects

    if [[ ! -e $COMPILED_OBJECTS_PATHFILE ]]; then
        ShowAsProc 'compiling objects' >&2

        # session flags
        for array_name in Display.Clean LineSpace ShowBackupLocation SuggestIssue Summary; do
            AddFlagObj Session.${array_name}
        done

        for array_name in ToArchive ToFile ToScreen; do
            AddFlagObj Session.Debug.${array_name}
        done

        AddFlagObj QPKGs.States.Built
        AddFlagObj QPKGs.SkipProcessing
        AddFlagObj IPKGs.Upgrade
        AddFlagObj IPKGs.Install
        AddFlagObj PIPs.Install

        # user option flags
        for array_name in Dependencies.Check IgnoreFreeSpace Versions.View; do
            AddFlagObj Opts.${array_name}
        done

        for array_name in Abbreviations Actions ActionsAll Backups Basic Options Packages Problems Status Tips; do
            AddFlagObj Opts.Help.${array_name}
        done

        for array_name in All Last Tail; do
            AddFlagObj Opts.Log.${array_name}.Paste
            AddFlagObj Opts.Log.${array_name}.View
        done

        for array_name in Backup Install Rebuild Reinstall Restart Restore Start Stop Uninstall Upgrade; do
            AddFlagObj Opts.Apps.All.${array_name}
            AddFlagObj Opts.Apps.Standalone.${array_name}
            AddFlagObj Opts.Apps.Dependent.${array_name}
        done

        for array_name in All Dependent Installable Installed NotInstalled Standalone Started Stopped Upgradable; do
            AddFlagObj Opts.Apps.List.${array_name}
        done

        # lists
        AddListObj Args.Unknown
        AddListObj QPKGs.Names

        for array_name in BackedUp Dependent Installed Installable Missing Names Standalone Starting Started Stopping Stopped SupportBackup SupportUpdateOnRestart Restarting Upgradable; do
            AddListObj QPKGs.Is${array_name}
            AddListObj QPKGs.IsNot${array_name}
        done

        for array_name in Backup Download Install Rebuild Reinstall Restart Restore Start Stop Uninstall Upgrade; do
            AddListObj QPKGs.To${array_name}      # to operate on
            AddListObj QPKGs.Ok${array_name}      # operation was tried and succeeded
            AddListObj QPKGs.Er${array_name}      # operation was tried but failed
            AddListObj QPKGs.Sk${array_name}      # operation was skipped
        done

        for array_name in Download Install Uninstall Upgrade; do
            AddListObj IPKGs.To${array_name}
        done
    fi

    . "$COMPILED_OBJECTS_PATHFILE"

    return 0

    }

Session.Init || exit
Session.Validate
Tiers.Processor
Session.Results
Session.Error.IsNot
