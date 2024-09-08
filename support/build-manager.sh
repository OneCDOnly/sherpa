#!/usr/bin/env bash

. vars.source || exit

a=$support_path/$management_source_file
b=$support_path/$management_file

SwapTags "$a" "$b"

if grep -q '<?\|?>' "$b"; then
	ColourTextBrightRed "'$b' contains unswapped tags, can't continue"; echo
	exit 1
fi

Squeeze "$b" "$b"
[[ -e $b ]] && chmod 554 "$b"

exit 0
