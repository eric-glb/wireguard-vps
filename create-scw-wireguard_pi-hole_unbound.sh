#!/usr/bin/env bash
#
# Object: create a cheap VPS VM as VPN Wireguard server, with Unbound and Pi-Hole.
# 
# Example:
#         vm_name=test zone=fr-par-2 type=AMP2-C1 ./create-scw-wireguard_pi-hole_unbound.sh
#

#-> Target <--------------------------------------------------------------------

SCHEMA=$(cat <<'EOF'

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

#-> Variables <-----------------------------------------------------------------

vm_name=${vm_name-wireguard-vps}   # Default: wireguard-vps
zone=${zone-nl-ams-1}              # Default: nl-ams-1
type=${type-DEV1-S}                # Default: DEV1-S, as STARDUST1-S mainly unavailable
image=debian_bookworm              # OS
script="./cloud-init/wireguard_pi-hole_unbound.sh" # cloud-init script

#-> Check prerequisites <-------------------------------------------------------

for bin in scw jq perl tput; do
  if ! type -P $bin &>/dev/null; then
    echo "Prerequisite '$bin' not found. Abort."
    exit 1
  fi
done

#-> Colors, etc. <--------------------------------------------------------------

R="\e[0;31m"; Y="\e[0;33m"; G="\e[0;32m"; C="\e[0;m"
sep(){ perl -le 'print "─" x $ARGV[0]' "$(tput cols)"; }


#-> Help <----------------------------------------------------------------------

for param in $@; do
  if grep -qE '\-h|\-\-help' <<<"$param"; then
    echo -e "\n${R}Object${C}: ${G}create a cheap VPS VM as VPN Wireguard server, with Unbound and Pi-Hole.${C}"
    echo -e "$SCHEMA\n"
    echo -e "${Y}Usage example${C}:\n\n${G}vm_name=test zone=fr-par-2 type=AMP2-C1 $0${C}\n"
    exit 0
  fi
done 

#-> Check VM availability <-----------------------------------------------------

TYPE_LIST=$(scw instance server-type list --output=json zone=$zone)
AVAIL=$(jq -r --arg TYPE "$type" '.[] | select(.name == $TYPE) | .availability' <<<$TYPE_LIST)
if [ "$AVAIL" != "available" ]; then
  echo -e "\n${R}ERROR${C}: VM type ${Y}${type}${C} is not available in zone ${Y}${zone}${C}.\n" && exit 1
fi

#-> Info <----------------------------------------------------------------------

clear; sep
echo -e "\nCreating Scaleway VM:\n"
echo -e "  - name:   ${Y}${vm_name}${C}"
echo -e "  - type:   ${Y}${type}${C}"
echo -e "  - zone:   ${Y}${zone}${C}"
echo -e "  - script: ${Y}${script}${C}\n"
sep;
echo -e "The console will be attached to this terminal.\n${R}[CTRL]${C}+${R}[Q]${C} to close it ${G}once finished${C}.\n"

#-> tput "magic" to print screen footer while waiting for the console <---------

content=(); IFS=$'\n'$'\r'; while read -r line; do content+=("$line"); done <<<"$SCHEMA"; IFS=
vLen=${#content[@]}; hLen=0; for i in "${content[@]}"; do [ ${#i} -gt $hLen ] && hLen=${#i}; done
totalvLen=$(tput lines); totalhLen=$(tput cols); lp=$(((totalhLen - hLen) / 2))
tput sc
tput cup $(( totalvLen - vLen -1 )) 0
for i in "${content[@]}"; do seq 1 $lp | xargs printf " %.0s"; echo -e "${G}$i${C}"; done
tput rc

#-> Create VM <-----------------------------------------------------------------

vm_id=$( scw instance server create --output=json         \
             type=${type} zone=${zone} image=${image}     \
             name=${vm_name} cloud-init=@${script} ip=new \
         | jq -r '.id'
)

#-> Attach console <------------------------------------------------------------

scw instance server console ${vm_id} zone=${zone}

#-> post-install info, once the console is detached <---------------------------

IP=$(scw instance server get zone=$zone $vm_id --output=json | jq -r '.public_ip.address')
echo -en "${R}";sep;echo -en "${C}"
scw instance server list zone=all
echo -en "${R}";sep;echo -en "${C}"
echo -e "\nHow to connect to VM ${Y}${vm_name}${C}:\n"
echo -e "${G}ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${Y}${IP}\n"
echo -e "${C}\nHow to delete VM ${Y}${vm_name}${C}:\n"
echo -e "${G}scw instance server terminate with-ip=true with-block=true zone=${Y}${zone}${G} ${Y}${vm_id}${C}\n"
echo -en "${R}";sep;echo -e "${C}"
