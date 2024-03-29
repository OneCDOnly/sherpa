#!/usr/bin/env bash

. vars.source || exit

source_pathfile=$source_path/$management_source_file
target_func=''

# shellcheck disable=SC2013
for target_func in $(grep '()$' "$source_pathfile" | grep -v '=\|\$\|_(' | sed 's|()||g'); do
	case $target_func in
		IPKs:upgrade|IPKs:install|IPKs:downgrade|PIPs:install)		# called by constructing the function name with vars.
			continue
# 			;;
# 		QPKGs.Actions:ListAll|QPKGs.GrAll:Show|QPKG.GetAppAuthor)	# unused for-now.
# 			continue
	esac

	if [[ $(grep -ow "$target_func" < "$source_pathfile" | wc -l) -eq 1 ]]; then
		echo "$target_func()"
	fi
done

exit 0
