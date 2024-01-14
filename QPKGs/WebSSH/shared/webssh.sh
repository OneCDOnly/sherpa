#!/usr/bin/env bash
#* Please don't edit this file directly, it was built/modified programmatically with the 'build-qpkgs.sh' script. (source: 'webssh.source')
#* webssh.sh
#* Copyright (C) 2017-2024 OneCD - one.cd.only@gmail.com
#*   So, blame OneCD if it all goes horribly wrong. ;)
#* Project:
#*	 https://git.io/sherpa
#* Forum:
#*	 https://forum.qnap.com/viewtopic.php?f=320&t=132373
#* Tested on:
#*	 GNU bash, version 3.2.57(2)-release (i686-pc-linux-gnu)
#*	 GNU bash, version 3.2.57(1)-release (aarch64-QNAP-linux-gnu)
#*	   Copyright (C) 2007 Free Software Foundation, Inc.
#* ... and periodically on:
#*	 GNU bash, version 5.0.17(1)-release (aarch64-openwrt-linux-gnu)
#*	   Copyright (C) 2019 Free Software Foundation, Inc.
#* License:
#*   This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
#*	 This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#*	 You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/
readonly USER_ARGS_RAW=$*
readonly QPKG_NAME=WebSSH
readonly SERVICE_SCRIPT_VERSION='240115'
readonly SERVICE_SCRIPT_TYPE=6
InitService()
{
app_version_cmd="/bin/grep '__version__ =' $app_version_pathfile | /bin/sed 's|^.*\"\(.*\)\"|\1|'"
run_daemon_in_screen_session=true
venv_python_pathfile=$venv_path/bin/python
daemon_pathfile=$venv_path/bin/wssh
daemon_launch_cmd="$venv_python_pathfile $daemon_pathfile --address='0.0.0.0' --port=8010 --encoding=850"
get_ui_listening_address_cmd='echo 0.0.0.0'
get_ui_port_cmd='echo 8010'
get_ui_port_secure_cmd='echo 0'
get_ui_port_secure_enabled_test_cmd='false'
source_git_branch=master
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
