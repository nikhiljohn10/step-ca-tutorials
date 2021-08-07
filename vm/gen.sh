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
SERVE_CA=1
UPGRADE_VM=1
RUN_STEP_CA=1
VM_NAME=$1

if [[ "${VM_NAME}" =~ [^a-zA-Z] ]]; then
   echo "Invalid VM name. It should only contain alphabets."
   exit 1
else
    shift
fi

while (( "$#" )); do
    case "$1" in
        -c|--step-ca)
            RUN_STEP_CA=0
            shift
            ;;
        -s|--serve)
            SERVE_CA=0
            shift
            ;;
        -u|--upgrade)
            UPGRADE_VM=0
            shift
            ;;
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
    $MULTIPASS launch -v -n $VM_NAME && \
    echo "A new virtual machine called $VM_NAME is created"

    if [ "$UPGRADE_VM" == "0" ]; then
        echo "Updating ubuntu"
        $MULTIPASS exec $VM_NAME -- sudo apt update && \
        echo "Ubuntu is updated"
        echo "Upgrading ubuntu"
        $MULTIPASS exec $VM_NAME -- sudo apt upgrade -y && \
        echo "Ubuntu is upgraded"
    fi

    if [ "$RUN_STEP_CA" == "0" ]; then
        $MULTIPASS transfer scripts/install.sh $VM_NAME:install
        $MULTIPASS transfer scripts/uninstall.sh $VM_NAME:uninstall
        $MULTIPASS transfer scripts/start.sh $VM_NAME:start

        echo "Installing step-cli and step-ca"
        $MULTIPASS exec $VM_NAME -- sudo bash install && \
        echo "Successfully installed step-cli and step-ca"

        if [ "$SERVE_CA" == "0" ]; then
            echo "Starting step server"
            $MULTIPASS exec $VM_NAME -- bash start
        fi
    fi

fi

$MULTIPASS shell $VM_NAME