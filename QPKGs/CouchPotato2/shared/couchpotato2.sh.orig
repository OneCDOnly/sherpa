#! /bin/sh

. $(getcfg SHARE_DEF defVolMP -f /etc/config/def_share.info)/.qpkg/wait-for-Entware.sh 300

QPKG_NAME=CouchPotato2
QPKG_DIR=$(/sbin/getcfg $QPKG_NAME Install_Path -f /etc/config/qpkg.conf)
PID_FILE="${QPKG_DIR}/config/couchpotato.pid"
DAEMON=/opt/bin/python2.7
DAEMON_OPTS="CouchPotato.py --daemon --data_dir ${QPKG_DIR}/config --pid_file $PID_FILE"
export PYTHONPATH="${QPKG_DIR}/Repository/lib/python"
URL_GIT="git://github.com/CouchPotato/CouchPotatoServer.git"
URL_HTTPS=${URL_GIT/git/http}

CheckQpkgRunning()
	{

	if [ -f $PID_FILE ]; then
		#grab pid from pid file
		Pid=$(cat $PID_FILE)
		if [ -d /proc/$Pid ]; then
			echo " $QPKG_NAME is already running"
			exit 1
		fi
	fi

	}

UpdateQpkg()
	{

	echo "Updating $QPKG_NAME"

	[ -d $QPKG_DIR/$QPKG_NAME/.git ] || git clone $URL_GIT $QPKG_DIR/$QPKG_NAME || git clone $URL_HTTPS $QPKG_DIR/$QPKG_NAME
	cd $QPKG_DIR/$QPKG_NAME && git reset --hard HEAD && git pull && /bin/sync

	}

StartQpkg()
	{

	echo "Starting $QPKG_NAME"
	cd $QPKG_DIR/$QPKG_NAME
	PATH=${PATH} ${DAEMON} ${DAEMON_OPTS}

	}

ShutdownQPKG()
	{

	echo "Shutting down $QPKG_NAME... "

	if [ -f $PID_FILE ]; then
		#grab pid from pid file
		Pid=$(cat $PID_FILE)
		i=0
		kill $Pid
		echo -n " Waiting for $QPKG_NAME to shut down: "

		while [ -d /proc/$Pid ]; do
			sleep 1
			let i+=1
			echo -n "$i, "
			if [ $i = 45 ]; then
				echo " Tired of waiting, killing $QPKG_NAME now"
				kill -9 $Pid
				rm -f $PID_FILE
				exit 1
			fi
		done
		rm -f $PID_FILE
		echo "Done"
	else
		echo "$QPKG_NAME is not running?"
	fi

	}

case "$1" in
	start)
		echo "$QPKG_NAME prestartup checks..."
		CheckQpkgRunning
		UpdateQpkg
		StartQpkg

		;;

	stop)
		ShutdownQPKG
		;;

	restart)
		echo "Restarting $QPKG_NAME"
		$0 stop
		$0 start
		;;

	*)
		N=/etc/init.d/$QPKG_NAME.sh
		echo "Usage: $N {start|stop|restart}" >&2
		exit 1
		;;
esac
