#!/usr/bin/env bash
#
# sherpa.manager.sh
#   Copyright (C) 2017-2022 OneCD [one.cd.only@gmail.com]
#
#   So, blame OneCD if it all goes horribly wrong. ;)
#
# Description:
#   This is the management script for the sherpa mini-package-manager.
#   It's automatically downloaded via the 'sherpa.loader.sh' script in the 'sherpa' QPKG no-more than once per 24 hours.
#
# Project:
#   https://git.io/sherpa
#
# Forum:
#   https://forum.qnap.com/viewtopic.php?f=320&t=132373
#
# Tested on:
#   GNU bash, version 3.2.57(2)-release (i686-pc-linux-gnu)
#   GNU bash, version 3.2.57(1)-release (aarch64-QNAP-linux-gnu)
#   Copyright (C) 2007 Free Software Foundation, Inc.
#
# ... and periodically on:
#   GNU bash, version 5.1.16(1)-release (aarch64-openwrt-linux-gnu)
#   Copyright (C) 2020 Free Software Foundation, Inc.
#
# License:
#   This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/
#
# Project variable and function naming style-guide:
#              functions: CamelCase
#   background functions: _CamelCaseWithLeadingAndTrailingUnderscores_
#              variables: lowercase_with_inline_underscores
#       "object" methods: Capitalised.CamelCase.With.Inline.Periods
#    "object" properties: _lowercase_with_leading_and_inline_and_trailing_underscores_ (these should ONLY be managed via the object's methods)
#              constants: UPPERCASE_WITH_INLINE_UNDERSCORES (also set as readonly)
#                indents: 1 x tab (converted to 4 x spaces to suit GitHub web-display)
#
# Notes:
#   If on-screen line-spacing is required, this should only be done by the next function that outputs to display.
#   Display functions should never finish by putting an empty line on-screen for spacing.

set -o nounset -o pipefail
readonly USER_ARGS_RAW=$*
readonly SCRIPT_STARTSECONDS=$(/bin/date +%s)

