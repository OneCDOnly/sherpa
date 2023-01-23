#!/usr/bin/env bash

# Fault-finding the single-line updating display. 2023-01-23

# When running on helga and sarah, QPKG progress shows large on-screen whitespaces between the displayed counts.
# Might be related to 'sed' handling of extended regexes when striping ANSI codes.

readonly SCRIPT_STARTSECONDS=$(/bin/date +%s)
GNU_SED_CMD=/usr/bin/sed
#GNU_SED_CMD=/opt/bin/sed
[[ -e $GNU_SED_CMD ]] && colourful=true || colourful=false

LaunchQPKGActionForks()
    {

    # Execute actions concurrently, but only as many as $max_forks will allow given the circumstances


    # inputs: (local)
    #   $1 = the target function action to be applied to each QPKG in $target_packages()
    #   $2 = an array of QPKG names to process with $1

    # inputs: (global)
    #   $fork_count = number of currently running forks
    #   $max_forks = maximum number of permitted concurrent forks given the current environment

    ShowAsProc "fake package action"

    UpdateForkProgress

    # all action forks have launched, just need to wait for them to exit

    while [[ $fork_count -gt 0 ]]; do
        UpdateForkProgress      # update display while running forks complete
        sleep 1
    done

    # all forks have exited

    EraseThisLine

    }

ShowAsProc()
    {

    local suffix=''
    [[ -n ${2:-} ]] && suffix=": $2"

    EraseThisLine
    WriteToDisplayWait "$(ColourTextBrightOrange proc)" "${1:-}${suffix}"

    }

