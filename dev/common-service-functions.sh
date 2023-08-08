#!/usr/bin/env bash
################################################################################################
# common-service-functions.sh
#
# Copyright (C) 2017-2023 OneCD - one.cd.only@gmail.com
#
# so, blame OneCD if it all goes horribly wrong. ;)
#
# This file is sourced to provide an initial set of common functions for each sherpa QPKG.
################################################################################################

readonly USER_ARGS_RAW=$*

ShowHelp()
	{

	Display "$(ColourTextBrightWhite "$(/usr/bin/basename "$0")") $SCRIPT_VERSION • a service control script for the $(FormatAsPackageName $QPKG_NAME) QPKG"
	Display
	Display "Usage: $0 [ACTION]"
	Display
	Display '[ACTION] may be any one of the following:'
	Display
	DisplayAsHelp start "activate $(FormatAsPackageName $QPKG_NAME) if not already active."
	DisplayAsHelp stop "deactivate $(FormatAsPackageName $QPKG_NAME) if active."
	DisplayAsHelp restart "stop, then start $(FormatAsPackageName $QPKG_NAME)."
	DisplayAsHelp status "check if $(FormatAsPackageName $QPKG_NAME) package is active. Returns \$? = 0 if active, 1 if not."
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

InstallAddons()
	{

	IsVirtualEnvironmentUsed || return 0

	local default_essential_modules_pathfile=$QPKG_CONFIG_PATH/essential.txt
	local default_requirements_modules_pathfile=$QPKG_CONFIG_PATH/requirements.txt
	local default_recommended_modules_pathfile=$QPKG_CONFIG_PATH/recommended.txt

	local essential_modules_pathfile=$QPKG_REPO_PATH/essential.txt
	local requirements_modules_pathfile=$QPKG_REPO_PATH/requirements.txt
	local recommended_modules_pathfile=$QPKG_REPO_PATH/recommended.txt
	local excluded_modules_pathfile=$QPKG_CONFIG_PATH/exclusions.txt
	local rename_modules_pathfile=$QPKG_CONFIG_PATH/rename.txt

	local pyproject_pathfile=$QPKG_REPO_PATH/pyproject.toml
	local pip_conf_pathfile=$VENV_PATH/pip.conf
	local new_env=false
	local sys_packages=' --system-site-packages'
	local no_pips_installed=true
	local pip_deps=' --no-deps'

	[[ $ALLOW_ACCESS_TO_SYS_PACKAGES != true ]] && sys_packages=''
	[[ $INSTALL_PIP_DEPS = true ]] && pip_deps=''

	if IsNotVirtualEnvironmentExist; then
		DisplayRunAndLog 'create new virtual Python environment' "export PIP_CACHE_DIR=$PIP_CACHE_PATH VIRTUALENV_OVERRIDE_APP_DATA=$PIP_CACHE_PATH; $INTERPRETER -m virtualenv ${VENV_PATH}${sys_packages}" log:failure-only
		new_env=true
	fi

	if IsNotVirtualEnvironmentExist; then
		DisplayErrCommitAllLogs 'unable to install addons: virtual environment does not exist!'
		SetError
		return 1
	fi

	if [[ ! -e $pip_conf_pathfile ]]; then
		DisplayRunAndLog "create global 'pip' config" "echo -e \"[global]\ncache-dir = $PIP_CACHE_PATH\" > $pip_conf_pathfile" log:failure-only
	fi

	IsNotAutoUpdate && [[ $new_env = false ]] && return 0

	[[ -e $essential_modules_pathfile && -d $(/usr/bin/dirname "$default_essential_modules_pathfile") ]] && cp -f "$essential_modules_pathfile" "$default_essential_modules_pathfile"
	[[ -e $default_essential_modules_pathfile ]] && essential_modules_pathfile=$default_essential_modules_pathfile

	# Edit developer-provided Python module requirements files out-of-repo

	[[ -e $requirements_modules_pathfile && -d $(/usr/bin/dirname "$default_requirements_modules_pathfile") ]] && cp -f "$requirements_modules_pathfile" "$default_requirements_modules_pathfile"
	[[ -e $default_requirements_modules_pathfile ]] && requirements_modules_pathfile=$default_requirements_modules_pathfile

	[[ -e $recommended_modules_pathfile && -d $(/usr/bin/dirname "$default_recommended_modules_pathfile") ]] && cp -f "$recommended_modules_pathfile" "$default_recommended_modules_pathfile"
	[[ -e $default_recommended_modules_pathfile ]] && recommended_modules_pathfile=$default_recommended_modules_pathfile

	# Must remove these modules from repo txt files, and use the ones installed via `opkg` instead (if available).
	# If not, `pip` will attempt to compile these, which fails on early ARMv5 CPUs.

	if [[ -e $excluded_modules_pathfile ]]; then
		local module_exclusions=$(/bin/tr '\n' ' ' < "$excluded_modules_pathfile")
		module_exclusions=${module_exclusions%* }
		local module_exclusions_re="/^${module_exclusions// /\|^}"

		for target in $essential_modules_pathfile $requirements_modules_pathfile $recommended_modules_pathfile $pyproject_pathfile; do
			if [[ -e $target ]]; then
				DisplayRunAndLog "exclude problem PyPI modules from '$(/usr/bin/basename "$target")'" "/bin/sed -i '${module_exclusions_re}/d' $target" log:failure-only
			fi
		done
	fi

	# Install remaining PyPI modules

	for target in $essential_modules_pathfile $requirements_modules_pathfile $recommended_modules_pathfile; do
		if [[ -e $target ]]; then
			DisplayRunAndLog "install PyPI modules from '$(/usr/bin/basename "$target")'" "$VENV_PIP_PATHFILE install${pip_deps} --no-input --upgrade pip -r $target" log:failure-only
			no_pips_installed=false
		fi
	done

	# Fallback to general installation method

	if [[ $no_pips_installed = true ]]; then
		if [[ -e $QPKG_REPO_PATH/setup.py || -e $pyproject_pathfile ]]; then
			DisplayRunAndLog "install PyPI modules from '$(/usr/bin/basename "$target")'" "$VENV_PIP_PATHFILE install${pip_deps} --no-input --upgrade pip $QPKG_REPO_PATH" log:failure-only
			no_pips_installed=false
		fi
	fi

	# KLUDGE: `manytolinux2014` builds are problematic in QTS, so rename these locally

	if [[ -e $rename_modules_pathfile ]]; then
		for module in $(<$rename_modules_pathfile); do
			RenameSharedObjectFile "$module"
		done
	fi

	return 0

	}

BackupConfig()
	{

	MakePaths
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

MakePaths()
	{

	DisplayWaitCommitToLog 'create paths:'
	[[ -n ${BACKUP_PATH:-} && ! -d $BACKUP_PATH ]] && mkdir -p "$BACKUP_PATH"
	[[ -n ${QPKG_REPO_PATH:-} && ! -d $QPKG_REPO_PATH ]] && mkdir -p "$QPKG_REPO_PATH"
	[[ -n ${PIP_CACHE_PATH:-} && ! -d $PIP_CACHE_PATH ]] && mkdir -p "$PIP_CACHE_PATH"
	IsVirtualEnvironmentUsed && [[ ! -d $VENV_PATH ]] && mkdir -p "$VENV_PATH"
	DisplayCommitToLog OK

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

PullGitRepo()
	{

	# inputs (global):
	#   $QPKG_NAME
	#   $SOURCE_GIT_URL
	#   $SOURCE_GIT_BRANCH
	#   $SOURCE_GIT_BRANCH_DEPTH
	#   $QPKG_REPO_PATH

	IsGitBranch || return 0

	local branch_depth='--depth 1'
	[[ $SOURCE_GIT_BRANCH_DEPTH = single-branch ]] && branch_depth='--single-branch'
	local active_branch=$(GetPathGitBranch "$QPKG_REPO_PATH")
	local branch_switch=false

	WaitForGit || return

	if [[ -d $QPKG_REPO_PATH/.git ]]; then
		if [[ $active_branch != "$SOURCE_GIT_BRANCH" ]]; then
			branch_switch=true
			DisplayCommitToLog "active git branch: '$active_branch', new git branch: '$SOURCE_GIT_BRANCH'"
			[[ $QPKG_NAME = nzbToMedia ]] && BackupConfig
			DisplayRunAndLog 'new git branch has been specified, so clean local repository' "cd /tmp; rm -r $QPKG_REPO_PATH" log:failure-only
		fi
	fi

	if [[ ! -d $QPKG_REPO_PATH/.git ]]; then
		DisplayRunAndLog "clone $(FormatAsPackageName "$QPKG_NAME") from remote repository" "cd /tmp; /opt/bin/git clone --branch $SOURCE_GIT_BRANCH $branch_depth -c advice.detachedHead=false $SOURCE_GIT_URL $QPKG_REPO_PATH" log:failure-only
	else
		if IsAutoUpdate; then
			# latest effort at resolving local clone corruption: https://stackoverflow.com/a/10170195
			DisplayRunAndLog "update $(FormatAsPackageName "$QPKG_NAME") from remote repository" "cd /tmp; /opt/bin/git -C $QPKG_REPO_PATH clean -f; /opt/bin/git -C $QPKG_REPO_PATH reset --hard origin/$SOURCE_GIT_BRANCH; /opt/bin/git -C $QPKG_REPO_PATH pull" log:failure-only
		fi
	fi

	if IsAutoUpdate; then
		DisplayCommitToLog "active git branch: '$(GetPathGitBranch "$QPKG_REPO_PATH")'"
	fi

	[[ $branch_switch = true && $QPKG_NAME = nzbToMedia ]] && RestoreConfig

	return 0

	}

CleanLocalClone()
	{

	# for occasions where the local repo needs to be deleted and cloned again from source.

	if [[ -z $QPKG_PATH || -z $QPKG_NAME ]] || IsNotSourcedOnline; then
		SetError
		return 1
	fi

	DisplayRunAndLog 'clean local repository' "rm -rf \"$QPKG_REPO_PATH\"" log:failure-only
	[[ -n $QPKG_REPO_PATH && -d $(/usr/bin/dirname "$QPKG_REPO_PATH")/$QPKG_NAME ]] && DisplayRunAndLog 'KLUDGE: remove previous local repository' "rm -r \"$(/usr/bin/dirname "$QPKG_REPO_PATH")/$QPKG_NAME\"" log:failure-only
	IsVirtualEnvironmentUsed && [[ -d $VENV_PATH ]] && DisplayRunAndLog 'clean virtual environment' "rm -rf \"$VENV_PATH\"" log:failure-only
	[[ -n $PIP_CACHE_PATH && -d $PIP_CACHE_PATH ]] && DisplayRunAndLog 'clean PyPI cache' "rm -rf \"$PIP_CACHE_PATH\"" log:failure-only
	[[ -e $APP_VERSION_STORE_PATHFILE ]] && DisplayRunAndLog 'remove application version' "rm -f \"$APP_VERSION_STORE_PATHFILE\"" log:failure-only

	}

WaitForGit()
	{

	if WaitForFileToAppear '/opt/bin/git' 300; then
		export PATH="$OPKG_PATH:$(/bin/sed "s|$OPKG_PATH||" <<< "$PATH")"
		return 0
	fi

	return 1

	}

GetLaunchTarget()
	{

	if [[ -n ${VENV_PYTHON_PATHFILE:-} ]]; then
		echo "$VENV_PYTHON_PATHFILE"
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

	local target_pid=''

	if [[ $DAEMON_PROC_IS_NAME_ONLY = true ]]; then
		# QTS `pidof` is unreliable and should be used as a last resort only
		target_pid="$(/bin/pidof -s "$(/usr/bin/basename "$DAEMON_PATHFILE")")"
	else
		target_pid="$(/bin/ps | /bin/grep "$(GetLaunchTarget)" | /bin/grep -v grep)"
		target_pid=${target_pid:0:5}
		target_pid=$(/bin/tr -d ' ' <<< "$target_pid")
	fi

	if [[ $target_pid -gt 0 ]]; then
		echo "$target_pid" > "$DAEMON_PID_PATHFILE"
		return 0
	fi

	rm -f "$DAEMON_PID_PATHFILE"

	return 1

	}

WaitForPID()
	{

	local -i count=0

	if [[ $PIDFILE_IS_MANAGED_BY_APP = true ]]; then
		if WaitForFileToAppear "$DAEMON_PID_PATHFILE" "$PIDFILE_APPEAR_TIMEOUT_SECONDS"; then
			/bin/sleep 1		# wait one more second to allow file to have PID written into it
		fi
	fi

	if [[ $RECHECK_DAEMON_PID_AFTER_LAUNCH = true ]]; then
		DisplayWaitCommitToLog 'found daemon PID:'

		if FindAndWritePIDFile; then
			DisplayCommitToLog "$(<"$DAEMON_PID_PATHFILE")"
		else
			DisplayCommitToLog false
		fi

		DisplayWaitCommitToLog "wait $PIDFILE_RECHECK_WAIT_SECONDS second$(Pluralise "$PIDFILE_RECHECK_WAIT_SECONDS") to recheck PID:"

		for ((count=1; count<=PIDFILE_RECHECK_WAIT_SECONDS; count++)); do
			/bin/sleep 1
			DisplayWait "$count,"
		done

		DisplayCommitToLog 'done'
	fi

	DisplayWaitCommitToLog 'found daemon PID:'

	if FindAndWritePIDFile; then
		DisplayCommitToLog "$(<"$DAEMON_PID_PATHFILE")"
	else
		DisplayErrCommitAllLogs false
		DisplayErrCommitAllLogs 'unable to locate active daemon process'
		return 1
	fi

	return 0

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
		DisplayWait "(no-more than $MAX_SECONDS second$(Pluralise "$MAX_SECONDS")):"

		local target_proc=''

		if [[ $DAEMON_PROC_IS_NAME_ONLY = true ]]; then
			target_proc=$(/usr/bin/basename "$DAEMON_PATHFILE")
		else
			target_proc="$(GetLaunchTarget)"
		fi

		(
			for ((count=1; count<=MAX_SECONDS; count++)); do
				/bin/sleep 1
				DisplayWait "$count,"

				if IsProcessActive "$target_proc" "$DAEMON_PID_PATHFILE"; then
					Display OK
					CommitToLog "active after $count second$(Pluralise "$count")"
					true
					exit	# only this sub-shell
				fi
			done

			false
		)

		if [[ $? -ne 0 ]]; then
			DisplayCommitToLog 'failed!'
			DisplayErrCommitAllLogs "daemon not found! (exceeded timeout: $MAX_SECONDS second$(Pluralise "$MAX_SECONDS"))"
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
		DisplayWait "(no-more than $MAX_SECONDS second$(Pluralise "$MAX_SECONDS")):"

		(
			for ((count=1; count<=MAX_SECONDS; count++)); do
				/bin/sleep 1
				DisplayWait "$count,"

				if [[ -e $1 ]]; then
					Display OK
					CommitToLog "visible after $count second$(Pluralise "$count")"
					true
					exit	# only this sub-shell
				fi
			done
			false
		)

		if [[ $? -ne 0 ]]; then
			DisplayCommitToLog 'failed!'
			DisplayErrCommitAllLogs "$1 not found! (exceeded timeout: $MAX_SECONDS second$(Pluralise "$MAX_SECONDS"))"
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

	if [[ $result_code -eq 0 ]]; then
		[[ ${3:-} != log:failure-only ]] && CommitInfoToSysLog "${1:?empty}: OK"
		DisplayCommitToLog OK
	else
		DisplayErrCommitAllLogs 'failed!'
	fi

	if [[ $result_code -eq 0 ]]; then
		[[ ${3:-} != log:failure-only ]] && AddFileToDebug "$LOG_PATHFILE"
	else
		[[ $result_code -ne ${4:-} ]] && AddFileToDebug "$LOG_PATHFILE"
	fi

	[[ -e $LOG_PATHFILE ]] && rm -f "$LOG_PATHFILE"
	return $result_code

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
			result_code=${PIPESTATUS[0]}						# must use $PIPESTATUS after `tee` to get returncode of previous command: https://stackoverflow.com/questions/1221833/pipe-output-and-capture-exit-status-in-bash
		else
			Display "exec (in screen session): '$1'"
		fi
	else
		if [[ ${5:-false} = false ]]; then
			(eval "$1" > "$LOG_PATHFILE" 2>&1)					# run in a subshell to suppress 'Terminated' message later
			result_code=$?
		fi
	fi

	if [[ ${5:-false} = true ]]; then
		/usr/sbin/screen -c "$SCREEN_CONF_PATHFILE" -dmLS "$QPKG_NAME" bash -c "$1"
		result_code=$?
	fi

	if [[ -e $LOG_PATHFILE ]]; then
		FormatAsResultAndStdout "$result_code" "$(<"$LOG_PATHFILE")" >> "$2"
	else
		FormatAsResultAndStdout "$result_code" '<null>' >> "$2"
	fi

	if [[ $debug = true ]]; then
		if [[ $result_code -eq 0 ]]; then
			Display 'exec: completed OK'
		else
			Display 'exec: completed, but with errors'
		fi
	fi

	[[ -e $LOG_PATHFILE ]] && rm -f "$LOG_PATHFILE"
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

Capitalise()
	{

	# capitalise first character of $1

	echo "$(Uppercase ${1:0:1})${1:1}"

	}

Uppercase()
	{

	/bin/tr 'a-z' 'A-Z' <<< "$1"

	}

Lowercase()
	{

	/bin/tr 'A-Z' 'a-z' <<< "$1"

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

GetPythonVer()
	{

	local v=''
	v=$(GetThisBinPath ${1:-python} &>/dev/null && ${1:-python} -V 2>&1 | /bin/sed 's|^Python ||;s|\.||g')
	[[ -n $v ]] && echo "${v:0:3}"

	}

GetThisBinPath()
	{

	[[ -n ${1:?null} ]] && command -v "$1" 2>&1

	}

RenameSharedObjectFile()
	{

	# need to check 3 possible module locations

	[[ -n ${1:-} ]] || return

	if [[ -e $(GetModulePath)/$(GetOriginalModuleSOFilename "_$1") ]]; then
		mv "$(GetModulePath)/$(GetOriginalModuleSOFilename "_$1")" "$(GetModulePath)/$(GetFixedModuleSOFilename "_$1")"
		DisplayCommitToLog "renamed module: _$1"
	fi

	if [[ -e $(GetModulePath)/$1/$(GetOriginalModuleSOFilename "$1") ]]; then
		mv "$(GetModulePath)/$1/$(GetOriginalModuleSOFilename "$1")" "$(GetModulePath)/$1/$(GetFixedModuleSOFilename "$1")"
		DisplayCommitToLog "renamed module: $1/$1"
	fi

	if [[ -e $(GetModulePath)/$(GetOriginalModuleSOFilename "$1") ]]; then
		mv "$(GetModulePath)/$(GetOriginalModuleSOFilename "$1")" "$(GetModulePath)/$(GetFixedModuleSOFilename "$1")"
		DisplayCommitToLog "renamed module: $1"
	fi

	return 0

	}

GetOriginalModuleSOFilename()
	{

	[[ -z $pyver ]] && pyver=$(GetPythonVer)
	[[ -n ${1:-} ]] && echo "$1.cpython-$pyver-$(uname -m)-linux-gnu.so"

	}

GetFixedModuleSOFilename()
	{

	[[ -z $pyver ]] && pyver=$(GetPythonVer)
	[[ -n ${1:-} ]] && echo "$1.cpython-$pyver.so"

	}

GetModulePath()
	{

	[[ -z $pyver ]] && pyver=$(GetPythonVer)
	echo "$VENV_PATH/lib/python${pyver:0:1}.${pyver:1:2}/site-packages"

	}

parse_yaml()
	{

	# a nice bit of coding! https://stackoverflow.com/a/21189044

	# input:
	#   $1 = filename to parse

	# output:
	#   stdout = parsed YAML

	local prefix=$2
	local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')

	/bin/sed -ne "s|^\($s\):|\1|" \
		-e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
		-e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
		/bin/awk -F$fs '{
			indent = length($1)/2;
			vname[indent] = $2;
			for (i in vname) {if (i > indent) {delete vname[i]}}
				if (length($3) > 0) {
				vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
				printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
				}
			}'
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

IsGitBranch()
	{

	[[ -n ${SOURCE_GIT_BRANCH:-} ]]

	}

IsNotGitBranch()
	{

	! IsGitBranch

	}

IsVirtualEnvironmentUsed()
	{

	[[ -n $VENV_PATH ]]

	}

IsNotVirtualEnvironmentUsed()
	{

	! IsVirtualEnvironmentUsed

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

	local target_proc=''

	if [[ $DAEMON_PROC_IS_NAME_ONLY = true ]]; then
		target_proc=$(/usr/bin/basename "$(GetLaunchTarget)")
	else
		target_proc="$(GetLaunchTarget)"
	fi

	if IsProcessActive "$target_proc" "$DAEMON_PID_PATHFILE"; then
		DisplayCommitToLog true
		DisplayCommitToLog "daemon PID: $(<"$DAEMON_PID_PATHFILE")"
		return 0
	fi

	DisplayCommitToLog false
	rm -f "$DAEMON_PID_PATHFILE"
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
	DisplayWait "(no-more than $PORT_CHECK_TIMEOUT_SECONDS second$(Pluralise "$PORT_CHECK_TIMEOUT_SECONDS")):"

	local target_proc=''

	if [[ $DAEMON_PROC_IS_NAME_ONLY = true ]]; then
		target_proc=$(/usr/bin/basename "$DAEMON_PATHFILE")
	else
		target_proc="$(GetLaunchTarget)"
	fi

	while true; do
		if ! IsProcessActive "$target_proc" "$DAEMON_PID_PATHFILE"; then
			DisplayCommitToLog 'process not active!'
			break
		fi

		/sbin/curl --silent --fail --max-time 1 http://localhost:"$port" &>/dev/null

		case $? in
			0|22|52)	# accept these exitcodes as evidence of valid responses
				Display OK
				CommitToLog "port responded after $acc second$(Pluralise "$acc")"
				return 0
				;;
			28)			# timeout
				: 			# do nothing
				;;
			7)			# this code is returned immediately
				/bin/sleep 1		# ... so let's wait here a bit
				;;
			*)
				: # do nothing
		esac

		((acc+=1))
		DisplayWait "$acc,"

		if [[ $acc -ge $PORT_CHECK_TIMEOUT_SECONDS ]]; then
			DisplayCommitToLog 'failed!'
			CommitErrToSysLog "port $port failed to respond after $acc second$(Pluralise "$acc")!"
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
	DisplayWait "(no-more than $PORT_CHECK_TIMEOUT_SECONDS second$(Pluralise "$PORT_CHECK_TIMEOUT_SECONDS")):"

	local target_proc=''

	if [[ $DAEMON_PROC_IS_NAME_ONLY = true ]]; then
		target_proc=$(/usr/bin/basename "$DAEMON_PATHFILE")
	else
		target_proc="$(GetLaunchTarget)"
	fi

	while true; do
		if ! IsProcessActive "$target_proc" "$DAEMON_PID_PATHFILE"; then
			DisplayCommitToLog 'process not active!'
			break
		fi

		/sbin/curl --silent -insecure --fail --max-time 1 https://localhost:"$port" &>/dev/null

		case $? in
			0|22|52)	# accept these exitcodes as evidence of valid responses
				Display OK
				CommitToLog "port responded after $acc second$(Pluralise "$acc")"
				return 0
				;;
			28)			# timeout
				: 			# do nothing
				;;
			7)			# this code is returned immediately
				/bin/sleep 1		# ... so let's wait here a bit
				;;
			*)
				: # do nothing
		esac

		((acc+=1))
		DisplayWait "$acc,"

		if [[ $acc -ge $PORT_CHECK_TIMEOUT_SECONDS ]]; then
			DisplayCommitToLog 'failed!'
			CommitErrToSysLog "secure port $port failed to respond after $acc second$(Pluralise "$acc")!"
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

	service_operation="${1:-unspecified}"
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

