---
title: Telegram drama (Part 2)
tags: network, vpn
description: Bypass telegram blocks with Mikrotik
---

I want my internet to work w/o restrictions and I don't want to set up tunnels
on every signle device. In other words router should set up the tunnel and route
traffic accordingly. My new toy is [Mikrotik hap ac2](https://mikrotik.com/product/hap_ac2)
and I'm very happy with it. It supports many cool features, the speed is great
and hardware accelearation for IPsec should speed it up even more.

I have bought a server overseas, let's setup GRE tunnel between router and a
server(`x.x.x.x` - server's white IP, `y.y.y.y` - router's white IP), the
network IP address inside the tunnel will be `192.168.0.1` for server and
`192.168.0.2` for router, my home network behind router is `192.168.88.0/24`:

```shell
$ sudo cat << EOF >> /etc/network/interfaces
 iface tun1 inet static
    address 192.168.0.1
    netmask 255.255.255.0
    mtu 1456
    pre-up iptunnel add tun1 mode gre local x.x.x.x remote y.y.y.y ttl 255
    up ifconfig tun1 multicast
    pointopoint 192.168.0.2
    post-down iptunnel del tun1
 up ip ro add 192.168.88.0/24 via 192.168.0.2
EOF

$ sudo echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
$ sudo sysctl -p # check if it's set properly
$ sudo iptables -t nat -A POSTROUTING -o ens3 -j MASQUERADE
$ ifdown tun1 && ifup tun1
```

On the router:

```shell
/interface gre add name="gre-tunnel1" mtu=auto local-address=y.y.y.y remote-address=x.x.x.x clamp-tcp-mss=yes dont-fragment=no allow-fast-path=yes
/ip address add address=192.168.0.2/24 network=192.168.0.0 interface=gre-tunnel1

/ip firewall mangle
add chain=forward action=change-mss new-mss=clamp-to-pmtu passthrough=no tcp-flags=syn protocol=tcp in-interface=gre-tunnel1 tcp-mss=1300-65535 log=no log-prefix=""
add chain=forward action=change-mss new-mss=clamp-to-pmtu passthrough=no tcp-flags=syn protocol=tcp out-interface=gre-tunnel1 tcp-mss=1300-65535 log=no log-prefix=""

/ip route
add comment=linkedin distance=1 dst-address=91.225.248.0/22 gateway=gre-tunnel1
add comment=linkedin distance=1 dst-address=108.174.0.0/20 gateway=gre-tunnel1
add comment=linkedin distance=1 dst-address=185.63.144.0/22 gateway=gre-tunnel1
add comment=rutracker distance=1 dst-address=195.82.146.0/24 gateway=gre-tunnel1
add comment=telegram distance=1 dst-address=149.154.164.0/22 gateway=gre-tunnel1
```

You can now open all sites you added routes to; the packets for them now flow
thru the tunnel. That's it.
