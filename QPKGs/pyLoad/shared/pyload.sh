#!/usr/bin/env bash
####################################################################################
# pyload.sh
#
# Copyright (C) 2023 OneCD - one.cd.only@gmail.com
#
# so, blame OneCD if it all goes horribly wrong. ;)
#
# This is a type 6 service-script: https://github.com/OneCDOnly/sherpa/wiki/Service-Script-Types
#
# For more info: https://forum.qnap.com/viewtopic.php?f=320&t=132373
####################################################################################

readonly USER_ARGS_RAW=$*

Init()
	{

	IsQNAP || return

	# service-script environment
	readonly QPKG_NAME=pyLoad
	readonly SCRIPT_VERSION=230524

	# general environment
	readonly QPKG_PATH=$(/sbin/getcfg $QPKG_NAME Install_Path -f /etc/config/qpkg.conf)
	readonly QPKG_VERSION=$(/sbin/getcfg $QPKG_NAME Version -d unknown -f /etc/config/qpkg.conf)
	readonly QPKG_CONFIG_PATH=$QPKG_PATH/config
	readonly SCREEN_CONF_PATHFILE=$QPKG_CONFIG_PATH/screen.conf
	readonly QPKG_INI_PATHFILE=$QPKG_CONFIG_PATH/settings/pyload.cfg
	readonly QPKG_INI_DEFAULT_PATHFILE=$QPKG_INI_PATHFILE.def
	readonly APP_VERSION_STORE_PATHFILE=$QPKG_CONFIG_PATH/version.stored
	readonly SERVICE_STATUS_PATHFILE=/var/run/$QPKG_NAME.last.operation
	readonly DAEMON_PID_PATHFILE=/var/run/$QPKG_NAME.pid
	readonly SERVICE_LOG_PATHFILE=/var/log/$QPKG_NAME.log
	readonly DAEMON_LOG_PATHFILE=/var/log/$QPKG_NAME.daemon.log
	local -r BACKUP_PATH=$(/sbin/getcfg SHARE_DEF defVolMP -f /etc/config/def_share.info)/.qpkg_config_backup
	readonly BACKUP_PATHFILE=$BACKUP_PATH/$QPKG_NAME.config.tar.gz
	readonly OPKG_PATH=/opt/bin:/opt/sbin
	export PATH="$OPKG_PATH:$(/bin/sed "s|$OPKG_PATH||" <<< "$PATH")"
	readonly DEBUG_LOG_DATAWIDTH=100
	local re=''
	daemon_port=0
	ui_port=0
	ui_port_secure=0
	ui_listening_address=undefined

	# specific to online-sourced applications only
	readonly SOURCE_GIT_URL=''
	readonly SOURCE_ARCH=''
	readonly SOURCE_GIT_BRANCH=''
	# 'shallow' (depth 1) or 'single-branch' ... 'shallow' implies 'single-branch'
	readonly SOURCE_GIT_DEPTH=''
	readonly QPKG_REPO_PATH=$QPKG_PATH/repo-cache
	readonly PIP_CACHE_PATH=$QPKG_PATH/pip-cache
	readonly INTERPRETER=/opt/bin/python3
	readonly VENV_PATH=$QPKG_PATH/venv
	readonly VENV_INTERPRETER=$VENV_PATH/bin/python
	readonly ALLOW_ACCESS_TO_SYS_PACKAGES=true
	readonly INSTALL_PIP_DEPS=false

	# specific to daemonised applications only
	readonly DAEMON_PATHFILE=$VENV_PATH/bin/pyload
	readonly DAEMON_LAUNCH_CMD=". $VENV_PATH/bin/activate && $DAEMON_PATHFILE --daemon --userdir $QPKG_PATH/config --pidfile $DAEMON_PID_PATHFILE"
	readonly RUN_DAEMON_IN_SCREEN_SESSION=false
	readonly PORT_CHECK_TIMEOUT_SECONDS=240
	readonly DAEMON_CHECK_TIMEOUT_SECONDS=60
	readonly DAEMON_STOP_TIMEOUT_SECONDS=120
	readonly PIDFILE_APPEAR_TIMEOUT_SECONDS=60
	readonly PIDFILE_RECHECK_WAIT_SECONDS=10
	readonly PIDFILE_IS_MANAGED_BY_APP=true

	readonly GET_DAEMON_PORT_CMD=''
	readonly GET_UI_PORT_CMD="GetPyloadConfig $QPKG_INI_PATHFILE webui port"
	readonly GET_UI_PORT_SECURE_CMD="GetPyloadConfig $QPKG_INI_PATHFILE webui port"
	readonly GET_UI_PORT_SECURE_ENABLED_TEST_CMD="[[ $(GetPyloadConfig "$QPKG_INI_PATHFILE" webui use_ssl) = True ]]"
	readonly GET_UI_LISTENING_ADDRESS_CMD="GetPyloadConfig $QPKG_INI_PATHFILE webui host"

	# specific to applications supporting version lookup only
	readonly APP_VERSION_PATHFILE=''
	readonly APP_VERSION_CMD=''

	if [[ -z $LANG ]]; then
		export LANG=en_US.UTF-8
		export LC_ALL=en_US.UTF-8
		export LC_CTYPE=en_US.UTF-8
	fi

	if [[ ${DEBUG_QPKG:-} = true ]]; then
		debug=true
	else
		debug=false
	fi

	for re in \\bd\\b \\bdebug\\b \\bdbug\\b \\bverbose\\b; do
		if [[ $USER_ARGS_RAW =~ $re ]]; then
			debug=true
			break
		fi
	done

	UnsetError
	UnsetRestartPending
	EnsureConfigFileExists
	LoadAppVersion

	IsSupportBackup && [[ -n ${BACKUP_PATH:-} && ! -d $BACKUP_PATH ]] && mkdir -p "$BACKUP_PATH"
	[[ -n ${VENV_PATH:-} && ! -d $VENV_PATH ]] && mkdir -p "$VENV_PATH"
	[[ -n ${PIP_CACHE_PATH:-} && ! -d $PIP_CACHE_PATH ]] && mkdir -p "$PIP_CACHE_PATH"

	IsAutoUpdateMissing && EnableAutoUpdate >/dev/null

	if [[ $RUN_DAEMON_IN_SCREEN_SESSION = true && ! -e $SCREEN_CONF_PATHFILE ]]; then
		echo "logfile $DAEMON_LOG_PATHFILE" > "$SCREEN_CONF_PATHFILE"
		echo 'logfile flush 1' >> "$SCREEN_CONF_PATHFILE"
		echo 'log on' >> "$SCREEN_CONF_PATHFILE"
	fi

	return 0

	}

