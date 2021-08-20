#!/usr/bin/env bash

MULTIPASS=""
INSTANCE_NAME=""
UPGRADE_INSTANCE=1
INSTANCE_EXISTS=1
FORCED_NEW_INSTANCE=1

check_multipass() {
    ! type multipass > /dev/null 2>&1 && \
        echo "Multipass is not installed" >&2 && exit 1
    MULTIPASS=$(which multipass)
}

check_network() {
    if ! wget -q --spider https://google.com; then
        ! wget -q --spider 1.1.1.1 && \
            echo "Network is not connected" >&2 || \
            echo "Unable to resolve DNS" >&2
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
        (echo "Invalid instance name. It should only contain alphabets." >&2 && exit 1) || \
        shift
    INSTANCE_EXISTS=$($MULTIPASS ls | grep $INSTANCE_NAME > /dev/null 2>&1; echo $?)
}

delete_instance() {
    $MULTIPASS delete $INSTANCE_NAME -p > /dev/null 2>&1 && \
        echo "Successfully removed the instance $INSTANCE_NAME" || \
            echo "Instance $INSTANCE_NAME does not exists"
    INSTANCE_EXISTS=1
}

parse_params() {
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
                echo "Error: Invalid input $1" >&2
                exit 1
                ;;
        esac
    done
}

create_instance() {
    [[ $FORCED_NEW_INSTANCE -eq 0 ]] && delete_instance

    if [[ $INSTANCE_EXISTS -eq 0 ]]; then
        echo "Virtual machine '$INSTANCE_NAME' already exists"
        load_shell
        exit 0
    else
        [ -z "$1" ] && echo "cloud init config parameter is empty" >&2 && exit 1

        echo "Starting a new virtual instance of Ubuntu" && \
            $MULTIPASS launch -n $INSTANCE_NAME --cloud-init "$1" && \
                echo "Ubuntu instance ${INSTANCE_NAME} is installed" || exit 1
        
        [ "$UPGRADE_INSTANCE" == "0" ] && \
            echo "Updating ubuntu" && \
                $MULTIPASS exec $INSTANCE_NAME -- sudo apt-get upgrade -q=2 && \
                    echo "Ubuntu is updated"
    fi
}

generate() {
    check_multipass
    verify_instance
    check_network

    CONFIG=$1
    shift
    parse_params $@
    create_instance "$CONFIG"
    
    echo "Installing runstep"
    $MULTIPASS transfer scripts/runstep.sh $INSTANCE_NAME:runstep
    $MULTIPASS exec $INSTANCE_NAME -- chmod 755 runstep
    $MULTIPASS exec $INSTANCE_NAME -- sudo mv runstep /usr/bin/runstep
    echo "Installing step-cli and step-ca"
    $MULTIPASS exec $INSTANCE_NAME -- sudo runstep install
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

    echo "Installing https-server"
    $MULTIPASS transfer scripts/server.py $INSTANCE_NAME:https-server
    $MULTIPASS exec $INSTANCE_NAME -- chmod 755 https-server
    $MULTIPASS exec $INSTANCE_NAME -- sudo mv https-server /usr/bin/https-server
    echo "Loading https-server service"
    $MULTIPASS exec $INSTANCE_NAME -- sudo systemctl daemon-reload
    $MULTIPASS exec $INSTANCE_NAME -- sudo runstep server enable
    load_shell
}

generate_client() {

    INSTANCE_NAME="home"
    CONFIG="$(pwd)/configs/client.yaml"

    shift
    generate "$CONFIG" "$@"
    load_shell
}

generate_generic() {

    check_multipass
    verify_instance
    check_network

    [ -z "$1" ] && echo "Instance name is empty" >&2 && exit 1

    INSTANCE_NAME="$1"
    shift
    parse_params $@
    create_instance "$(pwd)/configs/generic.yaml"
    load_shell
}

main() {
    [[ $# -eq 0 ]] && show_help && exit 1
    case "$1" in
        help)       show_help;;
        reset)      reset_instance;;
        ca)         generate_ca "$@";;
        server)     generate_server "$@";;
        client)     generate_client "$@";;
        *)          generate_generic $@;;
    esac
}

main "$@"