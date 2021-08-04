
if ! [ "$(whoami)" == "step" ]; then
  echo "Invalid user. Please login as 'step' user."
  exit 1
fi

mkdir -p $HOME/.step/
if type "openssl" > /dev/null 2>&1; then
  openssl rand -base64 24 > $HOME/.step/password.txt
elif type "gpg" > /dev/null 2>&1; then
  gpg --gen-random --armor 1 24 > $HOME/.step/password.txt
else
  echo "Need openssl or GPG to genereate password"
fi