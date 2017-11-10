#!/bin/sh

DATA_PATH=${DATA_PATH:-"/data"}
CRONTAB_PATH=${CRONTAB_PATH:-"/var/spool/cron/crontabs"}
CRONTAB_LOG=${CRONTAB_LOG:-"/var/log/cron"}
SCRIPTS_PATH=${SCRIPTS_PATH:-"/usr/local/bin"}

crond -s ${CRONTAB_PATH} \
  -L /dev/stdout \
  -f &

wait
