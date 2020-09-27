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
    readonly SCRIPT_STARTSECONDS=$(date +%s)

    readonly PROJECT_NAME=sherpa
    readonly MANAGER_SCRIPT_VERSION=200928

    # cherry-pick required binaries
    readonly AWK_CMD=/bin/awk
    readonly BUSYBOX_CMD=/bin/busybox
    readonly CAT_CMD=/bin/cat
    readonly CHMOD_CMD=/bin/chmod
    readonly GREP_CMD=/bin/grep
    readonly HOSTNAME_CMD=/bin/hostname
    readonly MD5SUM_CMD=/bin/md5sum
    readonly PING_CMD=/bin/ping
    readonly SED_CMD=/bin/sed
    readonly SLEEP_CMD=/bin/sleep
    readonly TAR_CMD=/bin/tar
    readonly TOUCH_CMD=/bin/touch
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

    # check required binaries are present
    IsSysFileExist $AWK_CMD || return 1
    IsSysFileExist $BUSYBOX_CMD || return 1
    IsSysFileExist $CAT_CMD || return 1
    IsSysFileExist $CHMOD_CMD || return 1
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
    readonly APP_CENTER_CONFIG_PATHFILE=/etc/config/qpkg.conf
    readonly INSTALL_LOG_FILE=install.log
    readonly REINSTALL_LOG_FILE=reinstall.log
    readonly DOWNLOAD_LOG_FILE=download.log
    readonly START_LOG_FILE=start.log
    readonly STOP_LOG_FILE=stop.log
    readonly RESTART_LOG_FILE=restart.log
    readonly UPDATE_LOG_FILE=update.log
    readonly UPGRADE_LOG_FILE=upgrade.log
    readonly BACKUP_LOG_FILE=backup.log
    readonly RESTORE_LOG_FILE=restore.log
    readonly DEFAULT_SHARES_PATHFILE=/etc/config/def_share.info
    local -r ULINUX_PATHFILE=/etc/config/uLinux.conf
    readonly PLATFORM_PATHFILE=/etc/platform.conf
    readonly EXTERNAL_PACKAGE_ARCHIVE_PATHFILE=/opt/var/opkg-lists/entware
    readonly PREV_QPKG_CONFIG_DIRS=(SAB_CONFIG CONFIG Config config)                                # last element is used as target dirname
    readonly PREV_QPKG_CONFIG_FILES=(sabnzbd.ini sickbeard.conf settings.ini config.cfg config.ini) # last element is used as target filename
    local -r REMOTE_REPO_URL=https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/master/QPKGs
    local -r PROJECT_PATH=$($GETCFG_CMD $PROJECT_NAME Install_Path -f $APP_CENTER_CONFIG_PATHFILE)
    readonly WORK_PATH=$PROJECT_PATH/cache
    readonly COMPILED_OBJECTS=$WORK_PATH/compiled.objects

    Objects.Compile

    # enable debug mode early if possible
    if [[ $USER_ARGS_RAW == *"debug"* ]]; then
        Display
        Session.Debug.To.Screen.Set
    fi

    User.Opts.IgnoreFreeSpace.Text = ' --force-space'
    Session.Summary.Set
    Session.Debug.To.Screen.Description = "Display on-screen live debugging information."
    Session.Display.Clean.Description = "Disable display of script title and trailing linespace. If 'set', output is suitable for script processing."
    Session.LineSpace.Description = "Keeps track of the display empty linespacing flag. If 'set', an empty linespace has been printed to screen."
    readonly PACKAGE_LOGS_PATH=$PROJECT_PATH/logs
    readonly DEBUG_LOG_PATHFILE=$PROJECT_PATH/$DEBUG_LOG_FILE
    Session.Backup.Path = $($GETCFG_CMD SHARE_DEF defVolMP -f $DEFAULT_SHARES_PATHFILE)/.qpkg_config_backup
    readonly QPKG_DL_PATH=$WORK_PATH/qpkgs
    readonly IPKG_DL_PATH=$WORK_PATH/ipkgs.downloads
    readonly IPKG_CACHE_PATH=$WORK_PATH/ipkgs
    readonly PIP_CACHE_PATH=$WORK_PATH/pips
    readonly EXTERNAL_PACKAGE_LIST_PATHFILE=$WORK_PATH/Packages

    # internals
    readonly NAS_FIRMWARE=$($GETCFG_CMD System Version -f $ULINUX_PATHFILE)
    readonly PACKAGE_VERSION=$(GetInstalledQPKGVersion "$PROJECT_NAME")
    readonly NAS_BUILD=$($GETCFG_CMD System 'Build Number' -f $ULINUX_PATHFILE)
    readonly INSTALLED_RAM_KB=$($GREP_CMD MemTotal /proc/meminfo | $CUT_CMD -f2 -d':' | $SED_CMD 's|kB||;s| ||g')
    readonly MIN_RAM_KB=1048576
    readonly LOG_TAIL_LINES=1000
    code_pointer=0
    pip3_cmd=/opt/bin/pip3
    [[ ${NAS_FIRMWARE//.} -lt 426 ]] && curl_insecure_arg='--insecure' || curl_insecure_arg=''

    # runtime arrays
    QPKGs_to_backup=()
    QPKGs_to_force_upgrade=()
    QPKGs_to_install=()
    QPKGs_to_reinstall=()
    QPKGs_to_restart=()
    QPKGs_to_restore=()
    QPKGs_to_status=()
    QPKGs_to_uninstall=()
    QPKGs_to_upgrade=()

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
        SHERPA_QPKG_URL+=($REMOTE_REPO_URL/Entware/Entware_1.02std.qpkg)
        SHERPA_QPKG_MD5+=(dbc82469933ac3049c06d4c8a023bbb9)
        SHERPA_QPKG_ABBRVS+=('ew ent opkg entware')
        SHERPA_QPKG_DEPS+=('')
        SHERPA_QPKG_IPKGS+=('')

    SHERPA_QPKG_NAME+=(Par2)
        SHERPA_QPKG_ARCH+=(x86)
        SHERPA_QPKG_URL+=($REMOTE_REPO_URL/Par2/Par2_0.8.1.0_x86.qpkg)
        SHERPA_QPKG_MD5+=(996ffb92d774eb01968003debc171e91)
        SHERPA_QPKG_ABBRVS+=('par par2')        # these apply to all 'Par2' packages
        SHERPA_QPKG_DEPS+=('')
        SHERPA_QPKG_IPKGS+=('')

    SHERPA_QPKG_NAME+=(Par2)
        SHERPA_QPKG_ARCH+=(x64)
        SHERPA_QPKG_URL+=($REMOTE_REPO_URL/Par2/Par2_0.8.1.0_x86_64.qpkg)
        SHERPA_QPKG_MD5+=(520472cc87d301704f975f6eb9948e38)
        SHERPA_QPKG_ABBRVS+=('')
        SHERPA_QPKG_DEPS+=('')
        SHERPA_QPKG_IPKGS+=('')

    SHERPA_QPKG_NAME+=(Par2)
        SHERPA_QPKG_ARCH+=(x31)
        SHERPA_QPKG_URL+=($REMOTE_REPO_URL/Par2/Par2_0.8.1.0_arm-x31.qpkg)
        SHERPA_QPKG_MD5+=(ce8af2e009eb87733c3b855e41a94f8e)
        SHERPA_QPKG_ABBRVS+=('')
        SHERPA_QPKG_DEPS+=('')
        SHERPA_QPKG_IPKGS+=('')

    SHERPA_QPKG_NAME+=(Par2)
        SHERPA_QPKG_ARCH+=(x41)
        SHERPA_QPKG_URL+=($REMOTE_REPO_URL/Par2/Par2_0.8.1.0_arm-x41.qpkg)
        SHERPA_QPKG_MD5+=(8516e45e704875cdd2cd2bb315c4e1e6)
        SHERPA_QPKG_ABBRVS+=('')
        SHERPA_QPKG_DEPS+=('')
        SHERPA_QPKG_IPKGS+=('')

    SHERPA_QPKG_NAME+=(Par2)
        SHERPA_QPKG_ARCH+=(a64)
        SHERPA_QPKG_URL+=($REMOTE_REPO_URL/Par2/Par2_0.8.1.0_arm_64.qpkg)
        SHERPA_QPKG_MD5+=(4d8e99f97936a163e411aa8765595f7a)
        SHERPA_QPKG_ABBRVS+=('')
        SHERPA_QPKG_DEPS+=('')
        SHERPA_QPKG_IPKGS+=('')

    SHERPA_QPKG_NAME+=(SABnzbd)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=($REMOTE_REPO_URL/SABnzbd/build/SABnzbd_200922.qpkg)
        SHERPA_QPKG_MD5+=(23af2f4260163bcc9995d12fdef39c79)
        SHERPA_QPKG_ABBRVS+=('sb sb3 sab sab3 sabnzbd3 sabnzbd')
        SHERPA_QPKG_DEPS+=('Entware Par2')
        SHERPA_QPKG_IPKGS+=('python3-asn1crypto python3-chardet python3-cryptography python3-pyopenssl unrar p7zip coreutils-nice ionice ffprobe')

    SHERPA_QPKG_NAME+=(nzbToMedia)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=($REMOTE_REPO_URL/nzbToMedia/build/nzbToMedia_200922.qpkg)
        SHERPA_QPKG_MD5+=(19acc62689c862b942bc52f417ce218e)
        SHERPA_QPKG_ABBRVS+=('nzb2 nzb2m nzbto nzbtom nzbtomedia')
        SHERPA_QPKG_DEPS+=('Entware')
        SHERPA_QPKG_IPKGS+=('')

    SHERPA_QPKG_NAME+=(SickChill)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=($REMOTE_REPO_URL/SickChill/build/SickChill_200916.qpkg)
        SHERPA_QPKG_MD5+=(ade1d1c67355bf7d8e73543384cc1c61)
        SHERPA_QPKG_ABBRVS+=('sc sick sickc chill sickchill')
        SHERPA_QPKG_DEPS+=('Entware')
        SHERPA_QPKG_IPKGS+=('')

    SHERPA_QPKG_NAME+=(LazyLibrarian)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=($REMOTE_REPO_URL/LazyLibrarian/build/LazyLibrarian_200922.qpkg)
        SHERPA_QPKG_MD5+=(21203435b4f3c2575a72aeae57992692)
        SHERPA_QPKG_ABBRVS+=('ll lazy lazylibrarian')
        SHERPA_QPKG_DEPS+=('Entware')
        SHERPA_QPKG_IPKGS+=('python3-pyopenssl python3-requests')

    SHERPA_QPKG_NAME+=(OMedusa)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=($REMOTE_REPO_URL/OMedusa/build/OMedusa_200922.qpkg)
        SHERPA_QPKG_MD5+=(1cd38aacce12f6172a7ac42abd9e9809)
        SHERPA_QPKG_ABBRVS+=('om med omed medusa omedusa')
        SHERPA_QPKG_DEPS+=('Entware')
        SHERPA_QPKG_IPKGS+=('mediainfo python3-pyopenssl')

    SHERPA_QPKG_NAME+=(OSickGear)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=($REMOTE_REPO_URL/OSickGear/build/OSickGear_200922.qpkg)
        SHERPA_QPKG_MD5+=(2635e0c2c51067bdd2c2b63d4d88193c)
        SHERPA_QPKG_ABBRVS+=('sg os osg sickg gear ogear osickg sickgear osickgear')
        SHERPA_QPKG_DEPS+=('Entware')
        SHERPA_QPKG_IPKGS+=('')

    SHERPA_QPKG_NAME+=(Mylar3)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=($REMOTE_REPO_URL/Mylar3/build/Mylar3_200922.qpkg)
        SHERPA_QPKG_MD5+=(8412e8f92b1df4a3cdad9a56edd8b4e0)
        SHERPA_QPKG_ABBRVS+=('my omy myl mylar mylar3')
        SHERPA_QPKG_DEPS+=('Entware')
        SHERPA_QPKG_IPKGS+=('python3-mako python3-pillow python3-pyopenssl python3-pytz python3-requests python3-six python3-urllib3')

    SHERPA_QPKG_NAME+=(NZBGet)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=($REMOTE_REPO_URL/NZBGet/build/NZBGet_200922.qpkg)
        SHERPA_QPKG_MD5+=(097f0893eeaf34a4c9f1414b97bcbb67)
        SHERPA_QPKG_ABBRVS+=('ng nzb nzbg nget nzbget')
        SHERPA_QPKG_DEPS+=('Entware')
        SHERPA_QPKG_IPKGS+=('nzbget')

    SHERPA_QPKG_NAME+=(OTransmission)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=($REMOTE_REPO_URL/OTransmission/build/OTransmission_200922.qpkg)
        SHERPA_QPKG_MD5+=(ec9fd927ca8333bafc5984911d781406)
        SHERPA_QPKG_ABBRVS+=('ot tm tr trans otrans tmission transmission otransmission')
        SHERPA_QPKG_DEPS+=('Entware')
        SHERPA_QPKG_IPKGS+=('transmission-web transmission-daemon-openssl jq')

    SHERPA_QPKG_NAME+=(Deluge-server)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=($REMOTE_REPO_URL/Deluge-server/build/Deluge-server_200922.qpkg)
        SHERPA_QPKG_MD5+=(633bc7ff090346a0e8c204fe7b19a382)
        SHERPA_QPKG_ABBRVS+=('deluge del-server deluge-server')
        SHERPA_QPKG_DEPS+=('Entware')
        SHERPA_QPKG_IPKGS+=('deluge')

    SHERPA_QPKG_NAME+=(Deluge-web)
        SHERPA_QPKG_ARCH+=(all)
        SHERPA_QPKG_URL+=($REMOTE_REPO_URL/Deluge-web/build/Deluge-web_200922.qpkg)
        SHERPA_QPKG_MD5+=(774191bbdcd31e6494abba4192b51d7a)
        SHERPA_QPKG_ABBRVS+=('del-web deluge-web')
        SHERPA_QPKG_DEPS+=('Entware')
        SHERPA_QPKG_IPKGS+=('deluge-ui-web')

    # package arrays are now full, so lock them
    readonly SHERPA_QPKG_NAME
        readonly SHERPA_QPKG_ARCH
        readonly SHERPA_QPKG_URL
        readonly SHERPA_QPKG_MD5
        readonly SHERPA_QPKG_ABBRVS
        readonly SHERPA_QPKG_DEPS
        readonly SHERPA_QPKG_IPKGS

    readonly SHERPA_COMMON_IPKGS='ca-certificates findutils gcc git git-http less nano python3-dev python3-pip python3-setuptools sed'
    readonly SHERPA_COMMON_PIPS='apscheduler beautifulsoup4 cfscrape cheetah3 "cheroot!=8.4.4" cherrypy configobj "feedparser==5.2.1" portend pygithub python-magic random_user_agent sabyenc3 simplejson slugify'
    readonly SHERPA_COMMON_CONFLICTS='Optware Optware-NG TarMT Python QPython2'

    QPKGs.Independent.Build
    QPKGs.Dependant.Build
    QPKGs.Installable.Build
    QPKGs.Installed.Build
    QPKGs.NotInstalled.Build
    QPKGs.Upgradable.Build
    CalcNASQPKGArch

    Session.ParseArguments
    Session.SkipPackageProcessing.IsNot && Session.Debug.To.File.Set
    SmartCR

    if Session.Display.Clean.IsNot; then
        if Session.Debug.To.Screen.IsNot; then
            Display "$(FormatAsScriptTitle) $MANAGER_SCRIPT_VERSION • a mini-package-manager for QNAP NAS"
            DisplayLineSpaceIfNoneAlready
        fi

        User.Opts.Apps.All.Upgrade.IsNot && DisplayNewQPKGVersions
    fi

    DebugFuncExit
    return 0

    }

Session.ParseArguments()
    {


    if [[ -z $USER_ARGS_RAW ]]; then
        User.Opts.Help.Basic.Set
        Session.SkipPackageProcessing.Set
        code_pointer=1
        return 1
    fi

    DebugFuncEntry

    local user_args=($(tr '[A-Z]' '[a-z]' <<< "$USER_ARGS_RAW"))
    local arg=''
    local action='install_'     # make 'install' the default action. A user-convenience to simulate the previous script behaviour.
    local action_force=false
    local target_package=''

    for arg in "${user_args[@]}"; do
        case $arg in
            --abs|abs)
                User.Opts.Help.Abbreviations.Set
                Session.SkipPackageProcessing.Set
                ;;
            -d|d|--debug|debug)
                Session.Debug.To.Screen.Set
                ;;
            --ignore-space|ignore-space)
                User.Opts.IgnoreFreeSpace.Set
                ;;
            -h|h|--help|help)
                User.Opts.Help.Basic.Set
                Session.SkipPackageProcessing.Set
                ;;
            -l|l|--log|log)
                User.Opts.Log.View.Set
                Session.SkipPackageProcessing.Set
                ;;
            --paste|paste)
                User.Opts.Log.Paste.Set
                Session.SkipPackageProcessing.Set
                ;;
            -a|a|--action|action|--actions|actions)
                User.Opts.Help.Actions.Set
                Session.SkipPackageProcessing.Set
                ;;
            --action-all|action-all|--actions-all|actions-all)
                User.Opts.Help.ActionsAll.Set
                Session.SkipPackageProcessing.Set
                ;;
            --package|package|--packages|packages)
                User.Opts.Help.Packages.Set
                Session.SkipPackageProcessing.Set
                ;;
            -o|o|--option|option|--options|options)
                User.Opts.Help.Options.Set
                Session.SkipPackageProcessing.Set
                ;;
            -p|p|--problem|problem|--problems|problems)
                User.Opts.Help.Problems.Set
                Session.SkipPackageProcessing.Set
                ;;
            -t|t|--tip|tip|--tips|tips)
                User.Opts.Help.Tips.Set
                Session.SkipPackageProcessing.Set
                ;;
            --list|list|--list-all|list-all|all)
                User.Opts.Apps.All.List.Set
                Session.Display.Clean.Set
                Session.SkipPackageProcessing.Set
                ;;
            --list-installed|list-installed|installed)
                User.Opts.Apps.List.Installed.Set
                Session.Display.Clean.Set
                Session.SkipPackageProcessing.Set
                ;;
            --list-installable|list-installable|--list-not-installed|list-not-installed|not-installed|--installable|installable)
                User.Opts.Apps.List.NotInstalled.Set
                Session.Display.Clean.Set
                Session.SkipPackageProcessing.Set
                ;;
            --list-upgradable|list-upgradable|upgradable)
                User.Opts.Apps.List.Upgradable.Set
                Session.Display.Clean.Set
                Session.SkipPackageProcessing.Set
                ;;
            -v|v|--version|version)
                User.Opts.Versions.View.Set
                Session.Display.Clean.Set
                Session.SkipPackageProcessing.Set
                ;;
            -c|c|--check|check|--check-all|check-all)
                User.Opts.Dependencies.Check.Set
                action=''
                ;;
            --install-all|install-all)
                User.Opts.Apps.All.Install.Set
                action=''
                ;;
            --uninstall-all-packages-please|uninstall-all-packages-please|--remove-all-packages-please|remove-all-packages-please)
                User.Opts.Apps.All.Uninstall.Set
                action=''
                ;;
            --reinstall-all|reinstall-all)
                User.Opts.Apps.All.Reinstall.Set
                action=''
                ;;
            --restart-all|restart-all)
                User.Opts.Apps.All.Restart.Set
                action=''
                ;;
            --upgrade-all|upgrade-all)
                User.Opts.Apps.All.Upgrade.Set
                action=''
                ;;
            --backup-all|backup-all)
                User.Opts.Apps.All.Backup.Set
                action=''
                ;;
            --restore-all|restore-all)
                User.Opts.Apps.All.Restore.Set
                action=''
                ;;
            --status-all|status-all)
                User.Opts.Apps.All.Status.Set
                action=''
                ;;
            --install|install)
                action=install_
                action_force=false
                ;;
            --uninstall|uninstall|--remove|remove)
                action=uninstall_
                action_force=false
                ;;
            --reinstall|reinstall)
                action=reinstall_
                action_force=false
                ;;
            --restart|restart)
                action=restart_
                action_force=false
                ;;
            --up|up|--upgrade|upgrade)
                action=upgrade_
                action_force=false
                ;;
            --backup|backup)
                action=backup_
                action_force=false
                ;;
            --restore|restore)
                action=restore_
                action_force=false
                ;;
            --status|status)
                action=status_
                action_force=false
                ;;
            --force|force)
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
                    uninstall_)
                        QPKGs.ToUninstall.Add "$target_package"
                        ;;
                    status_)
                        QPKGs.ToStatus.Add "$target_package"
                        ;;
                esac
        esac
    done

    DebugFuncExit
    return 0

    }