ShowHelp()
	{

	Display "$(ColourTextBrightWhite "$(/usr/bin/basename "$0")") $SCRIPT_VERSION • a service control script for the $(FormatAsPackageName $QPKG_NAME) QPKG"
	Display
	Display "Usage: $0 [OPTION]"
	Display
	Display '[OPTION] may be any one of the following:'
	Display
	DisplayAsHelp start "launch $(FormatAsPackageName $QPKG_NAME) if not already running."
	DisplayAsHelp stop "shutdown $(FormatAsPackageName $QPKG_NAME) if running."
	DisplayAsHelp restart "stop, then start $(FormatAsPackageName $QPKG_NAME)."
	DisplayAsHelp status "check if $(FormatAsPackageName $QPKG_NAME) daemon is running. Returns \$? = 0 if running, 1 if not."
	IsSupportBackup && DisplayAsHelp backup "backup the current $(FormatAsPackageName $QPKG_NAME) configuration to persistent storage."
	IsSupportBackup && DisplayAsHelp restore "restore a previously saved configuration from persistent storage. $(FormatAsPackageName $QPKG_NAME) will be stopped, then restarted."
	IsSupportReset && DisplayAsHelp reset-config "delete the application configuration, databases and history. $(FormatAsPackageName $QPKG_NAME) will be stopped, then restarted."
	IsSourcedOnline && DisplayAsHelp clean "delete the local copy of $(FormatAsPackageName $QPKG_NAME), and download it again from remote source. Configuration will be retained."
	DisplayAsHelp log 'display the service-script log.'
	IsSourcedOnline && DisplayAsHelp enable-auto-update "auto-update $(FormatAsPackageName $QPKG_NAME) before starting (default)."
	IsSourcedOnline && DisplayAsHelp disable-auto-update "don't auto-update $(FormatAsPackageName $QPKG_NAME) before starting."
	DisplayAsHelp version 'display the package version numbers.'
	Display

	}

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

	DisplayWaitCommitToLog 'auto-update:'

	if IsAutoUpdate; then
		DisplayCommitToLog true
	else
		DisplayCommitToLog false
	fi

	InstallAddons || { SetError; return 1 ;}
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

	if IsNotVirtualEnvironmentExist; then
		DisplayErrCommitAllLogs 'unable to start daemon: virtual environment does not exist!'
		SetError
		return 1
	fi

	DisplayRunAndLog 'start daemon' "$DAEMON_LAUNCH_CMD" log:failure-only "$RUN_DAEMON_IN_SCREEN_SESSION"
	WaitForDaemon
	WaitForPID

	if ! IsDaemonActive; then
		DisplayErrCommitAllLogs 'IsDaemonActive() failed'
		SetError
		return 1
	fi

	if ! CheckPorts; then
		DisplayErrCommitAllLogs 'CheckPorts() failed'
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
		DisplayWait "(no-more than $DAEMON_STOP_TIMEOUT_SECONDS seconds):"

		while true; do
			while [[ -d /proc/$pid ]]; do
				sleep 1
				((acc++))
				DisplayWait "$acc,"

				if [[ $acc -ge $DAEMON_STOP_TIMEOUT_SECONDS ]]; then
					DisplayCommitToLog 'failed!'
					DisplayCommitToLog "stop daemon PID ($pid) with SIGKILL:"
					kill -9 "$pid" 2> /dev/null
					[[ -f $DAEMON_PID_PATHFILE ]] && rm -f $DAEMON_PID_PATHFILE
					break 2
				fi
			done

			[[ -f $DAEMON_PID_PATHFILE ]] && rm -f $DAEMON_PID_PATHFILE
			Display OK
			CommitToLog "stopped in $acc seconds"

			CommitInfoToSysLog 'stop daemon: OK'
			break
		done

		IsNotDaemonActive || { SetError; return 1 ;}
	fi

	return 0

	}

InstallAddons()
	{

	local default_requirements_pathfile=$QPKG_CONFIG_PATH/requirements.txt
	local default_recommended_pathfile=$QPKG_CONFIG_PATH/recommended.txt
	local exclusions_pathfile=$QPKG_CONFIG_PATH/exclusions.txt
	local rebuild_pathfile=$QPKG_CONFIG_PATH/rebuild.txt
	local requirements_pathfile=$QPKG_REPO_PATH/requirements.txt
	local recommended_pathfile=$QPKG_REPO_PATH/recommended.txt
	local pyproject_pathfile=$QPKG_REPO_PATH/pyproject.toml
	local pip_conf_pathfile=$VENV_PATH/pip.conf
	local new_env=false
	local sys_packages=' --system-site-packages'
	local no_pips_installed=true
	local pip_deps=' --no-deps'

	[[ $ALLOW_ACCESS_TO_SYS_PACKAGES != true ]] && sys_packages=''
	[[ $INSTALL_PIP_DEPS = true ]] && pip_deps=''

	if IsNotVirtualEnvironmentExist; then
		DisplayRunAndLog 'create new virtual Python environment' "export PIP_CACHE_DIR=$PIP_CACHE_PATH VIRTUALENV_OVERRIDE_APP_DATA=$PIP_CACHE_PATH; $INTERPRETER -m virtualenv ${VENV_PATH}${sys_packages}" log:failure-only || SetError
		new_env=true
	fi

	if IsNotVirtualEnvironmentExist; then
		DisplayErrCommitAllLogs 'unable to install addons: virtual environment does not exist!'
		SetError
		return 1
	fi

	if [[ ! -e $pip_conf_pathfile ]]; then
		DisplayRunAndLog "create global 'pip' config" "echo -e \"[global]\ncache-dir = $PIP_CACHE_PATH\" > $pip_conf_pathfile" log:failure-only || SetError
	fi

	IsNotAutoUpdate && [[ $new_env = false ]] && return 0

	# edit developer-provided Python module requirements files out-of-repo

	[[ -e $requirements_pathfile ]] && cp -f "$requirements_pathfile" "$default_requirements_pathfile"
	[[ -e $default_requirements_pathfile ]] && requirements_pathfile=$default_requirements_pathfile

	[[ -e $recommended_pathfile ]] && cp -f "$recommended_pathfile" "$default_recommended_pathfile"
	[[ -e $default_recommended_pathfile ]] && recommended_pathfile=$default_recommended_pathfile

	# KLUDGE: can't use `manytolinux2014` wheel builds in QTS, so force these wheels to be rebuilt locally

	if [[ -e $rebuild_pathfile ]]; then
		for target in $requirements_pathfile $recommended_pathfile $pyproject_pathfile; do
			if [[ -e $target ]]; then
				for module in $(<$rebuild_pathfile); do
					if (/bin/grep -q $module < "$target") && ! (/bin/grep -q -- "--no-binary=$module" < "$target"); then
						DisplayRunAndLog "include rebuild directive for '$module' in '$(JustFile "$target")'" "echo \"--no-binary=$module\" >> $target" log:failure-only || SetError
					fi
				done
			fi
		done
	fi

	# Must remove these modules from repo txt files, and use the ones installed via `opkg` instead (if available).
	# If not, `pip` will attempt to compile these, which fails on early ARMv5 CPUs.

	if [[ -e $exclusions_pathfile ]]; then
		local module_exclusions=$(tr '\n' ' ' < "$exclusions_pathfile")
		module_exclusions=${module_exclusions%* }
		local module_exclusions_re="/^${module_exclusions// /\|^}"

		for target in $requirements_pathfile $recommended_pathfile $pyproject_pathfile; do
			if [[ -e $target ]]; then
				DisplayRunAndLog "exclude problem PyPI modules from '$(JustFile "$target")'" "/bin/sed -i '${module_exclusions_re}/d' $target" log:failure-only || SetError
			fi
		done
	fi

	# Install remaining PyPI modules

	for target in $requirements_pathfile $recommended_pathfile; do
		if [[ -e $target ]]; then
			DisplayRunAndLog "install PyPI modules from '$(JustFile "$target")'" ". $VENV_PATH/bin/activate && pip install${pip_deps} --no-input --upgrade pip -r $target" log:failure-only || SetError
			no_pips_installed=false
		fi
	done

	# fallback to general installation method

	if [[ $no_pips_installed = true ]]; then
		if [[ -e $QPKG_REPO_PATH/setup.py || -e $pyproject_pathfile ]]; then
			DisplayRunAndLog "install PyPI modules from '$(JustFile "$target")'" ". $VENV_PATH/bin/activate && pip install${pip_deps} --no-input --upgrade pip $QPKG_REPO_PATH" log:failure-only || SetError
			no_pips_installed=false
		fi
	fi

	}

