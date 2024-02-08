#!/usr/bin/env bash
#* Please don't edit this file directly, it was built/modified programmatically with the 'build-qpkgs.sh' script. (source: 'osonarr.source')
#* osonarr.sh
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
#*	 This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#*	 You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/
readonly USER_ARGS_RAW=$*
readonly QPKG_NAME=OSonarr
readonly SERVICE_SCRIPT_VERSION='240206'
readonly SERVICE_SCRIPT_TYPE=5
InitService()
{
local_temp_path=$QPKG_PATH/tmp
daemon_pathfile=$qpkg_repo_path/Sonarr/Sonarr
daemon_launch_cmd="export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1 TMPDIR=$local_temp_path; $daemon_pathfile --nobrowser --data=$QPKG_CONFIG_PATH"
get_ui_listening_address_cmd='echo 0.0.0.0'
get_ui_port_cmd='grep "<Port>" $qpkg_ini_pathfile | sed "s/.*<Port>\(.*\)<\/Port>.*/\1/"'
get_ui_port_secure_cmd='grep "<SslPort>" $qpkg_ini_pathfile | sed "s/.*<SslPort>\(.*\)<\/SslPort>.*/\1/"'
get_ui_port_secure_enabled_test_cmd='[[ $(grep "<EnableSsl>" $qpkg_ini_pathfile | sed "s/.*<EnableSsl>\(.*\)<\/EnableSsl>.*/\1/") = True ]]'
qpkg_ini_file=config.xml
qpkg_ini_pathfile=$QPKG_CONFIG_PATH/$qpkg_ini_file
qpkg_ini_default_pathfile=$qpkg_ini_pathfile.def
remote_url='https://services.sonarr.tv/v1/download/main/latest?version=4&os=linux&'
remote_url+='arch=x64'
run_daemon_in_screen_session=true
}
library_path=$(/usr/bin/readlink "$0" 2>/dev/null)
[[ -z $library_path ]] && library_path=$0
readonly SERVICE_LIBRARY_PATHFILE=$(/usr/bin/dirname "$library_path")/service.lib
if [[ -e $SERVICE_LIBRARY_PATHFILE ]]; then
. $SERVICE_LIBRARY_PATHFILE
else
printf '\033[1;31m%s\033[0m: %s\n' 'derp' "QPKG service function library not found, can't continue."
exit 1
fi
ProcessArgs
