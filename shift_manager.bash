#!/usr/bin/env bash
PATH="/usr/local/bin:/usr/bin:/bin"
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LANGUAGE=en_US.UTF-8
version="1.0.0"

cd "$(cd -P -- "$(dirname -- "$0")" && pwd -P)"
root_path=$(pwd)

mkdir -p $root_path/logs
logfile=$root_path/logs/shift_manager.log

set_network() {
  if [ "$(grep "7337a324ef27e1e234d1e9018cacff7d4f299a09c2df9be460543b8f7ef652f1" $SHIFT_CONFIG )" ];then
    NETWORK="mainnet"
  elif [ "$(grep "cba57b868c8571599ad594c6607a77cad60cf0372ecde803004d87e679117c12" $SHIFT_CONFIG )" ];then
    NETWORK="testnet"
  else
    NETWORK="unknown"
  fi
}

SHIFT_CONFIG="config.json"
DB_NAME="$(grep "database" $SHIFT_CONFIG | cut -f 4 -d '"' | head -1)"
DB_UNAME="$(grep "user" $SHIFT_CONFIG | cut -f 4 -d '"' | head -1)"
DB_PASSWD="$(grep "password" $SHIFT_CONFIG | cut -f 4 -d '"' | head -1)"
DB_SNAPSHOT="blockchain.db.gz"
DB_PORT="$(cat $SHIFT_CONFIG | jq -r '.port')"

NETWORK=""
set_network
# BLOCKCHAIN_URL="https://downloads.shiftnrg.org/snapshot/$NETWORK"
BLOCKCHAIN_URL="https://snapshot.shiftnrg.io/$NETWORK" 
GIT_BRANCH="$(git branch | sed -n '/\* /s///p')"

install_prereq() {

    if [[ ! -f /usr/bin/sudo ]]; then
        echo "Install sudo before continuing. Issue: apt-get install sudo as root user."
        echo "Also make sure that your user has sudo access."
    fi

    sudo id &> /dev/null || { exit 1; };

    echo ""
    echo "-------------------------------------------------------"
    echo "Shift installer script. Version: $version"
    echo "-------------------------------------------------------"
    
    echo -n "Running: apt-get update... ";
    sudo apt-get update  &> /dev/null || \
    { echo "Could not update apt repositories. Run apt-get update manually. Exiting." && exit 1; };
    echo -e "done.\n"

    echo -n "Running: apt-get install curl build-essential python lsb-release wget openssl autoconf libtool automake libsodium-dev jq dnsutils ... ";
    sudo apt-get install -y -qq curl build-essential python lsb-release wget openssl autoconf libtool automake libsodium-dev jq dnsutils &>> $logfile || \
    { echo "Could not install packages prerequisites. Exiting." && exit 1; };
    echo -e "done.\n"

#    echo -n "Removing former postgresql installation... ";
#    sudo apt-get purge -y -qq postgres* &>> $logfile || \
#    { echo "Could not remove former installation of postgresql. Exiting." && exit 1; };
#    echo -e "done.\n"

    echo -n "Updating apt repository sources for postgresql.. ";
    sudo bash -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ wheezy-pgdg main" > /etc/apt/sources.list.d/pgdg.list' &>> $logfile || \
    { echo "Could not add postgresql repo to apt." && exit 1; }
    echo -e "done.\n"

    echo -n "Adding postgresql repo key... "
    sudo wget -q https://www.postgresql.org/media/keys/ACCC4CF8.asc -O - | sudo apt-key add - &>> $logfile || \
    { echo "Could not add postgresql repo key. Exiting." && exit 1; }
    echo -e "done.\n"

    echo -n "Installing postgresql... "
    sudo apt-get update -qq &> /dev/null && sudo apt-get install -y -qq postgresql-9.6 postgresql-contrib-9.6 libpq-dev &>> $logfile || \
    { echo "Could not install postgresql. Exiting." && exit 1; }
    echo -e "done.\n"

    echo -n "Enable postgresql... "
        sudo update-rc.d postgresql enable
    echo -e "done.\n"

    return 0;
}

ntp_checks() {
    # Install NTP or Chrony for Time Management - Physical Machines only
    if [[ ! -f "/proc/user_beancounters" ]]; then
      if ! sudo pgrep -x "ntpd" > /dev/null; then
        echo -n "Installing NTP... "
        sudo apt-get install ntp -yyq &>> $logfile
        sudo service ntp stop &>> $logfile
        sudo ntpdate pool.ntp.org &>> $logfile
        sudo service ntp start &>> $logfile
        if ! sudo pgrep -x "ntpd" > /dev/null; then 
          echo -e "SHIFT requires NTP running. Please check /etc/ntp.conf and correct any issues. Exiting."
          exit 1
        echo -e "done.\n"
        fi # if sudo pgrep
      fi # if [[ ! -f "/proc/user_beancounters" ]]
    elif [[ -f "/proc/user_beancounters" ]]; then
      echo -e "Running OpenVZ or LXC VM, NTP is not required, done. \n"
    fi
}

