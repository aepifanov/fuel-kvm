#!/bin/bash

if [ $# -ne 1 ]
then
  echo "Usage: $0 prefix"
  exit 1
fi

PREFIX=$1

echo "You are going to delete all VMs with the following prefix:"
echo ${PREFIX}
echo "Do you wish to proceed?"
select ANS in Yes No; do
    case $ANS in
        [yY]*)
            break;
            ;;
        [nN]*|exit)
            exit 0
            ;;
        *)
            echo "try again: Yes, No"
    esac
done

echo "Deleting Fuel Master vm..."

master=$(virsh list --all | grep $PREFIX-fuel| awk '{print $2}')
if [ ! -z $master ]
then
    virsh destroy $master
    virsh undefine $master
    virsh vol-delete --pool big $PREFIX-fuel.qcow2
fi

echo "Deleting slaves..."

for i in $(virsh list --all | grep $PREFIX-mos | awk '{print $2}')
do
   echo $i
   virsh destroy $i
   sleep 2
   virsh undefine $i
done

for j in $(virsh vol-list --pool big | grep $PREFIX-mos | awk '{print $1}')
do
   echo $j
   virsh vol-delete --pool big $j
   sleep 2
done

