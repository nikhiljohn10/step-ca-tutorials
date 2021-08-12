#!/usr/bin/env bash


require_sudo() {
    if [[ "$EUID" -ne 0 ]]; then
        echo "The script need to be run as root..."
        exit 1
    fi
}

usage() {
    cat << EOF

Usage: ${0##*/} <COMMAND> [-h|--help] [-f OUTFILE] [FILE]...
Step CA Demo Runner

Commands:

    i | install
    u | uninstall
    b | bootstrap FINGERPRINT [-i|--install] [-c|--certbot]
    ca [-i|--install] [-u|--uninstall] [-s|--server]
    ca server [-i|--install] [-u|--uninstall]
    server [-i|--install] [-u|--uninstall]

Options:

    -h|--help       display this help and exit
    -c|--certbot    install certbot
    -i|--install    install certificate/server
    -u|--uninstall  uninstall certificate/server
    -s|--server     run step ca server
EOF
}

install_cmd() {
    echo "Installing Step CA"
    sleep 2
    echo "Installed Step CA"
}

uninstall_cmd() {
    echo "Uninstalling Step CA"
    sleep 2
    echo "Uninstalled Step CA"
}

bootstrap_cmd() {
    [[ $# -lt 1 ]] && usage && exit 1
    FINGERPRINT=$2
    shift
    INSTALL_CERT=1
    INSTALL_CERTBOT=1
    args=( )
    for arg; do
        case "$arg" in
            --help)           args+=( -h ) ;;
            --install)        args+=( -i ) ;;
            --certbot)        args+=( -c ) ;;
            --*)              args+=( ) ;;
            *)                args+=( "$arg" ) ;;
        esac
    done
    set -- "${args[@]}"
    OPTIND=1
    while getopts "hic" OPTION; do
        case $OPTION in
            h)  usage; exit 0;;
            i)  INSTALL_CERT=0;;
            c)  INSTALL_CERTBOT=0;;
        esac
    done
    echo "Bootstrapping in progress..."
    sleep 1
    echo "CA Server verified using fingerprint ${FINGERPRINT}"
    [[ $INSTALL_CERT -eq 0 ]] && echo "Installed CA Root certificate"
    [[ $INSTALL_CERTBOT -eq 0 ]] && echo "Installed Certbot"
}

ca_cmd() {
    INSTALL_CERT=1
    UNINSTALL_CERT=1
    RUN_SERVER=1
    args=( )
    for arg; do
        case "$arg" in
            --help)           args+=( -h ) ;;
            --install)        args+=( -i ) ;;
            --uninstall)      args+=( -u ) ;;
            --server)         args+=( -s ) ;;
            --*)              args+=( ) ;;
            *)                args+=( "$arg" ) ;;
        esac
    done
    set -- "${args[@]}"
    OPTIND=1
    while getopts "hius" OPTION; do
        case $OPTION in
            h)  usage; exit 0;;
            i)  INSTALL_CERT=0;;
            u)  UNINSTALL_CERT=0;;
            s)  RUN_SERVER=0;;
        esac
    done

    echo "Bootstrapping in progress..."
    sleep 1
    echo "CA Server verified using fingerprint ${FINGERPRINT}"
    [[ $INSTALL_CERT -eq 0 ]] && echo "Installed CA Root certificate"
    [[ $INSTALL_CERTBOT -eq 0 ]] && echo "Installed Certbot"
}

server_cmd() {
    :
}

parse_commands() {
    [[ $# -lt 1 ]] && usage && exit 1
    case "$1" in
        i|install) install_cmd;;
        u|uninstall) uninstall_cmd;;
        b|bootstrap) shift; bootstrap_cmd $@;;
        ca) parse_ca_cmd;;
        server) parse_server_cmd;;
        *) echo "Invalid command. Please use a valid command"; usage; exit 1;;
    esac
}

parse_arguments() {
    args=( )
    for arg; do
        case "$arg" in
            --help)           args+=( -h ) ;;
            --host|-hS)       args+=( -s ) ;;
            --cmd)            args+=( -c ) ;;
            --*)              args+=( ) ;;
            *)                args+=( "$arg" ) ;;
        esac
    done
    set -- "${args[@]}"
    OPTIND=1
    while getopts "hs:c:" OPTION; do
        case $OPTION in
            h)  usage; exit 0;;
            s)  servers_array+=("$OPTARG");;
            c)  cmd="$OPTARG";;
        esac
    done
}

runstep() {
    [[ $# -eq 0 ]] && show_help
    PARAMS=""
    while (( "$#" )); do
        case "$1" in
            install)
                require_sudo
                install_step_ca
                break
                ;;
            uninstall)
                require_sudo
                uninstall_step_ca
                break
                ;;
            ca)
                echo "Running Step CA"
                shift
                ;;
            -i|--install-cert)
                if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
                    echo "Installing certificate"
                    echo "Fingerprint is $2"
                    shift 2
                else
                    echo "Error: Fingerprint is missing" >&2
                    exit 1
                fi
                ;;
            -h|--help)
                show_help
                shift
                ;;
            -*|--*=)
                echo "Error: Unsupported flag $1" >&2
                exit 1
                ;;
            *)
                echo "Found params $1"
                PARAMS="$PARAMS $1"
                shift
                ;;
        esac
    done
    eval set -- "$PARAMS"
}

# runstep install
# runstep ca 
# runstep ca serve
# runstep ca stop
# runstep ca stop
# runstep uninstall
