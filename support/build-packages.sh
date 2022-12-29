#!/usr/bin/env bash

# construct a list of all QPKG checksum files
echo 'locating checksum files ...'
find ~/scripts/nas -name '*.qpkg.md5' > /tmp/raw.md5s

# sort this list, grouped by package names, most-recent package name version at the bottom of each group.
echo 'sorting file list ...'
sort -V < /tmp/raw.md5s > /tmp/sorted.md5s
rm -r /tmp/raw.md5s

checksum_pathfilename=''
previous_package_name=''
previous_package_filename=''
previous_package_pathfilename=''
package_version=''
previous_package_version=''

echo '---------- results -----------'
echo 'highest package pathfilenames (version):'

while read -r checksum_pathfilename; do
    # need just filename
    filename=$(basename "$checksum_pathfilename")

    # then extract package name (everything from start of filename to first underscore will-do)
    package_name=${filename%%_*}

    # also need to extract package version here
    a=${filename#*_}
    b=${a%%_*}
    package_version=${b//.qpkg.md5/}

    # and package arch here

    if [[ $package_name != "$previous_package_name" ]]; then
        if [[ -n $previous_package_filename ]]; then
            echo "$previous_package_pathfilename ($previous_package_version)"
            displayed=true
        fi
    fi

    previous_package_name=$package_name
    previous_package_filename=$filename
    previous_package_pathfilename=$checksum_pathfilename
    previous_package_version=$package_version
    displayed=false
done < /tmp/sorted.md5s

[[ $displayed = false ]] && echo "$previous_package_pathfilename ($previous_package_version)"