BackupConfig()
	{

	DisplayRunAndLog 'update configuration backup' "/bin/tar --create --gzip --file=$BACKUP_PATHFILE --directory=$QPKG_PATH/config ." || SetError

	return 0

	}

RestoreConfig()
	{

	if [[ ! -f $BACKUP_PATHFILE ]]; then
		DisplayErrCommitAllLogs 'unable to restore configuration: no backup file was found!'
		SetError
		return 1
	fi

	DisplayRunAndLog 'restore configuration backup' "/bin/tar --extract --gzip --file=$BACKUP_PATHFILE --directory=$QPKG_PATH/config" || SetError

	return 0

	}

ResetConfig()
	{

	DisplayRunAndLog 'reset configuration' "mv $QPKG_INI_DEFAULT_PATHFILE $QPKG_PATH; rm -rf $QPKG_PATH/config/*; mv $QPKG_PATH/$(/usr/bin/basename "$QPKG_INI_DEFAULT_PATHFILE") $QPKG_INI_DEFAULT_PATHFILE" || SetError

	return 0

	}

LoadPorts()
	{

	# If user changes ports via app UI, must first 'stop' application on old ports, then 'start' on new ports

	case $1 in
		app)
			# Read the current application UI ports from application configuration
			DisplayWaitCommitToLog 'load ports from configuration file:'
			[[ -n ${GET_UI_PORT_CMD:-} ]] && ui_port=$(eval "$GET_UI_PORT_CMD")
			[[ -n ${GET_UI_PORT_SECURE_CMD:-} ]] && ui_port_secure=$(eval "$GET_UI_PORT_SECURE_CMD")
			DisplayCommitToLog OK
			;;
		qts)
			# Read the current application UI ports from QTS App Center
			DisplayWaitCommitToLog 'load UI ports from QPKG icon:'
			ui_port=$(/sbin/getcfg $QPKG_NAME Web_Port -d 0 -f /etc/config/qpkg.conf)
			ui_port_secure=$(/sbin/getcfg $QPKG_NAME Web_SSL_Port -d 0 -f /etc/config/qpkg.conf)
			DisplayCommitToLog OK
			;;
		*)
			DisplayErrCommitAllLogs "unable to load ports: action '$1' is unrecognised"
			SetError
			return 1
			;;
	esac

	# Always read these from the application configuration
	[[ -n ${GET_DAEMON_PORT_CMD:-} ]] && daemon_port=$(eval "$GET_DAEMON_PORT_CMD")
	[[ -n ${GET_UI_LISTENING_ADDRESS_CMD:-} ]] && ui_listening_address=$(eval "$GET_UI_LISTENING_ADDRESS_CMD")

	# validate port numbers
	ui_port=${ui_port//[!0-9]/}					# strip everything not a numeral
	[[ -z $ui_port || $ui_port -lt 0 || $ui_port -gt 65535 ]] && ui_port=0

	ui_port_secure=${ui_port_secure//[!0-9]/}	# strip everything not a numeral
	[[ -z $ui_port_secure || $ui_port_secure -lt 0 || $ui_port_secure -gt 65535 ]] && ui_port_secure=0

	daemon_port=${daemon_port//[!0-9]/}			# strip everything not a numeral
	[[ -z $daemon_port || $daemon_port -lt 0 || $daemon_port -gt 65535 ]] && daemon_port=0

	[[ -z $ui_listening_address ]] && ui_listening_address=undefined

	return 0

	}

LoadAppVersion()
	{

	# Find the application's internal version number
	# creates a global var: $app_version
	# this is the installed application version (not the QPKG version)

	if [[ -n ${APP_VERSION_PATHFILE:-} && -e $APP_VERSION_PATHFILE ]]; then
		app_version=$(eval "$APP_VERSION_CMD")
		return 0
	else
		app_version=unknown
		return 1
	fi

	}

StatusQPKG()
	{

	IsNotError || return

	if IsDaemonActive; then
		if IsDaemon || IsSourcedOnline; then
			LoadPorts app
			! CheckPorts && exit 1
		fi
	else
		exit 1
	fi

	exit 0

	}

DisableOpkgDaemonStart()
	{

	if [[ -n $ORIG_DAEMON_SERVICE_SCRIPT && -x $ORIG_DAEMON_SERVICE_SCRIPT ]]; then
		$ORIG_DAEMON_SERVICE_SCRIPT stop		# stop default daemon
		chmod -x "$ORIG_DAEMON_SERVICE_SCRIPT"	# ... and ensure Entware doesn't re-launch it on startup
	fi

	}

CleanLocalClone()
	{

	# for occasions where the local repo needs to be deleted and cloned again from source.

	if [[ -z $QPKG_PATH || -z $QPKG_NAME ]] || IsNotSourcedOnline; then
		SetError
		return 1
	fi

	DisplayRunAndLog 'clean local repository' "rm -rf $QPKG_REPO_PATH" log:failure-only
	[[ -n $QPKG_REPO_PATH && -d $(/usr/bin/dirname "$QPKG_REPO_PATH")/$QPKG_NAME ]] && DisplayRunAndLog 'KLUDGE: remove previous local repository' "rm -r $(/usr/bin/dirname "$QPKG_REPO_PATH")/$QPKG_NAME" log:failure-only
	[[ -n $VENV_PATH && -d $VENV_PATH ]] && DisplayRunAndLog 'clean virtual environment' "rm -rf $VENV_PATH" log:failure-only
	[[ -n $PIP_CACHE_PATH && -d $PIP_CACHE_PATH ]] && DisplayRunAndLog 'clean PyPI cache' "rm -rf $PIP_CACHE_PATH" log:failure-only

	}

WaitForGit()
	{

	if WaitForFileToAppear '/opt/bin/git' 300; then
		export PATH="$OPKG_PATH:$(/bin/sed "s|$OPKG_PATH||" <<< "$PATH")"
		return 0
	else
		return 1
	fi

	}

GetLaunchTarget()
	{

	if [[ -n ${VENV_INTERPRETER:-} ]]; then
		echo "$VENV_INTERPRETER"
	elif [[ -n ${DAEMON_PATHFILE:-} ]]; then
		echo "$DAEMON_PATHFILE"
	else
		return 1
	fi

	}

WaitForLaunchTarget()
	{

	WaitForFileToAppear "$(GetLaunchTarget)" 30 || return

	}

FindAndWritePIDFile()
	{

	local -i pid=0
	target_pid="$(ps | /bin/grep "$(GetLaunchTarget)" | /bin/grep -v grep)"
	target_pid=${target_pid:0:5}
	target_pid=$(tr -d ' ' <<< "$target_pid")

	if [[ $target_pid -gt 0 ]]; then
		echo "$target_pid" > "$DAEMON_PID_PATHFILE"
		return 0
	fi

	return 1

	}

WaitForPID()
	{

	if [[ $PIDFILE_IS_MANAGED_BY_APP = true ]]; then
		if WaitForFileToAppear "$DAEMON_PID_PATHFILE" "$PIDFILE_APPEAR_TIMEOUT_SECONDS"; then
			sleep 1		# wait one more second to allow file to have PID written into it
		fi
	fi

	DisplayWaitCommitToLog 'found daemon PID:'

	if FindAndWritePIDFile; then
		DisplayCommitToLog "$(<"$DAEMON_PID_PATHFILE")"
	else
		DisplayCommitToLog false
	fi

	DisplayWaitCommitToLog "wait $PIDFILE_RECHECK_WAIT_SECONDS seconds to recheck PID:"
	sleep "$PIDFILE_RECHECK_WAIT_SECONDS"
	DisplayCommitToLog 'done'

	DisplayWaitCommitToLog 'found daemon PID:'

	if FindAndWritePIDFile; then
		DisplayCommitToLog "$(<"$DAEMON_PID_PATHFILE")"
	else
		DisplayErrCommitAllLogs false
		DisplayErrCommitAllLogs 'unable to locate active daemon process'
		return 1
	fi

	}

WaitForDaemon()
	{

	# input:
	#   $1 = timeout in seconds (optional) - default 30

	# output:
	#   $? = 0 (file was found) or 1 (file not found: timeout)

	local -i count=0

	if [[ -n $1 ]]; then
		MAX_SECONDS=$1
	else
		MAX_SECONDS=$DAEMON_CHECK_TIMEOUT_SECONDS
	fi

	if [[ ! -e $1 ]]; then
		DisplayWaitCommitToLog 'wait for daemon to appear:'
		DisplayWait "(no-more than $MAX_SECONDS seconds):"

		(
			for ((count=1; count<=MAX_SECONDS; count++)); do
				sleep 1
				DisplayWait "$count,"

				if IsProcessActive "$DAEMON_PATHFILE" "$DAEMON_PID_PATHFILE"; then
					Display OK
					CommitToLog "active after $count second$(FormatAsPlural "$count")"
					true
					exit	# only this sub-shell
				fi
			done
			false
		)

		if [[ $? -ne 0 ]]; then
			DisplayCommitToLog 'failed!'
			DisplayErrCommitAllLogs "daemon not found! (exceeded timeout: $MAX_SECONDS seconds)"
			return 1
		fi
	fi

	DisplayCommitToLog "daemon: exists"

	return 0

	}

WaitForFileToAppear()
	{

	# input:
	#   $1 = pathfilename to watch for
	#   $2 = timeout in seconds (optional) - default 30

	# output:
	#   $? = 0 : file was found
	#   $? = 1 : file not found/timeout

	[[ -n $1 ]] || return

	if [[ -n $2 ]]; then
		MAX_SECONDS=$2
	else
		MAX_SECONDS=30
	fi

	if [[ ! -e $1 ]]; then
		DisplayWaitCommitToLog "wait for $1 to appear:"
		DisplayWait "(no-more than $MAX_SECONDS seconds):"

		(
			for ((count=1; count<=MAX_SECONDS; count++)); do
				sleep 1
				DisplayWait "$count,"

				if [[ -e $1 ]]; then
					Display OK
					CommitToLog "visible after $count second$(FormatAsPlural "$count")"
					true
					exit	# only this sub-shell
				fi
			done
			false
		)

		if [[ $? -ne 0 ]]; then
			DisplayCommitToLog 'failed!'
			DisplayErrCommitAllLogs "$1 not found! (exceeded timeout: $MAX_SECONDS seconds)"
			return 1
		fi
	fi

	DisplayCommitToLog "file $1: exists"

	return 0

	}

ViewLog()
	{

	if [[ -e $SERVICE_LOG_PATHFILE ]]; then
		if [[ -e /opt/bin/less ]]; then
			LESSSECURE=1 /opt/bin/less +G --quit-on-intr --tilde --LINE-NUMBERS --RAW-CONTROL-CHARS --prompt ' use arrow-keys to scroll up-down left-right, press Q to quit' "$SERVICE_LOG_PATHFILE"
		else
			/bin/cat --number "$SERVICE_LOG_PATHFILE"
		fi
	else
		Display "service log not found: $SERVICE_LOG_PATHFILE"
		SetError
		return 1
	fi

	return 0

	}

EnsureConfigFileExists()
	{

	IsNotSupportReset && return

	if IsNotConfigFound && IsDefaultConfigFound; then
		DisplayCommitToLog 'no configuration file found: using default'
		cp "$QPKG_INI_DEFAULT_PATHFILE" "$QPKG_INI_PATHFILE"
	fi

	}

SaveAppVersion()
	{

	[[ -z $APP_VERSION_STORE_PATHFILE ]] && return
	echo "$app_version" > "$APP_VERSION_STORE_PATHFILE"

	}

DisplayRunAndLog()
	{

	# Run a commandstring with a summarised description, log the results, and show onscreen if required
	# This function is just a fancy wrapper for RunAndLog()

	# input:
	#   $1 = processing message
	#   $2 = commandstring to execute
	#   $3 = 'log:failure-only' (optional) - if specified, stdout & stderr are only recorded in the specified log if the command failed. default is to always record stdout & stderr.
	#   $4 = true/false (optional) - if true, run command in a screen session

	local -r LOG_PATHFILE=$(/bin/mktemp /var/log/"${FUNCNAME[0]}"_XXXXXX)
	local -i result_code=0

	DisplayWaitCommitToLog "$1:"

	RunAndLog "${2:?empty}" "$LOG_PATHFILE" "${3:-}" '' "${4:-false}"
	result_code=$?

	if [[ -e $LOG_PATHFILE ]]; then
		rm -f "$LOG_PATHFILE"
	fi

	if [[ $result_code -eq 0 ]]; then
		[[ ${3:-} != log:failure-only ]] && CommitInfoToSysLog "${1:?empty}: OK"
		[[ $debug = false ]] && DisplayCommitToLog OK
		return 0
	else
		DisplayErrCommitAllLogs 'failed!'
		return 1
	fi

	}

RunAndLog()
	{

	# Run a commandstring, log the results, and show onscreen if required

	# input:
	#   $1 = commandstring to execute
	#   $2 = log pathfile to record stdout and stderr for commandstring
	#   $3 = 'log:failure-only' (optional) - if specified, stdout & stderr are only recorded in the specified log if the command failed. default is to always record stdout & stderr.
	#   $4 = e.g. '10' (optional) - an additional acceptable result code. Any other result from command (other than zero) will be considered a failure
	#   $5 = true/false (optional) - if true, run command in a screen session

	# output:
	#   stdout : commandstring stdout and stderr if script is in 'debug' mode
	#   pathfile ($2) : commandstring ($1) stdout and stderr
	#   $? : $result_code of commandstring

	local -r LOG_PATHFILE=$(/bin/mktemp /var/log/"${FUNCNAME[0]}"_XXXXXX)
	local -i result_code=0

	FormatAsCommand "${1:?empty}" > "${2:?empty}"

	if [[ $debug = true ]]; then
		Display

		if [[ ${5:-false} = false ]]; then
			Display "exec: '$1'"
			eval "$1 > >(/usr/bin/tee $LOG_PATHFILE) 2>&1"		# NOTE: 'tee' buffers stdout here
			result_code=$?
		else
			Display "exec (in screen session): '$1'"
		fi
	else
		if [[ ${5:-false} = false ]]; then
			(eval "$1" > "$LOG_PATHFILE" 2>&1)			# run in a subshell to suppress 'Terminated' message later
		fi
	fi

	if [[ ${5:-false} = true ]]; then
		/usr/sbin/screen -c "$SCREEN_CONF_PATHFILE" -dmLS "$QPKG_NAME" bash -c "$1"
		result_code=$?
	fi

	if [[ -e $LOG_PATHFILE ]]; then
		FormatAsResultAndStdout "$result_code" "$(<"$LOG_PATHFILE")" >> "$2"
		rm -f "$LOG_PATHFILE"
	else
		FormatAsResultAndStdout "$result_code" '<null>' >> "$2"
	fi

	if [[ $result_code -eq 0 ]]; then
		[[ ${3:-} != log:failure-only ]] && AddFileToDebug "$2"
		[[ $debug = true ]] && Display 'exec: completed OK' || rm -f "$2"
	else
		[[ $result_code -ne ${4:-} ]] && AddFileToDebug "$2"
		[[ $debug = true ]] && Display 'exec: completed, but with errors'
	fi

	return $result_code

	}

AddFileToDebug()
	{

	# Add the contents of specified pathfile $1 to the runtime log

	local debug_was_set=$debug
	local linebuff=''

	# prevent external log contents appearing onscreen again, as they have already been seen "live"
	debug=false

	DebugAsLog ''
	DebugAsLog 'adding external log to main log ...'
	DebugExtLogMinorSeparator
	DebugAsLog "$(FormatAsLogFilename "${1:?no filename supplied}")"

	while read -r linebuff; do
		DebugAsLog "$linebuff"
	done < "$1"

	DebugExtLogMinorSeparator
	debug=$debug_was_set

	}

DebugExtLogMinorSeparator()
	{

	DebugAsLog "$(eval printf '%0.s-' "{1..$DEBUG_LOG_DATAWIDTH}")"		# 'seq' is unavailable in QTS, so must resort to 'eval' trickery instead

	}

DebugAsLog()
	{

	[[ -n ${1:-} ]] || return

	DebugThis "(LL) $1"

	}

DebugThis()
	{

	[[ $debug = true ]] && Display "${1:-}"
	WriteAsDebug "${1:-}"

	}

WriteAsDebug()
	{

	WriteToLog dbug "${1:-}"

	}

WriteToLog()
	{

	# input:
	#   $1 = pass/fail
	#   $2 = message

	printf "%-4s: %s\n" "$(StripANSI "${1:-}")" "$(StripANSI "${2:-}")" >> "$SERVICE_LOG_PATHFILE"

	}

StripANSI()
	{

	# QTS 4.2.6 BusyBox 'sed' doesn't fully support extended regexes, so this only works with a real 'sed'

	if [[ -e /opt/bin/sed ]]; then
		/opt/bin/sed -r 's/\x1b\[[0-9;]*m//g' <<< "${1:-}"
	else
		echo "${1:-}"		# can't strip, so pass thru original message unaltered
	fi

	}

Uppercase()
	{

	tr 'a-z' 'A-Z' <<< "$1"

	}

Lowercase()
	{

	tr 'A-Z' 'a-z' <<< "$1"

	}

ReWriteUIPorts()
	{

	# Write the current application UI ports into the QTS App Center configuration

	# QTS App Center requires 'Web_Port' to always be non-zero

	# 'Web_SSL_Port' behaviour:
	#		   < -2 = crashes current QTS session. Starts with non-responsive package icons in App Center
	# missing or -2 = QTS will fallback from HTTPS to HTTP, with a warning to user
	#			 -1 = launch QTS UI again (only if WebUI = '/'), else show "QNAP Error" page
	#			  0 = "unable to connect"
	#			> 0 = works if logged-in to QTS UI via HTTPS

	# If SSL is enabled, attempting to access with non-SSL via 'Web_Port' results in "connection was reset"

	[[ -n ${GET_DAEMON_PORT_CMD:-} ]] && return		# dont need to rewrite QTS UI ports if this app has a daemon port, as UI ports are unused

	DisplayWaitCommitToLog 'update QPKG icon with UI ports:'
	/sbin/setcfg $QPKG_NAME Web_Port "$ui_port" -f /etc/config/qpkg.conf

	if IsSSLEnabled; then
		/sbin/setcfg $QPKG_NAME Web_SSL_Port "$ui_port_secure" -f /etc/config/qpkg.conf
	else
		/sbin/setcfg $QPKG_NAME Web_SSL_Port '-2' -f /etc/config/qpkg.conf
	fi

	DisplayCommitToLog OK

	}

CheckPorts()
	{

	local msg=''

	DisplayCommitToLog "daemon listening address: $ui_listening_address"

	if [[ $daemon_port -ne 0 ]]; then
		DisplayCommitToLog "daemon port: $daemon_port"

		if IsPortResponds $daemon_port; then
			msg="daemon port $daemon_port"
		fi
	else
		DisplayWaitCommitToLog 'HTTPS port enabled:'
		if IsSSLEnabled; then
			DisplayCommitToLog true
			DisplayCommitToLog "HTTPS port: $ui_port_secure"

			if IsPortSecureResponds $ui_port_secure; then
				msg="HTTPS port $ui_port_secure"
			fi
		else
			DisplayCommitToLog false
		fi

		DisplayCommitToLog "HTTP port: $ui_port"

		if IsPortResponds $ui_port; then
			[[ -n $msg ]] && msg+=' and '
			msg+="HTTP port $ui_port"
		fi
	fi

	if [[ -z $msg ]]; then
		DisplayErrCommitAllLogs 'no response on configured port(s)!'
		SetError
		return 1
	else
		DisplayCommitToLog "$msg test: OK"
		ReWriteUIPorts
		return 0
	fi

	}

GetPyloadConfig()
	{

	# input:
	#   $1 = pathfilename to read from
	#   $2 = section name
	#   $3 = variable name to return value for

	# output:
	#   $? = 0 : variable found
	#   $? = 1 : file/section/variable not found
	#   stdout = variable value

	local source_pathfile=${1:?no pathfilename supplied}
	local target_section_name=${2:?no section supplied}
	local target_var_name=${3:?no variable supplied}

	if [[ ! -e $source_pathfile ]]; then
		echo false
		return
	fi

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
	done <<< "$(/bin/grep '.*:$' -n "$source_pathfile")"

	if [[ $start_line_num -eq 0 ]]; then
		echo 'section match not found'
		return 1
	fi

	target_section=$(/bin/sed -n "${start_line_num},${end_line_num}p" "$source_pathfile")

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

IsQNAP()
	{

	# output:
	#   $? = 0 : this is a QNAP NAS
	#   $? = 1 : not a QNAP

	if [[ ! -e /etc/init.d/functions ]]; then
		Display 'QTS functions missing (is this a QNAP NAS?)'
		SetError
		return 1
	fi

	return 0

	}

IsQPKGInstalled()
	{

	# input:
	#   $1 = (optional) package name to check. If unspecified, default is $QPKG_NAME

	# output:
	#   $? = 0 : true
	#   $? = 1 : false

	if [[ -n ${1:-} ]]; then
		local name=$1
	else
		local name=$QPKG_NAME
	fi

	/bin/grep -q "^\[$name\]" /etc/config/qpkg.conf

	}

IsNotQPKGInstalled()
	{

	! IsQPKGInstalled "${1:-}"

	}

IsQPKGEnabled()
	{

	# input:
	#   $1 = (optional) package name to check. If unspecified, default is $QPKG_NAME

	# output:
	#   $? = 0 : true
	#   $? = 1 : false

	if [[ -n ${1:-} ]]; then
		local name=$1
	else
		local name=$QPKG_NAME
	fi

	[[ $(Lowercase "$(/sbin/getcfg "$name" Enable -d false -f /etc/config/qpkg.conf)") = true ]]

	}

IsNotQPKGEnabled()
	{

	# input:
	#   $1 = (optional) package name to check. If unspecified, default is $QPKG_NAME

	# output:
	#   $? = 0 : true
	#   $? = 1 : false

	! IsQPKGEnabled "${1:-}"

	}

IsSupportBackup()
	{

	[[ -n ${BACKUP_PATHFILE:-} ]]

	}

IsNotSupportBackup()
	{

	! IsSupportBackup

	}

IsSupportReset()
	{

	[[ -n ${QPKG_INI_PATHFILE:-} ]]

	}

IsNotSupportReset()
	{

	! IsSupportReset

	}

IsSourcedOnline()
	{

	[[ -n ${SOURCE_GIT_URL:-} || -n ${PIP_CACHE_PATH} ]]

	}

IsNotSourcedOnline()
	{

	! IsSourcedOnline

	}

IsSSLEnabled()
	{

	eval "$GET_UI_PORT_SECURE_ENABLED_TEST_CMD"

	}

IsNotSSLEnabled()
	{

	! IsSSLEnabled

	}

IsDaemon()
	{

	[[ -n ${DAEMON_PID_PATHFILE:-} ]]

	}

IsNotDaemon()
	{

	! IsDaemon

	}

IsDaemonActive()
	{

	# $? = 0 : $DAEMON_PATHFILE is in memory
	# $? = 1 : $DAEMON_PATHFILE is not in memory

	DisplayWaitCommitToLog 'daemon active:'

	if [[ -n $VENV_INTERPRETER ]]; then
		if IsProcessActive "$VENV_INTERPRETER" "$DAEMON_PID_PATHFILE"; then
			DisplayCommitToLog true
			return 0
		fi
	else
		if IsProcessActive "$DAEMON_PATHFILE" "$DAEMON_PID_PATHFILE"; then
			DisplayCommitToLog true
			return 0
		fi
	fi

	DisplayCommitToLog false
	[[ -f $DAEMON_PID_PATHFILE ]] && rm "$DAEMON_PID_PATHFILE"
	return 1

	}

IsNotDaemonActive()
	{

	! IsDaemonActive

	}

IsProcessActive()
	{

	# input:
	#   $1 = process pathfile
	#   $2 = PID pathfile

	# output:
	#   $? = 0 : $1 is in memory
	#   $? = 1 : $1 is not in memory

	[[ -n ${1:-} ]] || return
	[[ -n ${2:-} ]] || return
	[[ ! -e $2 ]] && FindAndWritePIDFile
	[[ -e $2 && -d /proc/$(<"$2") && -n ${1:-} && $(</proc/"$(<"$2")"/cmdline) =~ ${1:-} ]]

	}

IsPackageActive()
	{

	# $? = 0 : package is `started`
	# $? = 1 : package is `stopped`

	DisplayWaitCommitToLog 'package active:'

	if [[ -e $BACKUP_SERVICE_PATHFILE ]]; then
		DisplayCommitToLog true
		return 0
	fi

	DisplayCommitToLog false
	return 1

	}

IsNotPackageActive()
	{

	# $? = 0 : package is `stopped`
	# $? = 1 : package is `started`

	! IsPackageActive

	}

IsSysFilePresent()
	{

	# input:
	#   $1 = pathfilename to check

	if [[ -z ${1:?pathfilename null} ]]; then
		SetError
		return 1
	fi

	if [[ ! -e $1 ]]; then
		Display "A required NAS system file is missing: $1"
		SetError
		return 1
	else
		return 0
	fi

	}

IsNotSysFilePresent()
	{

	# input:
	#   $1 = pathfilename to check

	! IsSysFilePresent "${1:?pathfilename null}"

	}

IsPortAvailable()
	{

	# input:
	#   $1 = port to check

	# output:
	#   $? = 0 : available
	#   $? = 1 : already used

	local port=${1//[!0-9]/}		# strip everything not a numeral
	[[ -n $port && $port -gt 0 ]] || return 0

	if (/usr/sbin/lsof -i :"$port" -sTCP:LISTEN >/dev/null 2>&1); then
		return 1
	else
		return 0
	fi

	}

IsNotPortAvailable()
	{

	# input:
	#   $1 = port to check

	# output:
	#   $? = 1 : port available
	#   $? = 0 : already used

	! IsPortAvailable "${1:-0}"

	}

IsPortResponds()
	{

	# input:
	#   $1 = port to check

	# output:
	#   $? = 0 : response received
	#   $? = 1 : not OK

	local port=${1//[!0-9]/}		# strip everything not a numeral

	if [[ -z $port ]]; then
		Display 'empty port: not testing for response'
		return 1
	elif [[ $port -eq 0 ]]; then
		Display 'port 0: not testing for response'
		return 1
	fi

	local acc=0

	DisplayWaitCommitToLog "test for port $port response:"
	DisplayWait "(no-more than $PORT_CHECK_TIMEOUT_SECONDS seconds):"

	while true; do
		if ! IsProcessActive "$DAEMON_PATHFILE" "$DAEMON_PID_PATHFILE"; then
			DisplayCommitToLog 'process not active!'
			break
		fi

		/sbin/curl --silent --fail --max-time 1 http://localhost:"$port" &>/dev/null

		case $? in
			0|22|52)	# accept these exitcodes as evidence of valid responses
				Display OK
				CommitToLog "port responded after $acc seconds"
				return 0
				;;
			28)			# timeout
				: 			# do nothing
				;;
			7)			# this code is returned immediately
				sleep 1		# ... so let's wait here a bit
				;;
			*)
				: # do nothing
		esac

		((acc+=1))
		DisplayWait "$acc,"

		if [[ $acc -ge $PORT_CHECK_TIMEOUT_SECONDS ]]; then
			DisplayCommitToLog 'failed!'
			CommitErrToSysLog "port $port failed to respond after $acc seconds!"
			break
		fi
	done

	return 1

	}

IsPortSecureResponds()
	{

	# input:
	#   $1 = secure port to check

	# output:
	#   $? = 0 : response received
	#   $? = 1 : not OK or secure port unspecified

	local port=${1//[!0-9]/}		# strip everything not a numeral

	if [[ -z $port ]]; then
		Display 'empty port: not testing for response'
		return 1
	elif [[ $port -eq 0 ]]; then
		Display 'port 0: not testing for response'
		return 1
	fi

	local acc=0

	DisplayWaitCommitToLog "test for secure port $port response:"
	DisplayWait "(no-more than $PORT_CHECK_TIMEOUT_SECONDS seconds):"

	while true; do
		if ! IsProcessActive "$DAEMON_PATHFILE" "$DAEMON_PID_PATHFILE"; then
			DisplayCommitToLog 'process not active!'
			break
		fi

		/sbin/curl --silent -insecure --fail --max-time 1 https://localhost:"$port" &>/dev/null

		case $? in
			0|22|52)	# accept these exitcodes as evidence of valid responses
				Display OK
				CommitToLog "port responded after $acc seconds"
				return 0
				;;
			28)			# timeout
				: 			# do nothing
				;;
			7)			# this code is returned immediately
				sleep 1		# ... so let's wait here a bit
				;;
			*)
				: # do nothing
		esac

		((acc+=1))
		DisplayWait "$acc,"

		if [[ $acc -ge $PORT_CHECK_TIMEOUT_SECONDS ]]; then
			DisplayCommitToLog 'failed!'
			CommitErrToSysLog "secure port $port failed to respond after $acc seconds!"
			break
		fi
	done

	return 1

	}

