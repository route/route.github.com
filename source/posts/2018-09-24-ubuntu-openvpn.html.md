---
title: OpenVPN on Ubuntu 18.04
tags: network, vpn, openvpn
description: Set up OpenVPN on Ubuntu
---

### Install and copy configs:

```shell
sudo apt update
sudo apt install openvpn
wget -P ~/ https://github.com/OpenVPN/easy-rsa/releases/download/v3.0.4/EasyRSA-3.0.4.tgz
tar zxvf EasyRSA-3.0.4.tgz
cd EasyRSA-3.0.4
cp vars.example vars
vim vars
```

Set these variables in the file and save:

```shell
vim vars
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
./easyrsa init-pki
./easyrsa build-ca
./easyrsa build-server-full openvpn-server nopass
./easyrsa gen-dh
openvpn --genkey --secret ta.key
```

### Generate client keys:

Set CLIENT_NAME to any name you'd like to associate your OpenVPN client with:

```shell
export CLIENT_NAME="<client-name>"
./easyrsa build-client-full $CLIENT_NAME nopass
```

### Copy server keys:

```shell
cp pki/dh.pem \
   pki/ca.crt \
   pki/issued/openvpn-server.crt \
   pki/private/openvpn-server.key \
   ta.key \
   /etc/openvpn/keys
```

### Configure client:
 Change `<server-ip>` in the middle of the ovpn file to your server IP address.

```shell
cd /etc/openvpn
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
cat ~/EasyRSA-3.0.4/pki/private/$CLIENT_NAME.key >> $CLIENT_NAME.ovpn
printf "</key>\n" >> $CLIENT_NAME.ovpn
printf "<cert>\n" >> $CLIENT_NAME.ovpn
sed -n '/^-----BEGIN/,/^-----END/p' ~/EasyRSA-3.0.4/pki/issued/$CLIENT_NAME.crt >> $CLIENT_NAME.ovpn
printf "</cert>\n" >> $CLIENT_NAME.ovpn
printf "<ca>\n" >> $CLIENT_NAME.ovpn
cat ~/EasyRSA-3.0.4/pki/ca.crt >> $CLIENT_NAME.ovpn
printf "</ca>\n" >> $CLIENT_NAME.ovpn
printf "<tls-auth>\n" >> $CLIENT_NAME.ovpn
cat ~/EasyRSA-3.0.4/ta.key >> $CLIENT_NAME.ovpn
printf "</tls-auth>\n" >> $CLIENT_NAME.ovpn
```

### Configure server:

```shell
touch server.conf
cat > server.conf
server 192.168.255.0 255.255.255.0

verb 3

key /etc/openvpn/keys/openvpn-server.key  # This file should be kept secret
ca /etc/openvpn/keys/ca.crt
cert /etc/openvpn/keys/openvpn-server.crt
dh /etc/openvpn/keys/dh.pem
tls-auth /etc/openvpn/keys/ta.key 0 # This file is secret

key-direction 0
keepalive 10 60

persist-key
persist-tun

proto udp
port 1194
dev tun

status openvpn-status.log

user nobody
group nogroup

explicit-exit-notify 1
remote-cert-tls client

route 192.168.254.0 255.255.255.0

push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
```

Type `Ctrl-D` here.

That's basically it, we only need to allow traffic to be NATed through the
server. Set `net.ipv4.ip_forward=1` in this file:

```shell
sudo vim /etc/sysctl.conf
```

Find your default interface:

```shell
ip route | grep default
```

Output should be like: default via x.x.x.x dev `ens3` proto dhcp src x.x.x.x
metric 100. Rememeber your interface name and put it to iptable rules below:

```shell
iptables -t nat -A POSTROUTING -o ens3 -j MASQUERADE
iptables -A FORWARD -j ACCEPT
apt-get install iptables-persistent
```

When you install iptables-persistent it will ask you to save current rules into
file, just agree with that and then start the service:

```shell
sudo systemctl start openvpn@server
sudo systemctl enable openvpn@server
```

Now you can download `$CLIENT_NAME.ovpn` to your machine and start browsing
internet securely:

```shell
scp root@<server-ip>:/etc/openvpn/<client-name>.ovpn ./
sudo openvpn <client-name>.ovpn
```
