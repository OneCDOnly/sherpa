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

echo -n 'locating QPKG checksum files ... '
raw=$(find ~/scripts/nas -name '*.qpkg.md5')
echo 'done!'

sorted=$(sort --version-sort --reverse <<< "$raw")

echo -n 'extracting highest QPKG version numbers ... '
checksum_pathfilename=''
qpkg_filename=''
version=''
arch=''
md5=''
previous_checksum_filename=''
previous_package_name=''
previous_version=''
previous_arch=''
match=false
highest=''

rm -f /tmp/highest.lst

while read -r checksum_pathfilename; do
    # need just filename
    checksum_filename=$(basename "$checksum_pathfilename")
    qpkg_filename="${checksum_filename//.md5/}"

    IFS='_' read -r package_name version arch tailend <<< "${checksum_filename//.qpkg.md5/}"

    if [[ $arch = std ]]; then     # make an exception for Entware
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

    if [[ $match = true ]]; then
        printf '%-36s %-30s %-20s %-12s %-6s %s\n' "$checksum_filename" "$qpkg_filename" "$package_name" "$version" "$(TranslateQPKGArch "$arch")" "$(cut -d' ' -f1 < "$checksum_pathfilename")" >> /tmp/highest.lst
        previous_checksum_filename=$checksum_filename
        previous_package_name=$package_name
        previous_version=$version
        previous_arch=$arch
    fi
done <<< "$sorted"
echo 'done!'

final=$(sort < /tmp/highest.lst)

echo -n 'updating QPKG fields ... '
source=$(<~/scripts/nas/sherpa/support/packages.source)
source=$(sed "s|<?today?>|$(date '+%y%m%d')|" <<< "$source")

while read -r checksum_filename qpkg_filename package_name version arch md5; do
    for attribute in version package_name qpkg_filename md5; do
        source=$(sed "/QPKG_NAME+=($package_name)/,/^$/{/QPKG_ARCH+=($arch)/,/$attribute.*/s/<?$attribute?>/${!attribute}/}" <<< "$source")
    done
done <<< "$final"

echo "$source" > ~/scripts/nas/sherpa/packages

echo 'done!'
