#!/usr/bin/env bash

TranslateQPKGArch()
    {

    case $1 in
        i686|x86)
            echo x86
            ;;
        x86_64)
            echo x64
            ;;
        arm-x19)
            echo x19
            ;;
        arm-x31)
            echo x31
            ;;
        arm-x41)
            echo x41
            ;;
        arm_64)
            echo a64
            ;;
        all)
            echo all
            ;;
        *)
            echo none
    esac

    }

echo 'locating checksum files ...'
find ~/scripts/nas -name '*.qpkg.md5' > /tmp/raw.md5s

echo 'sorting file list in reverse ...'
sort --version-sort --reverse < /tmp/raw.md5s > /tmp/sorted.md5s
rm -f /tmp/raw.md5s

echo 'extracting highest version numbers ...'
rm -f /tmp/highest-version.lst
checksum_pathfilename=''
version=''
arch=''
md5=''
previous_checksum_filename=''
previous_package_name=''
previous_version=''
previous_arch=''

match=false

while read -r checksum_pathfilename; do
    # need just filename
    checksum_filename=$(basename "$checksum_pathfilename")
    qpkg_filename="${checksum_filename//.md5/}"

    IFS='_' read -r package_name version arch tailend <<< "${checksum_filename//.qpkg.md5/}"

    if [[ $arch = std ]]; then     # make an exception for Entware
        version+=_$arch
        arch=''
        tailend=''
    fi

    [[ -z $arch ]] && arch=all
    [[ -n $tailend ]] && arch+=_$tailend

    if [[ $package_name != "$previous_package_name" ]]; then
        match=true
    elif [[ $version = "$previous_version" ]]; then
        if [[ $arch != "$previous_arch" ]]; then
            match=true
        fi
    else
        match=false
    fi

    md5=$(cut -d' ' -f1 < "$checksum_pathfilename")

    if [[ $match = true ]]; then
        printf '%-36s %-30s %-20s %-12s %-6s %s\n' "$checksum_filename" "$qpkg_filename" "$package_name" "$version" "$(TranslateQPKGArch "$arch")" "$md5" >> /tmp/highest-version.lst
        previous_checksum_filename=$checksum_filename
        previous_package_name=$package_name
        previous_version=$version
        previous_arch=$arch
    fi
done < /tmp/sorted.md5s

rm -f /tmp/sorted.md5s

echo 'sorting by package name ...'
sort < /tmp/highest-version.lst > /tmp/final.lst
rm -f /tmp/highest-version.lst

# echo -e "\nfound $(wc -l /tmp/final.lst | cut -d' ' -f1) packages"
# echo '---------- highest package version found -----------'
# printf '%-36s %-30s %-20s %-12s %-6s %s\n' checksum_filename qpkg_filename package_name version arch md5
# cat /tmp/final.lst

echo 'updating package fields ...'
source=$(<packages.source)
source=$(sed "s|<?today?>|$(date '+%y%m%d')|" <<< "$source")

while read -r checksum_filename qpkg_filename package_name version arch md5; do
    source=$(sed "/QPKG_NAME+=($package_name)/,/QPKG_NAME+=/ s/<?version?>/$version/" <<< "$source")
    source=$(sed "/QPKG_NAME+=($package_name)/,/QPKG_NAME+=/ s/<?package_name?>/$package_name/" <<< "$source")
    source=$(sed "/QPKG_NAME+=($package_name)/,/QPKG_NAME+=/ s/<?qpkg_filename?>/$qpkg_filename/" <<< "$source")
    source=$(sed "/QPKG_NAME+=($package_name)/,/QPKG_NAME+=/ s/<?md5?>/$md5/" <<< "$source")
done < /tmp/final.lst

echo "$source" > packages.final

echo "done."
