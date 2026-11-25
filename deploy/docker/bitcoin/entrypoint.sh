#!/bin/sh
set -eu
: "${BITCOIN_RPC_USER:?}"
: "${BITCOIN_RPC_PASSWORD:?}"
: "${BITCOIN_PEERS:=}"
CONF=/home/bitcoin/.bitcoin/bitcoin.conf
mkdir -p /home/bitcoin/.bitcoin
{
  echo "regtest=1"
  echo "server=1"
  echo "txindex=1"
  echo "fallbackfee=0.0002"
  echo "dnsseed=0"
  echo "discover=0"
  echo "listenonion=0"
  echo "upnp=0"
  echo "natpmp=0"
  echo "printtoconsole=1"
  echo "[regtest]"
  echo "rpcuser=${BITCOIN_RPC_USER}"
  echo "rpcpassword=${BITCOIN_RPC_PASSWORD}"
  echo "rpcbind=0.0.0.0"
  echo "rpcport=18443"
  echo "rpcallowip=10.0.0.0/8"
  echo "rpcallowip=172.16.0.0/12"
  echo "rpcallowip=192.168.0.0/16"
  echo "bind=0.0.0.0:18444"
  echo "zmqpubrawblock=tcp://0.0.0.0:28332"
  echo "zmqpubrawtx=tcp://0.0.0.0:28332"
  echo "zmqpubhashblock=tcp://0.0.0.0:28332"
  echo "zmqpubsequence=tcp://0.0.0.0:28332"
  for peer in $(echo "$BITCOIN_PEERS" | tr ',' ' '); do
    echo "connect=${peer}"
  done
  if [ -z "$BITCOIN_PEERS" ]; then
    echo "connect=0"
  fi
} > "$CONF"
chown -R bitcoin:bitcoin /home/bitcoin/.bitcoin
exec /entrypoint.sh bitcoind
