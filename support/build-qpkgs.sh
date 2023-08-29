#!/usr/bin/env bash

# jump into each QPKG base dir
# check './build' path and find most-recent .qpkg file to use as a datetime reference.
# check last changed datetime of all QPKG files, and if any are newer than the reference file, update date tags and run a 'qbuild'.

if [[ ! -e vars.source ]]; then
	echo "'vars.source' not found"
	exit 1
fi

. ./vars.source

SwapTags()
	{

	# input:
	# 	$1 = input pathfile to process for tags. This always has a '.source' extension.
	# 	$2 = output pathfile and extension

	# output:
	# 	$? = 0

	if [[ -f "$1" ]]; then			# ignore symlinks
		local buffer=$(<"$1")

		buffer=$(sed "s|<?dontedit?>|$dontedit_msg|" <<< "$buffer")
		buffer=$(sed "s|<?thisdate?>|$thisdate|" <<< "$buffer")
		buffer=$(sed "s|<?thisyear?>|$thisyear|" <<< "$buffer")

		echo "$buffer" > "$2"
	fi

	}

source_pathfile="$source_path/$service_library_source_file"
target_pathfile="$source_path/$service_library_file"
datetime_change_reference_pathfile="$target_pathfile"
rebuild_functions=false
rebuilt_functions=false

if [[ -e $datetime_change_reference_pathfile ]]; then
	if [[ -n $(find -L "$source_pathfile" -cnewer "$datetime_change_reference_pathfile") ]]; then
		echo "service library source: updated"
		rebuild_functions=true
	else
		echo "service library: not newer than reference file"
	fi
else
	echo "datetime reference file: not found, so must build service library"
	rebuild_functions=true
fi

if [[ $rebuild_functions = true ]]; then
	SwapTags "$source_pathfile" "$target_pathfile"

	if [[ -s "$target_pathfile" ]]; then
		echo "service library: rebuilt"
		rebuilt_functions=true
	fi
fi

for d in "$qpkgs_path"/*; do
	echo -e "\n$(ColourTextBrightWhite 'QPKG:') $(basename "$d")"
	config_source_pathfile="$d/qpkg.source"

	if [[ ! -e $config_source_pathfile ]]; then
		echo "config source: not found"
		echo "rebuild: not possible"
		continue
	fi

	config_pathfile="$d/qpkg.cfg"
	rebuild_package=false

	if [[ $rebuilt_functions = true ]]; then		# only need to rebuild QPKGs using the service functions library
		if [[ -n $(find -L "$d" -type f -iname "$service_library_file") ]]; then
			echo "service library: link found, and functions have been updated, so must rebuild this QPKG"
			rebuild_package=true
		else
			echo "service library: no link"
		fi
	else
		datetime_change_reference_file="$(cd "$d/build" || exit; ls -t1 --reverse | tail -n1)"

		if [[ -n $datetime_change_reference_file ]]; then
			echo "datetime reference file: $datetime_change_reference_file"
			datetime_change_reference_pathfile="$d/build/$datetime_change_reference_file"
		else
			echo "datetime reference file: unspecified"
			rebuild_package=true
		fi
	fi

	if [[ $rebuild_package = false ]]; then
		if [[ -e $datetime_change_reference_pathfile ]]; then
			changed_file_list="$(find -L "$d" ! -type d -cnewer "$datetime_change_reference_pathfile")"

			if [[ -n $changed_file_list ]]; then
				echo "package files: changed"
# 				echo "file(s) more recent than reference file: $changed_file_list"
				rebuild_package=true
			else
				echo "package files: not newer than reference file"
			fi
		else
			echo "datetime reference file: not found"
			rebuild_package=true
		fi
	fi

	if [[ $rebuild_package = false ]]; then
		echo "rebuild: not required"
		continue
	fi

	SwapTags "$config_source_pathfile" "$config_pathfile"

	if [[ ! -s "$config_pathfile" ]]; then
		echo "config file: missing"
		echo "rebuild: not possible"
		continue
	fi

	service_script_file=$(. $config_pathfile; echo "$QPKG_SERVICE_PROGRAM")

	if [[ -z $service_script_file ]]; then
		echo "service script file: unspecified"
		echo "rebuild: not possible"
		continue
	fi

	for test_path in shared arm_64 arm-x19 arm-x31 arm-x41 x86_64 x86; do
		SwapTags "$d/$test_path/${service_script_file%.*}.source" "$d/$test_path/$service_script_file"
	done

	(cd "$d" || exit; qbuild --exclude '*.source' &>/dev/null)
	echo "QPKG arches: rebuilt"
done
