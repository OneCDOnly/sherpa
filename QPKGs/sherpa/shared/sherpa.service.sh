#!/usr/bin/env bash
#
# sherpa.service.sh - (C)opyright 2020-2021 OneCD [one.cd.only@gmail.com]
#
# This is the service script for the sherpa mini-package-manager and is part of the 'sherpa' QPKG.
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

readonly PROJECT_NAME=sherpa
readonly PROJECT_PATH=$(/sbin/getcfg $PROJECT_NAME Install_Path -f /etc/config/qpkg.conf)
readonly REAL_LOG_PATHFILE=$PROJECT_PATH/logs/session.archive.log
readonly GUI_LOG_PATHFILE=/home/httpd/$PROJECT_NAME.debug.log
readonly REAL_LOADER_SCRIPT_PATHNAME=$PROJECT_PATH/$PROJECT_NAME.loader.sh
readonly APPARENT_LOADER_SCRIPT_PATHNAME=/usr/sbin/$PROJECT_NAME

[[ ! -e $REAL_LOG_PATHFILE ]] && /bin/touch "$REAL_LOG_PATHFILE"

case $1 in
    start)
        [[ ! -L $APPARENT_LOADER_SCRIPT_PATHNAME ]] && /bin/ln -s "$REAL_LOADER_SCRIPT_PATHNAME" "$APPARENT_LOADER_SCRIPT_PATHNAME"
        [[ ! -L $GUI_LOG_PATHFILE ]] && /bin/ln -s "$REAL_LOG_PATHFILE" "$GUI_LOG_PATHFILE"
        ;;
    stop)
        [[ -L $APPARENT_LOADER_SCRIPT_PATHNAME ]] && rm -f "$APPARENT_LOADER_SCRIPT_PATHNAME"
        [[ -L $GUI_LOG_PATHFILE ]] && rm -f "$GUI_LOG_PATHFILE"
        ;;
    restart)
        $0 stop
        $0 start
        ;;
    *)
        echo -e "\n Usage: $0 {start|stop|restart}\n"
        ;;
esac
