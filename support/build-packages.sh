#!/usr/bin/env bash

working_path=$HOME/scripts/nas/sherpa

source_pathfile=$working_path/support/packages.source
target_pathfile=$working_path/packages

dontedit_msg=" do not edit this file - it should only be built with the '$(basename "$0")' script"
branch=$(<"$working_path"/support/branch.txt)
buffer=$(<"$source_pathfile")

highest_package_versions_found_pathfile=$working_path/support/highest_package_versions_found.raw
highest_package_versions_found_sorted_pathfile=$working_path/support/highest_package_versions_found.tbl

checksum_pathfilename=''
checksum_filename=''
qpkg_filename=''
package_name=''
version=''
arch=''
md5=''
previous_package_name=''
previous_version=''
previous_arch=''
match=false

TranslateQPKGArch()
    {

    # translate arch from QPKG filename to sherpa

    case $1 in
        i686|x86)
            echo i86
            ;;
        x86_64)
            echo i64
            ;;
        arm-x19)
            echo a19
            ;;
        arm-x31)
            echo a31
            ;;
        arm-x41)
            echo a41
            ;;
        arm_64)
            echo a64
            ;;
        '')
            echo all
            ;;
        *)
            echo "$1"       # passthru
    esac

    }

echo -n 'locating QPKG checksum files ... '
raw=$(find $HOME/scripts/nas -name '*.qpkg.md5')
echo 'done'

sorted=$(sort --version-sort --reverse <<< "$raw")

echo -n 'extracting highest QPKG version numbers ... '

while read -r checksum_pathfilename; do
    # need just filename
    checksum_filename=$(basename "$checksum_pathfilename")
    qpkg_filename="${checksum_filename//.md5/}"

    IFS='_' read -r package_name version arch tailend <<< "${checksum_filename//.qpkg.md5/}"

    if [[ $arch = std ]]; then     # make an exception for Entware
        arch=''
        tailend=''
    fi

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
        printf '%-36s %-32s %-20s %-12s %-6s %s\n' "$checksum_filename" "$qpkg_filename" "$package_name" "$version" "$(TranslateQPKGArch "$arch")" "$(cut -d' ' -f1 < "$checksum_pathfilename")"
        previous_package_name=$package_name
        previous_version=$version
        previous_arch=$arch
    fi
done <<< "$sorted" > "$highest_package_versions_found_pathfile"

echo 'done'

echo -n 'updating QPKG fields ... '

buffer=$(sed "s|<?dontedit?>|$dontedit_msg|" <<< "$buffer")
buffer=$(sed "s|<?today?>|$(date '+%y%m%d')|" <<< "$buffer")
buffer=$(sed "s|<?branch?>|$branch|" <<< "$buffer")

while read -r checksum_filename qpkg_filename package_name version arch md5; do
    for attribute in version package_name qpkg_filename md5; do
        buffer=$(sed "/QPKG_NAME+=($package_name)/,/^$/{/QPKG_ARCH+=($arch)/,/$attribute.*/s/<?$attribute?>/${!attribute}/}" <<< "$buffer")
    done
done <<< "$(sort "$highest_package_versions_found_pathfile")"

buffer=$(sed "/^$/d" <<< "$buffer")                                                     # remove empty lines
buffer=$(sed -e '/^[[:space:]]*# /d;s/[[:space:]]#[[:space:]].*//' <<< "$buffer")       # remove comment lines and line comments

echo 'done'

echo -n "building 'packages' ... "

[[ -e $target_pathfile ]] && rm -f "$target_pathfile"
echo "$buffer" > "$target_pathfile"
chmod 444 "$target_pathfile"

echo 'done'

# sort for easier viewing
printf '%-36s %-32s %-20s %-12s %-6s %s\n%s\n' '# checksum_filename' qpkg_filename package_name version arch md5 "$(sort "$highest_package_versions_found_pathfile")" > "$highest_package_versions_found_sorted_pathfile"
rm -f "$highest_package_versions_found_pathfile"

exit 0
