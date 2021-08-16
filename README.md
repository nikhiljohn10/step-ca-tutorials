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

`runstep` command is custom built for this tutorial to demo the working of step-ca. With `-c` or `--step-ca` options of `vm.sh`, this command is installed inside the newly created virtual machine.

```
Usage: runstep <command>
Commands:
        install                         Install Step CA **
        uninstall                       Uninstall Step CA **
        start                           Start Step CA server
        init                            Initialise Step CA
        bootstrap FINGERPRINT [-c]      Bootstrap Step CA
        follow                          Follow Step CA server log
        creds [STEP PATH]               Show credentials of CA ** (default path=/etc/step-ca)
        server [-m]                     Start Web server with optional mTLS **
        service [COMMAND]                 Manage Step CA service (Show status if no commands found) **

Service commands: install, start, stop, enable [--now], disable [--now], restart, status 

[ ** - Require root access ]
```

`runstep` can manage the lifecycle of step-ca using inner shortcut commands.

When the `step-ca.service` is installed, the step-ca path is moved from user's home directory to `/etc/step-ca/`.

**Note: Do not run `runstep init` with root previlages**

## Step by Step by Step

### Commands
1. `./vm.sh ca` - to create vm for Step CA PKI (`ubuntu@stepca`)

2. `./vm.sh server` - to create vm for Webserver to subscribe to the Step CA server (`ubuntu@subscriber`)

3. `./vm.sh client` - to create vm for Client user to access webserver using Step CA Root & Client certificates. (`ubuntu@client`)

Ubuntu 20.04 LTS is the default image used by multipass.

The `ubuntu@stepca` vm will run step-ca as service in background. It display bootstrapping commands to be used in `ubuntu@subscriber` & `ubuntu@client`. For boostrapping, you can use Password tokens or ACME service. By default, certbot is used to subscriber to ACME service in `ubuntu@stepca`.

### Bootstrapping

Use the command `runstep bootstrap FINGERPRINT [-c|--certbot]`. This will fetch & install CA root certificate from `ubuntu@stepca`.

**NOTE: certbot option is only required to request client certificates.**

### Webserver

Run `sudo runstep server [-m|--mtls]` command to start a webserver. With `-m` or `--mtls` options, the client will have to request server along with client certificates to allow mutual authentication.

### Client

After bootstrapping, you can use the following commands depending on the type of authentication.

Normal TLS:
```
# For ubuntu users
curl https://stepca.multipass

# For macOS users
curl https://stepca.local 
```

Mutual TLS:
```
# For ubuntu users
curl --cert client.crt --key client.key https://stepca.multipass

# For macOS users
curl --cert client.crt --key client.key https://stepca.local
```

**NOTE: You need to pass `--cacert` if root certificate is not installed. But by default, root certificate in installed while bootstrapping.**

To obtain client certificate for `ubuntu@client`, you can use the following command.
```
# For ubuntu users
step ca certificate client.multipass client.crt client.key

# For macOS users
step ca certificate client.local client.crt client.key
```

You have to choose jwk token method. It will ask for a password. You can copy paste the password from `ubuntu@stepca`.

## Limitation

- Not compatible with Windows or WSL
- mDNS Issue in MacOS
- DNS Issue in Ubuntu can be resolved by running `bash utils/netfix_ubuntu.sh` on host system
