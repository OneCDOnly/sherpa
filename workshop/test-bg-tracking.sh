#!/usr/bin/env bash

# get background procs to cleanup their own pid files.

runme()
	{

	# Input:
	#	$pidfile (global) = the pidfile for this process, containing the PID.

	trap '[[ -e $pidfile ]] && rm "$pidfile"; exit' SIGINT

# 	[[ -e $pidfile ]] && echo "pidfile contains: '$(<$pidfile)'"
	echo "pidfile: [$pidfile], start sleep"
	cmd='sleep 15'

	eval "$cmd"

	echo "pidfile: [$pidfile], end sleep"

 	[[ -e $pidfile ]] && rm "$pidfile"

	}

basepath=~/workspace/bg_procs
mkdir -p "$basepath"
echo "root PID: [$$]"

for ((i=1; i<=10; i++)); do
	pidfile=$(mktemp "$basepath"/proc_XXXXXX)		# Set $pidfile here, before launching background process so it's inherited by child.

	runme &
	echo "$!" > "$pidfile"
	sleep 1
done

echo 'waiting for background procs to exit...'
wait 2>/dev/null

echo 'done waiting for background procs, now waiting to exit script...'
sleep 5

echo "and exit"

