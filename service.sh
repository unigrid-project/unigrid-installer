#!/bin/sh

set -e
. /lib/lsb/init-functions

# Must be a valid filename
NAME=unigrid
PIDFILE=/run/$NAME.pid

# Full path to executable
DAEMON="java -- -jar /usr/local/bin/groundhog.jar"

# Options
DAEMON_OPTS="start -t=false -l=/usr/local/bin/"

# User to run the command as
USER=root

CLI='/usr/local/bin/unigrid-cli'

export PATH="${PATH:+$PATH:}/usr/sbin:/sbin"

export PATH="${PATH:+$PATH:}/usr/sbin:/sbin"

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
        start-stop-daemon --start --quiet -b -m --pidfile $PIDFILE --chuid $USER --exec $DAEMON 
        echo "."
        ;;
  unigrid)
        echo -n "calling unigrid: "$NAME
        ($CLI $2 $3 $4 $5) 
        echo "."
        ;;
  status)
        status_of_proc -p $PIDFILE $DAEMON $NAME && exit 0 || exit $?
        ;;

  *)
        echo "Usage: "$1" {start|stop|restart|unigrid <COMMAND>}"
        exit 1
esac


