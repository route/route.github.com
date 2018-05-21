---
title: OpenVPN on FreeBSD 11.1 on DigitalOcean
tags: network, vpn
description: Set up OpenVPN on FreeBSD on DigitalOcean
---

It's nearly impossible to [work from Russia without VPN](https://nopecode.com/2018/04/24/telegram-drama.html)
that I decided to set up OpenVPN on $5 droplet on DigitalOcean. There's a good
[article](https://ramsdenj.com/2016/07/25/openvpn-on-freebsd-10_3.html) about
setting it up on FreeBSD 10.3 but it's a bit outdated and doesn't have important
information about routing. Why FreeBSD? Because it's always been in my ❤️. Just
take a look at this beauty:

```shell
root@vpn:~ # top

last pid:   915;  load averages:  1.26,  0.51,  0.20
up 0+00:01:10  17:13:10 21 processes:  1 running, 20 sleeping
CPU:  0.4% user,  0.0% nice,  0.4% system,  0.4% interrupt, 98.8% idle
Mem: 18M Active, 34M Inact, 48M Wired, 14M Buf, 866M Free
Swap: 2048M Total, 2048M Free
```

But it's not the only thing to fall in love with BSD I think I'll come with a
post about it later. Let's get going.

### Install and copy configs:

Let's first change shell to sh as FreeBSD comes with csh by default and set a
few variables:

```shell
root@vpn:~ # sh
```

```shell
pkg update && pkg install openvpn
mkdir /usr/local/etc/openvpn
cp /usr/local/share/examples/openvpn/sample-config-files/server.conf \
   /usr/local/etc/openvpn/openvpn.conf
cp -r /usr/local/share/easy-rsa /usr/local/etc/openvpn/easy-rsa
cd /usr/local/etc/openvpn/easy-rsa
```

Set fields in the file and save:

```shell
# vim vars
set_var EASYRSA_REQ_COUNTRY     "<COUNTRY>"
set_var EASYRSA_REQ_PROVINCE    "<PROVINCE>"
set_var EASYRSA_REQ_CITY        "<CITY>"
set_var EASYRSA_REQ_ORG         "<ORGANIZATION>"
set_var EASYRSA_REQ_EMAIL       "<EMAIL>"
set_var EASYRSA_REQ_OU          "<ORGANIZATIONAL UNIT>"
set_var EASYRSA_KEY_SIZE        2048
set_var EASYRSA_CA_EXPIRE       3650
set_var EASYRSA_CERT_EXPIRE     3650
```

### Generate server keys:

```shell
./easyrsa.real init-pki
./easyrsa.real build-ca
./easyrsa.real build-server-full openvpn-server nopass
./easyrsa.real gen-dh
openvpn --genkey --secret ta.key
```

### Generate client keys:

```shell
./easyrsa.real build-client-full $CLIENT_NAME nopass
```

### Copy server keys:

```shell
mkdir /usr/local/etc/openvpn/keys
cp pki/dh.pem \
   pki/ca.crt \
   pki/issued/openvpn-server.crt \
   pki/private/openvpn-server.key \
   ta.key \
   /usr/local/etc/openvpn/keys
```

### Configure client:
Set CLIENT_NAME to any name you'd like to use with your OpenVPN client and don't
forget to change `<server-ip>` in the middle of the ovpn file to your server IP.

```shell
CLIENT_NAME="<client-name>"
cd /usr/local/etc/openvpn
touch $CLIENT_NAME.ovpn
cat > $CLIENT_NAME.ovpn
client
nobind
dev tun
remote-cert-tls server

remote <server-ip> 1194 udp

key-direction 1

redirect-gateway def1
```

Type `Ctrl-D` here and then type the rest:

```shell
printf "<key>\n" >> $CLIENT_NAME.ovpn
cat easy-rsa/pki/private/$CLIENT_NAME.key >> $CLIENT_NAME.ovpn
printf "</key>\n" >> $CLIENT_NAME.ovpn
printf "<cert>\n" >> $CLIENT_NAME.ovpn
sed -n '/^-----BEGIN/,/^-----END/p' easy-rsa/pki/issued/$CLIENT_NAME.crt >> $CLIENT_NAME.ovpn
printf "</cert>\n" >> $CLIENT_NAME.ovpn
printf "<ca>\n" >> $CLIENT_NAME.ovpn
cat easy-rsa/pki/ca.crt >> $CLIENT_NAME.ovpn
printf "</ca>\n" >> $CLIENT_NAME.ovpn
printf "<tls-auth>\n" >> $CLIENT_NAME.ovpn
cat easy-rsa/ta.key >> $CLIENT_NAME.ovpn
printf "</tls-auth>\n" >> $CLIENT_NAME.ovpn
```

### Configure server:

```shell
touch openvpn.conf
cat > openvpn.conf
server 192.168.255.0 255.255.255.0

verb 3

key /usr/local/etc/openvpn/keys/openvpn-server.key  # This file should be kept secret
ca /usr/local/etc/openvpn/keys/ca.crt
cert /usr/local/etc/openvpn/keys/openvpn-server.crt
dh /usr/local/etc/openvpn/keys/dh.pem
tls-auth /usr/local/etc/openvpn/keys/ta.key 0 # This file is secret

key-direction 0
keepalive 10 60

persist-key
persist-tun

proto udp
port 1194
dev tun

status openvpn-status.log

user nobody
group nobody

explicit-exit-notify 1
remote-cert-tls client

route 192.168.254.0 255.255.255.0

push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
```

Type `Ctrl-D` here and again type the rest:

```shell
sysrc openvpn_enable="YES"
sysrc openvpn_if="tun"
sysrc gateway_enable="YES"
sysrc firewall_enable="YES"
sysrc firewall_type="OPEN"
sysrc natd_enable="YES"
sysrc natd_interface="vtnet0"
sysrc natd_flags=""
service openvpn start
reboot
```

After your droplet reboots you can download `$CLIENT_NAME.ovpn` to your client
machine and start browsing internet securely:

```shell
scp root@<server-ip>:/usr/local/etc/openvpn/<client-name>.ovpn ./
sudo openvpn <client-name>.ovpn
```
