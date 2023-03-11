#!/usr/bin/env bash

if [[ ! -e vars.source ]]; then
	echo "'vars.source' not found"
	exit 1
fi

. ./vars.source

Objects:Load()
	{

	readonly OBJECTS_PATHFILE="$source_path"/objects

	[[ ! -e $OBJECTS_PATHFILE ]] && ./build-objects.sh &>/dev/null

	. "$OBJECTS_PATHFILE"

	}

Packages:Load()
	{

	readonly PACKAGES_PATHFILE="$source_path"/packages.source

	if [[ ! -e $PACKAGES_PATHFILE ]]; then
		echo 'package list missing'
		exit 1
	fi

	. "$PACKAGES_PATHFILE"

	readonly PACKAGES_VER
	readonly BASE_QPKG_CONFLICTS_WITH
	readonly BASE_QPKG_WARNINGS
	readonly ESSENTIAL_IPKS
	readonly ESSENTIAL_PIPS
	readonly MIN_PYTHON_VER
	readonly MIN_PERL_VER

	# package list arrays are now full, so lock them
	readonly QPKG_NAME
		readonly QPKG_ARCH
		readonly QPKG_VERSION
		readonly QPKG_MD5
		readonly QPKG_URL
		readonly QPKG_MIN_RAM_KB
		readonly QPKG_AUTHOR
		readonly QPKG_APP_AUTHOR
		readonly QPKG_DESC
		readonly QPKG_NOTE
		readonly QPKG_ABBRVS
		readonly QPKG_CONFLICTS_WITH
		readonly QPKG_DEPENDS_ON
		readonly QPKG_REQUIRES_IPKS
		readonly QPKG_CAN_BACKUP
		readonly QPKG_CAN_RESTART_TO_UPDATE
		readonly QPKG_CAN_CLEAN
		readonly QPKG_CAN_LOG_SERVICE_OPERATIONS

	QPKGs-SCall:Add "${QPKG_NAME[*]}"

	}

QPKG.Abbrvs()
	{

	# input:
	#   $1 = QPKG name

	# output:
	#   stdout = list of abbreviations that may be used to specify this package (first package found)
	#   $? = 0 if successful, 1 if failed

	local -i index=0

	for index in "${!QPKG_NAME[@]}"; do
		if [[ ${QPKG_NAME[$index]} = "${1:?package name null}" ]]; then
			echo "${QPKG_ABBRVS[$index]}"
			return 0
		fi
	done

	return 1

	}

echo -n 'building wiki abbreviations page ... '

target_pathfile="$wiki_path"/Package-abbreviations.md

Objects:Load
Packages:Load 2>/dev/null	# packages source file throws a lot of syntax errors until it's processed - ignore these

echo 'These abbreviations are recognised by **sherpa** and may be used in-place of each package name:' > "$target_pathfile"
echo '| package name | acceptable abbreviations |' >> "$target_pathfile"
echo '| ---: | :--- |' >> "$target_pathfile"

for package_name in $(QPKGs-SCall:Array); do
	abs=$(QPKG.Abbrvs "$package_name")
	echo "| $package_name | \`${abs// /\` \`}\` |" >> "$target_pathfile"
done

ColourTextBrightGreen 'done\n'
exit 0
