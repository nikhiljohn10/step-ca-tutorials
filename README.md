# Step CA Tutorials

An automated demo for Step CA using Multipass

(Docker & K8 demo coming soon)

## Multipass Installation

**Ubuntu**
```
sudo snap install multipass
```

**MacOS**
```
brew install --cask multipass
```

For other methods of installations, follow this [link](https://multipass.run/)

### Tutorial

```
git clone https://github.com/nikhiljohn10/step-ca-tutorials
cd step-ca-tutorials
```

Use `./vm.sh help` for command help

## Using runstep

`runstep` command is custom built for this tutorial to demo the working of step-ca.

```
Usage: runstep <command>
Commands:
        install                         Install Step CA **
        uninstall                       Uninstall Step CA **
        init                            Initialise Step CA
        service [COMMAND]               Manage Step CA service ** (Show status if no commands found)
        follow                          Follow Step CA server log
        start                           Start Step CA server
        commands [STEP PATH]            Show credentials of CA ** (default path=/etc/step-ca)
        bootstrap FINGERPRINT [-c]      Bootstrap Step CA inside a client
        server [-m] [-p|--port PORT]    Run https server with optional mTLS **
        server COMMAND                  Manage https server service using systemctl commands **
        certbot                         Run certbot and obtain client certificate from stepca **
        certificate                     Generate client certificate

Service commands: install, start, stop, enable [--now], disable [--now], restart, status 

[ ** - Require root access ]
```

`runstep` can manage the lifecycle of step-ca using inner shortcut commands.

When the `step-ca.service` is installed, the step-ca path is moved from user's home directory to `/etc/step-ca/`.

**Note: Do not run `runstep init` with root previlages**

## Step by Step by Step

### Terminals

#### 1. `./vm.sh ca`

`ubuntu@stepca` : Contains Step CA PKI

   1. Verify network, dependencies & instance existance
   2. Multipass generate ubuntu instance using cloud init configuration from `/configs/ca.yaml`
   3. Install `runstep` command inside the instance
   4. Install `step-ca` and `step-cli` inside the instance
   5. Generate passwords
   6. Generate PKI
   7. Add `acme` provisioner of type `ACME`
   8. Move the PKI files to `/etc/step-ca`
   9. Install, enable & start `step-ca` server as service
   10. Display bootstrapping commands

#### 2. `./vm.sh server`

`ubuntu@website`: Contain https server which subscribe to the CA

   1. Verify network, dependencies & instance existance
   2. Multipass generate ubuntu instance using cloud init configuration from `/configs/server.yaml`
   3. Install `runstep` command inside the instance
   4. Install `step-ca` and `step-cli` inside the instance
   5. Install, enable `https-server` as service
   6. Load instance shell

#### 3. `./vm.sh client` - to create vm for Client user to access webserver using Step CA Root & Client certificates. (`ubuntu@home`)

`ubuntu@home` : Uses `curl` command with client and root certificates to connect with https server 

   1. Verify network, dependencies & instance existance
   2. Multipass generate ubuntu instance using cloud init configuration from `/configs/client.yaml`
   3. Install `runstep` command inside the instance
   4. Install `step-ca` and `step-cli` inside the instance
   5. Load instance shell

Ubuntu 20.04 LTS is the default image used by multipass. For boostrapping, you can use Password tokens or ACME service. By default, certbot is used to subscriber to ACME service in `ubuntu@stepca`.

### Bootstrapping

```
runstep bootstrap FINGERPRINT
```
This will fetch & install CA root certificate from `ubuntu@stepca`.

```
sudo runstep certbot
```
Get new client certificate and private key using `certbot` on the first run. Once certificates are obtained, futher execution of this command will renew the existing certificates.

### Webserver

This command will start a new https server
```
sudo runstep server [-m|--mtls] [-p|--port PORT]
```

- With `-m` or `--mtls` options, the client will have to request server along with client certificates to allow mutual authentication. By default, https-server does not use mTLS.

- With `-p PORT` or `--port PORT` option, https server start listening in given port number. Default is `443`.

Pre-installed https server listen on port `443` without using mTLS. To manage pre-installed https server in use following format: 
```
sudo runstep server COMMAND
```

Available service commands are `start`, `stop`, `enable`, `disable`, `restart`.

To run additional https server, use following command:
```
sudo runstep server -m -p 8443
```

### Client

After bootstrapping, you can use the following commands depending on the type of authentication.

Normal TLS:
```
curl https://website.local
```

Mutual TLS:
```
curl https://website.local:8443 --cert $(step path)/certs/home.local.crt --key $(step path)/secrets/home.local.key
```

**NOTE: You need to pass `--cacert` if root certificate is not installed. But by default, root certificate in installed while bootstrapping.**

### Alternative to certbot

To obtain client certificate for `ubuntu@home`, you can use the following command.
```
runstep certificate
```

You have to choose jwk token method. It will ask for a password. You can copy paste the password from `ubuntu@stepca`.

You can use the following command to display the bootstrapping process.
```
sudo runstep commands
```

## Limitation

- Not compatible with Windows or WSL
- DNS Issue in Ubuntu can be resolved by running `bash utils/netfix_ubuntu.sh` on host system
