#!/usr/bin/env bash

# construct a list of all QPKG checksum files
echo 'locating checksum files ...'
find ~/scripts/nas -name '*.qpkg.md5' > /tmp/raw.md5s

# sort this list, grouped by package names, most-recent package name version at the bottom of each group.
echo 'sorting file list ...'
sort -V < /tmp/raw.md5s > /tmp/sorted.md5s          # try sorting in reverse order. Then latest version will be first. Should be easier to read other arches with same version.
rm -r /tmp/raw.md5s

checksum_pathfilename=''
package_version=''
checksum_arch=''
previous_checksum_name=''
previous_checksum_version=''
previous_checksum_filename=''
previous_checksum_pathfilename=''
previous_checksum_arch=''
previous_checksum_md5=''

echo '---------- results -----------'
echo 'highest package version found:'
printf '%-36s %-14s %-10s %s\n' pathfilename version arch md5

while read -r checksum_pathfilename; do
    # need just filename
    checksum_filename=$(basename "$checksum_pathfilename")

    IFS='_' read -r package_name package_version checksum_arch tailend <<< "${checksum_filename//.qpkg.md5/}"

    [[ -n $tailend ]] && checksum_arch+=_$tailend
    [[ -z $checksum_arch ]] && checksum_arch=all

    if [[ $package_name != "$previous_checksum_name" ]]; then
        if [[ -n $previous_checksum_filename ]]; then
            printf '%-36s %-14s %-10s %s\n' "$previous_checksum_filename" "$previous_checksum_version" "$previous_checksum_arch" "$previous_checksum_md5"
            displayed=true
        fi
    fi

    previous_checksum_name=$package_name
    previous_checksum_filename=$checksum_filename
    previous_checksum_pathfilename=$checksum_pathfilename
    previous_checksum_version=$package_version
    previous_checksum_arch=$checksum_arch
    previous_checksum_md5=$(cut -f1 -d' ' <$checksum_pathfilename)
    displayed=false
done < /tmp/sorted.md5s

[[ $displayed = false ]] && printf '%-36s %-14s %-10s %s\n' "$previous_checksum_filename" "$previous_checksum_version" "$previous_checksum_arch" "$previous_checksum_md5"

# sed 's|<?version?>|230101|;s|<?md5?>|bc156789|' package.info
