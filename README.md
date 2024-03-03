# wireguard-vps

![screenshot](./assets/scw-wireguard.png)

Script to instanciate in ~3min a [Scaleway](https://www.scaleway.com/) VM as [Wireguard VPN](https://www.wireguard.com/) with [Unbound](https://nlnetlabs.nl/projects/unbound/about/) and [Pi-hole](https://github.com/pi-hole), using [cloud-init](https://cloudinit.readthedocs.io/en/latest/) facilities.
All these applications are dockerized, and the docker images are regularly pulled/updated by [watchtower](https://github.com/containrrr/watchtower).

[Scaleway](https://www.scaleway.com/) is a french cloud provider with affordable costs.

Cheaper instances:

- [STARDUST1-S](https://www.scaleway.com/en/stardust-instances/) (only available at fr-par-1 and nl-ams-1)
- [AMP2-C1](https://www.scaleway.com/en/amp2-instances/) (only available at fr-par-2; arm64)

```text
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
- [jq](https://github.com/jqlang/jq)
- [perl](https://www.perl.org/get.html)
- [tput](https://manned.org/tput.1)

### Example

```bash
# AMP2-C1 available at fr-par-2 for testing, as cheap as STARDUST1-S, but arm64 instead of x86_64

vm_name=test zone=fr-par-2 type=AMP2-C1 ./create-scw-wireguard_pi-hole_unbound.sh

```

Note the parameters `vm_name`, `zone` and `type` in the command-line.
Default values will be `wireguard-vps`, `nl-ams-1` and `DEV1-S` otherwise.

__NB__: `[ctrl]+[q]` to close the VM console attached to your terminal.

## What it does

The script [create-scw-wireguard_pi-hole_unbound.sh](./create-scw-wireguard_pi-hole_unbound.sh) will:

- check the availability for this VM type
- create a VM
- attach the console to the running terminal
- run the [cloud-init script](./cloud-init/wireguard_pi-hole_unbound.sh).

The script [basic_script.sh](./basic_script.sh) does exactly the same, but without any check or information display.

## The cloud-init part

The [cloud-init script](./cloud-init/wireguard_pi-hole_unbound.sh) pushed when creating the instance will:

- upgrade the OS
- install docker and other things (fail2ban, ...)
- generate a random password for root
- create a config file for Unbound
- configure and harden fail2ban using [fail2ban-endlessh](https://github.com/itskenny0/fail2ban-endlessh) configuration
- clone [endlessh](https://github.com/skeeto/endlessh) in order to build the container image (cf. [docker-compose.yml](./docker-compose.yml) and `endlessh`'s Dockerfile)
- create and start an application stack composed of Unbound, Wireguard, Pi-Hole and Watchtower using docker-compose
- add several blocklists and will also whitelist several domains in Pi-Hole
- set a service to print the login and wireguard client information on the server console
- reboot the OS.

## The docker-compose stack

Very largely inspired/copied from [IAmStoxe/wirehole](https://github.com/IAmStoxe/wirehole), but modified and a bit simplified according to my needs.

The [docker-compose stack](./docker-compose.yml) relies on:

- [alpinelinux/unbound](https://hub.docker.com/r/alpinelinux/unbound) (was previously [mvance/unbound](https://github.com/MatthewVance/unbound-docker), but the latter was x86_64-only)
- [linuxserver/docker-wireguard](https://github.com/linuxserver/docker-wireguard)
- [pihole/pihole](https://github.com/pi-hole/pi-hole)
- [containrrr/watchtower](https://github.com/containrrr/watchtower)
- a built on-the-fly [endlessh](https://github.com/skeeto/endlessh) container to harden a bit fail2ban

Thanks to them for building these docker images, and of course to people involved in these projects.



---

## Scaleway CLI commands examples

### How to list available VM types and hourly prices by zone

```bash
for zone in fr-par-1 fr-par-2 fr-par-3 nl-ams-1 nl-ams-2 pl-waw-1 pl-waw-2; do
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

## Wireguard client configuration modification

Objective: route only Internet traffic to the VPN, but keep local network and DNS reachable.

Use [WireGuard AllowedIPs Calculator](https://www.procustodibus.com/blog/2021/03/wireguard-allowedips-calculator/) to calculate the `AllowedIPs`parameter.

_Example_:

```text
[Interface]
PrivateKey = [REDACTED]
ListenPort = [REDACTED]
Address = 10.6.0.2/32
DNS = [REDACTED - LOCAL DNS IP]

[Peer]
PublicKey = [REDACTED]
AllowedIPs = 1.0.0.0/8, 2.0.0.0/7, 4.0.0.0/6, 8.0.0.0/7, 11.0.0.0/8, 12.0.0.0/6, 16.0.0.0/4, 32.0.0.0/3, 64.0.0.0/3, 96.0.0.0/4, 112.0.0.0/5, 120.0.0.0/6, 124.0.0.0/7, 126.0.0.0/8, 128.0.0.0/3, 160.0.0.0/5, 168.0.0.0/8, 169.0.0.0/9, 169.128.0.0/10, 169.192.0.0/11, 169.224.0.0/12, 169.240.0.0/13, 169.248.0.0/14, 169.252.0.0/15, 169.255.0.0/16, 170.0.0.0/7, 172.0.0.0/12, 172.32.0.0/11, 172.64.0.0/10, 172.128.0.0/9, 173.0.0.0/8, 174.0.0.0/7, 176.0.0.0/4, 192.0.0.0/9, 192.128.0.0/11, 192.160.0.0/13, 192.169.0.0/16, 192.170.0.0/15, 192.172.0.0/14, 192.176.0.0/12, 192.192.0.0/10, 193.0.0.0/8, 194.0.0.0/7, 196.0.0.0/6, 200.0.0.0/5, 208.0.0.0/4, 224.0.0.0/4, ::/1, 8000::/2, c000::/3, e000::/4, f000::/5, f800::/6, fe00::/9, fec0::/10, ff00::/8
Endpoint = [REDACTED]:[REDACTED]
```

This `AllowedIPs` excludes all local networks according to [RFC1918](https://en.wikipedia.org/w/index.php?title=RFC1918).
