#!/usr/bin/env bash
#
# sherpa.manager.sh - (C)opyright (C) 2017-2020 OneCD [one.cd.only@gmail.com]
#
# This is the management script for the sherpa mini-package-manager and is downloaded via the 'sherpa' QPKG.
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

Session.Init()
    {

    IsQNAP || return 1
    DebugFuncEntry
    readonly SCRIPT_STARTSECONDS=$(/bin/date +%s)

    readonly PROJECT_NAME=sherpa
    readonly MANAGER_SCRIPT_VERSION=201010

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

    # paths and files
    local -r LOADER_SCRIPT_FILE=$PROJECT_NAME.loader.sh
    readonly MANAGER_SCRIPT_FILE=$PROJECT_NAME.manager.sh

    Session.LockFile.Claim /var/run/$LOADER_SCRIPT_FILE.pid || return 1

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
    local -r PROJECT_REPO_URL=https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/master/QPKGs
    readonly APP_CENTER_CONFIG_PATHFILE=/etc/config/qpkg.conf
    local -r PROJECT_PATH=$($GETCFG_CMD $PROJECT_NAME Install_Path -f $APP_CENTER_CONFIG_PATHFILE)
    readonly DEBUG_LOG_PATHFILE=$PROJECT_PATH/$DEBUG_LOG_FILE
    readonly WORK_PATH=$PROJECT_PATH/cache
    readonly COMPILED_OBJECTS_URL=https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/master/compiled.objects
    readonly COMPILED_OBJECTS_PATHFILE=$WORK_PATH/compiled.objects
    readonly EXTERNAL_PACKAGE_LIST_PATHFILE=$WORK_PATH/Packages
    readonly LOGS_PATH=$PROJECT_PATH/logs
    readonly SESSION_LAST_PATHFILE=$LOGS_PATH/session.last.log
    readonly SESSION_TAIL_PATHFILE=$LOGS_PATH/session.tail.log
    readonly QPKG_DL_PATH=$WORK_PATH/qpkgs
    readonly IPKG_DL_PATH=$WORK_PATH/ipkgs.downloads
    readonly IPKG_CACHE_PATH=$WORK_PATH/ipkgs
    readonly PIP_CACHE_PATH=$WORK_PATH/pips
    readonly COMPILED_OBJECTS_HASH=91507e9b27e29bcfdd83a00626b58e6b
    readonly DEBUG_LOG_DATAWIDTH=92

    if ! MakePath "$WORK_PATH" 'work'; then
        DebugFuncExit; return 1
    fi

    Objects.Compile

    # enable debug mode early if possible
    if [[ $USER_ARGS_RAW == *"debug"* || $USER_ARGS_RAW == *"verbose"* ]]; then
        Display
        Session.Debug.To.Screen.Set
    fi

    User.Opts.IgnoreFreeSpace.Text = ' --force-space'
    Session.Summary.Set
    Session.LineSpace.DontLogChanges

    if ! MakePath "$LOGS_PATH" 'logs'; then
        DebugFuncExit; return 1
    fi

    Session.Backup.Path = "$($GETCFG_CMD SHARE_DEF defVolMP -f $DEFAULT_SHARES_PATHFILE)/.qpkg_config_backup"

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

    readonly NAS_FIRMWARE=$($GETCFG_CMD System Version -f $ULINUX_PATHFILE)
    readonly PACKAGE_VERSION=$(QPKG.InstalledVersion "$PROJECT_NAME")
    readonly NAS_BUILD=$($GETCFG_CMD System 'Build Number' -f $ULINUX_PATHFILE)
    readonly INSTALLED_RAM_KB=$($GREP_CMD MemTotal /proc/meminfo | $CUT_CMD -f2 -d':' | $SED_CMD 's|kB||;s| ||g')
    readonly MIN_RAM_KB=1048576
    readonly LOG_TAIL_LINES=2000    # a full download and install of everything generates a session around 1600 lines
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
        SHERPA_QPKG_INDEPS=()       # require these QPKGs to be installed
        SHERPA_QPKG_IPKGS_ADD=()    # require these IPKGs to be installed
        SHERPA_QPKG_IPKGS_REMOVE=() # require these IPKGs to be uninstalled

    SHERPA_QPKG_NAME+=(Entware)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=($PROJECT_REPO_URL/Entware/Entware_1.02std.qpkg)
        SHERPA_QPKG_MD5+=(dbc82469933ac3049c06d4c8a023bbb9)
        SHERPA_QPKG_ABBRVS+=('ew ent opkg entware')
        SHERPA_QPKG_INDEPS+=('')
        SHERPA_QPKG_IPKGS_ADD+=('')
        SHERPA_QPKG_IPKGS_REMOVE+=('')

    SHERPA_QPKG_NAME+=(Par2)
        SHERPA_QPKG_ARCH+=(x86)
        SHERPA_QPKG_URL+=($PROJECT_REPO_URL/Par2/Par2_0.8.1.0_x86.qpkg)
        SHERPA_QPKG_MD5+=(996ffb92d774eb01968003debc171e91)
        SHERPA_QPKG_ABBRVS+=('par par2')        # these apply to all 'Par2' packages
        SHERPA_QPKG_INDEPS+=('')
        SHERPA_QPKG_IPKGS_ADD+=('')
        SHERPA_QPKG_IPKGS_REMOVE+=('par2cmdline')

    SHERPA_QPKG_NAME+=(Par2)
        SHERPA_QPKG_ARCH+=(x64)
        SHERPA_QPKG_URL+=($PROJECT_REPO_URL/Par2/Par2_0.8.1.0_x86_64.qpkg)
        SHERPA_QPKG_MD5+=(520472cc87d301704f975f6eb9948e38)
        SHERPA_QPKG_ABBRVS+=('')
        SHERPA_QPKG_INDEPS+=('')
        SHERPA_QPKG_IPKGS_ADD+=('')
        SHERPA_QPKG_IPKGS_REMOVE+=('par2cmdline')

    SHERPA_QPKG_NAME+=(Par2)
        SHERPA_QPKG_ARCH+=(x31)
        SHERPA_QPKG_URL+=($PROJECT_REPO_URL/Par2/Par2_0.8.1.0_arm-x31.qpkg)
        SHERPA_QPKG_MD5+=(ce8af2e009eb87733c3b855e41a94f8e)
        SHERPA_QPKG_ABBRVS+=('')
        SHERPA_QPKG_INDEPS+=('')
        SHERPA_QPKG_IPKGS_ADD+=('')
        SHERPA_QPKG_IPKGS_REMOVE+=('par2cmdline')

    SHERPA_QPKG_NAME+=(Par2)
        SHERPA_QPKG_ARCH+=(x41)
        SHERPA_QPKG_URL+=($PROJECT_REPO_URL/Par2/Par2_0.8.1.0_arm-x41.qpkg)
        SHERPA_QPKG_MD5+=(8516e45e704875cdd2cd2bb315c4e1e6)
        SHERPA_QPKG_ABBRVS+=('')
        SHERPA_QPKG_INDEPS+=('')
        SHERPA_QPKG_IPKGS_ADD+=('')
        SHERPA_QPKG_IPKGS_REMOVE+=('par2cmdline')

    SHERPA_QPKG_NAME+=(Par2)
        SHERPA_QPKG_ARCH+=(a64)
        SHERPA_QPKG_URL+=($PROJECT_REPO_URL/Par2/Par2_0.8.1.0_arm_64.qpkg)
        SHERPA_QPKG_MD5+=(4d8e99f97936a163e411aa8765595f7a)
        SHERPA_QPKG_ABBRVS+=('')
        SHERPA_QPKG_INDEPS+=('')
        SHERPA_QPKG_IPKGS_ADD+=('')
        SHERPA_QPKG_IPKGS_REMOVE+=('par2cmdline')

    SHERPA_QPKG_NAME+=(Par2)
        SHERPA_QPKG_ARCH+=(none)
        SHERPA_QPKG_URL+=('')
        SHERPA_QPKG_MD5+=('')
        SHERPA_QPKG_ABBRVS+=('')
        SHERPA_QPKG_INDEPS+=('')
        SHERPA_QPKG_IPKGS_ADD+=('par2cmdline')
        SHERPA_QPKG_IPKGS_REMOVE+=('')

    SHERPA_QPKG_NAME+=(SABnzbd)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=($PROJECT_REPO_URL/SABnzbd/build/SABnzbd_200922.qpkg)
        SHERPA_QPKG_MD5+=(23af2f4260163bcc9995d12fdef39c79)
        SHERPA_QPKG_ABBRVS+=('sb sb3 sab sab3 sabnzbd3 sabnzbd')
        SHERPA_QPKG_INDEPS+=('Entware Par2')
        SHERPA_QPKG_IPKGS_ADD+=('python3-asn1crypto python3-chardet python3-cryptography python3-pyopenssl unrar p7zip coreutils-nice ionice ffprobe')
        SHERPA_QPKG_IPKGS_REMOVE+=('')

    SHERPA_QPKG_NAME+=(nzbToMedia)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=($PROJECT_REPO_URL/nzbToMedia/build/nzbToMedia_200922.qpkg)
        SHERPA_QPKG_MD5+=(19acc62689c862b942bc52f417ce218e)
        SHERPA_QPKG_ABBRVS+=('nzb2 nzb2m nzbto nzbtom nzbtomedia')
        SHERPA_QPKG_INDEPS+=('Entware')
        SHERPA_QPKG_IPKGS_ADD+=('')
        SHERPA_QPKG_IPKGS_REMOVE+=('')

    SHERPA_QPKG_NAME+=(SickChill)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=($PROJECT_REPO_URL/SickChill/build/SickChill_200916.qpkg)
        SHERPA_QPKG_MD5+=(ade1d1c67355bf7d8e73543384cc1c61)
        SHERPA_QPKG_ABBRVS+=('sc sick sickc chill sickchill')
        SHERPA_QPKG_INDEPS+=('Entware')
        SHERPA_QPKG_IPKGS_ADD+=('')
        SHERPA_QPKG_IPKGS_REMOVE+=('')

    SHERPA_QPKG_NAME+=(LazyLibrarian)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=($PROJECT_REPO_URL/LazyLibrarian/build/LazyLibrarian_200922.qpkg)
        SHERPA_QPKG_MD5+=(21203435b4f3c2575a72aeae57992692)
        SHERPA_QPKG_ABBRVS+=('ll lazy lazylibrarian')
        SHERPA_QPKG_INDEPS+=('Entware')
        SHERPA_QPKG_IPKGS_ADD+=('python3-pyopenssl python3-requests')
        SHERPA_QPKG_IPKGS_REMOVE+=('')

    SHERPA_QPKG_NAME+=(OMedusa)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=($PROJECT_REPO_URL/OMedusa/build/OMedusa_200922.qpkg)
        SHERPA_QPKG_MD5+=(1cd38aacce12f6172a7ac42abd9e9809)
        SHERPA_QPKG_ABBRVS+=('om med omed medusa omedusa')
        SHERPA_QPKG_INDEPS+=('Entware')
        SHERPA_QPKG_IPKGS_ADD+=('mediainfo python3-pyopenssl')
        SHERPA_QPKG_IPKGS_REMOVE+=('')

    SHERPA_QPKG_NAME+=(OSickGear)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=($PROJECT_REPO_URL/OSickGear/build/OSickGear_200922.qpkg)
        SHERPA_QPKG_MD5+=(2635e0c2c51067bdd2c2b63d4d88193c)
        SHERPA_QPKG_ABBRVS+=('sg os osg sickg gear ogear osickg sickgear osickgear')
        SHERPA_QPKG_INDEPS+=('Entware')
        SHERPA_QPKG_IPKGS_ADD+=('')
        SHERPA_QPKG_IPKGS_REMOVE+=('')

    SHERPA_QPKG_NAME+=(Mylar3)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=($PROJECT_REPO_URL/Mylar3/build/Mylar3_200922.qpkg)
        SHERPA_QPKG_MD5+=(8412e8f92b1df4a3cdad9a56edd8b4e0)
        SHERPA_QPKG_ABBRVS+=('my omy myl mylar mylar3')
        SHERPA_QPKG_INDEPS+=('Entware')
        SHERPA_QPKG_IPKGS_ADD+=('python3-mako python3-pillow python3-pyopenssl python3-pytz python3-requests python3-six python3-urllib3')
        SHERPA_QPKG_IPKGS_REMOVE+=('')

    SHERPA_QPKG_NAME+=(NZBGet)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=($PROJECT_REPO_URL/NZBGet/build/NZBGet_200922.qpkg)
        SHERPA_QPKG_MD5+=(097f0893eeaf34a4c9f1414b97bcbb67)
        SHERPA_QPKG_ABBRVS+=('ng nzb nzbg nget nzbget')
        SHERPA_QPKG_INDEPS+=('Entware')
        SHERPA_QPKG_IPKGS_ADD+=('nzbget')
        SHERPA_QPKG_IPKGS_REMOVE+=('')

    SHERPA_QPKG_NAME+=(OTransmission)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=($PROJECT_REPO_URL/OTransmission/build/OTransmission_200922.qpkg)
        SHERPA_QPKG_MD5+=(ec9fd927ca8333bafc5984911d781406)
        SHERPA_QPKG_ABBRVS+=('ot tm tr trans otrans tmission transmission otransmission')
        SHERPA_QPKG_INDEPS+=('Entware')
        SHERPA_QPKG_IPKGS_ADD+=('transmission-web transmission-daemon-openssl jq')
        SHERPA_QPKG_IPKGS_REMOVE+=('')

    SHERPA_QPKG_NAME+=(Deluge-server)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=($PROJECT_REPO_URL/Deluge-server/build/Deluge-server_200922.qpkg)
        SHERPA_QPKG_MD5+=(633bc7ff090346a0e8c204fe7b19a382)
        SHERPA_QPKG_ABBRVS+=('deluge del-server deluge-server')
        SHERPA_QPKG_INDEPS+=('Entware')
        SHERPA_QPKG_IPKGS_ADD+=('deluge jq')
        SHERPA_QPKG_IPKGS_REMOVE+=('')

    SHERPA_QPKG_NAME+=(Deluge-web)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=($PROJECT_REPO_URL/Deluge-web/build/Deluge-web_200922.qpkg)
        SHERPA_QPKG_MD5+=(774191bbdcd31e6494abba4192b51d7a)
        SHERPA_QPKG_ABBRVS+=('del-web deluge-web')
        SHERPA_QPKG_INDEPS+=('Entware')
        SHERPA_QPKG_IPKGS_ADD+=('deluge-ui-web jq')
        SHERPA_QPKG_IPKGS_REMOVE+=('')

    # package arrays are now full, so lock them
    readonly SHERPA_QPKG_NAME
        readonly SHERPA_QPKG_ARCH
        readonly SHERPA_QPKG_URL
        readonly SHERPA_QPKG_MD5
        readonly SHERPA_QPKG_ABBRVS
        readonly SHERPA_QPKG_INDEPS
        readonly SHERPA_QPKG_IPKGS_ADD
        readonly SHERPA_QPKG_IPKGS_REMOVE

    for package in "${SHERPA_QPKG_NAME[@]}"; do
        QPKGs.Names.Add $package
    done

    readonly SHERPA_COMMON_IPKGS_ADD='ca-certificates findutils gcc git git-http less nano python3-dev python3-pip python3-setuptools sed'
    readonly SHERPA_COMMON_PIPS_ADD='apscheduler beautifulsoup4 cfscrape cheetah3 cheroot!=8.4.4 cherrypy configobj feedparser==5.2.1 portend pygithub python-magic random_user_agent sabyenc3 simplejson slugify'
    readonly SHERPA_COMMON_CONFLICTS='Optware Optware-NG TarMT Python QPython2'

    Session.ParseArguments
    Session.SkipPackageProcessing.IsNot && Session.Debug.To.File.Set
    DebugInfoMajorSeparator
    DebugScript 'started' "$($DATE_CMD -d @$SCRIPT_STARTSECONDS | tr -s ' ')"
    DebugScript 'version' "package: $PACKAGE_VERSION, manager: $MANAGER_SCRIPT_VERSION, loader $LOADER_SCRIPT_VERSION"
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

    DebugFuncEntry

    if [[ -z $USER_ARGS_RAW ]]; then
        User.Opts.Help.Basic.Set
        Session.SkipPackageProcessing.Set
        code_pointer=1
        DebugFuncExit; return 1
    fi

    local user_args=($(tr '[A-Z]' '[a-z]' <<< "$USER_ARGS_RAW"))
    local arg=''
    local action='install_'     # make 'install' the default action. A user-convenience to emulate the previous script behaviour.
    local action_force=false
    local target_package=''

    for arg in "${user_args[@]/--/}"; do
        case $arg in
            abs)
                User.Opts.Help.Abbreviations.Set
                Session.SkipPackageProcessing.Set
                ;;
            d|debug|verbose)
                Session.Debug.To.Screen.Set
                ;;
            ignore-space)
                User.Opts.IgnoreFreeSpace.Set
                ;;
            h|help)
                User.Opts.Help.Basic.Set
                Session.SkipPackageProcessing.Set
                ;;
            log|view-log|log-view)
                User.Opts.Log.Whole.View.Set
                Session.SkipPackageProcessing.Set
                ;;
            l|log-last|last|last-log|view-last|last-view)
                User.Opts.Log.Last.View.Set
                Session.SkipPackageProcessing.Set
                ;;
            clean)
                User.Opts.Clean.Set
                Session.SkipPackageProcessing.Set
                ;;
            paste|paste-whole)
                User.Opts.Log.Tail.Paste.Set
                Session.SkipPackageProcessing.Set
                ;;
            p|paste-last)
                User.Opts.Log.Last.Paste.Set
                Session.SkipPackageProcessing.Set
                ;;
            a|action|actions)
                User.Opts.Help.Actions.Set
                Session.SkipPackageProcessing.Set
                ;;
            action-all|actions-all)
                User.Opts.Help.ActionsAll.Set
                Session.SkipPackageProcessing.Set
                ;;
            package|packages)
                User.Opts.Help.Packages.Set
                Session.SkipPackageProcessing.Set
                ;;
            o|option|options)
                User.Opts.Help.Options.Set
                Session.SkipPackageProcessing.Set
                ;;
            problem|problems)
                User.Opts.Help.Problems.Set
                Session.SkipPackageProcessing.Set
                ;;
            t|tip|tips)
                User.Opts.Help.Tips.Set
                Session.SkipPackageProcessing.Set
                ;;
            list|list-all|all)
                User.Opts.Apps.List.All.Set
                Session.Display.Clean.Set
                Session.SkipPackageProcessing.Set
                ;;
            list-installed|installed)
                User.Opts.Apps.List.Installed.Set
                Session.Display.Clean.Set
                Session.SkipPackageProcessing.Set
                ;;
            list-installable|list-not-installed|not-installed|installable)
                User.Opts.Apps.List.NotInstalled.Set
                Session.Display.Clean.Set
                Session.SkipPackageProcessing.Set
                ;;
            list-upgradable|upgradable)
                User.Opts.Apps.List.Upgradable.Set
                Session.Display.Clean.Set
                Session.SkipPackageProcessing.Set
                ;;
            list-independent|independent)
                User.Opts.Apps.List.Independent.Set
                Session.Display.Clean.Set
                Session.SkipPackageProcessing.Set
                ;;
            list-dependant|dependant)
                User.Opts.Apps.List.Dependant.Set
                Session.Display.Clean.Set
                Session.SkipPackageProcessing.Set
                ;;
            v|version)
                User.Opts.Versions.View.Set
                Session.Display.Clean.Set
                Session.SkipPackageProcessing.Set
                ;;
            c|check|check-all)
                User.Opts.Dependencies.Check.Set
                action=''
                ;;
            install-all|install-all-packages|install-all-applications)
                User.Opts.Apps.All.Install.Set
                action=''
                ;;
            uninstall-all-packages-please|uninstall-all-applications-please|remove-all-packages-please|remove-all-applications-please)
                User.Opts.Apps.All.Uninstall.Set
                action=''
                ;;
            reinstall-all)
                User.Opts.Apps.All.Reinstall.Set
                action=''
                ;;
            restart-all)
                User.Opts.Apps.All.Restart.Set
                action=''
                ;;
            stop-all)
                User.Opts.Apps.All.Stop.Set
                action=''
                ;;
            start-all)
                User.Opts.Apps.All.Start.Set
                action=''
                ;;
            upgrade-all)
                User.Opts.Apps.All.Upgrade.Set
                action=''
                ;;
            backup-all)
                User.Opts.Apps.All.Backup.Set
                action=''
                ;;
            restore-all)
                User.Opts.Apps.All.Restore.Set
                action=''
                ;;
            install)
                action=install_
                action_force=false
                ;;
            uninstall|remove)
                action=uninstall_
                action_force=false
                ;;
            reinstall)
                action=reinstall_
                action_force=false
                ;;
            restart)
                action=restart_
                action_force=false
                ;;
            stop)
                action=stop_
                action_force=false
                ;;
            start)
                action=start_
                action_force=false
                ;;
            up|upgrade)
                action=upgrade_
                action_force=false
                ;;
            backup)
                action=backup_
                action_force=false
                ;;
            restore)
                action=restore_
                action_force=false
                ;;
            force)
                action_force=true
                ;;
            *)
                target_package=$(MatchAbbrvToQPKGName "$arg")
                [[ -z $target_package ]] && continue

                case $action in
                    backup_)
                        QPKGs.ToBackup.Add "$target_package"
                        ;;
                    restore_)
                        QPKGs.ToRestore.Add "$target_package"
                        ;;
                    upgrade_)
                        if [[ $action_force = true ]]; then
                            QPKGs.ToForceUpgrade.Add "$target_package"
                        else
                            QPKGs.ToUpgrade.Add "$target_package"
                        fi
                        ;;
                    install_)
                        QPKGs.ToInstall.Add "$target_package"
                        ;;
                    reinstall_)
                        QPKGs.ToReinstall.Add "$target_package"
                        ;;
                    restart_)
                        QPKGs.ToRestart.Add "$target_package"
                        ;;
                    stop_)
                        QPKGs.ToStop.Add "$target_package"
                        ;;
                    start_)
                        QPKGs.ToStart.Add "$target_package"
                        ;;
                    uninstall_)
                        QPKGs.ToUninstall.Add "$target_package"
                        ;;
                esac
        esac
    done

    DebugFuncExit; return 0

    }

