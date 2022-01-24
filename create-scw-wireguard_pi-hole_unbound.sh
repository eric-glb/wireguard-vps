#!/usr/bin/env bash

[ -e .project_id ] && project_id=$(cat .project_id)
project_id=${project_id-xxxxxxxxxxxx}

vm_name=${vm_name-wireguard-vps}
zone=${zone-nl-ams-1}
# Unavailable type=${type-STARDUST1-S}
type=${type-DEV1-S}
script="./cloud-init/wireguard_pi-hole_unbound.sh"

# VM type list
TYPE_LIST=$(scw instance server-type list --output=json zone=$zone)

# Check availability
AVAIL=$(jq -r --arg TYPE "$type" '.[] | select(.name == $TYPE) | .availability' <<<$TYPE_LIST)
if [ "$AVAIL" != "available" ]
then
  echo -e "\nERROR: VM type '$type' is not available.\n"
  exit 1
fi

# Get size
size=$(jq -r --arg TYPE "$type" '.[] | select(.name == $TYPE) | .local_volume_size' <<<$TYPE_LIST)


# Create VM
cat <<EOF

==========================================================================================
Creating Scaleway VM named '$vm_name', type '$type', in zone '$zone'.

The console will be attached to this terminal.
[ctrl]+[q] to close it.

==========================================================================================

EOF

OUTPUT=$(
  scw instance server create \
      type=${type} \
      zone=${zone} \
      image=debian_buster \
      root-volume=l:${size} \
      name=${vm_name} \
      ip=new \
      project-id=${project_id} \
      cloud-init=@${script} \
      --output=json
)

# console
vm_id=$(jq -r '.id' <<<$OUTPUT)
scw instance server console ${vm_id} zone=${zone}


# how to delete
cat <<EOF

Delete VM $vm_name:

scw instance server terminate $vm_id zone=$zone with-ip=true

EOF
