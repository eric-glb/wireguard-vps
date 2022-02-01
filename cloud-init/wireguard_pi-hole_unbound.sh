#!/usr/bin/env bash

# Cloud-Init script to run Wireguard+Unbound+PiHole on a fresh virtual server.
# Use case: run this on a fresh cheap Scaleway stardust instance.

MY_USER=user

DEBIAN_FRONTEND=noninteractive apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
DEBIAN_FRONTEND=noninteractive apt-get install -y docker-compose pwgen qrencode fail2ban dnsutils

# Root random password, needed for console access
ROOT_PWD=$(pwgen 24 -1)
echo "root:${ROOT_PWD}" | chpasswd

# Where we store config files
mkdir -p /docker/{wireguard,unbound,etc-pihole,etc-dnsmasq.d}

# Unbound config file, butchered

cat <<'EOF' > /docker/unbound/unbound.conf
server:
    cache-max-ttl: 86400
    cache-min-ttl: 60
    directory: "/opt/unbound/etc/unbound"
    edns-buffer-size: 1472
    interface: 0.0.0.0@53
    rrset-roundrobin: yes
    username: "_unbound"
    log-local-actions: no
    log-queries: no
    log-replies: no
    log-servfail: no
    logfile: /dev/null
    verbosity: 1
    aggressive-nsec: yes
    delay-close: 10000
    do-daemonize: no
    do-not-query-localhost: no
    neg-cache-size: 4M
    qname-minimisation: yes
    access-control: 127.0.0.1/32 allow
    access-control: 192.168.0.0/16 allow
    access-control: 172.16.0.0/12 allow
    access-control: 10.0.0.0/8 allow
    auto-trust-anchor-file: "var/root.key"
    chroot: "/opt/unbound/etc/unbound"
    harden-algo-downgrade: yes
    harden-below-nxdomain: yes
    harden-dnssec-stripped: yes
    harden-glue: yes
    harden-large-queries: yes
    harden-referral-path: no
    harden-short-bufsize: yes
    hide-identity: yes
    hide-version: yes
    identity: "DNS"
    private-address: 10.0.0.0/8
    private-address: 172.16.0.0/12
    private-address: 192.168.0.0/16
    private-address: 169.254.0.0/16
    private-address: fd00::/8
    private-address: fe80::/10
    private-address: ::ffff:0:0/96
    tls-cert-bundle: /etc/ssl/certs/ca-certificates.crt
    unwanted-reply-threshold: 10000000
    val-clean-additional: yes
    msg-cache-size: 260991658
    num-queries-per-thread: 4096
    outgoing-range: 8192
    rrset-cache-size: 260991658
    minimal-responses: yes
    prefetch: yes
    prefetch-key: yes
    serve-expired: yes
    so-reuseport: yes
    so-rcvbuf: 1m
    remote-control:
        control-enable: no
EOF

# docker-compose file, Cf. https://github.com/IAmStoxe/wirehole

cat <<EOF > /docker/docker-compose.yml
---
version: "3"

networks:
  private_network:
    ipam:
      driver: default
      config:
        - subnet: 10.2.0.0/24

services:
  unbound:
    image: "mvance/unbound:latest"
    container_name: unbound
    restart: unless-stopped
    hostname: "unbound"
    volumes:
      - "./unbound:/opt/unbound/etc/unbound/"
    networks:
      private_network:
        ipv4_address: 10.2.0.200

  wireguard:
    depends_on: [unbound, pihole]
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
      - PEERDNS=10.2.0.100
      - INTERNAL_SUBNET=10.6.0.0
    volumes:
      - ./wireguard:/config
      - /lib/modules:/lib/modules
    ports:
      - 51820:51820/udp
    dns:
      - 10.2.0.100 # Points to pihole
      - 10.2.0.200 # Points to unbound
    sysctls:
      - net.ipv4.conf.all.src_valid_mark=1
    restart: unless-stopped
    networks:
      private_network:
        ipv4_address: 10.2.0.3

  pihole:
    depends_on: [unbound]
    container_name: pihole
    image: pihole/pihole:latest
    restart: unless-stopped
    hostname: pihole
    dns:
      - 127.0.0.1
      - 10.2.0.200 # Points to unbound
    environment:
      TZ: "EUrope/Paris"
      WEBPASSWORD: "" # Blank password
      ServerIP: 10.1.0.100 # Internal IP of pihole
      DNS1: 10.2.0.200     # Unbound IP
      DNS2: 10.2.0.200     # If we don't specify two, it will auto pick google.
    volumes:
      - "./etc-pihole/:/etc/pihole/"
      - "./etc-dnsmasq.d/:/etc/dnsmasq.d/"
    # Recommended but not required (DHCP needs NET_ADMIN)
    #   https://github.com/pi-hole/docker-pi-hole#note-on-capabilities
    #cap_add:
    #  - NET_ADMIN
    networks:
      private_network:
        ipv4_address: 10.2.0.100
EOF

cd /docker || return
docker-compose up -d

# Wait for wireguard image container to create config file
CONF="/docker/wireguard/peer_${MY_USER}/peer_${MY_USER}.conf"
while :
do
  [ -e ${CONF} ] && break
  sleep 2
done

# Print credentials on the console (and store information in /root/banner file)
(
  SEPARATOR=$(perl -le 'print "=" x 80')
  echo -e "${SEPARATOR}\nWireguard conf file for ${MY_USER}:\n"
  qrencode -t ansiutf8 < ${CONF}
  echo -e "${SEPARATOR}"
  cat ${CONF}
  echo -e "${SEPARATOR}\nRoot password for console access: ${ROOT_PWD}\n${SEPARATOR}"
  echo -e "Connect to this server:\n    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$(curl -sL https://ifconfig.co/)\n${SEPARATOR}"
) | tee /root/banner >/dev/console

# Systemd service to print credentials on the console at boot time
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
