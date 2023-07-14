# wireguard-vps

![screenshot](./assets/scw-wireguard.png)

Script to instanciate in ~3min a [Scaleway](https://www.scaleway.com/) VM as [Wireguard VPN](https://www.wireguard.com/) with [Unbound](https://nlnetlabs.nl/projects/unbound/about/) and [Pi-hole](https://github.com/pi-hole), using [cloud-init](https://cloudinit.readthedocs.io/en/latest/) facilities.
All these applications are dockerized, and the docker images are regularly pulled/updated by [watchtower](https://github.com/containrrr/watchtower).

[Scaleway](https://www.scaleway.com/) is a french cloud provider with affordable costs.

Cheaper instances:
- [STARDUST1-S](https://www.scaleway.com/en/stardust-instances/) (only available at fr-par-1 and nl-ams-1)
- [AMP2-C1](https://www.scaleway.com/en/amp2-instances/) (only available at fr-par-2; arm64)

```
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
```

## How to create a wireguard + Unbound + PI-hole VM

### Prerequisites
- a [Scaleway account](https://console.scaleway.com/register)
- [scaleway-cli](https://github.com/scaleway/scaleway-cli), using your account (`scw init` done)


### Example

```bash
# AMP2-C1 available at fr-par-2 for testing, as cheap as STARDUST1-S, but arm64 instead of x86_64

vm_name=test zone=fr-par-2 type=AMP2-C1 ./create-scw-wireguard_pi-hole_unbound.sh

```

Note the parameters `vm_name`, `zone` and `type` in the command-line.
Default values will be `wireguard-vps`, `nl-ams-1` and `DEV1-S` otherwise.


__NB__: [ctrl]+[q] to close the VM console attached to your terminal.


## What it does

This [script](./create-scw-wireguard_pi-hole_unbound.sh) will:
- check the availability for this VM type
- create a VM
- attach the console to the running terminal
- run the [cloud-init script](./cloud-init/wireguard_pi-hole_unbound.sh).


## The cloud-init part

The [cloud-init script](./cloud-init/wireguard_pi-hole_unbound.sh) will:
- upgrade the OS
- install docker and other things (fail2ban, ...)
- generate a random password for root
- create a config file for Unbound
- create an application stack composed of Unbound, Wireguard, Pi-Hole and Watchtower using docker-compose
- set a service to print the login and wireguard client information on the server console
- reboot the OS (in case the linux kernel has been updated during the OS upgrade). 


## The docker-compose stack

Very largely inspired/copied from [IAmStoxe/wirehole](https://github.com/IAmStoxe/wirehole), but modified and a bit simplified according to my needs.

The docker-compose stack relies on:
- [alpinelinux/unbound](https://hub.docker.com/r/alpinelinux/unbound) (was previously [mvance/unbound](https://github.com/MatthewVance/unbound-docker), but the latter was x86_64-only)
- [linuxserver/docker-wireguard](https://github.com/linuxserver/docker-wireguard)
- [pihole/pihole](https://github.com/pi-hole/pi-hole)
- [containrrr/watchtower](https://github.com/containrrr/watchtower)

Thanks to them for building these docker images, and of course to people involved in these projects.


## Scaleway CLI commands examples

### How to list available VM types and hourly prices by zone

```bash
for zone in fr-par-1 fr-par-2 fr-par-3 nl-ams-1 pl-waw-1; do
  echo -e "\n== $zone ==\n"
  scw instance server-type list --output=human zone=$zone
done
```


### How to connect to the VM

Open the console on your VM using the [Scaleway console](https://console.scaleway.com/) and restart the VM if you need to retrieve the root password and/or the wireguard information.

Alternative:
```bash
# List instances
scw instance server list zone=all

# Populate these variables
ZONE=<get value from instance list>
ID=<get value from instance list>

# Reboot instance
scw instance server reboot zone=$ZONE $ID

# Attach to the instance console ([CTRL]+[Q] to detach from console)
scw instance server console zone=$ZONE $ID
```


### How to delete a running VM

```bash
# List instances
scw instance server list zone=all

# Populate these variables
ZONE=<get value from instance list>
ID=<get value from instance list>

# Delete instance
scw instance server terminate with-ip=true with-block=true zone=$ZONE $ID
```

### How to get all available boot images for VMs

```bash
scw marketplace image list
```
