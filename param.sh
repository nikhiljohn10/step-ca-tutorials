#!/usr/bin/env bash

require_sudo() {
    if [[ "$EUID" -ne 0 ]]; then
        echo "The script need to be run as root..."
        exit 1
    fi
}

install_step_ca() {
    echo "Installing Step CA"
    sleep 2
    echo "Installed Step CA"
}

uninstall_step_ca() {
    echo "Uninstalling Step CA"
    sleep 2
    echo "Uninstalled Step CA"
}

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

parse_ca_command() {
    args=( )

    # replace long arguments
    for arg; do
        case "$arg" in
            --help)           args+=( -h ) ;;
            --host|-hS)       args+=( -s ) ;;
            --cmd)            args+=( -c ) ;;
            *)                args+=( "$arg" ) ;;
        esac
    done

    printf 'args before update : '; printf '%q ' "$@"; echo
    set -- "${args[@]}"
    printf 'args after update  : '; printf '%q ' "$@"; echo

    while getopts "hs:c:" OPTION; do
        : "$OPTION" "$OPTARG"
        echo "optarg : $OPTARG"
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

parse_ca_command -h