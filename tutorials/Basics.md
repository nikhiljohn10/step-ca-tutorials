# Basics

```
su -
useradd -r -m -U step -s /usr/sbin/nologin
passwd step
mkdir -p /var/log/step-ca
chown -R step:step /var/log/step-ca
su - step
step ca init \
  --name "Home CA" \
  --password-file=/home/step/password \
  --provisioner-password-file=/home/step/provider-password \
  --ssh
step-ca $(step path)/config/ca.json
```

Create `/etc/systemd/system/step-ca.service` file with following content:
```
[Unit]
Description=step-ca
After=syslog.target network.target

[Service]
User=step
Group=step
ExecStart=/bin/sh -c '/bin/step-ca /home/step/.step/config/ca.json --password-file=/home/step/password >> /var/log/step-ca/output.log 2>&1'
Type=simple
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```