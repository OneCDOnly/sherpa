#!/usr/bin/env bash
################################################################################################
# otransmission.sh
#
# Copyright (C) 2020-2023 OneCD - one.cd.only@gmail.com
#
# so, blame OneCD if it all goes horribly wrong. ;)
#
# This is a type 3 service-script: https://github.com/OneCDOnly/sherpa/wiki/Service-Script-Types
#
# For more info: https://forum.qnap.com/viewtopic.php?f=320&t=132373
################################################################################################

readonly USER_ARGS_RAW=$*

Init()
	{

	IsQNAP || return

	# service-script environment
	readonly QPKG_NAME=OTransmission
	readonly SCRIPT_VERSION="230820"

	# general environment
	readonly QPKG_PATH=$(/sbin/getcfg $QPKG_NAME Install_Path -f /etc/config/qpkg.conf)
	readonly QPKG_VERSION=$(/sbin/getcfg $QPKG_NAME Version -d unknown -f /etc/config/qpkg.conf)
	readonly QPKG_CONFIG_PATH=$QPKG_PATH/config
	readonly QPKG_INI_PATHFILE=$QPKG_CONFIG_PATH/settings.json
	readonly QPKG_INI_DEFAULT_PATHFILE=$QPKG_INI_PATHFILE.def
	readonly DAEMON_PID_PATHFILE=/var/run/$QPKG_NAME.pid
	readonly QPKG_REPO_PATH=''
	readonly PIP_CACHE_PATH=''
	readonly BACKUP_PATHFILE=$BACKUP_PATH/$QPKG_NAME.config.tar.gz

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
	readonly SOURCE_GIT_BRANCH_DEPTH=''		# 'shallow' (depth 1) or 'single-branch' ... 'shallow' implies 'single-branch'
	readonly INTERPRETER=''
	readonly VENV_PATH=''
	readonly VENV_PYTHON_PATHFILE=''
	readonly VENV_PIP_PATHFILE=''
	readonly ALLOW_ACCESS_TO_SYS_PACKAGES=''
	readonly INSTALL_PIP_DEPS=''

	# specific to Entware binaries only
	readonly ORIG_DAEMON_SERVICE_SCRIPT=/opt/etc/init.d/S88transmission
	readonly TRANSMISSION_WEB_HOME=/opt/share/transmission/web

	# specific to daemonised applications only
	readonly DAEMON_PATHFILE=/opt/bin/transmission-daemon
	readonly DAEMON_LAUNCH_CMD="$DAEMON_PATHFILE --config-dir $(/usr/bin/dirname "$QPKG_INI_PATHFILE") --pid-file $DAEMON_PID_PATHFILE"
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
	readonly GET_UI_PORT_CMD="/opt/bin/jq -r '.\"rpc-port\"' < "$QPKG_INI_PATHFILE""
	readonly GET_UI_PORT_SECURE_CMD='echo 0'		# Transmission doesn't appear to contain any SSL UI ability
	readonly GET_UI_PORT_SECURE_ENABLED_TEST_CMD='false'
	readonly GET_UI_LISTENING_ADDRESS_CMD="/opt/bin/jq -r '.\"rpc-bind-address\"' < $QPKG_INI_PATHFILE"

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

	# this function is customised depending on the requirements of the packaged application

	IsError && return

	if IsNotRestart && IsNotRestore && IsNotClean && IsNotReset; then
		IsDaemonActive && return
	fi

	if IsRestore || IsClean || IsReset; then
		IsNotRestartPending && return
	fi

	MakePaths
	IsNotDaemon && return
	WaitForLaunchTarget || { SetError; return 1 ;}
	EnsureConfigFileExists
	LoadPorts app || { SetError; return 1 ;}

	if [[ $daemon_port -le 0 && $ui_port -le 0 && $ui_port_secure -le 0 ]]; then
		DisplayErrCommitAllLogs 'unable to start daemon: no port specified!'
		SetError
		return 1
	elif IsNotPortAvailable $ui_port || IsNotPortAvailable $ui_port_secure; then
		DisplayErrCommitAllLogs "unable to start daemon: ports $ui_port or $ui_port_secure are already in use!"

		portpid=$(/usr/sbin/lsof -i :$ui_port -Fp)
		DisplayErrCommitAllLogs "process details for port $ui_port: '$([[ -n ${portpid:-} ]] && /bin/tr '\000' ' ' </proc/"${portpid/p/}"/cmdline)'"

		portpid=$(/usr/sbin/lsof -i :$ui_port_secure -Fp)
		DisplayErrCommitAllLogs "process details for secure port $ui_port_secure: '$([[ -n ${portpid:-} ]] && /bin/tr '\000' ' ' </proc/"${portpid/p/}"/cmdline)'"

		SetError
		return 1
	fi

	if ! DisplayRunAndLog 'start daemon' "$DAEMON_LAUNCH_CMD" log:failure-only "$RUN_DAEMON_IN_SCREEN_SESSION"; then
		SetError
		return 1
	fi

	WaitForDaemon
	WaitForPID

	if ! IsDaemonActive; then
		DisplayErrCommitAllLogs 'IsDaemonActive() failed!'
		SetError
		return 1
	fi

	if ! CheckPorts; then
		DisplayErrCommitAllLogs 'CheckPorts() failed!'
		SetError
		return 1
	fi

	return 0

	}

StopQPKG()
	{

	# this function is customised depending on the requirements of the packaged application

	IsError && return

	if IsDaemonActive; then
		if IsRestart || IsRestore || IsClean || IsReset; then
			SetRestartPending
		fi

		local acc=0
		local pid=0
		SetRestartPending

		pid=$(<$DAEMON_PID_PATHFILE)
		kill "$pid"
		DisplayWaitCommitToLog "stop daemon PID ($pid) with SIGTERM:"
		DisplayWait "(no-more than $DAEMON_STOP_TIMEOUT_SECONDS second$(Pluralise "$DAEMON_STOP_TIMEOUT_SECONDS")):"

		while true; do
			while [[ -d /proc/$pid ]]; do
				sleep 1
				((acc++))
				DisplayWait "$acc,"

				if [[ $acc -ge $DAEMON_STOP_TIMEOUT_SECONDS ]]; then
					DisplayCommitToLog 'failed!'
					DisplayCommitToLog "stop daemon PID ($pid) with SIGKILL:"
					kill -9 "$pid" 2> /dev/null
					[[ -f $DAEMON_PID_PATHFILE ]] && rm -f "$DAEMON_PID_PATHFILE"
					break 2
				fi
			done

			[[ -f $DAEMON_PID_PATHFILE ]] && rm -f "$DAEMON_PID_PATHFILE"
			Display OK
			CommitToLog "stopped in $acc second$(Pluralise "$acc")"

			CommitInfoToSysLog 'stop daemon: OK'
			break
		done

		IsNotDaemonActive || { SetError; return 1 ;}
	fi

	return 0

	}

ProcessArgs
