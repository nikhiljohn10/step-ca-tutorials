if [[ "$EUID" -ne 0 ]]; then
  echo "The script need to be run as root..."
  exit 1
fi

mkdir -p ~/.temp
CLI_VER=$(curl -s https://api.github.com/repos/smallstep/cli/releases/latest | grep tag_name | sed 's/[(tag_name)"v:,[:space:]]//g')
wget -O ~/.temp/step-cli_${CLI_VER}_amd64.deb https://github.com/smallstep/cli/releases/download/v${CLI_VER}/step-cli_${CLI_VER}_amd64.deb
dpkg -i ~/.temp/step-cli_${CLI_VER}_amd64.deb
rm ~/.temp/step-cli_${CLI_VER}_amd64.deb
CA_VER=$(curl -s https://api.github.com/repos/smallstep/certificates/releases/latest | grep tag_name | sed 's/[(tag_name)"v:,[:space:]]//g')
wget -O ~/.temp/step-ca_${CA_VER}_amd64.deb https://github.com/smallstep/certificates/releases/download/v${CA_VER}/step-ca_${CA_VER}_amd64.deb
dpkg -i ~/.temp/step-ca_${CA_VER}_amd64.deb
rm ~/.temp/step-ca_${CA_VER}_amd64.deb