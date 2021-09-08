#!/usr/bin/env bash

ORG_NAME="Step CA Tutorial"
HOSTDOMAIN="$(hostname).local"
STEP_CA_URL="https://stepca.local"
SERVER_URL="https://website.local"
CLIENT_DOMAIN="home.local"
EMAIL_ID="admin@$(hostname)"
HOST_CERT="/etc/letsencrypt/live/${HOSTDOMAIN}/fullchain.pem"
HOST_KEY="/etc/letsencrypt/live/${HOSTDOMAIN}/privkey.pem"
HOME_STEP_PATH="/home/ubuntu/.step"
ROOT_STEP_PATH="/etc/step-ca"
WORKER_PATH="/home/ubuntu/.worker"

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
        follow [KEYWORD]                Follow a service log 
        start                           Start Step CA server
        deploy                          Deploy Cloudflare worker
        commands [STEP PATH]            Show credentials of CA ** (default path=$ROOT_STEP_PATH)
        bootstrap FINGERPRINT [-c]      Bootstrap Step CA inside a client
        server [-m] [-p|--port PORT]    Run HTTPS server with optional mTLS **
        server COMMAND                  Manage HTTPS server service using systemctl commands **
        certbot                         Run certbot and obtain client certificate from stepca **
        certificate                     Generate a client certificate

Service commands:  install, start, stop, enable [--now], disable [--now], restart, status 
Follow keywords:   ca (Step CA server), server (HTTPS WebServer), mtls (HTTPS Server with mTLS), syslog (System Logs)

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

get_password_file() {
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

    get_root_cert
    get_password_file

    PASSWORD=$(cat $PASSWORD_FILE || exit 1)
    FINGERPRINT=$(step certificate fingerprint "${ROOT_CERT}" || exit 1)
    cat <<CREDS

1. Bootstrap
$ runstep bootstrap ${FINGERPRINT}
    ( This command initialise and bootstrap with certificarte authority)

2. Run certbot to obtain certificate for your system
$ sudo runstep certbot
    ( Certbot will manage all certificates and provide command to access server. Then it start HTTPS server service if it exsists)

3. Start HTTPS server as daemon (Optional)
$ sudo runstep server -m -p 8443
    ( Start server in terminal with mTLS on port 8443 )

4. Request client certificate using JWK Provisioner
$ runstep certificate
    Password: ${PASSWORD}
    ( Choose JWK provisioner key. Then copy the above password and pasted it where it is requested. )

5. Test HTTPS server from client
$ curl ${SERVER_URL}
    ( Connect with HTTPS server wihtout mTLS)

$ curl ${SERVER_URL}:8443 --cert \$(step path)/certs/${CLIENT_DOMAIN}.crt --key \$(step path)/secrets/${CLIENT_DOMAIN}.key
    ( Connect with HTTPS server wiht mTLS on port 8443)

    ===============================
    | Server flow:    | 1 > 2 > 3 |
    | Client flow #1: | 1 > 2 > 5 |
    | Client flow #2: | 1 > 4 > 5 |
    ===============================

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
    wget -q -O ${TEMP_PATH}/step-cli_${CLI_VER}_amd64.deb "${GITHUB_URL}/${CLI_REPO}/releases/download/v${CLI_VER}/step-cli_${CLI_VER}_amd64.deb"

    # Download step-ca if not downloaded
    [ ! -f "${TEMP_PATH}/step-ca_${CA_VER}_amd64.deb" ] && \
    wget -q -O ${TEMP_PATH}/step-ca_${CA_VER}_amd64.deb "${GITHUB_URL}/${CA_REPO}/releases/download/v${CA_VER}/step-ca_${CA_VER}_amd64.deb"

    # Install deb packages
    dpkg -i ${TEMP_PATH}/step-cli_${CLI_VER}_amd64.deb > >(awk '!/^[\(]|^(update)|^(Selecting)/ {print}') && \
    dpkg -i ${TEMP_PATH}/step-ca_${CA_VER}_amd64.deb > >(awk '!/^[\(]|^(update)|^(Selecting)/ {print}') && \
    bind_port_permission
    add_completion

    # Installing worker
    git clone "https://github.com/nikhiljohn10/ca-worker" "${WORKER_PATH}"
    mv "/home/ubuntu/ca-worker" "${WORKER_PATH}" 
    tree "/home/ubuntu/"
    tree "${WORKER_PATH}"
}

