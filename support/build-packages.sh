#!/usr/bin/env bash

if [[ ! -e vars.source ]]; then
	echo "'vars.source' not found"
	exit 1
fi

. ./vars.source

cdn_onecd_url='https://raw.githubusercontent.com/OneCDOnly'
cdn_sherpa_url="$cdn_onecd_url/sherpa/${1:-$unstable_branch}"
cdn_sherpa_packages_url="$cdn_sherpa_url/QPKGs/<?package_name?>/build"
cdn_qnap_dev_packages_url='https://github.com/qnap-dev/<?package_name?>/releases/download/v<?version?>'
cdn_other_packages_url="$cdn_onecd_url/<?package_name?>/main/build"

source_pathfile="$source_path/$packages_source_file"
target_pathfile="$source_path/$packages_file"

buffer=$(<"$source_pathfile")

highest_package_versions_found_pathfile="$source_path"/highest_package_versions_found.raw
highest_package_versions_found_sorted_pathfile="$source_path"/highest_package_versions_found.tbl

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

	# translate arch from QPKG filename to sherpa.

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
			echo "$1"		# passthru
	esac

	}

echo -n 'locating QPKG checksum files ... '
raw=$(find "$checksum_root_path" -name '*.qpkg.md5')

ShowDone

sorted=$(sort --version-sort --reverse <<< "$raw")

echo -n 'extracting highest QPKG version numbers ... '

while read -r checksum_pathfilename; do
	checksum_filename=$(basename "$checksum_pathfilename")
	qpkg_filename="${checksum_filename//.md5/}"

	IFS='_' read -r package_name version arch tailend <<< "${checksum_filename//.qpkg.md5/}"

	if [[ $arch = std ]]; then     			# an exception for Entware.
		arch=''
		tailend=''
	fi

	[[ -n $tailend ]] && arch+=_$tailend

	if [[ ${version##*.} = zip ]]; then		# an exception for QDK.
		version=${version%.*}
	fi

	if [[ ${qpkg_filename: -9} = .zip.qpkg ]]; then		# another exception for QDK.
		qpkg_filename=${qpkg_filename%.*}
	fi

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
done <<< "$sorted" | uniq > "$highest_package_versions_found_pathfile"

ShowDone

[[ -e $target_pathfile ]] && chmod +w "$target_pathfile"
echo "$buffer" > "$target_pathfile"
SwapTags "$source_pathfile" "$target_pathfile"
buffer=$(<"$target_pathfile")

echo -n 'updating QPKG fields ... '

buffer=$(sed "s|<?cdn_sherpa_packages_url?>|$cdn_sherpa_packages_url|" <<< "$buffer")
buffer=$(sed "s|<?cdn_qnap_dev_packages_url?>|$cdn_qnap_dev_packages_url|" <<< "$buffer")
buffer=$(sed "s|<?cdn_other_packages_url?>|$cdn_other_packages_url|" <<< "$buffer")

while read -r checksum_filename qpkg_filename package_name version arch md5; do
	for attribute in version package_name qpkg_filename md5; do
		buffer=$(sed "/QPKG_NAME+=($package_name)/,/^$/{/QPKG_ARCH+=($arch)/,/$attribute.*/s/<?$attribute?>/${!attribute}/}" <<< "$buffer")

		if [[ $package_name = QDK && $attribute = version ]]; then
			# run this a second time as there are 2 version placeholders in packages.source for QDK.
			buffer=$(sed "/QPKG_NAME+=($package_name)/,/^$/{/QPKG_ARCH+=($arch)/,/$attribute.*/s/<?$attribute?>/${!attribute}/}" <<< "$buffer")
		fi
	done
done <<< "$(sort "$highest_package_versions_found_pathfile")"

ShowDone

echo -n "building 'packages' file ... "

echo "$buffer" > "$target_pathfile"

if [[ ! -e $target_pathfile ]]; then
	ColourTextBrightRed "'$target_pathfile' was not written to disk"; echo
	exit 1
else
	ShowDone
fi

Squeeze "$target_pathfile" "$target_pathfile"
[[ -f $target_pathfile ]] && chmod 444 "$target_pathfile"

# sort and add header line for easier viewing.

[[ -f $highest_package_versions_found_sorted_pathfile ]] && chmod 644 "$highest_package_versions_found_sorted_pathfile"
printf '%-36s %-32s %-20s %-12s %-6s %s\n%s\n' '# checksum_filename' qpkg_filename package_name version arch md5 "$(sort "$highest_package_versions_found_pathfile")" > "$highest_package_versions_found_sorted_pathfile"

rm -f "$highest_package_versions_found_pathfile"
[[ -f $highest_package_versions_found_sorted_pathfile ]] && chmod 444 "$highest_package_versions_found_sorted_pathfile"

exit 0