create_database() {
    res=$(sudo -u postgres dropdb --if-exists "$DB_NAME" 2> /dev/null)
    res=$(sudo -u postgres createdb -O "$DB_UNAME" "$DB_NAME" 2> /dev/null)
    res=$(sudo -u postgres psql -t -c "SELECT count(*) FROM pg_database where datname='$DB_NAME'" 2> /dev/null)
    
    if [[ $res -eq 1 ]]; then
      echo "√ Postgresql database created successfully."
    else
      echo "X Failed to create Postgresql database."
      exit 1
    fi
}

backup_blockchain() {
  echo "Creating $DB_SNAPSHOT from local node"

  pg_dump --dbname=postgresql://$DB_UNAME:$DB_PASSWD@127.0.0.1:$DB_PORT/$DB_NAME | gzip > $DB_SNAPSHOT

  if [ $? != 0 ]; then
    rm -f $DB_SNAPSHOT
    echo "X Failed to create blockchain snapshot."
    exit 1
  else
    echo "√ Blockchain snapshot created successfully."
  fi
}

download_blockchain() {
    echo -n "Download a recent, verified snapshot? ([y]/n): "
    read downloadornot

    if [ "$downloadornot" == "y" ] || [ -z "$downloadornot" ]; then
        rm -f $DB_SNAPSHOT
        if [ -z "$BLOCKCHAIN_URL" ]; then
            # BLOCKCHAIN_URL="https://downloads.shiftnrg.org/snapshot/$NETWORK"
            BLOCKCHAIN_URL="https://snapshot.shiftnrg.io/$NETWORK"
        fi
        echo "√ Downloading $DB_SNAPSHOT from $BLOCKCHAIN_URL"
        curl --progress-bar -o $DB_SNAPSHOT "$BLOCKCHAIN_URL/$DB_SNAPSHOT"
        if [ $? != 0 ]; then
            rm -f $DB_SNAPSHOT
            echo "X Failed to download blockchain snapshot."
            exit 1
        else
            echo "√ Blockchain snapshot downloaded successfully."
            return 0
        fi
    else
        echo -e "√ Using Local Snapshot."
    fi
}

restore_blockchain() {
    export PGPASSWORD=$DB_PASSWD
    echo "Restoring blockchain with $DB_SNAPSHOT"
    gunzip -fcq "$DB_SNAPSHOT" | psql -q -h 127.0.0.1 -U "$DB_UNAME" -d "$DB_NAME" &> /dev/null
    if [ $? != 0 ]; then
        echo "X Failed to restore blockchain."
        exit 1
    else
        echo "√ Blockchain restored successfully."
    fi
}

add_pg_user_database() {

    if start_postgres; then
        user_exists=$(grep postgres /etc/passwd |wc -l);
        if [[ $user_exists == 1 ]]; then
            res=$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$DB_UNAME'" 2> /dev/null)
            if [[ $res -ne 1 ]]; then
              echo -n "Creating database user... "
              res=$(sudo -u postgres psql -c "CREATE USER $DB_UNAME WITH PASSWORD '$DB_PASSWD';" 2> /dev/null)
              res=$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$DB_UNAME'" 2> /dev/null)
              if [[ $res -eq 1 ]]; then
                echo -e "done.\n"
              fi
            fi

            echo -n "Creating database... "
            res=$(sudo -u postgres dropdb --if-exists "$DB_NAME" 2> /dev/null)
            res=$(sudo -u postgres createdb -O "$DB_UNAME" "$DB_NAME" 2> /dev/null)
            res=$(sudo -u postgres psql -t -c "SELECT count(*) FROM pg_database where datname='$DB_NAME'" 2> /dev/null)
            if [[ $res -eq 1 ]]; then
                echo -e "done.\n"
            fi
        fi
        return 0
    fi

    return 1;
}

start_postgres() {

    installed=$(dpkg -l |grep postgresql |grep ii |head -n1 |wc -l);
    running=$(ps aux |grep "bin\/postgres" |wc -l);

    if [[ $installed -ne 1 ]]; then
        echo "Postgres is not installed. Install postgres manually before continuing. Exiting."
        exit 1;
    fi

    if [[ $running -ne 1 ]]; then
        sudo /etc/init.d/postgresql start &>> $logfile || { echo -n "Could not start postgresql, try to start it manually. Exiting." && exit 1; }
    fi

    return 0
}

