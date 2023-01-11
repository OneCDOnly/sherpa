#!/usr/bin/env bash

# OneCD's async FIFO pipe reader proof-of-concept. 2023-01-12

# Have multiple background procs all send data to a single named pipe.
# Then, read from this pipe, and update the state of specific QPKG arrays according to details in data.

echo "started: $(date)"

output()
    {

    # $1 = id

    local -i x=0

    for x in {1..8}; do
        echo "id:[$1],data:[$(date)]"
        sleep 1
    done

    echo "id:[$1],status:[done]"

    }

declare -i index=0
declare -a ids=()
empty=false
stream_pipe=test.pipe

[[ -p $stream_pipe ]] && rm "$stream_pipe"
[[ ! -p $stream_pipe ]] && mknod "$stream_pipe" p

# open a 2-way channel to this pipe, so it will receive data without blocking the sender
exec {FD}<> "$stream_pipe"  # get BASH to assign next available FD: https://stackoverflow.com/a/28300838

# launch forks with delays in-between to simulate QPKG actions
echo 'launch forks'
ids+=(ae35)
output ${ids[-1]} >&${FD} &

sleep 2

ids+=(ae42)
output ${ids[-1]} >&${FD} &

sleep 4

ids+=(ae56)
output ${ids[-1]} >&${FD} &

sleep 1

ids+=(ae64)
output ${ids[-1]} >&${FD} &

echo 'sleep for a bit'
sleep 3

echo 'read pipe stream'

length=${#ids[@]}

while [[ $length -gt 0 ]]; do
    read input

    if [[ $input =~ "status:[done]" ]]; then
        for index in "${!ids[@]}"; do
            [[ -z ${ids[index]} ]] && continue      # ignore empty or emptied elements

            if [[ $input = "id:[${ids[index]}],status:[done]" ]]; then
                echo "id:[${ids[index]}] is complete"
                unset 'ids[index]'
                ((length--))
            fi
        done
    else
        echo "read:$input"
    fi
done <&${FD}

exec {FD}<&-
[[ -p $stream_pipe ]] && rm "$stream_pipe"

echo "finished: $(date)"
