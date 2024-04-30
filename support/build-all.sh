#!/usr/bin/env bash

. vars.source || exit

declare -a a
declare -i i=0

a+=("$support_path/$objects_file")
a+=("$support_path/$packages_file")
a+=("$support_path/$management_file")

for i in "${!a[@]}"; do
	[[ -e ${a[i]} ]] && rm -f "${a[i]}"
done

./build-qpkgs.sh sherpa || exit
./build-packages.sh || exit
./build-objects.sh || exit
./build-wiki-package-abbreviations.sh || exit
./build-manager.sh || exit
./build-archives.sh || exit
