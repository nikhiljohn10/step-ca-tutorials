#!/usr/bin/env bash

if [[ "$EUID" -ne 0 ]]; then
  echo "The script need to be run as root..."
  exit 1
fi

if ! type "step" > /dev/null 2>&1; then
  echo "Step CLI is not installed."
  exit 1
fi

if ! type "step-ca" > /dev/null 2>&1; then
  echo "Step CA is not installed."
  exit 1
fi

STEP_CA=$(which step-ca)
STEP_CA_LOG="/var/log/step-ca"

useradd -m -U step -s /bin/bash
usermod -aG sudo step
passwd -l step

setcap CAP_NET_BIND_SERVICE=+eip $STEP_CA

mkdir -p $STEP_CA_LOG
chown -R step:step $STEP_CA_LOG

cp service/step-ca.service /etc/systemd/system/step-ca.service
