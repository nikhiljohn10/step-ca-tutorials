
if ! type multipass > /dev/null 2>&1; then
    echo "Multipass is not installed"
    exit 1
fi

VM_NAME=${1:-steptest}
MULTIPASS=$(which multipass)
NET_FILE="/etc/netplan/50-cloud-init.yaml"

if ! $MULTIPASS ls --format csv | grep $VM_NAME > /dev/null 2>&1; then

    $MULTIPASS launch -v -n $VM_NAME
    echo "A new virtual machine called $VM_NAME is created"

    echo "Setting up network in $VM_NAME"
    $MULTIPASS exec $VM_NAME -- sudo sed -i '$ i\
            nameservers:\
                addresses: [1.1.1.1, 8.8.8.8]' $NET_FILE
    $MULTIPASS exec $VM_NAME -- sudo netplan apply
    echo "Network is setup"

    $MULTIPASS transfer scripts/install.sh $VM_NAME:install
    $MULTIPASS transfer scripts/uninstall.sh $VM_NAME:uninstall
    $MULTIPASS transfer scripts/start.sh $VM_NAME:start

    # echo "Updating ubuntu"
    # $MULTIPASS exec $VM_NAME -- sudo apt update && echo "Ubuntu is updated"
    # echo "Upgrading ubuntu"
    # $MULTIPASS exec $VM_NAME -- sudo apt upgrade -y && echo "Ubuntu is upgraded"

fi

$MULTIPASS shell $VM_NAME
