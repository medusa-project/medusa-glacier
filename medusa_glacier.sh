#!/bin/bash --login

PID_DIR="run"
PID_FILE="$PID_DIR/medusa_glacier.pid"
LOG_DIR="log"
LOG_FILE="$LOG_DIR/medusa_glacier_run.log"
ERROR_FILE="$LOG_DIR/medusa_glacier_run.err"
mkdir -p $PID_DIR
mkdir -p $LOG_DIR

case "$1" in
    start)
	if [ -f $PID_FILE ]; then
	    PID=`cat $PID_FILE`
	    echo "The server appears to be running with pid: $PID"
	else
	    nohup ./medusa_glacier.rb run 2>> $ERROR_FILE >> $LOG_FILE < /dev/null &
	    echo $! > $PID_FILE
	    echo "Started medusa_glacier.rb with pid: $!"
	fi
	;;
    stop)
	if [ -f $PID_FILE ]; then
	    PID=`cat $PID_FILE`
	    COMMAND=`ps -p $PID -o comm=`
	    #The jruby process shows up under ps with the command 'java'
	    if [ "$COMMAND" = "java" ]; then
		echo "Killing medusa_glacier.rb pid: $PID"
		kill $PID
	    else
		echo "Process $PID is not medusa_glacier.rb; removing stale pid file"
	    fi
	    rm $PID_FILE
	else
	    echo "The server does not seem to be running; no pid file found."
	fi
	;;
    toggle-halt-before-next-request)
	if [ -f $PID_FILE ]; then
	    PID=`cat $PID_FILE`
	    kill -USR2 $PID
	    sleep 1 
	    tail -n 1 'log/medusa_glacier.log'
	else
	    echo "The server does not seem to be running; no pid file found."
	fi
	;;
    *)
	echo "Unrecognized command $1"
	;;
esac
