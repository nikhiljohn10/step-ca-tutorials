# Installation

## Ubuntu/Debian

```
git clone https://github.com/nikhiljohn10/step-ca-tutorials
cd step-ca-tutorials
bash vm/ca.sh
bash vm/sub.sh
bash vm/client.sh
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