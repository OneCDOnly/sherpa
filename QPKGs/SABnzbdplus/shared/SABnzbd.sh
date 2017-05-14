#!/bin/sh
# an updated version of Clinton Hall's original init script. :)

. $(getcfg SHARE_DEF defVolMP -f /etc/config/def_share.info)/.qpkg/wait-for-Entware.sh 300

QPKG_NAME="SABnzbdplus"
QPKG_DIR=$(getcfg $QPKG_NAME Install_Path -f /etc/config/qpkg.conf)
DAEMON="/opt/bin/python"
DAEMON_PACKAGE="$QPKG_DIR/Repository/lib/python"
DAEMON_OPTS=" SABnzbd.py -f ${QPKG_DIR}/config/sabnzbd.ini --browser 0 --daemon --pid /tmp"	# note: '--pid' only sets the path to the PID file, not the name
PID_NAME="/tmp/sabnzbd" 																	# am a bit lazy to code the pidpath in a variable too, so change path here to path set by --pid in the line above
PID_FILE="$PID_NAME-$(getcfg Misc port -f ${QPKG_DIR}/config/sabnzbd.ini).pid" 				# sabnzbd itself names it's pidfile to sabnzbd-<portnr-listening-on> can be http or https port
DOWNLOAD_PATH=$(getcfg SHARE_DEF defDownload -d Qdownload -f /etc/config/def_share.info)

if [ -z "$LANG" ]; then
  export LANG=en_US.UTF-8
  export LC_ALL=en_US.UTF-8
  export LC_CTYPE=en_US.UTF-8
fi

export PYTHONPATH=$DAEMON_PACKAGE

CheckQpkgRunning()
	{

	#exit if the file exists, else grab the https port and recheck
	[ -f $PID_FILE ] && exit 1 #Normal HTTP port
	PID_FILE="$PID_NAME-$(getcfg Misc https_port -f ${QPKG_DIR}/config/sabnzbd.ini).pid"
	[ -f $PID_FILE ] && exit 1 #HTTPS port

	}

UpdateScripts()
	{

	echo "-> updating nzbToMedia scripts ..."

	local nzb_git_url=git://github.com/clinton-hall/nzbToMedia.git
	local nzb_git_url1=https://github.com/clinton-hall/nzbToMedia.git
	local target_path="/share/${DOWNLOAD_PATH}/nzbToMedia"

	cd "$target_path"

	if [ ! -d ${target_path}/.git ]; then
		#git clone the qpkg in a temp dir ($$ returns the pid we are running under, should be random enough)
		git clone "$nzb_git_url" "$target_path" || git clone "$nzb_git_url1" "$target_path"
	fi

	if [ ! -d "${target_path}/.git" ]; then
		echo "Could not git clone $nzb_git_url"
	fi

	git reset --hard
	git pull
 	sleep 10

	}

CheckEnvironment()
	{

	echo "-> checking environment ..."

	if [ ! -d $(getcfg $DOWNLOAD_PATH path -f /etc/config/smb.conf -d /ERROR) ] || [ ! -d "/share/${DOWNLOAD_PATH}" ]; then
		echo "$DOWNLOAD_PATH was not found, aborting QPKG start."
		exit 1
	fi

	DIRSCAN_dir=$(getcfg misc dirscan_dir -f $QPKG_DIR/config/sabnzbd.ini)
	NZB_backup_dir=$(getcfg misc nzb_backup_dir -f $QPKG_DIR/config/sabnzbd.ini)
	DOWNLOAD_dir=$(getcfg misc download_dir -f $QPKG_DIR/config/sabnzbd.ini)
	CACHE_dir=$(getcfg misc cache_dir -f $QPKG_DIR/config/sabnzbd.ini)
	COMPLETE_dir=$(getcfg misc complete_dir -f $QPKG_DIR/config/sabnzbd.ini)
	SCRIPT_dir=$(getcfg misc script_dir -f $QPKG_DIR/config/sabnzbd.ini)

	[ -d "$SAB_DIR" ] || mkdir -pm 777 "$SAB_DIR"
	[ -d "$DIRSCAN_dir" ] || mkdir -pm 777 "$DIRSCAN_dir"
	[ -d "$NZB_backup_dir" ] || mkdir -pm 777 "$NZB_backup_dir"
	[ -d "$DOWNLOAD_dir" ]|| mkdir -pm 777 "$DOWNLOAD_dir"
	[ -d "$CACHE_dir" ] || mkdir -pm 777 "$CACHE_dir"
	[ -d "$COMPLETE_dir" ] || mkdir -pm 777 "$COMPLETE_dir"
	[ -d "$SCRIPTS_dir" ] || mkdir -pm 777 "$SCRIPTS_dir"

	SCRIPTS_FOLDER="/share/${DOWNLOAD_PATH}/nzbToMedia"
	[ ! -f $SCRIPTS_FOLDER/CharTranslator.py ] && ln -sf "${QPKG_DIR}/scripts/CharTranslator.py" "${SCRIPTS_FOLDER}/CharTranslator.py"

	}

UpgradeApp()
	{

	echo "-> upgrading SABnzbd+ ..."

	local sab_git_url=git://github.com/sabnzbd/sabnzbd.git
	local sab_git_url1=https://github.com/sabnzbd/sabnzbd.git
	local target_path="${QPKG_DIR}/sabnzbd"

	if [ ! -d "${target_path}/.git" ]; then
		git clone "$sab_git_url1" "$target_path" || git clone "$sab_git_url" "$target_path"
		cd "$target_path"
		git checkout master
	else
		cd "$target_path"
	fi

	git pull

	}

StartQpkg()
	{

	echo "-> starting $QPKG_NAME"
	cd ${QPKG_DIR}/sabnzbd
	PATH=${PATH} ${DAEMON} ${DAEMON_OPTS}
	sleep 3

	}

ShutdownQPKG()
	{

	if [ -f $PID_FILE ]; then
		#grab pid from pid file
		Pid=$(cat $PID_FILE)
		i=0
		kill $Pid
		echo -n "-> waiting for ${QPKG_NAME} to shut down: "
		while [ -d /proc/$Pid ]; do
			sleep 1
			let i+=1
			echo -n "$i, "
			if [ $i = 45 ]; then
				echo -n " tired of waiting, killing $QPKG_NAME now"
				kill -9 $Pid
				rm -f $PID_FILE

				echo " done"
				exit 1
			fi
		done

		rm -f $PID_FILE
	else
		echo "$QPKG_NAME is not running?"
	fi

	}

case "$1" in
	start)
		echo "-> prestartup checks ..."

		CheckQpkgRunning
 		UpdateScripts
 		CheckEnvironment
 		UpgradeApp
		StartQpkg
		;;

	stop)
		echo "-> shutting down ${QPKG_NAME} ... "

		[ -f $PID_FILE ] || PID_FILE="$PID_NAME-$(getcfg Misc https_port -f ${QPKG_DIR}/config/sabnzbd.ini).pid"
		ShutdownQPKG
		;;

	restart)
		$0 stop
		$0 start
		;;

	*)
		echo "Usage: $0 {start|stop|restart}"
esac