IsConfigFound()
	{

	# Is there an application configuration file?

	[[ -e $QPKG_INI_PATHFILE ]]

	}

IsNotConfigFound()
	{

	! IsConfigFound

	}

IsDefaultConfigFound()
	{

	# Is there a default application configuration file?

	[[ -e $QPKG_INI_DEFAULT_PATHFILE ]]

	}

IsNotDefaultConfigFound()
	{

	! IsDefaultConfigFound

	}

IsVirtualEnvironmentExist()
	{

	# Is there a virtual environment?

	[[ -e $VENV_PATH/bin/activate ]]

	}

IsNotVirtualEnvironmentExist()
	{

	! IsVirtualEnvironmentExist

	}

SetServiceAction()
	{

	service_operation="${1:-}"
	CommitServiceStatus "$service_operation"
	DisplayAndCommitActionToLog

	}

SetServiceStatusAsOK()
	{

	service_result=ok
	CommitServiceStatus "$service_result"
	DisplayAndCommitStatusToLog

	}

SetServiceStatusAsFailed()
	{

	service_result=failed
	CommitServiceStatus "$service_result"
	DisplayAndCommitStatusToLog

	}

CommitServiceStatus()
	{

	# $1 = result of operation to record

	if IsNotStatus && IsNotLog && IsNotNone; then
		[[ -n ${1:-} && -n ${SERVICE_STATUS_PATHFILE:-} ]] && echo "${1:-}" > "$SERVICE_STATUS_PATHFILE"
	fi

	}

