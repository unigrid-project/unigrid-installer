#!/bin/bash
set -e
. /lib/lsb/init-functions

# Must be a valid filename
NAME=unigrid
PIDFILE=/run/$NAME.pid

# Full path to executable
DAEMON="/usr/bin/java -jar /usr/local/bin/groundhog.jar"

# Options
DAEMON_OPTS="start -t=false -l=/usr/local/bin/"

# User to run the command as
USER=root

CLI='/usr/local/bin/unigrid-cli'

export PATH="${PATH:+$PATH:}/usr/sbin:/sbin"

TEST_RESPONSE='{
  "status": "complete",
  "walletstatus": "Done loading",
  "progress": 0
}'

CHECK_IF_RUNNING() {
      GROUNDHOG="$(! pgrep -f groundhog &> /dev/null ; echo $?)"
      echo "groundhog: ${GROUNDHOG}"
      if [ "${GROUNDHOG}" = "0" ]; then
      start-stop-daemon --start --quiet --background --make-pidfile --pidfile $PIDFILE --chuid $USER --exec $DAEMON $DAEMON_OPTS
      echo -e "${TEST_RESPONSE}"
      else
      echo -e "Groundhog is running"
      fi
}

case "$1" in
  start)
        echo -n "Starting daemon: "$NAME
        start-stop-daemon --start --quiet --background --make-pidfile --pidfile $PIDFILE --chuid $USER --exec $DAEMON $DAEMON_OPTS
        echo "."
        ;;
  stop)
        echo -n "Stopping daemon: "$NAME
        start-stop-daemon --stop --quiet --oknodo --pidfile $PIDFILE
        echo "."
        ;;
  restart)
        echo -n "Restarting daemon: "$NAME
        start-stop-daemon --stop --quiet --oknodo --retry 30 --pidfile $PIDFILE
        sleep 0.3
        start-stop-daemon --start --quiet -b -m --pidfile $PIDFILE --chuid $USER --exec $DAEMON $DAEMON_OPTS
        echo "."
        ;;
  unigrid)
        echo -e "`($CLI $2 $3 $4 $5)`"
        ;;
  check)
        CHECK_IF_RUNNING
        ;;
  status)
        status_of_proc -p $PIDFILE $DAEMON $NAME && exit 0 || exit $?
        ;;

  *)
        echo "Usage: "$1" {start|stop|restart|unigrid <COMMAND>}"
        exit 1
esac


