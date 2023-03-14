#!/usr/bin/env bash

# a parser for pyLoad config files

GetPyloadConfig()
	{

	# input:
	#   $1 = pathfilename to read from
	#   $2 = section name
	#   $3 = variable name to return value for

	# output:
	#	$? = 0 : variable found
	#	$? = 1 : file/section/variable not found
	#	stdout = variable value

	local source_pathfile=${1:?no pathfilename supplied}
	local target_section_name=${2:?no section supplied}
	local target_var_name=${3:?no variable supplied}

	[[ -e $source_pathfile ]] || return

	local result_line=''
	local -i line_num=0
	local section_raw=''
	local blank=''
	local section_description=''
	local section_name=''
	local -i start_line_num=0
	local target_section=''
	local end_line_num='$'

	local raw_var_type=''
	local raw_var_description=''
	local value_raw=''
	local var_type=''
	local value=''

	local var_found=false

	while read -r result_line; do
		IFS=':' read -r line_num section_raw <<< "$result_line"
		IFS=' ' read -r section_name blank section_description <<< "$section_raw"

		if [[ $section_name = $target_section_name ]]; then
			[[ $start_line_num -eq 0 ]] && start_line_num=$((line_num+1))
		else
			if [[ $start_line_num -ne 0 ]]; then
				end_line_num=$((line_num-2))
				break
			fi
		fi
	done <<< "$(grep '.*:$' -n "$source_pathfile")"

	if [[ $start_line_num -eq 0 ]]; then
		echo 'section match not found'
		return 1
	fi

	target_section=$(sed -n "${start_line_num},${end_line_num}p" "$source_pathfile")

	while read -r section_line; do
		IFS=':' read -r raw_var_type raw_var_description <<< "$section_line"
		read -r var_type var_name <<< "$raw_var_type"

		[[ $var_name != $target_var_name ]] && continue

		var_found=true
		IFS='"' read -r blank var_description value_raw <<< "$raw_var_description"
		IFS='=' read -r blank value <<< "$value_raw"
		value=${value% }; value=${value# }
		break
	done <<< "$target_section"

	if [[ $var_found = false ]]; then
		echo 'variable match not found'
		return 1
	fi

	echo "$value"

	}

# result=$(GetPyloadConfig pyload.cfg.def webui host)
# result=$(GetPyloadConfig pyload.cfg.def download ipv6)
result=$(GetPyloadConfig pyload.cfg.def webui port)

if [[ $? -ne 0 ]]; then
	echo "failed: '$result'"
else
	echo "ok: '$result'"
fi

exit
