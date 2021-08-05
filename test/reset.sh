
if ! type multipass > /dev/null 2>&1; then
    echo "Multipass is not installed"
    exit 1
fi

VM_NAME=${1:-steptest}
MULTIPASS=$(which multipass)

($MULTIPASS delete $VM_NAME && $MULTIPASS purge) && \
echo "Successfully remove $VM_NAME" || echo "Nothing to remove"