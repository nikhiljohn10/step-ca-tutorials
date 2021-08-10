#!/usr/bin/env bash

if ! type multipass > /dev/null 2>&1; then
    echo "Multipass is not installed"
    exit 1
fi

if ! wget -q --spider https://google.com; then
    if ! wget -q --spider 1.1.1.1; then
        echo "Network is not connected"
    else
        echo "Unable to resolve DNS"
    fi
    exit 1
fi

MULTIPASS=$(which multipass)
NET_FILE="/etc/netplan/50-cloud-init.yaml"
PARAMS=""
VM_NAME="stepdns"

while (( "$#" )); do
    case "$1" in
        -d|--delete)
            ($MULTIPASS delete $VM_NAME && $MULTIPASS purge) && \
            echo "Successfully removed $VM_NAME" || exit 1
            exit 0
            ;;
        -*|--*=)
            echo "Error: Unsupported flag $1" >&2
            exit 1
            ;;
        *)
            PARAMS="$PARAMS $1"
            shift
            ;;
    esac
done
eval set -- "$PARAMS"

if ! $MULTIPASS ls | grep $VM_NAME > /dev/null 2>&1; then

    echo "Starting a new virtual instance of Ubuntu"
    $MULTIPASS launch -n $VM_NAME && \
    echo "A new virtual machine called $VM_NAME is created"

    $MULTIPASS exec $VM_NAME -- sudo sed -i '$ a deb http://download.webmin.com/download/repository sarge contrib' /etc/apt/sources.list
    $MULTIPASS exec $VM_NAME -- eval 'wget -q -O- http://www.webmin.com/jcameron-key.asc | sudo apt-key add' > /dev/null 2>&1

    echo "Updating ubuntu"
    $MULTIPASS exec $VM_NAME -- sudo apt update && \
    echo "Ubuntu is updated"
    echo "Upgrading ubuntu"
    $MULTIPASS exec $VM_NAME -- sudo apt upgrade -y && \
    echo "Ubuntu is upgraded"

    echo "Installing webmin"
    $MULTIPASS exec $VM_NAME -- sudo apt install -y webmin python3-ply bind9-utils dns-root-data bind9 && echo "Webmin installed"
    $MULTIPASS exec $VM_NAME -- sudo ufw allow Bind9 && \
    $MULTIPASS exec $VM_NAME -- sudo ufw allow 10000 && echo "Updated firewall"
    IP_ADDR=$($MULTIPASS exec $VM_NAME -- eval 'hostname -I | xargs')

    echo "Webmin can be accessed at https://${IP_ADDR}:10000"
    echo "Webmin user: root"
    $MULTIPASS exec $VM_NAME -- sudo passwd

fi

$MULTIPASS shell $VM_NAME
