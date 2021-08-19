#!/usr/bin/env bash

MULTIPASS=""
VM_NAME=""
SERVE_CA=1
UPGRADE_VM=1
RUN_STEP_CA=1
SERVE_HTTPS=1
VM_EXISTS=1
FORCED_NEW_VM=1

check_multipass() {
    ! type multipass > /dev/null 2>&1 && \
        echo "Multipass is not installed" && exit 1
    MULTIPASS=$(which multipass)
}

check_network() {
    if ! wget -q --spider https://google.com; then
        ! wget -q --spider 1.1.1.1 && \
            echo "Network is not connected" || \
            echo "Unable to resolve DNS"
        exit 1
    fi
}

show_help() {
    cat << EOF
Usage: ${0:-vm.sh} <name> [options]
Options:
         -u,--upgrade    Update and upgrade packages inside ubuntu vm
         -f,--force      Force a new instance to start
         -d,--delete     Delete the instance
EOF
}

verify_vm() {
    [[ "${VM_NAME}" =~ [^a-zA-Z] ]] && \
        (echo "Invalid VM name. It should only contain alphabets." && exit 1) || \
        shift
    VM_EXISTS=$($MULTIPASS ls | grep $VM_NAME > /dev/null 2>&1; echo $?)
}

delete_vm() {
    $MULTIPASS delete $VM_NAME -p && echo "Successfully removed $VM_NAME"
    VM_EXISTS=1
}

parse_params() {
    PARAMS=""

    while (( "$#" )); do
        case "$1" in
            -u|--upgrade)
                UPGRADE_VM=0
                shift
                ;;
            -f|--force)
                FORCED_NEW_VM=0
                shift
                ;;
            -d|--delete)
                delete_vm
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
    set -- "$PARAMS"
}

create_vm() {
    [[ $FORCED_NEW_VM -eq 0 ]] && delete_vm
    [[ $VM_EXISTS -eq 0 ]] && \
        (echo "Virtual machine '$VM_NAME' already exists" && load_shell && exit 0)
    echo "Starting a new virtual instance of Ubuntu"
    $MULTIPASS launch -n $VM_NAME --cloud-init "$1" && \
        echo "VM ${VM_NAME} installed" || exit 1
    
    [ "$UPGRADE_VM" == "0" ] && \
        echo "Updating ubuntu" && \
            $MULTIPASS exec $VM_NAME -- sudo apt-get upgrade -q=2 && \
                echo "Ubuntu is updated"
    
    echo "Installing runstep"
    $MULTIPASS transfer scripts/runstep.sh $VM_NAME:runstep
    $MULTIPASS exec $VM_NAME -- chmod 755 runstep
    $MULTIPASS exec $VM_NAME -- sudo mv runstep /usr/bin/runstep
    echo "Installing step-cli and step-ca"
    $MULTIPASS exec $VM_NAME -- sudo runstep install
}

generate() {
    check_multipass
    verify_vm
    check_network

    [ -z "$1" ] && echo "cloud init config parameter is empty" && exit 1
    CONFIG=$1 && shift
    parse_params $@
    create_vm "$CONFIG"
}

load_shell() {
    $MULTIPASS shell $VM_NAME
}

generate_ca() {
    VM_NAME="stepca"
    CONFIG="$(pwd)/configs/ca.yaml"
    shift
    generate "$CONFIG" "$@"
    echo "Generating PKI"
    $MULTIPASS exec $VM_NAME -- runstep init
    echo "Installing step-ca service"
    $MULTIPASS exec $VM_NAME -- sudo runstep service install
}

generate_server() {
    VM_NAME="website"
    CONFIG="$(pwd)/configs/server.yaml"
    shift
    generate "$CONFIG" "$@"
    echo "Installing https-servere"
    $MULTIPASS transfer scripts/server.py $VM_NAME:https-server
    $MULTIPASS exec $VM_NAME -- chmod 755 https-server
    $MULTIPASS exec $VM_NAME -- sudo mv https-server /usr/bin/https-server
    $MULTIPASS exec $VM_NAME -- sudo systemctl daemon-reload
    $MULTIPASS exec $VM_NAME -- sudo systemctl enable https-server.service
    load_shell
}

generate_client() {
    VM_NAME="home"
    CONFIG="$(pwd)/configs/client.yaml"
    shift
    generate "$CONFIG" "$@"
    load_shell
}

reset_vm() {
    check_multipass
    $MULTIPASS delete --all -p && 
        echo "Multipass is reset"
}

main() {
    VM_NAME=$1
    CONFIG="$(pwd)/configs/client.yaml"
    check_multipass
    verify_vm
    check_network
    parse_params $@
    process_vm
}

[[ $# -eq 0 ]] && show_help && exit 1
case "$1" in
    ca)         generate_ca "$@";;
    server)     generate_server "$@";;
    client)     generate_client "$@";;
    reset)      reset_vm;;
    help)       show_help;;
    *)          main $@;;
esac
