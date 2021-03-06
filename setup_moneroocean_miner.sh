#!/bin/bash

VERSION=2.11

# printing greetings

echo "MoneroOcean mining setup script v$VERSION."
echo "(please report issues to support@moneroocean.stream email with full output of this script with extra \"-x\" \"bash\" option)"
echo

if [ "$(id -u)" == "0" ]; then
  echo "WARNING: Generally it is not adviced to run this script under root"
fi

# command line arguments
WALLET=$1
EMAIL=$2 # this one is optional

# checking prerequisites

if [ -z $WALLET ]; then
  echo "Script usage:"
  echo "> setup_moneroocean_miner.sh <wallet address> [<your email address>]"
  echo "ERROR: Please specify your wallet address"
  exit 1
fi

WALLET_BASE=`echo $WALLET | cut -f1 -d"."`
if [ ${#WALLET_BASE} != 106 -a ${#WALLET_BASE} != 95 ]; then
  echo "ERROR: Wrong wallet base address length (should be 106 or 95): ${#WALLET_BASE}"
  exit 1
fi

if [ -z $HOME ]; then
  echo "ERROR: Please define HOME environment variable to your home directory"
  exit 1
fi

if [ ! -d $HOME ]; then
  echo "ERROR: Please make sure HOME directory $HOME exists or set it yourself using this command:"
  echo '  export HOME=<dir>'
  exit 1
fi

if ! type curl >/dev/null; then
  echo "ERROR: This script requires \"curl\" utility to work correctly"
  exit 1
fi

if ! type lscpu >/dev/null; then
  echo "WARNING: This script requires \"lscpu\" utility to work correctly"
fi

#if ! sudo -n true 2>/dev/null; then
#  if ! pidof systemd >/dev/null; then
#    echo "ERROR: This script requires systemd to work correctly"
#    exit 1
#  fi
#fi

# calculating port

CPU_THREADS=$(nproc)
EXP_MONERO_HASHRATE=$(( CPU_THREADS * 700 / 1000))
if [ -z $EXP_MONERO_HASHRATE ]; then
  echo "ERROR: Can't compute projected Monero CN hashrate"
  exit 1
fi

power2() {
  if ! type bc >/dev/null; then
    if   [ "$1" -gt "8192" ]; then
      echo "8192"
    elif [ "$1" -gt "4096" ]; then
      echo "4096"
    elif [ "$1" -gt "2048" ]; then
      echo "2048"
    elif [ "$1" -gt "1024" ]; then
      echo "1024"
    elif [ "$1" -gt "512" ]; then
      echo "512"
    elif [ "$1" -gt "256" ]; then
      echo "256"
    elif [ "$1" -gt "128" ]; then
      echo "128"
    elif [ "$1" -gt "64" ]; then
      echo "64"
    elif [ "$1" -gt "32" ]; then
      echo "32"
    elif [ "$1" -gt "16" ]; then
      echo "16"
    elif [ "$1" -gt "8" ]; then
      echo "8"
    elif [ "$1" -gt "4" ]; then
      echo "4"
    elif [ "$1" -gt "2" ]; then
      echo "2"
    else
      echo "1"
    fi
  else 
    echo "x=l($1)/l(2); scale=0; 2^((x+0.5)/1)" | bc -l;
  fi
}

PORT=$(( $EXP_MONERO_HASHRATE * 30 ))
PORT=$(( $PORT == 0 ? 1 : $PORT ))
PORT=`power2 $PORT`
PORT=$(( 10000 + $PORT ))
if [ -z $PORT ]; then
  echo "ERROR: Can't compute port"
  exit 1
fi

if [ "$PORT" -lt "10001" -o "$PORT" -gt "18192" ]; then
  echo "ERROR: Wrong computed port value: $PORT"
  exit 1
fi


# printing intentions

echo "I will download, setup and run in background Monero CPU miner."
echo "If needed, miner in foreground can be started by $HOME/moneroocean/miner.sh script."
echo "Mining will happen to $WALLET wallet."
if [ ! -z $EMAIL ]; then
  echo "(and $EMAIL email as password to modify wallet options later at https://moneroocean.stream site)"
fi
echo

if ! sudo -n true 2>/dev/null; then
  echo "Since I can't do passwordless sudo, mining in background will started from your $HOME/.profile file first time you login this host after reboot."
else
  echo "Mining in background will be performed using moneroocean_miner systemd service."
fi

echo
echo "JFYI: This host has $CPU_THREADS CPU threads, so projected Monero hashrate is around $EXP_MONERO_HASHRATE KH/s."
echo

echo "Sleeping for 15 seconds before continuing (press Ctrl+C to cancel)"
sleep 15
echo
echo

# start doing stuff: preparing miner

echo "[*] Removing previous moneroocean miner (if any)"
if sudo -n true 2>/dev/null; then
  sudo systemctl stop moneroocean_miner.service
fi
killall -9 xmrig

echo "[*] Removing $HOME/moneroocean directory"
rm -rf $HOME/moneroocean

echo "[*] Downloading MoneroOcean advanced version of xmrig to /tmp/xmrig.tar.gz"
if ! curl -L --progress-bar "https://raw.githubusercontent.com/MoneroOcean/xmrig_setup/master/xmrig.tar.gz" -o /tmp/xmrig.tar.gz; then
  echo "ERROR: Can't download https://raw.githubusercontent.com/MoneroOcean/xmrig_setup/master/xmrig.tar.gz file to /tmp/xmrig.tar.gz"
  exit 1
fi

echo "[*] Unpacking /tmp/xmrig.tar.gz to $HOME/moneroocean"
[ -d $HOME/moneroocean ] || mkdir $HOME/moneroocean
if ! tar xf /tmp/xmrig.tar.gz -C $HOME/moneroocean; then
  echo "ERROR: Can't unpack /tmp/xmrig.tar.gz to $HOME/moneroocean directory"
  exit 1
fi
rm /tmp/xmrig.tar.gz

echo "[*] Checking if advanced version of $HOME/moneroocean/xmrig works fine (and not removed by antivirus software)"
sed -i 's/"donate-level": *[^,]*,/"donate-level": 1,/' $HOME/moneroocean/config.json
$HOME/moneroocean/xmrig --help >/dev/null
if (test $? -ne 0); then
  if [ -f $HOME/moneroocean/xmrig ]; then
    echo "WARNING: Advanced version of $HOME/moneroocean/xmrig is not functional"
  else 
    echo "WARNING: Advanced version of $HOME/moneroocean/xmrig was removed by antivirus (or some other problem)"
  fi

  echo "[*] Looking for the latest version of Monero miner"
  LATEST_XMRIG_RELEASE=`curl -s https://github.com/xmrig/xmrig/releases/latest  | grep -o '".*"' | sed 's/"//g'`
  LATEST_XMRIG_LINUX_RELEASE="https://github.com"`curl -s $LATEST_XMRIG_RELEASE | grep xenial-x64.tar.gz\" |  cut -d \" -f2`

  echo "[*] Downloading $LATEST_XMRIG_LINUX_RELEASE to /tmp/xmrig.tar.gz"
  if ! curl -L --progress-bar $LATEST_XMRIG_LINUX_RELEASE -o /tmp/xmrig.tar.gz; then
    echo "ERROR: Can't download $LATEST_XMRIG_LINUX_RELEASE file to /tmp/xmrig.tar.gz"
    exit 1
  fi

  echo "[*] Unpacking /tmp/xmrig.tar.gz to $HOME/moneroocean"
  if ! tar xf /tmp/xmrig.tar.gz -C $HOME/moneroocean --strip=1; then
    echo "WARNING: Can't unpack /tmp/xmrig.tar.gz to $HOME/moneroocean directory"
  fi
  rm /tmp/xmrig.tar.gz

  echo "[*] Checking if stock version of $HOME/moneroocean/xmrig works fine (and not removed by antivirus software)"
  sed -i 's/"donate-level": *[^,]*,/"donate-level": 0,/' $HOME/moneroocean/config.json
  $HOME/moneroocean/xmrig --help >/dev/null
  if (test $? -ne 0); then 
    if [ -f $HOME/moneroocean/xmrig ]; then
      echo "ERROR: Stock version of $HOME/moneroocean/xmrig is not functional too"
    else 
      echo "ERROR: Stock version of $HOME/moneroocean/xmrig was removed by antivirus too"
    fi
    exit 1
  fi
fi

echo "[*] Miner $HOME/moneroocean/xmrig is OK"

PASS=`hostname | cut -f1 -d"." | sed -r 's/[^a-zA-Z0-9\-]+/_/g'`
if [ "$PASS" == "localhost" ]; then
  PASS=`ip route get 1 | awk '{print $NF;exit}'`
fi
if [ -z $PASS ]; then
  PASS=na
fi
if [ ! -z $EMAIL ]; then
  PASS="$PASS:$EMAIL"
fi

sed -i 's/"url": *"[^"]*",/"url": "gulf.moneroocean.stream:'$PORT'",/' $HOME/moneroocean/config.json
sed -i 's/"user": *"[^"]*",/"user": "'$WALLET'",/' $HOME/moneroocean/config.json
sed -i 's/"pass": *"[^"]*",/"pass": "'$PASS'",/' $HOME/moneroocean/config.json
sed -i 's/"max-cpu-usage": *[^,]*,/"max-cpu-usage": 100,/' $HOME/moneroocean/config.json
sed -i 's#"log-file": *null,#"log-file": "'$HOME/moneroocean/xmrig.log'",#' $HOME/moneroocean/config.json
sed -i 's/"syslog": *[^,]*,/"syslog": true,/' $HOME/moneroocean/config.json

cp $HOME/moneroocean/config.json $HOME/moneroocean/config_background.json
sed -i 's/"background": *false,/"background": true,/' $HOME/moneroocean/config_background.json

# preparing script

echo "[*] Creating $HOME/moneroocean/miner.sh script"
cat >$HOME/moneroocean/miner.sh <<EOL
#!/bin/bash
if ! pidof xmrig >/dev/null; then
  nice $HOME/moneroocean/xmrig \$*
else
  echo "Monero miner is already running in the background. Refusing to run another one."
  echo "Run \"killall xmrig\" or \"sudo killall xmrig\" if you want to remove background miner first."
fi
EOL

chmod +x $HOME/moneroocean/miner.sh

# preparing script background work and work under reboot

if ! sudo -n true 2>/dev/null; then
  if ! grep moneroocean/miner.sh $HOME/.profile >/dev/null; then
    echo "[*] Adding $HOME/moneroocean/miner.sh script to $HOME/.profile"
    echo "$HOME/moneroocean/miner.sh --config=$HOME/moneroocean/config_background.json >/dev/null 2>&1" >>$HOME/.profile
  else 
    echo "Looks like $HOME/moneroocean/miner.sh script is already in the $HOME/.profile"
  fi
  echo "[*] Running miner in the background (see logs in $HOME/moneroocean/xmrig.log file)"
  /bin/bash $HOME/moneroocean/miner.sh --config=$HOME/moneroocean/config_background.json >/dev/null 2>&1
else

  if [[ $(grep MemTotal /proc/meminfo | awk '{print $2}') > 3500000 ]]; then
    echo "[*] Enabling huge pages"
    echo "vm.nr_hugepages=$((1168+$(nproc)))" | sudo tee -a /etc/sysctl.conf
    sudo sysctl -w vm.nr_hugepages=$((1168+$(nproc)))
  fi

  if ! type systemctl >/dev/null; then

    echo "[*] Running miner in the background (see logs in $HOME/moneroocean/xmrig.log file)"
    /bin/bash $HOME/moneroocean/miner.sh --config=$HOME/moneroocean/config_background.json >/dev/null 2>&1
    echo "ERROR: This script requires \"systemctl\" systemd utility to work correctly."
    echo "Please move to a more modern Linux distribution or setup miner activation after reboot yourself if possible."

  else

    echo "[*] Creating moneroocean_miner systemd service"
    cat >/tmp/moneroocean_miner.service <<EOL
[Unit]
Description=Monero miner service

[Service]
ExecStart=$HOME/moneroocean/xmrig --config=$HOME/moneroocean/config.json
Restart=always
Nice=10
CPUWeight=1

[Install]
WantedBy=multi-user.target
EOL
    sudo mv /tmp/moneroocean_miner.service /etc/systemd/system/moneroocean_miner.service
    echo "[*] Starting moneroocean_miner systemd service"
    sudo killall xmrig 2>/dev/null
    sudo systemctl daemon-reload
    sudo systemctl enable moneroocean_miner.service
    sudo systemctl start moneroocean_miner.service
    echo "To see miner service logs run \"sudo journalctl -u moneroocean_miner -f\" command"
  fi
fi

echo ""
echo "NOTE: If you are using shared VPS it is recommended to avoid 100% CPU usage produced by the miner or you will be banned"
if [ "$CPU_THREADS" -lt "4" ]; then
  echo "HINT: Please execute these or similair commands under root to limit miner to 75% percent CPU usage:"
  echo "sudo apt-get update; sudo apt-get install -y cpulimit"
  echo "sudo cpulimit -e xmrig -l $((75*$CPU_THREADS)) -b"
  if [ "`tail -n1 /etc/rc.local`" != "exit 0" ]; then
    echo "sudo sed -i -e '\$acpulimit -e xmrig -l $((75*$CPU_THREADS)) -b\\n' /etc/rc.local"
  else
    echo "sudo sed -i -e '\$i \\cpulimit -e xmrig -l $((75*$CPU_THREADS)) -b\\n' /etc/rc.local"
  fi
else
  echo "HINT: Please execute these commands and reboot your VPS after that to limit miner to 75% percent CPU usage:"
  echo "sed -i 's/\"max-threads-hint\": *[^,]*,/\"max-threads-hint\": 75,/' \$HOME/moneroocean/config.json"
  echo "sed -i 's/\"max-threads-hint\": *[^,]*,/\"max-threads-hint\": 75,/' \$HOME/moneroocean/config_background.json"
fi
echo ""

echo "[*] Setup complete"