SetRestartPending()
	{

	_restart_pending_flag=true

	}

UnsetRestartPending()
	{

	_restart_pending_flag=false

	}

IsRestartPending()
	{

	[[ $_restart_pending_flag = true ]]

	}

IsNotRestartPending()
	{

	[[ $_restart_pending_flag = false ]]

	}

SetError()
	{

	IsError && return
	_error_flag=true

	}

UnsetError()
	{

	IsNotError && return
	_error_flag=false

	}

IsError()
	{

	[[ $_error_flag = true ]]

	}

IsNotError()
	{

	! IsError

	}

IsRestart()
	{

	[[ $service_operation = restart ]]

	}

IsNotRestart()
	{

	! IsRestart

	}

IsNotLog()
	{

	! [[ $service_operation = log ]]

	}

IsNotNone()
	{

	! [[ $service_operation = none ]]

	}

IsClean()
	{

	[[ $service_operation = clean ]]

	}

IsNotClean()
	{

	! IsClean

	}

IsRestore()
	{

	[[ $service_operation = restore ]]

	}

IsNotRestore()
	{

	! IsRestore

	}

IsReset()
	{

	[[ $service_operation = reset ]]

	}

IsNotReset()
	{

	! IsReset

	}

IsNotStatus()
	{

	! [[ $service_operation = status ]]

	}

