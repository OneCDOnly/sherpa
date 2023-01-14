#!/usr/bin/env bash

# OneCD's async FIFO pipe reader proof-of-concept. 2023-01-15

# Have multiple background procs all send data to a single named pipe.
# Then read from this pipe, and update the state of specific QPKG arrays according to details in data.

_LaunchForks_()
    {

    # * This function runs as a background process *

    # launch forks with delays in-between to simulate QPKG actions
    echo "$(Now): launch forks"
    _QPKG.Action_ ${packages[0]} 1.3 &

    sleep 2

    _QPKG.Action_ ${packages[1]} 2 skipped &

    sleep 4

    _QPKG.Action_ ${packages[2]} 1.6 failed &

    sleep 1

    _QPKG.Action_ ${packages[3]} 1.7 &

    sleep 1

    _QPKG.Action_ ${packages[4]} 2 skipped &

    sleep 3

    _QPKG.Action_ ${packages[5]} 1.3 failed &

    sleep 2

    _QPKG.Action_ ${packages[6]} 1.8 &

    }

_QPKG.Action_()
    {

    # * This function runs as a background process *

    # $1 = package name
    # $2 = sleep time in decimal seconds
    # $3 = (optional) forced status to return

    [[ -z ${1:?package name null} ]] && exit
    export PACKAGE_NAME=$1
    local -i x=0
    local fwvers=$(/sbin/getcfg System Version)

    # generate a few messages to test message stream
    for x in {1..8}; do
        SendPackageChangeStateRequest IsInstalled
        SendPackageChangeStateRequest IsStarted

        if [[ ${fwvers//.} -ge 430 ]]; then
            sleep "$2"
        else    # older BusyBox `sleep` requires integers only, so discard decimal component
            sleep "${2/.*/}"
        fi
    done

    SendPackageChangeStateRequest IsBollocksed      # add something to be picked up as `unidentified`

    SendProcStatus "${3:-ok}"
    SendProcStatus exit

    }

SendPackageChangeStateRequest()
    {

    # Send a message into message stream to change the state of this QPKG to $1
    # This might be: `IsInstalled`, `IsNtEnabled`, `IsStarted`, etc...
    # This function is only called from within background functions

    # $1 = action request

    echo "package $PACKAGE_NAME state $1 date $(NowInEpochSeconds)"

    } >&$fd_pipe

SendProcStatus()
    {

    # Send a message into message stream to update parent with the status of this action
    # This can be: `ok`, `skipped`, `failed`, `exit`
    # This function is only called from within background functions

    # $1 = status update

    echo "package $PACKAGE_NAME status $1 date $(NowInEpochSeconds)"

    } >&$fd_pipe

FindNextFD()
    {

    # find next available file descriptor: https://stackoverflow.com/a/41603891

    local -i fd=0

    for fd in {10..100}; do
        if [[ ! -e /proc/$$/fd/$fd ]]; then
            echo "$fd"
            return
        fi
    done

    }

Now()
    {

    date +%H:%M:%S

    }

NowInEpochSeconds()
    {

    date +%s

    }

ConvertEpochSecondsToTime()
    {

    # $1 = epoch seconds

    date -d @${1:-0} +'%H:%M:%S'

    }

echo "$(Now): started"

declare -a packages=()
declare -i index=0
passes=0
skips=0
fails=0
message_pipe=/tmp/messages.pipe
packages=(SABnzbd NZBGet HideThatBanner SortMyQPKGs QDK OMedusa OTransmission)
PACKAGE_STATES=(BackedUp Cleaned Downloaded Enabled Installed Missing Started Upgradable)           # sorted

[[ -p $message_pipe ]] && rm "$message_pipe"
[[ ! -p $message_pipe ]] && mknod "$message_pipe" p

fd_pipe=$(FindNextFD)

# open a 2-way channel to this pipe, so it will receive data without blocking the sender
eval "exec $fd_pipe<>$message_pipe"

_LaunchForks_ &
sleep 1
echo "$(Now): sleep for a bit"
sleep 5

echo "$(Now): begin processing message stream"
echo '-----------------------------------------'

while [[ ${#packages[@]} -gt 0 ]]; do
    read package_key package_name state_status_key state_status_value datetime_key datetime_value

    case $state_status_key in
        state)
            # must validate the content of $state_status_value before calling it
            while true; do
                for state in "${PACKAGE_STATES[@]}"; do
                    if [[ $state_status_value = "Is${state}" || $state_status_value = "IsNt${state}" ]]; then
                        echo "$(ConvertEpochSecondsToTime "$datetime_value"): marking $package_name state as $state_status_value"
#                       NoteQpkgStateAs${state_status_value} "$package_name"
                        break 2
                    fi
                done

                echo "$(ConvertEpochSecondsToTime "$datetime_value"): ignoring unidentified $package_name state: '$state_status_value'"
                break
            done
            ;;
        status)
            case $state_status_value in
                ok)
                    # mark QPKG action as finished OK
                    echo "$(ConvertEpochSecondsToTime "$datetime_value"): marking $package_name action status as $state_status_value"
                    ((passes++))
                    ;;
                skipped)
                    # mark QPKG action as skipped
                    echo "$(ConvertEpochSecondsToTime "$datetime_value"): marking $package_name action status as $state_status_value"
                    ((skips++))
                    ;;
                failed)
                    # mark QPKG action as failed
                    echo "$(ConvertEpochSecondsToTime "$datetime_value"): marking $package_name action status as $state_status_value"
                    ((fails++))
                    ;;
                exit)
                    for index in "${!packages[@]}"; do
                        if [[ ${packages[index]} = "$package_name" ]]; then
                            echo "$(ConvertEpochSecondsToTime "$datetime_value"): $package_name action fork is exiting"
                            unset 'packages[index]'
                            break
                        fi
                    done
                    ;;
                *)
                    echo "$(ConvertEpochSecondsToTime "$datetime_value"): ignoring unidentified $package_name status: '$state_status_value'"
            esac
    esac
done <&$fd_pipe

eval "exec $fd_pipe<&-"
[[ -p $message_pipe ]] && rm "$message_pipe"

echo '-----------------------------------------'
echo "$(Now): finished"
echo "totals=$passes, $skips, $fails"
