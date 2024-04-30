#!/usr/bin/env bash

# jump into each QPKG base dir.
# check './build' path and find most-recent .qpkg file to use as a datetime reference.
# check last changed datetime of all QPKG files, and if any are newer than the reference file, update date tags and run a 'qbuild'.

. vars.source || exit

rebuild_functions=false
rebuilt_functions=false
a=$support_path/$service_library_source_file
b=$support_path/$service_library_file
	c=$b

if [[ -e $c ]]; then
	if [[ -n $(find -L "$a" -newer "$c") ]]; then
		echo "service library source: modified"
		rebuild_functions=true
	else
		echo "service library: not newer than reference file"
	fi
else
	echo "datetime reference file: not found, so must build service library"
	rebuild_functions=true
fi

if [[ $rebuild_functions = true ]]; then
	SwapTags "$a" "$b" >/dev/null
	Squeeze "$b" "$b" >/dev/null
	[[ -f "$b" ]] && chmod 444 "$b"

	if [[ -s "$b" ]]; then
		echo "service library: $(ColourTextBrightGreen rebuilt)"
		rebuilt_functions=true
	fi
fi

for d in "$qpkgs_path"/*; do
	echo -e "\n$(ColourTextBrightWhite 'QPKG:') $(basename "$d")"
	config_source_pathfile=$d/qpkg.source

	if [[ ! -e $config_source_pathfile ]]; then
		echo "config source: not found"
		echo "rebuild: not possible"
		continue
	fi

	config_pathfile=$d/qpkg.cfg
	rebuild_package=false

	[[ $(basename "$d") = sherpa && ${1:-} = sherpa ]] && rebuild_package=true

	if [[ $rebuilt_functions = true ]]; then		# only need to rebuild QPKGs using the service functions library.
		if [[ -n $(find -L "$d" -type f -iname "$service_library_file") ]]; then
			echo "service library: link found, and functions have been updated, so must rebuild this QPKG"
			rebuild_package=true
		else
			echo "service library: no link"
		fi
	else
		a=$(cd "$d/build" || exit; ls -t1 --reverse | tail -n1)

		if [[ -n $a ]]; then
			echo "datetime reference file: '$a'"
			c=$d/build/$a
		else
			echo "datetime reference file: unspecified"
			rebuild_package=true
		fi
	fi

	if [[ $rebuild_package = false ]]; then
		if [[ -e $c ]]; then
			changed_file_list=$(find -L "$d" ! -type d -newer "$c")

			if [[ -n $changed_file_list ]]; then
				echo "package files: changed"
				echo "file(s) more recent than reference file: '$changed_file_list'"
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

	SwapTags "$config_source_pathfile" "$config_pathfile" >/dev/null

	if [[ ! -s "$config_pathfile" ]]; then
		echo "config file: missing"
		echo "rebuild: not possible"
		continue
	fi

	loader_script_file=$(. $config_pathfile; echo "$QPKG_LOADER_PROGRAM")
	service_script_file=$(. $config_pathfile; echo "$QPKG_SERVICE_PROGRAM")

	if [[ -z $service_script_file ]]; then
		echo "service script file: unspecified"
		echo "rebuild: not possible"
		continue
	fi

	for test_path in shared arm_64 arm-x19 arm-x31 arm-x41 x86_64 x86; do
		source=$d/$test_path/${service_script_file%.*}.source
		target=$d/$test_path/$service_script_file

		[[ -f "$source" ]] && chmod 644 "$source"
		SwapTags "$source" "$target" >/dev/null
		Squeeze "$target" "$target" >/dev/null
		[[ -f "$target" ]] && chmod 554 "$target"

		source=$d/$test_path/${loader_script_file%.*}.source
		target=$d/$test_path/$loader_script_file

		[[ -f "$source" ]] && chmod 644 "$source"
		SwapTags "$source" "$target" >/dev/null
		Squeeze "$target" "$target" >/dev/null
		[[ -f "$target" ]] && chmod 554 "$target"
	done

	(cd "$d" || exit; qbuild --exclude '*.source' &>/dev/null)
	echo "QPKG arches: $(ColourTextBrightGreen rebuilt)"
done

exit 0