DisplayErrCommitAllLogs()
	{

	DisplayCommitToLog "${1:-}"
	CommitErrToSysLog "${1:-}"

	}

DisplayCommitToLog()
	{

	Display "${1:-}"
	CommitToLog "${1:-}"

	}

DisplayWaitCommitToLog()
	{

	DisplayWait "${1:-}"
	CommitToLogWait "${1:-}"

	}

FormatAsLogFilename()
	{

	echo "= log file: '${1:-}'"

	}

FormatAsCommand()
	{

	Display "command: '${1:-}'"

	}

FormatAsStdout()
	{

	Display "output: \"${1:-}\""

	}

FormatAsResult()
	{

	Display "result: $(FormatAsExitcode "${1:-}")"

	}

FormatAsResultAndStdout()
	{

	if [[ ${1:-0} -eq 0 ]]; then
		echo "= result_code: $(FormatAsExitcode "$1") ***** stdout/stderr begins below *****"
	else
		echo "! result_code: $(FormatAsExitcode "$1") ***** stdout/stderr begins below *****"
	fi

	echo "${2:-}"
	echo '= ***** stdout/stderr is complete *****'

	}

FormatAsFuncMessages()
	{

	echo "= ${FUNCNAME[1]}()"
	FormatAsCommand "${1:?command null}"
	FormatAsStdout "${2:-}"

	}