uninstall_stepca() {
    
    check_network
    require_sudo

    dpkg -r step-cli step-ca
    deluser step sudo
    userdel --remove step
    rm -rf $HOME_STEP_PATH $ROOT_STEP_PATH /tmp/step
}

init_ca() {

    check_network

    NEW_PASSWORD_FILE="${HOME_STEP_PATH}/secrets/password.txt"
    IP_ADDR=$(hostname -I | xargs)
    PROVISIONER="token-admin"
    CA_HOST=""
    CA_PORT="443"

    if [ ! -f "${NEW_PASSWORD_FILE}" ]; then

        # Password generation
        mkdir -p "${HOME_STEP_PATH}/secrets"
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
        whoami
        ls -la "${HOME_STEP_PATH}/certs/root_ca.crt"
        cp "${HOME_STEP_PATH}/certs/root_ca.crt" "${WORKER_PATH}/certs/"
        ls -la "${WORKER_PATH}/certs/"
        tree "${WORKER_PATH}"
    fi
}

install_service() {

    check_network
    require_sudo

    shift
    if [[ "$1" == "install" ]]; then

        #Check for password
        [[ ! -f "${HOME_STEP_PATH}/secrets/password.txt" ]] && \
        echo "Password file not found" && exit 1

        # Create new step user
        useradd --system --home "$ROOT_STEP_PATH" --shell /bin/false step

        mv "$HOME_STEP_PATH" "$ROOT_STEP_PATH"
        sed -i 's/home\/ubuntu\/\.step/etc\/step-ca/g' "$ROOT_STEP_PATH/config/ca.json"
        sed -i 's/home\/ubuntu\/\.step/etc\/step-ca/g' "$ROOT_STEP_PATH/config/defaults.json"
        mkdir -p "${ROOT_STEP_PATH}/db"
        chown -R step:step "$ROOT_STEP_PATH"

        systemctl daemon-reload
        systemctl enable --now step-ca > /dev/null 2>&1

        tree "${ROOT_STEP_PATH}"
        bootstrap_commands "${ROOT_STEP_PATH}"
        tree "${WORKER_PATH}"

    elif [[ "$1" == "" ]]; then
        systemctl status step-ca
    else
        systemctl "$1" step-ca
    fi
    
}

start_ca() {

    get_ca_json
    get_password_file
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

    PARAMS=""
    shift
    while (( "$#" )); do
        case "$1" in
            start|stop|status|enable|disable|restart)
                systemctl "$1" https-server.service 1>/dev/null || exit 1
                systemctl "$1" https-mtls.service 1>/dev/null || exit 1
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

    get_root_cert
    SERVER=$(which https-server)
    set -- "-d $HOSTDOMAIN -r $ROOT_CERT -c $HOST_CERT -k $HOST_KEY $PARAMS"

    bind_port_permission "$SERVER"
    $SERVER $@
}

