#!/bin/bash
function create_disk {

    local _NAME=${1:-NAME}
    local _DISK=${2:-DISK}
    local _POOL=${3:-POOL}

    echo "Creating storage..."
    echo -e "Name: \"${_NAME}\"\nSize: ${_DISK}"

    virsh vol-create-as --name $_NAME.qcow2 --capacity $_DISK --format qcow2 --allocation $_DISK --pool ${_POOL}
}

function setup_network {


    local _NAME=${1:-NAME}
    local _VLAN=${2:-VLAN}

    echo "Setup network..."
    echo -e "Name: \"${_NAME}\"\nVLAN ID: ${_VLAN}"

    virsh dumpxml ${_NAME} > ${_NAME}.xml
	sed "0,/network='internal'\\/>/s//network='internal' portgroup='vlan-${_VLAN}'\\/>/" -i ${_NAME}.xml
	virsh define ${_NAME}.xml
    rm -f ${_NAME}.xml
}


function setup_iso {

    local _NAME=${1:-NAME}
    local _GW=${2:-GATEWAY_IP}
	local _TMPD=$(mktemp -d)
    local _IMAGE_PATH=${IMAGE_PATH:-"/var/lib/libvirt/images"}

    echo "Setup ISO..."

    modprobe nbd max_part=63
	qemu-nbd -n -c /dev/nbd0 ${_IMAGE_PATH}/${_NAME}.qcow2
	vgscan --mknode
	vgchange -ay os
	mount /dev/os/root ${_TMPD}
	sed "s/GATEWAY=.*/GATEWAY=\"${_GW}\"/g" -i ${_TMPD}/etc/sysconfig/network
    #Fuel 6.1 displays network setup menu by default
    sed -i 's/showmenu=yes/showmenu=no/g' ${TMPD}/root/.showfuelmenu
    echo "
DEVICE=eth1
TYPE=Ethernet
ONBOOT=yes
NM_CONTROLLED=no
BOOTPROTO=dhcp
PEERDNS=no" > ${_TMPD}/etc/sysconfig/network-scripts/ifcfg-eth1
    umount ${_TMPD}
	vgchange -an os
	qemu-nbd -d /dev/nbd0
}