FormatAsExitcode()
	{

	echo "[${1:-}]"

	}

FormatAsPackageName()
	{

	echo "'${1:-}'"

	}

DisplayAsHelp()
	{

	printf "  --%-19s  %s\n" "${1:-}" "${2:-}"

	}

Display()
	{

	echo "${1:-}"

	}

DisplayWait()
	{

	echo -n "${1:-} "

	}

DisplayAndCommitActionToLog()
	{

	starttime="$(/bin/date +%s%N)"
	local msg="begin action: $service_operation, datetime: $(date), package: $QPKG_VERSION, service: $SCRIPT_VERSION"

	if IsNotStatus && IsNotLog && IsNotNone; then
		CommitToLog '•'
		DisplayCommitToLog "$(ColourTextInverse "$msg")"
	fi

	}

DisplayAndCommitStatusToLog()
	{

	local msg="end action: $service_operation, datetime: $(date), result: $service_result, elapsed time: $(FormatAsDuration "$(CalcMilliDifference "$starttime" "$(/bin/date +%s%N)")")"

	if IsNotStatus && IsNotLog && IsNotNone; then
		case $service_result in
			ok)
				DisplayCommitToLog "$(ColourTextBlackOnGreen "$msg")"
				;;
			failed)
				DisplayCommitToLog "$(ColourTextBlackOnRed "$msg")"
				;;
			*)
				DisplayCommitToLog "$(ColourTextBlackOnYellow "$msg")"
		esac
	fi

	}

CommitInfoToSysLog()
	{

	CommitSysLog "${1:-}" 4

	}

CommitWarnToSysLog()
	{

	CommitSysLog "${1:-}" 2

	}

CommitErrToSysLog()
	{

	CommitSysLog "${1:-}" 1

	}

CommitToLog()
	{

	if IsNotStatus && IsNotLog && IsNotNone; then
		echo -e "${1:-}" >> "$SERVICE_LOG_PATHFILE"
	fi

	}

