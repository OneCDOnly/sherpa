#!/usr/bin/env bash

# Inputs: (local)
#	$1 = commit message (optional)
#	$1 = 'nocheck' (optional) = skip syntax check. Default is to perform syntax check before committing.

this_path=$PWD
. $HOME/scripts/nas/sherpa/support/environment.sourced || exit

[[ -e $objects_file ]] && rm -f "$objects_file"
[[ -e $management_file ]] && rm -f "$management_file"

cd "$support_path" || exit
./clean-source.sh

if [[ ${1:-} != nocheck ]]; then
	./check-syntax.sh || exit
	./check-whitespace.sh || exit
fi

cd "$root_path" || exit

if [[ -z ${1:-} || ${1:-} = nocheck ]]; then
	git add . && git commit && git push || exit
else
	git add . && git commit -m "$1" && git push || exit
fi

cd "$this_path" || exit
