#!/bin/bash

source functions.sh
source bash_arg_parser/arg_parser.sh

CONF='
    {
     "NAME":
       {
        "name":"name",
        "short":"n",
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
     "XML":
       {
        "name":"xml",
        "short":"x",
        "default": "ubuntu1404.xml",
        "required": "True",
        "help": "XML configuration for VM"
       }
    }'

arg_parser "${CONF}" "$*" bash_arg_parser

IMAGE_PATH=$(virsh pool-dumpxml ${POOL} | awk -F "[><]" '/path/ {print($3)}')
IMAGE_PATH=${IMAGE_PATH:-"/var/lib/libvirt/images"}

virsh destroy ${NAME}
virsh undefine ${NAME}
virsh vol-delete --pool ${POOL} ${IMAGE_PATH}/${NAME}.qcow2

sed -e "s/%name/${NAME}.qcow2/g" -e "s/%size/${DISK}/g" ${XML} > "/tmp/${NAME}.xml"
virsh vol-create  --pool ${POOL} "/tmp/${NAME}.xml"

virt-install \
  --name=${NAME} \
  --cpu host \
  --ram=${RAM} \
  --vcpus=${CPU},cores=${CPU} \
  --os-type=linux \
  --os-variant=rhel6 \
  --virt-type=kvm \
  --boot=hd \
  --disk "${IMAGE_PATH}/${NAME}.qcow2" \
  --noautoconsole \
  --network network=internal,model=virtio \
  --graphics vnc,listen=0.0.0.0

