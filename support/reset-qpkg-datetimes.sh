#!/usr/bin/env bash

# Set all QPKG file change datetimes to that of current sherpa QPKG release file.
# 	Must also update datetime of sherpa function library files.
# 	Auto QPKG rebuilder should therefore ignore datetimes updated by git during 'git checkout'. However, all these files will need to be pushed again, as git will see them as modifid since last push.

. vars.source || exit

latest_release=$(git describe --tags "$(git rev-list --tags --max-count=1)" | tr --delete v)
latest_release_pathfile=$qpkgs_path/sherpa/build/sherpa_${latest_release}.qpkg

if [[ ! -e $latest_release_pathfile ]]; then
	echo "datetime reference file not found: '$latest_release_pathfile'"
	exit 1
fi

echo "latest release file: $latest_release_pathfile"

find "$target_path" -not -path '*/.*' -not -path '*/workshop*' -not -path '*/docs*' -not -path '*/support*' -not -name '*.tar.gz' -type f -exec touch {} -r "$latest_release_pathfile" \;

touch "$service_library_source_file" -r "$latest_release_pathfile"
touch "$service_library_file" -r "$latest_release_pathfile"

exit 0
