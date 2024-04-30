#!/usr/bin/env bash

. vars.source || exit

a=$support_path/$management_source_file
b=$support_path/$management_file

SwapTags "$a" "$b"
Squeeze "$b" "$b"

[[ -e $b ]] && chmod 554 "$b"

exit 0