CommitToLogWait()
	{

	if IsNotStatus && IsNotLog && IsNotNone; then
		echo -n "${1:-} " >> "$SERVICE_LOG_PATHFILE"
	fi

	}

CommitSysLog()
	{

	# input (global):
	#   $QPKG_NAME

	# input:
	#   $1 = message to append to QTS system log
	#   $2 = event type:
	#	 1 : Error
	#	 2 : Warning
	#	 4 : Information

	if IsNotStatus && IsNotLog && IsNotNone; then
		if [[ -z ${1:-} || -z ${2:-} ]]; then
			SetError
			return 1
		fi

		/sbin/write_log "[$QPKG_NAME] $1" "$2"
	fi

	}

ColourTextBrightWhite()
	{

	printf '\033[1;97m%s\033[0m' "${1:-}"

	} 2>/dev/null

ColourTextBlackOnGreen()
	{

	printf '\033[30;42m%s\033[0m' "${1:-}"

	} 2>/dev/null

ColourTextBlackOnRed()
	{

	printf '\033[30;41m%s\033[0m' "${1:-}"

	} 2>/dev/null

ColourTextBlackOnYellow()
	{

	printf '\033[30;43m%s\033[0m' "${1:-}"

	} 2>/dev/null

ColourTextInverse()
	{

	printf '\033[7m%s\033[0m' "${1:-}"

	} 2>/dev/null

FormatAsPlural()
	{

	[[ $1 -ne 1 ]] && echo s

	}

JustFile()
	{

	local name=$(/usr/bin/basename "$1")
	echo "${name%%.*}"

	}

CalcMilliDifference()
	{

	# input:
	#	$1 = starttime in epoch nanoseconds
	#	$2 = endtime in epoch nanoseconds

	# output:
	#	stdout = difference in milliseconds

	echo "$((($2-$1)/1000000))"

	}

FormatAsThous()
	{

	# Format as thousands

	# A string-based thousands-group formatter totally unreliant on locale
	# Why? Because builtin `printf` in 32b ARM QTS versions doesn't follow locale ¯\_(ツ)_/¯

	# $1 = integer value

	local rightside_group=''
	local foutput=''
	local remainder=$(/bin/sed 's/[^0-9]*//g' <<< "${1:-}")	# strip everything not a numeral

	while [[ ${#remainder} -gt 0 ]]; do
		rightside_group=${remainder:${#remainder}<3?0:-3}	# a nifty trick found here: https://stackoverflow.com/a/19858692

		if [[ -z $foutput ]]; then
			foutput=$rightside_group
		else
			foutput=$rightside_group,$foutput
		fi

		if [[ ${#rightside_group} -eq 3 ]]; then
			remainder=${remainder%???}						# trim rightside 3 characters
		else
			break
		fi
	done

	echo "$foutput"
	return 0

	}

FormatAsDuration()
	{

	# input:
	#	$1 = duration in milliseconds

	if [[ ${1:-0} -lt 10000 ]]; then
		echo "$(FormatAsThous "${1:-0}")ms"
	else
		FormatSecsToHoursMinutesSecs "$(($1/1000))"
	fi

	}

FormatSecsToHoursMinutesSecs()
	{

	# http://stackoverflow.com/questions/12199631/convert-seconds-to-hours-minutes-seconds

	# input:
	#	$1 = a time in seconds to convert to `HHh:MMm:SSs`

	((h=${1:-0}/3600))
	((m=(${1:-0}%3600)/60))
	((s=${1:-0}%60))

	printf '%01dh:%02dm:%02ds\n' "$h" "$m" "$s"

	} 2>/dev/null

IsAutoUpdateMissing()
	{

	[[ $(/sbin/getcfg $QPKG_NAME Auto_Update -f /etc/config/qpkg.conf) = '' ]]

	}

IsAutoUpdate()
	{

	[[ $(Lowercase "$(/sbin/getcfg $QPKG_NAME Auto_Update -f /etc/config/qpkg.conf)") = true ]]

	}

IsNotAutoUpdate()
	{

	! IsAutoUpdate

	}

EnableAutoUpdate()
	{

	StoreAutoUpdateSelection true

	}

DisableAutoUpdate()
	{

	StoreAutoUpdateSelection false

	}

StoreAutoUpdateSelection()
	{

	/sbin/setcfg "$QPKG_NAME" Auto_Update "$(Uppercase "$1")" -f /etc/config/qpkg.conf
	DisplayCommitToLog "auto-update: $1"

	}

GetPathGitBranch()
	{

	[[ -n $1 ]] || return

	/opt/bin/git -C "$1" branch | /bin/grep '^\*' | /bin/sed 's|^\* ||'

	} 2>/dev/null

Init

if IsNotError; then
	case $1 in
		start|--start)
			if IsNotQPKGEnabled; then
				echo "The $(FormatAsPackageName "$QPKG_NAME") QPKG is disabled. Please enable it first with: qpkg_service enable $QPKG_NAME"
				SetError
			else
				SetServiceAction start
				StartQPKG
			fi
			;;
		stop|--stop)
			SetServiceAction stop
			StopQPKG
			;;
		r|-r|restart|--restart)
			if IsNotQPKGEnabled; then
				echo "The $(FormatAsPackageName "$QPKG_NAME") QPKG is disabled. Please enable it first with: qpkg_service enable $QPKG_NAME"
				SetError
			else
				SetServiceAction restart
				StopQPKG && StartQPKG
			fi
			;;
		s|-s|status|--status)
			SetServiceAction status
			StatusQPKG
			;;
		b|-b|backup|--backup|backup-config|--backup-config)
			if IsSupportBackup; then
				SetServiceAction backup
				BackupConfig
			else
				SetServiceAction none
				ShowHelp
			fi
			;;
		reset-config|--reset-config)
			if IsSupportReset; then
				SetServiceAction reset
				StopQPKG
				ResetConfig
				StartQPKG
			else
				SetServiceAction none
				ShowHelp
			fi
			;;
		restore|--restore|restore-config|--restore-config)
			if IsSupportBackup; then
				SetServiceAction restore
				StopQPKG
				RestoreConfig
				StartQPKG
			else
				SetServiceAction none
				ShowHelp
			fi
			;;
		clean|--clean)
			if IsSourcedOnline; then
				SetServiceAction clean
				StopQPKG
				[[ $QPKG_NAME = nzbToMedia ]] && BackupConfig
				CleanLocalClone
				StartQPKG
				[[ $QPKG_NAME = nzbToMedia ]] && RestoreConfig
			else
				SetServiceAction none
				ShowHelp
			fi
			;;
		l|-l|log|--log)
			SetServiceAction log
			ViewLog
			;;
		disable-auto-update|--disable-auto-update)
			SetServiceAction disable-auto-update
			DisableAutoUpdate
			;;
		enable-auto-update|--enable-auto-update)
			SetServiceAction enable-auto-update
			EnableAutoUpdate
			;;
		v|-v|version|--version)
			SetServiceAction none
			Display "package: $QPKG_VERSION"
			Display "service: $SCRIPT_VERSION"
			;;
		remove)		# only called by the QDK .uninstall.sh script
			SetServiceAction uninstall
			;;
		*)
			SetServiceAction none
			ShowHelp
	esac
fi

if IsError; then
	SetServiceStatusAsFailed
	exit 1
fi

SetServiceStatusAsOK
exit
