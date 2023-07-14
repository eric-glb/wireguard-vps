#!/usr/bin/env bash

vm_name=${vm_name-wireguard-vps}
zone=${zone-nl-ams-1}
type=${type-DEV1-S}
image=debian_bookworm
script="./cloud-init/wireguard_pi-hole_unbound.sh"

for bin in scw jq; do
  if ! type -P $bin &>/dev/null; then
    echo -e "\nERROR: Prerequisite [${bin}] not found. Abort.\n"; exit 1
  fi
done

JSON_OUTPUT=$( scw instance server create --output=json         \
                   type=${type} zone=${zone} image=${image}     \
                   name=${vm_name} cloud-init=@${script} ip=new )

vm_id=$(jq -r '.id' <<<"$JSON_OUTPUT")
scw instance server console ${vm_id} zone=${zone}

echo -e "\nCLI to delete VM $vm_name:\n"
echo -e "scw instance server terminate $vm_id zone=$zone with-ip=true\n"
