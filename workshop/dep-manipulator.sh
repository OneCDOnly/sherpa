#!/usr/bin/env bash

# Dependency = packageA:packageB:packageC

# dep='packageA:packageB:packageC'
#
# echo "dep=[$dep]"
#
# target=packageB
#
# re=\\b${target}\\b
#
# output=$(sed "s|${re}||" <<< "$dep")
# echo "output=[$output]"
#
# output=$(tr -s ':' <<< $output)
#
# echo "output=[$output]"

GetQPKGPostInstallDeps()
	{

	# Inputs: (local)
	#	$1 = target QPKG name

	# Outputs: (local)
	#	stdout = target QPKG dependency list, colon-separated.

	[[ -n ${1:-} ]] || return

	/sbin/getcfg "$1" Dependency -f /etc/config/qpkg.conf

	}

AddToQPKGPostInstallDeps()
	{

	# Inputs: (local)
	#	$1 = target QPKG name.
	#	$2 = QPKG to add as a post-install dependency.

	/bin/grep -qw "$2" $(GetQPKGPostInstallDeps "$1") && return


	}

RemoveFromQPKGPostInstallDeps()
	{

	# Inputs: (local)
	#	$1 = target QPKG name.
	#	$2 = QPKG to remove as a post-install dependency.

	# Dependency = packageA:packageB:packageC

	[[ -n ${1:-} && -n ${2:-} ]] || return

	local a=''
	local re=''

	re=\\b${2}\\b
	a=$(/bin/sed "s|${re}||" <<< "$(/sbin/getcfg "$1" Dependency -f /etc/config/qpkg.conf)")
	a=$(/bin/tr -s ':' <<< "$a")

	/sbin/setcfg "$1" Dependency "$a" -f /etc/config/qpkg.conf

	}

RemoveFromQPKGPostInstallDeps OTransmission test1

