CLI_VER=$(curl -s https://api.github.com/repos/smallstep/cli/releases/latest | grep tag_name | sed 's/[(tag_name)"v:,[:space:]]//g')
CA_VER=$(curl -s https://api.github.com/repos/smallstep/certificates/releases/latest | grep tag_name | sed 's/[(tag_name)"v:,[:space:]]//g')
wget https://github.com/smallstep/certificates/releases/download/v${CA_VER}/step-ca_${CA_VER}_amd64.deb https://github.com/smallstep/cli/releases/download/v${CLI_VER}/step-ca_${CLI_VER}_amd64.deb
sudo dpkg -i step-cli_${CLI_VER}_amd64.deb
sudo dpkg -i step-ca_${CA_VER}_amd64.deb