IsUnsupported()
	{

	[[ $service_operation = unsupported ]]

	}

ShowAsError()
	{

	# fatal error

	local capitalised="$(Capitalise "${1:-}")"

	Display "$(ColourTextBrightRed derp): $capitalised"

	} >&2

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

	[[ $service_operation = unspecified ]] && return

	starttime="$(/bin/date +%s%N)"
	local msg="source: $(/usr/bin/basename "$0"), action: $service_operation, datetime: $(date), package: $QPKG_VERSION, service: $SCRIPT_VERSION"
	msg=$(/bin/tr -s ' ' <<< "$msg")
	local target=DisplayCommitToLog

	if IsNotStatus && IsNotLog && IsNotNone; then
		IsUnsupported && target=CommitToLog
		CommitToLog '•'

		$target "$(ColourTextInverse "$msg")"
	fi

	}

DisplayAndCommitStatusToLog()
	{

	[[ $service_operation = unspecified ]] && return

	local msg="source: $(/usr/bin/basename "$0"), action: $service_operation, datetime: $(date), result: $service_result, elapsed time: $(FormatAsDuration "$(CalcMilliDifference "$starttime" "$(/bin/date +%s%N)")")"
	msg=$(/bin/tr -s ' ' <<< "$msg")
	local target=DisplayCommitToLog

	if IsNotStatus && IsNotLog && IsNotNone; then
		IsUnsupported && target=CommitToLog

		case $service_result in
			ok)
				$target "$(ColourTextBlackOnGreen "$msg")"
				;;
			failed)
				$target "$(ColourTextBlackOnRed "$msg")"
				;;
			*)
				$target "$(ColourTextBlackOnYellow "$msg")"
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
		[[ ${1:-} = '•' && ! -s "$SERVICE_LOG_PATHFILE" ]] || echo -e "${1:-}" >> "$SERVICE_LOG_PATHFILE"
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