Session.Validate()
    {

    Session.SkipPackageProcessing.IsSet && return

    DebugFuncEntry
    local package=''

    DebugInfoThickSeparator
    DebugScript 'started' "$(date | tr -s ' ')"
    DebugScript 'version' "package: $PACKAGE_VERSION, manager: $MANAGER_SCRIPT_VERSION, loader $LOADER_SCRIPT_VERSION"
    DebugScript 'PID' "$$"
    DebugInfoThinSeparator
    DebugInfo 'Markers: (**) detected, (II) information, (WW) warning, (EE) error, (LL) log file,'
    DebugInfo '(==) processing, (--) done, (>>) f entry, (<<) f exit, (vv) variable name & value,'
    DebugInfo '($1) positional argument value'
    DebugInfoThinSeparator
    DebugHardware.OK 'model' "$(get_display_name)"
    DebugHardware.OK 'RAM' "$(printf "%'.f" $INSTALLED_RAM_KB) kB"

    if QPKG.ToBeInstalled SABnzbd || QPKG.Installed SABnzbd || QPKG.Installed SABnzbdplus; then
        [[ $INSTALLED_RAM_KB -le $MIN_RAM_KB ]] && DebugHardware.Warning 'RAM' "less-than or equal-to $(printf "%'.f" $MIN_RAM_KB) kB"
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
        return 1
    fi

    DebugUserspace.OK 'BASH' "$(bash --version | $HEAD_CMD -n1)"
    DebugUserspace.OK 'default volume' "$($GETCFG_CMD SHARE_DEF defVolMP -f $DEFAULT_SHARES_PATHFILE)"

    if [[ -L '/opt' ]]; then
        DebugUserspace.OK '/opt' "$($READLINK_CMD '/opt' || echo '<not present>')"
    else
        DebugUserspace.Warning '/opt' '<not present>'
    fi

    DebugUserspace.OK '$PATH' "${PATH:0:54}"
    CheckPythonPathAndVersion python2
    CheckPythonPathAndVersion python3
    CheckPythonPathAndVersion python
    DebugUserspace.OK 'unparsed user arguments' "$USER_ARGS_RAW"

    if QPKG.Installed Entware; then
        [[ -e /opt/etc/passwd ]] && { [[ -L /opt/etc/passwd ]] && ENTWARE_VER=std || ENTWARE_VER=alt ;} || ENTWARE_VER=none
        DebugQPKG 'Entware installer' $ENTWARE_VER

        if [[ $ENTWARE_VER = none ]]; then
            ShowAsError "$(FormatAsPackageName Entware) appears to be installed but is not visible"
            return 1
        fi
    fi

    DebugQPKG 'arch' "$NAS_QPKG_ARCH"
    DebugQPKG 'logs path' "$PACKAGE_LOGS_PATH"
    DebugQPKG 'download path' "$QPKG_DL_PATH"
    DebugIPKG 'download path' "$IPKG_DL_PATH"
    DebugQPKG 'upgradable package(s)' "${QPKGS_upgradable[*]} "
    DebugInfoThinSeparator
    Packages.Assignment.Check
    DebugInfoThinSeparator

    if User.Opts.Apps.All.Backup.IsSet && User.Opts.Apps.All.Restore.IsSet; then
        ShowAsError 'no point running a backup then a restore operation'
        code_pointer=2
        return 1
    fi

    if QPKGs.ToInstall.IsAny || QPKGs.ToForceUpgrade.IsAny || User.Opts.Apps.All.Upgrade.IsSet || User.Opts.Dependencies.Check.IsSet; then
        Session.Ipkgs.Install.Set
    fi

    if QPKGs.ToBackup.IsNone && QPKGs.ToUninstall.IsNone && QPKGs.ToForceUpgrade.IsNone && QPKGs.ToUpgrade.IsNone && QPKGs.ToInstall.IsNone && QPKGs.ToReinstall.IsNone && QPKGs.ToRestore.IsNone && QPKGs.ToRestart.IsNone && QPKGs.ToStatus.IsNone; then
        if User.Opts.Apps.All.Install.IsNot && User.Opts.Apps.All.Uninstall.IsNot && User.Opts.Apps.All.Restart.IsNot && User.Opts.Apps.All.Upgrade.IsNot && User.Opts.Apps.All.Backup.IsNot && User.Opts.Apps.All.Restore.IsNot && User.Opts.Apps.All.Status.IsNot; then
            if User.Opts.Dependencies.Check.IsNot && Session.Debug.To.Screen.IsNot && User.Opts.IgnoreFreeSpace.IsNot; then
                ShowAsError 'nothing to do'
                User.Opts.Help.Basic.Set
                Session.SkipPackageProcessing.Set
                return 1
            fi
        fi
    fi

    QPKGs.Download.Build
    DebugInfoThinSeparator

    mkdir -p "$WORK_PATH" 2> /dev/null; result=$?

    if [[ $result -ne 0 ]]; then
        ShowAsError "unable to create script working directory $(FormatAsFileName "$WORK_PATH") $(FormatAsExitcode $result)"
        Session.SuggestIssue.Set
        return 1
    fi

    mkdir -p "$PACKAGE_LOGS_PATH" 2> /dev/null; result=$?

    if [[ $result -ne 0 ]]; then
        ShowAsError "unable to create package logs directory $(FormatAsFileName "$PACKAGE_LOGS_PATH") $(FormatAsExitcode $result)"
        Session.SuggestIssue.Set
        return 1
    fi

    mkdir -p "$QPKG_DL_PATH" 2> /dev/null; result=$?

    if [[ $result -ne 0 ]]; then
        ShowAsError "unable to create QPKG download directory $(FormatAsFileName "$QPKG_DL_PATH") $(FormatAsExitcode $result)"
        Session.SuggestIssue.Set
        return 1
    fi

    mkdir -p "$IPKG_DL_PATH" 2> /dev/null; result=$?

    if [[ $result -ne 0 ]]; then
        ShowAsError "unable to create IPKG download directory $(FormatAsFileName "$IPKG_DL_PATH") $(FormatAsExitcode $result)"
        Session.SuggestIssue.Set
        return 1
    fi

    [[ -d $IPKG_CACHE_PATH ]] && rm -rf "$IPKG_CACHE_PATH"
    mkdir -p "$IPKG_CACHE_PATH" 2> /dev/null; result=$?

    if [[ $result -ne 0 ]]; then
        ShowAsError "unable to create IPKG cache directory $(FormatAsFileName "$IPKG_CACHE_PATH") $(FormatAsExitcode $result)"
        Session.SuggestIssue.Set
        return 1
    fi

    [[ -d $PIP_CACHE_PATH ]] && rm -rf "$PIP_CACHE_PATH"
    mkdir -p "$PIP_CACHE_PATH" 2> /dev/null; result=$?

    if [[ $result -ne 0 ]]; then
        ShowAsError "unable to create PIP cache directory $(FormatAsFileName "$PIP_CACHE_PATH") $(FormatAsExitcode $result)"
        Session.SuggestIssue.Set
        return 1
    fi

    for package in "${SHERPA_COMMON_CONFLICTS[@]}"; do
        if QPKG.Enabled "$package"; then
            ShowAsError "'$package' is installed and enabled. One-or-more $(FormatAsScriptTitle) applications are incompatible with this package"
            return 1
        fi
    done

    DebugFuncExit
    return 0

    }

