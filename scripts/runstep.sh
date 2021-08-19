#!/usr/bin/env bash

ORG_NAME="Step CA Tutorial"
HOSTDOMAIN="$(hostname).local"
STEP_CA_URL="https://stepca.local"
SERVER_URL="https://website.local"
CLIENT_DOMAIN="home.local"
EMAIL_ID="admin@$(hostname)"
HOST_CERT="/etc/letsencrypt/live/${HOSTDOMAIN}/fullchain.pem"
HOST_KEY="/etc/letsencrypt/live/${HOSTDOMAIN}/privkey.pem"
declare -g ROOT_CERT
declare -g CA_JSON
declare -g PASSWORD_FILE
declare -g SEARCH_FILE

show_help() {
    cat << EOF
Usage: runstep <command>
Commands:
        install                         Install Step CA **
        uninstall                       Uninstall Step CA **
        init                            Initialise Step CA
        service [COMMAND]               Manage Step CA service ** (Show status if no commands found)
        follow                          Follow Step CA server log
        start                           Start Step CA server
        commands [STEP PATH]            Show credentials of CA ** (default path=/etc/step-ca)
        bootstrap FINGERPRINT [-c]      Bootstrap Step CA inside a client
        server [-m]                     Run python web server with optional mTLS **
        certbot                         Run certbot and obtain client certificate from stepca **
        certificate                     Generate client certificate

Service commands: install, start, stop, enable [--now], disable [--now], restart, status 

[ ** - Require root access ]
EOF
}

require_sudo() {
    if [[ "$EUID" -ne 0 ]]; then
        echo "PERMISSION DEINED: Require root access."
        exit 1
    fi
}

check_network() {
    if ! wget -q --spider https://google.com; then
        ! wget -q --spider 1.1.1.1 && \
            echo "Network is not connected" || \
            echo "Unable to resolve DNS"
        exit 1
    fi
}

check_certbot() {

    require_sudo

    ! type certbot > /dev/null 2>&1 && \
        snap install certbot --classic
}

search_file_in_step() {
    SEARCH_FILE=""
    [ -n "$1" ] && FILE_PATH=$1 || (echo "Invalid file path" >&2 && exit 1)
    declare -a STEP_ROOTS=(
        "/home/ubuntu/.step"
        "/root/.step"
        "/etc/step-ca"
    )
    for steppath in "${STEP_ROOTS[@]}"; do
        _FILE_PATH="${steppath}${FILE_PATH}"
        [ -f "$_FILE_PATH" ] && SEARCH_FILE=$_FILE_PATH && break
    done
    [ -z "$SEARCH_FILE" ] && echo "Error: Unable to find $FILE_PATH" >&2 && exit 1
}

get_root_cert() {
    search_file_in_step "/certs/root_ca.crt"
    ROOT_CERT=$SEARCH_FILE
    unset SEARCH_FILE
}

get_ca_json() {
    search_file_in_step "/config/ca.json"
    CA_JSON=$SEARCH_FILE
    unset SEARCH_FILE
}

get_password_txt() {
    search_file_in_step "/secrets/password.txt"
    PASSWORD_FILE=$SEARCH_FILE
    unset SEARCH_FILE
}


bind_port_permission() {
    
    require_sudo

    PROGRAM=${1:-$(which step-ca)}

    # Enable step-ca to bind ports lower than 1024
    setcap CAP_NET_BIND_SERVICE=+eip $PROGRAM
}