ColourTextBrightRed()
	{

	printf '\033[1;31m%s\033[0m' "${1:-}"

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

Pluralise()
	{

	[[ ${1:-0} -ne 1 ]] && echo s

	}

CalcMilliDifference()
	{

	# input:
	#	$1 = starttime in epoch nanoseconds
	#	$2 = endtime in epoch nanoseconds

	# output:
	#	stdout = difference in milliseconds

	local start=${1:-0}
	local end=${2:-1}

	echo "$(((end-start)/1000000))"

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

IsSU()
	{

	# running as superuser?

	if [[ $EUID -ne 0 ]]; then
		if [[ -e /usr/bin/sudo ]]; then
			ShowAsError 'this utility must be run with superuser privileges. Try again as:'
			Display "${CHARS_SUDO_PROMPT}$0 $USER_ARGS_RAW" >&2
		else
			ShowAsError "this utility must be run as the 'admin' user. Please login via SSH as 'admin' and try again"
		fi

		return 1
	fi

	return 0

	}

ShowUnsupportedAction()
	{

	ShowAsError "specified action '$1' is unsupported by this service script."
	SetError
	CommitToLog "specified action '$1' is unsupported."
	Display
	ShowHelp

	}

Init

if IsNotError; then
	case $1 in
		start|--start)
			IsSU ||	exit 1
			SetServiceAction start

			if IsNotQPKGEnabled; then
				DisplayCommitToLog "$(FormatAsPackageName "$QPKG_NAME") QPKG is disabled. Please enable it first with: qpkg_service enable $QPKG_NAME"
				SetError
			else
				StartQPKG
			fi
			;;
		stop|--stop)
			IsSU ||	exit 1
			SetServiceAction stop
			StopQPKG
			;;
		r|-r|restart|--restart)
			IsSU ||	exit 1
			SetServiceAction restart

			if IsNotQPKGEnabled; then
				DisplayCommitToLog "$(FormatAsPackageName "$QPKG_NAME") QPKG is disabled. Please enable it first with: qpkg_service enable $QPKG_NAME"
				SetError
			else
				StopQPKG && StartQPKG
			fi
			;;
		s|-s|status|--status)
			SetServiceAction status
			StatusQPKG
			;;
		b|-b|backup|--backup|backup-config|--backup-config)
			IsSU ||	exit 1

			if IsSupportBackup; then
				SetServiceAction backup
				BackupConfig
			else
				SetServiceAction unsupported
				ShowUnsupportedAction "$1"
			fi
			;;
		reset-config|--reset-config)
			IsSU ||	exit 1

			if IsSupportReset; then
				SetServiceAction reset
				StopQPKG
				ResetConfig
				StartQPKG
			else
				SetServiceAction unsupported
				ShowUnsupportedAction "$1"
			fi
			;;
		restore|--restore|restore-config|--restore-config)
			IsSU ||	exit 1

			if IsSupportBackup; then
				SetServiceAction restore
				StopQPKG
				RestoreConfig
				StartQPKG
			else
				SetServiceAction unsupported
				ShowUnsupportedAction "$1"
			fi
			;;
		clean|--clean)
			IsSU ||	exit 1

			if IsSourcedOnline; then
				SetServiceAction clean
				StopQPKG
				[[ $QPKG_NAME = nzbToMedia ]] && BackupConfig
				CleanLocalClone
				StartQPKG
				[[ $QPKG_NAME = nzbToMedia ]] && RestoreConfig
			else
				SetServiceAction unsupported
				ShowUnsupportedAction "$1"
			fi
			;;
		l|-l|log|--log)
			SetServiceAction log
			ViewLog
			;;
		disable-auto-update|--disable-auto-update)
			IsSU ||	exit 1

			if IsSourcedOnline; then
				SetServiceAction disable-auto-update
				DisableAutoUpdate
			else
				SetServiceAction unsupported
				ShowUnsupportedAction "$1"
			fi
			;;
		enable-auto-update|--enable-auto-update)
			IsSU ||	exit 1

			if IsSourcedOnline; then
				SetServiceAction enable-auto-update
				EnableAutoUpdate
			else
				SetServiceAction unsupported
				ShowUnsupportedAction "$1"
			fi
			;;
		v|-v|version|--version)
			SetServiceAction none
			Display "package: $QPKG_VERSION"
			Display "service: $SCRIPT_VERSION"
			;;
		remove)			# only called by the QDK '.uninstall.sh' script
			SetServiceAction uninstall
			;;
		*)
			if [[ -z $1 ]]; then
				ShowHelp
			else
				SetServiceAction unsupported
				ShowUnsupportedAction "$1"
			fi
	esac
fi

if IsError; then
	SetServiceStatusAsFailed
	exit 1
fi

SetServiceStatusAsOK
exit
