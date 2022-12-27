#!/usr/bin/env bash

# sherpa.service.sh
#   Copyright (C) 2020-2022 OneCD [one.cd.only@gmail.com]

#   So, blame OneCD if it all goes horribly wrong. ;)

# Description:
#   This is the service script for the sherpa mini-package-manager and is part of the 'sherpa' QPKG.

# Project:
#   https://git.io/sherpa

# Forum:
#   https://forum.qnap.com/viewtopic.php?f=320&t=132373

# Tested on:
#   GNU bash, version 3.2.57(2)-release (i686-pc-linux-gnu)
#   GNU bash, version 3.2.57(1)-release (aarch64-QNAP-linux-gnu)
#   Copyright (C) 2007 Free Software Foundation, Inc.

# ... and periodically on:
#   GNU bash, version 5.0.17(1)-release (aarch64-openwrt-linux-gnu)
#   Copyright (C) 2019 Free Software Foundation, Inc.

# License:
#   This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

#   This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

#   You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/

Init()
    {

    local -r QPKG_PATH=$(/sbin/getcfg sherpa Install_Path -f /etc/config/qpkg.conf)
    readonly REAL_LOG_PATHFILE=$QPKG_PATH/logs/session.archive.log
    readonly GUI_LOG_PATHFILE=/home/httpd/sherpa.debug.log
    readonly REAL_LOADER_SCRIPT_PATHNAME=$QPKG_PATH/sherpa.loader.sh
    readonly APPARENT_LOADER_SCRIPT_PATHNAME=/usr/sbin/sherpa
    readonly SERVICE_STATUS_PATHFILE=/var/run/sherpa.last.operation

    [[ ! -d $(/usr/bin/dirname "$REAL_LOG_PATHFILE") ]] && mkdir -p $(/usr/bin/dirname "$REAL_LOG_PATHFILE")
    [[ ! -e $REAL_LOG_PATHFILE ]] && /bin/touch "$REAL_LOG_PATHFILE"

    }

SetServiceOperationResult()
    {

    # $1 = result of operation to recorded

    [[ -n $1 && -n $SERVICE_STATUS_PATHFILE ]] && echo "$1" > "$SERVICE_STATUS_PATHFILE"

    }

Init

case $1 in
    start)
        [[ ! -L $APPARENT_LOADER_SCRIPT_PATHNAME ]] && /bin/ln -s "$REAL_LOADER_SCRIPT_PATHNAME" "$APPARENT_LOADER_SCRIPT_PATHNAME"
        [[ ! -L $GUI_LOG_PATHFILE ]] && /bin/ln -s "$REAL_LOG_PATHFILE" "$GUI_LOG_PATHFILE"
        sherpa status >& /dev/null
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
esac

SetServiceOperationResult ok
exit