UpdateInPlace()
    {

    # input:
    #   $1 = message to display

    local -i this_length=0
    local -i blanking_length=0
    local this_squeezed_msg=$(tr -s ' ' <<< "${1:-}")
    local this_clean_msg=$(StripANSI "$this_squeezed_msg")

    if [[ $this_clean_msg != "$previous_clean_msg" ]]; then
        this_length=$((${#this_clean_msg}))

        if [[ $this_length -lt $previous_length ]]; then
            blanking_length=$((this_length-previous_length))
            # backspace to start of previous msg, print new msg, add additional spaces, then backspace to end of new msg
            printf "%${previous_length}s" | tr ' ' '\b'; echo -en "$this_squeezed_msg"; printf "%${blanking_length}s"; printf "%${blanking_length}s" | tr ' ' '\b'
        else
            # backspace to start of previous msg, print new msg
            printf "%${previous_length}s" | tr ' ' '\b'; echo -en "$this_squeezed_msg"
        fi

        previous_length=$this_length
        previous_clean_msg=$this_clean_msg
    fi

    }

EraseThisLine()
    {

    # reset cursor to start-of-line, erasing entire line

    echo -en "\033[2K\r"

    }

Display()
    {

    echo -e "${1:-}"

    }

DisplayWait()
    {

    echo -en "${1:-}"

    }

InitForkCounts()
    {

    # create directories so background processes can be monitored

    InitProgress

    }

IncForkProgressIndex()
    {

    ((progress_index++))
    local formatted_index="$(printf '%02d' "$progress_index")"

    }

RefreshForkCounts()
    {

    fork_count="$(($(/bin/date +%s)-SCRIPT_STARTSECONDS+1))"
    ok_count="$(($(/bin/date +%s)-SCRIPT_STARTSECONDS+6))"
    skip_count="$(($(/bin/date +%s)-SCRIPT_STARTSECONDS+11))"
    fail_count="$(($(/bin/date +%s)-SCRIPT_STARTSECONDS+18))"

    total_count=$((ok_count+skip_count+fail_count+100))

    }

InitProgress()
    {

    progress_index=0
    previous_length=0
    previous_clean_msg=''

    RefreshForkCounts

    }

UpdateForkProgress()
    {

    # all input vars are global

    local progress_message=': '

    RefreshForkCounts

    progress_message+="$(PercFrac "$ok_count" "$skip_count" "$fail_count" "$total_count")"

    if [[ $fork_count -gt 0 ]]; then
        [[ -n $progress_message ]] && progress_message+=': '
        progress_message+="$(ColourTextBrightOrange "$fork_count") in-progress"
    fi

    if [[ $ok_count -gt 0 ]]; then
        [[ -n $progress_message ]] && progress_message+=':   '
        progress_message+="$(ColourTextBrightGreen "$ok_count") OK"
    fi

    if [[ $skip_count -gt 0 ]]; then
        [[ -n $progress_message ]] && progress_message+=': '
        progress_message+="$(ColourTextBrightOrange "$skip_count") skipped"
    fi

    if [[ $fail_count -gt 0 ]]; then
        [[ -n $progress_message ]] && progress_message+=': '
        progress_message+="$(ColourTextBrightRed "$fail_count") failed"
    fi

    [[ -n $progress_message ]] && UpdateInPlace "$progress_message "

    return 0

    }

ShowAsProcLong()
    {

    ShowAsProc "${1:-} (might take a while)" "${2:-}"

    } 2>/dev/null

ShowAsProc()
    {

    local suffix=''
    [[ -n ${2:-} ]] && suffix=": $2"

    EraseThisLine
    WriteToDisplayWait "$(ColourTextBrightOrange proc)" "${1:-}${suffix}"
    WriteToLog proc "${1:-}${suffix}"

    } 2>/dev/null

ShowAsDone()
    {

    # process completed OK

    EraseThisLine
    WriteToDisplayNew "$(ColourTextBrightGreen 'done')" "${1:-}"
    WriteToLog 'done' "$1"

    }

ShowAsWarn()
    {

    # warning only

    EraseThisLine
    WriteToDisplayNew "$(ColourTextBrightOrange warn)" "${1:-}"
    WriteToLog warn "$1"

    } 2>/dev/null

PercFrac()
    {

    # calculate percent-complete and a fraction of the total

    # $1 = ok count
    # $2 = skip count
    # $3 = fail count
    # $4 = total count

    declare -i -r OK_COUNT=${1:-0}
    declare -i -r SKIP_COUNT=${2:-0}
    declare -i -r FAIL_COUNT=${3:-0}
    declare -i -r TOTAL_COUNT=${4:-0}
    local -i progress_count="$((OK_COUNT+SKIP_COUNT+FAIL_COUNT))"
    local percent=''

    [[ $TOTAL_COUNT -gt 0 ]] || return          # no-point calculating a fraction of zero

    if [[ $progress_count -gt $TOTAL_COUNT ]]; then
        progress_count=$TOTAL_COUNT
        percent='100%'
    else
        percent="$((200*(progress_count+1)/(TOTAL_COUNT+1)%2+100*(progress_count+1)/(TOTAL_COUNT+1)))%"
    fi

    echo "$percent ($(ColourTextBrightWhite "$progress_count")/$(ColourTextBrightWhite "$TOTAL_COUNT"))"

    return 0

    } 2>/dev/null

ShowAsActionResult()
    {

    # $1 = tier (optional) e.g. `Standalone`, `Dependent`, `Addon`, `All`
    # $2 = package type: `QPKG`, `IPK`, `PIP`, etc ...
    # $3 = ok count
    # $4 = skip count
    # $5 = fail count
    # $6 = total count
    # $7 = verb (past)

    if [[ -n $1 && $1 != All ]]; then
        local -r TIER=" $(Lowercase "$1")"
    else
        local -r TIER=''
    fi

    local -r PACKAGE_TYPE=${2:?null}
    declare -i -r OK_COUNT=${3:-0}
    declare -i -r SKIP_COUNT=${4:-0}
    declare -i -r FAIL_COUNT=${5:-0}
    declare -i -r TOTAL_COUNT=${6:-0}
    local result_message="${7:?null} "

    if [[ $OK_COUNT -gt 0 ]]; then
        result_message+="${OK_COUNT}${TIER} ${PACKAGE_TYPE}$(Pluralise "$OK_COUNT") OK"
    fi

    if [[ $SKIP_COUNT -gt 0 ]]; then
        [[ $OK_COUNT -gt 0 ]] && result_message+=', '
        result_message+="${SKIP_COUNT}${TIER} ${PACKAGE_TYPE}$(Pluralise "$SKIP_COUNT") skipped"
    fi

    if [[ $FAIL_COUNT -gt 0 ]]; then
        [[ $OK_COUNT -gt 0 || $SKIP_COUNT -gt 0 ]] && result_message+=' and '
        result_message+="${FAIL_COUNT}${TIER} ${PACKAGE_TYPE}$(Pluralise "$FAIL_COUNT") failed"
    fi

    case $TOTAL_COUNT in
        0)
            DebugAsDone "no${TIER} ${PACKAGE_TYPE}s processed"
            ;;
        "$FAIL_COUNT")
            ShowAsWarn "$result_message"
            ;;
        *)
            ShowAsDone "$result_message"
    esac

    return 0

    }

WriteToDisplayWait()
    {

    # Writes a new message without newline

    # input:
    #   $1 = pass/fail
    #   $2 = message

    # output:
    #   $previous_msg = global and will be used again later

    if [[ $colourful = true ]]; then
        previous_msg=$(printf '%-10s: %s' "${1:-}" "${2:-}")    # allow extra length for ANSI codes
    else
        previous_msg=$(printf '%-4s: %s' "${1:-}" "${2:-}")
    fi

    DisplayWait "$previous_msg"

    return 0

    }

