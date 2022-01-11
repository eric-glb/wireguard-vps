#!/usr/bin/env bash

project_id=${project_id-xxxxxxxxxxxx}
vm_name=${vm_name-scw-wireguard}
zone=${zone-nl-ams-1}
type=${type-STARDUST1-S}
script="./cloud-init/wireguard_pi-hole_unbound.sh"

JSON=$(
  scw instance server create \
      type=${type} \
      zone=${zone} \
      image=debian_buster \
      root-volume=l:10G \
      name=${vm_name} \
      ip=new \
      project-id=${project_id} \
      cloud-init=@${script} \
      --output=json
)
vm_id=$(jq -r '.id' <<<$JSON)


# console
scw instance server console ${vm_id} zone=${zone}


# how to delete
cat <<EOF
Delete VM $vm_name:

scw instance server terminate $vm_id zone=$zone with-ip=true

EOF
