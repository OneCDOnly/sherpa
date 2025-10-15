#!/bin/bash

set -o nounset -o pipefail
[[ -L /dev/fd ]] || ln -fns /proc/self/fd /dev/fd		# KLUDGE: `/dev/fd` isn't always created by QTS.

IsOsOk()
	{

	if ! IsOsQNAP; then
		echo '! QNAP shell functions not found ... is this a QNAP NAS?'

		return 1
	fi

	return 0

	}

IsOsQNAP()
	{

	# Is this a QNAP NAS?

	[[ -e /etc/init.d/functions ]]

	}

IsPathEmpty()
	{

	# Inputs: (local)
	#	$1 = directory to check if empty.

	# Outputs: (local)
	#	$? = 0 : true
	#	$? = 1 : false or $1 does not exist.

	local a=${1:-}

	[[ -n $a && -d $a ]] || return

	rmdir "$a" &> /dev/null && mkdir "$a"

	}

GetUserDefVol()
	{

	# Outputs: (local)
	#	$? = 0 if found, 250 if not.

	/sbin/getcfg SHARE_DEF defVolMP -d undefined -f /etc/config/def_share.info

	}

GetOsFirmwareVersion()
	{

	# Outputs: (local)
	#	stdout = text string.
	#	$? = 0 if found, 250 if not.

	/sbin/getcfg System Version -d undefined -f /etc/config/uLinux.conf

	}

SaveVolumeInfo()
	{

	UpdateInfoFile Model "$(get_display_name)"
	UpdateInfoFile Hostname "$HOSTNAME"
	UpdateInfoFile DefaultVolume "$(GetUserDefVol)"
	UpdateInfoFile FirmwareVersion "$(GetOsFirmwareVersion)"

	}

DeleteVolumeInfo()
	{

	rm -f "$volume_info_pathfile"

	}

UpdateInfoFile()
	{

	[[ -n $1 && -n $2 ]] || return

	/sbin/setcfg Source "$1" "$2" -f "$volume_info_pathfile"

	}

IsOsOk || exit

qpkg_bu_path=$(GetUserDefVol)/.qpkg_config_backup
config_archive_pathfile=/share/Public/sherpa-config-archive.tar.gz
volume_info_pathfile=$qpkg_bu_path/volume.cfg

if [[ ! -d $qpkg_bu_path ]]; then
	echo '! no config backup path found'

	exit 1
fi

DeleteVolumeInfo		# Won't need to make an archive if the only thing there is the volume info file. So, remove it now and recreate it later.

if IsPathEmpty "$qpkg_bu_path"; then
	echo '! backup path is empty, nothing to archive'

	exit 1
fi

echo -n '> create backup archive ... '

SaveVolumeInfo

a=$(/bin/tar --create --gzip --file="$config_archive_pathfile" --directory="$qpkg_bu_path" . 2>&1)
z=$?

[[ -z $a ]] && echo done || echo

exit $z
