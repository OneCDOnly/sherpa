#!/usr/bin/env bash
#* Please don't edit this file directly, it was built/modified programmatically with the 'build-qpkgs.sh' script. (source: 'clamav.source')
#* clamav.sh
#* Copyright (C) 2017-2024 OneCD.
#* Contact:
#*   one.cd.only@gmail.com
#* Project:
#*	 https://git.io/sherpa
#* Forum:
#*	 https://forum.qnap.com/viewtopic.php?f=320&t=132373
#* Tested on:
#*	 GNU bash, version 3.2.57(2)-release (i686-pc-linux-gnu)
#*	 GNU bash, version 3.2.57(1)-release (aarch64-QNAP-linux-gnu)
#*	   Copyright (C) 2007 Free Software Foundation, Inc.
#*   ... and periodically on:
#*	 GNU bash, version 5.0.17(1)-release (aarch64-openwrt-linux-gnu)
#*	   Copyright (C) 2019 Free Software Foundation, Inc.
#* License:
#*   This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
#*	 This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY, without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#*	 You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/
readonly USER_ARGS_RAW=$*
readonly QPKG_NAME=ClamAV
readonly SERVICE_SCRIPT_VERSION='240307'
readonly SERVICE_SCRIPT_TYPE=4
InitService()
{
qpkg_backup_pathfile=undefined
install_pip_deps=true
qpkg_ini_file=undefined
qpkg_ini_pathfile=$QPKG_CONFIG_PATH/$qpkg_ini_file
qpkg_ini_default_pathfile=$qpkg_ini_pathfile.def
readonly TARGET_SERVICE_PATHFILE=/etc/init.d/antivirus.sh
readonly BACKUP_SERVICE_PATHFILE=$TARGET_SERVICE_PATHFILE.bak
}
StartQPKGCustom()
{
IsError && return
MakePaths
WaitForGit || { SetError;return 1 ;}
if [[ ! -e $BACKUP_SERVICE_PATHFILE ]];then
cp "$TARGET_SERVICE_PATHFILE" "$BACKUP_SERVICE_PATHFILE"
/bin/sed -i 's|/usr/local/bin/clamscan|/opt/sbin/clamscan|' "$TARGET_SERVICE_PATHFILE"
/bin/sed -i 's|/usr/local/bin/freshclam|/opt/sbin/freshclam|' "$TARGET_SERVICE_PATHFILE"
/bin/sed -i ':a;N;$!ba;s|/bin/sh -c "$AV_SCAN_PATH $DRY_RUN_OPTIONS --dryrun|#/bin/sh -c "$AV_SCAN_PATH $DRY_RUN_OPTIONS --dryrun|2' "$TARGET_SERVICE_PATHFILE"
/bin/sed -i ':a;N;$!ba;s|OPTIONS="$OPTIONS --countfile=/tmp/antivirous.job.$job_id.scanning"|OPTIONS="$OPTIONS --database=$ANTIVIRUS_CLAMAV"|2' "$TARGET_SERVICE_PATHFILE"
/bin/sed -i 's|$FRESHCLAM -u admin -l /tmp/.freshclam.log|$FRESHCLAM -u admin --config-file=$FRESHCLAM_CONFIG --datadir=$ANTIVIRUS_CLAMAV -l /tmp/.freshclam.log|' "$TARGET_SERVICE_PATHFILE"
eval "$TARGET_SERVICE_PATHFILE" restart &>/dev/null
fi
/bin/grep -q freshclam /etc/profile || echo "alias freshclam='/opt/sbin/freshclam -u admin --config-file=/etc/config/freshclam.conf --datadir=/share/$(/sbin/getcfg Public path -f /etc/config/smb.conf | cut -d '/' -f 3)/.antivirus/usr/share/clamav -l /tmp/.freshclam.log'" >> /etc/profile
DisplayCommitToLog 'start: OK'
return 0
}
StopQPKGCustom()
{
IsError && return
if [[ -e $BACKUP_SERVICE_PATHFILE ]];then
mv "$BACKUP_SERVICE_PATHFILE" "$TARGET_SERVICE_PATHFILE"
eval "$TARGET_SERVICE_PATHFILE" restart &>/dev/null
fi
/bin/sed -i '/freshclam/d' /etc/profile
DisplayCommitToLog 'stop: OK'
return 0
}
StatusQPKGCustom()
{
IsNotError || return
IsPackageActive && exit 0 || exit 1
}
library_path=$(/usr/bin/readlink "$0" 2>/dev/null)
[[ -z $library_path ]] && library_path=$0
readonly SERVICE_LIBRARY_PATHFILE=$(/usr/bin/dirname "$library_path")/service.lib
if [[ -e $SERVICE_LIBRARY_PATHFILE ]];then
. $SERVICE_LIBRARY_PATHFILE
else
printf '\033[1;31m%s\033[0m: %s\n' 'derp' "QPKG service function library not found, can't continue."
exit 1
fi
ProcessArgs
