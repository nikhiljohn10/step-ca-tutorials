#!/usr/bin/env bash

STEP_PATH=$(step path)
ROOT_CRT_PATH="${STEP_PATH}/certs/root_ca.crt"
STEP_CA_URL="https://stepca.multipass"
PARAMS=""

while (( "$#" )); do
    case "$1" in
        -c|--certbot)
            sudo snap install certbot --classic && \
            sudo REQUESTS_CA_BUNDLE=$ROOT_CRT_PATH \
            certbot certonly -n --standalone \
                --agree-tos --email "admin@${STEP_CA_URL}" -d stepsub.multipass \
                --server "${STEP_CA_URL}/acme/acme/directory" || exit 1
            exit 0
            ;;
        -f|--fingerprint)
            if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
                step ca bootstrap --ca-url $STEP_CA_URL -f --install --fingerprint $2
                shift 2
            else
                echo "Error: Fingerprint is missing" >&2
                exit 1
            fi
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