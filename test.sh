#!/usr/bin/env bash

! type multipass > /dev/null 2>&1 && \
    echo "Multipass is not installed" >&2 && exit 1

if ! wget -q --spider https://google.com; then
    ! wget -q --spider 1.1.1.1 && \
        echo "Network is not connected" >&2 || \
        echo "Unable to resolve DNS" >&2
    exit 1
fi

MULTIPASS=$(which multipass)
SERVER="${MULTIPASS} exec website --"
CLIENT="${MULTIPASS} exec home --"
cat <<EOF

  ┌─────────────────────────┐
  │  ┌───────────────────┐  │
  │  │                   │  │
  │  │   STEP CA TEST    │  │
  │  │                   │  │
  │  └───────────────────┘  │
  └─────────────────────────┘

EOF
echo "====> RESET ALL INSTANCES"
echo
./vm.sh reset
echo
echo "====> STARTING STEP CA INSTANCE"
echo
./vm.sh ca &
echo "====> STARTING SERVER INSTANCE"
echo
./vm.sh server &
echo "====> STARTING CLIENT INSTANCE"
echo
./vm.sh client &
echo "====> >> WAITING FOR ALL INSTANCES"
echo
wait
echo "====> ALL INSTANCES ARE STARTED AND CONFIGURED"
echo
echo "====> LOADING FINGERPRINT"
FINGERPRINT=$($MULTIPASS exec stepca -- sudo step certificate fingerprint /etc/step-ca/certs/root_ca.crt)
echo
echo "====> BOOTSTRAPPING SERVER"
echo
echo "====> >> RUNNING CERTBOT & HTTPS WEBSERVER IN SERVER"
echo
$SERVER runstep bootstrap $FINGERPRINT && $SERVER sudo runstep certbot &
echo "====> BOOTSTRAPPING CLIENT"
echo
$CLIENT runstep bootstrap $FINGERPRINT &
echo "====> >> WAITING FOR SERVER AND CLIENT TO BOOTSTRAP"
echo
wait
echo
echo "====> SERVER AND CLIENT ARE BOOTSTRAPPED"
echo
sleep 1
echo "====> TEST #1: ACCESSING HTTPS WEBSITE FROM CLIENT"
echo
echo "====> >> SENDING HTTPS REQUEST WITHOUT MTLS"
echo
$CLIENT curl https://website.local || exit 1
echo
echo "====> TEST #1 IS COMPLETE"
echo
echo "====> TEST #2: ACCESSING HTTPS WEBSITE WITH MTLS FROM CLIENT"
echo
echo "====> >> GENERATING ONT TIME TOKEN FROM CA"
echo
TOKEN=$($MULTIPASS exec stepca -- sudo STEPPATH=/etc/step-ca step ca token home.local --provisioner token-admin --provisioner-password-file=/etc/step-ca/secrets/password.txt)
echo
echo "====> >> CLIENT REQUESTING NEW CERTIFICATE FROM CA USING THE TOKEN"
echo
$CLIENT runstep certificate "$TOKEN"
echo
echo "====> >> CLIENT CERTIFICATE RECEIVED FROM CA"
echo
echo "====> >> SENDING HTTPS REQUEST WITH MTLS"
echo
$CLIENT curl https://website.local:8443 --cert /home/ubuntu/.step/certs/home.local.crt --key /home/ubuntu/.step/secrets/home.local.key || exit 1
echo
echo "====> TEST #2 IS COMPLETE"
echo
