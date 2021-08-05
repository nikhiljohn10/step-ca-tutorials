
if ! type multipass > /dev/null 2>&1; then
    echo "Multipass is not installed"
    exit 1
fi

VM_NAME=${1:-steptest}
MULTIPASS=$(which multipass)
CONFIG_FILE="$(pwd)/test/cloud-config.yaml"

if ! multipass ls --format csv | grep $VM_NAME > /dev/null 2>&1; then
    $MULTIPASS launch -v -n $VM_NAME --cloud-init $CONFIG_FILE
    echo "A new virtual machine called $VM_NAME is created"
    NET_FILE="/etc/netplan/50-cloud-init.yaml"
    echo "Setting up network in $VM_NAME"
    $MULTIPASS exec $VM_NAME -- sudo sed -i '$ i\
            nameservers:\
                addresses: [1.1.1.1, 8.8.8.8]' $NET_FILE
    $MULTIPASS exec $VM_NAME -- sudo netplan apply
    echo "Network is setup"
    echo "Updating ubuntu"
    $MULTIPASS exec $VM_NAME -- sudo apt update && echo "Ubuntu is updated"
    echo "Upgrading ubuntu"
    $MULTIPASS exec $VM_NAME -- sudo apt upgrade -y && echo "Ubuntu is upgraded"
fi

$MULTIPASS shell $VM_NAME
