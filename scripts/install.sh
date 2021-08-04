if [[ "$EUID" -ne 0 ]]; then
  echo "The script need to be run as root..."
  exit 1
fi

CLI_URL="https://api.github.com/repos/smallstep/cli"
CA_URL="https://api.github.com/repos/smallstep/certificates"
CLI_VER=$(curl -s ${CLI_URL}/releases/latest | grep tag_name | sed 's/[(tag_name)"v:,[:space:]]//g')
CA_VER=$(curl -s ${CA_URL}/releases/latest | grep tag_name | sed 's/[(tag_name)"v:,[:space:]]//g')
CLI_TAG="v${CLI_VER}"
CA_TAG="v${CA_VER}"

mkdir -p /tmp/step

if ! [ -f "/tmp/step/step-cli_${CLI_VER}_amd64.deb" ]; then
  wget -O /tmp/step/step-cli_${CLI_VER}_amd64.deb https://github.com/smallstep/cli/releases/download/${CLI_TAG}/step-cli_${CLI_VER}_amd64.deb
fi

if ! [ -f "/tmp/step/step-ca_${CA_VER}_amd64.deb" ]; then
  wget -O /tmp/step/step-ca_${CA_VER}_amd64.deb https://github.com/smallstep/certificates/releases/download/${CA_TAG}/step-ca_${CA_VER}_amd64.deb
fi

dpkg -i /tmp/step/step-cli_${CLI_VER}_amd64.deb || dpkg -r step-cli
dpkg -i /tmp/step/step-ca_${CA_VER}_amd64.deb || dpkg -r step-ca
