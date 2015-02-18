# VMs - global variable

VMs=

function parse-args {
    PREFIX=${1?"Prefix is mandatory for this command. Use --help for more details."}
    VMs=$(virsh list | grep $PREFIX | awk '{print $2}')
    VMs=${VMs:?"No one VM with this prefix: '${PREFIX}'"}
}

function snapshot-list {
    local VMs=$1

    for VM in $VMs; do
        echo "$VM"
        virsh snapshot-list $VM
    done
}

function snapshot-create {
    local VMs=$1
    local SNAPSHOT=$2

    for VM in $VMs; do
        echo "$VM"
        virsh suspend $VM
        virsh snapshot-create-as $VM $SNAPSHOT
        virsh resume $VM
    done
}

function snapshot-delete {
    local VMs=$1
    local SNAPSHOT=$2

    for VM in $VMs; do
        echo "$VM"
        virsh snapshot-delete $VM $SNAPSHOT
    done
}

function snapshot-revert {
    local VMs=$1
    local SNAPSHOT=$2

    for VM in $VMs; do
        echo "$VM"
        virsh destroy $VM
        virsh snapshot-revert $VM $SNAPSHOT
        virsh start $VM
    done
}
