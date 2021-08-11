
RUN_STEP_CA=1
RUN_SERVE=1
COMMAND_FOUND=0

show_help() {
    echo "Usage: runstep <command> [options]"
    echo "Commands:"
    echo "         install <fingerprint>    Install Step CA"
    echo "Options:"
    echo "         -c,--ca        Setup CA"
    echo "         -s,--server    Setup Webserver"
    echo
    echo "By default setup for normal client if no options are given"
    exit 0
}

check_network() {
    if ! wget -q --spider https://google.com; then
        if ! wget -q --spider 1.1.1.1; then
            echo "Network is not connected"
        else
            echo "Unable to resolve DNS"
        fi
        exit 1
    fi
    echo "Network connectivity verified"
}

parse_params() {
    PARAMS=""

    while (( "$#" )); do
        case "$1" in
            install)
                echo "Install Step CA"
                shift
                ;;
            -c|--ca)
                RUN_STEP_CA=0
                shift
                ;;
            -s|--server)
                RUN_SERVE=0
                shift
                ;;
            -i|--install-only)
                RUN_SERVE=0
                shift
                ;;
            -u|--uninstall)
                RUN_SERVE=0
                shift
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
}

run_command() {

    if [ "$RUN_STEP_CA" == "0" ]; then
        echo "Run CA"
    elif [ "$RUN_SERVE" == "0" ]; then
        echo "Run Server"
    else
        echo "Run Client"
    fi
}

main(){
    check_network
    parse_params $@
    run_command
}

[[ $# -eq 0 ]] && show_help || main $@
