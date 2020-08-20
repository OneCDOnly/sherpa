#!/usr/bin/env bash
#
# sherpa.sh
#
# The launcher for the sherpa package manager, to install various media-management apps into QNAP NAS
#
# Copyright (C) 2017-2020 OneCD [one.cd.only@gmail.com]
#
# so, blame OneCD if it all goes horribly wrong. ;)
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

readonly SCRIPT_FILE=sherpa.sh
readonly SCRIPT_VERSION=200820c
readonly REMOTE_SCRIPT_FILE=__sherpa-main__.sh

if [[ ! -e /etc/init.d/functions ]]; then
    echo '! QTS functions missing (is this a QNAP NAS?): aborting ...'
    exit 1
fi

readonly CURL_CMD=/sbin/curl
readonly GETCFG_CMD=/sbin/getcfg
readonly ULINUX_PATHFILE=/etc/config/uLinux.conf
readonly REMOTE_REPO_URL=https://raw.githubusercontent.com/OneCDOnly/sherpa/master
readonly DOWNLOAD_PATH=/dev/shm
readonly NAS_FIRMWARE=$($GETCFG_CMD System Version -f $ULINUX_PATHFILE)
[[ ${NAS_FIRMWARE//.} -lt 426 ]] && curl_insecure_arg='--insecure' || curl_insecure_arg=''

if ! ($CURL_CMD $curl_insecure_arg --silent --fail "$REMOTE_REPO_URL/$REMOTE_SCRIPT_FILE" > "$DOWNLOAD_PATH/$REMOTE_SCRIPT_FILE"); then
    echo '! unable to download: aborting ...'
    exit 1
fi

if [[ -e "$DOWNLOAD_PATH/$REMOTE_SCRIPT_FILE" ]]; then
    eval "/usr/bin/env bash $DOWNLOAD_PATH/$REMOTE_SCRIPT_FILE" "$*"
    rm -f "$DOWNLOAD_PATH/$REMOTE_SCRIPT_FILE"
else
    echo '! unable to find installer: aborting ...'
    exit 1
fi
