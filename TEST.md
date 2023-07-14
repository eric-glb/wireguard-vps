# How to test the VPN + DNS resolution


## VPN

Once the **client**, Wireguard client configured and **started**:

```bash
curl -sL http://ifconfig.co
```
Should return the VPS IP

Alternative:  
Connect to [http://ifconfig.co](http://ifconfig.co)


## DNS


### On the **VPS**, check default name resolution

```bash
dig +short addme.com
```

Should answer an IP address


### On the **VPS**, name resolution explicitely using Unbound

```bash
dig +short addme.com @10.2.0.200
```

Should answer the same IP address


### On the **VPS**, name resolution explicitely using Pi-Hole

```bash
dig +short addme.com @10.2.0.100
```

Should answer `0.0.0.0` (hence filtered)


### On the **client**, **VPN started**, check name resolution

```bash 
nslookup addme.com
```

Alterative:  
try to reach [http://addme.com](http://addme.com) or [d3ward/toolz](https://d3ward.github.io/toolz/adblock.html).
