#!/bin/bash

source functions.sh
source bash_arg_parser/arg_parser.sh

CONF='
    {
     "PREFIX":
       {
        "name":"prefix",
        "short":"x",
        "required": "True",
        "help": "VM name"
       },
     "CPU":
       {
        "name":"cpu",
        "short":"c",
        "default": "2",
        "required": "True",
        "help": "CPU Number for VM"
       },
     "RAM":
       {
        "name":"ram",
        "short":"r",
        "default": "4096",
        "required": "True",
        "help": "RAM in MB for VM"
       },
     "DISK":
       {
        "name":"disk",
        "short":"d",
        "default": "40",
        "required": "True",
        "help": "Disk size in GB for VM"
       },
     "POOL":
       {
        "name":"pool",
        "short":"p",
        "default": "big",
        "reuired": "True",
        "help": "Storage pool name. big: HDD or default: SSD"
       },
     "MGMT_VLAN":
       {
        "name":"management_vlan",
        "short":"m",
        "reuired": "True",
        "help": "Management VLAN ID"
       },
     "STRG_VLAN":
       {
        "name":"storage_vlan",
        "short":"s",
        "reuired": "True",
        "help": "Storage VLAN ID"
       },
     "PXE_VLAN":
       {
        "name":"vlan",
        "short":"v",
        "required": "True",
        "help": "PXE VLAN ID"
       }
    }'


arg_parser "${CONF}" "$*" bash_arg_parser


if [[ ${USER} != "root" ]]
then
    echo "This script should be run with root priveleges."
    echo "Terminating..."
    exit 1
fi

MAC=$(python -c 'from virtinst.util import *; print randomMAC(type="qemu")')
MAC_END=$(echo $MAC | awk -F":" '{print $5"-"$6}')
NAME=${PREFIX}-${PXE_VLAN}-mos_$MAC_END

IMAGE_PATH=$(virsh pool-dumpxml ${POOL} | awk -F "[><]" '/path/ {print($3)}')
IMAGE_PATH=${IMAGE_PATH:-"/var/lib/libvirt/images"}

### Confirm parameters

echo
echo "Your parameters are the following:"
echo "           Name: ${NAME}"
echo "            CPU: ${CPU}"
echo "            RAM: ${RAM}"
echo "           DISK: ${DISK}"
echo "       PXE VLAN: ${PXE_VLAN}"
echo "Management VLAN: ${MGMT_VLAN}"
echo "   Storage VLAN: ${STRG_VLAN}"
echo


### Start creating


create_disk ${NAME} ${DISK} ${POOL}

virt-install \
  --name=${NAME} \
  --cpu host \
  --ram=${RAM} \
  --vcpus=${CPU},cores=${CPU} \
  --os-type=linux \
  --os-variant=rhel6 \
  --virt-type=kvm \
  --pxe \
  --boot network,hd \
  --disk "${IMAGE_PATH}/${NAME}.qcow2" \
  --noautoconsole \
  --mac ${MAC} \
  --network network=internal,model=virtio \
  --network network=internal,model=virtio \
  --network network=internal,model=virtio \
  --network network=internal,model=virtio \
  --graphics vnc,listen=0.0.0.0

virsh destroy ${NAME}
setup_network ${NAME} ${PXE_VLAN}
setup_network ${NAME} ${MGMT_VLAN}
setup_network ${NAME} ${STRG_VLAN}

virsh start ${NAME}
echo "Started fuel-slave ${NAME}"

