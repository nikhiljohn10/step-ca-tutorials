#!/usr/bin/env zsh

/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
brew install dnsmasq

mkdir -pv $(brew —- prefix)/etc/
echo 'server=/.multipass/127.0.0.1' >> $(brew --prefix)/etc/dnsmasq.conf

sudo brew services start dnsmasq
sudo mkdir -v /etc/resolver
sudo bash -c 'echo "nameserver 127.0.0.1" > /etc/resolver/multipass'

# sudo brew services restart dnsmasq

# sudo brew services stop dnsmasq
# rm -f /usr/local/etc/dnsmasq.conf
# sudo rm -rf /etc/resolver
# brew uninstall --force dnsmasq

# sudo rm -rf /usr/local/Cellar/dnsmasq/2.85/sbin \
# /usr/local/Cellar/dnsmasq/2.85/sbin/dnsmasq \
# /usr/local/opt/dnsmasq \
# /usr/local/opt/dnsmasq/sbin \
# /usr/local/var/homebrew/linked/dnsmasq
