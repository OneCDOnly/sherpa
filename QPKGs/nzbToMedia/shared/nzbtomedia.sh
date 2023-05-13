#!/usr/bin/env bash
####################################################################################
# nzbtomedia.sh

# Copyright (C) 2020-2023 OneCD - one.cd.only@gmail.com

# so, blame OneCD if it all goes horribly wrong. ;)

# This is a type 2 service-script: https://github.com/OneCDOnly/sherpa/wiki/Service-Script-Types

# For more info: https://forum.qnap.com/viewtopic.php?f=320&t=132373
####################################################################################

readonly USER_ARGS_RAW=$*

Init()
	{

	IsQNAP || return

	# service-script environment
	readonly QPKG_NAME=nzbToMedia
	readonly SCRIPT_VERSION=230513

	# general environment
	readonly QPKG_PATH=$(/sbin/getcfg $QPKG_NAME Install_Path -f /etc/config/qpkg.conf)
	readonly QPKG_VERSION=$(/sbin/getcfg $QPKG_NAME Version -d unknown -f /etc/config/qpkg.conf)
	readonly APP_VERSION_STORE_PATHFILE=$QPKG_PATH/config/version.stored
	readonly SERVICE_STATUS_PATHFILE=/var/run/$QPKG_NAME.last.operation
	readonly SERVICE_LOG_PATHFILE=/var/log/$QPKG_NAME.log
	local -r BACKUP_PATH=$(/sbin/getcfg SHARE_DEF defVolMP -f /etc/config/def_share.info)/.qpkg_config_backup
	readonly BACKUP_PATHFILE=$BACKUP_PATH/$QPKG_NAME.config.tar.gz
	readonly OPKG_PATH=/opt/bin:/opt/sbin
	export PATH="$OPKG_PATH:$(/bin/sed "s|$OPKG_PATH||" <<< "$PATH")"
	readonly DEBUG_LOG_DATAWIDTH=100
	local re=''

	# specific to online-sourced applications only
	readonly SOURCE_GIT_URL=https://github.com/clinton-hall/nzbToMedia.git
	readonly SOURCE_GIT_BRANCH=master
	# 'shallow' (depth 1) or 'single-branch' ... 'shallow' implies 'single-branch'
	readonly SOURCE_GIT_BRANCH_DEPTH=shallow
	readonly QPKG_REPO_PATH=$QPKG_PATH/repo-cache
	readonly PIP_CACHE_PATH=$QPKG_PATH/pip-cache
	readonly INTERPRETER=/opt/bin/python3
	readonly VENV_PATH=$QPKG_PATH/venv
	readonly VENV_INTERPRETER=$VENV_PATH/bin/python3
	readonly ALLOW_ACCESS_TO_SYS_PACKAGES=false
	readonly INSTALL_PIP_DEPS=true
	readonly QPKG_INI_PATHFILE=$QPKG_REPO_PATH/autoProcessMedia.cfg
	readonly QPKG_INI_DEFAULT_PATHFILE=$QPKG_INI_PATHFILE.spec

	# specific to nzbToMedia
	local default_scripts_path=$(/sbin/getcfg $QPKG_NAME Scripts_Path -d '' -f /etc/config/qpkg.conf)
	local default_download_share=$(/sbin/getcfg SHARE_DEF defVolMP -f /etc/config/def_share.info)/$(/sbin/getcfg SHARE_DEF defDownload -d unspecified -f /etc/config/def_share.info)

	if [[ -z $default_download_share ]] || [[ -n $default_download_share && ! -L $default_download_share ]]; then
		default_download_share=unspecified
	fi

	if [[ -n $default_scripts_path ]]; then
		scripts_path_source="$QPKG_NAME 'Scripts_Path'"
		scripts_path=$default_scripts_path
	elif IsQPKGInstalled SABnzbd; then
		scripts_path_source="SABnzbd 'script_dir'"
		scripts_path=$(/sbin/getcfg misc script_dir -d /share/Public/Downloads -f "$(/sbin/getcfg SABnzbd Install_Path -f /etc/config/qpkg.conf)"/config/config.ini)
	elif IsQPKGInstalled NZBGet; then
		scripts_path_source="NZBGet 'MainDir'"
		scripts_path=$(/sbin/getcfg '' MainDir -d /share/Public/Downloads -f "$(/sbin/getcfg NZBGet Install_Path -f /etc/config/qpkg.conf)"/config/config.ini)
	elif [[ $default_download_share != unspecified ]]; then
		scripts_path_source="QTS 'Download' share"
		scripts_path=$default_download_share
	else
		scripts_path_source='default'
		scripts_path=/share/Public/Downloads
	fi

	[[ $scripts_path != "$QPKG_REPO_PATH" && $(/usr/bin/basename "$scripts_path") != "$QPKG_NAME" ]] && scripts_path+=/$QPKG_NAME

	# specific to applications supporting version lookup only
	readonly APP_VERSION_PATHFILE=$QPKG_REPO_PATH/.bumpversion.cfg
	readonly APP_VERSION_CMD="/sbin/getcfg bumpversion current_version -d 0 -f $APP_VERSION_PATHFILE"

	if [[ -z $LANG ]]; then
		export LANG=en_US.UTF-8
		export LC_ALL=en_US.UTF-8
		export LC_CTYPE=en_US.UTF-8
	fi

	if [[ ${DEBUG_QPKG:-} = true ]]; then
		SetDebug
	else
		UnsetDebug
	fi

	for re in \\bd\\b \\bdebug\\b \\bdbug\\b \\bverbose\\b; do
		if [[ $USER_ARGS_RAW =~ $re ]]; then
			SetDebug
			break
		fi
	done

	UnsetError
	UnsetRestartPending
	LoadAppVersion

	IsSupportBackup && [[ -n ${BACKUP_PATH:-} && ! -d $BACKUP_PATH ]] && mkdir -p "$BACKUP_PATH"
	[[ -n ${VENV_PATH:-} && ! -d $VENV_PATH ]] && mkdir -p "$VENV_PATH"
	[[ -n ${PIP_CACHE_PATH:-} && ! -d $PIP_CACHE_PATH ]] && mkdir -p "$PIP_CACHE_PATH"
	[[ ! -e $(/usr/bin/dirname "$scripts_path") ]] && mkdir -p "$(/usr/bin/dirname "$scripts_path")"

	IsAutoUpdateMissing && EnableAutoUpdate >/dev/null

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

StartQPKG()
	{

	# this function is customised depending on the requirements of the packaged application

	IsError && return

	if IsNotRestart && IsNotRestore && IsNotClean && IsNotReset; then
		CommitOperationToLog
	fi

	if IsRestore || IsClean || IsReset; then
		IsRestartPending || return
	fi

	DisplayWaitCommitToLog 'auto-update:'

	if IsAutoUpdate; then
		DisplayCommitToLog true
	else
		DisplayCommitToLog false
	fi

	PullGitRepo || { SetError; return 1 ;}
	WaitForLaunchTarget || { SetError; return 1 ;}

	if [[ $scripts_path = "$QPKG_REPO_PATH" ]]; then
		DisplayCommitToLog "direct path matches scripts_path, so don't create a symlink"
	elif [[ ! -L $scripts_path ]]; then
		[[ -d $scripts_path ]] && DisplayRunAndLog 'a local path is in the way of the target, moving it aside' "mv $scripts_path $scripts_path.prev"
		ln -s "$QPKG_REPO_PATH" "$scripts_path"
		DisplayCommitToLog "symlink created from: $scripts_path to: $QPKG_REPO_PATH"
	fi

	DisplayCommitToLog 'start package: OK'
	EnsureConfigFileExists
	IsPackageActive || { SetError; return 1 ;}

	return 0

	}

StopQPKG()
	{

	# this function is customised depending on the requirements of the packaged application

	IsError && return

	if IsNotRestore && IsNotClean && IsNotReset; then
		CommitOperationToLog
	fi

	if IsRestart || IsRestore || IsClean || IsReset; then
		IsPackageActive && SetRestartPending
	fi

	[[ -L $scripts_path ]] && rm "$scripts_path"
	DisplayCommitToLog 'stop package: OK'
	IsNotPackageActive	# if scripts_path = repo_path then package will always appear to be started
	return 0

	}

BackupConfig()
	{

	CommitOperationToLog

	if [[ ! -e $QPKG_REPO_PATH/autoProcessMedia.cfg ]]; then
		DisplayCommitToLog 'unable to backup configuration: nothing to backup'
		return
	fi

	DisplayRunAndLog 'update configuration backup' "/bin/tar --create --gzip --file=$BACKUP_PATHFILE --directory=$QPKG_REPO_PATH autoProcessMedia.cfg" || SetError

	return 0

	}

RestoreConfig()
	{

	CommitOperationToLog

	if [[ ! -f $BACKUP_PATHFILE ]]; then
		DisplayErrCommitAllLogs 'unable to restore configuration: no backup file found'
		return
	fi

	if [[ $QPKG_NAME = nzbToMedia && ! -d $QPKG_REPO_PATH ]]; then	# specific to nzbToMedia, can only restore after repo-cache has been created
		DisplayErrCommitAllLogs 'unable to restore configuration: restore directory does not exist'
		DisplayErrCommitAllLogs "please 'start' this QPKG first, then 'restore' the backup"
		SetError
		return 1
	fi

	DisplayRunAndLog 'restore configuration backup' "/bin/tar --extract --gzip --file=$BACKUP_PATHFILE --directory=$QPKG_REPO_PATH" || SetError

	return 0

	}

ResetConfig()
	{

	CommitOperationToLog
	DisplayRunAndLog 'reset configuration' "rm $QPKG_INI_PATHFILE" || SetError

	return 0

	}

LoadPorts()
	{

	# If user changes ports via app UI, must first 'stop' application on old ports, then 'start' on new ports

	case $1 in
		app)
			# Read the current application UI ports from application configuration
			DisplayWaitCommitToLog 'load ports from configuration file:'
			[[ -n ${UI_PORT_CMD:-} ]] && ui_port=$(eval "$UI_PORT_CMD")
			[[ -n ${UI_PORT_SECURE_CMD:-} ]] && ui_port_secure=$(eval "$UI_PORT_SECURE_CMD")
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
	[[ -n ${DAEMON_PORT_CMD:-} ]] && daemon_port=$(eval "$DAEMON_PORT_CMD")
	[[ -n ${UI_LISTENING_ADDRESS_CMD:-} ]] && ui_listening_address=$(eval "$UI_LISTENING_ADDRESS_CMD")

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
	IsPackageActive && exit 0 || exit 1

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

	CommitOperationToLog

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

WaitForLaunchTarget()
	{

	local launch_target=''

	if [[ -n ${INTERPRETER:-} ]]; then
		launch_target=$INTERPRETER
	elif [[ -n ${DAEMON_PATHFILE:-} ]]; then
		launch_target=$DAEMON_PATHFILE
	else
		return 0
	fi

	WaitForFileToAppear "$launch_target" 30 || return

	}

WritePID()
	{

	/bin/pidof -s $(/usr/bin/basename "$DAEMON_PATHFILE") > "$DAEMON_PID_PATHFILE"

	if [[ -s $DAEMON_PID_PATHFILE ]]; then
		return 0
	else
		return 1
	fi

	}

WaitForPID()
	{

	if WaitForFileToAppear "$DAEMON_PID_PATHFILE" 60; then
		sleep 1		# wait one more second to allow file to have PID written into it
		return 0
	else
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
		MAX_SECONDS=$DAEMON_CHECK_TIMEOUT
	fi

	if [[ ! -e $1 ]]; then
		DisplayWaitCommitToLog "wait for daemon to appear:"
		DisplayWait "(no-more than $MAX_SECONDS seconds):"

		(
			for ((count=1; count<=MAX_SECONDS; count++)); do
				sleep 1
				DisplayWait "$count,"

				if IsProcessActive "$DAEMON_PATHFILE" "$DAEMON_PID_PATHFILE"; then
					Display OK
					CommitLog "active in $count second$(FormatAsPlural "$count")"
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
					CommitLog "visible in $count second$(FormatAsPlural "$count")"
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
			LESSSECURE=1 /opt/bin/less +G --quit-on-intr --tilde --LINE-NUMBERS --prompt ' use arrow-keys to scroll up-down left-right, press Q to quit' "$SERVICE_LOG_PATHFILE"
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

ViewLog()
	{

	if [[ -e $SERVICE_LOG_PATHFILE ]]; then
		if [[ -e /opt/bin/less ]]; then
			LESSSECURE=1 /opt/bin/less +G --quit-on-intr --tilde --LINE-NUMBERS --prompt ' use arrow-keys to scroll up-down left-right, press Q to quit' "$SERVICE_LOG_PATHFILE"
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

DisplayRunAndLog()
	{

	# Run a commandstring with a summarised description, log the results, and show onscreen if required
	# This function is just a fancy wrapper for RunAndLog()

	# input:
	#   $1 = processing message
	#   $2 = commandstring to execute
	#   $3 = 'log:failure-only' (optional) - if specified, stdout & stderr are only recorded in the specified log if the command failed. default is to always record stdout & stderr.
	#   $4 = e.g. 'background' (optional) - run command as a background process

	local -r LOG_PATHFILE=$(/bin/mktemp /var/log/"${FUNCNAME[0]}"_XXXXXX)
	local -i result_code=0

	DisplayWaitCommitToLog "$1:"

	RunAndLog "${2:?empty}" "$LOG_PATHFILE" "${3:-}" '' "${4:-}"
	result_code=$?

	if [[ -e $LOG_PATHFILE ]]; then
		rm -f "$LOG_PATHFILE"
	fi

	if [[ $result_code -eq 0 ]]; then
		DisplayCommitToLog OK
		[[ ${3:-} != log:failure-only ]] && CommitInfoToSysLog "${1:?empty}: OK"
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
	#   $2 = pathfile to record stdout and stderr for commandstring
	#   $3 = 'log:failure-only' (optional) - if specified, stdout & stderr are only recorded in the specified log if the command failed. default is to always record stdout & stderr.
	#   $4 = e.g. '10' (optional) - an additional acceptable result code. Any other result from command (other than zero) will be considered a failure
	#   $5 = e.g. 'background' (optional) - run command as a background process

	# output:
	#   stdout : commandstring stdout and stderr if script is in 'debug' mode
	#   pathfile ($2) : commandstring ($1) stdout and stderr
	#   $? : $result_code of commandstring

	local -r LOG_PATHFILE=$(/bin/mktemp /var/log/"${FUNCNAME[0]}"_XXXXXX)
	local -i result_code=0

	FormatAsCommand "${1:?empty}" > "${2:?empty}"

	if IsDebug; then
		Display
		Display "exec: '$1'"

		if [[ ${5:-} != background ]]; then
			eval "$1 > >(/usr/bin/tee $LOG_PATHFILE) 2>&1"		# NOTE: 'tee' buffers stdout here
		else
			eval "$1 > >(/usr/bin/tee $LOG_PATHFILE) 2>&1" &	# NOTE: 'tee' buffers stdout here
		fi

		result_code=$?
	else
		if [[ ${5:-} != background ]]; then
			eval "$1" > "$LOG_PATHFILE" 2>&1
		else
 			eval "$1" > "$LOG_PATHFILE" 2>&1 &
		fi

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
	else
		[[ $result_code -ne ${4:-} ]] && AddFileToDebug "$2"
	fi

	return $result_code

	}

AddFileToDebug()
	{

	# Add the contents of specified pathfile $1 to the runtime log

	local debug_was_set=false
	local linebuff=''

	if IsDebug; then	# prevent external log contents appearing onscreen again, as they have already been seen "live"
		debug_was_set=true
		UnsetDebug
	fi

	DebugAsLog ''
	DebugAsLog 'adding external log to main log ...'
	DebugExtLogMinorSeparator
	DebugAsLog "$(FormatAsLogFilename "${1:?no filename supplied}")"

	while read -r linebuff; do
		DebugAsLog "$linebuff"
	done < "$1"

	DebugExtLogMinorSeparator
	[[ $debug_was_set = true ]] && SetDebug

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

	IsDebug && Display "${1:-}"
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

	[[ -n ${DAEMON_PORT_CMD:-} ]] && return		# dont need to rewrite QTS UI ports if this app has a daemon port, as UI ports are unused

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

	eval "$UI_PORT_SECURE_ENABLED_TEST_CMD"

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
	[[ -e $2 && -d /proc/$(<"$2") && -n ${1:-} && $(</proc/"$(<"$2")"/cmdline) =~ ${1:-} ]]

	}

IsDaemonActive()
	{

	# $? = 0 : $DAEMON_PATHFILE is in memory
	# $? = 1 : $DAEMON_PATHFILE is not in memory

	DisplayWaitCommitToLog 'daemon active:'

	if IsProcessActive "$DAEMON_PATHFILE" "$DAEMON_PID_PATHFILE"; then
		DisplayCommitToLog true
		DisplayCommitToLog "daemon PID: $(<"$DAEMON_PID_PATHFILE")"
		return 0
	fi

	DisplayCommitToLog false
	[[ -f $DAEMON_PID_PATHFILE ]] && rm "$DAEMON_PID_PATHFILE"
	return 1

	}

IsNotDaemonActive()
	{

	! IsDaemonActive

	}

IsPackageActive()
	{

	# $? = 0 : package is `started`
	# $? = 1 : package is `stopped`

	DisplayWaitCommitToLog 'package active:'

	if [[ -L $scripts_path || $scripts_path = "$QPKG_REPO_PATH" ]]; then
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
	DisplayWait "(no-more than $PORT_CHECK_TIMEOUT seconds):"

	while true; do
		if ! IsProcessActive "$DAEMON_PATHFILE" "$DAEMON_PID_PATHFILE"; then
			DisplayCommitToLog 'process not active!'
			break
		fi

		/sbin/curl --silent --fail --max-time 1 http://localhost:"$port" &>/dev/null

		case $? in
			0|22|52)	# accept these exitcodes as evidence of valid responses
				Display OK
				CommitLog "port responded after $acc seconds"
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

		if [[ $acc -ge $PORT_CHECK_TIMEOUT ]]; then
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
	DisplayWait "(no-more than $PORT_CHECK_TIMEOUT seconds):"

	while true; do
		if ! IsProcessActive "$DAEMON_PATHFILE" "$DAEMON_PID_PATHFILE"; then
			DisplayCommitToLog 'process not active!'
			break
		fi

		/sbin/curl --silent -insecure --fail --max-time 1 https://localhost:"$port" &>/dev/null

		case $? in
			0|22|52)	# accept these exitcodes as evidence of valid responses
				Display OK
				CommitLog "port responded after $acc seconds"
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

		if [[ $acc -ge $PORT_CHECK_TIMEOUT ]]; then
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

SetServiceOperation()
	{

	case ${1:-} in
		none|removing|versioning|logging)
			: # don't display when running the above actions
			;;
		*)
			if IsQPKGEnabled; then
				DisplayCommitToLog "scripts_path_source: $scripts_path_source"
				DisplayCommitToLog "scripts_path: $scripts_path"
			fi
	esac

	service_operation="${1:-}"
	SetServiceOperationResult "${1:-}"

	}

SetServiceOperationResultOK()
	{

	SetServiceOperationResult ok

	}

SetServiceOperationResultFailed()
	{

	SetServiceOperationResult failed

	}

SetServiceOperationResult()
	{

	# $1 = result of operation to record

	[[ -n ${1:-} && -n ${SERVICE_STATUS_PATHFILE:-} ]] && echo "${1:-}" > "$SERVICE_STATUS_PATHFILE"

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

SetDebug()
	{

	debug=true

	}

UnsetDebug()
	{

	debug=false

	}

IsDebug()
	{

	[[ $debug = true ]]

	}

IsNotDebug()
	{

	! IsDebug

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

	[[ $service_operation = restarting ]]

	}

IsNotRestart()
	{

	! IsRestart

	}

IsNotRestore()
	{

	! [[ $service_operation = restoring ]]

	}

IsNotLog()
	{

	! [[ $service_operation = log ]]

	}

IsClean()
	{

	[[ $service_operation = cleaning ]]

	}

IsNotClean()
	{

	! IsClean

	}

IsRestore()
	{

	[[ $service_operation = restoring ]]

	}

IsNotRestore()
	{

	! IsRestore

	}

IsReset()
	{

	[[ $service_operation = 'resetting-config' ]]

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
	CommitLog "${1:-}"

	}

DisplayWaitCommitToLog()
	{

	DisplayWait "${1:-}"
	CommitLogWait "${1:-}"

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

CommitOperationToLog()
	{

	CommitLog "$(SessionSeparator "datetime:'$(date)', request:'$service_operation', package:'$QPKG_VERSION', service:'$SCRIPT_VERSION', app:'$app_version'")"

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

CommitLog()
	{

	if IsNotStatus && IsNotLog; then
		echo "${1:-}" >> "$SERVICE_LOG_PATHFILE"
	fi

	}

CommitLogWait()
	{

	if IsNotStatus && IsNotLog; then
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

	if [[ -z ${1:-} || -z ${2:-} ]]; then
		SetError
		return 1
	fi

	/sbin/write_log "[$QPKG_NAME] $1" "$2"

	}

SessionSeparator()
	{

	# $1 = message

	printf '%0.s>' {1..10}; echo -n " $1 "; printf '%0.s<' {1..10}

	}

ColourTextBrightWhite()
	{

	printf '\033[1;97m%s\033[0m' "${1:-}"

	} 2>/dev/null

FormatAsPlural()
	{

	[[ $1 -ne 1 ]] && echo s

	}

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
				SetServiceOperation starting
				StartQPKG
			fi
			;;
		stop|--stop)
			SetServiceOperation stopping
			StopQPKG
			;;
		r|-r|restart|--restart)
			if IsNotQPKGEnabled; then
				echo "The $(FormatAsPackageName "$QPKG_NAME") QPKG is disabled. Please enable it first with: qpkg_service enable $QPKG_NAME"
				SetError
			else
				SetServiceOperation restarting
				StopQPKG && StartQPKG
			fi
			;;
		s|-s|status|--status)
			StatusQPKG
			;;
		b|-b|backup|--backup|backup-config|--backup-config)
			if IsSupportBackup; then
				SetServiceOperation backing-up
				BackupConfig
			else
				SetServiceOperation none
				ShowHelp
			fi
			;;
		reset-config|--reset-config)
			if IsSupportReset; then
				SetServiceOperation resetting-config
				StopQPKG
				ResetConfig
				StartQPKG
			else
				SetServiceOperation none
				ShowHelp
			fi
			;;
		restore|--restore|restore-config|--restore-config)
			if IsSupportBackup; then
				SetServiceOperation restoring
				StopQPKG
				RestoreConfig
				StartQPKG
			else
				SetServiceOperation none
				ShowHelp
			fi
			;;
		clean|--clean)
			if IsSourcedOnline; then
				SetServiceOperation cleaning
				StopQPKG
				[[ $QPKG_NAME = nzbToMedia ]] && BackupConfig
				CleanLocalClone
				StartQPKG
				[[ $QPKG_NAME = nzbToMedia ]] && RestoreConfig
			else
				SetServiceOperation none
				ShowHelp
			fi
			;;
		l|-l|log|--log)
			SetServiceOperation logging
			ViewLog
			;;
		disable-auto-update|--disable-auto-update)
			SetServiceOperation disable-auto-update
			DisableAutoUpdate
			;;
		enable-auto-update|--enable-auto-update)
			SetServiceOperation enable-auto-update
			EnableAutoUpdate
			;;
		v|-v|version|--version)
			SetServiceOperation versioning
			Display "package: $QPKG_VERSION"
			Display "service: $SCRIPT_VERSION"
			;;
		remove)		# only called by the QDK .uninstall.sh script
			SetServiceOperation removing
			;;
		*)
			SetServiceOperation none
			ShowHelp
	esac
fi

if IsError; then
	SetServiceOperationResultFailed
	exit 1
fi

SetServiceOperationResultOK
exit