run_certbot() {

    check_network
    require_sudo
    check_certbot
    get_root_cert

    REQUESTS_CA_BUNDLE="$ROOT_CERT" \
        certbot certonly -n --standalone \
        --agree-tos --email "$EMAIL_ID" -d "$HOSTDOMAIN" \
        --server "${STEP_CA_URL}/acme/acme/directory" || exit 1
    
    install -D -T -m 0644 -o ubuntu -g ubuntu $HOST_CERT "${HOME_STEP_PATH}/certs/${HOSTDOMAIN}.crt"
    install -D -T -m 0600 -o ubuntu -g ubuntu $HOST_KEY "${HOME_STEP_PATH}/secrets/${HOSTDOMAIN}.key"
    chown -R ubuntu:ubuntu "${HOME_STEP_PATH}"

    if [ -f "/etc/systemd/system/https-server.service" -a -f "/etc/systemd/system/https-mtls.service" ]; then
        if [ ! -f "/etc/letsencrypt/renewal-hooks/post/${HOSTDOMAIN}.sh" ]; then
            tee -a "/etc/letsencrypt/renewal-hooks/post/${HOSTDOMAIN}.sh" > /dev/null 2>&1 <<EOF
#!/usr/bin/env bash
install -D -T -m 0644 -o ubuntu -g ubuntu $HOST_CERT ${HOME_STEP_PATH}/certs/${HOSTDOMAIN}.crt
install -D -T -m 0600 -o ubuntu -g ubuntu $HOST_KEY ${HOME_STEP_PATH}/secrets/${HOSTDOMAIN}.key
chown -R ubuntu:ubuntu ${HOME_STEP_PATH}
systemctl restart https-server
systemctl restart https-mtls
EOF
            chmod +x "/etc/letsencrypt/renewal-hooks/post/${HOSTDOMAIN}.sh"
        fi
        main server start
    fi

    cat <<EOF

The certificate and private key is stored in following locations:

    Certificate: ${HOME_STEP_PATH}/certs/${HOSTDOMAIN}.crt
    Private Key: ${HOME_STEP_PATH}/secrets/${HOSTDOMAIN}.key

The certificate for the domain ${HOSTDOMAIN} is automatically renewed every 12 hours.

EOF
}

get_client_certificate() {
    mkdir -p "$HOME_STEP_PATH/secrets" "$HOME_STEP_PATH/certs"
    CLIENT_CERT="$HOME_STEP_PATH/certs/$HOSTDOMAIN.crt"
    CLIENT_KEY="$HOME_STEP_PATH/secrets/$HOSTDOMAIN.key"
    GET_CERTS="step ca certificate ${HOSTDOMAIN} ${CLIENT_CERT} ${CLIENT_KEY}"

    shift
    if [[ $# -eq 0 ]]; then
        $GET_CERTS || exit 1
    else
        [ -z "$1" ] && echo "Invalid TOKEN" >&2 && exit 1
        $GET_CERTS --provisioner "token-admin" --token $1 || exit 1
    fi
}

deploy_worker() {
    FINGERPRINT=$(step certificate fingerprint "${WORKER_PATH}/certs/root_ca.crt" || exit 1)
    python3 "${WORKER_PATH}/deploy.py" \
        --name "${ORG_NAME}" \
        --fingerprint "${FINGERPRINT}" \
        --ca-url "${STEP_CA_URL}" \
        --root-ca "${WORKER_PATH}/certs/root_ca.crt" \
        --worker "stepca" \
        --location "${WORKER_PATH}/build/index.js"
}

follow_service() {
    shift
    [[ $# -eq 0 ]] && show_help && exit 1
    case "$1" in
        ca)         journalctl -f -u step-ca;;
        server)     journalctl -f -u https-server;;
        mtls)       journalctl -f -u https-mtls;;
        syslog)     tail -f /var/log/syslog;;
        *)          echo "Error: Invalid service name" >&2 && exit 1;;
    esac
}

main() {
    case "$1" in
        install)        install_stepca;;
        uninstall)      uninstall_stepca;;
        service)        install_service "$@";;
        bootstrap)      stepca_bootstrap "$@";;
        server)         run_server "$@";;
        certbot)        run_certbot;;
        certificate)    get_client_certificate "$@";;
        start)          start_ca;;
        init)           init_ca;;
        deploy)         deploy_worker;;
        follow)         follow_service "$@";;
        commands)       bootstrap_commands;;
        help)           show_help && exit 0;;
        *)              echo "Invalid command" && exit 1;;
    esac
}

[[ $# -eq 0 ]] && show_help || main $@
