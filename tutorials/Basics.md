# Root CA Configuration

### Prepare for generating CA

```
sudo useradd -r -m -U step -s /bin/bash && sudo passwd -d step
sudo mkdir -p /var/log/step-ca
sudo chown -R step:step /var/log/step-ca
sudo adduser step sudo
sudo setcap CAP_NET_BIND_SERVICE=+eip $(which step-ca)
su - step
```

### Generate password file

```
openssl rand -base64 15 > /home/step/password.txt
```
or
```
gpg --gen-random --armor 1 15 > /home/step/password.txt
```
or
```
date +%s | sha256sum | base64 | head -c 15 > /home/step/password.txt
```

### Generate CA

```
step ca init --name "Happy Home CA" --provisioner admin \
  --dns localhost --address ":443" \
  --password-file /home/step/password.txt \
  --provisioner-password-file /home/step/password.txt \
  --ssh
```
### Run CA

```
step-ca $(step path)/config/ca.json --password-file /home/step/password.txt
```

### Service

```
sudo nano /etc/systemd/system/step-ca.service
sudo systemctl daemon-reload
sudo systemctl status step-ca
sudo systemctl enable --now step-ca
sudo journalctl --follow --unit=step-ca
```

Copy paste following content in to the text editor:
```toml
[Unit]
Description=step-ca service
After=syslog.target network.target
Wants=network-online.target
StartLimitIntervalSec=30
StartLimitBurst=3
ConditionFileNotEmpty=/home/step/.step/config/ca.json
ConditionFileNotEmpty=/home/step/password.txt

[Service]
User=step
Group=step
Environment=STEPPATH=/home/step/.step/
WorkingDirectory=/home/step/.step/
ExecStart=/bin/step-ca /home/step/.step/config/ca.json --password-file=/home/step/password.txt >> /var/log/step-ca/output.log 2>&1
ExecReload=/bin/kill --signal HUP $MAINPID
Type=simple
Restart=on-failure
RestartSec=5
TimeoutStopSec=30
StartLimitInterval=30
StartLimitBurst=3

AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
SecureBits=keep-caps
NoNewPrivileges=yes

ProtectSystem=full
ProtectHome=true
RestrictNamespaces=true
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
PrivateTmp=true
PrivateDevices=true
ProtectClock=true
ProtectControlGroups=true
ProtectKernelTunables=true
ProtectKernelLogs=true
ProtectKernelModules=true
LockPersonality=true
RestrictSUIDSGID=true
RemoveIPC=true
RestrictRealtime=true
SystemCallFilter=@system-service
SystemCallArchitectures=native
MemoryDenyWriteExecute=true
ReadWriteDirectories=/home/step/.step/db

[Install]
WantedBy=multi-user.target
```

### Clean up
```
sudo rm -rf /var/log/step-ca
sudo userdel --remove step
```