bootstrap_commands() {

    [[ $# -eq 0 ]] && require_sudo

    STEP_PATH="${1:-/etc/step-ca}"
    PASSWORD=$(cat ${STEP_PATH}/secrets/password.txt || exit 1)
    FINGERPRINT=$(step certificate fingerprint "${STEP_PATH}/certs/root_ca.crt" || exit 1)
    cat <<CREDS

1. Bootstrap
$ sudo runstep bootstrap ${FINGERPRINT}
    ( This command initialise and bootstrap with certificarte authority)

2. Run certbot to obtain certificate for your system
$ sudo runstep certbot
    ( Certbot will manage all certificates and provide command to access server )

3. Start https server as daemon
$ sudo runstep server start
    ( Start the systemd service without mTLS )

4. Start https server as daemon
$ sudo runstep server -m -p 8443
    ( Start server in terminal with mTLS on port 8443 )

5. Request client certificate using JWK Provisioner
$ runstep certificate
    Password: ${PASSWORD}
    ( Choose JWK provisioner key. Then copy the above password and pasted it where it is requested. )

6. Test https server from client
$ curl ${SERVER_URL}
    ( Connect with https server wihtout mTLS)
$ curl ${SERVER_URL}:8443 --cert /home/ubuntu/.step/certs/${CLIENT_DOMAIN}.crt --key /home/ubuntu/.step/secrets/${CLIENT_DOMAIN}.key
    ( Connect with https server wiht mTLS on port 8443)

    ===================================
    | Server flow:    | 1 > 2 > 3 > 4 |
    | Client flow #1: | 1 > 2 > 6     |
    | Client flow #2: | 1 > 5 > 6     |
    ===================================

CREDS
}

add_completion() {
    BC_FILE="/home/ubuntu/.bash_completion"
    ([ -f "$BC_FILE" ] && grep -q runstep $BC_FILE) || \
    (echo "complete -W 'install uninstall service bootstrap start certbot certificate server init follow commands help' runstep" >> $BC_FILE && \
    chown ubuntu:ubuntu "$BC_FILE" && chmod 0644 "$BC_FILE")
}

install_stepca() {

    check_network
    require_sudo

    CLI_REPO="smallstep/cli"
    CA_REPO="smallstep/certificates"
    GITHUB_API_URL="https://api.github.com"
    GITHUB_URL="https://github.com"
    CLI_VER=$(curl -s ${GITHUB_API_URL}/repos/${CLI_REPO}/releases/latest | grep tag_name | sed 's/[(tag_name)"v:,[:space:]]//g')
    CA_VER=$(curl -s ${GITHUB_API_URL}/repos/${CA_REPO}/releases/latest | grep tag_name | sed 's/[(tag_name)"v:,[:space:]]//g')
    TEMP_PATH="/tmp/step"
    mkdir -p ${TEMP_PATH}

    # Download step-cli if not downloaded
    [ ! -f "${TEMP_PATH}/step-cli_${CLI_VER}_amd64.deb" ] && \
    wget -q --show-progress -O ${TEMP_PATH}/step-cli_${CLI_VER}_amd64.deb "${GITHUB_URL}/${CLI_REPO}/releases/download/v${CLI_VER}/step-cli_${CLI_VER}_amd64.deb"

    # Download step-ca if not downloaded
    [ ! -f "${TEMP_PATH}/step-ca_${CA_VER}_amd64.deb" ] && \
    wget -q --show-progress -O ${TEMP_PATH}/step-ca_${CA_VER}_amd64.deb "${GITHUB_URL}/${CA_REPO}/releases/download/v${CA_VER}/step-ca_${CA_VER}_amd64.deb"

    # Install deb packages
    dpkg -i ${TEMP_PATH}/step-cli_${CLI_VER}_amd64.deb > >(awk '!/^[\(]|^(update)|^(Selecting)/ {print}') && \
    dpkg -i ${TEMP_PATH}/step-ca_${CA_VER}_amd64.deb > >(awk '!/^[\(]|^(update)|^(Selecting)/ {print}') && \
    bind_port_permission
    add_completion
}

uninstall_stepca() {
    
    check_network
    require_sudo

    dpkg -r step-cli step-ca
    deluser step sudo
    userdel --remove step
    rm -rf /home/step/.step/ /tmp/step /etc/step-ca
}

init_ca() {

    check_network

    STEP_PATH=$(step path)
    NEW_PASSWORD_FILE="${STEP_PATH}/secrets/password.txt"
    IP_ADDR=$(hostname -I | xargs)
    PROVISIONER="token-admin"
    CA_HOST=""
    CA_PORT="443"

    if [ ! -f "${NEW_PASSWORD_FILE}" ]; then

        # Password generation
        mkdir -p "${STEP_PATH}/secrets"
        if type "openssl" > /dev/null 2>&1; then
            openssl rand -base64 24 > $NEW_PASSWORD_FILE
        elif type "gpg" > /dev/null 2>&1; then
            gpg --gen-random --armor 1 24 > $NEW_PASSWORD_FILE
        else
            echo "Need OpenSSL or GPG to genereate password"
        fi
        
        step ca init \
            --name "$ORG_NAME" \
            --provisioner "$PROVISIONER" \
            --dns "$HOSTDOMAIN" \
            --address "$CA_HOST:$CA_PORT" \
            --password-file "$NEW_PASSWORD_FILE" \
            --provisioner-password-file "$NEW_PASSWORD_FILE"

        step ca provisioner add acme --type ACME

    fi
}

install_service() {

    check_network
    require_sudo

    shift
    if [[ "$1" == "install" ]]; then
        # STEP CA Preparation
        OLD_STEP_PATH="/home/ubuntu/.step"
        STEP_PATH="/etc/step-ca"

        #Check for password
        [[ ! -f "${OLD_STEP_PATH}/secrets/password.txt" ]] && \
        echo "Password file not found" && exit 1

        # Create new step user
        useradd --system --home $STEP_PATH --shell /bin/false step

        mv $OLD_STEP_PATH $STEP_PATH
        sed -i 's/home\/ubuntu\/\.step/etc\/step-ca/g' $STEP_PATH/config/ca.json
        sed -i 's/home\/ubuntu\/\.step/etc\/step-ca/g' $STEP_PATH/config/defaults.json
        mkdir -p "${STEP_PATH}/db"
        chown -R step:step $STEP_PATH

        systemctl daemon-reload
        systemctl enable --now step-ca > /dev/null 2>&1

        tree "${STEP_PATH}"
        bootstrap_commands "${STEP_PATH}"

    elif [[ "$1" == "" ]]; then
        systemctl status step-ca
    else
        systemctl "$1" step-ca
    fi
    
}

start_ca() {

    get_ca_json
    get_password_txt
    STEPCA=$(which step-ca)
    
    $STEPCA $CA_JSON --password-file $PASSWORD_FILE
}

stepca_bootstrap() {

    check_network
    FINGERPRINT=""

    shift
    [ -n "$1" ] && [ ${1:0:1} != "-" ] && FINGERPRINT=$1 || \
    (echo "Error: Fingerprint is missing" && exit 1)
    shift
    step ca bootstrap --ca-url $STEP_CA_URL -f --install --fingerprint $FINGERPRINT || exit 1

}

run_server() {
    
    check_network
    require_sudo
    get_root_cert

    SERVER=$(which https-server)
    PARAMS=""

    shift
    while (( "$#" )); do
        case "$1" in
            start)
                systemctl start https-server.service || exit 1
                exit 0
                ;;
            stop)
                systemctl stop https-server.service || exit 1
                exit 0
                ;;
            status)
                systemctl status https-server.service || exit 1
                exit 0
                ;;
            -m|--mlts)
                [ -n "$PARAMS" ] && PARAMS="$PARAMS $1" || PARAMS=$1
                shift
                ;;
            -p|--port)
                ([ -z "$2" ] || [ "${2:0:1}" == "-" ] || [[ "$2" =~ ^[^0-9]+$ ]]) && \
                (echo "Inavlid port value: $2" >&2 && exit 1)
                [ -n "$PARAMS" ] && PARAMS="$PARAMS $1 $2" || PARAMS="$1 $2"
                shift 2
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
    set -- "-d $HOSTDOMAIN -r $ROOT_CERT -c $HOST_CERT -k $HOST_KEY $PARAMS"

    bind_port_permission "$SERVER"
    $SERVER $@
}

