# stardust-wireguard

![screenshot](./assets/scw-wireguard.png)



Script to instanciate a Scaleway VM as wireguard VPN with Unbound and PiHole, using cloud-init facilities.  
Initially I used `STARDUST1-S` VM type, as they are really cheap, hence this github project name.


## How to create a wireguard VM

Prerequisites:
- a Scaleway account
- a Scaleway `project ID` (create a `.project_id file with this information, or modify the script accordingly)
- [scaleway-cli](https://github.com/scaleway/scaleway-cli), using your account (`scw init` done) 

```bash
vm_name=test zone=fr-par-1 type=DEV1-S ./create-scw-wireguard_pi-hole_unbound.sh
```

Note the parameters `vm_name`, `zone` and `type` in the command-line.  
Default values will be `scw-wireguard`, `nl-ams-1` and `STARDUST1-S` otherwise.


NB: [ctrl]+[q] to close the VM console attached to your terminal. 


## What it does

This script will: 
- check the availability for this VM type
- create a VM 
- attach the console to the running terminal
- run the cloud-init script [./cloud-init/wireguard_pi-hole_unbound.sh](./cloud-init/wireguard_pi-hole_unbound.sh).


## The cloud-init part

The cloud-init script will:
- upgrade the OS
- install docker and other things (fail2ban, ...)
- generate a random password for root
- create a config file for Unbound
- create an application stack composed of Unbound, Wireguard and Pi-Hole using docker-compose
- reboot the OS
- print the needed information on the server console.



## The docker-compose stack

The docker-compose stack relies on:
- [mvance/unbound](https://github.com/MatthewVance/unbound-docker)
- [linuxserver/docker-wireguard](https://github.com/linuxserver/docker-wireguard)
- [pihole/pihole](https://github.com/pi-hole/pi-hole)

Thanks to them for building these docker images, and of course to people involved in these projects.


## How to connect to the VM

Open the console on your VM using the [Scaleway console](https://console.scaleway.com/) and restart the VM if you need to retrieve the root password and/or the wireguard information. 
