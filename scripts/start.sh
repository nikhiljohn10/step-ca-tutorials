#!/usr/bin/env bash

STEP_PATH=$(step path)
PASSWORD_FILE="${STEP_PATH}/secrets/password.txt"
IP_ADDR=$(hostname -I | xargs)

ORG_NAME="Step CA Tutorial"
DNS_ADDR="stepca.multipass"
PROVISIONER="tokenizer"
LISTEN=":443"

if [ ! -f "${PASSWORD_FILE}" ]; then

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

  step ca provisioner add acme --type ACME

fi

PASSWORD=$(cat ${PASSWORD_FILE})
FINGERPRINT=$(step certificate fingerprint "${STEP_PATH}/certs/root_ca.crt")
echo "Password is ${PASSWORD}"
echo "Fingerprint is ${FINGERPRINT}"
echo "You CA link is https://${DNS_ADDR} or https://${IP_ADDR}"
step-ca "${STEP_PATH}/config/ca.json" --password-file $PASSWORD_FILE
