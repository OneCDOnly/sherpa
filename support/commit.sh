#!/usr/bin/env bash

# Input:
#	$1 = commit message (optional)
#	$1 = 'nocheck' (optional) = skip syntax check. Default is to perform syntax check before committing.

this_path=$PWD
. $HOME/scripts/nas/sherpa/support/vars.source || exit

cd "$support_path" || exit
./clean-source.sh
[[ ${1:-} != nocheck ]] && { ./check-syntax.sh || exit ;}

[[ -e $objects_file ]] && rm -f "$objects_file"
[[ -e $management_file ]] && rm -f "$management_file"
[[ -e $packages_file ]] && rm -f "$packages_file"

cd "$target_path" || exit

if [[ -z ${1:-} || ${1:-} = nocheck ]]; then
	git add . && git commit && git push || exit
else
	git add . && git commit -m "$1" && git push || exit
fi

cd "$this_path" || exit
