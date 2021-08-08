#!/usr/bin/env bash

if [[ "$EUID" -ne 0 ]]; then
  echo "The script need to be run as root..."
  exit 1
fi

CLI_URL="https://api.github.com/repos/smallstep/cli"
CA_URL="https://api.github.com/repos/smallstep/certificates"
CLI_VER=$(curl -s ${CLI_URL}/releases/latest | grep tag_name | sed 's/[(tag_name)"v:,[:space:]]//g')
CA_VER=$(curl -s ${CA_URL}/releases/latest | grep tag_name | sed 's/[(tag_name)"v:,[:space:]]//g')
CLI_TAG="v${CLI_VER}"
CA_TAG="v${CA_VER}"
TEMP_PATH="/tmp/step"
mkdir -p ${TEMP_PATH}

# Download step-cli if not downloaded
if ! [ -f "${TEMP_PATH}/step-cli_${CLI_VER}_amd64.deb" ]; then
  wget -O ${TEMP_PATH}/step-cli_${CLI_VER}_amd64.deb https://github.com/smallstep/cli/releases/download/${CLI_TAG}/step-cli_${CLI_VER}_amd64.deb
fi

# Download step-ca if not downloaded
if ! [ -f "${TEMP_PATH}/step-ca_${CA_VER}_amd64.deb" ]; then
  wget -O ${TEMP_PATH}/step-ca_${CA_VER}_amd64.deb https://github.com/smallstep/certificates/releases/download/${CA_TAG}/step-ca_${CA_VER}_amd64.deb
fi

# Install deb packages
dpkg -i ${TEMP_PATH}/step-cli_${CLI_VER}_amd64.deb
dpkg -i ${TEMP_PATH}/step-ca_${CA_VER}_amd64.deb

# STEP CA Preparation
STEP_CA=$(which step-ca)
STEP_PATH=$(step path)
STEP_CA_LOG="/var/log/step-ca"
PASSWORD_FILE="${STEP_PATH}/secrets/password.txt"

# Create new step user
# useradd --system --home $STEP_PATH --shell /bin/false step
# usermod -aG sudo step
# passwd -l step


# Service installation
# cp service/step-ca.service /etc/systemd/system/step-ca.service
# systemctl daemon-reload
# systemctl status step-ca

# Use following commands to activate service after pki is created
# systemctl enable step-ca
# systemctl start step-ca

# Preparing logging location
# mkdir -p ${STEP_CA_LOG}
# chown -R step:step ${STEP_CA_LOG}

# Enable step-ca to bind ports lower than 1024
setcap CAP_NET_BIND_SERVICE=+eip ${STEP_CA}
