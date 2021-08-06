
STEP_PATH=$(step path)
PASSWORD_FILE="${STEP_PATH}/secrets/password.txt"

# Password generation
mkdir -p "${STEP_PATH}/secrets"
if type "openssl" > /dev/null 2>&1; then
  openssl rand -base64 24 > $PASSWORD_FILE
elif type "gpg" > /dev/null 2>&1; then
  gpg --gen-random --armor 1 24 > $PASSWORD_FILE
else
  echo "Need OpenSSL or GPG to genereate password"
fi

step ca init \
  --password-file $PASSWORD_FILE \
  --provisioner-password-file $PASSWORD_FILE

echo "Password is in ${PASSWORD_FILE}"