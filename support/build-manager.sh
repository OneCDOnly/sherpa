#!/usr/bin/env bash

if [[ ! -e vars.source ]]; then
	echo "'vars.source' not found"
	exit 1
fi

. ./vars.source

cdn_onecd_url='https://raw.githubusercontent.com/OneCDOnly'
cdn_sherpa_url="$cdn_onecd_url/sherpa/${1:-$unstable_branch}"
cdn_sherpa_packages_url="$cdn_sherpa_url/QPKGs/<?package_name?>/build"
cdn_qnap_dev_packages_url='https://github.com/qnap-dev/<?package_name?>/releases/download/v<?version?>'
cdn_other_packages_url="$cdn_onecd_url/<?package_name?>/main/build"

source_pathfile="$source_path/$management_source_file"
target_pathfile="$source_path/$management_file"

SwapTags "$source_pathfile" "$target_pathfile"
Squeeze "$target_pathfile" "$target_pathfile"

[[ -e $target_pathfile ]] && chmod 554 "$target_pathfile"

exit 0
