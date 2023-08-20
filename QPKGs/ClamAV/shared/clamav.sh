#!/usr/bin/env bash
################################################################################################
# clamav.sh
#
# Copyright (C) 2021-2023 OneCD - one.cd.only@gmail.com
#
# so, blame OneCD if it all goes horribly wrong. ;)
#
# This is a type 4 service-script: https://github.com/OneCDOnly/sherpa/wiki/Service-Script-Types
#
# For more info: https://forum.qnap.com/viewtopic.php?f=320&t=132373
################################################################################################

readonly USER_ARGS_RAW=$*

Init()
	{

	# service-script environment
	readonly QPKG_NAME=ClamAV
	readonly SCRIPT_VERSION="230820"

	# general environment
	readonly QPKG_PATH=$(/sbin/getcfg $QPKG_NAME Install_Path -f /etc/config/qpkg.conf)
	readonly QPKG_VERSION=$(/sbin/getcfg $QPKG_NAME Version -d unknown -f /etc/config/qpkg.conf)
	readonly QPKG_CONFIG_PATH=$QPKG_PATH/config
	readonly QPKG_INI_PATHFILE=''
	readonly QPKG_INI_DEFAULT_PATHFILE=$QPKG_INI_PATHFILE.def
	readonly DAEMON_PID_PATHFILE=/var/run/$QPKG_NAME.pid
	readonly QPKG_REPO_PATH=''
	readonly PIP_CACHE_PATH=''
	readonly BACKUP_PATHFILE=''

	local re=''
	daemon_port=0
	ui_port=0
	ui_port_secure=0
	ui_listening_address=undefined
	service_operation=unspecified
	service_result=undefined

	# specific to online-sourced applications only
	readonly SOURCE_GIT_URL=''
	readonly SOURCE_ARCH=''
	readonly SOURCE_GIT_BRANCH=''
	# 'shallow' (depth 1) or 'single-branch' ... 'shallow' implies 'single-branch'
	readonly SOURCE_GIT_BRANCH_DEPTH=''
	readonly INTERPRETER=''
	readonly VENV_PATH=$QPKG_PATH/venv
	readonly VENV_PYTHON_PATHFILE=''
	readonly VENV_PIP_PATHFILE=''
	readonly ALLOW_ACCESS_TO_SYS_PACKAGES=true
	readonly INSTALL_PIP_DEPS=true

	# specific to Entware binaries only
	readonly TARGET_SERVICE_PATHFILE=/etc/init.d/antivirus.sh
	readonly BACKUP_SERVICE_PATHFILE=$TARGET_SERVICE_PATHFILE.bak

	# specific to daemonised applications only
	readonly DAEMON_PATHFILE=''
	readonly DAEMON_LAUNCH_CMD=''
	readonly RUN_DAEMON_IN_SCREEN_SESSION=false
	readonly DAEMON_PROC_IS_NAME_ONLY=false
	readonly PORT_CHECK_TIMEOUT_SECONDS=240
	readonly DAEMON_CHECK_TIMEOUT_SECONDS=60
	readonly DAEMON_STOP_TIMEOUT_SECONDS=120
	readonly RECHECK_DAEMON_PID_AFTER_LAUNCH=true
	readonly PIDFILE_APPEAR_TIMEOUT_SECONDS=60
	readonly PIDFILE_RECHECK_WAIT_SECONDS=10
	readonly PIDFILE_IS_MANAGED_BY_APP=true

	readonly GET_DAEMON_PORT_CMD=''
	readonly GET_UI_PORT_CMD=''
	readonly GET_UI_PORT_SECURE_CMD=''
	readonly GET_UI_PORT_SECURE_ENABLED_TEST_CMD=''
	readonly GET_UI_LISTENING_ADDRESS_CMD=''

	# specific to applications supporting version lookup only
	readonly APP_VERSION_PATHFILE=''
	readonly APP_VERSION_CMD=''

	}

readonly SERVICE_FUNCTIONS_PATHFILE="$(/usr/bin/dirname "$(/usr/bin/readlink "$0")")"/service-library.sh

if [[ -e $SERVICE_FUNCTIONS_PATHFILE ]]; then
	. $SERVICE_FUNCTIONS_PATHFILE
else
	printf '\033[1;31m%s\033[0m: %s\n' 'derp' "sherpa service function library not found, can't continue."
	exit 1
fi

StartQPKG()
	{

	IsError && return
	MakePaths
	WaitForGit || { SetError; return 1 ;}

	if [[ ! -e $BACKUP_SERVICE_PATHFILE ]]; then
		cp "$TARGET_SERVICE_PATHFILE" "$BACKUP_SERVICE_PATHFILE"

		# mod base references
		/bin/sed -i 's|/usr/local/bin/clamscan|/opt/sbin/clamscan|' "$TARGET_SERVICE_PATHFILE"
		/bin/sed -i 's|/usr/local/bin/freshclam|/opt/sbin/freshclam|' "$TARGET_SERVICE_PATHFILE"

		# disable dryrun. The new ClamAV engine (0.102.4) doesn't support the '--dryrun' or '--countfile=' options.
		# match second occurrence only. First one is used by Mcafee. Solution here: https://unix.stackexchange.com/a/403272
		/bin/sed -i ':a;N;$!ba; s|/bin/sh -c "$AV_SCAN_PATH $DRY_RUN_OPTIONS --dryrun|#/bin/sh -c "$AV_SCAN_PATH $DRY_RUN_OPTIONS --dryrun|2' "$TARGET_SERVICE_PATHFILE"

		# mod 'clamscan' runtime options
		# match second occurrence only. First one is used by Mcafee.
		/bin/sed -i ':a;N;$!ba; s|OPTIONS="$OPTIONS --countfile=/tmp/antivirous.job.$job_id.scanning"|OPTIONS="$OPTIONS --database=$ANTIVIRUS_CLAMAV"|2' "$TARGET_SERVICE_PATHFILE"

		# mod 'freshclam' runtime options
		/bin/sed -i 's|$FRESHCLAM -u admin -l /tmp/.freshclam.log|$FRESHCLAM -u admin --config-file=$FRESHCLAM_CONFIG --datadir=$ANTIVIRUS_CLAMAV -l /tmp/.freshclam.log|' "$TARGET_SERVICE_PATHFILE"

		eval "$TARGET_SERVICE_PATHFILE" restart &>/dev/null
	fi

	/bin/grep -q freshclam /etc/profile || echo "alias freshclam='/opt/sbin/freshclam -u admin --config-file=/etc/config/freshclam.conf --datadir=/share/$(/sbin/getcfg Public path -f /etc/config/smb.conf | cut -d '/' -f 3)/.antivirus/usr/share/clamav -l /tmp/.freshclam.log'" >> /etc/profile

	DisplayCommitToLog 'start: OK'

	return 0

	}

StopQPKG()
	{

	IsError && return

	if [[ -e $BACKUP_SERVICE_PATHFILE ]]; then
		mv "$BACKUP_SERVICE_PATHFILE" "$TARGET_SERVICE_PATHFILE"

		eval "$TARGET_SERVICE_PATHFILE" restart &>/dev/null
	fi

	/bin/sed -i '/freshclam/d' /etc/profile
	DisplayCommitToLog 'stop: OK'

	return 0

	}

StatusQPKG()
	{

	IsNotError || return
	IsPackageActive && exit 0 || exit 1

	}

ProcessArgs