install_node_npm() {

    echo -n "Installing nodejs and npm... "
    curl -sL https://deb.nodesource.com/setup_10.x | sudo -E bash - &>> $logfile
    sudo apt-get install -y -qq nodejs &>> $logfile || { echo "Could not install nodejs and npm. Exiting." && exit 1; }
    echo -e "done.\n" && echo -n "Installing grunt-cli... "
    sudo npm install grunt-cli -g &>> $logfile || { echo "Could not install grunt-cli. Exiting." && exit 1; }
    echo -e "done.\n" && echo -n "Installing bower... "
    sudo npm install bower -g &>> $logfile || { echo "Could not install bower. Exiting." && exit 1; }
    echo -e "done.\n" && echo -n "Installing process management software... "
    sudo npm install forever -g &>> $logfile || { echo "Could not install process management software(forever). Exiting." && exit 1; }
    echo -e "done.\n"

    return 0;
}

install_shift() {

    echo -n "Installing Shift core... "
    npm install --production &>> $logfile || { echo "Could not install SHIFT, please check the log directory. Exiting." && exit 1; }
    echo -e "done.\n"

    return 0;
}

install_webui() {

    echo -n "Installing Shift WebUi... "
    git clone https://github.com/shiftnrg/shift-wallet &>> $logfile || { echo -n "Could not clone git wallet source. Exiting." && exit 1; }

    if [[ -d "public" ]]; then
        rm -rf public/
    fi

    if [[ -d "shift-wallet" ]]; then
        mv shift-wallet public
    else
        echo "Could not find installation directory for SHIFT web wallet. Install the web wallet manually."
        exit 1;
    fi
    
    # Bower config seems to have the wrong permissions. Make sure we change these before trying to use bower.
    if [[ -d /home/$USER/.config ]]; then
        sudo chown -R $USER:$USER /home/$USER/.config &> /dev/null
    fi

    cd public && npm install &>> $logfile || { echo -n "Could not install web wallet node modules. Exiting." && exit 1; }

    bower --allow-root install &>> $logfile || { echo -e "\n\nCould not install bower components for the web wallet. Exiting." && exit 1; }
    grunt release &>> $logfile || { echo -e "\n\nCould not build web wallet release. Exiting." && exit 1; }
    echo "done."

    cd ..
    
    return 0;

}


update_manager() {

    echo -n "Updating Shift Manager ... "
    wget -q -O shift_manager.bash https://raw.githubusercontent.com/shiftnrg/shift-lisk/$GIT_BRANCH/shift_manager.bash
    echo "done."

    return 0;
}


update_client() {

    if [[ -f config.json ]]; then
        cp config.json config.json.bak
    fi

    echo -n "Updating Shift client ... "

    git checkout . &>> $logfile || { echo "Failed to checkout last status of git repository. Run it manually with: 'git checkout .'. Exiting." && exit 1; }
    git pull &>> $logfile || { echo "Failed to fetch updates from git repository. Run it manually with: git pull. Exiting." && exit 1; }
    npm install --production &>> $logfile || { echo -e "\n\nCould not install node modules. Exiting." && exit 1; }
    echo "done."

    if [[ -f $root_path/config.json.bak ]]; then
      echo -n "Take over config.json entries from previous installation ... "
      node $root_path/updateConfig.js -o $root_path/config.json.bak -n $root_path/config.json
      echo "done."
    fi

    return 0;
}

update_wallet() {

    if [[ ! -d "public" ]]; then
      install_webui
      return 0;
    fi

    echo -n "Updating Shift wallet ... "

    cd public
    git checkout . &>> $logfile || { echo "Failed to checkout last status of git repository. Exiting." && exit 1; }
    git pull &>> $logfile || { echo "Failed to fetch updates from git repository. Exiting." && exit 1; }
    npm install &>> $logfile || { echo -n "Could not install web wallet node modules. Exiting." && exit 1; }

    # Bower config seems to have the wrong permissions. Make sure we change these before trying to use bower.
    if [[ -d /home/$USER/.config ]]; then
        sudo chown -R $USER:$USER /home/$USER/.config &> /dev/null
    fi

    bower --allow-root install &>> $logfile || { echo -e "\n\nCould not install bower components for the web wallet. Exiting." && exit 1; }
    grunt release &>> $logfile || { echo -e "\n\nCould not build web wallet release. Exiting." && exit 1; }

    echo "done."
    cd ..
    return 0;
}

stop_shift() {
    echo -n "Stopping Shift... "
    forever_exists=$(whereis forever | awk {'print $2'})
    if [[ ! -z $forever_exists ]]; then
        $forever_exists stop $root_path/app.js &>> $logfile
    fi

    sleep 2

    if ! running; then
        echo "OK"
        return 0
    fi
    echo
    return 1
}

