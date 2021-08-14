#!/usr/bin/env bash

ORG_NAME="Step CA Tutorial"
STEPCA_DOMAIN="stepca.local"

require_sudo() {
    if [[ "$EUID" -ne 0 ]]; then
        echo "PERMISSION DEINED: Require root access."
        exit 1
    fi
}

show_help() {
    cat << EOF
Usage: runstep <command>
Commands:
        install                 Install Step CA **
        uninstall               Uninstall Step CA **
        start                   Start Step CA server
        init                    Initialise Step CA
        bootstrap               Bootstrap Step CA
        follow                  Follow Step CA server log
        creds [STEP PATH]       show credentials of CA ** (default path=/etc/step-ca)
        service <CMD>           Manage Step CA service **

Service commands:
        install         Install Step CA Service
        *               All service commands accepted by systemctl

[ ** - Require root access ]
EOF
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
    wget -O ${TEMP_PATH}/step-cli_${CLI_VER}_amd64.deb "${GITHUB_URL}/${CLI_REPO}/releases/download/v${CLI_VER}/step-cli_${CLI_VER}_amd64.deb"

    # Download step-ca if not downloaded
    [ ! -f "${TEMP_PATH}/step-ca_${CA_VER}_amd64.deb" ] && \
    wget -O ${TEMP_PATH}/step-ca_${CA_VER}_amd64.deb "${GITHUB_URL}/${CA_REPO}/releases/download/v${CA_VER}/step-ca_${CA_VER}_amd64.deb"

    # Install deb packages
    dpkg -i ${TEMP_PATH}/step-cli_${CLI_VER}_amd64.deb
    dpkg -i ${TEMP_PATH}/step-ca_${CA_VER}_amd64.deb

}

install_service() {

    check_network
    require_sudo

    shift
    if [[ "$1" == "install" ]]; then
        # STEP CA Preparation
        OLD_STEP_PATH="/home/ubuntu/.step"
        STEP_PATH="/etc/step-ca"
        STEP_CA_LOG="/var/log/step-ca"

        #Check for password
        [[ ! -f "${OLD_STEP_PATH}/secrets/password.txt" ]] && \
        echo "Password file not found" && exit 1

        # Create new step user
        useradd --system --home $STEP_PATH --shell /bin/false step

        # Enable step-ca to bind ports lower than 1024
        setcap CAP_NET_BIND_SERVICE=+eip $(which step-ca)

        mv $OLD_STEP_PATH $STEP_PATH
        sed -i 's/home\/ubuntu\/\.step/etc\/step-ca/g' $STEP_PATH/config/ca.json
        sed -i 's/home\/ubuntu\/\.step/etc\/step-ca/g' $STEP_PATH/config/defaults.json
        mkdir -p "${STEP_PATH}/db"
        chown -R step:step $STEP_PATH

        systemctl daemon-reload
        systemctl enable --now step-ca

    elif [[ "$1" == "" ]]; then
        systemctl status step-ca
    else
        systemctl "$1" step-ca
    fi
}

stepca_bootstrap() {

    check_network

    STEP_PATH=$(step path)
    ROOT_CRT_PATH="${STEP_PATH}/certs/root_ca.crt"
    STEP_CA_URL="https://${STEPCA_DOMAIN}"
    PARAMS=""
    FINGERPRINT=""

    shift
    [ -n "$1" ] && [ ${1:0:1} != "-" ] && FINGERPRINT=$1 || \
    (echo "Error: Fingerprint is missing" && exit 1)
    shift
    step ca bootstrap --ca-url $STEP_CA_URL -f --install --fingerprint $FINGERPRINT || exit 1
    
    if [[ $# -gt 0 ]]; then
        case "$1" in
            -c|--certbot)
                sudo snap install certbot --classic && \
                sudo REQUESTS_CA_BUNDLE=$ROOT_CRT_PATH \
                certbot certonly -n --standalone \
                    --agree-tos --email "admin@${STEP_CA_URL}" -d subscriber.local \
                    --server "${STEP_CA_URL}/acme/acme/directory" || exit 1
                exit 0
                ;;
            *)
                echo "Error: Unsupported flag $1" >&2
                exit 1
                ;;
        esac
    fi
}

show_creds() {

    [[ $# -eq 0 ]] && require_sudo

    STEP_PATH="${1:-\/etc\/step-ca}"
    PASSWORD=$(cat ${STEP_PATH}/secrets/password.txt)
    FINGERPRINT=$(step certificate fingerprint "${STEP_PATH}/certs/root_ca.crt")
    cat <<CREDS
Password is ${PASSWORD}
Use the following command to bootstrap

runstep bootstrap ${FINGERPRINT}

CREDS
}

init_ca() {

    check_network

    STEP_PATH=$(step path)
    PASSWORD_FILE="${STEP_PATH}/secrets/password.txt"
    IP_ADDR=$(hostname -I | xargs)
    PROVISIONER="tokenizer"
    LISTEN=":443"

    if [ ! -f "${PASSWORD_FILE}" ]; then

        # Password generation
        mkdir -p "${STEP_PATH}/secrets"
        if type "openssl" > /dev/null 2>&1; then
            openssl rand -base64 24 > $PASSWORD_FILE
        elif type "gpg" > /dev/null 2>&1; then
            gpg --gen-random --armor 1 24 > $PASSWORD_FILE
        else
            echo "Need OpenSSL or GPG to genereate password"
        fi

        step ca init --ssh \
            --name $ORG_NAME \
            --provisioner $PROVISIONER \
            --dns $STEPCA_DOMAIN \
            --address $LISTEN \
            --password-file $PASSWORD_FILE \
            --provisioner-password-file $PASSWORD_FILE

        step ca provisioner add acme --type ACME

    fi

    tree "${STEP_PATH}"
    show_creds "${STEP_PATH}"
    echo "You CA link is https://${STEPCA_DOMAIN} or https://${IP_ADDR}"
}

uninstall_stepca() {
    
    check_network
    require_sudo

    dpkg -r step-cli step-ca
    deluser step sudo
    userdel --remove step
    rm -rf /var/log/step-ca/* /home/step/.step/ /tmp/step /etc/step-ca
}

add_completion() {
    echo "complete -W 'install uninstall service bootstrap start init follow creds help' runstep" >> /home/ubuntu/.bash_completion
}

start_ca() {
    STEP_PATH=$(step path)
    STEPCA=$(which step-ca)
    $STEPCA $STEP_PATH/config/ca.json --password-file $STEP_PATH/secrets/password.txt
}

main() {
    case "$1" in
        install)        install_stepca;;
        uninstall)      uninstall_stepca;;
        service)        install_service "$@";;
        bootstrap)      stepca_bootstrap "$@";;
        completion)     add_completion;;
        start)          start_ca;;
        init)           init_ca;;
        follow)         journalctl -f -u step-ca;;
        creds)          show_creds;;
        help)           show_help && exit 0;;
        *)              echo "Invalid command" && exit 1;;
    esac
}

[[ $# -eq 0 ]] && show_help || main $@
