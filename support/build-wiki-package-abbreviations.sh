#!/usr/bin/env bash

. vars.source || exit
objects_built=false

Objects:Load()
	{

	readonly OBJECTS_PATHFILE=$source_path/$objects_file

	if [[ ! -e $OBJECTS_PATHFILE ]]; then
		./build-objects.sh &>/dev/null
		objects_built=true
	fi

	if [[ -e $OBJECTS_PATHFILE ]]; then
		. "$OBJECTS_PATHFILE"
	else
		echo 'unable to load objects: file missing'
		return 1
	fi

	return 0

	}

Packages:Load()
	{

	readonly PACKAGES_PATHFILE=$source_path/$packages_source_file

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

	# Package list arrays are now full, so lock them.
	readonly QPKG_ABBRVS
	readonly QPKG_APPLICATION_AUTHOR
	readonly QPKG_APPLICATION_AUTHOR_EMAIL
	readonly QPKG_APPLICATION_VERSION
	readonly QPKG_ARCH
	readonly QPKG_AUTHOR
	readonly QPKG_AUTHOR_EMAIL
	readonly QPKG_CAN_BACKUP
	readonly QPKG_CAN_CLEAN
	readonly QPKG_CAN_LOG_SERVICE_OPERATIONS
	readonly QPKG_CAN_RESTART_TO_UPDATE
	readonly QPKG_CONFLICTS_WITH
	readonly QPKG_DEPENDS_ON
	readonly QPKG_DESC
	readonly QPKG_HASH
	readonly QPKG_MAX_OS_VERSION
	readonly QPKG_MIN_OS_VERSION
	readonly QPKG_MIN_RAM_KB
	readonly QPKG_NAME
	readonly QPKG_NOTE
	readonly QPKG_REQUIRES_IPKS
	readonly QPKG_TEST_FOR_ACTIVE
	readonly QPKG_URL
	readonly QPKG_VERSION

	QPKGs-GRall:Add "${QPKG_NAME[*]}"

	}

QPKG.Abbrvs()
	{

	# input:
	#   $1 = QPKG name.

	# output:
	#   stdout = list of abbreviations that may be used to specify this package (first package found).
	#   $? = 0 if successful, 1 if failed.

	local -i index=0

	for index in "${!QPKG_NAME[@]}"; do
		if [[ ${QPKG_NAME[$index]} = "${1:?package name null}" ]]; then
			echo "${QPKG_ABBRVS[$index]}"
			return 0
		fi
	done

	return 1

	}

echo -n "building wiki 'Package abbreviations' page ... "

target_pathfile=$wiki_path/Package-abbreviations.md

Objects:Load
Packages:Load 2>/dev/null	# packages source file throws a lot of syntax errors until it's processed - ignore these.

	{

	echo -e '![Static Badge](https://img.shields.io/badge/page_status-live-green?style=for-the-badge)\n'
	echo -e 'These abbreviations are recognised by **sherpa** and may be used in-place of each [package name](Packages):\n'
	echo '| package name | acceptable abbreviations |'
	echo '| ---: | :--- |'

	} > "$target_pathfile"

for package_name in $(QPKGs-GRall:Array); do
	abs=$(QPKG.Abbrvs "$package_name")
	echo "| $package_name | \`${abs// /\` \`}\` |" >> "$target_pathfile"
done

[[ $objects_built = true ]] && rm -f "$OBJECTS_PATHFILE"

ShowDone
exit 0
