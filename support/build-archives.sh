#!/usr/bin/env bash

# compiler for sherpa management archives.

. vars.source || exit

echo -n 'building archives ... '

declare -a a
declare -a b
declare -i i=0

a+=("$support_path/$objects_file")
b+=("$root_path/$objects_archive_file")

# a+=("$qpkgs_support_path/$packages_file")
# b+=("$qpkgs_root_path/$packages_archive_file")

a+=("$support_path/$management_file")
b+=("$root_path/$management_archive_file")

for i in "${!a[@]}"; do
	[[ -e ${b[i]} ]] && rm -f "${b[i]}"

	if [[ ! -e ${a[i]} ]]; then
		ColourTextBrightRed "'${a[i]}' not found, "
		continue
	fi

	tar --create --gzip --numeric-owner --file="${b[i]}" --directory="$support_path" "$(basename "${a[i]}")"

	if [[ ! -s ${b[i]} ]]; then
		ColourTextBrightRed "'${b[i]}' was not written"; echo
		exit 1
	fi

	[[ -e ${a[i]} ]] && rm -f "${a[i]}"
	chmod 444 "${b[i]}"
done

ShowDone
exit 0
