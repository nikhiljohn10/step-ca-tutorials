# Installation

## Ubuntu/Debian

```
sudo bash install
```
or
```
curl -o- https://raw.githubusercontent.com/nikhiljohn10/step-ca-tutorials/main/scripts/install.sh | sudo bash
```

For uninstallation, use the following command:
```
sudo bash uninstall
```
or
```
curl -o- https://raw.githubusercontent.com/nikhiljohn10/step-ca-tutorials/main/scripts/uninstall.sh | sudo bash
```

## Pacman/Arch Linux

```
pacman -S step-cli step-ca
```

## Brew/MacOS

```
brew install step
```

## Kubernetes

```
helm install step-certificates
```

## Alpine Linux

```
apk add step-cli step-certificates
```

## Docker

```
docker pull smallstep/step-ca
docker volume create step
docker run -it -v step:/home/step smallstep/step-ca sh
```

## Limitation

- Not compatible with Windows or WSL