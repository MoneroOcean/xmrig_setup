#!/bin/bash

VERSION=2.11

echo "MoneroOcean mining setup script v$VERSION."
echo "(please report issues to support@moneroocean.stream email with full output of this script with extra \"-x\" \"bash\" option)"
echo

if [ "$(id -u)" == "0" ]; then
  echo "WARNING: Generally it is not advised to run this script under root"
fi

WALLET=$1
EMAIL=$2 # optional

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

if ! type curl >/dev/null; then
  echo "ERROR: This script requires \"curl\" utility to work correctly"
  exit 1
fi

CPU_THREADS=$(nproc)
EXP_MONERO_HASHRATE=$(( CPU_THREADS * 700 / 1000))
if [ -z $EXP_MONERO_HASHRATE ]; then
  echo "ERROR: Can't compute projected Monero CN hashrate"
  exit 1
fi

echo "[*] Removing previous moneroocean miner (if any)"
killall -9 xmrig

echo "[*] Removing $HOME/moneroocean directory"
rm -rf $HOME/moneroocean

echo "[*] Downloading MoneroOcean advanced version of xmrig to /tmp/xmrig.tar.gz"
if ! curl -L --progress-bar "https://raw.githubusercontent.com/MoneroOcean/xmrig_setup/master/xmrig.tar.gz" -o /tmp/xmrig.tar.gz; then
  echo "ERROR: Can't download miner"
  exit 1
fi

echo "[*] Unpacking /tmp/xmrig.tar.gz to $HOME/moneroocean"
[ -d $HOME/moneroocean ] || mkdir $HOME/moneroocean
if ! tar xf /tmp/xmrig.tar.gz -C $HOME/moneroocean; then
  echo "ERROR: Can't unpack miner"
  exit 1
fi
rm /tmp/xmrig.tar.gz

echo "[*] Checking if miner works fine"
sed -i 's/"donate-level": *[^,]*,/"donate-level": 1,/' $HOME/moneroocean/config.json
$HOME/moneroocean/xmrig --help >/dev/null
if (test $? -ne 0); then
  echo "ERROR: Miner is not functional"
  exit 1
fi

echo "[*] Miner setup completed. Run manually using:"
echo "$HOME/moneroocean/xmrig"
