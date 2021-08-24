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
echo "====>> RESET ALL INSTANCES <<===="
echo
./vm.sh reset
echo
echo "====>> STARTING STEP CA INSTANCE <<===="
echo
./vm.sh ca &
echo "====>> STARTING SERVER INSTANCE <<===="
echo
./vm.sh server &
echo "====>> STARTING CLIENT INSTANCE <<===="
echo
./vm.sh client &
echo "====>> WAITING FOR ALL INSTANCES <<===="
echo
wait
echo "====>> LOADING FINGERPRINT <<===="
FINGERPRINT=$($MULTIPASS exec stepca -- sudo step certificate fingerprint /etc/step-ca/certs/root_ca.crt)
echo
echo "====>> BOOTSTRAPPING SERVER <<===="
echo
echo "====>> RUNNING CERTBOT & HTTPS WEBSERVER IN SERVER <<===="
echo
$SERVER runstep bootstrap $FINGERPRINT && $SERVER sudo runstep certbot &
echo "====>> BOOTSTRAPPING CLIENT <<===="
echo
$CLIENT runstep bootstrap $FINGERPRINT &
echo "====>> WAITING FOR SERVER AND CLIENT TO BOOTSTRAP <<===="
echo
wait
sleep 1
echo "====>> TESTING HTTPS WEBSITE FROM CLIENT <<===="
echo
$CLIENT curl https://website.local
echo
echo "====>> TEST IS COMPLETE <<===="
echo
