#!/usr/bin/env bash

# construct a list of all QPKG checksum files
echo 'locating checksum files ...'
find ~/scripts/nas -name '*.qpkg.md5' > /tmp/raw.md5s

# sort this list, grouped by package names, most-recent package name version at the top of each group.
echo 'sorting file list ...'
sort --version-sort --reverse < /tmp/raw.md5s > /tmp/sorted.md5s
rm --recursive /tmp/raw.md5s

checksum_pathfilename=''
checksum_version=''
checksum_arch=''
previous_checksum_filename=''
previous_package_name=''
previous_checksum_version=''
previous_checksum_arch=''
match=false

echo '---------- results -----------'
echo 'highest package version found:'
printf '%-36s %-14s %-10s %s\n' pathfilename version arch md5

while read -r checksum_pathfilename; do
    # need just filename
    checksum_filename=$(basename "$checksum_pathfilename")

    IFS='_' read -r package_name checksum_version checksum_arch tailend <<< "${checksum_filename//.qpkg.md5/}"

    [[ -n $tailend ]] && checksum_arch+=_$tailend
    [[ -z $checksum_arch ]] && checksum_arch=all
    checksum_md5=$(cut -f1 -d' ' <$checksum_pathfilename)

    if [[ $package_name != "$previous_package_name" ]]; then
        match=true
    elif [[ $checksum_version = $previous_checksum_version ]]; then
        if [[ $checksum_arch != $previous_checksum_arch ]]; then
            match=true
        fi
    else
        match=false
    fi

    if [[ $match = true ]]; then
        printf '%-36s %-14s %-10s %s\n' "$checksum_filename" "$checksum_version" "$checksum_arch" "$checksum_md5"
        previous_checksum_filename=$checksum_filename
        previous_package_name=$package_name
        previous_checksum_version=$checksum_version
        previous_checksum_arch=$checksum_arch
    fi
done < /tmp/sorted.md5s


# sed 's|<?version?>|230101|;s|<?md5?>|bc156789|' package.info
