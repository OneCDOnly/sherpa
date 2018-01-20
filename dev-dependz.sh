#!/usr/bin/env bash

packages='gcc python python-pip python-cffi python-pyopenssl ca-certificates nano git git-http unrar p7zip ionice ffprobe'

for package in $packages; do
	echo "package: [$package]"
	resultmsg=$(opkg info $package)
	package_raw_dependancies=$(echo "$resultmsg" | LC_ALL=C grep 'Depends:' | sed 's|^Depends: ||')
	all_raw_packages+="$package $package_raw_dependancies "
done

# convert to array
IFS=', ' read -r -a all_required_packages_array <<<"$all_raw_packages"

# sort and uniq each package name
all_required_packages=($(printf '%s\n' "${all_required_packages_array[@]}" | sort | uniq))

echo
echo "all_required_packages: [${all_required_packages[@]}]"
echo

# how many have already been installed?
for element in ${all_required_packages[@]}; do
	(opkg info $element | LC_ALL=C grep 'Status: ' | LC_ALL=C grep -q 'not-installed') && { echo "to be installed: [$element]"; not_installed_packages+=($element) ;}
done

for element in ${not_installed_packages[@]}; do
	result_size=$(opkg info $element | grep 'Size:' | sed 's|^Size: ||')
	((not_installed_size+=result_size))
done

echo "total size to download: [$not_installed_size]"
