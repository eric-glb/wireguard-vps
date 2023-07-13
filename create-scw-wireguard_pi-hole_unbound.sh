#!/usr/bin/env bash

SUBJECT=$(cat <<'EOF'
                 .-~~~-.              ┌───────────────────────────────────┐
         .- ~ ~-(       )_ _          │VPS                                │
        / Internet           ~ -.     │ ┌────────────┐   DNS              │
       |                       ◄──────┼─┤Unbound     ◄───────┐            │
        \                    ▲    .'  │ │(DNS solver)│       │            │
          ~- ._ ,..,.,.,., ,.│ -~     │ └────────────┘       │            │
                          '  │        │               ┌──────┴─────┐      │
 ┌─────────────────┐         │        │               │Pi-Hole     │      │
 │ PC/Phone        │         │        │               │(DNS filter)│      │
 │                 │         │        │               └──────▲─────┘      │
 │   ┌─────────┐   │         │        │  ┌─────────┐         │            │
 │   │Wireguard│   │         └────────┼──┤Wireguard├─────────┘            │
 │   │ Client  │   │                  │  │ Server  │  DNS                 │
 │   │         │  ─┴──────────────────┴─ │ (VPN)   │                      │
 │   │         ├──►     VPN Tunnel     ──►         │   ┌────────────────┐ │
 │   └─────────┘  ─┬──────────────────┬─ └─────────┘   │Watchtower      │ │
 │                 │                  │                │(images updater)│ │
 └─────────────────┘                  │                └────────────────┘ │
                                      └───────────────────────────────────┘
EOF
)

vm_name=${vm_name-wireguard-vps}   # Default: wireguard-vps
zone=${zone-nl-ams-1}              # Default: nl-ams-1
type=${type-DEV1-S}                # Default: DEV1-S, as STARDUST1-S mainly unavailable
image=debian_bookworm              # OS
script="./cloud-init/wireguard_pi-hole_unbound.sh" # cloud-init script

# Prerequisites
for bin in scw jq perl tput; do
  if ! type -P $bin &>/dev/null; then
    echo "Prerequisite '$bin' not found. Abort."
    exit 1
  fi
done

# Colors, etc.
R="\e[0;31m"; Y="\e[0;33m"; G="\e[0;32m"; C="\e[0;m"
sep(){ perl -le 'print "─" x $ARGV[0]' "$(tput cols)"; }

# Intro
for param in $@; do
  if grep -qE '\-h|\-\-help' <<<"$param"; then
    echo -e "\nObject: create a cheap VPS VM as VPN Wireguard server, with Unbound and Pi-Hole."
    echo -e "\n$SUBJECT\n"; exit 0
  fi
done 

# Check VM availability
TYPE_LIST=$(scw instance server-type list --output=json zone=$zone)
AVAIL=$(jq -r --arg TYPE "$type" '.[] | select(.name == $TYPE) | .availability' <<<$TYPE_LIST)
if [ "$AVAIL" != "available" ]; then
  echo -e "\n${R}ERROR${C}: VM type ${Y}${type}${C} is not available in zone ${Y}${zone}${C}.\n" && exit 1
fi

# Create VM
clear; sep
echo -e "\nCreating Scaleway VM:\n"
echo -e "  - name:   ${Y}${vm_name}${C}"
echo -e "  - type:   ${Y}${type}${C}"
echo -e "  - zone:   ${Y}${zone}${C}"
echo -e "  - script: ${Y}${script}${C}\n"
vm_id=$( scw instance server create --output=json         \
             type=${type} zone=${zone} image=${image}     \
             name=${vm_name} cloud-init=@${script} ip=new \
         | jq -r '.id'
)

# Info: VM console attachment pending
echo -e "The console will be attached to this terminal.\n${R}[CTRL]${C}+${R}[Q]${C} to close it ${G}once finished${C}.\n"
sep;

# tput magic
tput sc
echo -e "\n\n\n\n\n\n$SUBJECT" 
cat <<'EOF'
              _ _   _              __                               _
 __ __ ____ _(_) |_(_)_ _  __ _   / _|___ _ _   __ ___ _ _  ___ ___| |___
 \ V  V / _` | |  _| | ' \/ _` | |  _/ _ \ '_| / _/ _ \ ' \(_-</ _ \ / -_)
  \_/\_/\__,_|_|\__|_|_||_\__, | |_| \___/_|   \__\___/_||_/__/\___/_\___|
                          |___/

EOF
tput rc

# Attach console
scw instance server console ${vm_id} zone=${zone}

# post-install info
IP=$(scw instance server get zone=$zone $vm_id --output=json | jq -r '.public_ip.address')
echo -e "${R}";sep
echo -e "${C}\nHow to connect to VM ${Y}$vm_name${C}:\n"
echo -e "${G}ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${Y}${IP}\n"
echo -e "${C}\nHow to delete VM ${Y}$vm_name${C}:\n"
echo -e "${G}scw instance server terminate ${Y}$vm_id${G} zone=${Y}$zone${G} with-ip=true${R}\n"
sep; echo -e "${C}"
