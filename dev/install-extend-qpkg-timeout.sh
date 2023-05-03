#!/usr/bin/env bash

. /etc/init.d/functions
FindDefVol

if [[ -z $DEF_VOLMP ]]; then
	echo 'No default volume has been set'
	exit 1
fi

echo "Default volume: '$DEF_VOLMP'"

scripts_path=$DEF_VOLMP/.system/autorun/scripts

if [[ ! -d $scripts_path ]]; then
	echo 'The autorun scripts path was not found'
	echo 'Have you run the create-autorun.sh script yet?'
	echo 'If not: curl -skL https://git.io/create-autorun | sudo bash'
	exit 1
fi

target_script_pathfile=$scripts_path/extend-qpkg-timeout.sh

if [[ -e $target_script_pathfile ]]; then
	echo 'Script to extend QPKG startup timeout already exists'
	exit 0
fi

/bin/cat > "$target_script_pathfile" << EOF
#!/usr/bin/env bash

/bin/sed -i 's|qpkg_service start|qpkg_service -t 1800 start|' /etc/init.d/services.sh
/bin/sed -i 's|qpkg_service start|qpkg_service -t 1800 start|' /etc/init.d/rcS_normal
/bin/sed -i 's|qpkg_service start|qpkg_service -t 1800 start|' /etc/init.d/rcS_normal_fast
EOF

if [[ ! -e $target_script_pathfile ]]; then
	echo 'Script file could not be created'
	exit 1
fi

/bin/chmod +x "$target_script_pathfile"

echo "'$(/usr/bin/basename "$target_script_pathfile")' has been added to your autorun system"

exit 0
