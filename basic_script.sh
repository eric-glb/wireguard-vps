#!/usr/bin/env bash

vm_name=${vm_name-wireguard-vps}
zone=${zone-nl-ams-1}
type=${type-DEV1-S}
image=debian_bookworm
script="./cloud-init/wireguard_pi-hole_unbound.sh"

# prerequisites
for bin in scw jq; do
  if ! type -P $bin &>/dev/null; then
    echo -e "\nERROR: Prerequisite [${bin}] not found. Abort.\n"; exit 1
  fi
done

# create instance
vm_id=$( scw instance server create --output=json ip=new    \
                   type=${type} zone=${zone} image=${image} \
                   name=${vm_name} cloud-init=@${script}    \
         | jq -r '.id' )

# Success?
[ -n "$vm_id" ] || exit 1

# attach console
scw instance server console ${vm_id} zone=${zone}

# once console is detached
echo -e "\nCLI to delete VM $vm_name:\n"
echo -e "scw instance server terminate with-ip=true with-block=true zone=$zone $vm_id\n"
