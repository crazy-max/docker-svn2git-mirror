#!/bin/sh

DATA_PATH=${DATA_PATH:-"/data"}
CRONTAB_PATH=${CRONTAB_PATH:-"/var/spool/cron/crontabs"}
SCRIPTS_PATH=${SCRIPTS_PATH:-"/usr/local/bin"}

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
exec $2 2>&1 | sed "s/^/[$1] /"
