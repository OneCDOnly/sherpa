#!/usr/bin/env bash
#
# sherpa.sh
#
# This is the loader script for the sherpa mini-package-manager.
#
# Copyright (C) 2017-2020 OneCD [one.cd.only@gmail.com]
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

Init()
    {

    IsQNAP || return 1

    local -r LOADER_SCRIPT_FILE=sherpa.sh
    export LOADER_SCRIPT_VERSION=200830

    local -r NAS_FIRMWARE=$(/sbin/getcfg System Version -f /etc/config/uLinux.conf)
    [[ ${NAS_FIRMWARE//.} -lt 426 ]] && curl_insecure_arg='--insecure' || curl_insecure_arg=''
    local -r MAIN_SCRIPT_FILE=__sherpa-main__.sh
    readonly REMOTE_MAIN_SCRIPT=https://raw.githubusercontent.com/OneCDOnly/sherpa/master/$MAIN_SCRIPT_FILE
    readonly LOCAL_MAIN_SCRIPT=/share/$MAIN_SCRIPT_FILE
    previous_msg=''

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

ShowAsAbort()
    {

    local buffer="$1"
    local capitalised="$(tr "[a-z]" "[A-Z]" <<< "${buffer:0:1}")${buffer:1}"      # use any available 'tr'

    WriteToDisplay_NewLine "$(ColourTextBrightRed fail)" "$capitalised: aborting ..."

    }

WriteToDisplay_NewLine()
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

        echo "$strbuffer"
    fi

    return 0

    }

ColourTextBrightRed()
    {

    echo -en '\033[1;31m'"$(ColourReset "$1")"

    }

ColourReset()
    {

    echo -en "$1"'\033[0m'

    }

Init || exit 1

if ! (/sbin/curl $curl_insecure_arg --silent --fail "$REMOTE_MAIN_SCRIPT" > "$LOCAL_MAIN_SCRIPT"); then
    ShowAsAbort 'installer download failed'
    exit 1
fi

if [[ ! -e $LOCAL_MAIN_SCRIPT ]]; then
    ShowAsAbort 'unable to find installer'
    exit 1
fi

eval "/usr/bin/env bash" "$LOCAL_MAIN_SCRIPT" "$*"
rm -f "$LOCAL_MAIN_SCRIPT"

exit 0
