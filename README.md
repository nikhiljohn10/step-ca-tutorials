# Step CA Tutorials

An automated demo for Step CA using Multipass

(Docker & K8 demo coming soon)

## Installation

### Multipass

**Ubuntu**
```
sudo snap install multipass
```

**macOS**
```
brew install --cask multipass
```

For other methods of installations, follow this [link](https://multipass.run/)

### Tutorial

```
git clone https://github.com/nikhiljohn10/step-ca-tutorials
cd step-ca-tutorials
```

Use `vm.sh` script to manage virtual ubuntu instance via multipass.

```
Usage: ./vm.sh <INSTANCE|KEYWORD> [OPTIONS]
Options:
         -u,--upgrade    Update and upgrade packages inside ubuntu instance
         -f,--force      Force a new instance to start
         -d,--delete     Delete the instance

Keywords: ca, server, client, help, reset
If none of keywords given, it creates a generic instance with name INSTANCE
```

Use `./vm.sh help` to display command help.
Use `./vm.sh reset` to delete all instance and purge them. (**Use this option with care if you have other instances running in multipass.**)

## Step by Step by Step

Run the following 3 commands in 3 different terminals. The last two commands are only for testing the Certificate Authority.

### 1. `./vm.sh ca`

`ubuntu@stepca` : Contains Step CA PKI

   1. Verify network, dependencies & instance existence
   2. Multipass generate ubuntu instance using cloud-init configuration from `/configs/ca.yaml`
   3. Install `runstep` command inside the instance
   4. Install `step-ca` and `step-cli` inside the instance
   5. Generate passwords
   6. Generate PKI
   7. Add `acme` provisioner of type `ACME`
   8. Move the PKI files to `/etc/step-ca`
   9. Install, enable & start `step-ca` server as a service
   10. Display bootstrapping commands

### 2. `./vm.sh server`

`ubuntu@website` : Contain HTTPS server which subscribes to the CA

   1. Verify network, dependencies & instance existence
   2. Multipass generate ubuntu instance using cloud-init configuration from `/configs/server.yaml`
   3. Install `runstep` command inside the instance
   4. Install `step-ca` and `step-cli` inside the instance
   5. Install, enable `https-server` as a service

### 3. `./vm.sh client`

`ubuntu@home` : Uses `curl` command with the client and root certificates to connect with an HTTPS server 

   1. Verify network, dependencies & instance existence
   2. Multipass generate ubuntu instance using cloud-init configuration from `/configs/client.yaml`
   3. Install `runstep` command inside the instance
   4. Install `step-ca` and `step-cli` inside the instance

Ubuntu 20.04 LTS is the default image used by multipass. For bootstrapping, you can use Password tokens or ACME service. By default, certbot is used to subscribe to ACME service in `ubuntu@stepca`.

All the bootstrapping commands required by the webserver and client will be displayed in `ubuntu@stepca` after the instance configuration is complete.

To load the shell of corresponding instance, run the same command again. To refresh the instance, pass `-f` or `--force` parameter after the command. This will delete, purge and start the instance fresh.

### Testing

```
./test.sh
```
This command will run 2 major test which uses the above 3 commands followed by bootstrapping commands.

**Tests:**

   1. HTTPS Request without mTLS
   2. HTTPS Request with mTLS

---
> *Note: The following commands are only for reference.*

## Using runstep command

`runstep` command is custom-built for this tutorial to demo the working of step-ca.

```
Usage: runstep <command>
Commands:
        install                         Install Step CA **
        uninstall                       Uninstall Step CA **
        init                            Initialise Step CA
        service [COMMAND]               Manage Step CA service ** (Show status if no commands found)
        follow [KEYWORD]                Follow a service log 
        start                           Start Step CA server
        commands [STEP PATH]            Show credentials of CA ** (default path=$ROOT_STEP_PATH)
        bootstrap FINGERPRINT [-c]      Bootstrap Step CA inside a client
        server [-m] [-p|--port PORT]    Run HTTPS server with optional mTLS **
        server COMMAND                  Manage HTTPS server service using systemctl commands **
        certbot                         Run certbot and obtain client certificate from stepca **
        certificate                     Generate a client certificate

Service commands:  install, start, stop, enable [--now], disable [--now], restart, status 
Follow keywords:   ca (Step CA server), server (HTTPS WebServer), mtls (HTTPS Server with mTLS), syslog (System Logs)

[ ** - Require root access ]
```

`runstep` can manage the lifecycle of step-ca using inner shortcut commands.

When the `step-ca.service` is installed, the step-ca path is moved from the user's home directory to `/etc/step-ca/`.

**Note: Do not run `init`, `bootstrap`, `start`, `certificate` & `follow` commands with root privileges**

### Bootstrapping

```
runstep bootstrap FINGERPRINT
```
This will fetch & install the CA root certificate from `ubuntu@stepca`.

```
sudo runstep certbot
```
Get a new client certificate and private key using `certbot` on the first run. Once certificates are obtained, certbot will renew the certificate every 12 hours automatically and restart the webserver if the `https-server` service exists.

### Webserver

This command will start a new HTTPS server
```
sudo runstep server [-m|--mtls] [-p|--port PORT]
```

- With `-m` or `--mtls` options, the client will have to request the server along with client certificates to allow mutual authentication. By default, https-server does not use mTLS.

- With `-p PORT` or `--port PORT` option, HTTPS server start listening in the given port number. Default is `443`.

Pre-installed HTTPS server listens on port `443` without using mTLS. To manage pre-installed HTTPS server in use following format: 
```
sudo runstep server COMMAND
```

Available service commands are `start`, `stop`, `enable`, `disable`, `restart`.

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

**NOTE: You need to pass `--cacert` if the root certificate is not installed. But by default, the root certificate is installed while bootstrapping.**

### Alternative to certbot

To obtain a client certificate for `ubuntu@home`, you can use the following command.
```
runstep certificate [TOKEN]
```

If no token parameter is provided, you have to choose the token-admin provisioner which uses the jwk token method. It will ask for a provisioner password. You can copy & paste the password from the terminal of `ubuntu@stepca` instance.

You can use the following command to display the bootstrapping process.
```
sudo runstep commands
```

**Note: Refer `test.sh` to understand how to use `certificate` command with the one-time token. Password is not required when the token parameter is given.**

## Limitation

- Not compatible with Windows or WSL
- DNS Issue in Ubuntu can be resolved by running `bash utils/netfix_ubuntu.sh` on the host system

## Credits

This project is completed with great help from various communities.

- [Michał Sawicz](https://github.com/Saviq) (multipass)
- [Mariano Cano](https://github.com/maraino) (stepca)
