#!/bin/sh

DATA_PATH=${DATA_PATH:-"/data"}
CRONTAB_PATH=${CRONTAB_PATH:-"/var/spool/cron/crontabs"}
CRONTAB_LOG=${CRONTAB_LOG:-"/var/log/cron"}
SCRIPTS_PATH=${SCRIPTS_PATH:-"/usr/local/bin"}

CONFIG="$DATA_PATH/config.json"
ID=$1

# Check ID
if [ -z "$ID" ]; then
  echo "ID is required."
  echo "Usage: ./`basename "$0"` id"
  exit 1
fi

# Check config
if [ ! -e "$CONFIG" ]; then
  echo "ERROR: $CONFIG not found"
  exit 1
fi
if ! jq -e . ${CONFIG} >/dev/null 2>&1; then
  echo "ERROR: Failed to parse JSON file $CONFIG"
  exit 1
fi

# Find and display public key
found=false
for i in $(jq -c -r '.[] | @base64' ${CONFIG}); do
  _jq() {
     echo ${i} | base64 -d  | jq -r ${1}
  }

  if [ ${ID} != $(_jq '.id') ]; then
    continue
  fi

  cat "${DATA_PATH}/.$(_jq '.id')/id_rsa.pub"

  found=true
  break
done

if [ "${found}" != true ]; then
  echo "ERROR: id '${ID}' not found."
fi
