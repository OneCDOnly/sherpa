#!/usr/bin/env bash

if [[ ! -e vars.source ]]; then
	echo "'vars.source' not found"
	exit 1
fi

. ./vars.source

echo -n 'building management script ... '

source_pathfile="$source_path"/sherpa.manager.source
target_pathfile="$source_path"/sherpa.manager.sh

buffer=$(<"$source_pathfile")

buffer=$(sed "s|<?dontedit?>|$dontedit_msg|" <<< "$buffer")
buffer=$(sed "s|<?year?>|$year|" <<< "$buffer")
buffer=$(sed "s|<?today?>|$today|" <<< "$buffer")
buffer=$(sed "s|<?branch?>|$branch|" <<< "$buffer")
buffer=$(sed "s|<?cdn_sherpa_url?>|$cdn_sherpa_url|" <<< "$buffer")

buffer=$(sed -e '/^#[[:space:]].*/d;s/[[:space:]]#[[:space:]].*//' <<< "$buffer")		# remove comment lines and line comments
buffer=$(sed -e 's/^[[:space:]]*//' <<< "$buffer")										# remove leading whitespace
buffer=$(sed 's/[[:space:]]*$//' <<< "$buffer")											# remove trailing whitespace
buffer=$(sed "/^$/d" <<< "$buffer")														# remove empty lines
buffer=$(sed "s|Content-Transfer-Encoding: base64|Content-Transfer-Encoding: base64\n|" <<< "$buffer")	# need to add a newline after this string so signature block is accepted by QTS

[[ -e $target_pathfile ]] && rm -f "$target_pathfile"
echo "$buffer" > "$target_pathfile"

if [[ ! -e $target_pathfile ]]; then
	ColourTextBrightRed "'$target_pathfile' was not written to disk\n"
	exit 1
fi

chmod 554 "$target_pathfile"

ColourTextBrightGreen 'done\n'
exit 0
