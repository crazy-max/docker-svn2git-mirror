#!/bin/sh

DATA_PATH=${DATA_PATH:-"/data"}
CRONTAB_PATH=${CRONTAB_PATH:-"/var/spool/cron/crontabs"}
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

# Find and display authors
found=false
for i in $(jq -c -r '.[] | @base64' ${CONFIG}); do
  _jq() {
     echo ${i} | base64 -d  | jq -r ${1}
  }

  if [ ${ID} != $(_jq '.id') ]; then
    continue
  fi

  if [ ! -z "$(_jq '.svn2git.username')" ]; then
    svn log --quiet "$(_jq '.svn2git.repo')" --non-interactive \
      --username "$(_jq '.svn2git.username')" --password "$(_jq '.svn2git.password')" \
      | grep -E "r[0-9]+ \| .+ \|" \
      | cut -d'|' -f2 \
      | sed 's/ //g' | sort | uniq
  else
    svn log --quiet "$(_jq '.svn2git.repo')" --non-interactive \
      | grep -E "r[0-9]+ \| .+ \|" \
      | cut -d'|' -f2 \
      | sed 's/ //g' | sort | uniq
  fi

  found=true
  break
done

if [ "${found}" != true ]; then
  echo "ERROR: id '${ID}' not found."
fi
