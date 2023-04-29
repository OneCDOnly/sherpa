#!/usr/bin/env bash

# sherpa.loader.sh
#	Copyright (C) 2017-2023 OneCD - one.cd.only@gmail.com

#	So, blame OneCD if it all goes horribly wrong. ;)

# Description:
#	This is the loader script for the sherpa mini-package-manager and is part of the `sherpa` QPKG.

# Project:
#	https://git.io/sherpa

# Forum:
#	https://forum.qnap.com/viewtopic.php?f=320&t=132373

# Tested on:
#	GNU bash, version 3.2.57(2)-release (i686-pc-linux-gnu)
#	GNU bash, version 3.2.57(1)-release (aarch64-QNAP-linux-gnu)
#	Copyright (C) 2007 Free Software Foundation, Inc.

# ... and periodically on:
#	GNU bash, version 5.0.17(1)-release (aarch64-openwrt-linux-gnu)
#	Copyright (C) 2019 Free Software Foundation, Inc.

# License:
#	This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

#	This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

#	You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/

Init()
	{

	IsQNAP || return

	export LOADER_SCRIPT_VER=230430
	export LOADER_SCRIPT_PPID=$PPID

	local -r WORK_PATH=$(/sbin/getcfg sherpa Install_Path -f /etc/config/qpkg.conf)/cache

	local -r MANAGER_FILE=sherpa.manager.sh
	local -r MANAGER_ARCHIVE_FILE=${MANAGER_FILE%.*}.tar.gz
	readonly MANAGER_ARCHIVE_URL=https://raw.githubusercontent.com/OneCDOnly/sherpa/stable/$MANAGER_ARCHIVE_FILE
	readonly MANAGER_ARCHIVE_PATHFILE=$WORK_PATH/$MANAGER_ARCHIVE_FILE
	readonly MANAGER_PATHFILE=$WORK_PATH/$MANAGER_FILE

	local -r NAS_FIRMWARE=$(/sbin/getcfg System Version -f /etc/config/uLinux.conf)
	[[ ${NAS_FIRMWARE//.} -lt 426 ]] && curl_insecure_arg=' --insecure' || curl_insecure_arg=''
	readonly GNU_FIND_CMD=/opt/bin/find
	previous_msg=''

	[[ ! -d $WORK_PATH ]] && mkdir -p "$WORK_PATH"

	return 0

	}

EnsureFileIsCurrent()
	{

	# $1 = local pathfilename to examine
	# $2 = remote archive to pull updated file from
	# $3 = local archive pathfilename to extract archive to

	local CHANGE_THRESHOLD_MINUTES=60

	# if file was updated only recently, don't run another update. Examine `change` time as this is updated even if file content isn't modified.
	if [[ -e $1 && -e $GNU_FIND_CMD ]]; then
		msgs=$($GNU_FIND_CMD "$1" -cmin +$CHANGE_THRESHOLD_MINUTES) # no-output if last update was less than $CHANGE_THRESHOLD_MINUTES minutes ago
	else
		msgs="this is either a new installation, or GNU 'find' was not found"
	fi

	if [[ -n $msgs ]]; then
		if ! (/sbin/curl"$curl_insecure_arg" --silent --fail "$2" > "$3"); then
			ShowAsWarning 'Remote file download failed'
		else
			/bin/tar --extract --gzip --file="$3" --directory="$(/usr/bin/dirname "$3")" 2>/dev/null
		fi
	fi

	if [[ ! -e $1 ]]; then
		ShowAsAbort 'Unable to find target file'
		exit 1
	fi

	}

IsQNAP()
	{

	# is this a QNAP NAS?

	if [[ ! -e /etc/init.d/functions ]]; then
		ShowAsAbort 'QNAP functions not found ... is this a QNAP NAS?'
		return 1
	fi

	return 0

	}

ShowAsWarning()
	{

	# warning only

	WriteToDisplay.New "$(ColourTextBrightOrange warn)" "${1:-}"

	return 0

	}

ShowAsAbort()
	{

	# fatal abort

	WriteToDisplay.New "$(ColourTextBrightRed bort)" "${1:-}"

	return 0

	}

WriteToDisplay.New()
	{

	# Updates the previous message

	# input:
	#	$1 = pass/fail
	#	$2 = message

	# output:
	#	stdout = overwrites previous message with updated message
	#	$previous_length
	#	$appended_length

	local new_message=''
	local strbuffer=''
	local new_length=0

	new_message=$(printf '%-10s: %s' "$1" "$2")

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

ColourTextBrightOrange()
	{

	printf '\033[1;38;5;214m%s\033[0m' "${1:-}"

	}

ColourTextBrightRed()
	{

	printf '\033[1;31m%s\033[0m' "${1:-}"

	}

Init || exit
EnsureFileIsCurrent "$MANAGER_PATHFILE" "$MANAGER_ARCHIVE_URL" "$MANAGER_ARCHIVE_PATHFILE"
eval '/usr/bin/env bash' "$MANAGER_PATHFILE" "$*"
