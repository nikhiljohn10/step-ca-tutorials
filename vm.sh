#!/usr/bin/env bash

MULTIPASS=""
INSTANCE_NAME=""
UPGRADE_INSTANCE=1
INSTANCE_EXISTS=1
FORCED_NEW_INSTANCE=1

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
         -u,--upgrade    Update and upgrade packages inside ubuntu instance
         -f,--force      Force a new instance to start
         -d,--delete     Delete the instance
EOF
}

verify_instance() {
    [[ "${INSTANCE_NAME}" =~ [^a-zA-Z] ]] && \
        (echo "Invalid instance name. It should only contain alphabets." && exit 1) || \
        shift
    INSTANCE_EXISTS=$($MULTIPASS ls | grep $INSTANCE_NAME > /dev/null 2>&1; echo $?)
}

delete_instance() {
    $MULTIPASS delete $INSTANCE_NAME -p && echo "Successfully removed $INSTANCE_NAME"
    INSTANCE_EXISTS=1
}

parse_params() {
    PARAMS=""

    while (( "$#" )); do
        case "$1" in
            -u|--upgrade)
                UPGRADE_INSTANCE=0
                shift
                ;;
            -f|--force)
                FORCED_NEW_INSTANCE=0
                shift
                ;;
            -d|--delete)
                delete_instance
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

create_instance() {
    [[ $FORCED_NEW_INSTANCE -eq 0 ]] && delete_instance
    [[ $INSTANCE_EXISTS -eq 0 ]] && \
        (echo "Virtual machine '$INSTANCE_NAME' already exists" && load_shell && exit 0)
    echo "Starting a new virtual instance of Ubuntu"
    $MULTIPASS launch -n $INSTANCE_NAME --cloud-init "$1" && \
        echo "Ubuntu instance ${INSTANCE_NAME} is installed" || exit 1
    
    [ "$UPGRADE_INSTANCE" == "0" ] && \
        echo "Updating ubuntu" && \
            $MULTIPASS exec $INSTANCE_NAME -- sudo apt-get upgrade -q=2 && \
                echo "Ubuntu is updated"
    
    echo "Installing runstep"
    $MULTIPASS transfer scripts/runstep.sh $INSTANCE_NAME:runstep
    $MULTIPASS exec $INSTANCE_NAME -- chmod 755 runstep
    $MULTIPASS exec $INSTANCE_NAME -- sudo mv runstep /usr/bin/runstep
    echo "Installing step-cli and step-ca"
    $MULTIPASS exec $INSTANCE_NAME -- sudo runstep install
}

generate() {
    check_multipass
    verify_instance
    check_network

    [ -z "$1" ] && echo "cloud init config parameter is empty" && exit 1
    CONFIG=$1 && shift
    parse_params $@
    create_instance "$CONFIG"
}

reset_instance() {
    check_multipass
    $MULTIPASS delete --all -p && 
        echo "Multipass is reset"
}

load_shell() {
    $MULTIPASS shell $INSTANCE_NAME
}

generate_ca() {
    INSTANCE_NAME="stepca"
    CONFIG="$(pwd)/configs/ca.yaml"
    shift
    generate "$CONFIG" "$@"
    echo "Generating PKI"
    $MULTIPASS exec $INSTANCE_NAME -- runstep init
    echo "Installing step-ca service"
    $MULTIPASS exec $INSTANCE_NAME -- sudo runstep service install
}

generate_server() {
    INSTANCE_NAME="website"
    CONFIG="$(pwd)/configs/server.yaml"
    shift
    generate "$CONFIG" "$@"
    echo "Installing https-servere"
    $MULTIPASS transfer scripts/server.py $INSTANCE_NAME:https-server
    $MULTIPASS exec $INSTANCE_NAME -- chmod 755 https-server
    $MULTIPASS exec $INSTANCE_NAME -- sudo mv https-server /usr/bin/https-server
    $MULTIPASS exec $INSTANCE_NAME -- sudo systemctl daemon-reload
    $MULTIPASS exec $INSTANCE_NAME -- sudo systemctl enable https-server.service
    load_shell
}

generate_client() {
    INSTANCE_NAME="home"
    CONFIG="$(pwd)/configs/client.yaml"
    shift
    generate "$CONFIG" "$@"
    load_shell
}

main() {
    INSTANCE_NAME=$1
    CONFIG="$(pwd)/configs/generic.yaml"
    generate "$CONFIG" "$@"
    load_shell
}

[[ $# -eq 0 ]] && show_help && exit 1
case "$1" in
    ca)         generate_ca "$@";;
    server)     generate_server "$@";;
    client)     generate_client "$@";;
    reset)      reset_instance;;
    help)       show_help;;
    *)          main $@;;
esac
