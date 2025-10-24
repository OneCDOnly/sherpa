#!/usr/bin/env bash

. $HOME/scripts/nas/sherpa/support/environment.sourced || exit

a=$support_path/$management_source_file
b=$support_path/$management_file
manager_epoch=$(date +%s)
package_release_version=$(cd "$qpkgs_root_path"; gh release view --json name --jq '.name')

SwapTags "$a" "$b"

if grep -q '<?\|?>' "$b"; then
	TextBrightRed "'$b' contains unswapped tags, can't continue"; echo
	exit 1
fi

Squeeze "$b" "$b"
[[ -e $b ]] && chmod 554 "$b"

exit 0
