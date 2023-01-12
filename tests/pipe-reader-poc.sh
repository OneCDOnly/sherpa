#!/usr/bin/env bash

# OneCD's async FIFO pipe reader proof-of-concept. 2023-01-12

# Have multiple background procs all send data to a single named pipe.
# Then, read from this pipe, and update the state of specific QPKG arrays according to details in data.

echo "started: $(date)"

output()
    {

    # $1 = package name

    local -i x=0

    for x in {1..8}; do
        echo "package:[$1],request:[$(date)]"
        sleep 1
    done

    echo "package:[$1],status:[done]"

    }

declare -i index=0
declare -a packages=()
empty=false
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
output ${packages[${#packages[@]}-1]} >&$fd &

sleep 2

packages+=(NZBGet)
output ${packages[${#packages[@]}-1]} >&$fd &

sleep 4

packages+=(HideThatBanner)
output ${packages[${#packages[@]}-1]} >&$fd &

sleep 1

packages+=(SortMyQPKGs)
output ${packages[${#packages[@]}-1]} >&$fd &

echo 'sleep for a bit'
sleep 3

echo 'begin parsing pipe stream'

while [[ ${#packages[@]} -gt 0 ]]; do
    read input

    if [[ $input =~ "status:[done]" ]]; then
        for index in "${!packages[@]}"; do
            [[ -z ${packages[index]} ]] && continue      # ignore empty or emptied elements

            if [[ $input = "package:[${packages[index]}],status:[done]" ]]; then
                echo "package:[${packages[index]}] is complete"
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