run_certbot() {

    check_network
    require_sudo
    check_certbot
    get_root_cert

    if [ -f "$HOST_CERT" -a -f "$HOST_KEY" ]; then
        REQUESTS_CA_BUNDLE="$ROOT_CERT" certbot renew || exit 1
    else
        REQUESTS_CA_BUNDLE="$ROOT_CERT" \
            certbot certonly -n --standalone \
            --agree-tos --email "$EMAIL_ID" -d "$HOSTDOMAIN" \
            --server "${STEP_CA_URL}/acme/acme/directory" || exit 1
    fi

    install -D -T -m 0644 -o ubuntu -g ubuntu $HOST_CERT "/home/ubuntu/.step/certs/$HOSTDOMAIN.crt"
    install -D -T -m 0600 -o ubuntu -g ubuntu $HOST_KEY "/home/ubuntu/.step/secrets/$HOSTDOMAIN.key"
    cat <<EOF

The certificate and private key is stored in following locations:

    Certificate: /home/ubuntu/.step/certs/$HOSTDOMAIN.crt
    Private Key: /home/ubuntu/.step/secrets/$HOSTDOMAIN.key

EOF
}

get_client_certificate() {
    STEP_PATH=$(step path)
    mkdir -p $STEP_PATH/secrets
    CLIENT_CERT="$STEP_PATH/certs/$HOSTDOMAIN.crt"
    CLIENT_KEY="$STEP_PATH/secrets/$HOSTDOMAIN.key"
    step ca certificate $HOSTDOMAIN $CLIENT_CERT $CLIENT_KEY || exit 1
    cat <<EOF

Run the following command to visit the HTTPS website using mTLS:
curl $SERVER_URL --cert $CLIENT_CERT --key $CLIENT_KEY

EOF
}

main() {
    case "$1" in
        install)        install_stepca;;
        uninstall)      uninstall_stepca;;
        service)        install_service "$@";;
        bootstrap)      stepca_bootstrap "$@";;
        server)         run_server "$@";;
        certbot)        run_certbot;;
        certificate)    get_client_certificate;;
        start)          start_ca;;
        init)           init_ca;;
        follow)         journalctl -f -u step-ca;;
        commands)       bootstrap_commands;;
        help)           show_help && exit 0;;
        *)              echo "Invalid command" && exit 1;;
    esac
}

[[ $# -eq 0 ]] && show_help || main $@