WriteToDisplayNew()
    {

    # Updates the previous message

    # input:
    #   $1 = pass/fail
    #   $2 = message

    # output:
    #   stdout = overwrites previous message with updated message
    #   $previous_length

    local this_message=''
    local strbuffer=''
    local -i this_length=0
    local -i blanking_length=0

    if [[ $colourful = true ]]; then
        this_message=$(printf '%-10s: %s' "${1:-}" "${2:-}")    # allow extra length for ANSI codes
    else
        this_message=$(printf '%-4s: %s' "${1:-}" "${2:-}")
    fi

    if [[ $this_message != "${previous_msg:=''}" ]]; then
        previous_length=$((${#previous_msg}+1))
        this_length=$((${#this_message}+1))

        # jump to start of line, print new msg
        strbuffer=$(echo -en "\r$this_message ")

        # if new msg is shorter then add spaces to end to cover previous msg
        if [[ $this_length -lt $previous_length ]]; then
            blanking_length=$((this_length-previous_length))
            strbuffer+=$(printf "%${blanking_length}s")
        fi

        Display "$strbuffer"
    fi

    return 0

    }

WriteToLog()
    {

    # input:
    #   $1 = pass/fail
    #   $2 = message

    [[ -n ${sess_active_pathfile:-} ]] && printf '%-4s: %s\n' "$(StripANSI "${1:-}")" "$(StripANSI "${2:-}")" >> "$sess_active_pathfile"

    }

ColourTextBrightGreen()
    {

    if [[ $colourful = true ]]; then
        echo -en '\033[1;32m'"$(ColourReset "${1:-}")"
    else
        echo -n "${1:-}"
    fi

    } 2>/dev/null

ColourTextBrightYellow()
    {

    if [[ $colourful = true ]]; then
        echo -en '\033[1;33m'"$(ColourReset "${1:-}")"
    else
        echo -n "${1:-}"
    fi

    } 2>/dev/null

ColourTextBrightOrange()
    {

    if [[ $colourful = true ]]; then
        echo -en '\033[1;38;5;214m'"$(ColourReset "${1:-}")"
    else
        echo -n "${1:-}"
    fi

    } 2>/dev/null

ColourTextBrightOrangeBlink()
    {

    if [[ $colourful = true ]]; then
        echo -en '\033[1;5;38;5;214m'"$(ColourReset "${1:-}")"
    else
        echo -n "${1:-}"
    fi

    } 2>/dev/null

ColourTextBrightRed()
    {

    if [[ $colourful = true ]]; then
        echo -en '\033[1;31m'"$(ColourReset "${1:-}")"
    else
        echo -n "${1:-}"
    fi

    } 2>/dev/null

ColourTextBrightRedBlink()
    {

    if [[ $colourful = true ]]; then
        echo -en '\033[1;5;31m'"$(ColourReset "${1:-}")"
    else
        echo -n "${1:-}"
    fi

    } 2>/dev/null

ColourTextUnderlinedCyan()
    {

    if [[ $colourful = true ]]; then
        echo -en '\033[4;36m'"$(ColourReset "${1:-}")"
    else
        echo -n "${1:-}"
    fi

    } 2>/dev/null

ColourTextBlackOnCyan()
    {

    if [[ $colourful = true ]]; then
        echo -en '\033[30;46m'"$(ColourReset "${1:-}")"
    else
        echo -n "${1:-}"
    fi

    } 2>/dev/null

ColourTextBrightWhite()
    {

    if [[ $colourful = true ]]; then
        echo -en '\033[1;97m'"$(ColourReset "${1:-}")"
    else
        echo -n "${1:-}"
    fi

    } 2>/dev/null

ColourReset()
    {

    echo -en "${1:-}"'\033[0m'

    } 2>/dev/null

StripANSI()
    {

    # QTS 4.2.6 BusyBox `sed` doesn't fully support extended regexes, so code stripping only works with a real `sed`

    if [[ -e $GNU_SED_CMD && -e $GNU_SED_CMD ]]; then   # KLUDGE: yes, it looks weird, but during Entware startup, weird things happen. Need to check for this file multiple times to ensure it's there before attempting to run it.
        $GNU_SED_CMD -r 's/\x1b\[[0-9;]*m//g' <<< "${1:-}"
    else
        echo "${1:-}"           # can't strip, so pass thru original message unaltered
    fi

    } 2>/dev/null

LaunchQPKGActionForks