Session.Validate()
    {

    Session.SkipPackageProcessing.IsSet && return
    DebugFuncEntry
    local package=''

    DebugInfoMinorSeparator
    DebugHardware.OK 'model' "$(get_display_name)"
    DebugHardware.OK 'RAM' "$(printf "%'.f kB" $INSTALLED_RAM_KB)"

    if QPKGs.ToInstall.Exist SABnzbd || QPKG.Installed SABnzbd; then
        [[ $INSTALLED_RAM_KB -le $MIN_RAM_KB ]] && DebugHardware.Warning 'RAM' "less-than or equal-to $(printf "%'.f kB" $MIN_RAM_KB)"
    fi

    DebugFirmware 'firmware version' "$NAS_FIRMWARE"
    DebugFirmware 'firmware build' "$NAS_BUILD"
    DebugFirmware 'kernel' "$($UNAME_CMD -mr)"
    DebugUserspace.OK 'OS uptime' "$($UPTIME_CMD | $SED_CMD 's|.*up.||;s|,.*load.*||;s|^\ *||')"
    DebugUserspace.OK 'system load' "$($UPTIME_CMD | $SED_CMD 's|.*load average: ||' | $AWK_CMD -F', ' '{print "1 min="$1 ", 5 min="$2 ", 15 min="$3}')"

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
        ShowAsError "this script must be run as the 'admin' user. Please login via SSH as 'admin' and try again"
        Session.SkipPackageProcessing.Set
        DebugFuncExit; return 1
    fi

    DebugUserspace.OK 'BASH' "$(bash --version | $HEAD_CMD -n1)"
    DebugUserspace.OK 'default volume' "$($GETCFG_CMD SHARE_DEF defVolMP -f $DEFAULT_SHARES_PATHFILE)"

    if [[ -L '/opt' ]]; then
        DebugUserspace.OK '/opt' "$($READLINK_CMD '/opt' || echo '<not present>')"
    else
        DebugUserspace.Warning '/opt' '<not present>'
    fi

    if [[ ${#PATH} -le 54 ]]; then
        DebugUserspace.OK '$PATH' "$PATH"
    else
        DebugUserspace.OK '$PATH' "${PATH:0:51}..."
    fi

    CheckPythonPathAndVersion python2
    CheckPythonPathAndVersion python3
    CheckPythonPathAndVersion python
    DebugUserspace.OK 'unparsed user arguments' "'$USER_ARGS_RAW'"

    DebugScript 'logs path' "$LOGS_PATH"
    DebugScript 'work path' "$WORK_PATH"
    DebugScript 'object reference hash' "$COMPILED_OBJECTS_HASH"

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
            DebugWarning "$(FormatAsPackageName Entware) appears to be installed but is not visible"
        fi
    fi

    Session.Calc.QPKGArch
    DebugQPKG 'arch' "$NAS_QPKG_ARCH"

    DebugQPKG 'upgradable package(s)' "$(QPKGs.Upgradable.List) "
    DebugInfoMinorSeparator
    QPKGs.Assignment.Check
    DebugInfoMinorSeparator

    if [[ $(QPKGs.Installed.Count) -eq 0 && $(QPKGs.ToInstall.Count) -eq 1 && $(QPKGs.ToInstall.First) = Entware ]]; then
        ShowAsNote "It's not necessary to install $(FormatAsPackageName Entware) on its own. It will be installed as-required with your other sherpa packages. :)"  # don't colourise title here as ANSI codes can't be removed without Entware being installed with its GNU utils.
        Session.SkipPackageProcessing.Set
        DebugFuncExit; return 1
    fi

    if User.Opts.Apps.All.Backup.IsSet && User.Opts.Apps.All.Restore.IsSet; then
        ShowAsError 'no point running a backup then a restore operation'
        Session.SkipPackageProcessing.Set
        DebugFuncExit; return 1
    fi

    if ! QPKGs.Conflicts.Check; then
        code_pointer=2
        Session.SkipPackageProcessing.Set
        DebugFuncExit; return 1
    fi

    if QPKGs.ToBackup.IsNone && QPKGs.ToUninstall.IsNone && QPKGs.ToForceUpgrade.IsNone && QPKGs.ToUpgrade.IsNone && QPKGs.ToInstall.IsNone && QPKGs.ToReinstall.IsNone && QPKGs.ToRestore.IsNone && QPKGs.ToRestart.IsNone && QPKGs.ToStart.IsNone && QPKGs.ToStop.IsNone; then
        if User.Opts.Apps.All.Install.IsNot && User.Opts.Apps.All.Uninstall.IsNot && User.Opts.Apps.All.Restart.IsNot && User.Opts.Apps.All.Upgrade.IsNot && User.Opts.Apps.All.Backup.IsNot && User.Opts.Apps.All.Restore.IsNot; then
            if User.Opts.Dependencies.Check.IsNot && Session.Debug.To.Screen.IsNot && User.Opts.IgnoreFreeSpace.IsNot; then
                ShowAsError 'nothing to do'
                User.Opts.Help.Basic.Set
                Session.SkipPackageProcessing.Set
                DebugFuncExit; return 1
            fi
        fi
    fi

    if User.Opts.Dependencies.Check.IsSet; then
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

    for package in $(QPKGs.ToDownload.Array); do
        QPKG.Download $package
    done

    DebugFuncExit; return 0

    }

Packages.Backup()
    {

    Session.SkipPackageProcessing.IsSet && return
    DebugFuncEntry
    local package=''

    if QPKGs.ToBackup.IsAny; then
        for package in $(QPKGs.ToBackup.Array); do
            if QPKG.Installed $package; then
                if QPKGs.Independent.Exist $package; then
                    ShowAsNote "unable to backup $(FormatAsPackageName $package) configuration as it's unsupported"
                else
                    QPKG.Backup $package
                fi
            else
                ShowAsNote "unable to backup $(FormatAsPackageName $package) configuration as it's not installed"
            fi
        done

        Session.ShowBackupLocation.Set
    fi

    DebugFuncExit; return 0

    }

Packages.Stop()
    {

    Session.SkipPackageProcessing.IsSet && return
    DebugFuncEntry
    local package=''
    local acc=()
    local index=0

    # if an independent has been selected for 'stop', need to stop all dependants too
    for package in $(QPKGs.ToStop.Array); do
        if QPKGs.Independent.Exist $package && QPKG.Installed $package; then
            acc+=($(QPKG.Get.Dependencies $package))
        fi
    done

    # if an independent has been selected for 'uninstall', need to stop all dependants too
    for package in $(QPKGs.ToUninstall.Array); do
        if QPKGs.Independent.Exist $package && QPKG.Installed $package; then
            acc+=($(QPKG.Get.Dependencies $package))
        fi
    done

    if [[ ${#acc[@]} -gt 0 ]]; then
        for package in "${acc[@]}"; do
            QPKG.Installed $package && QPKGs.ToStop.Add $package
        done
    fi

    if QPKGs.ToStop.IsAny; then
        for ((index=$(QPKGs.Dependant.Count); index>=1; index--)); do       # stop packages in reverse of declared order
            package=$(QPKGs.Dependant.GetItem $index)

            if QPKGs.ToStop.Exist $package; then
                if QPKG.Installed $package; then
                    QPKG.Stop $package
                else
                    ShowAsNote "unable to stop $(FormatAsPackageName $package) as it's not installed"
                fi
            fi
        done

        for ((index=$(QPKGs.Independent.Count); index>=1; index--)); do     # stop packages in reverse of declared order
            package=$(QPKGs.Independent.GetItem $index)

            if QPKGs.ToStop.Exist $package; then
                if QPKG.Installed $package; then
                    QPKG.Stop $package
                    QPKG.Disable $package   # independents don't have the same service scripts as other sherpa packages, so they must be enabled/disabled externally
                else
                    ShowAsNote "unable to stop $(FormatAsPackageName $package) as it's not installed"
                fi
            fi
        done
    fi

    DebugFuncExit; return 0

    }

Packages.Uninstall()
    {

    Session.SkipPackageProcessing.IsSet && return
    DebugFuncEntry
    local response=''
    local package=''
    local previous_pip3_module_list=$WORK_PATH/pip3.prev.installed.list
    local previous_opkg_package_list=$WORK_PATH/opkg.prev.installed.list
    local index=0

    if QPKGs.ToUninstall.IsAny; then
        # remove dependant packages first

        for ((index=$(QPKGs.Dependant.Count); index>=1; index--)); do       # uninstall packages in reverse of declared order
            package=$(QPKGs.Dependant.GetItem $index)

            if QPKGs.ToUninstall.Exist $package; then
                if QPKG.Installed $package; then
                    QPKG.Uninstall $package
                else
                    ShowAsNote "unable to uninstall $(FormatAsPackageName $package) as it's not installed"
                fi
            fi
        done

        # then the independent packages last
        for ((index=$(QPKGs.Independent.Count); index>=1; index--)); do     # uninstall packages in reverse of declared order
            package=$(QPKGs.Independent.GetItem $index)

            if QPKGs.ToUninstall.Exist $package; then
                if [[ $package != Entware ]]; then      # KLUDGE: ignore Entware as it needs to be handled separately.
                    if QPKG.Installed $package; then
                        QPKG.Uninstall $package
                    else
                        ShowAsNote "unable to uninstall $(FormatAsPackageName $package) as it's not installed"
                    fi
                fi
            fi
        done

        # TODO: still need something here to remove Entware if it's in the QPKGs.ToUninstall array
    fi

    QPKG.Installed Entware && IPKGs.Uninstall
    DebugFuncExit; return 0

    }

Packages.Reinstall.Independents()
    {

    Session.SkipPackageProcessing.IsSet && return
    DebugFuncEntry
    local package=''

    if QPKGs.ToReinstall.IsAny; then
        for package in $(QPKGs.Independent.Array); do
            if QPKGs.ToReinstall.Exist $package; then
                if QPKG.Installed $package; then
                    if [[ $package = Entware ]]; then
                        ShowAsNote "Reinstalling $(FormatAsPackageName Entware) will remove all IPKGs and Python modules, and only those required to support your $PROJECT_NAME apps will be reinstalled."
                        ShowAsNote "Your installed IPKG list will be saved to $(FormatAsFileName "$previous_opkg_package_list")"
                        ShowAsNote "Your installed Python module list will be saved to $(FormatAsFileName "$previous_pip3_module_list")"
                        (QPKG.Installed SABnzbdplus || QPKG.Installed Headphones) && ShowAsWarning "Also, the $(FormatAsPackageName SABnzbdplus) and $(FormatAsPackageName Headphones) packages CANNOT BE REINSTALLED as Python 2.7.16 is no-longer available."

                        if AskQuiz "Press 'Y' to remove all current $(FormatAsPackageName Entware) IPKGs (and their configurations), or any other key to abort"; then
                            ShowAsProc 'saving package and Python module lists'

                            if [[ -e $pip3_cmd ]]; then
                                $pip3_cmd freeze > "$previous_pip3_module_list"
                                DebugDone "saved current $(FormatAsPackageName pip3) module list to $(FormatAsFileName "$previous_pip3_module_list")"
                            fi

                            if [[ -e $OPKG_CMD ]]; then
                                $OPKG_CMD list-installed > "$previous_opkg_package_list"
                                DebugDone "saved current $(FormatAsPackageName Entware) IPKG list to $(FormatAsFileName "$previous_opkg_package_list")"
                            fi

                            ShowAsDone 'package and Python module lists saved'
                            QPKG.Uninstall Entware
                        else
                            DebugInfoMinorSeparator
                            DebugScript 'user abort'
                            Session.SkipPackageProcessing.Set
                            Session.Summary.Clear
                            DebugFuncExit; return 1
                        fi
                    else
                        QPKG.Reinstall $package
                    fi
                else
                    ShowAsNote "unable to reinstall $(FormatAsPackageName $package) as it's not installed. Use 'install' instead."
                fi
            fi
        done
    fi

    DebugFuncExit; return 0

    }

Packages.Install.Independents()
    {

    # install independent QPKGs first

    Session.SkipPackageProcessing.IsSet && return
    DebugFuncEntry
    local package=''

    if QPKGs.ToInstall.IsAny || User.Opts.Dependencies.Check.IsSet; then
        for package in $(QPKGs.Independent.Array); do
            if QPKGs.ToInstall.Exist $package; then
                if QPKG.NotInstalled $package; then
                    if [[ $package = Entware ]]; then
                        # rename original [/opt]
                        local opt_path=/opt
                        local opt_backup_path=/opt.orig
                        [[ -d $opt_path && ! -L $opt_path && ! -e $opt_backup_path ]] && mv "$opt_path" "$opt_backup_path"
                        QPKG.Install Entware && Session.AdjustPathEnv

                        # copy all files from original [/opt] into new [/opt]
                        [[ -L $opt_path && -d $opt_backup_path ]] && cp --recursive "$opt_backup_path"/* --target-directory "$opt_path" && rm -rf "$opt_backup_path"
                        Session.PIPs.Install.Set
                    else
                        if [[ $NAS_QPKG_ARCH != none ]]; then
                            if QPKGs.ToInstall.Exist $package; then
                                QPKG.Install $package
                            fi
                        fi
                    fi
                else
                    ShowAsNote "unable to install $(FormatAsPackageName $package) as it's already installed. Use 'reinstall' instead."
                fi
            fi
        done
    fi

    if QPKGs.ToInstall.IsAny || QPKGs.ToReinstall.IsAny; then
        Session.IPKGs.Install.Set
    fi

    QPKGs.ToInstall.Exist SABnzbd && Session.PIPs.Install.Set   # need to ensure 'sabyenc' module is also installed

    if QPKG.Enabled Entware; then
        Session.AdjustPathEnv
        Entware.Patch.Service
        IPKGs.Install
        PIPs.Install
    fi

    DebugFuncExit; return 0

    }

Packages.Start.Independents()
    {

    Session.SkipPackageProcessing.IsSet && return
    DebugFuncEntry
    local package=''
    local acc=()

    # if a dependant has been selected for 'start', need to start independents too
    for package in $(QPKGs.ToStart.Array); do
        acc+=($(QPKG.Get.Independencies $package))
    done

    if [[ ${#acc[@]} -gt 0 ]]; then
        for package in "${acc[@]}"; do
            QPKG.Installed $package && ! QPKGs.JustInstalled.Exist $package && QPKGs.ToStart.Add $package
        done
    fi

    if QPKGs.ToStart.IsAny; then
        for package in $(QPKGs.Independent.Array); do
            if QPKGs.ToStart.Exist $package; then
                if QPKG.Installed $package; then
                    QPKG.Enable $package    # independents don't have the same service scripts as other sherpa packages, so they must be enabled/disabled externally
                    QPKG.Start $package
                else
                    ShowAsNote "unable to start $(FormatAsPackageName $package) as it's not installed"
                fi
            fi
        done
    fi

    DebugFuncExit; return 0

    }

Packages.Upgrade.Dependants()
    {

    Session.SkipPackageProcessing.IsSet && return
    DebugFuncEntry
    local package=''

    if QPKGs.ToUpgrade.IsAny || QPKGs.ToForceUpgrade.IsAny; then
        for package in $(QPKGs.Dependant.Array); do
            if QPKGs.ToForceUpgrade.Exist $package; then
                QPKG.Upgrade $package --forced
            elif QPKGs.ToUpgrade.Exist $package; then
                if QPKG.Installed $package; then
                    if QPKGs.Upgradable.Exist $package; then
                        QPKG.Upgrade $package
                    else
                        ShowAsNote "unable to upgrade $(FormatAsPackageName $package) as it's not upgradable. Use the 'force' if you really want this."
                    fi
                else
                    ShowAsNote "unable to upgrade $(FormatAsPackageName $package) as it's not installed. Use 'install' instead."
                fi
            fi
        done
    fi

    DebugFuncExit; return 0

    }

Packages.Reinstall.Dependants()
    {

    Session.SkipPackageProcessing.IsSet && return
    DebugFuncEntry
    local package=''

    if QPKGs.ToReinstall.IsAny; then
        for package in $(QPKGs.Dependant.Array); do
            if QPKGs.ToReinstall.Exist $package; then
                if QPKG.Installed $package; then
                    QPKG.Reinstall $package
                else
                    ShowAsNote "unable to reinstall $(FormatAsPackageName $package) as it's not installed. Use 'install' instead."
                fi
            fi
        done
    fi

    DebugFuncExit; return 0

    }

Packages.Install.Dependants()
    {

    Session.SkipPackageProcessing.IsSet && return
    DebugFuncEntry
    local package=''

    if QPKGs.ToInstall.IsAny; then
        for package in $(QPKGs.Dependant.Array); do
            if QPKGs.ToInstall.Exist $package; then
                if QPKG.NotInstalled $package; then
                    QPKG.Install $package
                else
                    ShowAsNote "unable to install $(FormatAsPackageName $package) as it's already installed. Use 'reinstall' instead."
                fi
            fi
        done
    fi

    DebugFuncExit; return 0

    }

Packages.Restore()
    {

    Session.SkipPackageProcessing.IsSet && return
    DebugFuncEntry
    local package=''

    if QPKGs.ToRestore.IsAny; then
        for package in $(QPKGs.ToRestore.Array); do
            if QPKG.Installed $package; then
                if QPKGs.Independent.Exist $package; then
                    ShowAsNote "unable to restore $(FormatAsPackageName $package) configuration as it's unsupported"
                else
                    QPKG.Restore $package
                fi
            else
                ShowAsNote "unable to restore $(FormatAsPackageName $package) configuration as it's not installed"
            fi
        done

        Session.ShowBackupLocation.Set
    fi

    DebugFuncExit; return 0

    }

Packages.Start.Dependants()
    {

    Session.SkipPackageProcessing.IsSet && return
    DebugFuncEntry
    local dep_package=''
    local indep_package=''

    if QPKGs.ToStart.IsAny; then
        for dep_package in $(QPKGs.Dependant.Array); do
            if QPKGs.ToStart.Exist $dep_package; then
                if ! QPKG.Installed $dep_package; then
                    ShowAsNote "unable to start $(FormatAsPackageName $dep_package) as it's not installed"
                else
                    for indep_package in $(QPKG.Get.Independencies $dep_package); do
                        if ! QPKG.Installed $indep_package; then
                            ShowAsNote "unable to start $(FormatAsPackageName $dep_package) as $(FormatAsPackageName $indep_package) is not installed"
                            break
                        fi
                    done

                    QPKG.Start $dep_package
                fi
            fi
        done
    fi

    DebugFuncExit; return 0

    }

Packages.Restart()
    {

    Session.SkipPackageProcessing.IsSet && return
    DebugFuncEntry
    local package=''
    local acc=()

    for package in $(QPKGs.JustInstalled.Array); do
        if QPKGs.Independent.Exist $package; then
            acc+=($(QPKG.Get.Dependencies $package))
        fi
    done

    if [[ ${#acc[@]} -gt 0 ]]; then
        for package in "${acc[@]}"; do
            QPKG.Installed $package && ! QPKGs.JustInstalled.Exist $package && ! QPKGs.JustStarted.Exist $package && QPKGs.ToRestart.Add $package
        done
    fi

    if User.Opts.Apps.All.Upgrade.IsSet; then
        QPKGs.NotUpgraded.Restart
    elif QPKGs.ToRestart.IsAny; then
        for package in $(QPKGs.Dependant.Array); do
            if QPKGs.ToRestart.Exist $package; then
                if ! QPKG.Installed $package; then
                    ShowAsNote "unable to restart $(FormatAsPackageName $package) as it's not installed"
                elif QPKGs.JustInstalled.Exist $package; then
                    ShowAsNote "no-need to restart $(FormatAsPackageName $package) as it was just installed"
                elif QPKGs.JustStarted.Exist $package; then
                    ShowAsNote "no-need to restart $(FormatAsPackageName $package) as it was just started"
                else
                    QPKG.Restart $package
                fi
            fi
        done
    fi

    DebugFuncExit; return 0

    }

Session.Results()
    {

    if User.Opts.Versions.View.IsSet; then
        Versions.Show
    elif User.Opts.Log.Whole.View.IsSet; then
        Log.Whole.View
    elif User.Opts.Log.Tail.Paste.IsSet; then
        Log.Tail.Paste.Online
    elif User.Opts.Log.Last.Paste.IsSet; then
        Log.Last.Paste.Online
    elif User.Opts.Log.Last.View.IsSet; then
        Log.Last.View
    elif User.Opts.Clean.IsSet; then
        Clean.Cache
    elif User.Opts.Apps.List.Installed.IsSet; then
        QPKGs.Installed.Show
    elif User.Opts.Apps.List.NotInstalled.IsSet; then
        QPKGs.NotInstalled.Show
    elif User.Opts.Apps.List.Upgradable.IsSet; then
        QPKGs.Upgradable.Show
    elif User.Opts.Apps.List.All.IsSet; then
        QPKGs.All.Show
    elif User.Opts.Apps.List.Independent.IsSet; then
        QPKGs.Independent.Show
    elif User.Opts.Apps.List.Dependant.IsSet; then
        QPKGs.Dependant.Show
    fi

    if User.Opts.Help.Basic.IsSet; then
        Help.Basic.Show
        Help.Basic.Example.Show
    elif User.Opts.Help.Actions.IsSet; then
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

    [[ -d $WORK_PATH ]] && rm -rf $WORK_PATH
    ShowAsDone "work path cleaned"

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

Entware.Patch.Service()
    {

    local tab=$'\t'
    local prefix_text="# following line was inserted by $PROJECT_NAME"
    local find_text=''
    local insert_text=''
    local package_init_pathfile=$(QPKG.ServicePathFile Entware)

    if ($GREP_CMD -q 'opt.orig' "$package_init_pathfile"); then
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

        DebugDone 'patch: do the "opt shuffle"'
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
    local result=0

    # if Entware package list was updated only recently, don't run another update. Examine 'change' time as this is updated even if package list content isn't modified.
    if [[ -e $EXTERNAL_PACKAGE_ARCHIVE_PATHFILE && -e $GNU_FIND_CMD ]]; then
        msgs=$($GNU_FIND_CMD "$EXTERNAL_PACKAGE_ARCHIVE_PATHFILE" -cmin +$package_minutes_threshold)        # no-output if last update was less than $package_minutes_threshold minutes ago
    else
        msgs='new install'
    fi

    if [[ -n $msgs ]]; then
        ShowAsProc "updating $(FormatAsPackageName Entware) package list"

        if Session.Debug.To.Screen.IsSet; then
            RunThisAndLogResultsRealtime "$OPKG_CMD update" "$log_pathfile" log:failure-only
            result=$?
        else
            RunThisAndLogResults "$OPKG_CMD update" "$log_pathfile" log:failure-only
            result=$?
        fi

        if [[ $result -eq 0 ]]; then
            ShowAsDone "updated $(FormatAsPackageName Entware) package list"
        else
            ShowAsWarning "Unable to update $(FormatAsPackageName Entware) package list $(FormatAsExitcode $result)"
            # meh, continue anyway with old list ...
        fi
    else
        DebugInfo "$(FormatAsPackageName Entware) package list was updated less than $package_minutes_threshold minutes ago"
        ShowAsDone "$(FormatAsPackageName Entware) package list is current"
    fi

    return 0

    }

PIPs.Install()
    {

    Session.SkipPackageProcessing.IsSet && return
    Session.PIPs.Install.IsNot && return
    DebugFuncEntry
    local exec_cmd=''
    local result=0

    # sometimes, OpenWRT doesn't have a 'pip3'
    if [[ -e /opt/bin/pip3 ]]; then
        pip3_cmd=/opt/bin/pip3
    elif [[ -e /opt/bin/pip3.8 ]]; then
        pip3_cmd=/opt/bin/pip3.8
    elif [[ -e /opt/bin/pip3.7 ]]; then
        pip3_cmd=/opt/bin/pip3.7
    else
        if IsNotSysFileExist $pip3_cmd; then
            echo "* Ugh! The usual fix for this is to let $PROJECT_NAME reinstall $(FormatAsPackageName Entware) at least once."
            echo -e "\t$0 ew"
            echo "If it happens again after reinstalling $(FormatAsPackageName Entware), please create a new issue for this on GitHub."
            DebugFuncExit; return 1
        fi
    fi

    [[ -n ${SHERPA_COMMON_PIPS_ADD// /} ]] && exec_cmd="$pip3_cmd install $SHERPA_COMMON_PIPS_ADD --disable-pip-version-check --cache-dir $PIP_CACHE_PATH"

    local desc="'Python 3' assorted modules"
    local log_pathfile=$LOGS_PATH/py3-modules.assorted.$INSTALL_LOG_FILE
    ShowAsProcLong "downloading & installing $desc"

    if Session.Debug.To.Screen.IsSet; then
        RunThisAndLogResultsRealtime "$exec_cmd" "$log_pathfile"
        result=$?
    else
        RunThisAndLogResults "$exec_cmd" "$log_pathfile"
        result=$?
    fi

    if [[ $result -eq 0 ]]; then
        ShowAsDone "downloaded & installed $desc"
    else
        ShowAsError "download & install $desc failed $(FormatAsResult "$result")"
    fi

    if QPKG.Installed SABnzbd || QPKGs.ToInstall.Exist SABnzbd; then
        # KLUDGE: force recompilation of 'sabyenc3' package so it's recognised by SABnzbd. See: https://forums.sabnzbd.org/viewtopic.php?p=121214#p121214
        exec_cmd="$pip3_cmd install --force-reinstall --ignore-installed --no-binary :all: sabyenc3 --disable-pip-version-check --cache-dir $PIP_CACHE_PATH"

        desc="'Python 3' SABnzbd module"
        log_pathfile=$LOGS_PATH/py3-modules.sabnzbd.$INSTALL_LOG_FILE
        ShowAsProcLong "downloading & installing $desc"

        if Session.Debug.To.Screen.IsSet; then
            RunThisAndLogResultsRealtime "$exec_cmd" "$log_pathfile"
            result=$?
        else
            RunThisAndLogResults "$exec_cmd" "$log_pathfile"
            result=$?
        fi

        if [[ $result -eq 0 ]]; then
            ShowAsDone "downloaded & installed $desc"
            QPKGs.ToRestart.Add SABnzbd

        else
            ShowAsError "download & install $desc failed $(FormatAsResult "$result")"
        fi
    fi

    DebugFuncExit; return $result

    }

CalcAllIPKGDepsToInstall()
    {

    # From a specified list of IPKG names, find all dependent IPKGs, exclude those already installed, then generate a total qty to download and a total download byte-size

    if IsNotSysFileExist $OPKG_CMD || IsNotSysFileExist $GNU_GREP_CMD; then
        code_pointer=4
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

    ShowAsProc 'calculating IPKGs required'
    DebugInfo "IPKGs requested: $requested_list"

    if ! IPKGs.Archive.Open; then
        DebugFuncExit; return 1
    fi

    DebugProc 'finding IPKG dependencies'
    while [[ $iterations -lt $ITERATION_LIMIT ]]; do
        ((iterations++))
        DebugProc "iteration $iterations"

        local IPKG_titles=$(printf '^Package: %s$\|' "${this_list[@]}")
        IPKG_titles=${IPKG_titles%??}       # remove last 2 characters

        this_list=($($GNU_GREP_CMD --word-regexp --after-context 1 --no-group-separator '^Package:\|^Depends:' "$EXTERNAL_PACKAGE_LIST_PATHFILE" | $GNU_GREP_CMD -vG '^Section:\|^Version:' | $GNU_GREP_CMD --word-regexp --after-context 1 --no-group-separator "$IPKG_titles" | $GNU_GREP_CMD -vG "$IPKG_titles" | $GNU_GREP_CMD -vG '^Package: ' | $SED_CMD 's|^Depends: ||;s|, |\n|g' | $SORT_CMD | $UNIQ_CMD))

        if [[ ${#this_list[@]} -eq 0 ]]; then
            DebugDone 'complete'
            DebugInfo "found all IPKG dependencies in $iterations iteration$(FormatAsPlural $iterations)"
            complete=true
            break
        else
            dependency_accumulator+=(${this_list[*]})
        fi
    done

    if [[ $complete = false ]]; then
        DebugError "IPKG dependency list is incomplete! Consider raising \$ITERATION_LIMIT [$ITERATION_LIMIT]."
        Session.SuggestIssue.Set
    fi

    pre_download_list=$(DeDupeWords "$requested_list ${dependency_accumulator[*]}")
    DebugInfo "IPKGs requested + dependencies: $pre_download_list"

    DebugProc 'excluding IPKGs already installed'
    for element in $pre_download_list; do
        if [[ $element != 'ca-certs' ]]; then       # KLUDGE: 'ca-certs' appears to be a bogus meta-package, so silently exclude it from attempted installation.
            if [[ $element != 'libjpeg' ]]; then    # KLUDGE: 'libjpeg' appears to have been replaced by 'libjpeg-turbo', but many packages still list 'libjpeg' as a dependency, so replace it with 'libjpeg-turbo'.
                if ! $OPKG_CMD status "$element" | $GREP_CMD -q "Status:.*installed"; then
                    IPKGs.ToDownload.Add $element
                fi
            elif ! $OPKG_CMD status 'libjpeg-turbo' | $GREP_CMD -q "Status:.*installed"; then
                IPKGs.ToDownload.Add libjpeg-turbo
            fi
        fi
    done
    DebugDone 'complete'
    DebugInfo "IPKGs to download: $(IPKGs.ToDownload.List)"

    package_count=$(IPKGs.ToDownload.Count)

    if [[ $package_count -gt 0 ]]; then
        DebugProc "determining size of IPKG$(FormatAsPlural "$package_count") to download"
        size_array=($($GNU_GREP_CMD -w '^Package:\|^Size:' "$EXTERNAL_PACKAGE_LIST_PATHFILE" | $GNU_GREP_CMD --after-context 1 --no-group-separator ": $($SED_CMD 's/ /$ /g;s/\$ /\$\\\|: /g' <<< "$(IPKGs.ToDownload.List)")$" | $GREP_CMD '^Size:' | $SED_CMD 's|^Size: ||'))
        IPKGs.ToDownload.Size = "$(IFS=+; echo "$((${size_array[*]}))")"   # a neat sizing shortcut found here https://stackoverflow.com/a/13635566/6182835
        DebugDone 'complete'
        DebugInfo "IPKG download size: $(IPKGs.ToDownload.Size)"
        ShowAsDone "$package_count IPKG$(FormatAsPlural "$package_count") ($(FormatAsISOBytes "$(IPKGs.ToDownload.Size)")) to be downloaded"
    else
        ShowAsDone 'no IPKGs are required'
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
    local package_count=0
    local element=''

    requested_list=$(DeDupeWords "$(IPKGs.ToUninstall.List)")

    DebugInfo "IPKGs requested: $requested_list"
    DebugProc 'excluding IPKGs not installed'

    for element in $requested_list; do
        if ! $OPKG_CMD status "$element" | $GREP_CMD -q "Status:.*installed"; then
            IPKGs.ToUninstall.Remove "$element"
        fi
    done

    DebugDone 'complete'
    DebugInfo "IPKGs to uninstall: $(IPKGs.ToUninstall.ListComma)"
    package_count=$(IPKGs.ToUninstall.Count)

    if [[ $package_count -gt 0 ]]; then
        DebugDone 'complete'
        ShowAsDone "$package_count IPKG$(FormatAsPlural "$package_count") to be uninstalled"
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

    if User.Opts.Apps.All.Install.IsSet; then
        for index in "${!SHERPA_QPKG_NAME[@]}"; do
            IPKGs.ToUninstall.Add "${SHERPA_QPKG_IPKGS_REMOVE[$index]}"
        done
    else
        for index in "${!SHERPA_QPKG_NAME[@]}"; do
            if QPKGs.ToInstall.Exist "${SHERPA_QPKG_NAME[$index]}" || QPKG.Installed "${SHERPA_QPKG_NAME[$index]}" || QPKGs.ToUpgrade.Exist "${SHERPA_QPKG_NAME[$index]}" || QPKGs.ToUninstall.Exist "${SHERPA_QPKG_NAME[$index]}"; then
                IPKGs.ToUninstall.Add "${SHERPA_QPKG_IPKGS_REMOVE[$index]}"
            fi
        done
    fi

    IPKGs.Uninstall.Batch
    DebugFuncExit; return 0

    }

IPKGs.Install.Batch()
    {

    # output:
    #   $? = 0 (success) or 1 (failed)

    DebugFuncEntry
    local package_count=0
    local log_pathfile=$LOGS_PATH/ipkgs.$INSTALL_LOG_FILE
    local result=0

    CalcAllIPKGDepsToInstall || return 1
    package_count=$(IPKGs.ToDownload.Count)

    if [[ $package_count -gt 0 ]]; then
        ShowAsProc "downloading & installing $package_count IPKG$(FormatAsPlural "$package_count")"

        CreateDirSizeMonitorFlagFile $IPKG_DL_PATH/.monitor
            trap CTRL_C_Captured INT
                _MonitorDirSize_ "$IPKG_DL_PATH" "$(IPKGs.ToDownload.Size)" &

                RunThisAndLogResults "$OPKG_CMD install$(User.Opts.IgnoreFreeSpace.IsSet && User.Opts.IgnoreFreeSpace.Text) --force-overwrite $(IPKGs.ToDownload.List) --cache $IPKG_CACHE_PATH --tmp-dir $IPKG_DL_PATH" "$log_pathfile"
                result=$?
            trap - INT
        RemoveDirSizeMonitorFlagFile

        if [[ $result -eq 0 ]]; then
            ShowAsDone "downloaded & installed $package_count IPKG$(FormatAsPlural "$package_count")"
        else
            ShowAsError "download & install IPKG$(FormatAsPlural "$package_count") failed $(FormatAsExitcode $result)"
        fi
    fi

    DebugFuncExit; return $result

    }

IPKGs.Uninstall.Batch()
    {

    # output:
    #   $? = 0 (success) or 1 (failed)

    DebugFuncEntry
    local package_count=0
    local log_pathfile=$LOGS_PATH/ipkgs.$UNINSTALL_LOG_FILE
    local result=0

    CalcAllIPKGDepsToUninstall || return 1
    package_count=$(IPKGs.ToUninstall.Count)

    if [[ $package_count -gt 0 ]]; then
        ShowAsProc "uninstalling $package_count IPKG$(FormatAsPlural "$package_count")"

        if Session.Debug.To.Screen.IsSet; then
            RunThisAndLogResultsRealtime "$OPKG_CMD remove $(IPKGs.ToUninstall.List)" "$log_pathfile"
            result=$?
        else
            RunThisAndLogResults "$OPKG_CMD remove $(IPKGs.ToUninstall.List)" "$log_pathfile"
            result=$?
        fi

        if [[ $result -eq 0 ]]; then
            ShowAsDone "uninstalled $package_count IPKG$(FormatAsPlural "$package_count")"
        else
            ShowAsError "uninstall IPKG$(FormatAsPlural "$package_count") failed $(FormatAsExitcode $result)"
        fi
    fi

    DebugFuncExit; return $result

    }

IPKGs.Upgrade.Batch()
    {

    # upgrade all installed IPKGs

    # output:
    #   $? = 0 (success) or 1 (failed)

    DebugFuncEntry
    local package_count=0
    local log_pathfile=$LOGS_PATH/ipkgs.$UPGRADE_LOG_FILE
    local result=0

    IPKGs.ToDownload.Add "$($OPKG_CMD list-upgradable | $CUT_CMD -f1 -d' ')"
    package_count=$(IPKGs.ToDownload.Count)

    if [[ $package_count -gt 0 ]]; then
        ShowAsProc "downloading & upgrading $package_count IPKG$(FormatAsPlural "$package_count")"

        CreateDirSizeMonitorFlagFile $IPKG_DL_PATH/.monitor
            trap CTRL_C_Captured INT
                _MonitorDirSize_ "$IPKG_DL_PATH" "$(IPKGs.ToDownload.Size)" &

                RunThisAndLogResults "$OPKG_CMD upgrade$(User.Opts.IgnoreFreeSpace.IsSet && User.Opts.IgnoreFreeSpace.Text) --force-overwrite $(IPKGs.ToDownload.List) --cache $IPKG_CACHE_PATH --tmp-dir $IPKG_DL_PATH" "$log_pathfile"
                result=$?
            trap - INT
        RemoveDirSizeMonitorFlagFile

        if [[ $result -eq 0 ]]; then
            ShowAsDone "downloaded & upgraded $package_count IPKG$(FormatAsPlural "$package_count")"
        else
            ShowAsError "download & upgrade IPKG$(FormatAsPlural "$package_count") failed $(FormatAsExitcode $result)"
        fi
    fi

    DebugFuncExit; return $result

    }

IPKGs.Archive.Open()
    {

    # extract the 'opkg' package list file

    # output:
    #   $? = 0 (success) or 1 (failed)

    DebugFuncEntry

    if [[ ! -e $EXTERNAL_PACKAGE_ARCHIVE_PATHFILE ]]; then
        ShowAsError 'could not locate the IPKG list file'
        DebugFuncExit; return 1
    fi

    IPKGs.Archive.Close

    if Session.Debug.To.Screen.IsSet; then
        RunThisAndLogResultsRealtime "$Z7_CMD e -o$($DIRNAME_CMD "$EXTERNAL_PACKAGE_LIST_PATHFILE") $EXTERNAL_PACKAGE_ARCHIVE_PATHFILE" "$WORK_PATH/ipkg.list.archive.extract" log:failure-only
        result=$?
    else
        RunThisAndLogResults "$Z7_CMD e -o$($DIRNAME_CMD "$EXTERNAL_PACKAGE_LIST_PATHFILE") $EXTERNAL_PACKAGE_ARCHIVE_PATHFILE" "$WORK_PATH/ipkg.list.archive.extract" log:failure-only
        result=$?
    fi

    if [[ ! -e $EXTERNAL_PACKAGE_LIST_PATHFILE ]]; then
        ShowAsError 'could not open the IPKG list file'
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
    # It watches for the existence of $MONITOR_FLAG_PATHFILE
    # If that file is removed, this function dies gracefully

    # input:
    #   $1 = directory to monitor the size of
    #   $2 = total target bytes (100%) for specified path

    [[ -z $1 || ! -d $1 || -z $2 || $2 -eq 0 ]] && return
    IsNotSysFileExist $GNU_FIND_CMD && return

    local total_bytes=$2
    local last_bytes=0
    local stall_seconds=0
    local stall_seconds_threshold=4
    local current_bytes=0
    local percent=''

    progress_message=''
    previous_length=0
    previous_msg=''

    while [[ -e $MONITOR_FLAG_PATHFILE ]]; do
        current_bytes=$($GNU_FIND_CMD "$1" -type f -name '*.ipk' -exec $DU_CMD --bytes --total --apparent-size {} + 2> /dev/null | $GREP_CMD total$ | $CUT_CMD -f1)
        [[ -z $current_bytes ]] && current_bytes=0

        if [[ $current_bytes -ne $last_bytes ]]; then
            stall_seconds=0
            last_bytes=$current_bytes
        else
            ((stall_seconds++))
        fi

        percent="$((200*(current_bytes)/(total_bytes) % 2 + 100*(current_bytes)/(total_bytes)))%"
        progress_message=" $percent ($(FormatAsISOBytes "$current_bytes")/$(FormatAsISOBytes "$total_bytes"))"

        if [[ $stall_seconds -ge $stall_seconds_threshold ]]; then
            if [[ $stall_seconds -lt 60 ]]; then
                progress_message+=" stalled for $stall_seconds seconds"
            else
                progress_message+=" stalled for $(ConvertSecsToHoursMinutesSecs $stall_seconds)"
            fi
        fi

        ProgressUpdater "$progress_message"
        $SLEEP_CMD 1
    done

    [[ -n $progress_message ]] && ProgressUpdater ' done!'

    }

CreateDirSizeMonitorFlagFile()
    {

    [[ -z $1 ]] && return 1
    readonly MONITOR_FLAG_PATHFILE=$1
    $TOUCH_CMD "$MONITOR_FLAG_PATHFILE"

    }

RemoveDirSizeMonitorFlagFile()
    {

    if [[ -n $MONITOR_FLAG_PATHFILE && -e $MONITOR_FLAG_PATHFILE ]]; then
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

    [[ -z $1 ]] && return

    if location=$(command -v $1 2>&1); then
        DebugUserspace.OK "'$1' path" "$location"
        if version=$($1 -V 2>&1); then
            DebugUserspace.OK "'$1' version" "$version"
        else
            DebugUserspace.Warning "default '$1' version" '<unknown>'
        fi
    else
        DebugUserspace.Warning "'$1' path" '<not present>'
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
        printf "\n* %s \n       # %s\n" "$(tr "[a-z]" "[A-Z]" <<< "${1:0:1}")${1:1}" "$PROJECT_NAME $2"
    else
        printf "\n* %s:\n       # %s\n" "$(tr "[a-z]" "[A-Z]" <<< "${1:0:1}")${1:1}" "$PROJECT_NAME $2"
    fi

    Session.LineSpace.Clear

    }

DisplayAsProjectSyntaxIndentedExample()
    {

    # $1 = description
    # $2 = example syntax

    if [[ -z $2 ]]; then
        printf "\n   %s \n" "$(tr "[a-z]" "[A-Z]" <<< "${1:0:1}")${1:1}"
    elif [[ -z $1 ]]; then
        printf "       # %s\n" "$PROJECT_NAME $2"
    elif [[ ${1: -1} = '!' ]]; then
        printf "\n   %s \n       # %s\n" "$(tr "[a-z]" "[A-Z]" <<< "${1:0:1}")${1:1}" "$PROJECT_NAME $2"
    else
        printf "\n   %s:\n       # %s\n" "$(tr "[a-z]" "[A-Z]" <<< "${1:0:1}")${1:1}" "$PROJECT_NAME $2"
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
        printf "\n* %s \n       # %s\n" "$(tr "[a-z]" "[A-Z]" <<< "${1:0:1}")${1:1}" "$2"
    else
        printf "\n* %s:\n       # %s\n" "$(tr "[a-z]" "[A-Z]" <<< "${1:0:1}")${1:1}" "$2"
    fi

    Session.LineSpace.Clear

    }

DisplayAsInfoExample()
    {

    # $1 = description
    # $2 = example syntax

    if [[ ${1: -1} = '!' ]]; then
        printf "\n* %s \n       %s\n" "$(tr "[a-z]" "[A-Z]" <<< "${1:0:1}")${1:1}" "$2"
    else
        printf "\n* %s:\n       %s\n" "$(tr "[a-z]" "[A-Z]" <<< "${1:0:1}")${1:1}" "$2"
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

    Session.Debug.To.Screen.IsNot && echo -en "\033[1K\r"

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

    DisplayLineSpaceIfNoneAlready
    Display "Usage: $(FormatAsScriptTitle) $(FormatAsHelpActions) $(FormatAsHelpPackages) $(FormatAsHelpOptions)"

    return 0

    }

Help.Basic.Example.Show()
    {

    DisplayAsProjectSyntaxIndentedExample "to learn more about available $(FormatAsHelpActions), type" 'actions'

    DisplayAsProjectSyntaxIndentedExample '' 'actions-all'

    DisplayAsProjectSyntaxIndentedExample "to learn more about available $(FormatAsHelpPackages), type" 'packages'

    DisplayAsProjectSyntaxIndentedExample "or, for more about available $(FormatAsHelpOptions), type" 'options'

    echo -e "\nThere's also $(FormatAsURL 'https://github.com/OneCDOnly/sherpa/wiki')"

    return 0

    }

Help.Actions.Show()
    {

    Help.Basic.Show
    DisplayLineSpaceIfNoneAlready
    Display "* $(FormatAsHelpActions) usage examples:"

    DisplayAsProjectSyntaxIndentedExample 'install the following packages' "install $(FormatAsHelpPackages)"

    DisplayAsProjectSyntaxIndentedExample 'uninstall the following packages' "uninstall $(FormatAsHelpPackages)"

    DisplayAsProjectSyntaxIndentedExample 'reinstall the following packages' "reinstall $(FormatAsHelpPackages)"

    DisplayAsProjectSyntaxIndentedExample 'upgrade the following packages and the internal applications' "upgrade $(FormatAsHelpPackages)"

    DisplayAsProjectSyntaxIndentedExample 'force-upgrade the following packages and the internal applications' "upgrade force $(FormatAsHelpPackages)"

    DisplayAsProjectSyntaxIndentedExample 'start the following packages and enable package icons' "start $(FormatAsHelpPackages)"

    DisplayAsProjectSyntaxIndentedExample 'stop the following packages and disable package icons' "stop $(FormatAsHelpPackages)"

    DisplayAsProjectSyntaxIndentedExample 'upgrade the internal applications only' "restart $(FormatAsHelpPackages)"

    DisplayAsProjectSyntaxIndentedExample 'backup the internal application configurations to the default backup location' "backup $(FormatAsHelpPackages)"

    DisplayAsProjectSyntaxIndentedExample 'restore the internal application configurations from the default backup location' "restore $(FormatAsHelpPackages)"

    DisplayAsProjectSyntaxExample "$(FormatAsHelpActions) to affect all packages can be seen with" 'actions-all'

    Help.BackupLocation.Show

    DisplayAsProjectSyntaxExample "multiple $(FormatAsHelpActions) are supported like this" 'install sabnzbd sickchill restart transmission uninstall lazy nzbget upgrade nzbtomedia'

    DisplayAsInfoExample "$(FormatAsHelpActions) may be specified in any order, but the package processing order-of-operations is (first ► last)" 'backup ► uninstall ► force-upgrade ► upgrade ► install ► reinstall ► restore ► restart'

    return 0

    }

Help.ActionsAll.Show()
    {

    Help.Basic.Show
    DisplayLineSpaceIfNoneAlready
    Display "* $(FormatAsHelpActions) usage examples:"

    DisplayAsProjectSyntaxIndentedExample 'install everything!' 'install-all'

    DisplayAsProjectSyntaxIndentedExample "uninstall everything! (except $(FormatAsPackageName Entware) for now)" 'uninstall-all-packages-please'

    DisplayAsProjectSyntaxIndentedExample "reinstall all installed packages (except $(FormatAsPackageName Entware) for now)" 'reinstall-all'

    DisplayAsProjectSyntaxIndentedExample 'upgrade all installed packages (including the internal applications)' 'upgrade-all'

    DisplayAsProjectSyntaxIndentedExample 'start all installed packages and enable package icons' 'start-all'

    DisplayAsProjectSyntaxIndentedExample 'stop all installed packages and disable package icons' 'stop-all'

    DisplayAsProjectSyntaxIndentedExample 'restart all installed packages (only upgrades the internal applications, not the packages)' 'restart-all'

    DisplayAsProjectSyntaxIndentedExample 'ensure all application dependencies are installed' 'check-all'

    DisplayAsProjectSyntaxIndentedExample 'list all installable packages' 'list'

    DisplayAsProjectSyntaxIndentedExample 'list only installed packages' 'list-installed'

    DisplayAsProjectSyntaxIndentedExample 'list only upgradable packages' 'list-upgradable'

    DisplayAsProjectSyntaxIndentedExample 'backup all application configurations to the default backup location' 'backup-all'

    DisplayAsProjectSyntaxIndentedExample 'restore all application configurations from the default backup location' 'restore-all'

    Help.BackupLocation.Show

    return 0

    }

Help.Packages.Show()
    {

    local package=''
    local package_name_message=''
    local package_note_message=''

    Help.Basic.Show
    DisplayLineSpaceIfNoneAlready
    Display "* $(FormatAsHelpPackages) may be one or more of the following (space-separated):\n"

    for package in $(QPKGs.Installable.Array); do
        if QPKGs.Upgradable.Exist $package; then
            package_name_message=$(ColourTextBrightOrange $package)
        else
            package_name_message=$package
        fi

        if [[ $package = Entware ]]; then       # KLUDGE: use this until independent package checking works.
            package_note_message='(installed by-default)'
        else
            package_note_message=''
        fi

        DisplayAsHelpPackageNameExample "$package_name_message" "$package_note_message"
    done

    DisplayAsProjectSyntaxExample "example: to install $(FormatAsPackageName SABnzbd)" 'install SABnzbd'

    DisplayAsProjectSyntaxExample "abbreviations may also be used to specify $(FormatAsHelpPackages). To see these" 'abs'

    return 0

    }

Help.Options.Show()
    {

    Help.Basic.Show
    DisplayLineSpaceIfNoneAlready
    Display "* $(FormatAsHelpOptions) usage examples:"

    DisplayAsProjectSyntaxIndentedExample 'process one or more packages and show live debugging information' "$(FormatAsHelpActions) $(FormatAsHelpPackages) debug"

    DisplayAsProjectSyntaxIndentedExample "don't check free-space on target filesystem when installing $(FormatAsPackageName Entware) packages" "$(FormatAsHelpActions) $(FormatAsHelpPackages) ignore-space"

    DisplayAsProjectSyntaxIndentedExample 'display helpful tips and shortcuts' 'tips'

    DisplayAsProjectSyntaxIndentedExample 'display troubleshooting options' 'problems'

    return 0

    }

Help.Problems.Show()
    {

    Help.Basic.Show
    DisplayLineSpaceIfNoneAlready
    Display '* usage examples when dealing with problems:'

    DisplayAsProjectSyntaxIndentedExample 'process one or more packages and show live debugging information' "$(FormatAsHelpActions) $(FormatAsHelpPackages) debug"

    DisplayAsProjectSyntaxIndentedExample 'ensure all application dependencies are installed' 'check-all'

    DisplayAsProjectSyntaxIndentedExample "don't check free-space on target filesystem when installing $(FormatAsPackageName Entware) packages" "$(FormatAsHelpActions) $(FormatAsHelpPackages) ignore-space"

    DisplayAsProjectSyntaxIndentedExample "clean the $(FormatAsScriptTitle) cache" 'clean'

    DisplayAsProjectSyntaxIndentedExample 'restart all installed packages (upgrades the internal applications, not the packages)' 'restart-all'

    DisplayAsProjectSyntaxIndentedExample "view only the most recent $(FormatAsScriptTitle) session log" 'l'

    DisplayAsProjectSyntaxIndentedExample "upload the most-recent session in your $(FormatAsScriptTitle) log to the $(FormatAsURL 'https://termbin.com') public pastebin. A URL will be generated afterward" 'p'

    DisplayAsProjectSyntaxIndentedExample "view the entire $(FormatAsScriptTitle) session log" 'log'

    DisplayAsProjectSyntaxIndentedExample "upload the most-recent $(printf "%'.f" $LOG_TAIL_LINES) entries in your $(FormatAsScriptTitle) log to the $(FormatAsURL 'https://termbin.com') public pastebin. A URL will be generated afterward" 'paste'

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

    DisplayAsProjectSyntaxIndentedExample "upload the most-recent $(printf "%'.f" $LOG_TAIL_LINES) entries in your $(FormatAsScriptTitle) log to the $(FormatAsURL 'https://termbin.com') public pastebin. A URL will be generated afterward" 'paste'

    Display "\n$(ColourTextBrightOrange '* If you need help, please include a copy of your') $(FormatAsScriptTitle) $(ColourTextBrightOrange 'log for analysis!')"

    return 0

    }

Help.Tips.Show()
    {

    Help.Basic.Show
    DisplayLineSpaceIfNoneAlready
    Display '* helpful tips and shortcuts:'

    DisplayAsProjectSyntaxIndentedExample "install all available $(FormatAsScriptTitle) packages" 'install-all'

    DisplayAsProjectSyntaxIndentedExample 'package abbreviations also work. To see these' 'abs'

    DisplayAsProjectSyntaxIndentedExample 'ensure all application dependencies are installed' 'check-all'

    DisplayAsProjectSyntaxIndentedExample 'restart all packages (only upgrades the internal applications, not the packages)' 'restart-all'

    DisplayAsProjectSyntaxIndentedExample 'upgrade all installed packages (including the internal applications)' 'upgrade-all'

    DisplayAsProjectSyntaxIndentedExample 'list only packages that are not installed' 'list-installable'

    DisplayAsProjectSyntaxIndentedExample 'list only independent packages' 'list-independent'

    DisplayAsProjectSyntaxIndentedExample 'list only dependant packages' 'list-dependant'

    DisplayAsProjectSyntaxIndentedExample "upload the most-recent $(printf "%'.f" $LOG_TAIL_LINES) entries in your $(FormatAsScriptTitle) log to the $(FormatAsURL 'https://termbin.com') public pastebin. A URL will be generated afterward" 'paste'

    DisplayAsProjectSyntaxIndentedExample 'display all package-manager scripts versions' 'version'

    Help.BackupLocation.Show

    echo -e "\n$(ColourTextBrightOrange '* If you need help, please include a copy of your') $(FormatAsScriptTitle) $(ColourTextBrightOrange 'log for analysis!')"

    return 0

    }

Help.PackageAbbreviations.Show()
    {

    [[ ${#SHERPA_QPKG_NAME[@]} -eq 0 || ${#SHERPA_QPKG_ABBRVS[@]} -eq 0 ]] && return 1

    local package_index=0
    Help.Basic.Show
    DisplayLineSpaceIfNoneAlready
    echo -e "* $(FormatAsScriptTitle) recognises these abbreviations as $(FormatAsHelpPackages):"

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

    DisplayAsSyntaxExample 'the default backup location can be accessed by running' "cd $(Session.Backup.Path)"

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
        ShowAsError 'no session log to display'
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
        ShowAsError 'no last session log to display'
    fi

    return 0

    }

Log.Tail.Paste.Online()
    {

    ExtractTailFromLog

    if [[ -e $SESSION_TAIL_PATHFILE ]]; then
        if AskQuiz "Press 'Y' to post the most-recent $(printf "%'.f" $LOG_TAIL_LINES) entries in your $(FormatAsScriptTitle) log to a public pastebin, or any other key to abort"; then
            ShowAsProc "uploading $(FormatAsScriptTitle) log"
            # with thanks to https://github.com/solusipse/fiche
            link=$($CAT_CMD -n "$SESSION_TAIL_PATHFILE" | (exec 3<>/dev/tcp/termbin.com/9999; $CAT_CMD >&3; $CAT_CMD <&3; exec 3<&-))

            if [[ $? -eq 0 ]]; then
                ShowAsDone "your $(FormatAsScriptTitle) log is now online at $(FormatAsURL "$($SED_CMD 's|http://|http://l.|;s|https://|https://l.|' <<< "$link")") and will be deleted in 1 month"
            else
                ShowAsError "a link could not be generated. Most likely a problem occurred when talking with $(FormatAsURL 'https://termbin.com')"
            fi
        else
            DebugInfoMinorSeparator
            DebugScript 'user abort'
            Session.Summary.Clear
            return 1
        fi
    else
        ShowAsError 'no tail log to paste'
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
                ShowAsError "a link could not be generated. Most likely a problem occurred when talking with $(FormatAsURL 'https://termbin.com')"
            fi
        else
            DebugInfoMinorSeparator
            DebugScript 'user abort'
            Session.Summary.Clear
            return 1
        fi
    else
        ShowAsError 'no last session log to paste'
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

    Display "objects hash: $COMPILED_OBJECTS_HASH"
    Display "manager: $MANAGER_SCRIPT_VERSION"
    Display "loader: $LOADER_SCRIPT_VERSION"
    Display "package: $PACKAGE_VERSION"

    return 0

    }

QPKGs.NewVersions.Show()
    {

    # Check installed QPKGs and compare versions against package arrays. If new versions are available, advise on-screen.

    # $? = 0 if all packages are up-to-date
    # $? = 1 if one or more packages can be upgraded

    local msg=''
    local index=0
    local left_to_upgrade=()
    local names_formatted=''

    QPKGs.StateLists.Build

    for package in $(QPKGs.Upgradable.Array); do
        if ! QPKGs.ToUpgrade.Exist $package; then
            left_to_upgrade+=($package)
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
        msg='an upgraded package is'
    else
        msg='upgraded packages are'
    fi

    ShowAsNote "$msg available for $names_formatted"
    return 1

    }

QPKGs.Conflicts.Check()
    {

    for package in "${SHERPA_COMMON_CONFLICTS[@]}"; do
        if QPKG.Enabled $package; then
            ShowAsError "'$package' is installed and enabled. One-or-more $(FormatAsScriptTitle) applications are incompatible with this package"
            return 1
        fi
    done

    return 0

    }

QPKGs.Assignment.Check()
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
    #  17. backup                   (highest: most-important)
    #  16. stop dependants
    #  15. stop independents
    #  14. uninstall
    #  13. force-upgrade independents
    #  12. upgrade independents
    #  11. reinstall independents
    #  10. install independents
    #   9. restore independents
    #   8. start independents
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
    local download_acc=()
    QPKGs.StateLists.Build

    # start by adding packages to lists as required:

    if User.Opts.Apps.All.Backup.IsSet; then
        for package in $(QPKGs.Installed.Array); do
            QPKGs.ToBackup.Add $package
        done
    fi

    if User.Opts.Apps.All.Uninstall.IsSet; then
        for package in $(QPKGs.Installed.Array); do
            QPKGs.ToUninstall.Add $package
        done
    fi

    if User.Opts.Apps.All.Stop.IsSet; then
        for package in $(QPKGs.Installed.Array); do
            QPKGs.ToStop.Add $package
        done
    fi

    if User.Opts.Apps.All.Upgrade.IsSet; then
        for package in $(QPKGs.Upgradable.Array); do
            QPKGs.ToUpgrade.Add $package
        done
    fi

    # check for independent packages that require installation
    for package in $(QPKGs.Installed.Array); do
        ! QPKGs.ToUninstall.Exist $package && installer_acc+=($(QPKG.Get.Independencies $package))
    done

    for package in $(QPKGs.ToInstall.Array); do
        installer_acc+=($(QPKG.Get.Independencies $package))
    done

    for package in $(QPKGs.ToReinstall.Array); do
        installer_acc+=($(QPKG.Get.Independencies $package))
    done

    for package in $(QPKGs.ToUpgrade.Array); do
        installer_acc+=($(QPKG.Get.Independencies $package))
    done

    for package in $(QPKGs.ToForceUpgrade.Array); do
        installer_acc+=($(QPKG.Get.Independencies $package))
    done

    for package in "${installer_acc[@]}"; do
        ! QPKG.Installed $package && QPKGs.ToInstall.Add $package
    done

    if User.Opts.Apps.All.Install.IsSet; then
        for package in $(QPKGs.Installable.Array); do
            QPKGs.ToInstall.Add $package
        done
    fi

    if User.Opts.Apps.All.Reinstall.IsSet; then
        for package in $(QPKGs.Installed.Array); do
            QPKGs.ToReinstall.Add $package
        done
    fi

    if User.Opts.Apps.All.Restore.IsSet; then
        for package in $(QPKGs.Installed.Array); do
            QPKGs.ToRestore.Add $package
        done
    fi

    if User.Opts.Apps.All.Start.IsSet; then
        for package in $(QPKGs.Installed.Array); do
            QPKGs.ToStart.Add $package
        done
    fi

    if User.Opts.Apps.All.Restart.IsSet; then
        for package in $(QPKGs.Installed.Array); do
            QPKGs.ToRestart.Add $package
        done
    fi

    # build an initial package download list. Items on this list will be skipped at download-time if they can be found in local cache.

    if User.Opts.Dependencies.Check.IsSet; then
        download_acc+=($(QPKGs.Installed.Array))
    else
        download_acc+=($(QPKGs.ToInstall.List))
        download_acc+=($(QPKGs.ToReinstall.List))
        download_acc+=($(QPKGs.ToUpgrade.List))
        download_acc+=($(QPKGs.ToForceUpgrade.List))
    fi

    for package in "${download_acc[@]}"; do
        QPKGs.ToDownload.Add $package
    done

    QPKGs.Assignment.List
    DebugFuncExit; return 0

    }

QPKGs.Assignment.List()
    {

    DebugFuncEntry

    DebugQPKG 'to download' "$(QPKGs.ToDownload.ListComma) "
    DebugQPKG 'to backup' "$(QPKGs.ToBackup.ListComma) "
    DebugQPKG 'to uninstall' "$(QPKGs.ToUninstall.ListComma) "
    DebugQPKG 'to stop' "$(QPKGs.ToStop.ListComma) "
    DebugQPKG 'to force-upgrade' "$(QPKGs.ToForceUpgrade.ListComma) "
    DebugQPKG 'to upgrade' "$(QPKGs.ToUpgrade.ListComma) "
    DebugQPKG 'to reinstall' "$(QPKGs.ToReinstall.ListComma) "
    DebugQPKG 'to install' "$(QPKGs.ToInstall.ListComma) "
    DebugQPKG 'to restore' "$(QPKGs.ToRestore.ListComma) "
    DebugQPKG 'to start' "$(QPKGs.ToStart.ListComma) "
    DebugQPKG 'to restart' "$(QPKGs.ToRestart.ListComma) "

    DebugFuncExit; return 0

    }

QPKGs.NotUpgraded.Restart()
    {

    # restart all sherpa QPKGs except those that were just upgraded.

    QPKGs.Dependant.IsNone && return
    DebugFuncEntry
    local package=''

    for package in $(QPKGs.Dependant.Array); do
        QPKG.Enabled $package && ! QPKGs.Upgradable.Exist $package && QPKG.Restart $package
    done

    DebugFuncExit; return 0

    }

QPKGs.StateLists.Build()
    {

    QPKGs.DepAndIndep.Build
    QPKGs.InstallationState.Build
    QPKGs.Upgradable.Build

    }

QPKGs.DepAndIndep.Build()
    {

    # Independent packages don't depend on other packages. These are therefore independent. They should be installed/started before any dependant QPKGs.
    # Dependant packages depend on other QPKGs. These are therefore dependant. They should be installed/started after any independent QPKGs.

    DebugFuncEntry
    local index=0

    for index in "${!SHERPA_QPKG_NAME[@]}"; do
        if [[ -n ${SHERPA_QPKG_INDEPS[$index]} ]]; then
            QPKGs.Dependant.Add "${SHERPA_QPKG_NAME[$index]}"
        else
            QPKGs.Independent.Add "${SHERPA_QPKG_NAME[$index]}"
        fi
    done

    DebugFuncExit; return 0

    }

QPKGs.InstallationState.Build()
    {

    # Builds a list of QPKGs that can be installed or reinstalled by the user.

    DebugFuncEntry
    local package=''

    for package in $(QPKGs.Names.Array); do
        QPKG.UserInstallable $package && QPKGs.Installable.Add $package

        if QPKG.Installed $package; then
            QPKGs.Installed.Add $package
        else
            QPKGs.NotInstalled.Add $package
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
        [[ $package = Entware || $package = Par2 ]] && continue        # KLUDGE: ignore 'Entware' as package filename version doesn't match the QTS App Center version string
        installed_version=$(QPKG.InstalledVersion $package)
        remote_version=$(QPKG.URLVersion $package)

        if [[ $installed_version != "$remote_version" ]]; then
            #QPKGs.Upgradable.Add "$package $installed_version $remote_version"
            QPKGs.Upgradable.Add $package
        fi
    done

    DebugFuncExit; return 0

    }

QPKGs.All.Show()
    {

    local package=''

    for package in $(QPKGs.Names.Array); do
        echo $package
    done

    return 0

    }

QPKGs.Installed.Show()
    {

    local package=''
    QPKGs.StateLists.Build

    for package in $(QPKGs.Installed.Array); do
        echo $package
    done

    return 0

    }

QPKGs.NotInstalled.Show()
    {

    local package=''
    QPKGs.StateLists.Build

    for package in $(QPKGs.NotInstalled.Array); do
        echo $package
    done

    return 0

    }

QPKGs.Upgradable.Show()
    {

    local package=''
    QPKGs.StateLists.Build

    for package in $(QPKGs.Upgradable.Array); do
        echo $package
    done

    return 0

    }

QPKGs.Independent.Show()
    {

    local package=''
    QPKGs.StateLists.Build

    for package in $(QPKGs.Independent.Array); do
        echo $package
    done

    return 0

    }

QPKGs.Dependant.Show()
    {

    local package=''
    QPKGs.StateLists.Build

    for package in $(QPKGs.Dependant.Array); do
        echo $package
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

    return 0

    }

Session.AdjustPathEnv()
    {

    local opkg_prefix=/opt/bin:/opt/sbin

    if QPKG.Installed Entware; then
        export PATH="$opkg_prefix:$($SED_CMD "s|$opkg_prefix||" <<< "$PATH")"
        DebugDone 'adjusted $PATH for Entware'
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
            ShowAsDone 'no QPKGs need upgrading'
        elif Session.Error.IsNot; then
            ShowAsDone 'all upgradable QPKGs were successfully upgraded'
        else
            ShowAsError "upgrade failed! [$code_pointer]"
            Session.SuggestIssue.Set
        fi
    fi

    return 0

    }

Session.LockFile.Claim()
    {

    [[ -z $1 ]] && return 1
    readonly RUNTIME_LOCK_PATHFILE=$1

    if [[ -e $RUNTIME_LOCK_PATHFILE && -d /proc/$(<$RUNTIME_LOCK_PATHFILE) && $(</proc/"$(<$RUNTIME_LOCK_PATHFILE)"/cmdline) =~ $MANAGER_SCRIPT_FILE ]]; then
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
                ShowAsError "$(FormatAsPackageName "$1") service failed to start.$([[ -e /var/log/$1.log ]] && echo " Check $(FormatAsFileName "/var/log/$1.log") for more information")"
                ;;
            *)
                DebugWarning "$(FormatAsPackageName "$1") service status is incorrect"
                ;;
        esac
    else
        DebugWarning "unable to get status of $(FormatAsPackageName "$1") service. It may be a non-sherpa package, or a package earlier than 200816c that doesn't support service results."
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

QPKG.Get.Independencies()
    {

    # input:
    #   $1 = dependant QPKG name to return independencies for

    # output:
    #   $? = 0 if successful, 1 if failed

    local index=0

    for index in "${!SHERPA_QPKG_NAME[@]}"; do
        if [[ ${SHERPA_QPKG_NAME[$index]} = "$1" ]]; then
            echo "${SHERPA_QPKG_INDEPS[$index]}"
            return 0
        fi
    done

    return 1

    }

QPKG.Get.Dependencies()
    {

    # input:
    #   $1 = independent QPKG name to return dependants for

    # output:
    #   $? = 0 if successful, 1 if failed

    local index=0
    local acc=()

    if QPKGs.Independent.Exist $1; then
        for index in "${!SHERPA_QPKG_NAME[@]}"; do
            if [[ ${SHERPA_QPKG_INDEPS[$index]} == *"$1"* ]]; then
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
    #   $? = 0 if successful, 1 if failed

    Session.Error.IsSet && return
    DebugFuncEntry

    if [[ -z $1 ]]; then
        DebugFuncExit; return 1
    fi

    local result=0
    local remote_url=$(QPKG.URL "$1")
    local remote_filename=$($BASENAME_CMD "$remote_url")
    local remote_md5=$(QPKG.MD5 "$1")
    local local_pathfile=$QPKG_DL_PATH/$remote_filename
    local local_filename=$($BASENAME_CMD "$local_pathfile")
    local log_pathfile=$LOGS_PATH/$local_filename.$DOWNLOAD_LOG_FILE

    if [[ -z $remote_url ]]; then
        DebugWarning "no URL found for this package $(FormatAsPackageName "$1")"
        code_pointer=6
        DebugFuncExit; return
    elif [[ -z $remote_md5 ]]; then
        DebugWarning "no checksum found for this package $(FormatAsPackageName "$1")"
        code_pointer=7
        DebugFuncExit; return
    fi

    if [[ -e $local_pathfile ]]; then
        if FileMatchesMD5 "$local_pathfile" "$remote_md5"; then
            DebugInfo "local package $(FormatAsFileName "$local_filename") checksum correct, so skipping download"
        else
            DebugWarning "local package $(FormatAsFileName "$local_filename") checksum incorrect"
            DebugInfo "deleting $(FormatAsFileName "$local_filename")"
            rm -f "$local_pathfile"
        fi
    fi

    if Session.Error.IsNot && [[ ! -e $local_pathfile ]]; then
        ShowAsProc "downloading $(FormatAsFileName "$remote_filename")"

        [[ -e $log_pathfile ]] && rm -f "$log_pathfile"

        if Session.Debug.To.Screen.IsSet; then
            RunThisAndLogResultsRealtime "$CURL_CMD${curl_insecure_arg} --output $local_pathfile $remote_url" "$log_pathfile"
            result=$?
        else
            RunThisAndLogResults "$CURL_CMD${curl_insecure_arg} --output $local_pathfile $remote_url" "$log_pathfile"
            result=$?
        fi

        if [[ $result -eq 0 ]]; then
            if FileMatchesMD5 "$local_pathfile" "$remote_md5"; then
                ShowAsDone "downloaded $(FormatAsFileName "$remote_filename")"
            else
                ShowAsError "downloaded package $(FormatAsFileName "$local_pathfile") checksum incorrect"
                result=1
            fi
        else
            ShowAsError "download failed $(FormatAsFileName "$local_pathfile") $(FormatAsExitcode $result)"
        fi
    fi

    DebugFuncExit; return $result

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
    local result=0
    local local_pathfile=$(QPKG.PathFilename "$1")
    local log_pathfile=''

    if [[ ${local_pathfile##*.} = zip ]]; then
        $UNZIP_CMD -nq "$local_pathfile" -d "$QPKG_DL_PATH"
        local_pathfile=${local_pathfile%.*}
    fi

    target_file=$($BASENAME_CMD "$local_pathfile")
    log_pathfile=$LOGS_PATH/$target_file.$INSTALL_LOG_FILE

    ShowAsProcLong "installing $(FormatAsPackageName "$1")"

    if Session.Debug.To.Screen.IsSet; then
        RunThisAndLogResultsRealtime "$SH_CMD $local_pathfile" "$log_pathfile"
        result=$?
    else
        RunThisAndLogResults "$SH_CMD $local_pathfile" "$log_pathfile"
        result=$?
    fi

    if [[ $result -eq 0 || $result -eq 10 ]]; then
        ShowAsDone "installed $(FormatAsPackageName "$1")"
        QPKG.ServiceStatus "$1"
        QPKGs.JustInstalled.Add "$1"
        QPKGs.JustStarted.Add "$1"
        QPKGs.ToStart.Remove "$1"
        QPKGs.ToReinstall.Remove "$1"
        QPKGs.ToRestart.Remove "$1"
    else
        ShowAsError "installation failed $(FormatAsFileName "$target_file") $(FormatAsExitcode $result)"
    fi

    DebugFuncExit; return $result

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
    local result=0
    local local_pathfile=$(QPKG.PathFilename "$1")
    local log_pathfile=''

    if [[ ${local_pathfile##*.} = zip ]]; then
        $UNZIP_CMD -nq "$local_pathfile" -d "$QPKG_DL_PATH"
        local_pathfile=${local_pathfile%.*}
    fi

    target_file=$($BASENAME_CMD "$local_pathfile")
    log_pathfile=$LOGS_PATH/$target_file.$REINSTALL_LOG_FILE

    ShowAsProcLong "re-installing $(FormatAsPackageName "$1")"

    if Session.Debug.To.Screen.IsSet; then
        RunThisAndLogResultsRealtime "$SH_CMD $local_pathfile" "$log_pathfile"
        result=$?
    else
        RunThisAndLogResults "$SH_CMD $local_pathfile" "$log_pathfile"
        result=$?
    fi

    if [[ $result -eq 0 || $result -eq 10 ]]; then
        ShowAsDone "re-installed $(FormatAsPackageName "$1")"
        QPKG.ServiceStatus "$1"
        QPKGs.JustInstalled.Add "$1"
        QPKGs.JustStarted.Add "$1"
        QPKGs.ToStart.Remove "$1"
        QPKGs.ToInstall.Remove "$1"
        QPKGs.ToRestart.Remove "$1"
    else
        ShowAsError "re-installation failed $(FormatAsFileName "$target_file") $(FormatAsExitcode $result)"
    fi

    DebugFuncExit; return $result

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
    local result=0
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

    ShowAsProcLong "${prefix}upgrading $(FormatAsPackageName "$1")"

    if Session.Debug.To.Screen.IsSet; then
        RunThisAndLogResultsRealtime "$SH_CMD $local_pathfile" "$log_pathfile"
        result=$?
    else
        RunThisAndLogResults "$SH_CMD $local_pathfile" "$log_pathfile"
        result=$?
    fi

    current_version=$(QPKG.InstalledVersion "$1")

    if [[ $result -eq 0 || $result -eq 10 ]]; then
        if [[ $current_version = "$previous_version" ]]; then
            DebugDone "${prefix}upgraded $(FormatAsPackageName "$1") and installed version is $current_version"
        else
            ShowAsDone "${prefix}upgraded $(FormatAsPackageName "$1") from $previous_version to $current_version"
        fi
        QPKG.ServiceStatus "$1"
        QPKGs.JustInstalled.Add "$1"
        QPKGs.JustStarted.Add "$1"
        QPKGs.ToStart.Remove "$1"
        QPKGs.ToInstall.Remove "$1"
        QPKGs.ToReinstall.Remove "$1"
        QPKGs.ToRestart.Remove "$1"
    else
        ShowAsError "${prefix}upgrade failed $(FormatAsFileName "$target_file") $(FormatAsExitcode $result)"
    fi

    DebugFuncExit; return $result

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

    local result=0
    local qpkg_installed_path=$($GETCFG_CMD "$1" Install_Path -f $APP_CENTER_CONFIG_PATHFILE)
    local log_pathfile=$LOGS_PATH/$1.$UNINSTALL_LOG_FILE

    if [[ -e $qpkg_installed_path/.uninstall.sh ]]; then
        ShowAsProc "uninstalling $(FormatAsPackageName "$1")"

        if Session.Debug.To.Screen.IsSet; then
            RunThisAndLogResultsRealtime "$SH_CMD $qpkg_installed_path/.uninstall.sh" "$log_pathfile"
            result=$?
        else
            RunThisAndLogResults "$SH_CMD $qpkg_installed_path/.uninstall.sh" "$log_pathfile"
            result=$?
        fi

        if [[ $result -eq 0 ]]; then
            ShowAsDone "uninstalled $(FormatAsPackageName "$1")"
            $RMCFG_CMD "$1" -f $APP_CENTER_CONFIG_PATHFILE
            DebugDone 'removed icon information from App Center'
        else
            ShowAsError "unable to uninstall $(FormatAsPackageName "$1") $(FormatAsExitcode $result)"
        fi
    fi

    DebugFuncExit; return $result

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

    local result=0
    local log_pathfile=$LOGS_PATH/$1.$RESTART_LOG_FILE

    ShowAsProc "restarting $(FormatAsPackageName "$1")"

    if Session.Debug.To.Screen.IsSet; then
        RunThisAndLogResultsRealtime "$QPKG_SERVICE_CMD restart $1" "$log_pathfile"
        result=$?
    else
        RunThisAndLogResults "$QPKG_SERVICE_CMD restart $1" "$log_pathfile"
        result=$?
    fi

    if [[ $result -eq 0 ]]; then
        ShowAsDone "restarted $(FormatAsPackageName "$1")"
        QPKG.ServiceStatus "$1"
        QPKGs.JustStarted.Add "$1"
        QPKGs.ToStart.Remove "$1"
    else
        ShowAsWarning "Could not restart $(FormatAsPackageName "$1") $(FormatAsExitcode $result)"
    fi

    DebugFuncExit; return $result

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

    local result=0
    local log_pathfile=$LOGS_PATH/$1.$START_LOG_FILE

    ShowAsProc "starting $(FormatAsPackageName "$1")"

    if Session.Debug.To.Screen.IsSet; then
        RunThisAndLogResultsRealtime "$QPKG_SERVICE_CMD start $1" "$log_pathfile"
        result=$?
    else
        RunThisAndLogResults "$QPKG_SERVICE_CMD start $1" "$log_pathfile"
        result=$?
    fi

    if [[ $result -eq 0 ]]; then
        ShowAsDone "started $(FormatAsPackageName "$1")"
        QPKG.ServiceStatus "$1"
        QPKGs.JustStarted.Add "$1"
        QPKGs.ToRestart.Remove "$1"
    else
        ShowAsWarning "Could not start $(FormatAsPackageName "$1") $(FormatAsExitcode $result)"
    fi

    DebugFuncExit; return $result

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

    local result=0
    local log_pathfile=$LOGS_PATH/$1.$STOP_LOG_FILE

    ShowAsProc "stopping $(FormatAsPackageName "$1")"

    if Session.Debug.To.Screen.IsSet; then
        RunThisAndLogResultsRealtime "$QPKG_SERVICE_CMD stop $1" "$log_pathfile"
        result=$?
    else
        RunThisAndLogResults "$QPKG_SERVICE_CMD stop $1" "$log_pathfile"
        result=$?
    fi

    if [[ $result -eq 0 ]]; then
        ShowAsDone "stopped $(FormatAsPackageName "$1")"
        QPKG.ServiceStatus "$1"
        QPKGs.JustStarted.Remove "$1"
    else
        ShowAsWarning "Could not stop $(FormatAsPackageName "$1") $(FormatAsExitcode $result)"
    fi

    DebugFuncExit; return $result

    }

QPKG.Enable()
    {

    # $1 = package name to enable

    DebugFuncEntry

    if [[ -z $1 ]]; then
        DebugFuncExit; return 1
    fi

    local result=0
    local log_pathfile=$LOGS_PATH/$1.$ENABLE_LOG_FILE

    if QPKG.NotEnabled "$1"; then
        if Session.Debug.To.Screen.IsSet; then
            RunThisAndLogResultsRealtime "$QPKG_SERVICE_CMD enable $1" "$log_pathfile"
            result=$?
        else
            RunThisAndLogResults "$QPKG_SERVICE_CMD enable $1" "$log_pathfile"
            result=$?
        fi

        if [[ $result -eq 0 ]]; then
            QPKG.ServiceStatus "$1"
        else
            ShowAsWarning "Could not enable $(FormatAsPackageName "$1") $(FormatAsExitcode $result)"
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

    local result=0
    local log_pathfile=$LOGS_PATH/$1.$DISABLE_LOG_FILE

    if QPKG.Enabled "$1"; then
        if Session.Debug.To.Screen.IsSet; then
            RunThisAndLogResultsRealtime "$QPKG_SERVICE_CMD disable $1" "$log_pathfile"
            result=$?
        else
            RunThisAndLogResults "$QPKG_SERVICE_CMD disable $1" "$log_pathfile"
            result=$?
        fi

        if [[ $result -eq 0 ]]; then
            QPKG.ServiceStatus "$1"
        else
            ShowAsWarning "Could not disable $(FormatAsPackageName "$1") $(FormatAsExitcode $result)"
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

    local result=0
    local package_init_pathfile=$(QPKG.ServicePathFile "$1")
    local log_pathfile=$LOGS_PATH/$1.$BACKUP_LOG_FILE

    ShowAsProc "backing-up $(FormatAsPackageName "$1") configuration"

    if Session.Debug.To.Screen.IsSet; then
        RunThisAndLogResultsRealtime "$SH_CMD $package_init_pathfile backup" "$log_pathfile"
        result=$?
    else
        RunThisAndLogResults "$SH_CMD $package_init_pathfile backup" "$log_pathfile"
        result=$?
    fi

    if [[ $result -eq 0 ]]; then
        ShowAsDone "backed-up $(FormatAsPackageName "$1") configuration"
        QPKG.ServiceStatus "$1"
    else
        ShowAsWarning "Could not backup $(FormatAsPackageName "$1") configuration $(FormatAsExitcode $result)"
    fi

    DebugFuncExit; return $result

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

    local result=0
    local package_init_pathfile=$(QPKG.ServicePathFile "$1")
    local log_pathfile=$LOGS_PATH/$1.$RESTORE_LOG_FILE

    ShowAsProc "restoring $(FormatAsPackageName "$1") configuration"

    if Session.Debug.To.Screen.IsSet; then
        RunThisAndLogResultsRealtime "$SH_CMD $package_init_pathfile restore" "$log_pathfile"
        result=$?
    else
        RunThisAndLogResults "$SH_CMD $package_init_pathfile restore" "$log_pathfile"
        result=$?
    fi

    if [[ $result -eq 0 ]]; then
        ShowAsDone "restored $(FormatAsPackageName "$1") configuration"
        QPKG.ServiceStatus "$1"
    else
        ShowAsWarning "Could not restore $(FormatAsPackageName "$1") configuration $(FormatAsExitcode $result)"
    fi

    DebugFuncExit; return $result

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

MakePath()
    {

    [[ -z $1 || -z $2 ]] && return 1

    mkdir -p "$1" 2> /dev/null; result=$?

    if [[ $result -ne 0 ]]; then
        ShowAsError "unable to create $2 path $(FormatAsFileName "$1") $(FormatAsExitcode $result)"
        [[ $(type -t Session.SuggestIssue.Init) = 'function' ]] && Session.SuggestIssue.Set
        return 1
    fi

    return 0

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
                Display "${SHERPA_QPKG_NAME[$package_index]}"
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
    #   $3 'log:failure-only' (optional) - if specified, stdout & stderr are only recorded in the specified log if the command failed.
    #                                    - if unspecified, stdout & stderr is always recorded.

    # output:
    #   $? = result code of command string

    [[ -z $1 || -z $2 ]] && return 1
    DebugFuncEntry

    local msgs=/var/log/execd.log
    local result=0


    FormatAsCommand "$1" > "$2"
    $1 >> "$msgs" 2>&1
    result=$?
    FormatAsResultAndStdout "$result" "$(<"$msgs")" >> "$2"
    [[ -e $msgs ]] && rm -f "$msgs"

    if [[ $result -eq 0 && $3 != log:failure-only ]] || [[ $reset -ne 0 ]]; then
        AddFileToDebug "$2"
    fi

    DebugFuncExit; return $result

    }

RunThisAndLogResultsRealtime()
    {

    # Run a command string, show and log the results

    # input:
    #   $1 = command string to execute
    #   $2 = pathfilename to record this operation in
    #   $3 'log:failure-only' (optional) - if specified, stdout & stderr are only recorded in the specified log if the command failed.
    #                                    - if unspecified, stdout & stderr is always recorded.

    # output:
    #   $? = result code of executed command

    [[ -z $1 || -z $2 ]] && return 1
    DebugFuncEntry

    local msgs=/var/log/execd.log
    local result=0

    FormatAsCommand "$1" > "$2"
    $1 > >($TEE_CMD -a "$msgs") 2>&1
    result=$?

    if [[ -e $msgs ]]; then
        FormatAsResultAndStdout "$result" "$(<"$msgs")" >> "$2"
        rm -f "$msgs"
    else
        FormatAsResultAndStdout "$result" "<null>" >> "$2"
    fi

    if [[ $result -eq 0 && $3 != log:failure-only ]] || [[ $reset -ne 0 ]]; then
        AddFileToDebug "$2"
    fi

    DebugFuncExit; return $result

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

ProgressUpdater()
    {

    # input:
    #   $1 = message to display

    if [[ $1 != "$previous_msg" ]]; then
        temp=$1
        current_length=$((${#temp}+1))

        if [[ $current_length -lt $previous_length ]]; then
            appended_length=$((current_length-previous_length))
            # backspace to start of previous msg, print new msg, add additional spaces, then backspace to end of msg
            printf "%${previous_length}s" | tr ' ' '\b'; echo -n "$1 "; printf "%${appended_length}s"; printf "%${appended_length}s" | tr ' ' '\b'
        else
            # backspace to start of previous msg, print new msg
            printf "%${previous_length}s" | tr ' ' '\b'; echo -n "$1 "
        fi

        previous_length=$current_length
        previous_msg=$1
    fi

    }

#### FormatAs... functions always output formatted info to be used as part of another string. These shouldn't be used for direct screen output.

FormatAsPlural()
    {

    [[ $1 -ne 1 ]] && echo 's'

    }

FormatAsISOBytes()
    {

    echo "$1" | $AWK_CMD 'BEGIN{ u[0]="B"; u[1]="kB"; u[2]="MB"; u[3]="GB"} { n = $1; i = 0; while(n > 1000) { i+=1; n= int((n/1000)+0.5) } print n u[i] } '

    }

FormatAsScriptTitle()
    {

    ColourTextBrightWhite "$PROJECT_NAME"

    }

FormatAsHelpActions()
    {

    ColourTextBrightYellow '[actions]'

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
        echo "= result: $(FormatAsExitcode "$1")"
    else
        echo "! result: $(FormatAsExitcode "$1")"
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
        echo "= result: $(FormatAsExitcode "$1") ***** stdout/stderr begins below *****"
    else
        echo "! result: $(FormatAsExitcode "$1") ***** stdout/stderr begins below *****"
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

DebugFirmware()
    {

    DebugDetected.OK "$(FormatAsFirmware)" "$1" "$2"

    }

DebugUserspace.OK()
    {

    DebugDetected.OK "$(FormatAsUserspace)" "$1" "$2"

    }

DebugUserspace.Warning()
    {

    DebugDetected.Warning "$(FormatAsUserspace)" "$1" "$2"

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
        elapsed_time=$(printf "%'.fms" $diff_milliseconds)
    else
        elapsed_time=$(ConvertSecsToHoursMinutesSecs "$((diff_milliseconds/1000))")
    fi

    DebugThis "(<<) ${FUNCNAME[1]}()|$code_pointer|$elapsed_time"

    }

DebugProc()
    {

    DebugThis "(==) $1 ..."

    }

DebugDone()
    {

    DebugThis "(--) $1"

    }

DebugDetected.Warning()
    {

    if [[ -z $3 ]]; then                # if $3 is nothing, then assume only 2 fields are required
        DebugWarning "$(printf "%9s: %23s\n" "$1" "$2")"
    elif [[ $3 = ' ' ]]; then           # if $3 is only a whitespace then print $2 with trailing colon but no third field
        DebugWarning "$(printf "%9s: %23s:\n" "$1" "$2")"
    elif [[ ${3: -1} = ' ' ]]; then     # if $3 has a trailing whitespace then print $3 without the trailing whitespace
        DebugWarning "$(printf "%9s: %23s: %-s\n" "$1" "$2" "$($SED_CMD 's| *$||' <<< "$3")")"
    else
        DebugWarning "$(printf "%9s: %23s: %-s\n" "$1" "$2" "$3")"
    fi

    }

DebugDetected.OK()
    {

    if [[ -z $3 ]]; then                # if $3 is nothing, then assume only 2 fields are required
        DebugDetected "$(printf "%9s: %23s\n" "$1" "$2")"
    elif [[ $3 = ' ' ]]; then           # if $3 is only a whitespace then print $2 with trailing colon but no third field
        DebugDetected "$(printf "%9s: %23s:\n" "$1" "$2")"
    elif [[ ${3: -1} = ' ' ]]; then     # if $3 has a trailing whitespace then print $3 without the trailing whitespace
        DebugDetected "$(printf "%9s: %23s: %-s\n" "$1" "$2" "$($SED_CMD 's| *$||' <<< "$3")")"
    else
        DebugDetected "$(printf "%9s: %23s: %-s\n" "$1" "$2" "$3")"
    fi

    }

DebugDetected()
    {

    DebugThis "(**) $1"

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

ShowAsProc()
    {

    WriteToDisplay.Wait "$(ColourTextBrightOrange proc)" "$1 ..."
    WriteToLog proc "$1 ..."
    [[ $(type -t Session.Debug.To.Screen.Init) = 'function' ]] && Session.Debug.To.Screen.IsSet && Display

    }

ShowAsProcLong()
    {

    ShowAsProc "$1 - this may take a while"

    }

ShowAsDebug()
    {

    WriteToDisplay.New "$(ColourTextBlackOnCyan dbug)" "$1"

    }

ShowAsNote()
    {

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

    WriteToDisplay.New "$(ColourTextBrightGreen 'done')" "$1"
    WriteToLog 'done' "$1"

    }

ShowAsWarning()
    {

    WriteToDisplay.New "$(ColourTextBrightOrangeBlink warn)" "$1"
    WriteToLog warn "$1"

    }

ShowAsAbort()
    {

    local capitalised="$(tr "[a-z]" "[A-Z]" <<< "${1:0:1}")${1:1}"      # use any available 'tr'

    WriteToDisplay.New "$(ColourTextBrightRed fail)" "$capitalised: aborting ..."
    WriteToLog fail "$capitalised: aborting"
    Session.Error.Set

    }

ShowAsError()
    {

    local capitalised="$(tr "[a-z]" "[A-Z]" <<< "${1:0:1}")${1:1}"      # use any available 'tr'

    WriteToDisplay.New "$(ColourTextBrightRed fail)" "$capitalised"
    WriteToLog fail "$capitalised."
    Session.Error.Set

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

    printf "%02dh:%02dm:%02ds\n" $h $m $s

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
    local safe_function_name="$(tr '[A-Z]' '[a-z]' <<< "${public_function_name//[.-]/_}")"

    _placeholder_size_="_object_${safe_function_name}_size_"
    _placeholder_text_="_object_${safe_function_name}_text_"
    _placeholder_flag_="_object_${safe_function_name}_flag_"
    _placeholder_log_changes_flag_="_object_${safe_function_name}_changes_flag_"
    _placeholder_enable_="_object_${safe_function_name}_enable_"
    _placeholder_array_="_object_${safe_function_name}_array_"
    _placeholder_array_index_="_object_${safe_function_name}_array_index_"
    _placeholder_path_="_object_${safe_function_name}_path_"

echo $public_function_name'.Add()
    {
    [[ ${'$_placeholder_array_'[*]} != *"$1"* ]] && '$_placeholder_array_'+=("$1")
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
'$public_function_name'.ListComma()
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
        '$_placeholder_path_'="$2"
    else
        echo -n "$'$_placeholder_path_'"
    fi
    }
'$public_function_name'.Remove()
    {
    [[ ${'$_placeholder_array_'[*]} == *"$1"* ]] && '$_placeholder_array_'=("${'$_placeholder_array_'[@]/$1}")
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
        '$_placeholder_text_'="$2"
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
        Objects.Add User.Opts.Apps.All.Install
        Objects.Add User.Opts.Apps.All.Reinstall
        Objects.Add User.Opts.Apps.All.Restart
        Objects.Add User.Opts.Apps.All.Restore
        Objects.Add User.Opts.Apps.All.Start
        Objects.Add User.Opts.Apps.All.Stop
        Objects.Add User.Opts.Apps.All.Uninstall
        Objects.Add User.Opts.Apps.All.Upgrade

        Objects.Add User.Opts.Apps.List.All
        Objects.Add User.Opts.Apps.List.Dependant
        Objects.Add User.Opts.Apps.List.Independent
        Objects.Add User.Opts.Apps.List.Installed
        Objects.Add User.Opts.Apps.List.NotInstalled
        Objects.Add User.Opts.Apps.List.Upgradable

        # lists
        Objects.Add IPKGs.ToDownload
        Objects.Add IPKGs.ToInstall
        Objects.Add IPKGs.ToUninstall

        Objects.Add QPKGs.Dependant
        Objects.Add QPKGs.Independent
        Objects.Add QPKGs.Installable
        Objects.Add QPKGs.Installed
        Objects.Add QPKGs.JustInstalled
        Objects.Add QPKGs.JustStarted
        Objects.Add QPKGs.Names
        Objects.Add QPKGs.NotInstalled
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

Session.Init || exit 1
Session.Validate
Packages.Download
Packages.Backup
Packages.Stop
Packages.Uninstall
Packages.Reinstall.Independents
Packages.Install.Independents
Packages.Start.Independents
Packages.Upgrade.Dependants
Packages.Reinstall.Dependants
Packages.Install.Dependants
Packages.Start.Dependants
Packages.Restore
Packages.Restart
Session.Results
Session.Error.IsNot