start_shift() {
    echo -n "Starting Shift... "
    forever_exists=$(whereis forever | awk {'print $2'})
    if [[ ! -z $forever_exists ]]; then
        $forever_exists start -o $root_path/logs/shift_console.log -e $root_path/logs/shift_err.log app.js -c "$SHIFT_CONFIG" &>> $logfile || \
        { echo -e "\nCould not start Shift." && exit 1; }
    fi

    sleep 2

    if running; then
        echo "OK"
        return 0
    fi
    echo
    return 1
}

  start_snapshot() {
    echo -n "Starting Shift (snapshot mode) ... "
    forever_exists=$(whereis forever | awk {'print $2'})
    if [[ ! -z $forever_exists ]]; then
        $forever_exists start -o $root_path/logs/snapshot_console.log -e $root_path/logs/snapshot_err.log app.js -c "$SHIFT_CONFIG" -s highest &>> $logfile || \
        { echo -e "\nCould not start Shift." && exit 1; }
    fi

    sleep 2

    if running; then
        echo "OK"
        return 0
    fi
    echo
    return 1
}

running() {
    process=$(forever list |grep app.js |awk {'print $9'})
    if [[ -z $process ]] || [[ "$process" == "STOPPED" ]]; then
        return 1
    fi
    return 0
}

show_networkBlockHeight(){
  if [ "$NETWORK" == "mainnet" ] ; then
    networkBlockHeight=`curl -s https://wallet.shiftnrg.org/api/blocks/getStatus | jq -r '.height'` 2>/dev/null
  else
    networkBlockHeight=`curl -s https://wallet.testnet.shiftnrg.org/api/blocks/getStatus | jq -r '.height'` 2>/dev/null
  fi

  if [[ ! "$networkBlockHeight" =~ ^[0-9]+$ ]] ; then
    echo "Problem fetching network height check your internet connection or there is issue with $NETWORK api"
  fi
  echo "Network height = $networkBlockHeight"
  return 0
}

show_blockHeight(){
  export PGPASSWORD=$DB_PASSWD
  blockHeight=$(psql -d $DB_NAME -U $DB_UNAME -h localhost -p 5432 -t -c "select height from blocks order by height desc limit 1")
  echo "Block height = $blockHeight"
}

parse_option() {
  OPTIND=2
  while getopts c:x opt; do
    case "$opt" in
      c)
        if [ -f "$OPTARG" ]; then
          SHIFT_CONFIG="$OPTARG"
        fi ;;
    esac
  done
}

rebuild_shift() {
  create_database
  download_blockchain
  restore_blockchain
}

start_log() {
  echo "Starting $0... " > $logfile
  echo -n "Date: " >> $logfile
  date >> $logfile
  echo "" >> $logfile
}

case $1 in
    "install")
      start_log
      install_prereq
      ntp_checks
      add_pg_user_database
      install_node_npm
      install_shift
      install_webui
      echo ""
      echo ""
      echo "SHIFT successfully installed"

    ;;
    "update_manager")
      update_manager
    ;;
    "update_client")
      start_log
      stop_shift
      sleep 2
      update_client
      sleep 2
      start_shift
      show_blockHeight
      show_networkBlockHeight
    ;;
    "update_wallet")
      start_log
      stop_shift
      sleep 2
      update_wallet
      sleep 2
      start_shift
      show_blockHeight
      show_networkBlockHeight
    ;;
    "reload")
      stop_shift
      sleep 2
      start_shift
      show_blockHeight
      show_networkBlockHeight
      ;;
    "rebuild")
      stop_shift
      sleep 2
      start_postgres
      sleep 2
      rebuild_shift
      start_shift
      show_blockHeight
      show_networkBlockHeight
      ;;
    "status")
      if running; then
        echo "√ SHIFT is running."
        show_blockHeight
        show_networkBlockHeight
      else
        echo "X SHIFT is NOT running."
      fi
    ;;
    "start")
      parse_option $@
      start_shift
      show_blockHeight
      show_networkBlockHeight
    ;;
    "createsnapshot")
      stop_shift
      backup_blockchain
      parse_option $@
      start_shift
    ;;
    "snapshot")
      parse_option $@
      start_snapshot
    ;;
    "stop")
      stop_shift
    ;;

*)
    echo 'Available options: install, reload (stop/start), rebuild (official snapshot), createsnapshot, start, stop, update_manager, update_client, update_wallet'
    echo 'Usage: ./shift_installer.bash install'
    exit 1
;;
esac
exit 0;
