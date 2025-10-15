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
target_pathfile=/share/Public/sherpa-config-backups.tar.gz

if [[ ! -d $qpkg_bu_path ]]; then
	echo '! no config backup path found'

	exit 1
elif IsPathEmpty "$qpkg_bu_path"; then
	echo '! backup path is empty'

	exit 1
fi

echo -n '> create config backup archive ... '
a=$(/bin/tar --create --gzip --file="$target_pathfile" --directory="$qpkg_bu_path" . 2>&1)
z=$?

[[ -z $a ]] && echo done || echo

exit $z