Packages.Assignment.Check()
    {

    # Ensure packages are assigned to the correct lists

    # As a package manager, package importance should always be:
    #   8. backup           (highest: most-important)
    #   7. restore
    #   6. force-upgrade
    #   5. upgrade
    #   4. reinstall
    #   3. install
    #   2. restart
    #   1. uninstall        (lowest: least-important)

    #   0. status           (none: packages in this list should always be processed if requested)

    Session.SkipPackageProcessing.IsSet && return

    local package=''

    # add packages to appropriate lists:

    if User.Opts.Apps.All.Backup.IsSet; then
        if QPKGs.Installed.IsAny; then
            for package in "${QPKGs_installed[@]}"; do
                QPKGs.ToBackup.Add "$package"
            done
        fi
    fi

    if User.Opts.Apps.All.Restore.IsSet; then
        if QPKGs.Installed.IsAny; then
            for package in "${QPKGs_installed[@]}"; do
                QPKGs.ToRestore.Add "$package"
            done
        fi
    fi

    if User.Opts.Apps.All.Upgrade.IsSet; then
        if [[ ${#QPKGS_upgradable[*]} -gt 0 ]]; then
            for package in "${QPKGS_upgradable[@]}"; do
                if [[ $package != Entware ]]; then      # KLUDGE: ignore Entware as it needs to be handled separately.
                    QPKGs.ToUpgrade.Add "$package"
                fi
            done
        fi
    fi

    if User.Opts.Apps.All.Reinstall.IsSet; then
        if QPKGs.Installed.IsAny; then
            for package in "${QPKGs_installed[@]}"; do
                if [[ $package != Entware ]]; then      # KLUDGE: ignore Entware as it needs to be handled separately.
                    QPKGs.ToReinstall.Add "$package"
                fi
            done
        fi
    fi

    if User.Opts.Apps.All.Install.IsSet; then
        if [[ ${#QPKGS_user_installable[*]} -gt 0 ]]; then
            for package in "${QPKGS_user_installable[@]}"; do
                if [[ $package != Entware ]]; then      # KLUDGE: ignore Entware as it needs to be handled separately.
                    QPKGs.ToInstall.Add "$package"
                fi
            done
        fi
    fi

    if User.Opts.Apps.All.Restart.IsSet; then
        if QPKGs.Installed.IsAny; then
            for package in "${QPKGs_installed[@]}"; do
                if [[ $package != Entware ]]; then      # KLUDGE: ignore Entware as it needs to be handled separately.
                    QPKGs.ToRestart.Add "$package"
                fi
            done
        fi
    fi

    if User.Opts.Apps.All.Uninstall.IsSet; then
        if QPKGs.Installed.IsAny; then
            for package in "${QPKGs_installed[@]}"; do
                if [[ $package != Entware ]]; then      # KLUDGE: ignore Entware as it needs to be handled separately.
                    QPKGs.ToUninstall.Add "$package"
                fi
            done
        fi
    fi

    if User.Opts.Apps.All.Status.IsSet; then
        if QPKGs.Installed.IsAny; then
            for package in "${QPKGS_user_installable[@]}"; do
                if [[ $package != Entware ]]; then      # KLUDGE: ignore Entware as it needs to be handled separately.
                    QPKGs.ToStatus.Add "$package"
                fi
            done
        fi
    fi

    # However, package processing priorities need to be:
    #   8. backup           (highest: most-important)
    #   7. uninstall
    #   6. force-upgrade
    #   5. upgrade
    #   4. install
    #   3. reinstall
    #   2. restore
    #   1. restart          (lowest: least-important)

    #   0. status           (none: packages in this list should always be processed if requested)

    # remove duplicate and redundant entries from lists by following package processing priority order:

    # don't check the 'backup' list as this has the highest-priority and should always be processed.

    if QPKGs.ToUninstall.IsAny; then
        for package in "${SHERPA_DEP_QPKGs[@]}"; do
            if [[ ${QPKGs_to_install[*]} == *"$package"* ]]; then
                QPKGs.ToRestart.Remove "$package"
            fi
        done
    fi

    if QPKGs.ToForceUpgrade.IsAny; then
        for package in "${SHERPA_DEP_QPKGs[@]}"; do
            if [[ ${QPKGs_to_force_upgrade[*]} == *"$package"* ]]; then
                QPKGs.ToUpgrade.Remove "$package"
                QPKGs.ToInstall.Remove "$package"
                QPKGs.ToReinstall.Remove "$package"
                QPKGs.ToRestart.Remove "$package"
            fi
        done
    fi

    if QPKGs.ToUpgrade.IsAny; then
        for package in "${SHERPA_DEP_QPKGs[@]}"; do
            if [[ ${QPKGs_to_upgrade[*]} == *"$package"* ]]; then
                QPKGs.ToInstall.Remove "$package"
                QPKGs.ToReinstall.Remove "$package"
                QPKGs.ToRestart.Remove "$package"
            fi
        done
    fi

    if QPKGs.ToInstall.IsAny; then
        for package in "${SHERPA_DEP_QPKGs[@]}"; do
            if [[ ${QPKGs_to_install[*]} == *"$package"* ]]; then
                QPKGs.ToReinstall.Remove "$package"
                QPKGs.ToRestart.Remove "$package"
            fi
        done
    fi

    if QPKGs.ToReinstall.IsAny; then
        for package in "${SHERPA_DEP_QPKGs[@]}"; do
            if [[ ${QPKGs_to_reinstall[*]} == *"$package"* ]]; then
                QPKGs.ToRestart.Remove "$package"
            fi
        done
    fi

    if QPKGs.ToRestore.IsAny; then
        for package in "${SHERPA_DEP_QPKGs[@]}"; do
            if [[ ${QPKGs_to_restore[*]} == *"$package"* ]]; then
                QPKGs.ToRestart.Remove "$package"
            fi
        done
    fi

    # don't need to independently check the 'restart' list as it is checked by the previous conditions.

    DebugScript 'backup' "${QPKGs_to_backup[*]} "
    DebugScript 'uninstall' "${QPKGs_to_uninstall[*]} "
    DebugScript 'forced-upgrade' "${QPKGs_to_force_upgrade[*]} "
    DebugScript 'upgrade' "${QPKGs_to_upgrade[*]} "
    DebugScript 'install' "${QPKGs_to_install[*]} "
    DebugScript 'reinstall' "${QPKGs_to_reinstall[*]} "
    DebugScript 'restore' "${QPKGs_to_restore[*]} "
    DebugScript 'restart' "${QPKGs_to_restart[*]} "
    DebugScript 'status' "${QPKGs_to_status[*]} "

    return 0

    }

Packages.Download()
    {

    Session.SkipPackageProcessing.IsSet && return

    DebugFuncEntry
    local package=''

    for package in "${QPKGs_download_array[@]}"; do
        QPKG.Download "$package"
    done

    DebugFuncExit
    return 0

    }

Packages.Backup()
    {

    Session.SkipPackageProcessing.IsSet && return

    DebugFuncEntry
    local package=''

    if QPKGs.ToBackup.IsAny; then
        for package in "${QPKGs_to_backup[@]}"; do
            if QPKG.Installed "$package"; then
                if [[ ${SHERPA_INDEP_QPKGs[*]} == *"$package"* ]]; then
                    ShowAsNote "unable to backup $(FormatAsPackageName "$package") configuration as it's unsupported"
                else
                    QPKG.Backup "$package"
                fi
            else
                ShowAsNote "unable to backup $(FormatAsPackageName "$package") configuration as it's not installed"
            fi
        done

        Session.ShowBackupLocation.Set
    fi

    DebugFuncExit
    return 0

    }

Packages.Uninstall()
    {

    Session.SkipPackageProcessing.IsSet && return

    DebugFuncEntry
    local response=''
    local package=''
    local previous_pip3_module_list=$WORK_PATH/pip3.prev.installed.list
    local previous_opkg_package_list=$WORK_PATH/opkg.prev.installed.list

    if QPKGs.ToUninstall.IsAny; then
        # remove dependant packages first
        for package in "${SHERPA_DEP_QPKGs[@]}"; do
            if [[ ${QPKGs_to_uninstall[*]} == *"$package"* ]]; then
                if QPKG.Installed "$package"; then
                    QPKG.Uninstall "$package"
                else
                    ShowAsNote "unable to uninstall $(FormatAsPackageName "$package") as it's not installed"
                fi
            fi
        done

        # then the independent packages last
        for package in "${SHERPA_INDEP_QPKGs[@]}"; do
            if [[ ${QPKGs_to_uninstall[*]} == *"$package"* ]]; then
                if [[ $package != Entware ]]; then      # KLUDGE: ignore Entware as it needs to be handled separately.
                    if QPKG.Installed "$package"; then
                        QPKG.Uninstall "$package"
                    else
                        ShowAsNote "unable to uninstall $(FormatAsPackageName "$package") as it's not installed"
                    fi
                fi
            fi
        done

        # TODO: still need something here to remove Entware if it's in the $QPKGs_to_uninstall array
    fi

    if QPKG.ToBeReinstalled Entware; then
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
            DebugInfoThinSeparator
            DebugScript 'user abort'
            Session.SkipPackageProcessing.Set
            Session.Summary.Clear
            return 1
        fi
    else
        [[ -e $OPKG_CMD && $NAS_QPKG_ARCH != none ]] && (QPKG.ToBeInstalled Par2 || QPKG.Installed Par2) && ($OPKG_CMD list-installed | $GREP_CMD -q par2cmdline) && $OPKG_CMD remove par2cmdline > /dev/null 2>&1
    fi

    DebugFuncExit
    return 0

    }

Packages.Install.Independents()
    {

    Session.SkipPackageProcessing.IsSet && return

    # install independent QPKGs first, in the order they were declared

    DebugFuncEntry

    if QPKGs.ToInstall.IsAny || QPKGs.ToReinstall.IsAny; then
        for package in "${SHERPA_INDEP_QPKGs[@]}"; do
            if  [[ ${QPKGs_to_install[*]} == *"$package"* || ${QPKGs_to_reinstall[*]} == *"$package"* ]]; then
                if [[ $package = Entware ]]; then
                    # rename original [/opt]
                    local opt_path=/opt
                    local opt_backup_path=/opt.orig
                    [[ -d $opt_path && ! -L $opt_path && ! -e $opt_backup_path ]] && mv "$opt_path" "$opt_backup_path"

                    QPKG.Install Entware && ReloadProfile

                    # copy all files from original [/opt] into new [/opt]
                    [[ -L $opt_path && -d $opt_backup_path ]] && cp --recursive "$opt_backup_path"/* --target-directory "$opt_path" && rm -rf "$opt_backup_path"
                else
                    if [[ $NAS_QPKG_ARCH != none ]]; then
                        if [[ ${QPKGs_to_install[*]} == *"$package"* ]]; then
                            QPKG.Install "$package"
                        elif [[ ${QPKGs_to_reinstall[*]} == *"$package"* ]]; then
                            QPKG.Reinstall "$package"
                        fi
                    fi
                fi
            fi
        done
        Session.Ipkgs.Install.Set
    fi

    if QPKG.Installed Entware; then
        QPKG.NotEnabled Entware && QPKG.Enable Entware && ReloadProfile
        PatchBaseInit
        IPKGs.Install
        PIP.Install
    fi

    if QPKG.ToBeReinstalled Entware || User.Opts.Apps.All.Restart.IsSet; then
        QPKGs.Dependant.Restart
    fi

    QPKG.ToBeInstalled Par2 && QPKG.Installed SABnzbd && QPKGs.ToRestart.Add SABnzbd  # KLUDGE: only until dep restarting is fixed

    DebugFuncExit
    return 0

    }

Packages.Install.Dependants()
    {

    Session.SkipPackageProcessing.IsSet && return

    DebugFuncEntry
    local package=''

    if QPKGs.ToUpgrade.IsAny || QPKGs.ToForceUpgrade.IsAny; then
        for package in "${SHERPA_DEP_QPKGs[@]}"; do
            if [[ ${QPKGs_to_force_upgrade[*]} == *"$package"* ]]; then
                QPKG.Upgrade "$package" --forced
            elif [[ ${QPKGs_to_upgrade[*]} == *"$package"* ]]; then
                if QPKG.Installed "$package"; then
                    if [[ ${QPKGS_upgradable[*]} == *"$package"* ]]; then
                        QPKG.Upgrade "$package"
                    else
                        ShowAsNote "unable to upgrade $(FormatAsPackageName "$package") as it's not upgradable. Use the '--force' if you really want this."
                    fi
                else
                    ShowAsNote "unable to upgrade $(FormatAsPackageName "$package") as it's not installed. Use '--install' instead."
                fi
            fi
        done
    fi

    if QPKGs.ToInstall.IsAny; then
        for package in "${SHERPA_DEP_QPKGs[@]}"; do
            if [[ ${QPKGs_to_install[*]} == *"$package"* ]]; then
                if QPKG.NotInstalled "$package"; then
                    QPKG.Install "$package"
                else
                    ShowAsNote "unable to install $(FormatAsPackageName "$package") as it's already installed. Use '--reinstall' instead."
                fi
            fi
        done
    fi

    if QPKGs.ToReinstall.IsAny; then
        for package in "${SHERPA_DEP_QPKGs[@]}"; do
            if [[ ${QPKGs_to_reinstall[*]} == *"$package"* ]]; then
                if QPKG.Installed "$package"; then
                    QPKG.Reinstall "$package"
                else
                    ShowAsNote "unable to reinstall $(FormatAsPackageName "$package") as it's not installed. Use '--install' instead."
                fi
            fi
        done
    fi

    DebugFuncExit
    return 0

    }

Packages.Restore()
    {

    Session.SkipPackageProcessing.IsSet && return

    DebugFuncEntry
    local package=''

    if QPKGs.ToRestore.IsAny; then
        for package in "${QPKGs_to_restore[@]}"; do
            if QPKG.Installed "$package"; then
                if [[ ${SHERPA_INDEP_QPKGs[*]} == *"$package"* ]]; then
                    ShowAsNote "unable to restore $(FormatAsPackageName "$package") configuration as it's unsupported"
                else
                    QPKG.Restore "$package"
                fi
            else
                ShowAsNote "unable to restore $(FormatAsPackageName "$package") configuration as it's not installed"
            fi
        done

        Session.ShowBackupLocation.Set
    fi

    DebugFuncExit
    return 0

    }

Packages.Restart()
    {

    Session.SkipPackageProcessing.IsSet && return

    DebugFuncEntry

    if User.Opts.Apps.All.Upgrade.IsSet; then
        QPKGs.RestartNotUpgraded
    elif [[ ${#QPKGs_to_restart[*]} -gt 0 ]]; then
        for package in "${SHERPA_DEP_QPKGs[@]}"; do
            if [[ ${QPKGs_to_restart[*]} == *"$package"* ]]; then
                if QPKG.Installed "$package"; then
                    if QPKG.ToNotBeInstalled "$package" && QPKG.ToNotBeReinstalled "$package"; then
                        QPKG.Restart "$package"
                    else
                        ShowAsNote "no-need to restart $(FormatAsPackageName "$package") as it was just installed"
                    fi
                else
                    ShowAsNote "unable to restart $(FormatAsPackageName "$package") as it's not installed"
                fi
            fi
        done
    fi

    DebugFuncExit
    return 0

    }

Session.Results()
    {

    if User.Opts.Versions.View.IsSet; then
        Versions.Show
    elif User.Opts.Log.View.IsSet; then
        Log.View.Show
    elif User.Opts.Log.Paste.IsSet; then
        Log.Paste.Online
    elif User.Opts.Apps.List.Installed.IsSet; then
        QPKGs.Installed.Show
    elif User.Opts.Apps.List.NotInstalled.IsSet; then
        QPKGs.NotInstalled.Show
    elif User.Opts.Apps.List.Upgradable.IsSet; then
        QPKGs.Upgradable.Show
    elif User.Opts.Apps.All.List.IsSet; then
        QPKGs.All.Show
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

    DebugInfoThinSeparator
    DebugScript 'finished' "$(date)"
    DebugScript 'elapsed time' "$(ConvertSecsToMinutes "$(($(date +%s)-$([[ -n $SCRIPT_STARTSECONDS ]] && echo "$SCRIPT_STARTSECONDS" || echo "1")))")"
    DebugInfoThickSeparator

    Session.LockFile.Release

    return 0

    }

DisplayNewQPKGVersions()
    {

    # Check installed sherpa packages and compare versions against package arrays. If new versions are available, advise on-screen.

    # $? = 0 if all packages are up-to-date
    # $? = 1 if one or more packages can be upgraded

    local msg=''
    local packages_left_to_upgrade=()
    local package_names=''

    if [[ ${#QPKGS_upgradable[@]} -gt 0 ]]; then
        for package in "${QPKGS_upgradable[@]}"; do
            if [[ ${QPKGs_to_upgrade[*]} != *"$package"* ]]; then
                packages_left_to_upgrade+=("$package")
            fi
        done

        if [[ ${#packages_left_to_upgrade[@]} -eq 0 ]]; then
            return 0
        elif [[ ${#packages_left_to_upgrade[@]} -eq 1 ]]; then
            msg='An upgraded package is'
        else
            msg='Upgraded packages are'
        fi

        package_names=${packages_left_to_upgrade[*]}

        ShowAsNote "$msg available for $(ColourTextBrightYellow "${package_names// /, }")"
        return 1
    fi

    return 0

    }

Log.Paste.Online()
    {

    # with thanks to https://github.com/solusipse/fiche

    if [[ -n $DEBUG_LOG_PATHFILE && -e $DEBUG_LOG_PATHFILE ]]; then
        if AskQuiz "Press 'Y' to post the most-recent $(printf "%'.f" $LOG_TAIL_LINES) entries in your $(FormatAsScriptTitle) log to a public pastebin, or any other key to abort"; then
            ShowAsProc "uploading $(FormatAsScriptTitle) log"
            link=$($TAIL_CMD -n $LOG_TAIL_LINES -q "$DEBUG_LOG_PATHFILE" | (exec 3<>/dev/tcp/termbin.com/9999; $CAT_CMD >&3; $CAT_CMD <&3; exec 3<&-))

            if [[ $? -eq 0 ]]; then
                ShowAsDone "your $(FormatAsScriptTitle) log is now online at $(FormatAsURL "$($SED_CMD 's|http://|http://l.|;s|https://|https://l.|' <<< "$link")") and will be deleted in 1 month"
            else
                ShowAsError "a link could not be generated. Most likely a problem occurred when talking with $(FormatAsURL 'https://termbin.com')"
            fi
        else
            DebugInfoThinSeparator
            DebugScript 'user abort'
            Session.SkipPackageProcessing.Set
            Session.Summary.Clear
            return 1
        fi
    else
        ShowAsError 'no log to paste'
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

    if IsNotSysFileExist $OPKG_CMD; then
        code_pointer=3
        return 1
    fi

    local package_minutes_threshold=60
    local log_pathfile="$PACKAGE_LOGS_PATH/entware.$UPDATE_LOG_FILE"
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
        ShowAsDone "$(FormatAsPackageName Entware) package list is current"
    fi

    return 0

    }

InstallIPKGBatch()
    {

    # input:
    #   $1 = whitespace-separated string containing list of IPKG names to download and install

    # output:
    #   $? = 0 (true) or 1 (false)

    DebugFuncEntry
    local returncode=0
    local log_pathfile=$PACKAGE_LOGS_PATH/ipkgs.$INSTALL_LOG_FILE
    local result=0

    # errors can occur due to incompatible IPKGs (tried installing Entware-3x, then Entware-ng), so delete them first
    [[ -d $IPKG_DL_PATH ]] && rm -f "$IPKG_DL_PATH"/*.ipk
    [[ -d $IPKG_CACHE_PATH ]] && rm -f "$IPKG_CACHE_PATH"/*.ipk

    GetAllIPKGDepsToDownload "$1" || return 1

    if [[ $IPKG_download_count -gt 0 ]]; then
        ShowAsProc "downloading & installing $IPKG_download_count IPKG$(FormatAsPlural "$IPKG_download_count")"

        CreateDirSizeMonitorFlagFile
            trap CTRL_C_Captured INT
                _MonitorDirSize_ "$IPKG_DL_PATH" "$IPKG_download_size" &

                RunThisAndLogResults "$OPKG_CMD install$(User.Opts.IgnoreFreeSpace.IsSet && User.Opts.IgnoreFreeSpace.Text) --force-overwrite ${IPKG_download_list[*]} --cache $IPKG_CACHE_PATH --tmp-dir $IPKG_DL_PATH" "$log_pathfile"
                result=$?
            trap - INT
        RemoveDirSizeMonitorFlagFile

        if [[ $result -eq 0 ]]; then
            ShowAsDone "downloaded & installed $IPKG_download_count IPKG$(FormatAsPlural "$IPKG_download_count")"
            Session.Pips.Install.Set
        else
            ShowAsError "download & install IPKG$(FormatAsPlural "$IPKG_download_count") failed $(FormatAsExitcode $result)"
            DebugErrorFile "$log_pathfile"
            returncode=1
        fi
    fi

    DebugFuncExit
    return $returncode

    }

PIP.Install()
    {

    Session.SkipPackageProcessing.IsSet && return
    Session.Pips.Install.IsNot && return

    DebugFuncEntry
    local exec_cmd=''
    local result=0
    local returncode=0
    local packages=''
    local desc="'Python 3' modules"
    local log_pathfile=$PACKAGE_LOGS_PATH/py3-modules.$INSTALL_LOG_FILE

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
            return 1
        fi
    fi

    [[ -n ${SHERPA_COMMON_PIPS// /} ]] && exec_cmd="$pip3_cmd install $SHERPA_COMMON_PIPS --disable-pip-version-check --cache-dir $PIP_CACHE_PATH"
    [[ -n ${SHERPA_COMMON_PIPS// /} && -n ${packages// /} ]] && exec_cmd+=" && "
    [[ -n ${packages// /} ]] && exec_cmd+="$pip3_cmd install $packages --disable-pip-version-check --cache-dir $PIP_CACHE_PATH"

    # KLUDGE: force recompilation of 'sabyenc3' package so it's recognised by SABnzbd. See: https://forums.sabnzbd.org/viewtopic.php?p=121214#p121214
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

GetInstalledQPKGVars()
    {

    # Load variables for specified package

    # input:
    #   $1 = QPKG name

    # output:
    #   $? = 0 if successful, 1 if failed
    #   $package_installed_path
    #   $package_config_path

    QPKG.NotInstalled "$1" && return 1

    package_installed_path=''
    package_config_path=''
    local prev_config_dir=''
    local prev_config_file=''
    local package_settings_pathfile=''
    package_installed_path=$($GETCFG_CMD "$1" Install_Path -f $APP_CENTER_CONFIG_PATHFILE)

    for prev_config_dir in "${PREV_QPKG_CONFIG_DIRS[@]}"; do
        package_config_path=$package_installed_path/$prev_config_dir
        [[ -d $package_config_path ]] && break
    done

    for prev_config_file in "${PREV_QPKG_CONFIG_FILES[@]}"; do
        package_settings_pathfile=$package_config_path/$prev_config_file
        [[ -f $package_settings_pathfile ]] && break
    done

    return 0

    }

GetInstalledQPKGServicePathFile()
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

GetInstalledQPKGVersion()
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
        DebugWarning "unable to get status of $(FormatAsPackageName "$1") service. It may be a non-sherpa package, or a package earlier than 200816c that doesn't support service results."
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

    for index in "${!SHERPA_QPKG_NAME[@]}"; do
        if [[ $1 = "${SHERPA_QPKG_NAME[$index]}" ]] && [[ ${SHERPA_QPKG_ARCH[$index]} = all || ${SHERPA_QPKG_ARCH[$index]} = "$NAS_QPKG_ARCH" ]]; then
            echo "${SHERPA_QPKG_URL[$index]}"
            return 0
        fi
    done

    return 1

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

QPKG.Download()
    {

    # input:
    #   $1 = QPKG name to download

    # output:
    #   $? = 0 if successful, 1 if failed

    Session.Error.IsSet && return

    if [[ -z $1 ]]; then
        DebugError "no package name specified"
        code_pointer=4
        return 1
    fi

    local result=0
    local returncode=0
    local remote_url=$(GetQPKGRemoteURL "$1")
    local remote_filename=$($BASENAME_CMD "$remote_url")
    local remote_filename_md5=$(GetQPKGMD5 "$1")
    local local_pathfile=$QPKG_DL_PATH/$remote_filename
    local local_filename=$($BASENAME_CMD "$local_pathfile")
    local log_pathfile=$PACKAGE_LOGS_PATH/$local_filename.$DOWNLOAD_LOG_FILE

    if [[ -z $remote_url ]]; then
        DebugWarning "no URL found for this package [$1]"
        code_pointer=5
        return
    elif [[ -z $remote_filename_md5 ]]; then
        DebugWarning "no remote MD5 found for this package [$1]"
        code_pointer=6
        return
    fi

    if [[ -e $local_pathfile ]]; then
        if FileMatchesMD5 "$local_pathfile" "$remote_filename_md5"; then
            DebugInfo "local package checksum correct $(FormatAsFileName "$local_filename") so skipping download"
        else
            DebugWarning "local package checksum incorrect $(FormatAsFileName "$local_filename")"
            DebugInfo "deleting $(FormatAsFileName "$local_filename")"
            rm -f "$local_pathfile"
        fi
    fi

    if Session.Error.IsNot && [[ ! -e $local_pathfile ]]; then
        ShowAsProc "downloading $(FormatAsFileName "$remote_filename")"

        [[ -e $log_pathfile ]] && rm -f "$log_pathfile"

        if Session.Debug.To.Screen.IsSet; then
            RunThisAndLogResultsRealtime "$CURL_CMD $curl_insecure_arg --output $local_pathfile $remote_url" "$log_pathfile"
            result=$?
        else
            RunThisAndLogResults "$CURL_CMD $curl_insecure_arg --output $local_pathfile $remote_url" "$log_pathfile"
            result=$?
        fi

        if [[ $result -eq 0 ]]; then
            if FileMatchesMD5 "$local_pathfile" "$remote_filename_md5"; then
                ShowAsDone "downloaded $(FormatAsFileName "$remote_filename")"
            else
                ShowAsError "downloaded package checksum incorrect $(FormatAsFileName "$local_pathfile")"
                returncode=1
            fi
        else
            ShowAsError "download failed $(FormatAsFileName "$local_pathfile") $(FormatAsExitcode $result)"
            DebugErrorFile "$log_pathfile"
            returncode=1
        fi
    fi

    return $returncode

    }

QPKG.Install()
    {

    # $1 = QPKG name to install

    Session.Error.IsSet && return
    Session.SkipPackageProcessing.IsSet && return

    if [[ -z $1 ]]; then
        DebugError "no package name specified "
        code_pointer=7
        return 1
    elif QPKG.Installed "$1"; then
        DebugQPKG "$(FormatAsPackageName "$1")" "already installed"
        return 1
    fi

    local target_file=''
    local result=0
    local returncode=0
    local local_pathfile="$(GetQPKGPathFilename "$1")"
    local log_pathfile=''

    if [[ ${local_pathfile##*.} = zip ]]; then
        $UNZIP_CMD -nq "$local_pathfile" -d "$QPKG_DL_PATH"
        local_pathfile="${local_pathfile%.*}"
    fi

    target_file=$($BASENAME_CMD "$local_pathfile")
    log_pathfile=$PACKAGE_LOGS_PATH/$target_file.$INSTALL_LOG_FILE

    ShowAsProcLong "installing $(FormatAsFileName "$target_file")"

    sh "$local_pathfile" > "$log_pathfile" 2>&1
    result=$?

    if [[ $result -eq 0 || $result -eq 10 ]]; then
        ShowAsDone "installed $(FormatAsFileName "$target_file")"
        GetQPKGServiceStatus "$1"
    else
        ShowAsError "installation failed $(FormatAsFileName "$target_file") $(FormatAsExitcode $result)"
        DebugErrorFile "$log_pathfile"
        returncode=1
    fi

    return $returncode

    }

QPKG.Reinstall()
    {

    # $1 = QPKG name to install

    Session.Error.IsSet && return
    Session.SkipPackageProcessing.IsSet && return

    if [[ -z $1 ]]; then
        DebugError "no package name specified "
        code_pointer=8
        return 1
    elif QPKG.NotInstalled "$1"; then
        DebugQPKG "$(FormatAsPackageName "$1")" "not installed"
        code_pointer=9
        return 1
    fi

    local target_file=''
    local result=0
    local returncode=0
    local local_pathfile="$(GetQPKGPathFilename "$1")"
    local log_pathfile=''

    if [[ ${local_pathfile##*.} = zip ]]; then
        $UNZIP_CMD -nq "$local_pathfile" -d "$QPKG_DL_PATH"
        local_pathfile="${local_pathfile%.*}"
    fi

    target_file=$($BASENAME_CMD "$local_pathfile")
    log_pathfile=$PACKAGE_LOGS_PATH/$target_file.$REINSTALL_LOG_FILE

    ShowAsProcLong "re-installing $(FormatAsFileName "$target_file")"

    sh "$local_pathfile" > "$log_pathfile" 2>&1
    result=$?

    if [[ $result -eq 0 || $result -eq 10 ]]; then
        ShowAsDone "re-installed $(FormatAsFileName "$target_file")"
        GetQPKGServiceStatus "$1"
    else
        ShowAsError "$re-installation failed $(FormatAsFileName "$target_file") $(FormatAsExitcode $result)"
        DebugErrorFile "$log_pathfile"
        returncode=1
    fi

    return $returncode

    }

QPKG.Upgrade()
    {

    # $1 = QPKG name to upgrade

    Session.Error.IsSet && return
    Session.SkipPackageProcessing.IsSet && return

    if [[ -z $1 ]]; then
        DebugError "no package name specified "
        code_pointer=10
        return 1
    fi

    local prefix=''
    local target_file=''
    local result=0
    local returncode=0
    local local_pathfile="$(GetQPKGPathFilename "$1")"
    [[ -n $2 && $2 = '--forced' ]] && prefix='force-'

    if [[ ${local_pathfile##*.} = zip ]]; then
        $UNZIP_CMD -nq "$local_pathfile" -d "$QPKG_DL_PATH"
        local_pathfile="${local_pathfile%.*}"
    fi

    target_file=$($BASENAME_CMD "$local_pathfile")

    local log_pathfile=$PACKAGE_LOGS_PATH/$target_file.$UPGRADE_LOG_FILE

    ShowAsProcLong "${prefix}upgrading $(FormatAsFileName "$target_file")"

    sh "$local_pathfile" > "$log_pathfile" 2>&1
    result=$?

    if [[ $result -eq 0 || $result -eq 10 ]]; then
        ShowAsDone "${prefix}upgraded $(FormatAsFileName "$target_file")"
        GetQPKGServiceStatus "$1"
    else
        ShowAsError "${prefix}upgrade failed $(FormatAsFileName "$target_file") $(FormatAsExitcode $result)"
        DebugErrorFile "$log_pathfile"
        returncode=1
    fi

    return $returncode

    }

QPKG.Uninstall()
    {

    # input:
    #   $1 = QPKG name

    # output:
    #   $? = 0 if successful, 1 if failed

    Session.Error.IsSet && return

    if [[ -z $1 ]]; then
        DebugError "no package name specified "
        code_pointer=11
        return 1
    elif QPKG.NotInstalled "$1"; then
        DebugQPKG "$(FormatAsPackageName "$1")" "not installed"
        code_pointer=12
        return 1
    fi

    local result=0
    local qpkg_installed_path="$($GETCFG_CMD "$1" Install_Path -f $APP_CENTER_CONFIG_PATHFILE)"

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

    return 0

    }

QPKG.Restart()
    {

    # Restarts the service script for the QPKG named in $1

    # input:
    #   $1 = QPKG name

    # output:
    #   $? = 0 if successful, 1 if failed

    if [[ -z $1 ]]; then
        DebugError "no package name specified "
        code_pointer=13
        return 1
    elif QPKG.NotInstalled "$1"; then
        DebugQPKG "$(FormatAsPackageName "$1")" "not installed"
        code_pointer=14
        return 1
    fi

    local result=0
    local package_init_pathfile=$(GetInstalledQPKGServicePathFile "$1")
    local log_pathfile=$PACKAGE_LOGS_PATH/$1.$RESTART_LOG_FILE

    ShowAsProc "restarting $(FormatAsPackageName "$1")"

    sh "$package_init_pathfile" restart > "$log_pathfile" 2>&1
    result=$?

    if [[ $result -eq 0 ]]; then
        ShowAsDone "restarted $(FormatAsPackageName "$1")"
        GetQPKGServiceStatus "$1"
    else
        ShowAsWarning "Could not restart $(FormatAsPackageName "$1") $(FormatAsExitcode $result)"

        if Session.Debug.To.Screen.IsSet; then
            DebugInfoThickSeparator
            $CAT_CMD "$log_pathfile"
            DebugInfoThickSeparator
        else
            $CAT_CMD "$log_pathfile" >> "$DEBUG_LOG_PATHFILE"
        fi
        return 1
    fi

    return 0

    }

QPKG.Enable()
    {

    # $1 = package name to enable

    if [[ -z $1 ]]; then
        DebugError "no package name specified "
        code_pointer=15
        return 1
    elif QPKG.NotInstalled "$1"; then
        DebugQPKG "$(FormatAsPackageName "$1")" "not installed"
        code_pointer=16
        return 1
    fi

    if QPKG.NotEnabled "$1"; then
        DebugProc "enabling package icon"
        $SETCFG_CMD "$1" Enable TRUE -f $APP_CENTER_CONFIG_PATHFILE
        DebugDone "$(FormatAsPackageName "$1") icon enabled"
    fi

    }

QPKG.Backup()
    {

    # calls the service script for the QPKG named in $1 and runs a backup operation

    # input:
    #   $1 = QPKG name

    # output:
    #   $? = 0 if successful, 1 if failed

    if [[ -z $1 ]]; then
        DebugError "no package name specified "
        code_pointer=17
        return 1
    elif QPKG.NotInstalled "$1"; then
        DebugQPKG "$(FormatAsPackageName "$1")" "not installed"
        code_pointer=18
        return 1
    fi

    local result=0
    local package_init_pathfile=$(GetInstalledQPKGServicePathFile "$1")
    local log_pathfile=$PACKAGE_LOGS_PATH/$1.$BACKUP_LOG_FILE

    ShowAsProc "backing-up $(FormatAsPackageName "$1") configuration"

    sh "$package_init_pathfile" backup > "$log_pathfile" 2>&1
    result=$?

    if [[ $result -eq 0 ]]; then
        ShowAsDone "backed-up $(FormatAsPackageName "$1") configuration"
        GetQPKGServiceStatus "$1"
    else
        ShowAsWarning "Could not backup $(FormatAsPackageName "$1") configuration $(FormatAsExitcode $result)"

        if Session.Debug.To.Screen.IsSet; then
            DebugInfoThickSeparator
            $CAT_CMD "$log_pathfile"
            DebugInfoThickSeparator
        else
            $CAT_CMD "$log_pathfile" >> "$DEBUG_LOG_PATHFILE"
        fi
        return 1
    fi

    return 0

    }

QPKG.Restore()
    {

    # calls the service script for the QPKG named in $1 and runs a restore operation

    # input:
    #   $1 = QPKG name

    # output:
    #   $? = 0 if successful, 1 if failed

    if [[ -z $1 ]]; then
        DebugError "no package name specified "
        code_pointer=19
        return 1
    elif QPKG.NotInstalled "$1"; then
        DebugQPKG "$(FormatAsPackageName "$1")" "not installed"
        code_pointer=20
        return 1
    fi

    local result=0
    local package_init_pathfile=$(GetInstalledQPKGServicePathFile "$1")
    local log_pathfile=$PACKAGE_LOGS_PATH/$1.$RESTORE_LOG_FILE

    ShowAsProc "restoring $(FormatAsPackageName "$1") configuration"

    sh "$package_init_pathfile" restore > "$log_pathfile" 2>&1
    result=$?

    if [[ $result -eq 0 ]]; then
        ShowAsDone "restored $(FormatAsPackageName "$1") configuration"
        GetQPKGServiceStatus "$1"
    else
        ShowAsWarning "Could not restore $(FormatAsPackageName "$1") configuration $(FormatAsExitcode $result)"

        if Session.Debug.To.Screen.IsSet; then
            DebugInfoThickSeparator
            $CAT_CMD "$log_pathfile"
            DebugInfoThickSeparator
        else
            $CAT_CMD "$log_pathfile" >> "$DEBUG_LOG_PATHFILE"
        fi
        return 1
    fi

    return 0

    }

GetTheseQPKGDeps()
    {

    # From a specified list of QPKG names, find all dependent QPKGs.

    # input:
    #   $1 = string with space-separated initial QPKG names.

    # output:
    #   $QPKG_pre_download_list = name-sorted list with complete list of all QPKGs, including those originally specified.

    QPKG_pre_download_list=''
    local requested_list=''
    local last_list_array=()
    local new_list_array=()
    local iterations=0
    local -r ITERATION_LIMIT=20
    local complete=false

    requested_list=$(DeDupeWords "$1")
    [[ -z $requested_list ]] && return
    last_list_array=(${requested_list})

    DebugInfo "requested QPKGs: $requested_list"

    DebugProc 'finding QPKG dependencies'
    while [[ $iterations -lt $ITERATION_LIMIT ]]; do
        ((iterations++))
        DebugProc "iteration $iterations"
        new_list_array=()

        for package in "${last_list_array[@]}"; do
            new_list_array+=($(GetQPKGDeps "$package"))
        done

        new_list_array=($(DeDupeWords "${new_list_array[*]}"))
        dependency_list_array+=(${new_list_array[@]})

        if [[ ${#new_list_array[@]} -gt 0 ]]; then
            last_list_array=(${new_list_array[*]})
        else
            DebugDone 'complete'
            DebugInfo "found all QPKG dependencies in $iterations iteration$(FormatAsPlural $iterations)"
            complete=true
            break
        fi
    done

    if [[ $complete = false ]]; then
        DebugError "QPKG dependency list is incomplete! Consider raising \$ITERATION_LIMIT [$ITERATION_LIMIT]."
        Session.SuggestIssue.Set
    fi

    QPKG_pre_download_list=$(DeDupeWords "$requested_list ${dependency_list_array[*]}")
    DebugInfo "QPKGs requested + dependencies: $QPKG_pre_download_list"

    return 0

    }

ExcludeInstalledQPKGs()
    {

    # From a specified list of QPKG names, exclude those already installed.

    # input:
    #   $1 = string with space-separated initial QPKG names.

    # output:
    #   $QPKGs_download_array() = name-sorted array with space-separated QPKG names, minus those already installed.

    QPKGs_download_array=()
    local requested_list=''
    local requested_list_array=()
    local element=''

    requested_list=$(DeDupeWords "$1")
    [[ -z $requested_list ]] && return
    requested_list_array=(${requested_list})

    DebugProc 'excluding QPKGs already installed'

    for element in "${requested_list_array[@]}"; do
        if QPKG.NotInstalled "$element"; then
            QPKGs_download_array+=($element)
            QPKGs.ToInstall.Add "$package"
        elif QPKGs.ToInstall.IsAny && [[ ${QPKGs_to_install[*]} == *"$element"* ]]; then
            QPKGs_download_array+=($element)
        elif QPKGs.ToReinstall.IsAny && [[ ${QPKGs_to_reinstall[*]} == *"$element"* ]]; then
            QPKGs_download_array+=($element)
        elif QPKGs.ToUpgrade.IsAny && [[ ${QPKGs_to_upgrade[*]} == *"$element"* ]]; then
            QPKGs_download_array+=($element)
        elif QPKGs.ToForceUpgrade.IsAny && [[ ${QPKGs_to_force_upgrade[*]} == *"$element"* ]]; then
            QPKGs_download_array+=($element)
        fi
    done

    DebugDone 'complete'

    return 0

    }

GetAllIPKGDepsToDownload()
    {

    # From a specified list of IPKG names, find all dependent IPKGs, exclude those already installed, then generate a total qty to download and a total download byte-size

    # input:
    #   $1 = string with space-separated initial IPKG names

    # output:
    #   $IPKG_download_list = name-sorted array with complete list of all IPKGs, including those originally specified
    #   $IPKG_download_count = number of packages to be downloaded
    #   $IPKG_download_size = byte-count of packages to be downloaded

    if IsNotSysFileExist $OPKG_CMD || IsNotSysFileExist $GNU_GREP_CMD; then
        code_pointer=21
        return 1
    fi

    DebugFuncEntry

    IPKG_download_list=()
    IPKG_download_count=0
    IPKG_download_size=0
    local requested_list=''
    local this_list=()
    local dependency_accumulator=()
    local pre_download_list=''
    local element=''
    local iterations=0
    local -r ITERATION_LIMIT=20
    local complete=false

    # remove duplicate entries
    requested_list=$(DeDupeWords "$1")
    this_list=($requested_list)

    ShowAsProc 'determining IPKGs required'
    DebugInfo "IPKGs requested: $requested_list"

    IPKGs.Archive.Open || return 1

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
    # shellcheck disable=SC2068
    for element in ${pre_download_list[@]}; do
        if [[ $element != 'ca-certs' ]]; then       # KLUDGE: 'ca-certs' appears to be a bogus meta-package, so silently exclude it from attempted installation.
            if [[ $element != 'libjpeg' ]]; then    # KLUDGE: 'libjpeg' appears to have been replaced by 'libjpeg-turbo', but many packages still list 'libjpeg' as a dependency, so replace it with 'libjpeg-turbo'.
                if ! $OPKG_CMD status "$element" | $GREP_CMD -q "Status:.*installed"; then
                    IPKG_download_list+=($element)
                fi
            elif ! $OPKG_CMD status 'libjpeg-turbo' | $GREP_CMD -q "Status:.*installed"; then
                [[ ${IPKG_download_list[*]} != *libjpeg-turbo* ]] && IPKG_download_list+=(libjpeg-turbo)
            fi
        fi
    done
    DebugDone 'complete'
    DebugInfo "IPKGs to download: ${IPKG_download_list[*]}"

    IPKG_download_count=${#IPKG_download_list[@]}

    if [[ $IPKG_download_count -gt 0 ]]; then
        DebugProc "determining size of IPKG$(FormatAsPlural "$IPKG_download_count") to download"
        size_array=($($GNU_GREP_CMD -w '^Package:\|^Size:' "$EXTERNAL_PACKAGE_LIST_PATHFILE" | $GNU_GREP_CMD --after-context 1 --no-group-separator ": $($SED_CMD 's/ /$ /g;s/\$ /\$\\\|: /g' <<< "${IPKG_download_list[*]}")$" | $GREP_CMD '^Size:' | $SED_CMD 's|^Size: ||'))
        IPKG_download_size=$(IFS=+; echo "$((${size_array[*]}))")   # a neat trick found here https://stackoverflow.com/a/13635566/6182835
        DebugDone 'complete'
        DebugVar IPKG_download_size
        ShowAsDone "$IPKG_download_count IPKG$(FormatAsPlural "$IPKG_download_count") ($(FormatAsISOBytes "$IPKG_download_size")) to be downloaded"
    else
        ShowAsDone 'no IPKGs are required'
    fi

    IPKGs.Archive.Close

    DebugFuncExit
    return 0

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

ReloadProfile()
    {

    local opkg_prefix=/opt/bin:/opt/sbin

    if QPKG.Installed Entware; then
        export PATH="$opkg_prefix:$($SED_CMD "s|$opkg_prefix||" <<< "$PATH")"
        DebugDone 'adjusted $PATH for Entware'
        DebugVar PATH
    fi

    return 0

    }

IPKGs.Install()
    {

    Session.SkipPackageProcessing.IsSet && return
    Session.Ipkgs.Install.IsNot && return
    UpdateEntware
    Session.Error.IsSet && return

    local packages="$SHERPA_COMMON_IPKGS"
    local index=0

    if User.Opts.Apps.All.Install.IsSet; then
        for index in "${!SHERPA_QPKG_NAME[@]}"; do
            packages+=" ${SHERPA_QPKG_IPKGS[$index]}"
        done
    else
        for index in "${!SHERPA_QPKG_NAME[@]}"; do
            if QPKG.ToBeInstalled "${SHERPA_QPKG_NAME[$index]}" || QPKG.Installed "${SHERPA_QPKG_NAME[$index]}" || QPKG.ToBeUpgraded "${SHERPA_QPKG_NAME[$index]}"; then
                packages+=" ${SHERPA_QPKG_IPKGS[$index]}"
            fi
        done
    fi

    if QPKG.ToBeInstalled SABnzbd || QPKG.Installed SABnzbd || QPKG.Installed SABnzbdplus; then
        [[ $NAS_QPKG_ARCH = none ]] && packages+=' par2cmdline'
    fi

    InstallIPKGBatch "$packages"

    # in-case 'python' has disappeared again ...
    [[ ! -L /opt/bin/python && -e /opt/bin/python3 ]] && ln -s /opt/bin/python3 /opt/bin/python

    return 0

    }

IPKGs.Archive.Open()
    {

    # extract the 'opkg' package list file

    if [[ ! -e $EXTERNAL_PACKAGE_ARCHIVE_PATHFILE ]]; then
        ShowAsError 'could not locate the IPKG list file'
        return 1
    fi

    IPKGs.Archive.Close

    RunThisAndLogResults "$Z7_CMD e -o$($DIRNAME_CMD "$EXTERNAL_PACKAGE_LIST_PATHFILE") $EXTERNAL_PACKAGE_ARCHIVE_PATHFILE" "$WORK_PATH/ipkg.list.archive.extract"

    if [[ ! -e $EXTERNAL_PACKAGE_LIST_PATHFILE ]]; then
        ShowAsError 'could not open the IPKG list file'
        return 1
    fi

    return 0

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
        progress_message=" $percent ($(FormatAsISOBytes "$current_bytes")/$(FormatAsISOBytes "$total_bytes"))"

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

IsQNAP()
    {

    # is this a QNAP NAS?

    if [[ ! -e /etc/init.d/functions ]]; then
        ShowAsAbort 'QTS functions missing (is this a QNAP NAS?)'
        return 1
    fi

    return 0

    }

Session.LockFile.Claim()
    {

    [[ -z $1 ]] && return 1

    readonly RUNTIME_LOCK_PATHFILE="$1"

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

CheckPythonPathAndVersion()
    {

    [[ -z $1 ]] && return

    if location=$(command -v $1 2>&1); then
        DebugUserspace.OK "default '$1' path" "$location"
        DebugUserspace.OK "default '$1' version" "$(version=$($1 -V 2>&1) && echo "$version" || echo '<unknown>')"
    else
        DebugUserspace.Warning "default '$1' path" '<not present>'
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

DisplayAsSyntaxIndentedExample()
    {

    # $1 = description
    # $2 = example syntax

    if [[ -z $2 && ${1: -1} = ':' ]]; then
        printf "       %s\n" "$1"
    elif [[ -z $1 ]]; then
        printf "       # %s\n" "$2"
    elif [[ ${1: -1} = '!' ]]; then
        printf "\n   %s \n       # %s\n" "$(tr "[a-z]" "[A-Z]" <<< "${1:0:1}")${1:1}" "$2"
    else
        printf "\n   %s:\n       # %s\n" "$(tr "[a-z]" "[A-Z]" <<< "${1:0:1}")${1:1}" "$2"
    fi

    Session.LineSpace.Clear

    }

DisplayAsIndentedExample()
    {

    # $1 = description
    # $2 = example syntax

    if [[ -z $2 && ${1: -1} = ':' ]]; then
        printf "       %s\n" "$1"
    elif [[ -z $1 ]]; then
        printf "       %s\n" "$2"
    elif [[ ${1: -1} = '!' ]]; then
        printf "\n   %s \n       %s\n" "$(tr "[a-z]" "[A-Z]" <<< "${1:0:1}")${1:1}" "$2"
    else
        printf "\n   %s:\n       %s\n" "$(tr "[a-z]" "[A-Z]" <<< "${1:0:1}")${1:1}" "$2"
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

    DisplayAsProjectSyntaxIndentedExample "to learn more about available $(FormatAsHelpActions), type" '--actions'

    DisplayAsProjectSyntaxIndentedExample '' '--actions-all'

    DisplayAsProjectSyntaxIndentedExample "to learn more about available $(FormatAsHelpPackages), type" '--packages'

    DisplayAsProjectSyntaxIndentedExample "or, for more about available $(FormatAsHelpOptions), type" '--options'

    echo -e "\nThere's also $(FormatAsURL 'https://github.com/OneCDOnly/sherpa/wiki')"

    return 0

    }

Help.Actions.Show()
    {

    Help.Basic.Show
    DisplayLineSpaceIfNoneAlready
    Display "* $(FormatAsHelpActions) usage examples:"

    DisplayAsProjectSyntaxIndentedExample 'install the following packages' "--install $(FormatAsHelpPackages)"

    DisplayAsProjectSyntaxIndentedExample 'uninstall the following packages' "--uninstall $(FormatAsHelpPackages)"

    DisplayAsProjectSyntaxIndentedExample 'reinstall the following packages' "--reinstall $(FormatAsHelpPackages)"

    DisplayAsProjectSyntaxIndentedExample 'upgrade the following packages and the internal applications' "--upgrade $(FormatAsHelpPackages)"

    DisplayAsProjectSyntaxIndentedExample 'force-upgrade the following packages and the internal applications' "--upgrade --force $(FormatAsHelpPackages)"

    DisplayAsProjectSyntaxIndentedExample 'upgrade the internal applications only' "--restart $(FormatAsHelpPackages)"

    DisplayAsProjectSyntaxIndentedExample 'backup the internal application configurations to the default backup location' "--backup $(FormatAsHelpPackages)"

    DisplayAsProjectSyntaxIndentedExample 'restore the internal application configurations from the default backup location' "--restore $(FormatAsHelpPackages)"

    #DisplayAsProjectSyntaxIndentedExample '--status'

    DisplayAsProjectSyntaxExample "$(FormatAsHelpActions) to affect all packages can be seen with" '--actions-all'

    Help.BackupLocation.Show

    DisplayAsProjectSyntaxExample "multiple $(FormatAsHelpActions) are supported like this" '--install sabnzbd sickchill --restart transmission --uninstall lazy nzbget --upgrade nzbtomedia'

    DisplayAsInfoExample "$(FormatAsHelpActions) may be specified in any order, but the package processing order-of-operations is (first ► last)" 'backup ► uninstall ► force-upgrade ► upgrade ► install ► reinstall ► restore ► restart'

    return 0

    }

Help.ActionsAll.Show()
    {

    Help.Basic.Show
    DisplayLineSpaceIfNoneAlready
    Display "* $(FormatAsHelpActions) usage examples:"

    DisplayAsProjectSyntaxIndentedExample 'install everything!' '--install-all'

    DisplayAsProjectSyntaxIndentedExample "uninstall everything! (except $(FormatAsPackageName Entware) for now)" '--uninstall-all-packages-please'

    DisplayAsProjectSyntaxIndentedExample "reinstall all installed packages (except $(FormatAsPackageName Entware) for now)" '--reinstall-all'

    DisplayAsProjectSyntaxIndentedExample 'upgrade all installed packages (including the internal applications)' '--upgrade-all'

    DisplayAsProjectSyntaxIndentedExample 'restart all installed packages (only upgrades the internal applications, not the packages)' '--restart-all'

    DisplayAsProjectSyntaxIndentedExample 'ensure all application dependencies are installed' '--check-all'

    DisplayAsProjectSyntaxIndentedExample 'list all installable packages' '--list'

    DisplayAsProjectSyntaxIndentedExample 'list only installed packages' '--list-installed'

    DisplayAsProjectSyntaxIndentedExample 'list only packages that are not installed' '--list-installable'

    DisplayAsProjectSyntaxIndentedExample 'list only upgradable packages' '--list-upgradable'

    DisplayAsProjectSyntaxIndentedExample 'backup all application configurations to the default backup location' '--backup-all'

    DisplayAsProjectSyntaxIndentedExample 'restore all application configurations from the default backup location' '--restore-all'

#   DisplayAsProjectSyntaxIndentedExample '--status-all'

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

    for package in "${QPKGS_user_installable[@]}"; do
        if QPKG.Upgradable "$package"; then
            package_name_message="$(ColourTextBrightYellow "$package")"
        else
            package_name_message="$package"
        fi

        if [[ $package = Entware ]]; then       # KLUDGE: use this until independent package checking works.
            package_note_message='(installed by-default)'
        else
            package_note_message=''
        fi

        DisplayAsHelpPackageNameExample "$package_name_message" "$package_note_message"
    done

    DisplayAsProjectSyntaxExample "example: to install $(FormatAsPackageName SABnzbd)" '--install SABnzbd'

    DisplayAsProjectSyntaxExample "abbreviations may also be used to specify $(FormatAsHelpPackages). To see these" '--abs'

    return 0

    }

Help.Options.Show()
    {

    Help.Basic.Show
    DisplayLineSpaceIfNoneAlready
    Display "* $(FormatAsHelpOptions) usage examples:"

    DisplayAsProjectSyntaxIndentedExample 'process one or more packages and show live debugging information' "$(FormatAsHelpActions) $(FormatAsHelpPackages) --debug"

    DisplayAsProjectSyntaxIndentedExample "don't check free-space on target filesystem when installing $(FormatAsPackageName Entware) packages" "$(FormatAsHelpActions) $(FormatAsHelpPackages) --ignore-space"

    DisplayAsProjectSyntaxIndentedExample 'display helpful tips and shortcuts' '--tips'

    DisplayAsProjectSyntaxIndentedExample 'display troubleshooting options' '--problems'

    return 0

    }

Help.Problems.Show()
    {

    Help.Basic.Show
    DisplayLineSpaceIfNoneAlready
    Display "* usage examples when dealing with problems:"

    DisplayAsProjectSyntaxIndentedExample 'process one or more packages and show live debugging information' "$(FormatAsHelpActions) $(FormatAsHelpPackages) --debug"

    DisplayAsProjectSyntaxIndentedExample 'ensure all application dependencies are installed' '--check-all'

    DisplayAsProjectSyntaxIndentedExample "don't check free-space on target filesystem when installing $(FormatAsPackageName Entware) packages" "$(FormatAsHelpActions) $(FormatAsHelpPackages) --ignore-space"

    DisplayAsProjectSyntaxIndentedExample 'restart all installed packages (upgrades the internal applications, not the packages)' '--restart-all'

    DisplayAsProjectSyntaxIndentedExample "view the $(FormatAsScriptTitle) debug log" '--log'

    DisplayAsProjectSyntaxIndentedExample "upload the most-recent $(printf "%'.f" $LOG_TAIL_LINES) entries in your $(FormatAsScriptTitle) log to the $(FormatAsURL 'https://termbin.com') public pastebin. A URL will be generated afterward" '--paste'

    Display "\n$(ColourTextBrightOrange "* If you need help, please include a copy of your") $(FormatAsScriptTitle) $(ColourTextBrightOrange "log for analysis!")"

    return 0

    }

Help.Issue.Show()
    {

    DisplayLineSpaceIfNoneAlready
    Display "* Please consider creating a new issue for this on GitHub:\n\thttps://github.com/OneCDOnly/sherpa/issues"

    Display "\n* Alternatively, post on the QNAP NAS Community Forum:\n\thttps://forum.qnap.com/viewtopic.php?f=320&t=132373"

    DisplayAsProjectSyntaxIndentedExample "view the $(FormatAsScriptTitle) debug log" '--log'

    DisplayAsProjectSyntaxIndentedExample "upload the most-recent $(printf "%'.f" $LOG_TAIL_LINES) entries in your $(FormatAsScriptTitle) log to the $(FormatAsURL 'https://termbin.com') public pastebin. A URL will be generated afterward" '--paste'

    Display "\n$(ColourTextBrightOrange '* If you need help, please include a copy of your') $(FormatAsScriptTitle) $(ColourTextBrightOrange 'log for analysis!')"

    return 0

    }

Help.Tips.Show()
    {

    Help.Basic.Show
    DisplayLineSpaceIfNoneAlready
    Display "* helpful tips and shortcuts:"

    DisplayAsProjectSyntaxIndentedExample "the leading '--' characters before $(FormatAsHelpActions) and $(FormatAsHelpOptions) are optional"

    DisplayAsProjectSyntaxIndentedExample "install all available $(FormatAsScriptTitle) packages" '--install-all'

    DisplayAsProjectSyntaxIndentedExample 'package abbreviations also work. To see these' '--abs'

    DisplayAsProjectSyntaxIndentedExample 'ensure all application dependencies are installed' '--check-all'

    DisplayAsProjectSyntaxIndentedExample 'restart all packages (only upgrades the internal applications, not the packages)' '--restart-all'

    DisplayAsProjectSyntaxIndentedExample 'upgrade all installed packages (including the internal applications)' '--upgrade-all'

    DisplayAsProjectSyntaxIndentedExample "upload the most-recent $(printf "%'.f" $LOG_TAIL_LINES) entries in your $(FormatAsScriptTitle) log to the $(FormatAsURL 'https://termbin.com') public pastebin. A URL will be generated afterward" '--paste'

    DisplayAsProjectSyntaxIndentedExample 'display all package-manager scripts versions' '--version'

    Help.BackupLocation.Show

    echo -e "\n$(ColourTextBrightOrange "* If you need help, please include a copy of your") $(FormatAsScriptTitle) $(ColourTextBrightOrange "log for analysis!")"

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
            if QPKG.Upgradable "${SHERPA_QPKG_NAME[$package_index]}"; then
                printf "%26s: %s\n" "$(ColourTextBrightYellow "${SHERPA_QPKG_NAME[$package_index]}")" "$($SED_CMD 's| |, |g' <<< "${SHERPA_QPKG_ABBRVS[$package_index]}")"
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

    DisplayAsSyntaxExample "the default backup location can be accessed by running" "cd $(Session.Backup.Path)"

    return 0

    }

Log.View.Show()
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

Versions.Show()
    {

    Display "package: $PACKAGE_VERSION"
    Display "loader: $LOADER_SCRIPT_VERSION"
    Display "manager: $MANAGER_SCRIPT_VERSION"

    }

QPKGs.Dependant.Restart()
    {

    # restart all sherpa QPKGs except independents. Needed if user has requested each QPKG update itself.

    Session.SkipPackageProcessing.IsSet && return

    [[ -z ${SHERPA_DEP_QPKGs[*]} || ${#SHERPA_DEP_QPKGs[@]} -eq 0 ]] && return

    DebugFuncEntry
    local package=''

    for package in "${SHERPA_DEP_QPKGs[@]}"; do
        QPKG.Enabled "$package" && QPKG.Restart "$package"
    done

    DebugFuncExit
    return 0

    }

QPKGs.RestartNotUpgraded()
    {

    # restart all sherpa QPKGs except those that were just upgraded.

    Session.SkipPackageProcessing.IsSet && return

    [[ -z ${SHERPA_DEP_QPKGs[*]} || ${#SHERPA_DEP_QPKGs[@]} -eq 0 ]] && return

    DebugFuncEntry
    local package=''

    for package in "${SHERPA_DEP_QPKGs[@]}"; do
        QPKG.Enabled "$package" && ! QPKG.Upgradable "$package" && QPKG.Restart "$package"
    done

    DebugFuncExit
    return 0

    }

QPKGs.NotInstalled.Show()
    {

    for package in $(QPKGs.NotInstalled.Print); do
        echo "$package"
    done

    return 0

    }

QPKGs.Upgradable.Show()
    {

    for package in $(QPKGs.Upgradable.Print); do
        echo "$package"
    done

    return 0

    }

QPKGs.All.Show()
    {

    for package in "${QPKGS_user_installable[@]}"; do
        echo "$package"
    done

    return 0

    }

QPKGs.Download.Build()
    {

    local QPKGs_initial_download_array=()

    # build an initial package download list. Items on this list will be skipped at download-time if they can be found in local cache.
    if User.Opts.Apps.All.Install.IsSet; then
        QPKGs_initial_download_array+=($(QPKGs.NotInstalled.Array))
        for package in "${QPKGs_initial_download_array[@]}"; do
            QPKGs.ToInstall.Add "$package"
        done
    elif User.Opts.Apps.All.Upgrade.IsSet; then
        QPKGs_initial_download_array=($(QPKGs.Upgradable.Array))
        for package in "${QPKGs_initial_download_array[@]}"; do
            QPKGs.ToUpgrade.Add "$package"
        done
    elif User.Opts.Dependencies.Check.IsSet; then
        QPKGs_initial_download_array+=($(QPKGs.Installed.Array))
    else
        QPKGs_initial_download_array+=(${QPKGs_to_install[*]} ${QPKGs_to_reinstall[*]} ${QPKGs_to_upgrade[*]} ${QPKGs_to_force_upgrade[*]})
    fi

    GetTheseQPKGDeps "${QPKGs_initial_download_array[*]}"

    ExcludeInstalledQPKGs "$QPKG_pre_download_list"

    if [[ $(Packages.Download.Count) -eq 1 && ${QPKGs_download_array[0]} = Entware ]] && QPKG.NotInstalled Entware; then
        ShowAsNote "It's not necessary to install $(FormatAsPackageName Entware) on its own. It will be installed as-required with your other $(FormatAsScriptTitle) packages. :)"
    fi

    DebugScript 'initial package download' "${QPKGs_download_array[*]} "

    return 0

    }

QPKGs.Independent.Build()
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

QPKGs.Dependant.Build()
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

QPKGs.Installable.Build()
    {

    # Returns a list of QPKGs that can be installed or reinstalled by the user.
    # creates a global variable array: $QPKGS_user_installable()

    QPKGS_user_installable=()
    local package=''

    for package in "${SHERPA_QPKG_NAME[@]}"; do
        QPKG.Installable "$package" && QPKGs.Installable.Add "$package"
    done

    return 0

    }

QPKGs.Installable.Add()
    {

    [[ ${QPKGS_user_installable[*]} != *"$1"* ]] && QPKGS_user_installable+=("$1")

    return 0

    }


QPKGs.ToInstall.Add()
    {

    [[ ${QPKGs_to_install[*]} != *"$1"* ]] && QPKGs_to_install+=("$1")

    return 0

    }

QPKGs.ToInstall.Remove()
    {

    [[ ${QPKGs_to_install[*]} == *"$1"* ]] && QPKGs_to_install=("${QPKGs_to_install[@]/$1}")

    return 0

    }

QPKGs.ToInstall.Count()
    {

    echo "${#QPKGs_to_install[@]}"

    }

QPKGs.ToInstall.Print()
    {

    echo "${QPKGs_to_install[*]}"

    }

QPKGs.ToInstall.IsAny()
    {

    [[ $(QPKGs.ToInstall.Count) -gt 0 ]]

    }

QPKGs.ToInstall.IsNone()
    {

    [[ $(QPKGs.ToInstall.Count) -eq 0 ]]

    }

QPKGs.Installed.Add()
    {

    [[ ${QPKGs_installed[*]} != *"$1"* ]] && QPKGs_installed+=("$1")

    return 0

    }

QPKGs.Installed.Array()
    {

    echo "${QPKGs_installed[@]}"

    }

QPKGs.Installed.Build()
    {

    # Returns a list of user-installed sherpa QPKGs
    # creates a global variable array: $QPKGs_installed()

    QPKGs_installed=()
    local package=''

    for package in "${SHERPA_QPKG_NAME[@]}"; do
        QPKG.Installed "$package" && QPKGs.Installed.Add "$package"
    done

    return 0

    }

QPKGs.Installed.Count()
    {

    echo "${#QPKGs_installed[@]}"

    }

QPKGs.Installed.IsAny()
    {

    [[ $(QPKGs.Installed.Count) -gt 0 ]]

    }

QPKGs.Installed.IsNone()
    {

    [[ $(QPKGs.Installed.Count) -eq 0 ]]

    }

QPKGs.Installed.Print()
    {

    echo "${QPKGs_installed[*]}"

    }

QPKGs.Installed.Show()
    {

    for package in $(QPKGs.Installed.Print); do
        echo "$package"
    done

    return 0

    }

QPKGs.NotInstalled.Print()
    {

    echo "${QPKGs_not_installed[*]}"

    }

QPKGs.ToUninstall.Add()
    {

    [[ ${QPKGs_to_uninstall[*]} != *"$1"* ]] && QPKGs_to_uninstall+=("$1")

    return 0

    }

QPKGs.ToUninstall.Print()
    {

    echo "${QPKGs_to_uninstall[*]}"

    }

QPKGs.ToUninstall.IsAny()
    {

    [[ ${#QPKGs_to_uninstall[@]} -gt 0 ]]

    }

QPKGs.ToUninstall.IsNone()
    {

    [[ ${#QPKGs_to_uninstall[@]} -eq 0 ]]

    }

QPKGs.ToReinstall.Add()
    {

    [[ ${QPKGs_to_reinstall[*]} != *"$1"* ]] && QPKGs_to_reinstall+=("$1")

    return 0

    }

QPKGs.ToReinstall.Remove()
    {

    [[ ${QPKGs_to_reinstall[*]} == *"$1"* ]] && QPKGs_to_reinstall=("${QPKGs_to_reinstall[@]/$1}")

    return 0

    }

QPKGs.ToReinstall.Count()
    {

    echo "${#QPKGs_to_reinstall[@]}"

    }

QPKGs.ToReinstall.Print()
    {

    echo "${QPKGs_to_reinstall[*]}"

    }

QPKGs.ToReinstall.IsAny()
    {

    [[ $(QPKGs.ToReinstall.Count) -gt 0 ]]

    }

QPKGs.ToReinstall.IsNone()
    {

    [[ $(QPKGs.ToReinstall.Count) -eq 0 ]]

    }

QPKGs.NotInstalled.Add()
    {

    [[ ${QPKGs_not_installed[*]} != *"$1"* ]] && QPKGs_not_installed+=("$1")

    return 0

    }

QPKGs.NotInstalled.IsAny()
    {

    [[ ${#QPKGs_not_installed[@]} -gt 0 ]]

    }

QPKGs.NotInstalled.IsNone()
    {

    [[ ${#QPKGs_not_installed[@]} -eq 0 ]]

    }

QPKGs.NotInstalled.Build()
    {

    # Returns a list of QPKGs that can be installed.
    # creates a global variable array: $QPKGs_not_installed()

    QPKGs_not_installed=()
    local package=''

    for package in "${QPKGS_user_installable[@]}"; do
        QPKG.NotInstalled "$package" && QPKGs.NotInstalled.Add "$package"
    done

    return 0

    }

QPKGs.NotInstalled.Array()
    {

    echo "${QPKGs_not_installed[@]}"

    }

QPKGs.ToUpgrade.Add()
    {

    [[ ${QPKGs_to_upgrade[*]} != *"$1"* ]] && QPKGs_to_upgrade+=("$1")

    return 0

    }

QPKGs.ToUpgrade.Remove()
    {

    [[ ${QPKGs_to_upgrade[*]} == *"$1"* ]] && QPKGs_to_upgrade=("${QPKGs_to_upgrade[@]/$1}")

    return 0

    }

QPKGs.ToUpgrade.Count()
    {

    echo "${#QPKGs_to_upgrade[@]}"

    }

QPKGs.ToUpgrade.IsAny()
    {

    [[ ${#QPKGs_to_upgrade[@]} -gt 0 ]]

    }

QPKGs.ToUpgrade.IsNone()
    {

    [[ ${#QPKGs_to_upgrade[@]} -eq 0 ]]

    }

QPKGs.ToForceUpgrade.Add()
    {

    [[ ${QPKGs_to_force_upgrade[*]} != *"$1"* ]] && QPKGs_to_force_upgrade+=("$1")

    return 0

    }

QPKGs.ToForceUpgrade.Count()
    {

    echo "${#QPKGs_to_force_upgrade[@]}"

    }

QPKGs.ToForceUpgrade.IsAny()
    {

    [[ ${#QPKGs_to_force_upgrade[@]} -gt 0 ]]

    }

QPKGs.ToForceUpgrade.IsNone()
    {

    [[ ${#QPKGs_to_force_upgrade[@]} -eq 0 ]]

    }

QPKGs.Upgradable.Build()
    {

    # Returns a list of QPKGs that can be upgraded.
    # creates a global variable array: $QPKGS_upgradable()

    QPKGS_upgradable=()
    local package=''
    local installed_version=''
    local remote_version=''

    for package in "${QPKGs_installed[@]}"; do
        [[ $package = Entware || $package = Par2 ]] && continue        # KLUDGE: ignore 'Entware' as package filename version doesn't match the QTS App Center version string
        installed_version=$(GetInstalledQPKGVersion "$package")
        remote_version=$(GetQPKGRemoteVersion "$package")

        if [[ $installed_version != "$remote_version" ]]; then
            #QPKGS_upgradable+=("$package $installed_version $remote_version")
            QPKGS_upgradable+=($package)
        fi
    done

    return 0

    }

QPKGs.Upgradable.Array()
    {

    echo "${QPKGS_upgradable[@]}"

    }

QPKGs.Upgradable.Print()
    {

    echo "${QPKGS_upgradable[*]}"

    }

QPKGs.Upgradable.IsAny()
    {

    [[ ${#QPKGS_upgradable[@]} -gt 0 ]]

    }

QPKGs.Upgradable.IsNone()
    {

    [[ ${#QPKGS_upgradable[@]} -eq 0 ]]

    }

QPKGs.ToRestart.Add()
    {

    [[ ${QPKGs_to_restart[*]} != *"$1"* ]] && QPKGs_to_restart+=("$1")

    return 0

    }

QPKGs.ToRestart.Remove()
    {

    [[ ${QPKGs_to_restart[*]} == *"$1"* ]] && QPKGs_to_restart=("${QPKGs_to_restart[@]/$1}")

    return 0

    }

QPKGs.ToRestart.IsAny()
    {

    [[ ${#QPKGs_to_restart[@]} -gt 0 ]]

    }

QPKGs.ToRestart.IsNone()
    {

    [[ ${#QPKGs_to_restart[@]} -eq 0 ]]

    }

QPKGs.ToBackup.Add()
    {

    [[ ${QPKGs_to_backup[*]} != *"$1"* ]] && QPKGs_to_backup+=("$1")

    return 0

    }

QPKGs.ToBackup.Count()
    {

    echo "${#QPKGs_to_backup[@]}"

    }

QPKGs.ToBackup.IsAny()
    {

    [[ ${#QPKGs_to_backup[@]} -gt 0 ]]

    }

QPKGs.ToBackup.IsNone()
    {

    [[ ${#QPKGs_to_backup[@]} -eq 0 ]]

    }

QPKGs.ToRestore.Add()
    {

    [[ ${QPKGs_to_restore[*]} != *"$1"* ]] && QPKGs_to_restore+=("$1")

    return 0

    }

QPKGs.ToRestore.Count()
    {

    echo "${#QPKGs_to_restore[@]}"

    }

QPKGs.ToRestore.IsAny()
    {

    [[ ${#QPKGs_to_restore[@]} -gt 0 ]]

    }

QPKGs.ToRestore.IsNone()
    {

    [[ ${#QPKGs_to_restore[@]} -eq 0 ]]

    }

QPKGs.ToStatus.Add()
    {

    [[ ${QPKGs_to_status[*]} != *"$1"* ]] && QPKGs_to_status+=("$1")

    return 0

    }

QPKGs.ToStatus.Count()
    {

    echo "${#QPKGs_to_status[@]}"

    }

QPKGs.ToStatus.Print()
    {

    echo "${QPKGs_to_status[*]}"

    }

QPKGs.ToStatus.IsAny()
    {

    [[ $(QPKGs.ToStatus.Count) -gt 0 ]]

    }

QPKGs.ToStatus.IsNone()
    {

    [[ $(QPKGs.ToStatus.Count) -eq 0 ]]

    }

Packages.Download.Add()
    {

    [[ ${QPKGs_download_array[*]} != *"$1"* ]] && QPKGs_download_array+=("$1")

    return 0

    }

Packages.Download.Count()
    {

    echo "${#QPKGs_download_array[@]}"

    }

Packages.Download.Print()
    {

    echo "${QPKGs_download_array[*]}"

    }

Packages.Download.IsAny()
    {

    [[ ${#QPKGs_download_array[@]} -gt 0 ]]

    }

Packages.Download.IsNone()
    {

    [[ ${#QPKGs_download_array[@]} -eq 0 ]]

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
            ShowAsDone "no QPKGs need upgrading"
        elif Session.Error.IsNot; then
            ShowAsDone "all upgradable QPKGs were successfully upgraded"
        else
            ShowAsError "upgrade failed! [$code_pointer]"
            Session.SuggestIssue.Set
        fi
    fi

    if User.Opts.Dependencies.Check.IsSet; then
        if Session.Error.IsNot; then
            ShowAsDone "all application dependencies are installed"
        else
            ShowAsError "application dependency check failed! [$code_pointer]"
            Session.SuggestIssue.Set
        fi
    fi

    return 0

    }

QPKG.Installable()
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

QPKG.ToBeInstalled()
    {

    # input:
    #   $1 = package name to check

    # output:
    #   $? = 0 (true) or 1 (false)

    [[ -z $1 ]] && return 1
    [[ $(QPKGs.ToInstall.Count) -gt 0 && ${QPKGs_to_install[*]} == *"$1"* ]] && return 0

    return 1

    }

QPKG.ToNotBeInstalled()
    {

    # input:
    #   $1 = package name to check

    # output:
    #   $? = 0 (true) or 1 (false)

    ! QPKG.ToBeInstalled "$1"

    }

QPKG.ToBeReinstalled()
    {

    # input:
    #   $1 = package name to check

    # output:
    #   $? = 0 (true) or 1 (false)

    [[ -z $1 ]] && return 1
    [[ $(QPKGs.ToReinstall.Count) -gt 0 && ${QPKGs_to_reinstall[*]} == *"$1"* ]] && return 0

    return 1

    }

QPKG.ToNotBeReinstalled()
    {

    # input:
    #   $1 = package name to check

    # output:
    #   $? = 0 (true) or 1 (false)

    ! QPKG.ToBeReinstalled "$1"

    }

QPKG.ToBeUpgraded()
    {

    # input:
    #   $1 = package name to check

    # output:
    #   $? = 0 (true) or 1 (false)

    [[ -z $1 ]] && return 1
    [[ $(QPKGs.ToUpgrade.Count) -gt 0 && ${QPKGs_to_upgrade[*]} == *"$1"* ]] && return 0

    return 1

    }

QPKG.ToNotBeUpgraded()
    {

    # input:
    #   $1 = package name to check

    # output:
    #   $? = 0 (true) or 1 (false)

    ! QPKG.ToBeUpgraded "$1"

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

QPKG.Upgradable()
    {

    # input:
    #   $1 = QPKG name to check if upgrade available

    # output:
    #   $? = 0 (true) or 1 (false)

    [[ -n $1 && ${#QPKGS_upgradable[@]} -gt 0 && ${QPKGS_upgradable[*]} == *"$1"* ]]

    }

QPKG.NotUpgradable()
    {

    ! QPKG.Upgradable "$1"

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

    # output:
    #   $? = result code of command string

    [[ -z $1 || -z $2 ]] && return 1

    local msgs=''
    local result=0

    FormatAsCommand "$1" > "$2"
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
    #   $? = result code of executed command

    [[ -z $1 || -z $2 ]] && return 1

    local buffer=/var/log/execd.log

    FormatAsCommand "$1" > "$2"
    eval "$1" 2>&1 | $TEE_CMD "$buffer"
    result=$?
    FormatAsResultAndStdout "$result" "$(<"$buffer")" >> "$2"
    [[ -e $buffer ]] && rm -f "$buffer"

    return $result

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
        temp="$1"
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
        previous_msg="$1"
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

DebugInfoThickSeparator()
    {

    DebugInfo "$(printf '%0.s=' {1..92})"

    }

DebugInfoThinSeparator()
    {

    DebugInfo "$(printf '%0.s-' {1..92})"

    }

DebugErrorThinSeparator()
    {

    DebugError "$(printf '%0.s-' {1..92})"

    }

DebugLogThinSeparator()
    {

    DebugLog "$(printf '%0.s-' {1..92})"

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

DebugIPKG()
    {

    DebugDetected.OK 'IPKG' "$1" "$2"

    }

DebugFuncEntry()
    {

    local var_name="${FUNCNAME[1]}_STARTSECONDS"
    local var_safe_name="${var_name//[.-]/_}"
    eval "$var_safe_name=$(date +%s%N)"

    DebugThis "(>>) ${FUNCNAME[1]}()"

    }

DebugFuncExit()
    {

    local var_name="${FUNCNAME[1]}_STARTSECONDS"
    local var_safe_name="${var_name//[.-]/_}"

    DebugThis "(<<) ${FUNCNAME[1]}() [$code_pointer]: $(printf "%'.f" $((($(date +%s%N) - ${!var_safe_name})/1000000))) ms"

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
        DebugWarning "$(printf "%9s: %25s\n" "$1" "$2")"
    elif [[ $3 = ' ' ]]; then           # if $3 is only a whitespace then print $2 with trailing colon but no third field
        DebugWarning "$(printf "%9s: %25s:\n" "$1" "$2")"
    elif [[ ${3: -1} = ' ' ]]; then     # if $3 has a trailing whitespace then print $3 without the trailing whitespace
        DebugWarning "$(printf "%9s: %25s: %-s\n" "$1" "$2" "$($SED_CMD 's| *$||' <<< "$3")")"
    else
        DebugWarning "$(printf "%9s: %25s: %-s\n" "$1" "$2" "$3")"
    fi

    }

DebugDetected.OK()
    {

    if [[ -z $3 ]]; then                # if $3 is nothing, then assume only 2 fields are required
        DebugDetected "$(printf "%9s: %25s\n" "$1" "$2")"
    elif [[ $3 = ' ' ]]; then           # if $3 is only a whitespace then print $2 with trailing colon but no third field
        DebugDetected "$(printf "%9s: %25s:\n" "$1" "$2")"
    elif [[ ${3: -1} = ' ' ]]; then     # if $3 has a trailing whitespace then print $3 without the trailing whitespace
        DebugDetected "$(printf "%9s: %25s: %-s\n" "$1" "$2" "$($SED_CMD 's| *$||' <<< "$3")")"
    else
        DebugDetected "$(printf "%9s: %25s: %-s\n" "$1" "$2" "$3")"
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

    WriteToDisplay.Wait "$(ColourTextBrightWhite info)" "$1"
    WriteToLog info "$1"

    }

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
    Session.Debug.To.File.IsNot && return

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

Objects.Add()
    {

    # $1: object name to create

    local public_function_name="$1"
    local safe_function_name="$(tr '[A-Z]' '[a-z]' <<< "${public_function_name//[.-]/_}")"

    _placehold_description_="_object_${safe_function_name}_description_"
    _placehold_value_="_object_${safe_function_name}_value_"
    _placehold_text_="_object_${safe_function_name}_text_"
    _placehold_flag_="_object_${safe_function_name}_flag_"
    _placehold_enable_="_object_${safe_function_name}_enable_"
    _placehold_list_array_="_object_${safe_function_name}_list_"
    _placehold_list_index_="_object_${safe_function_name}_list_index_"
    _placehold_path_="_object_${safe_function_name}_path_"

    echo $public_function_name'.Clear()
    {
    [[ $'$_placehold_flag_' != "true" ]] && return
    '$_placehold_flag_'=false
    DebugVar '$_placehold_flag_'
    }

'$public_function_name'.Description()
    {
    if [[ -n $1 && $1 = "=" ]]; then
        '$_placehold_description_'="$2"
    else
        echo -n "'$_placehold_description_'"
    fi
    }

'$public_function_name'.Disable()
    {
    [[ $'$_placehold_enable_' != "true" ]] && return
    '$_placehold_enable_'=false
    DebugVar '$_placehold_enable_'
    }

'$public_function_name'.Enable()
    {
    [[ $'$_placehold_enable_' = "true" ]] && return
    '$_placehold_enable_'=true
    DebugVar '$_placehold_enable_'
    }

'$public_function_name'.Env()
    {
    echo "* object internal environment *"
    echo "Name: '\'$public_function_name\''"
    echo "Description: '\'\$$_placehold_description_\''"
    echo "Value: '\'\$$_placehold_value_\''"
    echo "Text: '\'\$$_placehold_text_\''"
    echo "Flag: '\'\$$_placehold_flag_\''"
    echo "Enable: '\'\$$_placehold_enable_\''"
    echo "List: '\'\${$_placehold_list_array_[*]}\''"
    echo "List pointer: '\'\$$_placehold_list_index_\''"
    echo "Path: '\'\$$_placehold_path_\''"
    }

'$public_function_name'.Init()
    {
    '$_placehold_description_'=''
    '$_placehold_value_'=0
    '$_placehold_text_'=''
    '$_placehold_flag_'=false
    '$_placehold_enable_'=false
    '$_placehold_list_array_'+=()
    '$_placehold_list_index_'=1
    '$_placehold_path_'=''
    }

'$public_function_name'.IsDisabled()
    {
    [[ $'$_placehold_enable_' != "true" ]]
    }

'$public_function_name'.IsEnabled()
    {
    [[ $'$_placehold_enable_' = "true" ]]
    }

'$public_function_name'.IsNot()
    {
    [[ $'$_placehold_flag_' != "true" ]]
    }

'$public_function_name'.IsSet()
    {
    [[ $'$_placehold_flag_' = "true" ]]
    }

'$public_function_name'.Items.Add()
    {
    '$_placehold_list_array_'+=("$1")
    }

'$public_function_name'.Items.Count()
    {
    echo "${#'$_placehold_list_array_'[@]}"
    }

'$public_function_name'.Items.First()
    {
    echo "${'$_placehold_list_array_'[0]}"
    }

'$public_function_name'.Items.Enumerate()
    {
    (('$_placehold_list_index_'++))
    if [[ $'$_placehold_list_index_' -gt ${#'$_placehold_list_array_'[@]} ]]; then
        '$_placehold_list_index_'=1
    fi
    }

'$public_function_name'.Items.GetCurrent()
    {
    echo -n "${'$_placehold_list_array_'[(('$_placehold_list_index_'-1))]}"
    }

'$public_function_name'.Items.GetThis()
    {
    local -i index="$1"
    [[ $index -lt 1 ]] && index=1
    [[ $index -gt ${#'$_placehold_list_array_'[@]} ]] && index=${#'$_placehold_list_array_'[@]}
    echo -n "${'$_placehold_list_array_'[((index-1))]}"
    }

'$public_function_name'.Items.Index()
    {
    if [[ -n $1 && $1 = "=" ]]; then
        if [[ $2 -gt ${#'$_placehold_list_array_'[@]} ]]; then
            '$_placehold_list_index_'=${#'$_placehold_list_array_'[@]}
        else
            '$_placehold_list_index_'=$2
        fi
    else
        echo -n $'$_placehold_list_index_'
    fi
    }

'$public_function_name'.Path()
    {
    if [[ -n $1 && $1 = "=" ]]; then
        '$_placehold_path_'="$2"
    else
        echo -n "$'$_placehold_path_'"
    fi
    }

'$public_function_name'.Set()
    {
    [[ $'$_placehold_flag_' = "true" ]] && return
    '$_placehold_flag_'=true
    DebugVar '$_placehold_flag_'
    }

'$public_function_name'.Text()
    {
    if [[ -n $1 && $1 = "=" ]]; then
        '$_placehold_text_'="$2"
    else
        echo -n "$'$_placehold_text_'"
    fi
    }

'$public_function_name'.Value()
    {
    if [[ -n $1 && $1 = "=" ]]; then
        '$_placehold_value_'=$2
    else
        echo -n $'$_placehold_value_'
    fi
    }

'$public_function_name'.Value.Decrement()
    {
    local -i amount
    if [[ -n $1 && $1 = "by" ]]; then
        amount=$2
    else
        amount=1
    fi
    '$_placehold_value_'=$(('$_placehold_value_'-amount))
    }

'$public_function_name'.Value.Increment()
    {
    local -i amount
    if [[ -n $1 && $1 = "by" ]]; then
        amount=$2
    else
        amount=1
    fi
    '$_placehold_value_'=$(('$_placehold_value_'+amount))
    }

'$public_function_name'.Init
' >> $COMPILED_OBJECTS

    return 0

    }

Objects.Compile()
    {

    local reference_hash=43fb740d1dd2b4c72ad63333461efc7f

    [[ -e $COMPILED_OBJECTS ]] && ! FileMatchesMD5 "$COMPILED_OBJECTS" "$reference_hash" && rm -f "$COMPILED_OBJECTS"

    if [[ ! -e $COMPILED_OBJECTS ]]; then
        ShowAsProc "compiling objects"

        # user-selected options
        Objects.Add User.Opts.Help.Abbreviations
        Objects.Add User.Opts.Help.Actions
        Objects.Add User.Opts.Help.ActionsAll
        Objects.Add User.Opts.Help.Basic
        Objects.Add User.Opts.Help.Options
        Objects.Add User.Opts.Help.Packages
        Objects.Add User.Opts.Help.Problems
        Objects.Add User.Opts.Help.Tips

        Objects.Add User.Opts.Dependencies.Check
        Objects.Add User.Opts.IgnoreFreeSpace
        Objects.Add User.Opts.Versions.View

        Objects.Add User.Opts.Log.Paste
        Objects.Add User.Opts.Log.View

        Objects.Add User.Opts.Apps.All.Backup
        Objects.Add User.Opts.Apps.All.Install
        Objects.Add User.Opts.Apps.All.List
        Objects.Add User.Opts.Apps.All.Reinstall
        Objects.Add User.Opts.Apps.All.Restart
        Objects.Add User.Opts.Apps.All.Restore
        Objects.Add User.Opts.Apps.All.Status
        Objects.Add User.Opts.Apps.All.Uninstall
        Objects.Add User.Opts.Apps.All.Upgrade

        Objects.Add User.Opts.Apps.List.Installed
        Objects.Add User.Opts.Apps.List.NotInstalled
        Objects.Add User.Opts.Apps.List.Upgradable

        # script flags
        Objects.Add Session.Backup
        Objects.Add Session.Debug.To.File
        Objects.Add Session.Debug.To.Screen
        Objects.Add Session.Display.Clean
        Objects.Add Session.Ipkgs.Install
        Objects.Add Session.LineSpace
        Objects.Add Session.Pips.Install
        Objects.Add Session.ShowBackupLocation
        Objects.Add Session.SkipPackageProcessing
        Objects.Add Session.SuggestIssue
        Objects.Add Session.Summary
    fi

    . "$COMPILED_OBJECTS"

    return 0

    }

Session.Init || exit 1
Session.Validate
Packages.Download
Packages.Backup
Packages.Uninstall
Packages.Install.Independents
Packages.Install.Dependants
Packages.Restore
Packages.Restart
Session.Results
Session.Error.IsNot
