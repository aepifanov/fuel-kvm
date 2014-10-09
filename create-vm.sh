#!/bin/bash



set -x
name=$1
ram=$2
cpu=$3
size=$4
os=$5

virsh destroy $name
virsh undefine $name
virsh vol-delete --pool default $name"("$os").qcow2"

sed -e "s/%name/$name($os).qcow2/g" -e "s/%size/$size/g" $os".xml" > /tmp/$name.xml
virsh vol-create --pool default /tmp/$name.xml
#rm -f /tmp/$name.xml

virt-install \
  --name=$name \
  --cpu host \
  --ram=$ram \
  --vcpus=$cpu,cores=$cpu \
  --os-type=linux \
  --os-variant=rhel6 \
  --virt-type=kvm \
  --boot=hd \
  --disk "/var/lib/libvirt/images/$name($os).qcow2" \
  --noautoconsole \
  --network network=internal,model=virtio \
  --graphics vnc,listen=0.0.0.0

