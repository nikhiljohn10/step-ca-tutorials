#!/usr/bin/env bash

STEP_PATH=$(step path)
PASSWORD_FILE="${STEP_PATH}/secrets/password.txt"
IP_ADDR=$(hostname -I)

if [ "$1" == "-t" ]; then
  $(step ca token --password-file ${PASSWORD_FILE} ${2})
  exit 0
fi


if [ ! -f "${PASSWORD_FILE}" ]; then

  ORG_NAME="Step Tutorial"
  DNS_ADDR="localhost,${IP_ADDR}"
  PROVISIONER="admin@${DNS_ADDR}"
  LISTEN=":443"

  # Password generation
  mkdir -p "${STEP_PATH}/secrets"
  if type "openssl" > /dev/null 2>&1; then
    openssl rand -base64 24 > $PASSWORD_FILE
  elif type "gpg" > /dev/null 2>&1; then
    gpg --gen-random --armor 1 24 > $PASSWORD_FILE
  else
    echo "Need OpenSSL or GPG to genereate password"
  fi

  step ca init --ssh \
    --name $ORG_NAME \
    --provisioner $PROVISIONER \
    --dns $DNS_ADDR \
    --address $LISTEN \
    --password-file $PASSWORD_FILE \
    --provisioner-password-file $PASSWORD_FILE

  echo "Password is in ${PASSWORD_FILE}"

fi

echo "You CA link is https://${IP_ADDR}"
step-ca "${STEP_PATH}/config/ca.json" --password-file $PASSWORD_FILE
