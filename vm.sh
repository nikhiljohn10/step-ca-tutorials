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
         -c,--step-ca    Install step ca inside vm
         -s,--serve      Run step ca server if --step-ca options is given
         -p,--pyserver   Run python https server using certificate from certbot inside vm
         -u,--upgrade    Update and upgrade packages inside ubuntu vm
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
            # -c|--step-ca)
            #     RUN_STEP_CA=0
            #     shift
            #     ;;
            # -s|--serve)
            #     SERVE_CA=0
            #     shift
            #     ;;
            # -p|--pyserver)
            #     SERVE_HTTPS=0
            #     shift
            #     ;;
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

process_vm() {
    [[ $FORCED_NEW_VM -eq 0 ]] && delete_vm
    if [[ $VM_EXISTS -eq 1 ]] ; then
        echo "Starting a new virtual instance of Ubuntu"
        $MULTIPASS launch -n $VM_NAME --cloud-init "$(pwd)/utils/config.yaml" && \
            echo "VM ${VM_NAME} installed" || exit 1

        [ "$UPGRADE_VM" == "0" ] && \
            echo "Updating ubuntu" && \
                $MULTIPASS exec $VM_NAME -- sudo apt-get upgrade -q=2 && \
                    echo "Ubuntu is updated"

        if [ "$RUN_STEP_CA" == "0" ]; then
            $MULTIPASS transfer scripts/runstep.sh $VM_NAME:runstep
            $MULTIPASS exec $VM_NAME -- chmod 755 runstep
            $MULTIPASS exec $VM_NAME -- sudo mv runstep /usr/bin/runstep
            $MULTIPASS exec $VM_NAME -- runstep completion

            echo "Installing step-cli and step-ca"
            $MULTIPASS exec $VM_NAME -- sudo runstep install && \
                echo "Successfully installed step-cli and step-ca"

            if [ "$SERVE_HTTPS" == "0" ]; then
                $MULTIPASS transfer scripts/server.py $VM_NAME:server
                $MULTIPASS transfer services/step-renew.service $VM_NAME:step-renew.service
                $MULTIPASS exec $VM_NAME -- chmod 755 server
                $MULTIPASS exec $VM_NAME -- sudo mv server /usr/bin/server
                $MULTIPASS exec $VM_NAME -- sudo mv step-renew.service /etc/systemd/system/step-renew.service
            elif [ "$SERVE_CA" == "0" ]; then
                $MULTIPASS transfer services/step-ca.service $VM_NAME:step-ca.service
                $MULTIPASS exec $VM_NAME -- runstep init
                $MULTIPASS exec $VM_NAME -- sudo mv step-ca.service /etc/systemd/system/step-ca.service
                $MULTIPASS exec $VM_NAME -- sudo runstep service install
                exit 0
            fi
        fi
    else
        echo "Virtual machine '$VM_NAME' already exists"
    fi

    $MULTIPASS shell $VM_NAME
}

create_vm() {
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
    CONFIG=$1

    parse_params $@
    [[ $FORCED_NEW_VM -eq 0 ]] && delete_vm
    [[ $VM_EXISTS -eq 0 ]] && \
        (echo "Virtual machine '$VM_NAME' already exists" && load_shell && exit 0)
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
    VM_NAME="server"
    CONFIG="$(pwd)/configs/server.yaml"
    shift
    generate "$CONFIG" "$@"
    echo "Installing https-servere"
    $MULTIPASS transfer scripts/server.py $VM_NAME:https-server
    $MULTIPASS exec $VM_NAME -- chmod 755 https-server
    $MULTIPASS exec $VM_NAME -- sudo mv https-server /usr/bin/https-server
    $MULTIPASS exec $VM_NAME -- sudo systemctl daemon-reload
    $MULTIPASS exec $VM_NAME -- sudo systemctl start https-server.service
    load_shell
}

generate_client() {
    VM_NAME="client"
    CONFIG="$(pwd)/configs/client.yaml"
    shift
    generate "$CONFIG" "$@"
    $MULTIPASS shell $VM_NAME
    load_shell
}

main() {
    VM_NAME=$1
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
    reset)      check_multipass && $MULTIPASS delete --all -p && echo "Multipass is reset";;
    help)       show_help;;
    *)          main $@;;
esac
