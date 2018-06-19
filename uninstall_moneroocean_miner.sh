#!/bin/bash

VERSION=1.0

# printing greetings

echo "MoneroOcean mining uninstall script v$VERSION."
echo "(please report issues to support@moneroocean.stream email with full output of this script with extra \"-x\" \"bash\" option)"
echo

if [ -z $HOME ]; then
  echo "ERROR: Please define HOME environment variable to your home directory"
  exit 1
fi

if [ ! -d $HOME ]; then
  echo "ERROR: Please make sure HOME directory $HOME exists"
  exit 1
fi

echo "[*] Removing moneroocean miner"
if sudo -n true 2>/dev/null; then
  sudo systemctl stop moneroocean_miner.service
  sudo systemctl disable moneroocean_miner.service
  rm -f /etc/systemd/system/moneroocean_miner.service
  sudo systemctl daemon-reload
  sudo systemctl reset-failed
fi

sed -i '/moneroocean/d' $HOME/.profile
killall -9 xmrig

echo "[*] Removing $HOME/moneroocean directory"
rm -rf $HOME/moneroocean

echo "[*] Uninstall complete"

