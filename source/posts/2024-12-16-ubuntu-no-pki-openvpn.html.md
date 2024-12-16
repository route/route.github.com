---
title: OpenVPN without PKI on Ubuntu 24.04
tags: network, vpn, openvpn
description: Set up OpenVPN on Ubuntu
---

It's mostly copy-paste version of the original OpenVPN [example](https://github.com/openvpn/openvpn/blob/master/doc/man-sections/example-fingerprint.rst) with
exception to editing `/etc/sysctl.conf`, figuring out default interface and downloading ovpn file.

### Install and copy configs:

```shell
sudo apt update
sudo apt upgrade
sudo reboot
sudo apt install openvpn
```

### Generate server/client configs:

```shell
export CLIENT_NAME=client # arbitrary client name
export REMOTE_SERVER_IP='x.x.x.x' # public ip address of the server

openssl req -x509 -newkey ec:<(openssl ecparam -name secp384r1) -keyout server.key -out server.crt -nodes -sha256 -days 3650 -subj '/CN=server'
export SERVER_FINGERPRINT=$(openssl x509 -fingerprint -sha256 -in server.crt -noout | cut -d'=' -f2)

openssl req -x509 -newkey ec:<(openssl ecparam -name secp384r1) -nodes -sha256 -days 3650 -subj "/CN=${CLIENT_NAME}" > client.cert
export CLIENT_CERTIFICATE=$(<client.cert)
export CLIENT_PRIVATE_KEY=$(<privkey.pem)

cat > $CLIENT_NAME.ovpn <<EOF
remote $REMOTE_SERVER_IP 1194 udp

client
nobind
dev tun
tun-mtu 1400

key-direction 1

redirect-gateway def1

<key>
$CLIENT_PRIVATE_KEY
</key>

<cert>
$CLIENT_CERTIFICATE
</cert>

peer-fingerprint $SERVER_FINGERPRINT

EOF

export CLIENT_FINGERPRINT=$(openssl x509 -fingerprint -sha256 -noout -in $CLIENT_NAME.ovpn | cut -d'=' -f2)

cat > server.conf <<EOF
server 192.168.255.0 255.255.255.0

cert server/server.crt
key server/server.key
dh none

proto udp
port 1194
dev tun
tun-mtu 1400

<peer-fingerprint>
$CLIENT_FINGERPRINT
</peer-fingerprint>

explicit-exit-notify 1

keepalive 10 60

push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"

EOF

rm client.cert privkey.pem
sudo mv server.key server.crt /etc/openvpn/server
sudo mv $CLIENT_NAME.ovpn /etc/openvpn/client
sudo mv server.conf /etc/openvpn
```

That's basically it, we only need to allow traffic to be NATed through the
server. Set `net.ipv4.ip_forward=1` in this file:

```shell
sudo sysctl -w net.ipv4.ip_forward=1
sudo vim /etc/sysctl.conf # edit this file, so that setting is applied after reboot
```

Find your default interface:

```shell
ip route | grep default
```

Output should be like: default via x.x.x.x dev `ens5` proto dhcp src x.x.x.x
metric 100. Remember your interface name and put it to iptables rules below:

```shell
sudo iptables -t nat -A POSTROUTING -o ens5 -j MASQUERADE
sudo iptables -A FORWARD -j ACCEPT
sudo apt-get install iptables-persistent
```

When you install iptables-persistent it will ask you to save current rules into
file, just agree with that and then start the service:

```shell
sudo systemctl enable openvpn@server
sudo systemctl start openvpn@server
```

Now you can download `$CLIENT_NAME.ovpn` to your machine and start browsing internet securely:

```shell
scp ubuntu@<server-ip>:/etc/openvpn/client/<client-name>.ovpn ./
sudo openvpn <client-name>.ovpn
```
