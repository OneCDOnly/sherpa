#!/usr/bin/env bash

# OneCD's async FIFO pipe reader proof-of-concept. 2023-01-13

# Have multiple background procs all send data to a single named pipe.
# Then read from this pipe, and update the state of specific QPKG arrays according to details in data.

echo "started: $(date)"

_Output_()
    {

    # * this function runs as a background process *

    # $1 = package name
    # $2 = sleep time in decimal seconds

    [[ -z ${1:?package name null} ]] && exit
    export package_name=$1
    local -i x=0

    for x in {1..8}; do
        SendPackageChangeStateRequest installed
        SendPackageChangeStateRequest started
        sleep $2
    done

    SendProcStatus ok
    SendProcStatus exit

    } >&$fd

SendPackageChangeStateRequest()
    {

    # send a message back to receiver to change the state of this QPKG to $1
    # this might be: `installed`, `enabled`, `started`, etc...

    # $1 = action request

    echo "package:[$package_name],state:[$1]"

    }

SendProcStatus()
    {

    # send a message back to receiver to change the status of this action
    # this might be: `ok`, `skipped`, `failed`, `exit`

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
for fd in {10..100}; do
    [[ ! -e /proc/$$/fd/$fd ]] && break
done

[[ $fd -eq 0 ]] && echo 'unable to locate next available file descriptor' && exit

# open a 2-way channel to this pipe, so it will receive data without blocking the sender
eval "exec $fd<>$stream_pipe"

# launch forks with delays in-between to simulate QPKG actions
echo 'launch forks'
packages+=(SABnzbd)
_Output_ ${packages[${#packages[@]}-1]} 1.3 &

sleep 2

packages+=(NZBGet)
_Output_ ${packages[${#packages[@]}-1]} 2 &

sleep 4

packages+=(HideThatBanner)
_Output_ ${packages[${#packages[@]}-1]} 1.6 &

sleep 1

packages+=(SortMyQPKGs)
_Output_ ${packages[${#packages[@]}-1]} .7 &

# echo 'sleep for a bit'
# sleep 3

passes=0
skips=0
fails=0

echo 'begin parsing pipe stream'

while [[ ${#packages[@]} -gt 0 ]]; do
    read input

    # extract 2 values from data: package name, and state or status
    package_name="${input#*[}"; package_name=${package_name%%]*}
    second_key="${input##*],}"; second_key=${second_key%:*}
    second_value="${input##*[}"; second_value=${second_value%]*}

    case $second_key in
        status)
            case $second_value in
                ok)
                    # mark QPKG action as finished OK
                    echo "marking $package_name action as $second_value"
                    ((passes++))
                    ;;
                skipped)
                    # mark QPKG action as skipped
                    echo "marking $package_name action as $second_value"
                    ((skips++))
                    ;;
                failed)
                    # mark QPKG action as failed
                    echo "marking $package_name action as $second_value"
                    ((fails++))
                    ;;
                exit)
                    for index in "${!packages[@]}"; do
                        if [[ ${packages[index]} = "$package_name" ]]; then
                            echo "$package_name is complete"
                            unset 'packages[index]'
                            break
                        fi
                    done
                    ;;
                *)
                echo "unknown status: <$second_value>"
            esac
            ;;
        state)
            case $second_value in
                installed)
                    # mark QPKG state as installed
                    echo "marking $package_name state as $second_value"
                    ;;
                started)
                    # mark QPKG state as started
                    echo "marking $package_name state as $second_value"
                    ;;
                *)
                    echo "unknown state: <$second_value>"
            esac
    esac
done <&$fd

eval "exec $fd<&-"
[[ -p $stream_pipe ]] && rm "$stream_pipe"

echo "finished: $(date)"
echo "totals=$passes, $skips, $fails"
