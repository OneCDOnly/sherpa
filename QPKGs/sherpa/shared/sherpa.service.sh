#!/usr/bin/env bash
#
# sherpa.service.sh - (C)opyright 2020 OneCD [one.cd.only@gmail.com]
#
# This is the service script for the sherpa mini-package-manager and is part of the 'sherpa' QPKG.
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

Init()
    {

    readonly PROJECT_NAME=sherpa
    readonly CONFIG_PATHFILE=/etc/config/qpkg.conf

    # cherry-pick required binaries
    readonly LN_CMD=/bin/ln
    readonly TOUCH_CMD=/bin/touch

    readonly GETCFG_CMD=/sbin/getcfg

    [[ ! -e $CONFIG_PATHFILE ]] && { echo "file not found [$CONFIG_PATHFILE]"; exit 1 ;}

    local -r QPKG_PATH=$($GETCFG_CMD $PROJECT_NAME Install_Path -f $CONFIG_PATHFILE)
    readonly REAL_LOG_PATHFILE=$QPKG_PATH/$PROJECT_NAME.debug.log
    readonly GUI_LOG_PATHFILE=/home/httpd/$PROJECT_NAME.debug.log
    readonly REAL_LOADER_SCRIPT_PATHNAME=$QPKG_PATH/$PROJECT_NAME.loader.sh
    readonly APPARENT_LOADER_SCRIPT_PATHNAME=/usr/sbin/$PROJECT_NAME

    [[ ! -e $REAL_LOG_PATHFILE ]] && $TOUCH_CMD "$REAL_LOG_PATHFILE"

    }

Init

case $1 in
    start)
        [[ ! -L $APPARENT_LOADER_SCRIPT_PATHNAME ]] && $LN_CMD -s "$REAL_LOADER_SCRIPT_PATHNAME" "$APPARENT_LOADER_SCRIPT_PATHNAME"
        [[ ! -L $GUI_LOG_PATHFILE ]] && $LN_CMD -s "$REAL_LOG_PATHFILE" "$GUI_LOG_PATHFILE"
        ;;
    stop)
        [[ -L $APPARENT_LOADER_SCRIPT_PATHNAME ]] && rm -f "$APPARENT_LOADER_SCRIPT_PATHNAME"
        [[ -L $GUI_LOG_PATHFILE ]] && rm -f "$GUI_LOG_PATHFILE"
        ;;
    *)
        echo -e "\n Usage: $0 {start|stop}\n"
        ;;
esac
