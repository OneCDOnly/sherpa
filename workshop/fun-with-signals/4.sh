#!/usr/bin/env bash

# This script will call 3.sh

clear

[[ $- != *m* ]] || set +m			# Disable job control if-enabled. Only needed for QTS 4.2.6.

scriptname="$(basename $0) [$$]"

thisscript()
	{

	printf '%-12s: ' "$scriptname"

	}

pid()
	{

	printf '[%s]' "$1"

	}

cleanup()
	{

	trap - EXIT

	echo "$(thisscript)${FUNCNAME[0]}(): enter"

	local a=''

	for a in $fork_pids; do
		if [[ -d /proc/$a ]] && grep -q 3.sh /proc/$a/cmdline; then
			echo "$(thisscript)${FUNCNAME[0]}(): send SIGTERM to 3.sh $(pid "$a")"
			kill -15 "$a"
			wait "$a" 2> /dev/null				# Suppress "Terminated" message in QTS 4.2.6.
		fi
	done

	rm -f /tmp/$$

	echo "$(thisscript)${FUNCNAME[0]}(): exit"

	exit

	}

trap 'echo "$(thisscript)caught EXIT, so cleanup()"; cleanup' EXIT

touch /tmp/$$

echo -n "$(thisscript)launch 3.sh ... "
./3.sh &
fork_pid=$!
echo "$(pid "$fork_pid")"
fork_pids+=" $fork_pid"

echo "$(thisscript)wait for 3.sh to exit ..."
wait