Self.Init()
    {

    DebugFuncEntry

    readonly PROJECT_NAME=sherpa
    local -r SCRIPT_VER=221216-beta
    readonly PROJECT_BRANCH=main

    IsQNAP || return
    IsSU || return
    ClaimLockFile /var/run/$PROJECT_NAME.lock || return

    export LC_ALL=''    # need to disable ALL to enable setting of individual vars
    export LANG=en_US.utf8
    export LC_CTYPE=C
    export LC_NUMERIC=en_US.utf8

    # cherry-pick required binaries
    readonly AWK_CMD=/bin/awk
    readonly CAT_CMD=/bin/cat
    readonly DATE_CMD=/bin/date
    readonly DF_CMD=/bin/df
    readonly GREP_CMD=/bin/grep
    readonly MD5SUM_CMD=/bin/md5sum
    readonly SED_CMD=/bin/sed
    readonly SH_CMD=/bin/sh
    readonly SLEEP_CMD=/bin/sleep
    readonly TOUCH_CMD=/bin/touch
    readonly UNAME_CMD=/bin/uname

    readonly CURL_CMD=/sbin/curl
    readonly GETCFG_CMD=/sbin/getcfg
    readonly SETCFG_CMD=/sbin/setcfg

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
    IsSysFileExist $DF_CMD || return
    IsSysFileExist $GREP_CMD || return
    IsSysFileExist $MD5SUM_CMD || return
    IsSysFileExist $SED_CMD || return
    IsSysFileExist $SH_CMD || return
    IsSysFileExist $SLEEP_CMD || return
    IsSysFileExist $TOUCH_CMD || return
    IsSysFileExist $UNAME_CMD || return

    IsSysFileExist $CURL_CMD || return
    IsSysFileExist $GETCFG_CMD || return
    IsSysFileExist $SETCFG_CMD || return

    [[ ! -e $SORT_CMD ]] && ln -s /bin/busybox "$SORT_CMD"  # KLUDGE: 'sort' randomly goes missing from QTS
    [[ ! -e /dev/fd ]] && ln -s /proc/self/fd /dev/fd       # KLUDGE: '/dev/fd' isn't always created by QTS during startup

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

    readonly OPKG_CMD=/opt/bin/opkg
    readonly GNU_FIND_CMD=/opt/bin/find
    readonly GNU_GREP_CMD=/opt/bin/grep
    readonly GNU_SED_CMD=/opt/bin/sed
    readonly GNU_STTY_CMD=/opt/bin/stty
    readonly PYTHON_CMD=/opt/bin/python
    readonly PYTHON3_CMD=/opt/bin/python3
    readonly PIP_CMD="$PYTHON3_CMD -m pip"
    readonly PERL_CMD=/opt/bin/perl

    readonly BACKUP_LOG_FILE=backup.log
    readonly CHECK_LOG_FILE=check.log
    readonly CLEAN_LOG_FILE=clean.log
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

    readonly PROJECT_PATH=$(QPKG.InstallationPath $PROJECT_NAME)
    readonly WORK_PATH=$PROJECT_PATH/cache
    readonly LOGS_PATH=$PROJECT_PATH/logs
    readonly QPKG_DL_PATH=$WORK_PATH/qpkgs.downloads
    readonly IPKG_DL_PATH=$WORK_PATH/ipkgs.downloads
    readonly IPKG_CACHE_PATH=$WORK_PATH/ipkgs
    readonly PIP_CACHE_PATH=$WORK_PATH/pips
    readonly BACKUP_PATH=$(GetDefaultVolume)/.qpkg_config_backup

    local -r MANAGER_FILE=$PROJECT_NAME.manager.sh
    local -r MANAGER_ARCHIVE_FILE=${MANAGER_FILE%.*}.tar.gz
    readonly MANAGER_ARCHIVE_PATHFILE=$WORK_PATH/$MANAGER_ARCHIVE_FILE
    readonly MANAGER_PATHFILE=$WORK_PATH/$MANAGER_FILE

    local -r OBJECTS_FILE=objects
    local -r OBJECTS_ARCHIVE_FILE=$OBJECTS_FILE.tar.gz
    readonly OBJECTS_ARCHIVE_URL=https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/$PROJECT_BRANCH/$OBJECTS_ARCHIVE_FILE
    readonly OBJECTS_ARCHIVE_PATHFILE=$WORK_PATH/$OBJECTS_ARCHIVE_FILE
    readonly OBJECTS_PATHFILE=$WORK_PATH/$OBJECTS_FILE

    local -r PACKAGES_FILE=packages
    local -r PACKAGES_ARCHIVE_FILE=$PACKAGES_FILE.tar.gz
    local -r PACKAGES_ARCHIVE_URL=https://raw.githubusercontent.com/OneCDOnly/$PROJECT_NAME/$PROJECT_BRANCH/$PACKAGES_ARCHIVE_FILE
    readonly PACKAGES_ARCHIVE_PATHFILE=$WORK_PATH/$PACKAGES_ARCHIVE_FILE
    readonly PACKAGES_PATHFILE=$WORK_PATH/$PACKAGES_FILE

    readonly EXTERNAL_PACKAGES_ARCHIVE_PATHFILE=/opt/var/opkg-lists/entware
    readonly EXTERNAL_PACKAGES_PATHFILE=$WORK_PATH/Packages

    readonly PREVIOUS_OPKG_PACKAGES_LIST=$WORK_PATH/opkg.prev.installed.list
    readonly PREVIOUS_PIP_MODULES_LIST=$WORK_PATH/pip.prev.installed.list

    readonly SESSION_ARCHIVE_PATHFILE=$LOGS_PATH/session.archive.log
    readonly SESSION_ACTIVE_PATHFILE=$PROJECT_PATH/session.$$.active.log
    readonly SESSION_LAST_PATHFILE=$LOGS_PATH/session.last.log
    readonly SESSION_TAIL_PATHFILE=$LOGS_PATH/session.tail.log

    MANAGEMENT_ACTIONS=(Check List Paste Status)

    PACKAGE_TIERS=(Standalone Addon Dependent)
    PACKAGE_SCOPES=(All Dependent HasDependents Installable Standalone SupportBackup SupportUpdateOnRestart Upgradable)
    PACKAGE_STATES=(BackedUp Cleaned Downloaded Enabled Installed Missing Started)
    PACKAGE_STATES_TEMPORARY=(Starting Stopping Restarting)
    PACKAGE_ACTIONS=(Download Rebuild Backup Stop Disable Uninstall Upgrade Reinstall Install Restore Clean Enable Start Restart)
    PACKAGE_RESULTS=(Ok Unknown)

    readonly MANAGEMENT_ACTIONS

    readonly PACKAGE_SCOPES
    readonly PACKAGE_STATES
    readonly PACKAGE_STATES_TEMPORARY
    readonly PACKAGE_RESULTS
    readonly PACKAGE_ACTIONS
    readonly PACKAGE_TIERS

    MakePath "$WORK_PATH" work || return
    MakePath "$LOGS_PATH" logs || return

    [[ -d $IPKG_DL_PATH ]] && rm -rf "$IPKG_DL_PATH"
    [[ -d $IPKG_CACHE_PATH ]] && rm -rf "$IPKG_CACHE_PATH"
    [[ -d $PIP_CACHE_PATH ]] && rm -rf "$PIP_CACHE_PATH"

    # KLUDGE: service scripts prior to 22/12/08 would use these paths (by-default) to build/cache Python packages. This has been fixed, but still need to free-up this space to prevent out-of-space issues.
    [[ -d /root/.cache ]] && rm -rf /root/.cache
    [[ -d /root/.local/share/virtualenv ]] && rm -rf /root/.local/share/virtualenv

    MakePath "$QPKG_DL_PATH" 'QPKG download' || return
    MakePath "$IPKG_DL_PATH" 'IPKG download' || return
    MakePath "$IPKG_CACHE_PATH" 'IPKG cache' || return
    MakePath "$PIP_CACHE_PATH" 'PIP cache' || return
    MakePath "$BACKUP_PATH" 'QPKG backup' || return

    ArchivePriorSessionLogs

    local re=\\breset\\b        # create BASH 3.2 compatible regex with word boundaries. https://stackoverflow.com/a/9793094

    if [[ $USER_ARGS_RAW =~ $re ]]; then
        ResetArchivedLogs
        ResetWorkPath
        ArchiveActiveSessionLog
        ResetActiveSessionLog
        exit 0
    fi

    Objects.Load || return
    Self.Debug.ToArchive.Set
    Self.Debug.ToFile.Set

    if [[ -e $GNU_STTY_CMD ]]; then
        local terminal_dimensions=$($GNU_STTY_CMD size)
        readonly SESSION_ROWS=${terminal_dimensions% *}
        readonly SESSION_COLUMNS=${terminal_dimensions#* }
    else
        readonly SESSION_ROWS=40
        readonly SESSION_COLUMNS=156
    fi

    for re in \\bdebug\\b \\bdbug\\b \\bverbose\\b; do
        if [[ $USER_ARGS_RAW =~ $re ]]; then
            Display >&2
            Self.Debug.ToScreen.Set
            break
        fi
    done

    readonly THIS_PACKAGE_VER=$(QPKG.Local.Version "$PROJECT_NAME")
    readonly MANAGER_SCRIPT_VER="$SCRIPT_VER$([[ $PROJECT_BRANCH = develop ]] && echo '(d)')"

    DebugInfoMajorSeparator
    DebugScript started "$($DATE_CMD -d @"$SCRIPT_STARTSECONDS" | tr -s ' ')"
    DebugScript version "package: ${THIS_PACKAGE_VER:-unknown}, manager: ${MANAGER_SCRIPT_VER:-unknown}, loader: ${LOADER_SCRIPT_VER:-unknown}, objects: ${OBJECTS_VER:-unknown}"
    DebugScript PID "$$"
    DebugInfoMinorSeparator
    DebugInfo 'Markers: (**) detected, (II) information, (WW) warning, (EE) error, (LL) log file, (--) processing,'
    DebugInfo '(==) done, (>>) f entry, (<<) f exit, (vv) variable name & value, ($1) positional argument value'
    DebugInfoMinorSeparator

    Self.Summary.Set

    readonly NAS_FIRMWARE_VER=$(GetFirmwareVersion)
    readonly NAS_FIRMWARE_BUILD=$(GetFirmwareBuild)
    readonly NAS_FIRMWARE_DATE=$(GetFirmwareDate)
    readonly NAS_RAM_KB=$(GetInstalledRAM)
    readonly NAS_ARCH=$(GetArch)
    readonly NAS_PLATFORM=$(GetPlatform)
    readonly NAS_QPKG_ARCH=$(GetQPKGArch)
    readonly ENTWARE_VER=$(GetEntwareType)
    readonly LOG_TAIL_LINES=5000    # note: a full download and install of everything generates a session log of around 1600 lines, but include a bunch of opkg updates and it can get much longer
    previous_msg=' '
    [[ ${NAS_FIRMWARE_VER//.} -lt 426 ]] && curl_insecure_arg=' --insecure' || curl_insecure_arg=''
    QPKG.IsInstalled Entware && [[ $ENTWARE_VER = none ]] && DebugAsWarn "$(FormatAsPackageName Entware) appears to be installed but is not visible"

    # speedup: don't build package lists if only showing basic help
    if [[ -z $USER_ARGS_RAW ]]; then
        Opts.Help.Basic.Set
        QPKGs.SkProc.Set
        DisableDebugToArchiveAndFile
    else
        Packages.Load || return
        ParseArguments
    fi

    SmartCR >&2

    if Self.Display.Clean.IsNt && Self.Debug.ToScreen.IsNt; then
        Display "$(FormatAsScriptTitle) $MANAGER_SCRIPT_VER • a mini-package-manager for QNAP NAS"
        DisplayLineSpaceIfNoneAlready
    fi

    if ! QPKGs.Conflicts.Check; then
        QPKGs.SkProc.Set
        DebugFuncExit 1; return
    fi

    QPKGs.Warnings.Check

    # KLUDGE: remove all max QTS versions from qpkg.conf (these are not removed automatically when installing updated QPKGs without max version set)
    # retain this kludge for 12 months to give everyone time to update their installed sherpa QPKGs. Remove after 2023-09-22
    if [[ $($GETCFG_CMD sherpa max_versions_cleared -d FALSE -f /etc/config/qpkg.conf) = 'FALSE' ]]; then
        $SED_CMD -i '/^FW_Ver_Max/d' /etc/config/qpkg.conf
        $SETCFG_CMD sherpa max_versions_cleared TRUE -f /etc/config/qpkg.conf
    fi

    DebugFuncExit

    }

Self.Validate()
    {

    # This function handles most of the high-level logic for package actions.
    # If a package isn't being processed by the correct action, odds-are it's due to a logic error in this function.

    ArgumentSuggestions
    QPKGs.SkProc.IsSet && return
    DebugFuncEntry

    local action=''
    local scope=''
    local state=''
    local prospect=''
    local package=''
    local something_to_do=false
    local -i max_width=70
    local -i trimmed_width=$((max_width - 3))
    local available_ver=''

    ShowAsProc environment >&2

    DebugInfoMinorSeparator
    DebugHardwareOK model "$(get_display_name)"
    DebugHardwareOK CPU "$(GetCPUInfo)"
    DebugHardwareOK architecture "$NAS_ARCH"
    DebugHardwareOK RAM "$(FormatAsThousands "$NAS_RAM_KB")kB"
    DebugFirmwareOK OS "Q$($GREP_CMD -q zfs /proc/filesystems && echo u)TS"

    if [[ ${NAS_FIRMWARE_VER//.} -ge 400 ]]; then
        DebugFirmwareOK version "$NAS_FIRMWARE_VER.$NAS_FIRMWARE_BUILD"
    else
        DebugFirmwareWarning version "$NAS_FIRMWARE_VER"
    fi

    if [[ $NAS_FIRMWARE_DATE -lt 20201015 || $NAS_FIRMWARE_DATE -gt 20201020 ]]; then   # QTS builds released over these 6 days don't allow unsigned QPKGs to run at-all
        DebugFirmwareOK 'build date' "$NAS_FIRMWARE_DATE"
    else
        DebugFirmwareWarning 'build date' "$NAS_FIRMWARE_DATE"
    fi

    DebugFirmwareOK kernel "$(GetKernel)"
    DebugFirmwareOK platform "$NAS_PLATFORM"
    DebugUserspaceOK 'OS uptime' "$(GetUptime)"
    DebugUserspaceOK 'system load' "$(GetSysLoadAverages)"
    DebugUserspaceOK '$USER' "$USER"

    if [[ $EUID -eq 0 ]]; then
        DebugUserspaceOK '$EUID' "$EUID"
    else
        DebugUserspaceWarning '$EUID' "$EUID"
    fi

    DebugUserspaceOK 'time in shell' "$(GetTimeInShell)"
    DebugUserspaceOK '$BASH_VERSION' "$BASH_VERSION"
    DebugUserspaceOK 'default volume' "$(GetDefaultVolume)"
    DebugUserspaceOK '/opt' "$($READLINK_CMD /opt || echo '<not present>')"

    local public_share=$($GETCFG_CMD SHARE_DEF defPublic -d Qpublic -f /etc/config/def_share.info)

    if [[ -L /share/$public_share ]]; then
        DebugUserspaceOK "'$public_share' share" "/share/$public_share"
    else
        DebugUserspaceWarning "'$public_share' share" '<not present>'
    fi

    local download_share=$($GETCFG_CMD SHARE_DEF defDownload -d Qdownload -f /etc/config/def_share.info)

    if [[ -L /share/$download_share ]]; then
        DebugUserspaceOK "'$download_share' share" "/share/$download_share"
    else
        DebugUserspaceWarning "'$download_share' share" '<not present>'
    fi

    if [[ ${#PATH} -le $max_width ]]; then
        DebugUserspaceOK '$PATH' "$PATH"
    else
        DebugUserspaceOK '$PATH' "${PATH:0:trimmed_width}..."
    fi

    LogBinaryPathAndVersion python "$(GetDefaultPythonVersion)" "$MIN_PYTHON_VER"
    LogBinaryPathAndVersion python3 "$(GetDefaultPython3Version)" "$MIN_PYTHON_VER"
    LogBinaryPathAndVersion perl "$(GetDefaultPerlVersion)" "$MIN_PERL_VER"
    DebugScript 'logs path' "$LOGS_PATH"
    DebugScript 'work path' "$WORK_PATH"

    if IsAllowUnsignedPackages; then
        DebugQPKG 'allow unsigned' yes
    else
        if [[ ${NAS_FIRMWARE_VER//.} -lt 435 ]]; then
            DebugQPKG 'allow unsigned' no
        else
            DebugQPKGWarning 'allow unsigned' no
        fi
    fi

    DebugQPKG architecture "$NAS_QPKG_ARCH"
    DebugQPKG 'Entware installer' "$ENTWARE_VER"

    RunAndLog "$DF_CMD -h | $GREP_CMD '^Filesystem\|^none\|^tmpfs'" /var/log/ramdisks.state

    QPKGs.States.Build

    ShowAsProc arguments >&2

    if Opts.Deps.Check.IsSet || Opts.Help.Status.IsSet; then
        something_to_do=true
    else
        for action in "${PACKAGE_ACTIONS[@]}"; do
            if QPKGs.AcTo${action}.IsAny; then
                something_to_do=true
                break
            fi

            for scope in "${PACKAGE_SCOPES[@]}"; do
                if QPKGs.Ac${action}.Sc${scope}.IsSet || QPKGs.Ac${action}.ScNt${scope}.IsSet; then
                    something_to_do=true
                    break 2
                fi
            done

            for state in "${PACKAGE_STATES[@]}"; do
                if QPKGs.Ac${action}.Is${state}.IsSet || QPKGs.Ac${action}.IsNt${state}.IsSet; then
                    something_to_do=true
                    break 2
                fi
            done
        done
    fi

    if [[ $something_to_do = false ]]; then
        ShowAsError "I've nothing to-do (the supplied arguments were incomplete or didn't make sense)"
        Opts.Help.Basic.Set
        QPKGs.SkProc.Set
        DebugFuncExit 1; return
    fi

    if Opts.Deps.Check.IsSet || QPKGs.AcToUpgrade.Exist Entware || QPKGs.AcToInstall.Exist Entware || QPKGs.AcToReinstall.Exist Entware; then
        IPKGs.Upgrade.Set
        IPKGs.Install.Set
        PIPs.Install.Set

        if QPKG.IsInstalled Entware && QPKG.IsStarted Entware; then
            if [[ -e $PYTHON3_CMD ]]; then
                available_ver=$($PYTHON3_CMD -V 2>/dev/null | $SED_CMD 's|^Python ||')
                if [[ ${available_ver//./} -lt $MIN_PYTHON_VER ]]; then
                    ShowAsInfo 'installed Python environment will be upgraded' >&2
                    IPKGs.AcToUninstall.Add 'python*'
                fi
            fi

            if [[ -e $PERL_CMD ]]; then
                available_ver=$($PERL_CMD -e 'print "$^V\n"' 2>/dev/null | $SED_CMD 's|v||')
                if [[ ${available_ver//./} -lt $MIN_PERL_VER ]]; then
                    ShowAsInfo 'installed Perl environment will be upgraded' >&2
                    IPKGs.AcToUninstall.Add 'perl*'
                fi
            fi
        fi
    fi

    QPKGs.IsSupportBackup.Build
    QPKGs.IsSupportUpdateOnRestart.Build
    ApplySensibleExceptions

    # meta-action pre-processing
    if QPKGs.AcToRebuild.IsAny; then
        if QPKGs.IsBackedUp.IsNone; then
            ShowAsWarn 'there are no package backups to rebuild from' >&2
        else
            for package in $(QPKGs.AcToRebuild.Array); do
                if ! QPKGs.IsBackedUp.Exist "$package"; then
                    MarkActionAsSkipped show "$package" rebuild 'does not have a backup to rebuild from'
                else
                    (QPKGs.IsNtInstalled.Exist "$package" || QPKGs.AcToUninstall.Exist "$package") && QPKGs.AcToInstall.Add "$package"
                    QPKGs.AcToRestore.Add "$package"
                    QPKGs.AcToRebuild.Remove "$package"
                fi
            done
        fi
    fi

    # ensure standalone packages are also installed when processing these specific actions
    for action in Upgrade Reinstall Install Start Restart; do
        for package in $(QPKGs.AcTo${action}.Array); do
            for prospect in $(QPKG.GetStandalones "$package"); do
                if QPKGs.IsNtInstalled.Exist "$prospect" || (QPKGs.IsInstalled.Exist "$prospect" && QPKGs.AcToUninstall.Exist "$prospect"); then
                    QPKGs.AcToInstall.Add "$prospect"
                fi
            done
        done
    done

    # install standalones for started packages only
    for package in $(QPKGs.IsInstalled.Array); do
        if QPKGs.IsStarted.Exist "$package" || QPKGs.AcToStart.Exist "$package"; then
            for prospect in $(QPKG.GetStandalones "$package"); do
                QPKGs.IsNtInstalled.Exist "$prospect" && QPKGs.AcToInstall.Add "$prospect"
            done
        fi
    done

    # if a standalone has been selected for 'reinstall' or 'restart', need to 'stop' its dependents first, and 'start' them again later
    for package in $(QPKGs.AcToReinstall.Array) $(QPKGs.AcToRestart.Array); do
        if QPKGs.ScStandalone.Exist "$package" && QPKGs.IsStarted.Exist "$package"; then
            for prospect in $(QPKG.GetDependents "$package"); do
                if QPKGs.IsStarted.Exist "$prospect"; then
                    QPKGs.AcToStop.Add "$prospect"
                    QPKGs.AcToStart.Add "$prospect"
                fi
            done
        fi
    done

    # if a standalone has been selected for 'stop' or 'uninstall', need to 'stop' its dependents first
    for package in $(QPKGs.AcToStop.Array) $(QPKGs.AcToUninstall.Array); do
        if QPKGs.ScStandalone.Exist "$package" && QPKGs.IsInstalled.Exist "$package"; then
            for prospect in $(QPKG.GetDependents "$package"); do
                if QPKGs.IsStarted.Exist "$prospect"; then
                    QPKGs.AcToStop.Add "$prospect"
                fi
            done
        fi
    done

    # if a standalone has been selected for 'uninstall' then 'install', need to 'stop' its dependents first, and 'start' them again later
    for package in $(QPKGs.AcToUninstall.Array); do
        if QPKGs.ScStandalone.Exist "$package" && QPKGs.IsInstalled.Exist "$package"; then
            if QPKGs.AcToInstall.Exist "$package"; then
                for prospect in $(QPKG.GetDependents "$package"); do
                    if QPKGs.IsStarted.Exist "$prospect"; then
                        QPKGs.AcToStop.Add "$prospect"
                        QPKGs.AcToStart.Add "$prospect"
                    fi
                done
            fi
        fi
    done

    if QPKGs.AcToReinstall.Exist Entware; then    # Entware is a special case: complete removal and fresh install (to clear all installed IPKGs)
        QPKGs.AcToReinstall.Remove Entware
        QPKGs.AcToUninstall.Add Entware
        QPKGs.AcToInstall.Add Entware
    fi

    # no-need to 'stop' packages that are about to be uninstalled
    if QPKGs.AcUninstall.ScAll.IsSet; then
        QPKGs.AcToStop.Init
    else
        QPKGs.AcToStop.Remove "$(QPKGs.AcToUninstall.Array)"
    fi

    # build a list of original storage paths for packages to be 'uninstalled', then 'installed' again later this session (a "complex reinstall")
    # this will ensure migrated packages end-up in the original location
    QPKGs_were_installed_name=()
    QPKGs_were_installed_path=()

    if QPKGs.AcToUninstall.IsAny; then
        for package in $(QPKGs.AcToUninstall.Array); do
            if QPKGs.AcToInstall.Exist "$package"; then
                QPKGs_were_installed_name+=("$package")
                QPKGs_were_installed_path+=("$($DIRNAME_CMD "$(QPKG.InstallationPath $package)")")
            fi
        done
    fi

    # build list containing packages that will require installation QPKGs
    QPKGs.AcToDownload.Add "$(QPKGs.AcToUpgrade.Array) $(QPKGs.AcToReinstall.Array) $(QPKGs.AcToInstall.Array)"

    # check all items
    if Opts.Deps.Check.IsSet; then
        QPKGs.NewVersions.Show

        for package in $(QPKGs.ScDependent.Array); do
            if ! QPKGs.ScUpgradable.Exist "$package" && QPKGs.IsStarted.Exist "$package" && QPKGs.ScSupportUpdateOnRestart.Exist "$package"; then
                QPKGs.AcToRestart.Add "$package"
            fi
        done
    fi

    DebugFuncExit

    }

# package processing priorities shall be:

#   _. rebuild dependents           (meta-action: 'install' QPKG and 'restore' config, but only if package has a backup file)

#  19. backup all                   (highest: most-important)
#  18. stop dependents
#  17. stop standalones
#  16. uninstall all

#  15. upgrade standalones
#  14. reinstall standalones
#  13. install standalones
#  12. restore standalones
#  11. clean standalones            (presently unsupported by any standalone QPKGs)
#  10. start standalones
#   9. restart standalones

#   8. upgrade dependents
#   7. reinstall dependents
#   6. install dependents
#   5. restore dependents
#   4. clean dependents
#   3. start dependents
#   2. restart dependents

#   1. status                       (lowest: least-important)

Tiers.Process()
    {

    QPKGs.SkProc.IsSet && return
    DebugFuncEntry

    local tier=''
    local action=''
    local prospect=''
    local package=''
    local -i index=0

    Tier.Process Download false All QPKG AcToDownload 'update package cache with' 'updating package cache with' 'package cache updated with' '' || return
    Tier.Process Backup false Dependent QPKG AcToBackup 'backup configuration for' 'backing-up configuration for' 'configuration backed-up for' '' || return
    Tier.Process Backup false Standalone QPKG AcToBackup 'backup configuration for' 'backing-up configuration for' 'configuration backed-up for' '' || return

    # -> package 'removal' phase begins here <-

    for ((index=${#PACKAGE_TIERS[@]}-1; index>=0; index--)); do     # process tiered removal actions in-reverse
        tier=${PACKAGE_TIERS[$index]}

        case $tier in
            Standalone|Dependent)
                Tier.Process Stop false "$tier" QPKG AcToStop stop stopping stopped '' true || return
                Tier.Process Uninstall false "$tier" QPKG AcToUninstall uninstall uninstalling uninstalled '' || return
        esac
    done

    # -> package 'installation' phase begins here <-

    # just in-case 'python' has disappeared again ... ¯\_(ツ)_/¯
    [[ ! -L $PYTHON_CMD && -e $PYTHON3_CMD ]] && ln -s $PYTHON3_CMD $PYTHON_CMD

    for tier in "${PACKAGE_TIERS[@]}"; do
        case $tier in
            Standalone|Dependent)
                Tier.Process Upgrade false "$tier" QPKG AcToUpgrade upgrade upgrading upgraded long || return
                Tier.Process Reinstall false "$tier" QPKG AcToReinstall reinstall reinstalling reinstalled long || return
                Tier.Process Install false "$tier" QPKG AcToInstall install installing installed long || return
                Tier.Process Restore false "$tier" QPKG AcToRestore 'restore configuration for' 'restoring configuration for' 'configuration restored for' long || return
                Tier.Process Clean false "$tier" QPKG AcToClean clean cleaning cleaned long || return

                if [[ $tier = Standalone ]]; then
                    # check for standalone packages that must be started because dependents are being reinstalled/installed/started/restarted
                    for package in $(QPKGs.AcToReinstall.Array) $(QPKGs.AcOkReinstall.Array) $(QPKGs.AcToInstall.Array) $(QPKGs.AcOkInstall.Array) $(QPKGs.AcToStart.Array) $(QPKGs.AcOkStart.Array) $(QPKGs.AcToRestart.Array) $(QPKGs.AcOkRestart.Array); do
                        for prospect in $(QPKG.GetStandalones "$package"); do
                            QPKGs.IsNtStarted.Exist "$prospect" && QPKGs.AcToStart.Add "$prospect"
                        done
                    done
                fi

                Tier.Process Start false "$tier" QPKG AcToStart start starting started long || return

                for action in Install Restart Start; do
                    QPKGs.AcToRestart.Remove "$(QPKGs.AcOk${action}.Array)"
                done

                Tier.Process Restart false "$tier" QPKG AcToRestart restart restarting restarted long || return

                ;;
            Addon)
                for action in Install Reinstall Upgrade Start; do
                    if QPKGs.IsStarted.Exist Entware; then
                        IPKGs.Upgrade.Set
                    fi

                    if QPKGs.AcTo${action}.IsAny; then
                        IPKGs.Install.Set
                    fi
                done

                if QPKGs.IsStarted.Exist Entware; then
                    ModPathToEntware
                    Tier.Process Upgrade false "$tier" IPKG '' upgrade upgrading upgraded long || return
                    Tier.Process Install false "$tier" IPKG '' install installing installed long || return

                    PIPs.Install.Set
                    Tier.Process Install false "$tier" PIP '' install installing installed long || return
                fi
        esac
    done

    QPKGs.Actions.List
    QPKGs.States.List
    SmartCR >&2

    DebugFuncExit

    }

Tier.Process()
    {

    # run a single action on a group of packages

    # input:
    #   $1 = $TARGET_ACTION                     e.g. 'Start', 'Restart'...
    #   $2 = is this a forced action?           e.g. 'true', 'false'
    #   $3 = $TIER                              e.g. 'Standalone', 'Dependent', 'Addon', 'All'
    #   $4 = $PACKAGE_TYPE                      e.g. 'QPKG', 'IPKG', 'PIP'
    #   $5 = $TARGET_OBJECT_NAME (optional)     e.g. 'AcToStart', 'AcToStop'...
    #   $6 = $ACTION_INTRANSITIVE               e.g. 'start'...
    #   $7 = $ACTION_PRESENT                    e.g. 'starting'...
    #   $8 = $ACTION_PAST                       e.g. 'started'...
    #   $9 = $RUNTIME (optional)                e.g. 'long'
    #  $10 = execute asynchronously? (optional) e.g. 'true', 'false'

    QPKGs.SkProc.IsSet && return
    DebugFuncEntry

    local package=''
    local forced_action=''
    local message_prefix=''
    local target_function=''
    local targets_function=''
    local -i result_code=0
    local -a target_packages=()
    local -i pass_count=0
    local -i fail_count=0
    local -i total_count=0
    local -r TARGET_ACTION=${1:?empty}
    local -r TIER=${3:?empty}
    local -r PACKAGE_TYPE=${4:?empty}
    local -r TARGET_OBJECT_NAME=${5:-}
    local -r RUNTIME=${9:-}
    local -r ASYNC=${10:-1}

    if [[ $2 = true ]]; then
        forced_action='--forced'
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

    ShowAsProc "$([[ $TIER != All ]] && tr 'A-Z' 'a-z' <<< "$TIER ")packages to $ACTION_INTRANSITIVE" >&2

    case $PACKAGE_TYPE in
        QPKG)
            if [[ $TIER = All ]]; then  # process all tiers
                target_packages=($($targets_function.$TARGET_OBJECT_NAME.Array))
            else                        # only process packages in specified tier, ignoring all others
                for package in $($targets_function.$TARGET_OBJECT_NAME.Array); do
                    $targets_function.Sc${TIER}.Exist "$package" && target_packages+=("$package")
                done
            fi

            total_count=${#target_packages[@]}

            if [[ $total_count -eq 0 ]]; then
                DebugInfo 'nothing to process'
                DebugFuncExit; return
            fi

            if [[ $ASYNC = false ]]; then
                # execute actions consecutively
                for package in "${target_packages[@]}"; do
                    ShowAsActionProgress "$TIER" "$PACKAGE_TYPE" "$pass_count" "$fail_count" "$total_count" "$ACTION_PRESENT" "$RUNTIME"

                    $target_function.${TARGET_ACTION} "$package" "$forced_action"
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
            else
                # execute actions concurrently
                # NON-FUNCTIONAL: for now, use same code as above
                for package in "${target_packages[@]}"; do
                    ShowAsActionProgress "$TIER" "$PACKAGE_TYPE" "$pass_count" "$fail_count" "$total_count" "$ACTION_PRESENT" "$RUNTIME"

                    $target_function.${TARGET_ACTION} "$package" "$forced_action"
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
            fi
            ;;
        IPKG|PIP)
            $targets_function.${TARGET_ACTION}
    esac

    # execute with pass_count > total_count to trigger 100% message
    ShowAsActionProgress "$TIER" "$PACKAGE_TYPE" "$((total_count + 1))" "$fail_count" "$total_count" "$ACTION_PRESENT" "$RUNTIME"
    ShowAsActionResult "$TIER" "$PACKAGE_TYPE" "$pass_count" "$fail_count" "$total_count" "$ACTION_PAST" "$RUNTIME"

    DebugFuncExit
    Self.Error.IsNt

    }

Self.Results()
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
        elif Opts.Log.Last.View.IsSet; then
            Log.Last.View
        elif Opts.Log.Tail.View.IsSet; then
            Log.Tail.View
        elif Opts.Log.Last.Paste.IsSet; then
            Log.Last.Paste
        elif Opts.Log.Tail.Paste.IsSet; then
            Log.Tail.Paste
        elif QPKGs.List.IsInstalled.IsSet; then
            QPKGs.IsInstalled.Show
        elif QPKGs.List.ScInstallable.IsSet; then
            QPKGs.ScInstallable.Show
        elif QPKGs.List.IsNtInstalled.IsSet; then
            QPKGs.IsNtInstalled.Show
        elif QPKGs.List.IsStarted.IsSet; then
            QPKGs.IsStarted.Show
        elif QPKGs.List.IsNtStarted.IsSet; then
            QPKGs.IsNtStarted.Show
        elif QPKGs.List.ScUpgradable.IsSet; then
            QPKGs.ScUpgradable.Show
        elif QPKGs.List.ScStandalone.IsSet; then
            QPKGs.ScStandalone.Show
        elif QPKGs.List.ScDependent.IsSet; then
            QPKGs.ScDependent.Show
        elif Opts.Help.Backups.IsSet; then
            QPKGs.Backups.Show
        elif Opts.Help.Repos.IsSet; then
            QPKGs.Repos.Show
        elif Opts.Help.Status.IsSet; then
            Self.Display.Clean.IsNt && QPKGs.NewVersions.Show
            QPKGs.Statuses.Show
        fi
    fi

    if Opts.Help.Basic.IsSet; then
        Help.Basic.Show
        Help.Basic.Example.Show
    fi

    Self.ShowBackupLoc.IsSet && Help.BackupLocation.Show
    Self.Summary.IsSet && ShowSummary
    Self.SuggestIssue.IsSet && Help.Issue.Show

    DebugInfoMinorSeparator
    DebugScript finished "$($DATE_CMD)"
    DebugScript 'elapsed time' "$(FormatSecsToHoursMinutesSecs "$(($($DATE_CMD +%s)-$([[ -n $SCRIPT_STARTSECONDS ]] && echo "$SCRIPT_STARTSECONDS" || echo "1")))")"
    DebugInfoMajorSeparator
    Self.Debug.ToArchive.IsSet && ArchiveActiveSessionLog
    ResetActiveSessionLog
    ReleaseLockFile
    DisplayLineSpaceIfNoneAlready   # final on-screen linespace

    return 0

    }

ParseArguments()
    {

    # basic argument syntax:
    #   scriptname [action] [scope] [options]

    DebugFuncEntry

    DebugVar USER_ARGS_RAW

    local user_args_fixed=$(tr 'A-Z' 'a-z' <<< "${USER_ARGS_RAW//,/ }")
    local -a user_args=(${user_args_fixed/--/})
    local arg=''
    local arg_identified=false
    local action=''
    local action_force=false
    local scope=''
    local scope_identified=false
    local package=''
    local prospect=''

    for arg in "${user_args[@]}"; do
        arg_identified=false

        # identify action: every time action changes, must clear scope too
        case $arg in
            backup|check|clean|install|rebuild|reinstall|restart|restore|start|stop|upgrade)
                action=${arg}_
                arg_identified=true
                scope=''
                scope_identified=false
                Self.Display.Clean.UnSet
                QPKGs.SkProc.UnSet
                ;;
            rm|remove|uninstall)
                action=uninstall_
                arg_identified=true
                scope=''
                scope_identified=false
                Self.Display.Clean.UnSet
                QPKGs.SkProc.UnSet
                ;;
            s|status|statuses)
                action=status_
                arg_identified=true
                scope=''
                scope_identified=false
                Self.Display.Clean.UnSet
                QPKGs.SkProc.Set
                ;;
            paste)
                action=paste_
                arg_identified=true
                scope=''
                scope_identified=false
                Self.Display.Clean.UnSet
                QPKGs.SkProc.Set
                ;;
            display|help|list|show|view)
                action=help_
                arg_identified=true
                scope=''
                scope_identified=false
                Self.Display.Clean.UnSet
                QPKGs.SkProc.Set
        esac

        # identify scope in two stages: first stage for when user didn't supply an action. Second is after an action has been defined.

        # stage 1
        if [[ -z $action ]]; then
            case $arg in
                a|abs|action|actions|actions-all|all-actions|b|backups|dependent|dependents|installable|installed|l|last|log|not-installed|option|options|p|package|packages|problems|r|repo|repos|standalone|standalones|started|stopped|tail|tips|upgradable|v|version|versions|whole)
                    action=help_
                    arg_identified=true
                    scope=''
                    scope_identified=false
                    QPKGs.SkProc.Set
            esac

            DebugVar action
        fi

        # stage 2
        if [[ -n $action ]]; then
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
                installable|installed|not-installed|started|stopped|upgradable)
                    scope=${arg}_
                    scope_identified=true
                    arg_identified=true
                    ;;
                problems|tail|tips)
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
                r|repo|repos)
                    scope=repos_
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
                Self.Debug.ToScreen.Set
                arg_identified=true
                scope_identified=true
                ;;
            force)
                action_force=true
                arg_identified=true
                ;;
        esac

        # identify package
        package=$(QPKG.MatchAbbrv "$arg")

        if [[ -n $package ]]; then
            scope_identified=true
            arg_identified=true
        fi

        [[ $arg_identified = false ]] && Args.Unknown.Add "$arg"

        case $action in
            backup_)
                case $scope in
                    all_)
                        QPKGs.AcBackup.ScAll.Set
                        action=''
                        ;;
                    installed_)
                        QPKGs.AcBackup.IsInstalled.Set
                        action=''
                        ;;
                    dependent_)
                        QPKGs.AcBackup.ScDependent.Set
                        ;;
                    standalone_)
                        QPKGs.AcBackup.ScStandalone.Set
                        ;;
                    started_)
                        QPKGs.AcToBackup.Add "$(QPKGs.IsStarted.Array)"
                        ;;
                    stopped_)
                        QPKGs.AcToBackup.Add "$(QPKGs.IsNtStarted.Array)"
                        ;;
                    *)
                        QPKGs.AcToBackup.Add "$package"
                esac
                ;;
            check_)
                Opts.Deps.Check.Set
                ;;
            clean_)
                case $scope in
                    all_)
                        QPKGs.AcClean.ScAll.Set
                        action=''
                        ;;
                    installed_)
                        QPKGs.AcClean.IsInstalled.Set
                        action=''
                        ;;
                    dependent_)
                        QPKGs.AcClean.ScDependent.Set
                        ;;
                    standalone_)
                        QPKGs.AcClean.ScStandalone.Set
                        ;;
                    started_)
                        QPKGs.AcToClean.Add "$(QPKGs.IsStarted.Array)"
                        ;;
                    stopped_)
                        QPKGs.AcToClean.Add "$(QPKGs.IsNtStarted.Array)"
                        ;;
                    *)
                        QPKGs.AcToClean.Add "$package"
                esac
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
                        QPKGs.List.ScInstallable.Set
                        Self.Display.Clean.Set
                        ;;
                    installed_)
                        QPKGs.List.IsInstalled.Set
                        Self.Display.Clean.Set
                        ;;
                    last_)
                        Opts.Log.Last.View.Set
                        Self.Display.Clean.Set
                        ;;
                    log_)
                        Opts.Log.Tail.View.Set
                        Self.Display.Clean.Set
                        ;;
                    not-installed_)
                        QPKGs.List.IsNtInstalled.Set
                        Self.Display.Clean.Set
                        ;;
                    dependent_)
                        QPKGs.List.ScDependent.Set
                        Self.Display.Clean.Set
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
                    repos_)
                        Opts.Help.Repos.Set
                        ;;
                    standalone_)
                        QPKGs.List.ScStandalone.Set
                        Self.Display.Clean.Set
                        ;;
                    started_)
                        QPKGs.List.IsStarted.Set
                        Self.Display.Clean.Set
                        ;;
                    status_)
                        Opts.Help.Status.Set
                        ;;
                    stopped_)
                        QPKGs.List.IsNtStarted.Set
                        Self.Display.Clean.Set
                        ;;
                    tips_)
                        Opts.Help.Tips.Set
                        ;;
                    upgradable_)
                        QPKGs.List.ScUpgradable.Set
                        Self.Display.Clean.Set
                        ;;
                    versions_)
                        Opts.Versions.View.Set
                        Self.Display.Clean.Set
                esac

                QPKGs.SkProc.Set
                ;;
            install_)
                case $scope in
                    all_)
                        QPKGs.AcInstall.ScAll.Set
                        action=''
                        ;;
                    dependent_)
                        QPKGs.AcInstall.ScDependent.Set
                        action=''
                        ;;
                    installable_)
                        QPKGs.AcInstall.ScInstallable.Set
                        action=''
                        ;;
                    not-installed_)
                        QPKGs.AcInstall.IsNtInstalled.Set
                        action=''
                        ;;
                    standalone_)
                        QPKGs.AcInstall.ScStandalone.Set
                        action=''
                        ;;
                    *)
                        QPKGs.AcToInstall.Add "$package"
                esac
                ;;
            paste_)
                case $scope in
                    all_|log_|tail_)
                        Opts.Log.Tail.Paste.Set
                        ;;
                    last_)
                        Opts.Log.Last.Paste.Set
                esac

                QPKGs.SkProc.Set

                if [[ $scope_identified = true ]]; then
                    DebugFuncExit; return
                fi
                ;;
            rebuild_)
                case $scope in
                    all_|installed_)
                        QPKGs.AcRebuild.ScAll.Set
                        action=''
                        ;;
                    dependent_)
                        QPKGs.AcRebuild.ScDependent.Set
                        action=''
                        ;;
                    standalone_)
                        QPKGs.AcRebuild.ScStandalone.Set
                        action=''
                        ;;
                    *)
                        QPKGs.AcToRebuild.Add "$package"
                esac
                ;;
            reinstall_)
                case $scope in
                    all_|installed_)
                        QPKGs.AcReinstall.ScAll.Set
                        action=''
                        ;;
                    dependent_)
                        QPKGs.AcReinstall.ScDependent.Set
                        action=''
                        ;;
                    standalone_)
                        QPKGs.AcReinstall.ScStandalone.Set
                        action=''
                        ;;
                    *)
                        QPKGs.AcToReinstall.Add "$package"
                esac
                ;;
            restart_)
                case $scope in
                    all_|installed_)
                        QPKGs.AcRestart.ScAll.Set
                        action=''
                        ;;
                    dependent_)
                        QPKGs.AcRestart.ScDependent.Set
                        action=''
                        ;;
                    standalone_)
                        QPKGs.AcRestart.ScStandalone.Set
                        action=''
                        ;;
                    *)
                        QPKGs.AcToRestart.Add "$package"
                esac
                ;;
            restore_)
                case $scope in
                    all_|installed_)
                        QPKGs.AcRestore.ScAll.Set
                        action=''
                        ;;
                    dependent_)
                        QPKGs.AcRestore.ScDependent.Set
                        action=''
                        ;;
                    standalone_)
                        QPKGs.AcRestore.ScStandalone.Set
                        action=''
                        ;;
                    *)
                        QPKGs.AcToRestore.Add "$package"
                esac
                ;;
            start_)
                case $scope in
                    all_|installed_)
                        QPKGs.AcStart.ScAll.Set
                        action=''
                        ;;
                    dependent_)
                        QPKGs.AcStart.ScDependent.Set
                        action=''
                        ;;
                    standalone_)
                        QPKGs.AcStart.ScStandalone.Set
                        action=''
                        ;;
                    stopped_)
                        QPKGs.AcStart.IsNtStarted.Set
                        action=''
                        ;;
                    *)
                        QPKGs.AcToStart.Add "$package"
                esac
                ;;
            status_)
                Opts.Help.Status.Set
                QPKGs.SkProc.Set
                ;;
            stop_)
                case $scope in
                    all_|installed_)
                        QPKGs.AcStop.ScAll.Set
                        action=''
                        ;;
                    dependent_)
                        QPKGs.AcStop.ScDependent.Set
                        action=''
                        ;;
                    standalone_)
                        QPKGs.AcStop.ScStandalone.Set
                        action=''
                        ;;
                    started_)
                        QPKGs.AcStop.IsStarted.Set
                        action=''
                        ;;
                    *)
                        QPKGs.AcToStop.Add "$package"
                esac
                ;;
            uninstall_)
                case $scope in
                    all_|installed_)   # this scope is dangerous, so make 'force' a requirement
                        if [[ $action_force = true ]]; then
                            QPKGs.AcUninstall.ScAll.Set
                            action=''
                            action_force=false
                        fi
                        ;;
                    dependent_)
                        QPKGs.AcUninstall.ScDependent.Set
                        action=''
                        action_force=false
                        ;;
                    standalone_)
                        QPKGs.AcUninstall.ScStandalone.Set
                        action=''
                        action_force=false
                        ;;
                    started_)
                        QPKGs.AcUninstall.IsStarted.Set
                        action=''
                        action_force=false
                        ;;
                    stopped_)
                        QPKGs.AcUninstall.IsNtStarted.Set
                        action=''
                        action_force=false
                        ;;
                    *)
                        QPKGs.AcToUninstall.Add "$package"
                esac
                ;;
            upgrade_)
                case $scope in
                    all_)
                        QPKGs.AcUpgrade.ScAll.Set
                        action=''
                        ;;
                    dependent_)
                        QPKGs.AcUpgrade.ScDependent.Set
                        action=''
                        ;;
                    standalone_)
                        QPKGs.AcUpgrade.ScStandalone.Set
                        action=''
                        ;;
                    started_)
                        QPKGs.AcUpgrade.IsStarted.Set
                        action=''
                        ;;
                    stopped_)
                        QPKGs.AcUpgrade.IsNtStarted.Set
                        action=''
                        ;;
                    upgradable_)
                        QPKGs.AcUpgrade.ScUpgradable.Set
                        action=''
                        ;;
                    *)
                        QPKGs.AcToUpgrade.Add "$package"
                esac
        esac
    done

    if [[ -n $action && $scope_identified = false ]]; then
        case $action in
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
            repos_)
                Opts.Help.Repos.Set
                ;;
            tips_)
                Opts.Help.Tips.Set
                ;;
            versions_)
                Opts.Versions.View.Set
                Self.Display.Clean.Set
        esac
    fi

    if Args.Unknown.IsAny; then
        Opts.Help.Basic.Set
        QPKGs.SkProc.Set
        Self.Display.Clean.UnSet
    fi

    DebugFuncExit

    }

