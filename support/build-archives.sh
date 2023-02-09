#!/usr/bin/env bash

# compiler for all sherpa archives

echo -n 'building archives ... '

working_path=$HOME/scripts/nas/sherpa

objects_pathfile=$working_path/objects
objects_archive_pathfile=$working_path/objects.tar.gz

packages_pathfile=$working_path/packages
packages_archive_pathfile=$working_path/packages.tar.gz

manager_pathfile=$working_path/sherpa.manager.sh
manager_archive_pathfile=$working_path/sherpa.manager.tar.gz

[[ -e $objects_archive_pathfile ]] && rm -f "$objects_archive_pathfile"
[[ -e $packages_archive_pathfile ]] && rm -f "$packages_archive_pathfile"
[[ -e $manager_archive_pathfile ]] && rm -f "$manager_archive_pathfile"

tar --create --gzip --numeric-owner --file="$objects_archive_pathfile" --directory="$working_path" "$(basename "$objects_pathfile")"
tar --create --gzip --numeric-owner --file="$packages_archive_pathfile" --directory="$working_path" "$(basename "$packages_pathfile")"
tar --create --gzip --numeric-owner --file="$manager_archive_pathfile" --directory="$working_path" "$(basename "$manager_pathfile")"

[[ -e $objects_pathfile ]] && rm -f "$objects_pathfile"
[[ -e $packages_pathfile ]] && rm -f "$packages_pathfile"
[[ -e $manager_pathfile ]] && rm -f "$manager_pathfile"

chmod 444 "$objects_archive_pathfile"
chmod 444 "$packages_archive_pathfile"
chmod 444 "$manager_archive_pathfile"

echo 'done'
exit 0
