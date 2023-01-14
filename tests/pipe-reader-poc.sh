#!/usr/bin/env bash

# OneCD's async FIFO pipe reader proof-of-concept. 2023-01-14

# Have multiple background procs all send data to a single named pipe.
# Then read from this pipe, and update the state of specific QPKG arrays according to details in data.

_QPKG.Action_()
    {

    # * this function runs as a background process *

    # $1 = package name
    # $2 = sleep time in decimal seconds
    # $3 = (optional) forced status to return

    [[ -z ${1:?package name null} ]] && exit
    export PACKAGE_NAME=$1
    local -i x=0

    # generate a few messages to test message stream
    for x in {1..8}; do
        SendPackageChangeStateRequest IsInstalled
        SendPackageChangeStateRequest IsStarted
        sleep $2
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

    echo "package:[$PACKAGE_NAME],state:[$1],date:[$(now)]"

    } >&$fd

SendProcStatus()
    {

    # Send a message into message stream to update parent with the status of this action
    # This can be: `ok`, `skipped`, `failed`, `exit`
    # This function is only called from within background functions

    # $1 = status update

    echo "package:[$PACKAGE_NAME],status:[$1],date:[$(now)]"

    } >&$fd

now()
    {

    date +%H:%M:%S

    }

echo "$(now): started"

declare -i index=0
declare -a packages=()
message_pipe=/tmp/messages.pipe

[[ -p $message_pipe ]] && rm "$message_pipe"
[[ ! -p $message_pipe ]] && mknod "$message_pipe" p

# find next available FD: https://stackoverflow.com/a/41603891
declare -i prospect=0
declare -i fd=0
for fd in {10..100}; do
    [[ ! -e /proc/$$/fd/$fd ]] && break
done

[[ $fd -eq 0 ]] && echo 'unable to locate next available file descriptor' && exit

# open a 2-way channel to this pipe, so it will receive data without blocking the sender
eval "exec $fd<>$message_pipe"

# launch forks with delays in-between to simulate QPKG actions
echo "$(now): launch forks"
packages+=(SABnzbd)
_QPKG.Action_ ${packages[${#packages[@]}-1]} 1.3 &

sleep 2

packages+=(NZBGet)
_QPKG.Action_ ${packages[${#packages[@]}-1]} 2 skipped &

sleep 4

packages+=(HideThatBanner)
_QPKG.Action_ ${packages[${#packages[@]}-1]} 1.6 failed &

sleep 1

packages+=(SortMyQPKGs)
_QPKG.Action_ ${packages[${#packages[@]}-1]} .7 &

echo "$(now): sleep for a bit"
sleep 3

passes=0
skips=0
fails=0

PACKAGE_STATES=(BackedUp Cleaned Downloaded Enabled Installed Missing Started Upgradable)           # sorted



echo "$(now): begin processing message stream"
echo '-----------------------------------------'

while [[ ${#packages[@]} -gt 0 ]]; do
    read input

    # whittle-down $input to extract 3 values: package name, state or status, and datetime
#     package_key="${input%%:*}"
    input="${input#*[}"

    package_name=${input%%]*}
    input="${input#*,}"

    state_status_key="${input%%:*}"
    input="${input#*[}"

    state_status_value=${input%%]*}
    input="${input#*,}"

#     datetime_key="${input%%:*}"
    input="${input#*[}"

    datetime_value=${input%%]*}

    case $state_status_key in
        state)
            # must validate the content of $state_status_value before calling it
            while true; do
                for state in "${PACKAGE_STATES[@]}"; do
                    if [[ $state_status_value = "Is${state}" || $state_status_value = "IsNt${state}" ]]; then
                        echo "$datetime_value: marking $package_name state as $state_status_value"
#                       NoteQpkgStateAs${state_status_value} "$package_name"
                        break 2
                    fi
                done

                echo "$datetime_value: ignoring unidentified $package_name state: '$state_status_value'"
                break
            done
            ;;
        status)
            case $state_status_value in
                ok)
                    # mark QPKG action as finished OK
                    echo "$datetime_value: marking $package_name action status as $state_status_value"
                    ((passes++))
                    ;;
                skipped)
                    # mark QPKG action as skipped
                    echo "$datetime_value: marking $package_name action status as $state_status_value"
                    ((skips++))
                    ;;
                failed)
                    # mark QPKG action as failed
                    echo "$datetime_value: marking $package_name action status as $state_status_value"
                    ((fails++))
                    ;;
                exit)
                    for index in "${!packages[@]}"; do
                        if [[ ${packages[index]} = "$package_name" ]]; then
                            echo "$datetime_value: $package_name action fork is exiting"
                            unset 'packages[index]'
                            break
                        fi
                    done
                    ;;
                *)
                    echo "$datetime_value: ignoring unidentified $package_name status: '$state_status_value'"
            esac
    esac
done <&$fd

eval "exec $fd<&-"
[[ -p $message_pipe ]] && rm "$message_pipe"

echo '-----------------------------------------'
echo "$(now): finished"
echo "totals=$passes, $skips, $fails"