ArgumentSuggestions()
    {

    DebugFuncEntry

    local arg=''

    if Args.Unknown.IsAny; then
        ShowAsError "unknown argument$(Plural "$(Args.Unknown.Count)"): \"$(Args.Unknown.List)\". Please check the argument list again"

        for arg in $(Args.Unknown.Array); do
            case $arg in
                all)
                    Display
                    DisplayAsProjectSyntaxExample "please provide a valid $(FormatAsHelpAction) before 'all' like" 'start all'
                    Opts.Help.Basic.UnSet
                    ;;
                all-backup|backup-all)
                    Display
                    DisplayAsProjectSyntaxExample 'to backup all installed package configurations, use' 'backup all'
                    Opts.Help.Basic.UnSet
                    ;;
                dependent)
                    Display
                    DisplayAsProjectSyntaxExample "please provide a valid $(FormatAsHelpAction) before 'dependent' like" 'start dependents'
                    Opts.Help.Basic.UnSet
                    ;;
                all-restart|restart-all)
                    Display
                    DisplayAsProjectSyntaxExample 'to restart all packages, use' 'restart all'
                    Opts.Help.Basic.UnSet
                    ;;
                all-restore|restore-all)
                    Display
                    DisplayAsProjectSyntaxExample 'to restore all installed package configurations, use' 'restore all'
                    Opts.Help.Basic.UnSet
                    ;;
                standalone)
                    Display
                    DisplayAsProjectSyntaxExample "please provide a valid $(FormatAsHelpAction) before 'standalone' like" 'start standalones'
                    Opts.Help.Basic.UnSet
                    ;;
                all-start|start-all)
                    Display
                    DisplayAsProjectSyntaxExample 'to start all packages, use' 'start all'
                    Opts.Help.Basic.UnSet
                    ;;
                all-stop|stop-all)
                    Display
                    DisplayAsProjectSyntaxExample 'to stop all packages, use' 'stop all'
                    Opts.Help.Basic.UnSet
                    ;;
                all-uninstall|all-remove|uninstall-all|remove-all)
                    Display
                    DisplayAsProjectSyntaxExample 'to uninstall all packages, use' 'force uninstall all'
                    Opts.Help.Basic.UnSet
                    ;;
                all-upgrade|upgrade-all)
                    Display
                    DisplayAsProjectSyntaxExample 'to upgrade all packages, use' 'upgrade all'
                    Opts.Help.Basic.UnSet
            esac
        done
    fi

    DebugFuncExit

    }

ApplySensibleExceptions()
    {

    DebugFuncEntry

    local action=''
    local scope=''
    local state=''
    local prospect=''
    local found=false

    for action in "${PACKAGE_ACTIONS[@]}"; do
        # process scope-based user-options
        for scope in "${PACKAGE_SCOPES[@]}"; do
            if QPKGs.Ac${action}.Sc${scope}.IsSet; then
                # use sensible scope exceptions (for convenience) rather than follow requested scope literally
                case $action in
                    Clean)
                        case $scope in
                            All)
                                found=true
                                for prospect in $(QPKGs.IsInstalled.Array); do
                                    QPKGs.ScSupportUpdateOnRestart.Exist "$prospect" && QPKGs.AcTo${action}.Add "$prospect"
                                done
                                ;;
                            Dependent)
                                found=true
                                for prospect in $(QPKGs.IsInstalled.Array); do
                                    QPKGs.ScDependent.Exist "$prospect" && QPKGs.AcTo${action}.Add "$prospect"
                                done
                                ;;
                            Standalone)
                                found=true
                                for prospect in $(QPKGs.IsInstalled.Array); do
                                    QPKGs.ScStandalone.Exist "$prospect" && QPKGs.AcTo${action}.Add "$prospect"
                                done
                        esac
                        ;;
                    Install)
                        case $scope in
                            All)
                                found=true
                                QPKGs.AcTo${action}.Add "$(QPKGs.IsNtInstalled.Array)"
                                ;;
                            Dependent)
                                found=true
                                for prospect in $(QPKGs.IsNtInstalled.Array); do
                                    QPKGs.ScDependent.Exist "$prospect" && QPKGs.AcTo${action}.Add "$prospect"
                                done
                                ;;
                            Standalone)
                                found=true
                                for prospect in $(QPKGs.IsNtInstalled.Array); do
                                    QPKGs.ScStandalone.Exist "$prospect" && QPKGs.AcTo${action}.Add "$prospect"
                                done
                        esac
                        ;;
                    Rebuild)
                        case $scope in
                            All)
                                found=true
                                QPKGs.AcTo${action}.Add "$(QPKGs.ScSupportBackup.Array)"
                                ;;
                            Dependent)
                                found=true
                                for prospect in $(QPKGs.ScSupportBackup.Array); do
                                    QPKGs.ScDependent.Exist "$prospect" && QPKGs.AcTo${action}.Add "$prospect"
                                done
                                ;;
                            Standalone)
                                found=true
                                for prospect in $(QPKGs.ScSupportBackup.Array); do
                                    QPKGs.ScStandalone.Exist "$prospect" && QPKGs.AcTo${action}.Add "$prospect"
                                done
                        esac
                        ;;
                    Restart)
                        case $scope in
                            All)
                                found=true
                                QPKGs.AcTo${action}.Add "$(QPKGs.IsStarted.Array)"
                                ;;
                            Dependent)
                                found=true
                                for prospect in $(QPKGs.IsStarted.Array); do
                                    QPKGs.ScDependent.Exist "$prospect" && QPKGs.AcTo${action}.Add "$prospect"
                                done
                                ;;
                            Standalone)
                                found=true
                                for prospect in $(QPKGs.IsStarted.Array); do
                                    QPKGs.ScStandalone.Exist "$prospect" && QPKGs.AcTo${action}.Add "$prospect"
                                done
                        esac
                        ;;
                    Start)
                        case $scope in
                            All)
                                found=true
                                QPKGs.AcTo${action}.Add "$(QPKGs.IsNtStarted.Array)"
                                ;;
                            Dependent)
                                found=true
                                for prospect in $(QPKGs.IsNtStarted.Array); do
                                    QPKGs.ScDependent.Exist "$prospect" && QPKGs.AcTo${action}.Add "$prospect"
                                done
                                ;;
                            Standalone)
                                found=true
                                for prospect in $(QPKGs.IsNtStarted.Array); do
                                    QPKGs.ScStandalone.Exist "$prospect" && QPKGs.AcTo${action}.Add "$prospect"
                                done
                        esac
                        ;;
                    Stop)
                        case $scope in
                            All)
                                found=true
                                QPKGs.AcTo${action}.Add "$(QPKGs.IsStarted.Array)"
                                ;;
                            Dependent)
                                found=true
                                for prospect in $(QPKGs.IsStarted.Array); do
                                    QPKGs.ScDependent.Exist "$prospect" && QPKGs.AcTo${action}.Add "$prospect"
                                done
                                ;;
                            Standalone)
                                found=true
                                for prospect in $(QPKGs.IsStarted.Array); do
                                    QPKGs.ScStandalone.Exist "$prospect" && QPKGs.AcTo${action}.Add "$prospect"
                                done
                        esac
                        ;;
                    Uninstall)
                        case $scope in
                            All)
                                found=true
                                QPKGs.AcTo${action}.Add "$(QPKGs.IsInstalled.Array)"
                                ;;
                            Dependent)
                                found=true
                                for prospect in $(QPKGs.IsInstalled.Array); do
                                    QPKGs.ScDependent.Exist "$prospect" && QPKGs.AcTo${action}.Add "$prospect"
                                done
                                ;;
                            Standalone)
                                found=true
                                for prospect in $(QPKGs.IsInstalled.Array); do
                                    QPKGs.ScStandalone.Exist "$prospect" && QPKGs.AcTo${action}.Add "$prospect"
                                done
                        esac
                        ;;
                    Upgrade)
                        case $scope in
                            All)
                                found=true
                                QPKGs.AcTo${action}.Add "$(QPKGs.ScUpgradable.Array)"
                                QPKGs.AcToRestart.Add "$(QPKGs.ScSupportUpdateOnRestart.Array)"
                                QPKGs.AcToRestart.Remove "$(QPKGs.IsNtInstalled.Array) $(QPKGs.AcToUpgrade.Array) $(QPKGs.ScStandalone.Array)"
                                ;;
                            Dependent)
                                found=true
                                for prospect in $(QPKGs.IsInstalled.Array); do
                                    QPKGs.ScDependent.Exist "$prospect" && QPKGs.AcTo${action}.Add "$prospect"
                                done
                                ;;
                            Standalone)
                                found=true
                                for prospect in $(QPKGs.IsInstalled.Array); do
                                    QPKGs.ScStandalone.Exist "$prospect" && QPKGs.AcTo${action}.Add "$prospect"
                                done
                        esac
                esac

                [[ $found != true ]] && QPKGs.AcTo${action}.Add "$(QPKGs.Sc${scope}.Array)" || found=false
            elif QPKGs.Ac${action}.ScNt${scope}.IsSet; then
                # use sensible scope exceptions (for convenience) rather than follow requested scope literally
                :

                [[ $found != true ]] && QPKGs.AcTo${action}.Add "$(QPKGs.ScNt${scope}.Array)" || found=false
            fi
        done

        # process state-based user-options
        for state in "${PACKAGE_STATES[@]}"; do
            if QPKGs.Ac${action}.Is${state}.IsSet; then
                # use sensible state exceptions (for convenience) rather than follow requested state literally
                case $action in
                    Uninstall)
                        case $state in
                            Installed)
                                found=true
                                QPKGs.AcTo${action}.Add "$(QPKGs.IsInstalled.Array)"
                        esac
                esac

                [[ $found != true ]] && QPKGs.AcTo${action}.Add "$(QPKGs.Is${state}.Array)" || found=false
            elif QPKGs.Ac${action}.IsNt${state}.IsSet; then
                # use sensible state exceptions (for convenience) rather than follow requested state literally
                case $action in
                    Install)
                        case $state in
                            Installed)
                                found=true
                                QPKGs.AcTo${action}.Add "$(QPKGs.IsNtInstalled.Array)"
                        esac
                esac

                [[ $found != true ]] && QPKGs.AcTo${action}.Add "$(QPKGs.IsNt${state}.Array)" || found=false
            fi
        done
    done

    DebugFuncExit

    }

