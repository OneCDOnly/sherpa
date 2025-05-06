#!/usr/bin/env bash

ConvertLongdateAsHuman()
	{

	# Convert 'YYYYMMDD' to a more human-friendly string.

	# Examples:
	# 	'20250101' to 'early-January 2025'.
	# 	'20250115' to 'mid-January 2025'.
	# 	'20250130' to 'late-January 2025'.

	# Inputs: (local)
	#	$1 = longdatecode in the format 'YYYYMMDD'. Example: '20240928' with 8 digits.

	# Outputs: (local)
	#	stdout = string conversion.

	[[ -n ${1:-} ]] || return

	local a=${1//[!0-9]/}	# Strip non-digits.

	if [[ ${#a} -ne 8 ]]; then
		printf 'invalid longdate code length'
		return 1
	fi

	local b=${a:6:2}
	local c=''

	if ((b >= 1 && b <= 10)); then
		c=early
	elif ((b >= 11 && b <= 20)); then
		c=mid
	elif ((b >= 21 && b <= 31)); then
		c=late
	else
		printf 'invalid day code'
		return 1
	fi

	local d=${a:4:2}

	if ((d < 1 || d > 12)); then
		printf 'invalid month code'
		return 1
	fi

	printf '%s-%s %s' "$c" "$(/usr/bin/date -d 2025-$d-01 '+%B')" "${a::4}"

	}

echo $(ConvertLongdateAsHuman 20240615)
