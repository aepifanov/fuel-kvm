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
        "default": "4",
        "required": "True",
        "help": "CPU Number for VM"
       },
     "RAM":
       {
        "name":"ram",
        "short":"r",
        "default": "8192",
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
     "ISO":
       {
        "name":"iso",
        "short":"i",
        "default": "fuel.iso",
        "reuired": "True",
        "help": "Path to FUEL ISO file"
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

NAME=${PREFIX}-${PXE_VLAN}-fuel

if [[ ! -f ${ISO} ]]
then
    echo "ISO file \"${ISO}\" does not exist!"
    echo "Terminating..."
    exit 1
fi

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


### Start creating


create_disk ${NAME} ${DISK} ${POOL}

echo "Starting Fuel master vm..."

virt-install \
  --name=${NAME} \
  --cpu host \
  --ram=${RAM} \
  --vcpus=${CPU},cores=${CPU} \
  --os-type=linux \
  --os-variant=rhel6 \
  --virt-type=kvm \
  --disk "${IMAGE_PATH}/${NAME}.qcow2" \
  --cdrom "${ISO}" \
  --noautoconsole \
  --network network=internal,model=virtio \
  --network network=internal,model=virtio \
  --graphics vnc,listen=0.0.0.0

GATEWAY_IP=172.18.161.1

while (true)
do
    STATUS=$(virsh dominfo ${NAME} | grep State | awk -F " " '{print $2}')
    if [ ${STATUS} == 'shut' ]
    then
        setup_iso ${NAME} ${GATEWAY_IP}
        setup_network ${NAME} ${PXE_VLAN}
        virsh start ${NAME}
        break
    fi

    sleep 10
done

echo "Running Fuel master deployment..."

