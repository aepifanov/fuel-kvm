#!/bin/bash

function generate_mac
{
    MAC=$(python -c 'from virtinst.util import *; print randomMAC(type="qemu")')
    MAC_END=$(echo "${MAC}" | awk -F":" '{print $5"-"$6}')
}

function fail_if_not_root
{
    if [[ ${USER} != "root" ]]
    then
        echo "This script should be run with root priveleges."
        echo "Terminating..."
        exit 1
    fi
}


function is_iso_exist
{
    local ISO=${1:?"Please specify ISO image."}
    pwd

    if [[ ! -f ${ISO} ]]
    then
        echo "ISO file \"${ISO}\" does not exist!"
        echo "Terminating..."
        exit 1
    fi
}

function set_image_path
{
    local NAME=${1:?"Please specify Name"}
    local POOL=${2:?"Please specify Pool"}

    IMAGE_PATH=$(virsh pool-dumpxml "${POOL}" | awk -F "[><]" '/path/ {print($3)}')
    IMAGE_PATH=${IMAGE_PATH:-"/var/lib/libvirt/images"}
    IMAGE_PATH="${IMAGE_PATH}/${NAME}.qcow2"
}

function create_volume
{
    local NAME=${1:?"Please specify Name."}
    local DISK=${2:?"Please specify Disk."}
    local POOL=${3:?"Please specify Pool."}

    DISK="${DISK}G"
    echo "Creating storage..."
    echo -e "Name: \"${NAME}\"\nSize: ${DISK}"

    virsh vol-create-as \
        --name       "${NAME}.qcow2" \
        --capacity   "${DISK}" \
        --format     qcow2 \
        --allocation "${DISK}" \
        --pool       "${POOL}"
}

function create_volume_from_img
{
    local NAME=${1:?"Please specify Name."}
    local DISK=${2:?"Please specify Disk."}
    local POOL=${3:?"Please specify Pool."}
    local IMG=${4:?"Please specify Image."}

    DISK="${DISK}"
    echo "Creating storage..."
    echo -e "Name: \"${NAME}\"\nSize: ${DISK}"

    echo "<volume>
  <name>${NAME}.qcow2</name>
  <capacity unit='G'>${DISK}</capacity>
  <allocation>0</allocation>
  <target>
    <format type='qcow2'/>
  </target>
  <backingStore>
    <path>${IMG}</path>
    <format type='qcow2'/>
  </backingStore>
</volume>" > "/tmp/${NAME}.xml"

    virsh vol-create \
        --pool ${POOL} \
        "/tmp/${NAME}.xml"
}

function setup_network {


    local NAME=${1:?"Please specify Name"}
    local VLAN=${2:?"Please specify VLAN"}

    echo "Setup network..."
    echo -e "Name: \"${NAME}\"\nVLAN ID: ${VLAN}"

    virsh dumpxml "${NAME}" > "${NAME}.xml"
	sed "0,/network='internal'\\/>/s//network='internal' portgroup='vlan-${VLAN}'\\/>/" -i "${NAME}.xml"
	virsh define "${NAME}.xml"
    rm -f "${NAME}.xml"
}


function setup_iso {

    local NAME=${1:-"Please specify Name"}
    local GW=${2:-"Please specify Gateway"}
    local IMAGE_PATH=${3:-"Please specify Image Path"}
	local TMPD=$(mktemp -d)

    echo "Setup ISO..."

    modprobe nbd max_part=63
	qemu-nbd -n -c /dev/nbd0 "${IMAGE_PATH}"
	vgscan --mknode
	vgchange -ay os
	mount /dev/os/root "${TMPD}"
	sed "s/GATEWAY=.*/GATEWAY=\"${GW}\"/g" -i "${TMPD}"/etc/sysconfig/network
    #Fuel 6.1 displays network setup menu by default
    sed -i 's/showmenu=yes/showmenu=no/g' "${TMPD}"/root/.showfuelmenu
    echo "
DEVICE=eth1
TYPE=Ethernet
ONBOOT=yes
NM_CONTROLLED=no
BOOTPROTO=dhcp
PEERDNS=no" > "${TMPD}"/etc/sysconfig/network-scripts/ifcfg-eth1
    umount "${TMPD}"
	vgchange -an os
	qemu-nbd -d /dev/nbd0
    rm -rf "${TMPD}"
}

