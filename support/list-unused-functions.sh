#!/usr/bin/env bash

. vars.source || exit

a=$support_path/$management_source_file
b=''

# shellcheck disable=SC2013
for b in $(grep '()$' "$a" | grep -v '=\|\$\|_(' | sed 's|()||g'); do
	case $b in
		IPKs:upgrade|IPKs:install|IPKs:downgrade|PIPs:install)		# called by constructing the function name with vars.
			continue
# 			;;
# 		QPKGs.Actions:ListAll|QPKGs.GrAll:Show|QPKG.GetAppAuthor)	# unused for-now.
# 			continue
	esac

	if [[ $(grep -ow "$b" < "$a" | wc -l) -eq 1 ]]; then
		echo "$b()"
	fi
done

exit 0
