#!/usr/bin/env bash

GetQPKGPostInstallDeps()
	{

	# Inputs: (local)
	#	$1 = target QPKG name

	# Outputs: (local)
	#	stdout = target QPKG dependency list, colon-separated.

	# Layout:
	# 	'Dependency = packageA:packageB:packageC'

	[[ -n ${1:-} ]] || return

	/sbin/getcfg "$1" Dependency -f /etc/config/qpkg.conf

	}

AddToQPKGPostInstallDeps()
	{

	# Inputs: (local)
	#	$1 = target QPKG name.
	#	$2 = QPKG to add as a post-install dependency.

	# Layout:
	# 	'Dependency = packageA:packageB:packageC'

	[[ -n ${1:-} && -n ${2:-} ]] || return

	local a=''

	a=$(GetQPKGPostInstallDeps "$1")

	# First, check if entry already exists.
	/bin/grep -qw "$2" <<< "$a" && return

	# Then, append entry to existing 'Dependency' string.
	/sbin/setcfg "$1" Dependency "$a:$2" -f /etc/config/qpkg.conf

	}

RemoveFromQPKGPostInstallDeps()
	{

	# Inputs: (local)
	#	$1 = target QPKG name.
	#	$2 = QPKG to remove as a post-install dependency.

	# Layout:
	# 	'Dependency = packageA:packageB:packageC'

	[[ -n ${1:-} && -n ${2:-} ]] || return

	local a=''
	local re=''

	re=\\b${2}\\b
	a=$(/bin/sed "s|${re}||" <<< "$(/sbin/getcfg "$1" Dependency -f /etc/config/qpkg.conf)")
	a=$(/bin/tr -s ':' <<< "$a")

	if [[ -n $a ]]; then
		/sbin/setcfg "$1" Dependency "$a" -f /etc/config/qpkg.conf
	else
		/sbin/setcfg -e "$1" Dependency -f /etc/config/qpkg.conf
	fi

	}

RemoveFromQPKGPostInstallDeps OTransmission test1