function deploy_fuel
{
    local NAME=${1:?"Please specify Name"}
    local CPU=${2:?"Please specify CPU"}
    local RAM=${3:?"Please specify RAM"}
    local ISO=${4:?"Please specify ISO"}
    local GW=${5:?"Please specify Gateway"}
    local PXE_VLAN=${6:?"Please specify PXE VLAN"}
    local IMAGE_PATH=${7:?"Please specify Image path"}

    echo "Starting Fuel master vm..."

    virt-install \
        --name  "${NAME}" \
        --cpu   host \
        --ram   "${RAM}" \
        --vcpus "${CPU},cores=${CPU}" \
        --disk  "${IMAGE_PATH},serial=$(uuidgen)" \
        --cdrom "${ISO}" \
        --noautoconsole \
        --graphics   vnc,listen=0.0.0.0 \
        --os-type    linux \
        --os-variant rhel6 \
        --virt-type  kvm \
        --network    network=internal,model=virtio \
        --network    network=internal,model=virtio

    while true
    do
        STATUS=$(virsh dominfo "${NAME}" | grep State | awk -F " " '{print $2}')
        if [[ ${STATUS} == 'shut' ]]
        then
            setup_iso     "${NAME}" "${GW}" "${IMAGE_PATH}"
            setup_network "${NAME}" "${PXE_VLAN}"
            virsh start   "${NAME}"
            break
        fi

        sleep 10
    done

    echo "Running Fuel master deployment..."
}


function deploy_slave
{
    local NAME=${1:?"Please specify Name"}
    local CPU=${2:?"Please specify CPU"}
    local RAM=${3:?"Please specify RAM"}
    local MAC=${4:?"Please specify MAC"}
    local PXE_VLAN=${5:?"Please specify PXE_VLAN"}
    local MGMT_VLAN=${6:?"Please specify MGMT_VLAN"}
    local STRG_VLAN=${7:?"Please specify STRG_VLAN"}
    local IMAGE_PATH=${8:?"Please specify Image path"}

    virt-install \
        --name  "${NAME}" \
        --cpu   host \
        --ram   "${RAM}" \
        --vcpus "${CPU},cores=${CPU}" \
        --disk  "${IMAGE_PATH},serial=$(uuidgen)" \
        --boot   network,hd \
        --pxe \
        --noautoconsole \
        --graphics   vnc,listen=0.0.0.0 \
        --os-type    linux \
        --os-variant rhel6 \
        --virt-type  kvm \
        --mac        "${MAC}" \
        --network    network=internal,model=virtio \
        --network    network=internal,model=virtio \
        --network    network=internal,model=virtio \
        --network    network=internal,model=virtio \

    virsh destroy "${NAME}"
    setup_network "${NAME}" "${PXE_VLAN}"
    setup_network "${NAME}" "${MGMT_VLAN}"
    setup_network "${NAME}" "${STRG_VLAN}"
    virsh start   "${NAME}"

    echo "Started fuel-slave ${NAME}"
}

function deploy_vm
{
    local NAME=${1:?"Please specify Name"}
    local CPU=${2:?"Please specify CPU"}
    local RAM=${3:?"Please specify RAM"}
    local IMAGE_PATH=${4:?"Please specify Image path"}

    virt-install \
        --name  "${NAME}" \
        --cpu   host \
        --ram   "${RAM}" \
        --vcpus "${CPU},cores=${CPU}" \
        --disk  "${IMAGE_PATH},serial=$(uuidgen)" \
        --boot  hd \
        --noautoconsole \
        --graphics   vnc,listen=0.0.0.0 \
        --os-type    linux \
        --virt-type  kvm \
        --network    network=internal,model=virtio \

    echo "Started VM ${NAME}"
}

function snapshot_delete_all
{
    local NAME=${1:?"Please specify Name"}

    for i in $(virsh snapshot-list ${NAME} | grep -Ev "Creation Time|-------" | awk '{print $1}')
    do
        virsh snapshot-delete "${NAME}" "${i}"
    done
}

function volume_delete
{
    local NAME=${1:?"Please specify Name"}
    local POOL=${2:?"Please specify Pool"}
    NAME="${NAME}.qcow2"

    virsh vol-delete --pool "${POOL}" "${NAME}"
}

function vm_delete
{
    local NAME=${1:?"Please specify Name"}
    local POOL=${2:?"Please specify Pool"}

    snapshot_delete_all "${NAME}"
    virsh destroy       "${NAME}"
    virsh undefine      "${NAME}"
    volume_delete       "${NAME}" "${POOL}"

}

