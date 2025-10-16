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

GetUserDefVol()
	{

	# Outputs: (local)
	#	$? = 0 if found, 250 if not.

	/sbin/getcfg SHARE_DEF defVolMP -d undefined -f /etc/config/def_share.info

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

IsOsOk || exit

qpkg_bu_path=$(GetUserDefVol)/.qpkg_config_backup
config_archive_pathfile=/share/Public/sherpa-backup-archive.tar.gz

mkdir -p "$qpkg_bu_path"

if [[ ! -s $config_archive_pathfile ]]; then
	echo '! backup archive is empty or missing'

	exit 1
fi

echo -n '> restore backups from archive ... '
a=$(/bin/tar --extract --gzip --file="$config_archive_pathfile" --directory="$qpkg_bu_path" 2>&1)
z=$?

[[ -z $a ]] && echo done || echo

exit $z
