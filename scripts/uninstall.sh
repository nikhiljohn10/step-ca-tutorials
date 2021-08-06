if [[ "$EUID" -ne 0 ]]; then
  echo "The script need to be run as root..."
  exit 1
fi

dpkg -r step-cli step-ca
deluser step sudo
userdel --remove step
rm -rf /var/log/step-ca/* /home/step/.step/* /tmp/step