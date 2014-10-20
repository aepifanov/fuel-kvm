#!/bin/bash

source functions.sh
source bash_arg_parser/parse_args.sh

CONF='
    {
     "options":
      [
       {"opt":"n",
        "opt_long": "name",
        "arg": ":",
        "man": "Env name and prefix for the VM name. (mandatory option)"
       },
       {"opt":"c",
        "opt_long": "cpu",
        "arg": ":",
        "man": "CPU Number for VM. (Default: 4)"
       },
       {"opt":"r",
        "opt_long": "ram",
        "arg": ":",
        "man": "RAM in MB for VM. (Default: 8192)"
       },
       {"opt":"d",
        "opt_long": "disk",
        "arg": ":",
        "man": "Disk size in GB for VM. (Default: 40)"
       },
       {"opt":"x",
        "opt_long": "xml",
        "arg": ":",
        "man": "XML configuration for VM. (Default: the same with name)"
       },
       {"opt":"l",
        "opt_long": "pool",
        "arg": ":",
        "man": "Storage pool name. (default: big)"
       }
     ]
    }'

ARGS=${@}

function parse_args {
    local _CONF=${1-$CONF}
    local _ARGS=${2-$ARGS}

    parse_default_args "${_CONF}" "${_ARGS}"

    eval set -- "${ARGS}"

    while true ; do
        case "$1" in
            # Custom options
            -n|--name)                 NAME=$2 ; shift 2 ;;
            -c|--cpu)                   CPU=$2 ; shift 2 ;;
            -r|--ram)                   RAM=$2 ; shift 2 ;;
            -d|--disk)                 DISK=$2 ; shift 2 ;;
            -l|--pool)                 POOL=$2 ; shift 2 ;;
            -x|--xml)                   XML=$2 ; shift 2 ;;

            # Exit
            --) shift ; break ;;
            *)  usage ; exit 1;;
        esac
    done

    #echo "Remaining arguments:"
    #for arg do echo '--> '"\`${arg}'" ; done
}

parse_args "${CONF}" "${ARGS}"

NAME=${NAME?"--name is mandatory option. use --help for more details"}
NAME=${NAME}
RAM=${RAM:-8192}
CPU=${CPU:-4}
DISK=${DISK:-"40"}
XML=${XML:-${NAME}".xml"}
POOL=${POOL:-"big"}

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

