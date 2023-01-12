#!/usr/bin/env bash

# OneCD's async FIFO pipe reader proof-of-concept. 2023-01-13

# Have multiple background procs all send data to a single named pipe.
# Then read from this pipe, and update the state of specific QPKG arrays according to details in data.

echo "started: $(date)"

_Output_()
    {

    # * this function runs as a background process *

    # $1 = package name

    [[ -z ${1:?package name null} ]] && exit
    export package_name=$1
    local -i x=0

    for x in {1..8}; do
        SendRequest "$(date)"
        sleep 1
    done

    SendStatus 'done'

    } >&$fd

SendRequest()
    {

    # $1 = action request

    echo "package:[$package_name],request:[$1]"

    }

SendStatus()
    {

    # $1 = status update

    echo "package:[$package_name],status:[$1]"

    }

declare -i index=0
declare -a packages=()
stream_pipe=test.pipe

[[ -p $stream_pipe ]] && rm "$stream_pipe"
[[ ! -p $stream_pipe ]] && mknod "$stream_pipe" p

# find next available FD: https://stackoverflow.com/a/41603891
declare -i prospect=0
declare -i fd=0
for fd in {10..100} ; do
    [[ ! -e /proc/$$/fd/$fd ]] && break
done

[[ $fd -eq 0 ]] && echo 'unable to locate next available file descriptor' && exit

# open a 2-way channel to this pipe, so it will receive data without blocking the sender
eval "exec $fd<>$stream_pipe"

# launch forks with delays in-between to simulate QPKG actions
echo 'launch forks'
packages+=(SABnzbd)
_Output_ ${packages[${#packages[@]}-1]} &

sleep 2

packages+=(NZBGet)
_Output_ ${packages[${#packages[@]}-1]} &

sleep 4

packages+=(HideThatBanner)
_Output_ ${packages[${#packages[@]}-1]} &

sleep 1

packages+=(SortMyQPKGs)
_Output_ ${packages[${#packages[@]}-1]} &

echo 'sleep for a bit'
sleep 3

echo 'begin parsing pipe stream'

while [[ ${#packages[@]} -gt 0 ]]; do
    read input

    if [[ $input =~ "status:[done]" ]]; then
        for index in "${!packages[@]}"; do
            if [[ $input = "package:[${packages[index]}],status:[done]" ]]; then
                echo "${packages[index]} is complete"
                unset 'packages[index]'
            fi
        done
    else
        echo "read:$input"
    fi
done <&$fd

eval "exec $fd<&-"
[[ -p $stream_pipe ]] && rm "$stream_pipe"

echo "finished: $(date)"
