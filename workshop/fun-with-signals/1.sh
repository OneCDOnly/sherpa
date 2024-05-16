#!/usr/bin/env bash

# A loop that takes a while to run.

# This script is called from 2.sh

[[ $- != *m* ]] || set +m			# Disable job control if-enabled. Only needed for QTS 4.2.6.

scriptname="$(basename $0) [$$]"

thisscript()
	{

	printf '%-12s: ' "$scriptname"

	}

cleanup()
	{

	trap - EXIT

	echo "$(thisscript)${FUNCNAME[0]}(): enter"

	rm -f /tmp/$$

	echo "$(thisscript)${FUNCNAME[0]}(): exit"

	exit

	}

trap 'echo "$(thisscript)caught EXIT, so cleanup()"; cleanup' EXIT

touch /tmp/$$

for ((i=1; i<=10; i++)); do
	sleep 1
	echo -n "$i, "
done
