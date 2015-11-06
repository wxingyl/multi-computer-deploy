#!/bin/bash
DATE=`date +%F-%T`
TMP_FILE_NAME=`pwd`"/.tmpfile_"$DATE

function kill_process()
{
	times=0
	while [ 1 ]
	do
		ps -ef > $TMP_FILE_NAME
		pid_list=$(cat $TMP_FILE_NAME | awk '/act_server/{print $2}')
		times=$(($times+1))
		echo "pid_list: "$pid_list" times: "$times
		if [ -z "$pid_list" ]
		then
			break
		elif [ $times -ge 10 ]
		then
			kill -9 $pid_list
			break
		fi
		for pid in $pid_list
		do
			kill $pid
		done
		sleep 1
	done
	rm $TMP_FILE_NAME
}

kill_process
