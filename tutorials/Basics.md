# Root CA Configuration

### Prepare for generating CA

```
sudo bash service/install.sh
su - step
```

### Generate password file

```
sudo bash scripts/password.sh
```

### Generate CA

```
step ca init --name "Tutorial CA" --provisioner admin \
  --dns localhost --address ":443" \
  --password-file /home/step/.step/password \
  --provisioner-password-file /home/step/.step/password \
  --ssh
```
### Run CA

```
step-ca $(step path)/config/ca.json --password-file /home/step/.step/password
```
or
```
sudo bash service/start.sh
```