# VMs - global variable

VMs=
ARGS=

function parse-args {
    PREFIX=${1?"Prefix is mandatory for this command. Use --help for more details."}
    shift
    ARGS=$@

    VMs=$(virsh list --all | grep $PREFIX | awk '{print $2}')
    VMs=${VMs:?"No one VM with this prefix: '${PREFIX}'"}
}

function execute {
    CMD=${1?"CMD is mandatory for this command. Use --help for more details."}
    shift

    for VM in $VMs; do
        echo "$VM"
        virsh $CMD $VM $@
    done
}

