#!/bin/sh

DATA_PATH=${DATA_PATH:-"/data"}
CRONTAB_PATH=${CRONTAB_PATH:-"/var/spool/cron/crontabs"}
CRONTAB_LOG=${CRONTAB_LOG:-"/var/log/cron"}
SCRIPTS_PATH=${SCRIPTS_PATH:-"/usr/local/bin"}

USER="root"
SSH_PATH="/$USER/.ssh"
CONFIG="$DATA_PATH/config.json"

# Timezone
ln -snf /usr/share/zoneinfo/${TZ:-"UTC"} /etc/localtime
echo ${TZ:-"UTC"} > /etc/timezone

# Check config
if [ ! -e "$CONFIG" ]; then
  echo "ERROR: $CONFIG not found"
  exec "$@"
  exit 0
fi
if ! jq -e . ${CONFIG} >/dev/null 2>&1; then
  echo "ERROR: Failed to parse JSON file $CONFIG"
  exec "$@"
  exit 0
fi

# Init
mkdir -p "${SSH_PATH}"
chmod 700 "${SSH_PATH}"
> "${SSH_PATH}/config"
chmod 400 "${SSH_PATH}/config"
rm -rf "${CRONTAB_PATH}"
mkdir -m 0644 -p "${CRONTAB_PATH}"

# Iterate config
for i in $(jq -c -r '.[] | @base64' ${CONFIG}); do
  _jq() {
    local _tmp=$(echo ${i} | base64 -d | jq -r ${1})
    if [ ! -z "${_tmp}" -a "${_tmp}" != "null" -a "${_tmp}" != "[]" ]; then
      echo "${_tmp}"
    fi
  }

  # Vars
  id=$(_jq '.id')
  pid_file="/var/run/${id}.pid"
  basefolder="${DATA_PATH}/.${id}"
  repofolder="${DATA_PATH}/.${id}/repo"
  authorsfile="${basefolder}/authors.txt"
  cron=$(_jq '.cron')
  crontab="${CRONTAB_PATH}/${id}"
  svn2git_repo=$(_jq '.svn2git.repo')
  svn2git_username=$(_jq '.svn2git.username')
  svn2git_password=$(_jq '.svn2git.password')
  svn2git_options=$(_jq '.svn2git.options')
  git_hostname=$(_jq '.git.hostname')
  git_port=$(_jq '.git.port')
  git_user=$(_jq '.git.user')
  git_repo=$(_jq '.git.repo')
  git_master=$(_jq '.git.master')
  authors=$(_jq '.authors')

  printf "\n#### Init ${id} ####\n"

  # Create folders
  mkdir -p ${repofolder}
  cd ${basefolder}

  # Create authors file
  > ${authorsfile}
  if [ ! -z "${authors}" ]; then
    printf "\n= Generating authors file...\n"
    for j in $(echo "$authors" | jq -r '.[] | @base64'); do
      __jq() {
        local _tmp=$(echo ${j} | base64 -d | jq -r ${1})
        if [ ! -z "${_tmp}" -a "${_tmp}" != "null" -a "${_tmp}" != "[]" ]; then
          echo "${_tmp}"
        fi
      }
      echo "$(__jq '.svn') = $(__jq '.git')" >> ${authorsfile}
    done
    cat ${authorsfile}
  fi

  # Create SSH key if not exist
  if [ ! -f "${basefolder}/id_rsa" ]; then
    printf "\n= Generating SSH key in ${basefolder}/id_rsa...\n"
    ssh-keygen -b 2048 -t rsa -f "${basefolder}/id_rsa" -q -N ""
    echo "To display the public key type: cat ${basefolder}/id_rsa.pub"
  fi

  # Create SSH config
  cat >> "${SSH_PATH}/config" <<EOL
Host ${id} ${git_hostname}
  Hostname ${git_hostname}
  Port ${git_port}
  IdentityFile "${basefolder}/id_rsa"
  StrictHostKeyChecking no

EOL

  # Create rebase script
  cat > "${SCRIPTS_PATH}/${id}_rebase" <<EOL
#!/bin/sh

cd ${repofolder}

# Check if already running
currentPid=\$\$
if [ -f ${pid_file} ]; then
  oldPid=\$(cat ${pid_file})
  if [ -d "/proc/\$oldPid" ]; then
    exit 0
  fi
fi
echo \${currentPid} > ${pid_file}

# Store SVN username and password
if [ ! -z "${svn2git_username}" ]; then
  svn info --username "${svn2git_username}" --password "${svn2git_password}" \
  --config-option servers:global:store-passwords=yes \
  --config-option servers:global:store-plaintext-passwords=yes \
  ${svn2git_repo} > /dev/null
fi

# Init
if [ ! -d "${repofolder}/.git" ]; then
  printf "\n## Info about SVN repository...\n"
  svn info ${svn2git_repo}

  printf "\n## Init Git repository...\n"
  svn2git ${svn2git_repo} ${svn2git_options} --authors "${authorsfile}"
  git remote add origin ${git_user}@${id}:${git_repo}.git
  git config --add remote.origin.push 'refs/remotes/svn/*:refs/heads/*'
  git gc
fi

# Rebase
printf "\n## Rebasing...\n"
svn2git --rebase --authors "${authorsfile}"

printf "\nTesting access to Git repository...\n"
ssh -i "${basefolder}/id_rsa" -T git@github.com
if [ "\$?" != "1" ]; then
  rm -f ${pid_file}
  exit 1
fi

printf "\n## Pushing to Git repository...\n"
git push origin

rm -f ${pid_file}
EOL
  chmod a+x "${SCRIPTS_PATH}/${id}_rebase"

  # Create gc script
cat > "${SCRIPTS_PATH}/${id}_gc" <<EOL
#!/bin/sh

cd ${repofolder}

# Check if already running
currentPid=\$\$
if [ -f ${pid_file} ]; then
  oldPid=\$(cat ${pid_file})
  if [ -d "/proc/\$oldPid" ]; then
    exit 0
  fi
fi
echo \${currentPid} > ${pid_file}

printf "\n## Cleanup unnecessary files and optimize the local repository...\n"
git gc
EOL
  chmod a+x "${SCRIPTS_PATH}/${id}_gc"

  # Create crontab
  > ${crontab}
  echo "${cron} ${SCRIPTS_PATH}/execute ${id} ${SCRIPTS_PATH}/${id}_rebase > /proc/1/fd/1 2>/proc/1/fd/2" >> ${crontab}
  echo "0 2 * * * ${SCRIPTS_PATH}/execute ${id} ${SCRIPTS_PATH}/${id}_gc > /proc/1/fd/1 2>/proc/1/fd/2" >> ${crontab}

  #sh "${SCRIPTS_PATH}/${id}_rebase"
  cd ${DATA_PATH}
done

# Perms crons
chmod -R 0644 "${CRONTAB_PATH}"

printf "\n"
exec "$@"
