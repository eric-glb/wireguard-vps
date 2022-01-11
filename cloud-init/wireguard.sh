#!/usr/bin/env bash

# Cloud-Init script to install Wireguard on a fresh virtual server.
# Use case: run this on a fresh cheap Scaleway stardust instance.

MY_USER=user

DEBIAN_FRONTEND=noninteractive apt-get update 
DEBIAN_FRONTEND=apt-get upgrade -y
DEBIAN_FRONTEND=noninteractive apt-get install -y docker-compose pwgen qrencode fail2ban dnsutils

# Root random password, needed for console access
ROOT_PWD=$(pwgen 24 -1)
echo "root:${ROOT_PWD}" | chpasswd

# Docker container image for Wireguard
# Cf. https://hub.docker.com/r/linuxserver/wireguard

mkdir -p /docker/wireguard
cat <<EOF > /docker/docker-compose.yml
---
version: "2.1"
services:
  wireguard:
    image: ghcr.io/linuxserver/wireguard
    container_name: wireguard
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/Paris
      - SERVERPORT=51820
      - PEERS=${MY_USER}
      - PEERDNS=auto
      - INTERNAL_SUBNET=10.13.13.0 #optional
      - ALLOWEDIPS=0.0.0.0/0 #optional
    volumes:
      - /docker/wireguard:/config
      - /lib/modules:/lib/modules
    ports:
      - 51820:51820/udp
    sysctls:
      - net.ipv4.conf.all.src_valid_mark=1
    restart: unless-stopped
EOF
cd /docker
docker-compose up -d

# Wait for wireguard image container to create config file
CONF="/docker/wireguard/peer_${MY_USER}/peer_${MY_USER}.conf"
while :
do
  [ -e ${CONF} ] && break
  sleep 2
done

# Print credentials on the console
(
  SEPARATOR=$(perl -le 'print "=" x 80')
  echo -e "${SEPARATOR}\nWireguard conf file for ${MY_USER}:\n"
  qrencode -t ansiutf8 < ${CONF}
  echo -e "${SEPARATOR}" 
  cat ${CONF}
  echo -e "${SEPARATOR}\nRoot password for console access: ${ROOT_PWD}\n${SEPARATOR}"
  echo -e "Connect to this server:\n    ssh root@$(curl -sL https://ifconfig.co/)\n${SEPARATOR}"
) | tee /root/banner >/dev/console

# Systemd service to print credential on the console at boot time
cat <<'EOF' > /lib/systemd/system/banner-console.service
[Unit]
Description=Show information on the console
After=cloud-init.target

[Service]
Type=oneshot
ExecStart=/usr/bin/bash -c "/usr/bin/cat /root/banner > /dev/console"
[Install]
WantedBy=cloud-init.target
EOF

systemctl daemon-reload
systemctl enable banner-console

reboot