ResetArchivedLogs()
    {

    if [[ -n $LOGS_PATH && -d $LOGS_PATH ]]; then
        rm -rf "${LOGS_PATH:?}"/*
        ShowAsDone 'all logs cleared'
    fi

    return 0

    }

ResetWorkPath()
    {

    if [[ -n $WORK_PATH && -d $WORK_PATH ]]; then
        rm -rf "${WORK_PATH:?}"/*
        ShowAsDone 'package cache cleared'
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

UpdateEntwarePackageList()
    {

    IsNtSysFileExist $OPKG_CMD && return 1
    [[ ${ENTWARE_PACKAGE_LIST_UPTODATE:-false} = true ]] && return 0

    local -r CHANGE_THRESHOLD_MINUTES=60
    local -r LOG_PATHFILE=$LOGS_PATH/entware.$UPDATE_LOG_FILE
    local -i result_code=0

    # if Entware package list was recently updated, don't update again.

    if ! IsThisFileRecent "$EXTERNAL_PACKAGES_ARCHIVE_PATHFILE" "$CHANGE_THRESHOLD_MINUTES" || [[ ! -f $EXTERNAL_PACKAGES_ARCHIVE_PATHFILE ]] || Opts.Deps.Check.IsSet; then
        DebugAsProc "updating $(FormatAsPackageName Entware) package list"

        RunAndLog "$OPKG_CMD update" "$LOG_PATHFILE" log:failure-only
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

    [[ -f $EXTERNAL_PACKAGES_ARCHIVE_PATHFILE && ! -f $EXTERNAL_PACKAGES_PATHFILE ]] && OpenIPKGArchive
    readonly ENTWARE_PACKAGE_LIST_UPTODATE=true

    return 0

    }

IsThisFileRecent()
    {

    # input:
    #   $1 = pathfilename: file to examine change time of
    #   $2 = integer (optional): threshold in minutes - default is '1440' = 1 day

    # output:
    #   $? = true/false

    # examine 'change' time as this is updated even if file content isn't modified
    if [[ -e $1 && -e $GNU_FIND_CMD ]]; then
        if [[ -z $($GNU_FIND_CMD "$1" -cmin +${2:-1440}) ]]; then        # no-output if last 'change' was less than $2 minutes ago
            return 0
        fi
    fi

    return 1    # file not found, GNU 'find' unavailable or file 'change' time was more than $2 minutes ago

    }

SavePackageLists()
    {

    $PIP_CMD freeze > "$PREVIOUS_PIP_MODULES_LIST" 2>/dev/null && DebugAsDone "saved current $(FormatAsPackageName pip3) module list to $(FormatAsFileName "$PREVIOUS_PIP_MODULES_LIST")"
    $OPKG_CMD list-installed > "$PREVIOUS_OPKG_PACKAGES_LIST" 2>/dev/null && DebugAsDone "saved current $(FormatAsPackageName Entware) IPKG list to $(FormatAsFileName "$PREVIOUS_OPKG_PACKAGES_LIST")"

    }

CalcIPKGsDepsToInstall()
    {

    # From a specified list of IPKG names, find all dependent IPKGs, exclude those already installed, then generate a total qty to download

    QPKGs.IsNtInstalled.Exist Entware && return
    QPKGs.IsNtStarted.Exist Entware && return
    IsNtSysFileExist $GNU_GREP_CMD && return 1
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
    req_list=$(DeDupeWords "$(IPKGs.AcToInstall.List)")
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

        this_list=($($GNU_GREP_CMD --word-regexp --after-context 1 --no-group-separator '^Package:\|^Depends:' "$EXTERNAL_PACKAGES_PATHFILE" | $GNU_GREP_CMD -vG '^Section:\|^Version:' | $GNU_GREP_CMD --word-regexp --after-context 1 --no-group-separator "$IPKG_titles" | $GNU_GREP_CMD -vG "$IPKG_titles" | $GNU_GREP_CMD -vG '^Package: ' | $SED_CMD 's|^Depends: ||;s|, |\n|g' | $SORT_CMD | /bin/uniq))

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
        Self.SuggestIssue.Set
    fi

    # exclude already installed IPKGs
    pre_exclude_list=$(DeDupeWords "$req_list ${dep_acc[*]}")
    pre_exclude_count=$($WC_CMD -w <<< "$pre_exclude_list")

    if [[ $pre_exclude_count -gt 0 ]]; then
        DebugInfo "$pre_exclude_count IPKG$(Plural "$pre_exclude_count") required (including dependencies)" "'$pre_exclude_list' "

        DebugAsProc 'excluding IPKGs already installed'

        for element in $pre_exclude_list; do
            # KLUDGE: silently exclude these from attempted installation:
            # KLUDGE: 'ca-certs' appears to be a bogus meta-package.
            # KLUDGE: 'python3-gdbm' is not available, but can be requested as per https://forum.qnap.com/viewtopic.php?p=806031#p806031 (don't know why).
            if [[ $element != 'ca-certs' && $element != 'python3-gdbm' ]]; then
                # KLUDGE: 'libjpeg' appears to have been replaced by 'libjpeg-turbo', but many packages still list 'libjpeg' as a dependency, so replace it with 'libjpeg-turbo'.
                if [[ $element != 'libjpeg' ]]; then
                    if ! $OPKG_CMD status "$element" | $GREP_CMD -q "Status:.*installed"; then
                        IPKGs.AcToDownload.Add "$element"
                    fi
                elif ! $OPKG_CMD status 'libjpeg-turbo' | $GREP_CMD -q "Status:.*installed"; then
                    IPKGs.AcToDownload.Add 'libjpeg-turbo'
                fi
            fi
        done
    else
        DebugAsDone 'no IPKGs to exclude'
    fi

    DebugFuncExit

    }

CalcIPKGsDownloadSize()
    {

    # calculate size of required IPKGs

    DebugFuncEntry

    local -a size_array=()
    local -i size_count=0
    size_count=$(IPKGs.AcToDownload.Count)

    if [[ $size_count -gt 0 ]]; then
        DebugAsDone "$size_count IPKG$(Plural "$size_count") to download: '$(IPKGs.AcToDownload.List)'"
        DebugAsProc "calculating size of IPKG$(Plural "$size_count") to download"
        size_array=($($GNU_GREP_CMD -w '^Package:\|^Size:' "$EXTERNAL_PACKAGES_PATHFILE" | $GNU_GREP_CMD --after-context 1 --no-group-separator ": $($SED_CMD 's/ /$ /g;s/\$ /\$\\\|: /g' <<< "$(IPKGs.AcToDownload.List)")" | $GREP_CMD '^Size:' | $SED_CMD 's|^Size: ||'))
        IPKGs.AcToDownload.Size = "$(IFS=+; echo "$((${size_array[*]}))")"   # a neat sizing shortcut found here https://stackoverflow.com/a/13635566/6182835
        DebugAsDone "$(FormatAsThousands "$(IPKGs.AcToDownload.Size)") bytes ($(FormatAsISOBytes "$(IPKGs.AcToDownload.Size)")) to download"
    else
        DebugAsDone 'no IPKGs to size'
    fi

    DebugFuncExit

    }

IPKGs.Upgrade()
    {

    # upgrade all installed IPKGs

    QPKGs.SkProc.IsSet && return
    IPKGs.Upgrade.IsNt && return
    QPKGs.IsNtInstalled.Exist Entware && return
    QPKGs.IsNtStarted.Exist Entware && return
    UpdateEntwarePackageList
    Self.Error.IsSet && return
    DebugFuncEntry

    local -i result_code=0
    IPKGs.AcToUpgrade.Init
    IPKGs.AcToDownload.Init

    IPKGs.AcToUpgrade.Add "$($OPKG_CMD list-upgradable | cut -f1 -d' ')"
    IPKGs.AcToDownload.Add "$(IPKGs.AcToUpgrade.Array)"

    CalcIPKGsDownloadSize
    local -i total_count=$(IPKGs.AcToDownload.Count)

    if [[ $total_count -gt 0 ]]; then
        ShowAsProc "downloading & upgrading $total_count IPKG$(Plural "$total_count")"

        CreateDirSizeMonitorFlagFile "$IPKG_DL_PATH"/.monitor
            trap CTRL_C_Captured INT
                _MonitorDirSize_ "$IPKG_DL_PATH" "$(IPKGs.AcToDownload.Size)" &

                RunAndLog "$OPKG_CMD upgrade --force-overwrite $(IPKGs.AcToDownload.List) --cache $IPKG_CACHE_PATH --tmp-dir $IPKG_DL_PATH" "$LOGS_PATH/ipkgs.$UPGRADE_LOG_FILE" log:failure-only
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

IPKGs.Install()
    {

    # install IPKGs required to support QPKGs

    QPKGs.SkProc.IsSet && return
    IPKGs.Install.IsNt && return
    QPKGs.IsNtInstalled.Exist Entware && return
    QPKGs.IsNtStarted.Exist Entware && return
    UpdateEntwarePackageList
    Self.Error.IsSet && return
    DebugFuncEntry

    local -i index=0
    local -i result_code=0
    IPKGs.AcToInstall.Init
    IPKGs.AcToDownload.Init

    IPKGs.AcToInstall.Add "$BASE_IPKGS_INSTALL"

    if QPKGs.AcInstall.ScAll.IsSet; then
        for index in "${!QPKG_NAME[@]}"; do
            [[ ${QPKG_ARCH[$index]} = "$NAS_QPKG_ARCH" || ${QPKG_ARCH[$index]} = all ]] || continue
            IPKGs.AcToInstall.Add "${QPKG_IPKGS_INSTALL[$index]}"
        done
    else
        for index in "${!QPKG_NAME[@]}"; do
            if QPKGs.AcToInstall.Exist "${QPKG_NAME[$index]}" || QPKGs.IsInstalled.Exist "${QPKG_NAME[$index]}" || QPKGs.AcToReinstall.Exist "${QPKG_NAME[$index]}" || QPKGs.AcToStart.Exist "${QPKG_NAME[$index]}"; then
                [[ ${QPKG_ARCH[$index]} = "$NAS_QPKG_ARCH" || ${QPKG_ARCH[$index]} = all ]] || continue
                QPKG.MinRAM "${QPKG_NAME[$index]}" &>/dev/null || continue
                IPKGs.AcToInstall.Add "${QPKG_IPKGS_INSTALL[$index]}"
            fi
        done
    fi

    CalcIPKGsDepsToInstall
    CalcIPKGsDownloadSize
    local -i total_count=$(IPKGs.AcToDownload.Count)

    if [[ $total_count -gt 0 ]]; then
        ShowAsProc "downloading & installing $total_count IPKG$(Plural "$total_count")"

        CreateDirSizeMonitorFlagFile "$IPKG_DL_PATH"/.monitor
            trap CTRL_C_Captured INT
                _MonitorDirSize_ "$IPKG_DL_PATH" "$(IPKGs.AcToDownload.Size)" &

                RunAndLog "$OPKG_CMD install --force-overwrite $(IPKGs.AcToDownload.List) --cache $IPKG_CACHE_PATH --tmp-dir $IPKG_DL_PATH" "$LOGS_PATH/ipkgs.addons.$INSTALL_LOG_FILE" log:failure-only
                result_code=$?
            trap - INT
        RemoveDirSizeMonitorFlagFile

        if [[ $result_code -eq 0 ]]; then
            ShowAsDone "downloaded & installed $total_count IPKG$(Plural "$total_count")"
            IPKGs.AcOkInstall.Add "$(IPKGs.AcToDownload.Array)"
        else
            ShowAsFail "download & install $total_count IPKG$(Plural "$total_count") failed $(FormatAsExitcode $result_code)"
        fi
    fi

    DebugFuncExit

    }

PIPs.Install()
    {

    QPKGs.SkProc.IsSet && return
    PIPs.Install.IsNt && return
    QPKGs.IsNtInstalled.Exist Entware && return
    QPKGs.IsNtStarted.Exist Entware && return
    ! $OPKG_CMD status python3-pip | $GREP_CMD -q "Status:.*installed" && return
    Self.Error.IsSet && return
    DebugFuncEntry

    local exec_cmd=''
    local -i result_code=0
    local -i pass_count=0
    local -i fail_count=0
    local -i total_count=1
    local -i index=0
    local -r PACKAGE_TYPE='PIP group'
    local ACTION_PRESENT=installing
    local ACTION_PAST=installed
    local -r RUNTIME=long
    ModPathToEntware

    if Opts.Deps.Check.IsSet || IPKGs.AcOkInstall.Exist python3-pip; then
        ShowAsActionProgress '' "$PACKAGE_TYPE" "$pass_count" "$fail_count" "$total_count" "$ACTION_PRESENT" "$RUNTIME"

        exec_cmd="$PIP_CMD install --upgrade --no-input $BASE_PIPS_INSTALL --cache-dir $PIP_CACHE_PATH"
        local desc="'Python3' base modules"
        local log_pathfile=$LOGS_PATH/py3-modules.base.$INSTALL_LOG_FILE
        DebugAsProc "$ACTION_PRESENT $desc"
        RunAndLog "$exec_cmd" "$log_pathfile" log:failure-only
        result_code=$?

        if [[ $result_code -eq 0 ]]; then
            DebugAsDone "$ACTION_PAST $desc"
            ((pass_count++))
        else
            ShowAsFail "$ACTION_PAST $desc failed $(FormatAsResult "$result_code")"
            ((fail_count++))
        fi
    else
        ((total_count--))
    fi

    # execute with pass_count > total_count to trigger 100% message
    ShowAsActionProgress '' "$PACKAGE_TYPE" "$((total_count + 1))" "$fail_count" "$total_count" "$ACTION_PRESENT" "$RUNTIME"
    ShowAsActionResult '' "$PACKAGE_TYPE" "$pass_count" "$fail_count" "$total_count" "$ACTION_PAST" "$RUNTIME"
    DebugFuncExit $result_code

    }

OpenIPKGArchive()
    {

    # extract the 'opkg' package list file

    # output:
    #   $? = 0 if successful or 1 if failed

    if [[ ! -e $EXTERNAL_PACKAGES_ARCHIVE_PATHFILE ]]; then
        ShowAsError 'unable to locate the IPKG list file'
        return 1
    fi

    RunAndLog "/usr/local/sbin/7z e -o$($DIRNAME_CMD "$EXTERNAL_PACKAGES_PATHFILE") $EXTERNAL_PACKAGES_ARCHIVE_PATHFILE" "$WORK_PATH/ipkg.list.archive.extract" log:failure-only
    result_code=$?

    if [[ ! -e $EXTERNAL_PACKAGES_PATHFILE ]]; then
        ShowAsError 'unable to open the IPKG list file'
        return 1
    fi

    return 0

    }

CloseIPKGArchive()
    {

    [[ -f $EXTERNAL_PACKAGES_PATHFILE ]] && rm -f "$EXTERNAL_PACKAGES_PATHFILE"

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

        percent="$((200 * (current_bytes) / (total_bytes) % 2 + 100 * (current_bytes) / (total_bytes)))%"
        [[ $current_bytes -lt $total_bytes && $percent = '100%' ]] && percent='99%' # ensure we don't hit 100% until the last byte is downloaded
        progress_message="$percent ($(FormatAsISOBytes "$current_bytes")/$(FormatAsISOBytes "$total_bytes"))"

        if [[ $stall_seconds -ge $stall_seconds_threshold ]]; then
            # append a message showing stalled time
            if [[ $stall_seconds -lt 60 ]]; then
                stall_message=" stalled for $stall_seconds seconds"
            else
                stall_message=" stalled for $(FormatSecsToHoursMinutesSecs $stall_seconds)"
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
        this_length=$((${#this_clean_msg} + 1))

        if [[ $this_length -lt $previous_length ]]; then
            blanking_length=$((this_length - previous_length))
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

IsSU()
    {

    # running as superuser?

    if [[ $EUID -ne 0 ]]; then
        if [[ -e /usr/bin/sudo ]]; then
            ShowAsError 'this utility must be run with superuser privileges. Try again as:'
            echo "$ sudo $PROJECT_NAME"
        else
            ShowAsError "this utility must be run as the 'admin' user. Please login via SSH as 'admin' and try again"
        fi
        return 1
    fi

    return 0

    }

GetDefaultPythonVersion()
    {

    GetThisBinaryPath python &>/dev/null && python -V 2>&1 | $SED_CMD 's|^Python ||'

    }

GetDefaultPython3Version()
    {

    GetThisBinaryPath python3 &>/dev/null && python3 -V 2>&1 | $SED_CMD 's|^Python ||'

    }

GetDefaultPerlVersion()
    {

    GetThisBinaryPath perl &>/dev/null && perl -e 'print "$^V\n"' 2>/dev/null | $SED_CMD 's|v||'

    }

GetThisBinaryPath()
    {

    [[ -n ${1:?empty} ]] && command -v "$1" 2>&1

    }

LogBinaryPathAndVersion()
    {

    # $1 = binary filename
    # $2 = current version found
    # $3 = minimum version required

    [[ -z $1 ]] && return 1

    local binarypath=$(GetThisBinaryPath "$1")

    if [[ -n $binarypath ]]; then
        DebugUserspaceOK "'$1' path" "$binarypath"
    else
        DebugUserspaceWarning "'$1' path" '<not present>'
    fi

    if [[ -n $2 ]]; then
        if [[ ${2//./} -ge ${3//./} ]]; then
            DebugUserspaceOK "'$1' version" "$2"
        else
            DebugUserspaceWarning "'$1' version" "$2"
        fi
    else
        DebugUserspaceWarning "'$1' version" '<unknown>'
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

readonly HELP_PACKAGE_NAME_WIDTH=20
readonly HELP_PACKAGE_STATUS_WIDTH=40
readonly HELP_PACKAGE_VERSION_WIDTH=17
readonly HELP_PACKAGE_PATH_WIDTH=42
readonly HELP_PACKAGE_REPO_WIDTH=40
readonly HELP_FILE_NAME_WIDTH=33

readonly HELP_COLUMN_SPACER=' '
readonly HELP_COLUMN_MAIN_PREFIX='* '
readonly HELP_COLUMN_OTHER_PREFIX='- '
readonly HELP_COLUMN_BLANK_PREFIX='  '
readonly HELP_SYNTAX_PREFIX='# '

LenANSIDiff()
    {

    local stripped=$(StripANSI "$1")
    echo $((${#1} - ${#stripped}))

    return 0

    }

DisplayAsProjectSyntaxExample()
    {

    # $1 = description
    # $2 = example syntax

    if [[ ${1: -1} = '!' ]]; then
        printf "${HELP_COLUMN_MAIN_PREFIX}%s\n%${HELP_SYNTAX_INDENT}s${HELP_SYNTAX_PREFIX}%s\n" "$(Capitalise "$1")" '' "$PROJECT_NAME $2"
    else
        printf "${HELP_COLUMN_MAIN_PREFIX}%s:\n%${HELP_SYNTAX_INDENT}s${HELP_SYNTAX_PREFIX}%s\n" "$(Capitalise "$1")" '' "$PROJECT_NAME $2"
    fi

    Self.LineSpace.UnSet

    }

DisplayAsProjectSyntaxIndentedExample()
    {

    # $1 = description
    # $2 = example syntax

    if [[ -z ${1:-} ]]; then
        printf "%${HELP_SYNTAX_INDENT}s${HELP_SYNTAX_PREFIX}%s\n" '' "$PROJECT_NAME $2"
    elif [[ ${1: -1} = '!' ]]; then
        printf "\n%${HELP_DESC_INDENT}s%s\n%${HELP_SYNTAX_INDENT}s${HELP_SYNTAX_PREFIX}%s\n" '' "$(Capitalise "$1")" '' "$PROJECT_NAME $2"
    else
        printf "\n%${HELP_DESC_INDENT}s%s:\n%${HELP_SYNTAX_INDENT}s${HELP_SYNTAX_PREFIX}%s\n" '' "$(Capitalise "$1")" '' "$PROJECT_NAME $2"
    fi

    Self.LineSpace.UnSet

    }

DisplayAsSyntaxExample()
    {

    # $1 = description
    # $2 = example syntax

    if [[ -z $2 && ${1: -1} = ':' ]]; then
        printf "\n${HELP_COLUMN_MAIN_PREFIX}%s\n" "$1"
    elif [[ ${1: -1} = '!' ]]; then
        printf "\n${HELP_COLUMN_MAIN_PREFIX}%s\n%${HELP_SYNTAX_INDENT}s${HELP_SYNTAX_PREFIX}%s\n" "$(Capitalise "$1")" '' "$2"
    else
        printf "\n${HELP_COLUMN_MAIN_PREFIX}%s:\n%${HELP_SYNTAX_INDENT}s${HELP_SYNTAX_PREFIX}%s\n" "$(Capitalise "$1")" '' "$2"
    fi

    Self.LineSpace.UnSet

    }

DisplayAsHelpTitlePackageNamePlusSomething()
    {

    # $1 = package name title
    # $2 = second column title

    printf "${HELP_COLUMN_MAIN_PREFIX}%-${HELP_PACKAGE_NAME_WIDTH}s${HELP_COLUMN_SPACER}${HELP_COLUMN_MAIN_PREFIX}%s\n" "$(Capitalise "$1"):" "$(Capitalise "$2"):"

    }

DisplayAsHelpPackageNamePlusSomething()
    {

    # $1 = package name
    # $2 = second column text

    printf "${HELP_COLUMN_SPACER}${HELP_COLUMN_BLANK_PREFIX}%-${HELP_PACKAGE_NAME_WIDTH}s${HELP_COLUMN_SPACER}${HELP_COLUMN_OTHER_PREFIX}%s\n" "${1:-}" "${2:-}"

    }

CalculateMaximumStatusColumnsToDisplay()
    {

    local column1_width=$((${#HELP_COLUMN_MAIN_PREFIX} + HELP_PACKAGE_NAME_WIDTH))
    local column2_width=$((${#HELP_COLUMN_SPACER} + ${#HELP_COLUMN_MAIN_PREFIX} + HELP_PACKAGE_STATUS_WIDTH))
    local column3_width=$((${#HELP_COLUMN_SPACER} + ${#HELP_COLUMN_MAIN_PREFIX} + HELP_PACKAGE_VERSION_WIDTH))
    local column4_width=$((${#HELP_COLUMN_SPACER} + ${#HELP_COLUMN_MAIN_PREFIX} + HELP_PACKAGE_PATH_WIDTH))

    if [[ $((column1_width + column2_width)) -ge $SESSION_COLUMNS ]]; then
        echo 1
    elif [[ $((column1_width + column2_width + column3_width)) -ge $SESSION_COLUMNS ]]; then
        echo 2
    elif [[ $((column1_width + column2_width + column3_width + column4_width)) -ge $SESSION_COLUMNS ]]; then
        echo 3
    else
        echo 4
    fi

    return 0

    }

CalculateMaximumRepoColumnsToDisplay()
    {

    local column1_width=$((${#HELP_COLUMN_MAIN_PREFIX} + HELP_PACKAGE_NAME_WIDTH))
    local column2_width=$((${#HELP_COLUMN_SPACER} + ${#HELP_COLUMN_MAIN_PREFIX} + HELP_PACKAGE_REPO_WIDTH))

    if [[ $((column1_width + column2_width)) -ge $SESSION_COLUMNS ]]; then
        echo 1
    else
        echo 2
    fi

    return 0

    }

DisplayAsHelpTitlePackageNameVersionStatus()
    {

    # $1 = package name title
    # $2 = package status title
    # $3 = package version title
    # $4 = package installation location (only if installed)

    local maxcols=$(CalculateMaximumStatusColumnsToDisplay)

    if [[ -n ${1:-} && $maxcols -ge 1 ]]; then
        printf "${HELP_COLUMN_MAIN_PREFIX}%-${HELP_PACKAGE_NAME_WIDTH}s" "$(Capitalise "$1"):"
    fi

    if [[ -n ${2:-} && $maxcols -ge 2 ]]; then
        printf "${HELP_COLUMN_SPACER}${HELP_COLUMN_MAIN_PREFIX}%-${HELP_PACKAGE_STATUS_WIDTH}s" "$(Capitalise "$2"):"
    fi

    if [[ -n ${3:-} && $maxcols -ge 3 ]]; then
        printf "${HELP_COLUMN_SPACER}${HELP_COLUMN_MAIN_PREFIX}%-${HELP_PACKAGE_VERSION_WIDTH}s" "$(Capitalise "$3"):"
    fi

    if [[ -n ${4:-} && $maxcols -ge 4 ]]; then
        printf "${HELP_COLUMN_SPACER}${HELP_COLUMN_MAIN_PREFIX}%s" "$(Capitalise "$4"):"
    fi

    printf '\n'

    }

DisplayAsHelpPackageNameVersionStatus()
    {

    # $1 = package name
    # $2 = package status (optional)
    # $3 = package version number (optional)
    # $4 = package installation path (optional) only if installed

    local maxcols=$(CalculateMaximumStatusColumnsToDisplay)

    if [[ -n ${1:-} && $maxcols -ge 1 ]]; then
        printf "${HELP_COLUMN_SPACER}${HELP_COLUMN_BLANK_PREFIX}%-$((HELP_PACKAGE_NAME_WIDTH + $(LenANSIDiff "$1")))s" "$1"
    fi

    if [[ -n ${2:-} && $maxcols -ge 2 ]]; then
        printf "${HELP_COLUMN_SPACER}${HELP_COLUMN_OTHER_PREFIX}%-$((HELP_PACKAGE_STATUS_WIDTH + $(LenANSIDiff "$2")))s" "$2"
    fi

    if [[ -n ${3:-} && $maxcols -ge 3 ]]; then
        printf "${HELP_COLUMN_SPACER}${HELP_COLUMN_OTHER_PREFIX}%-$((HELP_PACKAGE_VERSION_WIDTH + $(LenANSIDiff "$3")))s" "$3"
    fi

    if [[ -n ${4:-} && $maxcols -ge 4 ]]; then
        printf "${HELP_COLUMN_SPACER}${HELP_COLUMN_BLANK_PREFIX}%s" "$4"
    fi

    printf '\n'

    }

DisplayAsHelpTitlePackageNameRepo()
    {

    # $1 = package name title
    # $2 = assigned repository title

    local maxcols=$(CalculateMaximumStatusColumnsToDisplay)

    if [[ -n ${1:-} && $maxcols -ge 1 ]]; then
        printf "${HELP_COLUMN_MAIN_PREFIX}%-${HELP_PACKAGE_NAME_WIDTH}s" "$(Capitalise "$1"):"
    fi

    if [[ -n ${2:-} && $maxcols -ge 2 ]]; then
        printf "${HELP_COLUMN_SPACER}${HELP_COLUMN_MAIN_PREFIX}%-${HELP_PACKAGE_REPO_WIDTH}s" "$(Capitalise "$2"):"
    fi

    printf '\n'

    }

DisplayAsHelpPackageNameRepo()
    {

    # $1 = package name
    # $2 = assigned repository

    local maxcols=$(CalculateMaximumRepoColumnsToDisplay)

    if [[ -n ${1:-} && $maxcols -ge 1 ]]; then
        printf "${HELP_COLUMN_SPACER}${HELP_COLUMN_BLANK_PREFIX}%-$((HELP_PACKAGE_NAME_WIDTH + $(LenANSIDiff "$1")))s" "$1"
    fi

    if [[ -n ${2:-} && $maxcols -ge 2 ]]; then
        printf "${HELP_COLUMN_SPACER}${HELP_COLUMN_OTHER_PREFIX}%-$((HELP_PACKAGE_REPO_WIDTH + $(LenANSIDiff "$2")))s" "$2"
    fi

    printf '\n'

    }

DisplayAsHelpTitleFileNamePlusSomething()
    {

    # $1 = file name title
    # $2 = second column title

    printf "${HELP_COLUMN_MAIN_PREFIX}%-${HELP_FILE_NAME_WIDTH}s ${HELP_COLUMN_MAIN_PREFIX}%s\n" "$(Capitalise "$1"):" "$(Capitalise "$2"):"

    }

DisplayAsHelpTitle()
    {

    # $1 = text

    printf "${HELP_COLUMN_MAIN_PREFIX}%s\n" "$(Capitalise "$1")"

    }

DisplayAsHelpTitleHighlighted()
    {

    # $1 = text

    # shellcheck disable=2059
    printf "$(ColourTextBrightOrange "${HELP_COLUMN_MAIN_PREFIX}%s\n")" "$(Capitalise "$1")"

    }

SmartCR()
    {

    # reset cursor to start-of-line, erasing previous characters

    [[ $(type -t Self.Debug.ToScreen.Init) = function ]] && Self.Debug.ToScreen.IsSet && return

    echo -en "\033[1K\r"

    }

Display()
    {

    echo -e "${1:-}"
    [[ $(type -t Self.LineSpace.Init) = function ]] && Self.LineSpace.UnSet

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
    DisplayAsProjectSyntaxIndentedExample '' 's'
    DisplayAsProjectSyntaxIndentedExample 'show package repositories' 'repos'
    DisplayAsProjectSyntaxIndentedExample '' 'r'
    DisplayAsProjectSyntaxIndentedExample 'ensure all application dependencies are installed' 'check'
    DisplayAsProjectSyntaxIndentedExample 'install these packages' "install $(FormatAsHelpPackages)"
    DisplayAsProjectSyntaxIndentedExample 'uninstall these packages' "uninstall $(FormatAsHelpPackages)"
    DisplayAsProjectSyntaxIndentedExample 'reinstall these packages' "reinstall $(FormatAsHelpPackages)"
    DisplayAsProjectSyntaxIndentedExample "rebuild these packages ('install' packages, then 'restore' configuration backups)" "rebuild $(FormatAsHelpPackages)"
    DisplayAsProjectSyntaxIndentedExample 'upgrade these packages (and internal applications)' "upgrade $(FormatAsHelpPackages)"
    DisplayAsProjectSyntaxIndentedExample 'start these packages' "start $(FormatAsHelpPackages)"
    DisplayAsProjectSyntaxIndentedExample 'stop these packages' "stop $(FormatAsHelpPackages)"
    DisplayAsProjectSyntaxIndentedExample 'restart these packages' "restart $(FormatAsHelpPackages)"
    DisplayAsProjectSyntaxIndentedExample 'clear local repository files from these packages' "clean $(FormatAsHelpPackages)"
    DisplayAsProjectSyntaxIndentedExample 'backup these application configurations to the backup location' "backup $(FormatAsHelpPackages)"
    DisplayAsProjectSyntaxIndentedExample 'restore these application configurations from the backup location' "restore $(FormatAsHelpPackages)"
    DisplayAsProjectSyntaxIndentedExample 'show application backup files' 'list backups'
    DisplayAsProjectSyntaxIndentedExample '' 'b'
    DisplayAsProjectSyntaxIndentedExample "list $(FormatAsScriptTitle) object version numbers" 'list versions'
    DisplayAsProjectSyntaxIndentedExample '' 'v'
    Display
    DisplayAsProjectSyntaxExample "$(FormatAsHelpAction)s to affect all packages can be seen with" 'all-actions'
    Display
    DisplayAsProjectSyntaxExample "multiple $(FormatAsHelpAction)s are supported like this" "$(FormatAsHelpAction) $(FormatAsHelpPackages) $(FormatAsHelpAction) $(FormatAsHelpPackages)"
    DisplayAsProjectSyntaxIndentedExample '' 'install sabnzbd sickgear restart transmission uninstall lazy nzbget upgrade nzbtomedia'

    return 0

    }

Help.ActionsAll.Show()
    {

    DisableDebugToArchiveAndFile
    Help.Basic.Show
    DisplayLineSpaceIfNoneAlready
    DisplayAsHelpTitle "these $(FormatAsHelpAction)s apply to all installed packages. If $(FormatAsHelpAction) is 'install all' then all available packages will be installed."
    Display
    DisplayAsHelpTitle "$(FormatAsHelpAction) usage examples:"
    DisplayAsProjectSyntaxIndentedExample 'show package statuses' 'status'
    DisplayAsProjectSyntaxIndentedExample '' 's'
    DisplayAsProjectSyntaxIndentedExample 'show package repositories' 'repos'
    DisplayAsProjectSyntaxIndentedExample '' 'r'
    DisplayAsProjectSyntaxIndentedExample 'install everything!' 'install all'
    DisplayAsProjectSyntaxIndentedExample 'uninstall everything!' 'force uninstall all'
    DisplayAsProjectSyntaxIndentedExample 'reinstall all installed packages' 'reinstall all'
    DisplayAsProjectSyntaxIndentedExample "rebuild all packages with backups ('install' packages and 'restore' backups)" 'rebuild all'
    DisplayAsProjectSyntaxIndentedExample 'upgrade all installed packages (and internal applications)' 'upgrade all'
    DisplayAsProjectSyntaxIndentedExample 'start all installed packages (upgrade internal applications, not packages)' 'start all'
    DisplayAsProjectSyntaxIndentedExample 'stop all installed packages' 'stop all'
    DisplayAsProjectSyntaxIndentedExample 'restart packages that are able to upgrade their internal applications' 'restart all'
    DisplayAsProjectSyntaxIndentedExample 'clear local repository files from all packages' 'clean all'
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
    DisplayAsProjectSyntaxIndentedExample '' 'a'

    return 0

    }

Help.Options.Show()
    {

    DisableDebugToArchiveAndFile
    Help.Basic.Show
    DisplayLineSpaceIfNoneAlready
    DisplayAsHelpTitle "$(FormatAsHelpOptions) usage examples:"
    DisplayAsProjectSyntaxIndentedExample 'process one-or-more packages and show live debugging information' "$(FormatAsHelpAction) $(FormatAsHelpPackages) debug"
    DisplayAsProjectSyntaxIndentedExample '' "$(FormatAsHelpAction) $(FormatAsHelpPackages) verbose"

    return 0

    }

Help.Problems.Show()
    {

    DisableDebugToArchiveAndFile
    Help.Basic.Show
    DisplayLineSpaceIfNoneAlready
    DisplayAsHelpTitle 'usage examples for dealing with problems:'
    DisplayAsProjectSyntaxIndentedExample 'show package statuses' 'status'
    DisplayAsProjectSyntaxIndentedExample '' 's'
    DisplayAsProjectSyntaxIndentedExample 'process one-or-more packages and show live debugging information' "$(FormatAsHelpAction) $(FormatAsHelpPackages) debug"
    DisplayAsProjectSyntaxIndentedExample '' "$(FormatAsHelpAction) $(FormatAsHelpPackages) verbose"
    DisplayAsProjectSyntaxIndentedExample 'ensure all application dependencies are installed' 'check'
    DisplayAsProjectSyntaxIndentedExample 'clear local repository files from these packages' "clean $(FormatAsHelpPackages)"
    DisplayAsProjectSyntaxIndentedExample "remove all cached $(FormatAsScriptTitle) items and logs" 'reset'
    DisplayAsProjectSyntaxIndentedExample 'restart all installed packages (upgrades the internal applications, not packages)' 'restart all'
    DisplayAsProjectSyntaxIndentedExample 'start these packages and enable package icons' "start $(FormatAsHelpPackages)"
    DisplayAsProjectSyntaxIndentedExample 'stop these packages and disable package icons' "stop $(FormatAsHelpPackages)"
    DisplayAsProjectSyntaxIndentedExample "view only the most recent $(FormatAsScriptTitle) session log" 'last'
    DisplayAsProjectSyntaxIndentedExample '' 'l'
    DisplayAsProjectSyntaxIndentedExample "view the entire $(FormatAsScriptTitle) session log" 'log'
    DisplayAsProjectSyntaxIndentedExample "upload the most-recent session in your $(FormatAsScriptTitle) log to the $(FormatAsURL 'https://termbin.com') public pastebin. A URL will be generated afterward" 'paste last'
    DisplayAsProjectSyntaxIndentedExample "upload the most-recent $(FormatAsThousands "$LOG_TAIL_LINES") entries in your $(FormatAsScriptTitle) log to the $(FormatAsURL 'https://termbin.com') public pastebin. A URL will be generated afterward" 'paste log'
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
    DisplayAsProjectSyntaxIndentedExample "upload the most-recent $(FormatAsThousands "$LOG_TAIL_LINES") entries in your $(FormatAsScriptTitle) log to the $(FormatAsURL 'https://termbin.com') public pastebin. A URL will be generated afterward" 'paste log'
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
    DisplayAsProjectSyntaxIndentedExample "view only the most recent $(FormatAsScriptTitle) session log" 'last'
    DisplayAsProjectSyntaxIndentedExample '' 'l'
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
        ShowAsError 'no last session log to display'
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
        ShowAsError 'no session log tail to display'
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
            Self.Summary.UnSet
            return 1
        fi
    else
        ShowAsError 'no last session log found'
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
            Self.Summary.UnSet
            return 1
        fi
    else
        ShowAsError 'no session log tail found'
    fi

    return 0

    }

GetLogSessionStartLine()
    {

    # $1 = how many sessions back? (optional) default = 1

    local -i linenum=$(($($GREP_CMD -n 'SCRIPT:.*started:' "$SESSION_TAIL_PATHFILE" | $TAIL_CMD -n${1:-1} | $HEAD_CMD -n1 | cut -d':' -f1) - 1))
    [[ $linenum -lt 1 ]] && linenum=1
    echo $linenum

    }

GetLogSessionFinishLine()
    {

    # $1 = how many sessions back? (optional) default = 1

    local -i linenum=$(($($GREP_CMD -n 'SCRIPT:.*finished:' "$SESSION_TAIL_PATHFILE" | $TAIL_CMD -n${1:-1} | cut -d':' -f1) + 2))
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
        start_line=$((end_line + 1))      # ensure an invalid condition, to be solved by the loop

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

    Display "package: ${THIS_PACKAGE_VER:-unknown}"
    Display "manager: ${MANAGER_SCRIPT_VER:-unknown}"
    Display "loader: ${LOADER_SCRIPT_VER:-unknown}"
    Display "objects: ${OBJECTS_VER:-unknown}"
    Display "packages: ${PACKAGES_VER:-unknown}"

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

    for ((index=0; index<=((${#left_to_upgrade[@]} - 1)); index++)); do
        names_formatted+=$(ColourTextBrightOrange "${left_to_upgrade[$index]}")

        if [[ $((index + 2)) -lt ${#left_to_upgrade[@]} ]]; then
            names_formatted+=', '
        elif [[ $((index + 2)) -eq ${#left_to_upgrade[@]} ]]; then
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

    local package=''

    if [[ -n ${BASE_QPKG_CONFLICTS_WITH:-} ]]; then
        # shellcheck disable=2068
        for package in ${BASE_QPKG_CONFLICTS_WITH[@]}; do
            if [[ $($GETCFG_CMD "$package" Enable -u -f /etc/config/qpkg.conf) = 'TRUE' ]]; then
                ShowAsError "the '$package' QPKG is enabled. $(FormatAsScriptTitle) is incompatible with this package. Please consider 'stop'ing this QPKG in your App Center"
                return 1
            fi
        done
    fi

    return 0

    }

QPKGs.Warnings.Check()
    {

    local package=''

    if [[ -n ${BASE_QPKG_WARNINGS:-} ]]; then
        # shellcheck disable=2068
        for package in ${BASE_QPKG_WARNINGS[@]}; do
            if [[ $($GETCFG_CMD "$package" Enable -u -f /etc/config/qpkg.conf) = 'TRUE' ]]; then
                ShowAsWarn "the '$package' QPKG is enabled. This may cause problems with $(FormatAsScriptTitle) applications. Please consider 'stop'ing this QPKG in your App Center"
            fi
        done
    fi

    return 0

    }

QPKGs.Actions.List()
    {

    QPKGs.SkProc.IsSet && return
    DebugFuncEntry

    local action=''
    local prefix=''
    DebugInfoMinorSeparator

    for action in "${PACKAGE_ACTIONS[@]}"; do
        # speedup: only log arrays with more than zero elements
        for prefix in To Ok Er Sk; do
            if QPKGs.Ac${prefix}${action}.IsAny; then
                if [[ $prefix != To ]]; then
                    DebugQPKGInfo "Ac${prefix}${action}" "($(QPKGs.Ac${prefix}${action}.Count)) $(QPKGs.Ac${prefix}${action}.ListCSV) "
                else
                    DebugQPKGWarning "Ac${prefix}${action}" "($(QPKGs.Ac${prefix}${action}.Count)) $(QPKGs.Ac${prefix}${action}.ListCSV) "
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

    for state in "${PACKAGE_STATES[@]}" "${PACKAGE_RESULTS[@]}"; do
        # speedup: only log arrays with more than zero elements
        for prefix in Is IsNt; do
            if [[ $prefix = IsNt && $state = Ok ]]; then
                QPKGs.${prefix}${state}.IsAny && DebugQPKGError "${prefix}${state}" "($(QPKGs.${prefix}${state}.Count)) $(QPKGs.${prefix}${state}.ListCSV) "
            elif [[ $prefix = IsNt && $state = BackedUp ]]; then
                QPKGs.${prefix}${state}.IsAny && DebugQPKGWarning "${prefix}${state}" "($(QPKGs.${prefix}${state}.Count)) $(QPKGs.${prefix}${state}.ListCSV) "
            elif [[ $prefix = IsNt && $state = Installed ]]; then
                # don't log packages that haven't been installed - it pollutes the runtime log
                :
            else
                QPKGs.${prefix}${state}.IsAny && DebugQPKGInfo "${prefix}${state}" "($(QPKGs.${prefix}${state}.Count)) $(QPKGs.${prefix}${state}.ListCSV) "
            fi
        done
    done

    for state in "${PACKAGE_STATES_TEMPORARY[@]}"; do
        # speedup: only log arrays with more than zero elements
        # shellcheck disable=2043
        for prefix in Is; do
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

    for index in "${!QPKG_NAME[@]}"; do
        if [[ -z ${QPKG_DEPENDS_ON[$index]} ]]; then
            QPKGs.ScStandalone.Add "${QPKG_NAME[$index]}"
        else
            QPKGs.ScDependent.Add "${QPKG_NAME[$index]}"
        fi
    done

    return 0

    }

QPKGs.States.Build()
    {

    # Builds several lists of QPKGs:
    #   - can be installed or reinstalled by the user
    #   - are installed or not
    #   - can be upgraded
    #   - are enabled or disabled in [/etc/config/qpkg.conf]
    #   - are started or stopped
    #   - have backup files in backup location
    #   - have config blocks in [/etc/config/qpkg.conf], but no files on-disk
    #   - those in the process of starting, stopping, or restarting

    # NOTE: these lists cannot be rebuilt unless element removal methods are added

    QPKGs.States.Built.IsSet && return
    DebugFuncEntry

    local -i index=0
    local package=''
    local previous=''
    ShowAsProc 'package states' >&2

    for index in "${!QPKG_NAME[@]}"; do
        package="${QPKG_NAME[$index]}"
        [[ $package = "$previous" ]] && continue || previous=$package

        if $GREP_CMD -q "^\[$package\]" /etc/config/qpkg.conf; then
            if [[ ! -d $(QPKG.InstallationPath "$package") ]]; then
                QPKGs.IsMissing.Add "$package"
                continue
            fi

            QPKGs.IsInstalled.Add "$package"

            [[ $($GETCFG_CMD "$package" Version -d unknown -f /etc/config/qpkg.conf) != "${QPKG_VERSION[$index]}" ]] && QPKGs.ScUpgradable.Add "$package"

            if [[ $($GETCFG_CMD "$package" Enable -u -f /etc/config/qpkg.conf) = 'TRUE' ]]; then
                QPKGs.IsEnabled.Add "$package"
                QPKGs.IsStarted.Add "$package"
            elif [[ $($GETCFG_CMD "$package" Enable -u -f /etc/config/qpkg.conf) = 'FALSE' ]]; then
                QPKGs.IsNtEnabled.Add "$package"
                QPKGs.IsNtStarted.Add "$package"
            fi

            if [[ -e /var/run/$package.last.operation ]]; then
                case $(</var/run/$package.last.operation) in
                    starting)
                        QPKGs.IsStarted.Remove "$package"
                        QPKGs.IsNtStarted.Remove "$package"
                        QPKGs.IsStarting.Add "$package"
                        ;;
                    restarting)
                        QPKGs.IsStarted.Remove "$package"
                        QPKGs.IsNtStarted.Remove "$package"
                        QPKGs.IsRestarting.Add "$package"
                        ;;
                    stopping)
                        QPKGs.IsStarted.Remove "$package"
                        QPKGs.IsNtStarted.Remove "$package"
                        QPKGs.IsStopping.Add "$package"
                        ;;
                    failed)
                        QPKGs.IsOk.Remove "$package"
                        QPKGs.IsNtOk.Add "$package"
                        ;;
                    ok)
                        QPKGs.IsNtOk.Remove "$package"
                        QPKGs.IsOk.Add "$package"
                esac
            else
                QPKGs.IsUnknown.Add "$package"
            fi

            if ${QPKG_SUPPORTS_BACKUP[$index]}; then
                if [[ -e $BACKUP_PATH/$package.config.tar.gz ]]; then
                    QPKGs.IsBackedUp.Add "$package"
                else
                    QPKGs.IsNtBackedUp.Add "$package"
                fi
            fi
        else
            QPKGs.IsNtInstalled.Add "$package"

            if [[ -n ${QPKG_ABBRVS[$index]} ]]; then
                if [[ ${QPKG_ARCH[$index]} = 'all' || ${QPKG_ARCH[$index]} = "$NAS_QPKG_ARCH" ]]; then
                    if [[ ${QPKG_MIN_RAM_KB[$index]} = any || $NAS_RAM_KB -ge ${QPKG_MIN_RAM_KB[$index]} ]]; then
                        QPKGs.ScInstallable.Add "$package"
                    fi
                fi
            fi

            if ${QPKG_SUPPORTS_BACKUP[$index]}; then
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

    # Builds a list of QPKGs that do and don't support 'backup' and 'restore' actions

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
    # these packages also do and don't support 'clean' actions

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

QPKGs.Repos.Show()
    {

    local tier=''
    local -i index=0
    local current_package_name=''
    local package_repo=''
    local package_repo_formatted=''
    local maxcols=$(CalculateMaximumRepoColumnsToDisplay)

    QPKGs.States.Build
    DisplayLineSpaceIfNoneAlready

    for tier in Standalone Dependent; do
        DisplayAsHelpTitlePackageNameRepo "$tier packages" 'repository'

        for current_package_name in $(QPKGs.Sc$tier.Array); do
            package_repo=''

            if ! QPKG.URL "$current_package_name" &>/dev/null; then
                DisplayAsHelpPackageNameRepo "$current_package_name" 'not installable: no arch'
            elif ! QPKG.MinRAM "$current_package_name" &>/dev/null; then
                DisplayAsHelpPackageNameRepo "$current_package_name" 'not installable: low RAM'
            elif QPKGs.IsNtInstalled.Exist "$current_package_name"; then
                DisplayAsHelpPackageNameRepo "$current_package_name" 'not installed'
            else
                package_repo=$(QPKG.Repo "$current_package_name")

                if [[ $package_repo = "$PROJECT_NAME" ]]; then
                    package_repo_formatted=$(ColourTextBrightGreen "$package_repo")
                else
                    package_repo_formatted=$(ColourTextBrightOrange "$package_repo")
                fi

                DisplayAsHelpPackageNameRepo "$current_package_name" "$package_repo_formatted"
            fi
        done

        Display; Self.LineSpace.Set
    done

    QPKGs.Actions.List
    QPKGs.States.List

    return 0

    }

QPKGs.Statuses.Show()
    {

    local tier=''
    local -a package_status_notes=()
    local -i index=0
    local current_package_name=''
    local package_name=''
    local package_status=''
    local package_version=''
    local maxcols=$(CalculateMaximumStatusColumnsToDisplay)

    QPKGs.States.Build
    DisplayLineSpaceIfNoneAlready

    for tier in Standalone Dependent; do
        DisplayAsHelpTitlePackageNameVersionStatus "$tier packages" 'package statuses (last result)' 'QPKG version' 'installation path'

        for current_package_name in $(QPKGs.Sc$tier.Array); do
            package_name=''
            package_status=''
            package_version=''
            package_status_notes=()

            if ! QPKG.URL "$current_package_name" &>/dev/null; then
                DisplayAsHelpPackageNameVersionStatus "$current_package_name" 'not installable: no arch'
            elif ! QPKG.MinRAM "$current_package_name" &>/dev/null; then
                DisplayAsHelpPackageNameVersionStatus "$current_package_name" 'not installable: low RAM'
            elif QPKGs.IsNtInstalled.Exist "$current_package_name"; then
                DisplayAsHelpPackageNameVersionStatus "$current_package_name" 'not installed' "$(QPKG.Available.Version "$current_package_name")"
            else
                if [[ $maxcols -eq 1 ]]; then
                    if QPKGs.IsMissing.Exist "$current_package_name"; then
                        package_name=$(ColourTextBrightRedBlink "$current_package_name")
                    elif QPKGs.IsEnabled.Exist "$current_package_name"; then
                        package_name=$(ColourTextBrightGreen "$current_package_name")
                    elif QPKGs.IsNtEnabled.Exist "$current_package_name"; then
                        package_name=$(ColourTextBrightRed "$current_package_name")
                    fi

                    if QPKGs.IsStarting.Exist "$current_package_name"; then
                        package_name=$(ColourTextBrightOrange "$current_package_name")
                    elif QPKGs.IsStopping.Exist "$current_package_name"; then
                        package_name=$(ColourTextBrightOrange "$current_package_name")
                    elif QPKGs.IsRestarting.Exist "$current_package_name"; then
                        package_name=$(ColourTextBrightOrange "$current_package_name")
                    elif QPKGs.IsStarted.Exist "$current_package_name"; then
                        package_name=$(ColourTextBrightGreen "$current_package_name")
                    elif QPKGs.IsNtStarted.Exist "$current_package_name"; then
                        package_name=$(ColourTextBrightRed "$current_package_name")
                    fi
                else
                    [[ ! -e ${GNU_SED_CMD:-} ]] && Self.Boring.Set

                    if QPKGs.IsMissing.Exist "$current_package_name"; then
                        package_status_notes=($(ColourTextBrightRedBlink missing))
                    elif QPKGs.IsEnabled.Exist "$current_package_name"; then
                        package_status_notes+=($(ColourTextBrightGreen enabled))
                    elif QPKGs.IsNtEnabled.Exist "$current_package_name"; then
                        package_status_notes+=($(ColourTextBrightRed disabled))
                    fi

                    if QPKGs.IsStarting.Exist "$current_package_name"; then
                        package_status_notes+=($(ColourTextBrightOrange starting))
                    elif QPKGs.IsStopping.Exist "$current_package_name"; then
                        package_status_notes+=($(ColourTextBrightOrange stopping))
                    elif QPKGs.IsRestarting.Exist "$current_package_name"; then
                        package_status_notes+=($(ColourTextBrightOrange restarting))
                    elif QPKGs.IsStarted.Exist "$current_package_name"; then
                        package_status_notes+=($(ColourTextBrightGreen started))
                    elif QPKGs.IsNtStarted.Exist "$current_package_name"; then
                        package_status_notes+=($(ColourTextBrightRed stopped))
                    fi

                    if QPKGs.IsNtOk.Exist "$current_package_name"; then
                        package_status_notes+=("($(ColourTextBrightRed failed))")
                    elif QPKGs.IsOk.Exist "$current_package_name"; then
                        package_status_notes+=("($(ColourTextBrightGreen ok))")
                    elif QPKGs.IsUnknown.Exist "$current_package_name"; then
                        package_status_notes+=("($(ColourTextBrightOrange unknown))")
                    fi

                    if QPKGs.ScUpgradable.Exist "$current_package_name"; then
                        package_version="$(QPKG.Local.Version "$current_package_name") $(ColourTextBrightOrange "($(QPKG.Available.Version "$current_package_name"))")"
                        package_status_notes+=($(ColourTextBrightOrange upgradable))
                    else
                        package_version=$(QPKG.Available.Version "$current_package_name")
                    fi

                    [[ ! -e ${GNU_SED_CMD:-} ]] && Self.Boring.UnSet

                    for ((index=0; index<=((${#package_status_notes[@]} - 1)); index++)); do
                        package_status+=${package_status_notes[$index]}

                        [[ $((index + 2)) -le ${#package_status_notes[@]} ]] && package_status+=', '
                    done

                    package_name=$current_package_name
                fi

                DisplayAsHelpPackageNameVersionStatus "$package_name" "$package_status" "$package_version" "$(QPKG.InstallationPath "$current_package_name")"
            fi
        done

        Display; Self.LineSpace.Set
    done

    QPKGs.Actions.List
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

QPKGs.IsNtStarted.Show()
    {

    local package=''
    QPKGs.States.Build
    DisableDebugToArchiveAndFile

    for package in $(QPKGs.IsNtStarted.Array); do
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

MarkActionAsDone()
    {

    # move specified package name from 'To' action array into associated 'Ok' array

    # input:
    #   $1 = package name
    #   $2 = action

    QPKGs.AcTo"$(Capitalise "$2")".Remove "$1"
    QPKGs.AcOk"$(Capitalise "$2")".Add "$1"

    return 0

    }

MarkActionAsError()
    {

    # move specified package name from 'To' action array into associated 'Er' array

    # input:
    #   $1 = package name
    #   $2 = action
    #   $3 = reason (optional)

    local message="failing request to $2 $(FormatAsPackageName "$1")"

    [[ -n ${3:-} ]] && message+=" as $3"
    DebugAsError "$message" >&2
    QPKGs.AcTo"$(Capitalise "$2")".Remove "$1"
    QPKGs.AcEr"$(Capitalise "$2")".Add "$1"

    return 0

    }

MarkActionAsSkipped()
    {

    # move specified package name from 'To' action array into associated 'Sk' array

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

    QPKGs.AcTo"$(Capitalise "$3")".Remove "$2"
    QPKGs.AcSk"$(Capitalise "$3")".Add "$2"

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

MarkStateAsEnabled()
    {

    QPKGs.IsNtEnabled.Remove "$1"
    QPKGs.IsEnabled.Add "$1"

    }

MarkStateAsDisabled()
    {

    QPKGs.IsEnabled.Remove "$1"
    QPKGs.IsNtEnabled.Add "$1"

    }

MarkStateAsStarted()
    {

    QPKGs.IsStarting.Remove "$1"
    QPKGs.IsStarted.Add "$1"
    QPKGs.IsStopping.Remove "$1"
    QPKGs.IsNtStarted.Remove "$1"
    QPKGs.IsRestarting.Remove "$1"

    }

MarkStateAsStopped()
    {

    QPKGs.IsStarting.Remove "$1"
    QPKGs.IsStarted.Remove "$1"
    QPKGs.IsStopping.Remove "$1"
    QPKGs.IsNtStarted.Add "$1"
    QPKGs.IsRestarting.Remove "$1"

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

GetCPUInfo()
    {

    # QTS 4.5.1 & BusyBox 1.01 don't support '-m' option for 'grep', so extract first mention the hard way with 'head'

    if $GREP_CMD -q '^model name' /proc/cpuinfo; then
        $GREP_CMD '^model name' /proc/cpuinfo | $HEAD_CMD -n1 | $SED_CMD 's|^.*: ||'
    elif $GREP_CMD -q '^Processor name' /proc/cpuinfo; then
        $GREP_CMD '^Processor name' /proc/cpuinfo | $HEAD_CMD -n1 | $SED_CMD 's|^.*: ||'
    else
        echo unknown
        return 1
    fi

    return 0

    }

GetArch()
    {

    $UNAME_CMD -m

    }

GetKernel()
    {

    $UNAME_CMD -r

    }

GetPlatform()
    {

    $GETCFG_CMD '' Platform -d unknown -f /etc/platform.conf

    }

GetDefaultVolume()
    {

    $GETCFG_CMD SHARE_DEF defVolMP -f /etc/config/def_share.info

    }

IsAllowUnsignedPackages()
    {

    [[ $($GETCFG_CMD 'QPKG Management' Ignore_Cert) = TRUE ]]

    }

GetUptime()
    {

    raw=$(</proc/uptime)
    FormatSecsToHoursMinutesSecs "${raw%%.*}"

    }

GetTimeInShell()
    {

    local duration=0

    if [[ -n ${LOADER_SCRIPT_PPID:-} ]]; then
        duration=$(ps -o pid,etime | $GREP_CMD $LOADER_SCRIPT_PPID | $HEAD_CMD -n1)
    fi

    FormatLongMinutesSecs "${duration:6}"

    }

GetSysLoadAverages()
    {

    $UPTIME_CMD | $SED_CMD 's|.*load average: ||' | $AWK_CMD -F', ' '{print "1m:"$1", 5m:"$2", 15m:"$3}'

    }

GetInstalledRAM()
    {

    $GREP_CMD MemTotal /proc/meminfo | cut -f2 -d':' | $SED_CMD 's|kB||;s| ||g'

    }

GetFirmwareVersion()
    {

    $GETCFG_CMD System Version -f /etc/config/uLinux.conf

    }

GetFirmwareBuild()
    {

    $GETCFG_CMD System Number -f /etc/config/uLinux.conf

    }

GetFirmwareDate()
    {

    $GETCFG_CMD System 'Build Number' -f /etc/config/uLinux.conf

    }

GetQPKGArch()
    {

    # Decide which package arch is suitable for this NAS

    case $NAS_ARCH in
        x86_64)
            [[ ${NAS_FIRMWARE_VER//.} -ge 430 ]] && echo x64 || echo x86
            ;;
        i686|x86)
            echo x86
            ;;
        armv5tel)
            echo x19
            ;;
        armv7l)
            case $NAS_PLATFORM in
                ARM_MS)
                    echo x31
                    ;;
                ARM_AL)
                    echo x41
                    ;;
                *)
                    echo none
            esac
            ;;
        aarch64)
            echo a64
            ;;
        *)
            echo none
    esac

    }

GetEntwareType()
    {

    if QPKG.IsInstalled Entware; then
        if [[ -e /opt/etc/passwd ]]; then
            if [[ -L /opt/etc/passwd ]]; then
                echo std
            else
                echo alt
            fi
        else
            echo none
        fi
    fi

    }

Self.Error.Set()
    {

    [[ $(type -t QPKGs.SkProc.Init) = function ]] && QPKGs.SkProc.Set
    Self.Error.IsSet && return
    _script_error_flag_=true
    DebugVar _script_error_flag_

    }

Self.Error.IsSet()
    {

    [[ ${_script_error_flag_:-} = true ]]

    }

Self.Error.IsNt()
    {

    [[ ${_script_error_flag_:-} != true ]]

    }

ShowSummary()
    {

    local state=''
    local action=''

    for state in "${PACKAGE_STATES[@]}"; do
        for action in "${PACKAGE_ACTIONS[@]}"; do
            QPKGs.Ac${action}.Is${state}.IsSet && QPKGs.AcOk${action}.IsNone && ShowAsDone "no QPKGs were $(tr 'A-Z' 'a-z' <<< "$state")"
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

    Self.Debug.ToArchive.UnSet
    Self.Debug.ToFile.UnSet

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

    Self.Error.IsSet && return
    DebugFuncEntry

    local -r PACKAGE_NAME=${1:?no package name supplied}
    local -i result_code=0
    local -r REMOTE_URL=$(QPKG.URL "$PACKAGE_NAME")
    local -r REMOTE_FILENAME=$($BASENAME_CMD "$REMOTE_URL")
    local -r REMOTE_MD5=$(QPKG.MD5 "$PACKAGE_NAME")
    local -r LOCAL_PATHFILE=$QPKG_DL_PATH/$REMOTE_FILENAME
    local -r LOCAL_FILENAME=$($BASENAME_CMD "$LOCAL_PATHFILE")
    local -r LOG_PATHFILE=$LOGS_PATH/$LOCAL_FILENAME.$DOWNLOAD_LOG_FILE
    local action=download

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
        MarkActionAsSkipped hide "$PACKAGE_NAME" "$action"
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
                QPKGs.AcOkDownload.Add "$PACKAGE_NAME"
            else
                DebugAsError "downloaded package $(FormatAsFileName "$LOCAL_PATHFILE") checksum incorrect"
                QPKGs.AcErDownload.Add "$PACKAGE_NAME"
                result_code=1
            fi
        else
            DebugAsError "$action failed $(FormatAsFileName "$PACKAGE_NAME") $(FormatAsExitcode $result_code)"
            QPKGs.AcErDownload.Add "$PACKAGE_NAME"
            result_code=1    # remap to 1 (last time I checked, 'curl' had 92 return codes)
        fi
    fi

    QPKGs.AcToDownload.Remove "$PACKAGE_NAME"
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

    Self.Error.IsSet && return
    QPKGs.SkProc.IsSet && return
    DebugFuncEntry

    local -r PACKAGE_NAME=${1:?no package name supplied}
    local -i result_code=0
    local action=install

    if QPKGs.IsInstalled.Exist "$PACKAGE_NAME"; then
        MarkActionAsSkipped show "$PACKAGE_NAME" "$action" "it's already installed - use 'reinstall' instead"
        DebugFuncExit 2; return
    fi

    if ! QPKG.URL "$PACKAGE_NAME" &>/dev/null; then
        MarkActionAsSkipped show "$PACKAGE_NAME" "$action" 'this NAS has an unsupported arch'
        DebugFuncExit 2; return
    fi

    if ! QPKG.MinRAM "$PACKAGE_NAME" &>/dev/null; then
        MarkActionAsSkipped show "$PACKAGE_NAME" "$action" 'this NAS has insufficient RAM'
        DebugFuncExit 2; return
    fi

    local local_pathfile=$(QPKG.PathFilename "$PACKAGE_NAME")

    if [[ ${local_pathfile##*.} = zip ]]; then
        $UNZIP_CMD -nq "$local_pathfile" -d "$QPKG_DL_PATH"
        local_pathfile=${local_pathfile%.*}
    fi

    if [[ -z $local_pathfile ]]; then
        MarkActionAsSkipped show "$PACKAGE_NAME" "$action" 'no local file found for processing: this error should be reported'
        DebugFuncExit 2; return
    fi

    if [[ $PACKAGE_NAME = Entware ]] && ! QPKGs.IsInstalled.Exist Entware && QPKGs.AcToInstall.Exist Entware; then
        local -r OPT_PATH=/opt
        local -r OPT_BACKUP_PATH=/opt.orig

        if [[ -d $OPT_PATH && ! -L $OPT_PATH && ! -e $OPT_BACKUP_PATH ]]; then
            DebugAsProc 'backup original /opt'
            mv "$OPT_PATH" "$OPT_BACKUP_PATH"
            DebugAsDone 'complete'
        fi
    fi

    local -r TARGET_FILE=$($BASENAME_CMD "$local_pathfile")
    local -r LOG_PATHFILE=$LOGS_PATH/$TARGET_FILE.$INSTALL_LOG_FILE
    local target_path=''

    DebugAsProc "installing $(FormatAsPackageName "$PACKAGE_NAME")"
    [[ ${QPKGs_were_installed_name[*]:-} == *"$PACKAGE_NAME"* ]] && target_path="QINSTALL_PATH=$(QPKG.OriginalPath "$PACKAGE_NAME") "
    RunAndLog "${target_path}$SH_CMD $local_pathfile" "$LOG_PATHFILE" log:failure-only 10
    result_code=$?

    if [[ $result_code -eq 0 || $result_code -eq 10 ]]; then
        DebugAsDone "installed $(FormatAsPackageName "$PACKAGE_NAME")"
        QPKG.StoreServiceStatus "$PACKAGE_NAME"
        MarkActionAsDone "$PACKAGE_NAME" "$action"
        MarkStateAsInstalled "$PACKAGE_NAME"

        if QPKG.IsStarted "$PACKAGE_NAME"; then
            MarkStateAsStarted "$PACKAGE_NAME"
        else
            MarkStateAsStopped "$PACKAGE_NAME"
        fi

        if [[ $PACKAGE_NAME = Entware ]]; then
            ModPathToEntware
            PatchEntwareService

            if QPKGs.AcOkInstall.Exist Entware; then
                # copy all files from original [/opt] into new [/opt]
                if [[ -L ${OPT_PATH:-} && -d ${OPT_BACKUP_PATH:-} ]]; then
                    DebugAsProc 'restoring original /opt'
                    mv "$OPT_BACKUP_PATH"/* "$OPT_PATH" && rm -rf "$OPT_BACKUP_PATH"
                    DebugAsDone 'complete'
                fi

                # add extra package(s) needed immediately
                DebugAsProc 'installing standalone IPKGs'
                RunAndLog "$OPKG_CMD install --force-overwrite $BASE_IPKGS_INSTALL --cache $IPKG_CACHE_PATH --tmp-dir $IPKG_DL_PATH" "$LOGS_PATH/ipkgs.extra.$INSTALL_LOG_FILE" log:failure-only
                DebugAsDone 'installed standalone IPKGs'
            fi
        fi

        result_code=0    # remap to zero (0 or 10 from a QPKG install/reinstall/upgrade is OK)
    else
        DebugAsError "$action failed $(FormatAsFileName "$PACKAGE_NAME") $(FormatAsExitcode $result_code)"
        MarkActionAsError "$PACKAGE_NAME" "$action"
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

    Self.Error.IsSet && return
    QPKGs.SkProc.IsSet && return
    DebugFuncEntry

    local -r PACKAGE_NAME=${1:?no package name supplied}
    local -i result_code=0
    local action=reinstall

    if ! QPKGs.IsInstalled.Exist "$PACKAGE_NAME"; then
        MarkActionAsSkipped show "$PACKAGE_NAME" "$action" "it's not installed - use 'install' instead"
        DebugFuncExit 2; return
    fi

    if ! QPKG.URL "$PACKAGE_NAME" &>/dev/null; then
        MarkActionAsSkipped show "$PACKAGE_NAME" "$action" 'this NAS has an unsupported arch'
        DebugFuncExit 2; return
    fi

    if ! QPKG.MinRAM "$PACKAGE_NAME" &>/dev/null; then
        MarkActionAsSkipped show "$PACKAGE_NAME" "$action" 'this NAS has insufficient RAM'
        DebugFuncExit 2; return
    fi

    local local_pathfile=$(QPKG.PathFilename "$PACKAGE_NAME")

    if [[ ${local_pathfile##*.} = zip ]]; then
        $UNZIP_CMD -nq "$local_pathfile" -d "$QPKG_DL_PATH"
        local_pathfile=${local_pathfile%.*}
    fi

    if [[ -z $local_pathfile ]]; then
        MarkActionAsSkipped show "$PACKAGE_NAME" "$action" 'no local file found for processing: this error should be reported'
        DebugFuncExit 2; return
    fi

    local -r TARGET_FILE=$($BASENAME_CMD "$local_pathfile")
    local -r LOG_PATHFILE=$LOGS_PATH/$TARGET_FILE.$REINSTALL_LOG_FILE
    local target_path=''

    DebugAsProc "reinstalling $(FormatAsPackageName "$PACKAGE_NAME")"
    QPKG.IsInstalled "$PACKAGE_NAME" && target_path="QINSTALL_PATH=$($DIRNAME_CMD "$(QPKG.InstallationPath $PACKAGE_NAME)") "
    RunAndLog "${target_path}$SH_CMD $local_pathfile" "$LOG_PATHFILE" log:failure-only 10
    result_code=$?

    if [[ $result_code -eq 0 || $result_code -eq 10 ]]; then
        DebugAsDone "reinstalled $(FormatAsPackageName "$PACKAGE_NAME")"
        MarkActionAsDone "$PACKAGE_NAME" "$action"
        QPKG.StoreServiceStatus "$PACKAGE_NAME"

        if QPKG.IsStarted "$PACKAGE_NAME"; then
            MarkStateAsStarted "$PACKAGE_NAME"
        else
            MarkStateAsStopped "$PACKAGE_NAME"
        fi

        result_code=0    # remap to zero (0 or 10 from a QPKG install/reinstall/upgrade is OK)
    else
        DebugAsError "$action failed $(FormatAsFileName "$PACKAGE_NAME") $(FormatAsExitcode $result_code)"
        MarkActionAsError "$PACKAGE_NAME" "$action"
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

    Self.Error.IsSet && return
    QPKGs.SkProc.IsSet && return
    DebugFuncEntry

    local -r PACKAGE_NAME=${1:?no package name supplied}
    local -i result_code=0
    local action=upgrade

    if ! QPKGs.IsInstalled.Exist "$PACKAGE_NAME"; then
        MarkActionAsSkipped show "$PACKAGE_NAME" "$action" "it's not installed - use 'install' instead"
        DebugFuncExit 2; return
    fi

    if ! QPKG.URL "$PACKAGE_NAME" &>/dev/null; then
        MarkActionAsSkipped show "$PACKAGE_NAME" "$action" 'this NAS has an unsupported arch'
        DebugFuncExit 2; return
    fi

    if ! QPKG.MinRAM "$PACKAGE_NAME" &>/dev/null; then
        MarkActionAsSkipped show "$PACKAGE_NAME" "$action" 'this NAS has insufficient RAM'
        DebugFuncExit 2; return
    fi

    if ! QPKGs.ScUpgradable.Exist "$PACKAGE_NAME"; then
        MarkActionAsSkipped show "$PACKAGE_NAME" "$action" 'no new package is available'
        DebugFuncExit 2; return
    fi

    local local_pathfile=$(QPKG.PathFilename "$PACKAGE_NAME")

    if [[ ${local_pathfile##*.} = zip ]]; then
        $UNZIP_CMD -nq "$local_pathfile" -d "$QPKG_DL_PATH"
        local_pathfile=${local_pathfile%.*}
    fi

    if [[ -z $local_pathfile ]]; then
        MarkActionAsSkipped show "$PACKAGE_NAME" "$action" 'no local file found for processing: this error should be reported'
        DebugFuncExit 2; return
    fi

    local -r TARGET_FILE=$($BASENAME_CMD "$local_pathfile")
    local -r LOG_PATHFILE=$LOGS_PATH/$TARGET_FILE.$UPGRADE_LOG_FILE
    local previous_version=$(QPKG.Local.Version "$PACKAGE_NAME")
    local target_path=''

    DebugAsProc "upgrading $(FormatAsPackageName "$PACKAGE_NAME")"
    QPKG.IsInstalled "$PACKAGE_NAME" && target_path="QINSTALL_PATH=$($DIRNAME_CMD "$(QPKG.InstallationPath $PACKAGE_NAME)") "
    RunAndLog "${target_path}$SH_CMD $local_pathfile" "$LOG_PATHFILE" log:failure-only 10
    result_code=$?

    local current_version=$(QPKG.Local.Version "$PACKAGE_NAME")

    if [[ $result_code -eq 0 || $result_code -eq 10 ]]; then
        if [[ $current_version = "$previous_version" ]]; then
            DebugAsDone "upgraded $(FormatAsPackageName "$PACKAGE_NAME") and installed version is $current_version"
        else
            DebugAsDone "upgraded $(FormatAsPackageName "$PACKAGE_NAME") from $previous_version to $current_version"
        fi
        QPKG.StoreServiceStatus "$PACKAGE_NAME"
        QPKGs.ScUpgradable.Remove "$PACKAGE_NAME"
        MarkActionAsDone "$PACKAGE_NAME" "$action"

        if QPKG.IsStarted "$PACKAGE_NAME"; then
            MarkStateAsStarted "$PACKAGE_NAME"
        else
            MarkStateAsStopped "$PACKAGE_NAME"
        fi

        result_code=0    # remap to zero (0 or 10 from a QPKG install/reinstall/upgrade is OK)
    else
        DebugAsError "$action failed $(FormatAsFileName "$PACKAGE_NAME") $(FormatAsExitcode $result_code)"
        MarkActionAsError "$PACKAGE_NAME" "$action"
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

    Self.Error.IsSet && return
    DebugFuncEntry

    local -r PACKAGE_NAME=${1:?no package name supplied}
    local -i result_code=0
    local action=uninstall

    if QPKGs.IsNtInstalled.Exist "$PACKAGE_NAME"; then
        MarkActionAsSkipped show "$PACKAGE_NAME" "$action" "it's not installed"
        DebugFuncExit 2; return
    fi

    if [[ $PACKAGE_NAME = "$PROJECT_NAME" ]]; then
        MarkActionAsSkipped show "$PACKAGE_NAME" "$action" "it's needed here! 😉"
        DebugFuncExit 2; return
    fi

    local -r QPKG_UNINSTALLER_PATHFILE=$(QPKG.InstallationPath "$PACKAGE_NAME")/.uninstall.sh
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
            MarkActionAsDone "$PACKAGE_NAME" "$action"
            MarkStateAsNotInstalled "$PACKAGE_NAME"
            QPKGs.IsStarted.Remove "$PACKAGE_NAME"
        else
            DebugAsError "$action failed $(FormatAsFileName "$PACKAGE_NAME") $(FormatAsExitcode $result_code)"
            MarkActionAsError "$PACKAGE_NAME" "$action"
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
    local action=restart

    QPKG.ClearServiceStatus "$PACKAGE_NAME"

    if QPKGs.IsNtInstalled.Exist "$PACKAGE_NAME"; then
        MarkActionAsSkipped show "$PACKAGE_NAME" "$action" "it's not installed"
        DebugFuncExit 2; return
    fi

    if [[ $PACKAGE_NAME = "$PROJECT_NAME" ]]; then
        MarkActionAsSkipped show "$PACKAGE_NAME" "$action" "it's needed here! 😉"
        DebugFuncExit 2; return
    fi

    local -r PACKAGE_INIT_PATHFILE=$(QPKG.ServicePathFile "$PACKAGE_NAME")
    local -r LOG_PATHFILE=$LOGS_PATH/$PACKAGE_NAME.$RESTART_LOG_FILE

    QPKG.Enable "$PACKAGE_NAME"
    result_code=$?

    if [[ $result_code -eq 0 ]]; then
        DebugAsProc "restarting $(FormatAsPackageName "$PACKAGE_NAME")"
        RunAndLog "$SH_CMD $PACKAGE_INIT_PATHFILE $action" "$LOG_PATHFILE" log:failure-only
        result_code=$?
    fi

    if [[ $result_code -eq 0 ]]; then
        DebugAsDone "restarted $(FormatAsPackageName "$PACKAGE_NAME")"
        QPKG.StoreServiceStatus "$PACKAGE_NAME"
        MarkActionAsDone "$PACKAGE_NAME" "$action"
    else
        DebugAsError "$action failed $(FormatAsFileName "$PACKAGE_NAME") $(FormatAsExitcode $result_code)"
        MarkActionAsError "$PACKAGE_NAME" "$action"
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
    local action=start

    QPKG.ClearServiceStatus "$PACKAGE_NAME"

    if QPKGs.IsNtInstalled.Exist "$PACKAGE_NAME"; then
        MarkActionAsSkipped show "$PACKAGE_NAME" "$action" "it's not installed"
        DebugFuncExit 2; return
    fi

    if QPKGs.IsStarted.Exist "$PACKAGE_NAME"; then
        MarkActionAsSkipped show "$PACKAGE_NAME" "$action" "it's already started"
        DebugFuncExit 2; return
    fi

    local -r PACKAGE_INIT_PATHFILE=$(QPKG.ServicePathFile "$PACKAGE_NAME")
    local -r LOG_PATHFILE=$LOGS_PATH/$PACKAGE_NAME.$START_LOG_FILE

    QPKG.Enable "$PACKAGE_NAME"
    result_code=$?

    if [[ $result_code -eq 0 ]]; then
        DebugAsProc "starting $(FormatAsPackageName "$PACKAGE_NAME")"
        RunAndLog "$SH_CMD $PACKAGE_INIT_PATHFILE $action" "$LOG_PATHFILE" log:failure-only
        result_code=$?
    fi

    if [[ $result_code -eq 0 ]]; then
        DebugAsDone "started $(FormatAsPackageName "$PACKAGE_NAME")"
        QPKG.StoreServiceStatus "$PACKAGE_NAME"
        MarkActionAsDone "$PACKAGE_NAME" "$action"
        MarkStateAsStarted "$PACKAGE_NAME"
        [[ $PACKAGE_NAME = Entware ]] && ModPathToEntware
    else
        DebugAsError "$action failed $(FormatAsFileName "$PACKAGE_NAME") $(FormatAsExitcode $result_code)"
        MarkActionAsError "$PACKAGE_NAME" "$action"
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
    local action=stop

    QPKG.ClearServiceStatus "$PACKAGE_NAME"

    if QPKGs.IsNtInstalled.Exist "$PACKAGE_NAME"; then
        MarkActionAsSkipped show "$PACKAGE_NAME" "$action" "it's not installed"
        DebugFuncExit 2; return
    fi

    if QPKGs.IsNtStarted.Exist "$PACKAGE_NAME"; then
        MarkActionAsSkipped show "$PACKAGE_NAME" "$action" "it's already stopped"
        DebugFuncExit 2; return
    fi

    if [[ $PACKAGE_NAME = "$PROJECT_NAME" ]]; then
        MarkActionAsSkipped show "$PACKAGE_NAME" "$action" "it's needed here! 😉"
        DebugFuncExit 2; return
    fi

    local -r PACKAGE_INIT_PATHFILE=$(QPKG.ServicePathFile "$PACKAGE_NAME")
    local -r LOG_PATHFILE=$LOGS_PATH/$PACKAGE_NAME.$STOP_LOG_FILE

    DebugAsProc "stopping $(FormatAsPackageName "$PACKAGE_NAME")"
    RunAndLog "$SH_CMD $PACKAGE_INIT_PATHFILE $action" "$LOG_PATHFILE" log:failure-only
    result_code=$?

    if [[ $result_code -eq 0 ]]; then
        QPKG.Disable "$PACKAGE_NAME"
        result_code=$?
    fi

    if [[ $result_code -eq 0 ]]; then
        DebugAsDone "stopped $(FormatAsPackageName "$PACKAGE_NAME")"
        QPKG.StoreServiceStatus "$PACKAGE_NAME"
        MarkActionAsDone "$PACKAGE_NAME" "$action"
        MarkStateAsStopped "$PACKAGE_NAME"
    else
        DebugAsError "$action failed $(FormatAsFileName "$PACKAGE_NAME") $(FormatAsExitcode $result_code)"
        MarkActionAsError "$PACKAGE_NAME" "$action"
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
    local action=enable

    RunAndLog "/sbin/qpkg_service $action $PACKAGE_NAME" "$LOGS_PATH/$PACKAGE_NAME.$ENABLE_LOG_FILE" log:failure-only
    result_code=$?

    if [[ $result_code -eq 0 ]]; then
        MarkStateAsEnabled "$PACKAGE_NAME"
    else
        result_code=1    # remap to 1
    fi

    return $result_code

    }

QPKG.Disable()
    {

    # $1 = package name to disable

    local -r PACKAGE_NAME=${1:?no package name supplied}
    local -i result_code=0
    local action=disable

    RunAndLog "/sbin/qpkg_service $action $PACKAGE_NAME" "$LOGS_PATH/$PACKAGE_NAME.$DISABLE_LOG_FILE" log:failure-only
    result_code=$?

    if [[ $result_code -eq 0 ]]; then
        MarkStateAsDisabled "$PACKAGE_NAME"
    else
        result_code=1    # remap to 1
    fi

    return $result_code

    }

QPKG.Backup()
    {

    # calls the service script for the QPKG named in $1 and runs a backup action

    # input:
    #   $1 = QPKG name

    # output:
    #   $? = 0  : successful
    #   $? = 1  : failed
    #   $? = 2  : skipped (not backed-up: not already installed)

    DebugFuncEntry

    local -r PACKAGE_NAME=${1:?no package name supplied}
    local -i result_code=0
    local action=backup

    if ! QPKG.IsSupportBackup "$PACKAGE_NAME"; then
        MarkActionAsSkipped show "$PACKAGE_NAME" "$action" "it does not support backup"
        DebugFuncExit 2; return
    fi

    if QPKGs.IsNtInstalled.Exist "$PACKAGE_NAME"; then
        MarkActionAsSkipped show "$PACKAGE_NAME" "$action" "it's not installed"
        DebugFuncExit 2; return
    fi

    local -r PACKAGE_INIT_PATHFILE=$(QPKG.ServicePathFile "$PACKAGE_NAME")
    local -r LOG_PATHFILE=$LOGS_PATH/$PACKAGE_NAME.$BACKUP_LOG_FILE

    DebugAsProc "backing-up $(FormatAsPackageName "$PACKAGE_NAME") configuration"
    RunAndLog "$SH_CMD $PACKAGE_INIT_PATHFILE $action" "$LOG_PATHFILE" log:failure-only
    result_code=$?

    if [[ $result_code -eq 0 ]]; then
        DebugAsDone "backed-up $(FormatAsPackageName "$PACKAGE_NAME") configuration"
        MarkActionAsDone "$PACKAGE_NAME" "$action"
        QPKG.StoreServiceStatus "$PACKAGE_NAME"
        QPKGs.IsNtBackedUp.Remove "$PACKAGE_NAME"
        QPKGs.IsBackedUp.Add "$PACKAGE_NAME"
    else
        DebugAsError "$action failed $(FormatAsFileName "$PACKAGE_NAME") $(FormatAsExitcode $result_code)"
        MarkActionAsError "$PACKAGE_NAME" "$action"
        result_code=1    # remap to 1
    fi

    DebugFuncExit $result_code

    }

QPKG.Restore()
    {

    # calls the service script for the QPKG named in $1 and runs a restore action

    # input:
    #   $1 = QPKG name

    # output:
    #   $? = 0 if successful, 1 if failed

    DebugFuncEntry

    local -r PACKAGE_NAME=${1:?no package name supplied}
    local -i result_code=0
    local action=restore

    if ! QPKG.IsSupportBackup "$PACKAGE_NAME"; then
        MarkActionAsSkipped show "$PACKAGE_NAME" "$action" "it does not support backup"
        DebugFuncExit 2; return
    fi

    if QPKGs.IsNtInstalled.Exist "$PACKAGE_NAME"; then
        MarkActionAsSkipped show "$PACKAGE_NAME" "$action" "it's not installed"
        DebugFuncExit 2; return
    fi

    local -r PACKAGE_INIT_PATHFILE=$(QPKG.ServicePathFile "$PACKAGE_NAME")
    local -r LOG_PATHFILE=$LOGS_PATH/$PACKAGE_NAME.$RESTORE_LOG_FILE

    DebugAsProc "restoring $(FormatAsPackageName "$PACKAGE_NAME") configuration"
    RunAndLog "$SH_CMD $PACKAGE_INIT_PATHFILE $action" "$LOG_PATHFILE" log:failure-only
    result_code=$?

    if [[ $result_code -eq 0 ]]; then
        DebugAsDone "restored $(FormatAsPackageName "$PACKAGE_NAME") configuration"
        MarkActionAsDone "$PACKAGE_NAME" "$action"
        QPKG.StoreServiceStatus "$PACKAGE_NAME"
    else
        DebugAsError "$action failed $(FormatAsFileName "$PACKAGE_NAME") $(FormatAsExitcode $result_code)"
        MarkActionAsError "$PACKAGE_NAME" "$action"
    fi

    DebugFuncExit $result_code

    }

QPKG.Clean()
    {

    # calls the service script for the QPKG named in $1 and runs a clean action

    # input:
    #   $1 = QPKG name

    # output:
    #   $? = 0  : successful
    #   $? = 1  : failed
    #   $? = 2  : skipped (not already installed, does not support clean)

    DebugFuncEntry

    local -r PACKAGE_NAME=${1:?no package name supplied}
    local -i result_code=0
    local action=clean

    if ! QPKG.IsSupportUpdateOnRestart "$PACKAGE_NAME"; then
        MarkActionAsSkipped show "$PACKAGE_NAME" "$action" "it does not support cleaning"
        DebugFuncExit 2; return
    fi

    if QPKGs.IsNtInstalled.Exist "$PACKAGE_NAME"; then
        MarkActionAsSkipped show "$PACKAGE_NAME" "$action" "it's not installed"
        DebugFuncExit 2; return
    fi

    local -r PACKAGE_INIT_PATHFILE=$(QPKG.ServicePathFile "$PACKAGE_NAME")
    local -r LOG_PATHFILE=$LOGS_PATH/$PACKAGE_NAME.$CLEAN_LOG_FILE

    DebugAsProc "cleaning $(FormatAsPackageName "$PACKAGE_NAME")"
    RunAndLog "$SH_CMD $PACKAGE_INIT_PATHFILE $action" "$LOG_PATHFILE" log:failure-only
    result_code=$?

    if [[ $result_code -eq 0 ]]; then
        DebugAsDone "cleaned $(FormatAsPackageName "$PACKAGE_NAME")"
        MarkActionAsDone "$PACKAGE_NAME" "$action"
        QPKG.StoreServiceStatus "$PACKAGE_NAME"
        QPKGs.IsNtCleaned.Remove "$PACKAGE_NAME"
        QPKGs.IsCleaned.Add "$PACKAGE_NAME"
    else
        DebugAsError "$action failed $(FormatAsFileName "$PACKAGE_NAME") $(FormatAsExitcode $result_code)"
        MarkActionAsError "$PACKAGE_NAME" "$action"
        result_code=1    # remap to 1
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
    $SETCFG_CMD "$PACKAGE_NAME" Status complete -f /etc/config/qpkg.conf

    return 0

    }

QPKG.ClearServiceStatus()
    {

    # input:
    #   $1 = QPKG name

    [[ -e /var/run/${1:?no package name supplied}.last.operation ]] && rm /var/run/"${1:?no package name supplied}".last.operation

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
            DebugInfo "$(FormatAsPackageName "$PACKAGE_NAME") service action completed OK"
            ;;
        failed)
            if [[ -e /var/log/$PACKAGE_NAME.log ]]; then
                ShowAsFail "$(FormatAsPackageName "$PACKAGE_NAME") service action failed. Check $(FormatAsFileName "/var/log/$PACKAGE_NAME.log") for more information"
                AddFileToDebug /var/log/$PACKAGE_NAME.log
            else
                ShowAsFail "$(FormatAsPackageName "$PACKAGE_NAME") service action failed"
            fi
            ;;
        *)
            DebugAsWarn "$(FormatAsPackageName "$PACKAGE_NAME") service status is incorrect"
    esac

    return 0

    }

# QPKG capabilities

QPKG.InstallationPath()
    {

    # input:
    #   $1 = QPKG name

    # output:
    #   stdout = the installation path to this QPKG
    #   $? = 0 if found, !0 if not

    $GETCFG_CMD "${1:?no package name supplied}" Install_Path -f /etc/config/qpkg.conf

    }

QPKG.ServicePathFile()
    {

    # input:
    #   $1 = QPKG name

    # output:
    #   stdout = service script pathfile
    #   $? = 0 if found, !0 if not

    $GETCFG_CMD "${1:?no package name supplied}" Shell -d unknown -f /etc/config/qpkg.conf

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

    for index in "${!QPKG_NAME[@]}"; do
        package="${QPKG_NAME[$index]}"
        [[ $package = "$previous" ]] && continue || previous=$package

        if [[ $1 = "$package" ]]; then
            echo "${QPKG_VERSION[$index]}"
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

    $GETCFG_CMD "${1:?no package name supplied}" Version -d unknown -f /etc/config/qpkg.conf

    }

QPKG.Repo()
    {

    # Returns the presently assigned repository ID of an installed QPKG.

    # input:
    #   $1 = QPKG name

    # output:
    #   stdout = package store ID
    #   $? = 0 if found, !0 if not

    $GETCFG_CMD "${1:?no package name supplied}" store -d "$PROJECT_NAME" -f /etc/config/qpkg.conf

    }

QPKG.IsSupportBackup()
    {

    # does this QPKG support 'backup' and 'restore' actions?

    # input:
    #   $1 = QPKG name

    # output:
    #   $? = 0 if true, 1 if false

    local -i index=0

    for index in "${!QPKG_NAME[@]}"; do
        if [[ ${QPKG_NAME[$index]} = "${1:?no package name supplied}" ]]; then
            if ${QPKG_SUPPORTS_BACKUP[$index]}; then
                return 0
            else
                break
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

    for index in "${!QPKG_NAME[@]}"; do
        if [[ ${QPKG_NAME[$index]} = "${1:?no package name supplied}" ]]; then
            if ${QPKG_RESTART_TO_UPDATE[$index]}; then
                return 0
            else
                break
            fi
        fi
    done

    return 1

    }

QPKG.OriginalPath()
    {

    # input:
    #   $1 = QPKG name

    # output:
    #   $? = 0 if successful, 1 if failed
    #   stdout = the original installation path of this QPKG (even if it was migrated to another volume)

    local -i index=0

    if [[ ${#QPKGs_were_installed_name[@]} -gt 0 ]]; then
        for index in "${!QPKGs_were_installed_name[@]}"; do
            if [[ ${QPKGs_were_installed_name[$index]} = "${1:?no package name supplied}" ]]; then
                echo "${QPKGs_were_installed_path[$index]}"
                return 0
            fi
        done
    fi

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

    for index in "${!QPKG_NAME[@]}"; do
        if [[ ${QPKG_NAME[$index]} = "${1:?no package name supplied}" ]]; then
            echo "${QPKG_ABBRVS[$index]}"
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

    for package_index in "${!QPKG_NAME[@]}"; do
        abbs=(${QPKG_ABBRVS[$package_index]})

        for abb_index in "${!abbs[@]}"; do
            if [[ ${abbs[$abb_index]} = "$1" ]]; then
                Display "${QPKG_NAME[$package_index]}"
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

    local -r URL=$(QPKG.URL "${1:?no package name supplied}")

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

    for index in "${!QPKG_NAME[@]}"; do
        if [[ ${QPKG_NAME[$index]} = "${1:?no package name supplied}" ]] && [[ ${QPKG_ARCH[$index]} = all || ${QPKG_ARCH[$index]} = "$NAS_QPKG_ARCH" ]]; then
            echo "${QPKG_URL[$index]}"
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

    for index in "${!QPKG_NAME[@]}"; do
        if [[ ${QPKG_NAME[$index]} = "${1:?no package name supplied}" ]]; then
            echo "${QPKG_DESC[$index]}"
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

    for index in "${!QPKG_NAME[@]}"; do
        if [[ ${QPKG_NAME[$index]} = "${1:?no package name supplied}" ]] && [[ ${QPKG_ARCH[$index]} = all || ${QPKG_ARCH[$index]} = "$NAS_QPKG_ARCH" ]]; then
            echo "${QPKG_MD5[$index]}"
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

    for index in "${!QPKG_NAME[@]}"; do
        if [[ ${QPKG_NAME[$index]} = "${1:?no package name supplied}" ]] && [[ ${QPKG_MIN_RAM_KB[$index]} = any || $NAS_RAM_KB -ge ${QPKG_MIN_RAM_KB[$index]} ]]; then
            echo "${QPKG_MIN_RAM_KB[$index]}"
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

    for index in "${!QPKG_NAME[@]}"; do
        if [[ ${QPKG_NAME[$index]} = "${1:?no package name supplied}" ]] && [[ ${QPKG_ARCH[$index]} = all || ${QPKG_ARCH[$index]} = "$NAS_QPKG_ARCH" ]]; then
            if [[ ${QPKG_DEPENDS_ON[$index]} != none ]]; then
                echo "${QPKG_DEPENDS_ON[$index]}"
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
        for index in "${!QPKG_NAME[@]}"; do
            if [[ ${QPKG_DEPENDS_ON[$index]} == *"${1:?no package name supplied}"* ]]; then
                [[ ${acc[*]:-} != "${QPKG_NAME[$index]}" ]] && acc+=(${QPKG_NAME[$index]})
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

    [[ $($GETCFG_CMD "${1:?no package name supplied}" Enable -u -f /etc/config/qpkg.conf) = 'TRUE' ]]

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
        ShowAsError "unable to create ${2:?empty} path $(FormatAsFileName "$1") $(FormatAsExitcode $result_code)"
        [[ $(type -t Self.SuggestIssue.Init) = function ]] && Self.SuggestIssue.Set
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

    if Self.Debug.ToScreen.IsSet; then
        eval $1 > >($TEE_CMD "$msgs") 2>&1   # NOTE: 'tee' buffers stdout here
        result_code=$?
    else
        eval $1 > "$msgs" 2>&1
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

    tr ' ' '\n' <<< "${1:-}" | $SORT_CMD | /bin/uniq | tr '\n' ' ' | $SED_CMD 's|^[[:blank:]]*||;s|[[:blank:]]*$||'

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

Capitalise()
    {

    echo "$(tr 'a-z' 'A-Z' <<< "${1:0:1}")${1:1}"

    }

FormatAsThousands()
    {

    printf "%'.f" "$1"

    }

FormatAsISOBytes()
    {

    $AWK_CMD 'BEGIN{ u[0]="B"; u[1]="kB"; u[2]="MB"; u[3]="GB"} { n = $1; i = 0; while(n > 1000) { i+=1; n= int((n/1000)+0.5) } print n u[i] } ' <<< "$1"

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

    echo "${2:-null}"
    echo '= ***** stdout/stderr is complete *****'

    }

DisplayLineSpaceIfNoneAlready()
    {

    if Self.LineSpace.IsNt && Self.Display.Clean.IsNt; then
        echo
        Self.LineSpace.Set
    else
        Self.LineSpace.UnSet
    fi

    }

readonly DEBUG_LOG_DATAWIDTH=100
readonly DEBUG_LOG_FIRST_COL_WIDTH=9
readonly DEBUG_LOG_SECOND_COL_WIDTH=17

DebugInfoMajorSeparator()
    {

    DebugInfo "$(eval printf '%0.s=' "{1..$DEBUG_LOG_DATAWIDTH}")"  # 'seq' is unavailable in QTS, so must resort to 'eval' trickery instead

    }

DebugInfoMinorSeparator()
    {

    DebugInfo "$(eval printf '%0.s-' "{1..$DEBUG_LOG_DATAWIDTH}")"  # 'seq' is unavailable in QTS, so must resort to 'eval' trickery instead

    }

DebugExtLogMinorSeparator()
    {

    DebugAsLog "$(eval printf '%0.s-' "{1..$DEBUG_LOG_DATAWIDTH}")" # 'seq' is unavailable in QTS, so must resort to 'eval' trickery instead

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

DebugQPKG()
    {

    DebugDetectedTabulated QPKG "${1:-}" "${2:-}"

    }

DebugQPKGInfo()
    {

    DebugInfoTabulated QPKG "${1:-}" "${2:-}"

    }

DebugQPKGWarning()
    {

    DebugWarningTabulated QPKG "${1:-}" "${2:-}"

    }

DebugQPKGError()
    {

    DebugErrorTabulated QPKG "${1:-}" "${2:-}"

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

DebugErrorTabulated()
    {

    if [[ -z $3 ]]; then                # if $3 is nothing, then assume only 2 fields are required
        DebugAsError "$(printf "%${DEBUG_LOG_FIRST_COL_WIDTH}s: %${DEBUG_LOG_SECOND_COL_WIDTH}s\n" "${1:-}" "${2:-}")"
    elif [[ $3 = ' ' ]]; then           # if $3 is only a whitespace then print $2 with trailing colon and 'none' as third field
        DebugAsError "$(printf "%${DEBUG_LOG_FIRST_COL_WIDTH}s: %${DEBUG_LOG_SECOND_COL_WIDTH}s: none\n" "${1:-}" "${2:-}")"
    elif [[ ${3: -1} = ' ' ]]; then     # if $3 has a trailing whitespace then print $3 without the trailing whitespace
        DebugAsError "$(printf "%${DEBUG_LOG_FIRST_COL_WIDTH}s: %${DEBUG_LOG_SECOND_COL_WIDTH}s: %-s\n" "${1:-}" "${2:-}" "$($SED_CMD 's| *$||' <<< "${3:-}")")"
    else
        DebugAsError "$(printf "%${DEBUG_LOG_FIRST_COL_WIDTH}s: %${DEBUG_LOG_SECOND_COL_WIDTH}s: %-s\n" "${1:-}" "${2:-}" "${3:-}")"
    fi

    }

DebugVar()
    {

    # had to split this onto its own line so Kate editor wouldn't choke when highlighting syntax
    local temp=${!1}

    DebugAsVar "\$$1 : '$temp'"

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
    eval "$var_safe_name=$(/bin/date +%s%N)"

    DebugThis "(>>) ${FUNCNAME[1]}"

    }

DebugFuncExit()
    {

    local var_name=${FUNCNAME[1]}_STARTSECONDS
    local var_safe_name=${var_name//[.-]/_}
    local diff_milliseconds=$((($($DATE_CMD +%s%N) - ${!var_safe_name}) / 1000000))
    local elapsed_time=''

    if [[ $diff_milliseconds -lt 30000 ]]; then
        elapsed_time="$(FormatAsThousands "$diff_milliseconds")ms"
    else
        elapsed_time=$(FormatSecsToHoursMinutesSecs "$((diff_milliseconds / 1000))")
    fi

    DebugThis "(<<) ${FUNCNAME[1]}|${1:-0}|$elapsed_time"

    return ${1:-0}

    }

DebugAsProc()
    {

    DebugThis "(--) ${1:-} ..."

    }

DebugAsDone()
    {

    DebugThis "(==) ${1:-}"

    }

DebugAsDetected()
    {

    DebugThis "(**) ${1:-}"

    }

DebugAsInfo()
    {

    DebugThis "(II) ${1:-}"

    }

DebugAsWarn()
    {

    DebugThis "(WW) ${1:-}"

    }

DebugAsError()
    {

    DebugThis "(EE) ${1:-}"

    }

DebugAsLog()
    {

    DebugThis "(LL) ${1:-}"

    }

DebugAsVar()
    {

    DebugThis "(vv) ${1:-}"

    }

DebugThis()
    {

    [[ $(type -t Self.Debug.ToScreen.Init) = function ]] && Self.Debug.ToScreen.IsSet && ShowAsDebug "${1:-}"
    WriteAsDebug "${1:-}"

    }

AddFileToDebug()
    {

    # Add the contents of specified pathfile $1 to the runtime log

    local linebuff=''
    local screen_debug=false

    DebugAsLog 'adding external log to main log ...'
    DebugExtLogMinorSeparator

    if Self.Debug.ToScreen.IsSet; then      # prevent external log contents appearing onscreen again - it's already been seen "live"
        screen_debug=true
        Self.Debug.ToScreen.UnSet
    fi

    DebugAsLog "$(FormatAsLogFilename "${1:?no filename supplied}")"

    while read -r linebuff; do
        DebugAsLog "$linebuff"
    done < "$1"

    [[ $screen_debug = true ]] && Self.Debug.ToScreen.Set
    DebugExtLogMinorSeparator

    }

ShowAsProcLong()
    {

    ShowAsProc "${1:-} (might take a while)" "${2:-}"

    }

ShowAsProc()
    {

    local suffix=''

    [[ -n ${2:-} ]] && suffix=" $2"

    SmartCR
    WriteToDisplayWait "$(ColourTextBrightOrange proc)" "${1:-} ...$suffix"
    WriteToLog proc "${1:-} ...$suffix"
    [[ $(type -t Self.Debug.ToScreen.Init) = function ]] && Self.Debug.ToScreen.IsSet && Display

    }

ShowAsDebug()
    {

    WriteToDisplayNew "$(ColourTextBlackOnCyan dbug)" "${1:-}"

    }

ShowAsInfo()
    {

    # note to user

    SmartCR
    WriteToDisplayNew "$(ColourTextBrightYellow note)" "${1:-}"
    WriteToLog note "${1:-}"

    }

ShowAsQuiz()
    {

    WriteToDisplayWait "$(ColourTextBrightOrangeBlink quiz)" "${1:-}: "
    WriteToLog quiz "${1:-}:"

    }

ShowAsQuizDone()
    {

    WriteToDisplayNew "$(ColourTextBrightOrange quiz)" "${1:-}"

    }

ShowAsDone()
    {

    # process completed OK

    SmartCR
    WriteToDisplayNew "$(ColourTextBrightGreen 'done')" "${1:-}"
    WriteToLog 'done' "$1"

    }

ShowAsWarn()
    {

    # warning only

    SmartCR

    local capitalised="$(Capitalise "${1:-}")"

    WriteToDisplayNew "$(ColourTextBrightOrange warn)" "$capitalised."
    WriteToLog warn "$capitalised."

    }

ShowAsAbort()
    {

    local capitalised="$(Capitalise "${1:-}")"

    WriteToDisplayNew "$(ColourTextBrightRed bort)" "$capitalised: aborting ..."
    WriteToLog bort "$capitalised: aborting"
    Self.Error.Set

    }

ShowAsFail()
    {

    # non-fatal error

    SmartCR

    local capitalised="$(Capitalise "${1:-}")"

    WriteToDisplayNew "$(ColourTextBrightRed fail)" "$capitalised."
    WriteToLog fail "$capitalised."

    }

ShowAsError()
    {

    # fatal error

    SmartCR

    local capitalised="$(Capitalise "${1:-}")"
    [[ ${1: -1} != ':' ]] && capitalised+='.'

    WriteToDisplayNew "$(ColourTextBrightRed derp)" "$capitalised"
    WriteToLog derp "$capitalised"
    Self.Error.Set

    }

ShowAsActionProgress()
    {

    # show QPKG actions progress as percent-complete and a fraction of the total

    # $1 = tier (optional)
    # $2 = package type: 'QPKG', 'IPKG', 'PIP', etc ...
    # $3 = pass count
    # $4 = fail count
    # $5 = total count
    # $6 = verb (present)
    # $7 = 'long' (optional)

    if [[ -n $1 && $1 != All ]]; then
        local tier=" $(tr 'A-Z' 'a-z' <<< "$1")"
    else
        local tier=''
    fi

    local -r PACKAGE_TYPE=${2:?empty}
    local -i pass_count=${3:-0}
    local -i fail_count=${4:-0}
    local -i total_count=${5:-0}
    local -r ACTION_PRESENT=${6:?empty}
    local -r DURATION=${7:-}
    local -i tweaked_passes=$((pass_count + 1))              # never show zero (e.g. 0/8)
    local -i tweaked_total=$((total_count - fail_count))     # auto-adjust upper limit to account for failures

    [[ $tweaked_total -eq 0 ]] && return 1              # no-point showing a fraction of zero

    if [[ $tweaked_passes -gt $tweaked_total ]]; then
        tweaked_passes=$((tweaked_total - fail_count))
        percent='100%'
    else
        percent="$((200 * (tweaked_passes) / (tweaked_total + 1) % 2 + 100 * (tweaked_passes) / (tweaked_total + 1)))%"
    fi

    if [[ $DURATION = long ]]; then
        ShowAsProcLong "$ACTION_PRESENT ${tweaked_total}${tier} ${PACKAGE_TYPE}$(Plural "$tweaked_total")" "$percent ($tweaked_passes/$tweaked_total)"
    else
        ShowAsProc "$ACTION_PRESENT ${tweaked_total}${tier} ${PACKAGE_TYPE}$(Plural "$tweaked_total")" "$percent ($tweaked_passes/$tweaked_total)"
    fi

    [[ $percent = '100%' ]] && sleep 1

    return 0

    }

ShowAsActionResult()
    {

    # $1 = tier (optional)
    # $2 = package type: 'QPKG', 'IPKG', 'PIP', etc ...
    # $3 = pass count
    # $4 = fail count
    # $5 = total count
    # $6 = verb (past)
    # $7 = 'long' (optional)

    if [[ -n $1 && $1 != All ]]; then
        local tier=" $(tr 'A-Z' 'a-z' <<< "$1")"
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

    WriteToLog dbug "${1:-}"

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
        previous_length=$((${#previous_msg} + 1))
        this_length=$((${#this_message} + 1))

        # jump to start of line, print new msg
        strbuffer=$(echo -en "\r$this_message ")

        # if new msg is shorter then add spaces to end to cover previous msg
        if [[ $this_length -lt $previous_length ]]; then
            blanking_length=$((this_length - previous_length))
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

    [[ $(type -t Self.Debug.ToFile.Init) = function ]] && Self.Debug.ToFile.IsNt && return
    [[ -n ${SESSION_ACTIVE_PATHFILE:-} ]] && printf "%-4s: %s\n" "$(StripANSI "${1:-}")" "$(StripANSI "${2:-}")" >> "$SESSION_ACTIVE_PATHFILE"

    }

ColourTextBrightGreen()
    {

    if [[ $(type -t Self.Boring.Init) = function ]] && Self.Boring.IsSet; then
        echo -n "${1:-}"
    else
        echo -en '\033[1;32m'"$(ColourReset "${1:-}")"
    fi

    }

ColourTextBrightYellow()
    {

    if [[ $(type -t Self.Boring.Init) = function ]] && Self.Boring.IsSet; then
        echo -n "${1:-}"
    else
        echo -en '\033[1;33m'"$(ColourReset "${1:-}")"
    fi

    }

ColourTextBrightOrange()
    {

    if [[ $(type -t Self.Boring.Init) = function ]] && Self.Boring.IsSet; then
        echo -n "${1:-}"
    else
        echo -en '\033[1;38;5;214m'"$(ColourReset "${1:-}")"
    fi

    }

ColourTextBrightOrangeBlink()
    {

    if [[ $(type -t Self.Boring.Init) = function ]] && Self.Boring.IsSet; then
        echo -n "${1:-}"
    else
        echo -en '\033[1;5;38;5;214m'"$(ColourReset "${1:-}")"
    fi

    }

ColourTextBrightRed()
    {

    if [[ $(type -t Self.Boring.Init) = function ]] && Self.Boring.IsSet; then
        echo -n "${1:-}"
    else
        echo -en '\033[1;31m'"$(ColourReset "${1:-}")"
    fi

    }

ColourTextBrightRedBlink()
    {

    if [[ $(type -t Self.Boring.Init) = function ]] && Self.Boring.IsSet; then
        echo -n "${1:-}"
    else
        echo -en '\033[1;5;31m'"$(ColourReset "${1:-}")"
    fi

    }

ColourTextUnderlinedCyan()
    {

    if [[ $(type -t Self.Boring.Init) = function ]] && Self.Boring.IsSet; then
        echo -n "${1:-}"
    else
        echo -en '\033[4;36m'"$(ColourReset "${1:-}")"
    fi

    }

ColourTextBlackOnCyan()
    {

    if [[ $(type -t Self.Boring.Init) = function ]] && Self.Boring.IsSet; then
        echo -n "${1:-}"
    else
        echo -en '\033[30;46m'"$(ColourReset "${1:-}")"
    fi

    }

ColourTextBrightWhite()
    {

    if [[ $(type -t Self.Boring.Init) = function ]] && Self.Boring.IsSet; then
        echo -n "${1:-}"
    else
        echo -en '\033[1;97m'"$(ColourReset "${1:-}")"
    fi

    }

ColourReset()
    {

    echo -en "${1:-}"'\033[0m'

    }

StripANSI()
    {

    # QTS 4.2.6 BusyBox 'sed' doesn't fully support extended regexes, so this only works with a real 'sed'

    if [[ -e ${GNU_SED_CMD:-} ]]; then
        $GNU_SED_CMD -r 's/\x1b\[[0-9;]*m//g' <<< "${1:-}"
    else
        echo "${1:-}"           # can't strip, so pass thru original message unaltered
    fi

    }

FormatSecsToHoursMinutesSecs()
    {

    # http://stackoverflow.com/questions/12199631/convert-seconds-to-hours-minutes-seconds

    # input:
    #   $1 = a time in seconds to convert to 'HHh:MMm:SSs'

    ((h=${1:-0} / 3600))
    ((m=(${1:-0} % 3600) / 60))
    ((s=${1:-0} % 60))

    printf "%01dh:%02dm:%02ds\n" "$h" "$m" "$s"

    }

FormatLongMinutesSecs()
    {

    # input:
    #   $1 = a time in long minutes and seconds to convert to 'MMMm:SSs'

    # separate minutes from seconds
    m=${1%%:*}
    s=${1#*:}

    # remove leading whitespace
    m=${m##* }
    s=${s##* }

    printf "%01dm:%02ds\n" "$((10#$m))" "$((10#$s))"

    }

CTRL_C_Captured()
    {

    RemoveDirSizeMonitorFlagFile

    exit

    }

Objects.Load()
    {

    # ensure 'objects' in the local work path is up-to-date, then source it

    DebugFuncEntry

    if [[ ! -e $PWD/dont.refresh.sherpa.objects ]]; then
        if [[ ! -e $OBJECTS_PATHFILE ]] || ! IsThisFileRecent "$OBJECTS_PATHFILE"; then
            ShowAsProc 'updating objects' >&2
            if $CURL_CMD${curl_insecure_arg:-} --silent --fail "$OBJECTS_ARCHIVE_URL" > "$OBJECTS_ARCHIVE_PATHFILE"; then
                /bin/tar --extract --gzip --file="$OBJECTS_ARCHIVE_PATHFILE" --directory="$WORK_PATH"
            fi
        fi
    fi

    if [[ ! -e $OBJECTS_PATHFILE ]]; then
        ShowAsAbort 'objects missing'
        DebugFuncExit 1; exit
    fi

    ShowAsProc 'loading objects' >&2
    . "$OBJECTS_PATHFILE"

    readonly OBJECTS_VER

    DebugFuncExit

    }

Packages.Load()
    {

    # ensure 'packages' in the local work path is up-to-date, then source it

    QPKGs.Loaded.IsSet && return
    DebugFuncEntry

    if [[ ! -e $PWD/dont.refresh.sherpa.packages ]]; then
        if [[ ! -e $PACKAGES_PATHFILE ]] || ! IsThisFileRecent "$PACKAGES_PATHFILE" 60; then
            ShowAsProc 'updating package list' >&2
            if $CURL_CMD${curl_insecure_arg:-} --silent --fail "$PACKAGES_ARCHIVE_URL" > "$PACKAGES_ARCHIVE_PATHFILE"; then
                /bin/tar --extract --gzip --file="$PACKAGES_ARCHIVE_PATHFILE" --directory="$WORK_PATH"
            fi
        fi
    fi

    if [[ ! -e $PACKAGES_PATHFILE ]]; then
        ShowAsAbort 'package list missing'
        DebugFuncExit 1; exit
    fi

    ShowAsProc 'loading package list' >&2
    . "$PACKAGES_PATHFILE"

    readonly PACKAGES_VER
    readonly BASE_QPKG_CONFLICTS_WITH
    readonly BASE_QPKG_WARNINGS
    readonly BASE_IPKGS_INSTALL
    readonly BASE_PIPS_INSTALL
    readonly MIN_PYTHON_VER
    readonly MIN_PERL_VER

    # package arrays are now full, so lock them
    readonly QPKG_NAME
        readonly QPKG_ARCH
        readonly QPKG_MIN_RAM_KB
        readonly QPKG_VERSION
        readonly QPKG_URL
        readonly QPKG_MD5
        readonly QPKG_DESC
        readonly QPKG_ABBRVS
        readonly QPKG_CONFLICTS_WITH
        readonly QPKG_DEPENDS_ON
        readonly QPKG_DEPENDED_UPON
        readonly QPKG_IPKGS_INSTALL
        readonly QPKG_SUPPORTS_BACKUP
        readonly QPKG_RESTART_TO_UPDATE

    QPKGs.Loaded.Set
    DebugScript version "packages: ${PACKAGES_VER:-unknown}"
    QPKGs.ScAll.Add "${QPKG_NAME[*]}"
    QPKGs.StandaloneDependent.Build
    DebugFuncExit

    }

Self.Init || exit
Self.Validate
Tiers.Process
Self.Results
Self.Error.IsNt
