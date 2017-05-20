#!/bin/sh

WAITER_PATHFILE="$(getcfg SHARE_DEF defVolMP -f /etc/config/def_share.info)/.qpkg/wait-for-Entware.sh"
[ -e "$WAITER_PATHFILE" ] && . "$WAITER_PATHFILE" 300

# package specific
QPKG_NAME="SABnzbdplus"
TARGET_SCRIPT="SABnzbd.py"
URL_HTTP="http://github.com/sabnzbd/sabnzbd.git"

# followup
QPKG_PATH="$(/sbin/getcfg $QPKG_NAME Install_Path -f /etc/config/qpkg.conf)"
SETTINGS_PATHFILE="${QPKG_PATH}/config/config.ini"
SETTINGS_DEFAULT_PATHFILE="${SETTINGS_PATHFILE}.def"
SETTINGS="--daemon --browser 0 --config-file $SETTINGS_PATHFILE"

# boilerplate
STORED_PID_PATHFILE="/tmp/${QPKG_NAME}.pid"
DAEMON_OPTS="$TARGET_SCRIPT $SETTINGS --pidfile $STORED_PID_PATHFILE"
QPKG_GIT_PATH="${QPKG_PATH}/${QPKG_NAME}"
LOG_PATHFILE="/var/log/${QPKG_NAME}.log"
DAEMON="/opt/bin/python2.7"
URL_GIT=${URL_HTTP/http/git}
errorcode=0
[ ! -f "$SETTINGS_PATHFILE" ] && [ -f "$SETTINGS_DEFAULT_PATHFILE" ] && cp "$SETTINGS_DEFAULT_PATHFILE" "$SETTINGS_PATHFILE"

QPKGIsActive()
	{

	# $? = 0 if $QPKG_NAME is active
	# $? = 1 if $QPKG_NAME is not active

	local returncode=0
	local active=false
	local msg=""

	[ -f "$STORED_PID_PATHFILE" ] && { PID=$(cat "$STORED_PID_PATHFILE"); [ -d "/proc/$PID" ] && active=true ;}

	if [ "$active" == "true" ]; then
		msg="($QPKG_NAME) is active"
	else
		msg="($QPKG_NAME) is not active"
		returncode=1
	fi

	echo "$msg" | tee -a "$LOG_PATHFILE"
	return $returncode

	}

UpdateQpkg()
	{

	local returncode=0
	local msg=""

	echo -n "Updating ($QPKG_NAME): " | tee -a "$LOG_PATHFILE"
	messages=$({

	[ -d "${QPKG_GIT_PATH}/.git" ] || git clone "$URL_GIT" "$QPKG_GIT_PATH" || git clone "$URL_HTTP" "$QPKG_GIT_PATH"
	cd "$QPKG_GIT_PATH" && git checkout master && git pull && /bin/sync

	} 2>&1 )
	result=$?

	if [ "$result" == "0" ]; then
		msg="OK"
		returncode=0
	else
		msg="failed\nresult=[$result]"
		returncode=1
	fi

	echo -e "$(OutputSeparator start)\n${messages}\n$(OutputSeparator end)" >> "$LOG_PATHFILE"
	echo -e "$msg" | tee -a "$LOG_PATHFILE"
	return $returncode

	}

StartQPKG()
	{

	local returncode=0
	local msg=""

	cd "$QPKG_GIT_PATH"

	echo -n "Starting ($QPKG_NAME): " | tee -a "$LOG_PATHFILE"
	messages="$(PATH=${PATH} ${DAEMON} ${DAEMON_OPTS} >> "$LOG_PATHFILE")"
	result=$?

	if [ "$result" == "0" ]; then
		msg="OK"
	else
		msg="failed\nresult=[$result]"
		errorcode=1
	fi

	echo -e "$(OutputSeparator start)\n${messages}\n$(OutputSeparator end)" >> "$LOG_PATHFILE"
	echo -e "$msg" | tee -a "$LOG_PATHFILE"
	return $returncode

	}

StopQPKG()
	{

	local maxwait=60

	PID=$(cat "$STORED_PID_PATHFILE"); i=0

	kill $PID
	echo -n "Stopping ($QPKG_NAME) with SIGTERM: " | tee -a "$LOG_PATHFILE"
	echo -n "waiting for up to $maxwait seconds: "

	while true; do
		while [ -d /proc/$PID ]; do
			sleep 1
			let i+=1
			echo -n "$i, "
			if [ "$i" -ge "$maxwait" ]; then
				echo -n "failed! " | tee -a "$LOG_PATHFILE"
				kill -9 $PID
				echo -n "Sent SIGKILL. " | tee -a "$LOG_PATHFILE"
				rm -f "$STORED_PID_PATHFILE"
				errorcode=1
				break 2
			fi
		done

		rm -f "$STORED_PID_PATHFILE"
		echo "OK"; echo "stopped OK in $i seconds " >> "$LOG_PATHFILE"
		break
	done

	}

SessionSeparator()
	{

	# $1 = message

	printf '%0.s-' {1..20}; echo -n " $1 "; printf '%0.s-' {1..20}

	}

OutputSeparator()
	{

	# $1 = message

	printf '%0.s-' {1..20}; echo -n " stdout $1 "; printf '%0.s-' {1..20}

	}

case "$1" in
	start)
		echo -e "$(SessionSeparator "start requested")\n$(date)" >> "$LOG_PATHFILE"
		! QPKGIsActive && { UpdateQpkg; StartQPKG ;} || errorcode=1
		;;

	stop)
		echo -e "$(SessionSeparator "stop requested")\n$(date)" >> "$LOG_PATHFILE"
		QPKGIsActive && StopQPKG || errorcode=1
		;;

	restart)
		$0 stop
		$0 start
		;;

	*)
		echo "Usage: $0 {start|stop|restart}"
		;;
esac

exit $errorcode
