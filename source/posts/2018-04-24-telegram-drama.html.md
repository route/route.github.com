---
title: Telegram drama
tags: network, gpon
description: Investigation on how telegram is blocked in Russia
---

In my childhood internet and network looked like a magick. In the movies they
showed something like ping output and I definitely thought that someone hacked
someone else.

<img src="/images/hackers.png" class="img-fluid" alt="hackers">

### The beginning of story
Recently media regulator Roskomnadzor started to block Telegram IP addresses
because the latter denied giving goverment keys to decipher messages. It goes
without saying that it's creepy but among other things Roskomnadzor blocked like
roughly 18m of IP addresses. It happened because Telegram used services publicly
provided by AWS and other big companies. Here I should say that's exactly the
reason these companies exist lol they provide services. Roskomnadzor started to
block these IPs and Telegram started to use other IPs and so on. The post is not
about how secure Telegram is or why it doesn't provide secure E2E encrypted
channels by default. In general it's about freedom to talk to each other, browse
internet and live privately and by the way tools you can use to debug network.

### The debugging
As usually this morning I tried to connect to one of our web services and it
timed out. ICMP traffic wasn't blocked though. Let's say a domain for this
server was `example.com` with IP address `x.x.x.x` and my PC had white IP
address `y.y.y.y`.

```shell
$ ping example.com
PING x.x.x.x: 64 data bytes
72 bytes from x.x.x.x: seq=0 ttl=52 time=141.242 ms
72 bytes from x.x.x.x: seq=1 ttl=52 time=140.809 ms

2 packets transmitted, 2 packets received, 0% packet loss
round-trip min/avg/max = 140.702/140.918/141.242 ms
```

Ping goes smoothly but providers can block resources using different techniques
starting from DNS spoofing and ending by DPI. If I want to open [rutracker.org](http://rutracker.org)
for example my ISP redirects me to its own [page](http://warning.rt.ru/?id=9&st=0&dt=195.82.146.214&rs=http%3A%2F%2Frutracker.org%2Fforum%2Findex.php)
showing that this address was in fact blocked by goverment. Though it's not the
case for `x.x.x.x` where HTTP traffic disappears silently. Opening
`chrome://net-internals` sometimes is very intersting and confirms time out:

```text
14057: URL_REQUEST
https://example.com/
Start Time: 2018-04-24 08:07:06.009

t=144674 [st=    0] +REQUEST_ALIVE  [dt=24521]
                     --> priority = "HIGHEST"
                     --> url = "https://example.com/"
t=144674 [st=    0]    URL_REQUEST_DELEGATE  [dt=0]
t=144674 [st=    0]   +URL_REQUEST_START_JOB  [dt=24521]
                       --> load_flags = 4353 (MAIN_FRAME_DEPRECATED | VALIDATE_CACHE | VERIFY_EV_CERT)
                       --> method = "GET"
                       --> url = "https://example.com/"
t=144674 [st=    0]      URL_REQUEST_DELEGATE  [dt=0]
t=144674 [st=    0]      HTTP_CACHE_GET_BACKEND  [dt=0]
t=144674 [st=    0]      HTTP_CACHE_OPEN_ENTRY  [dt=0]
                         --> net_error = -2 (ERR_FAILED)
t=144674 [st=    0]      HTTP_CACHE_CREATE_ENTRY  [dt=0]
t=144674 [st=    0]      HTTP_CACHE_ADD_TO_ENTRY  [dt=1]
t=144675 [st=    1]     +HTTP_STREAM_REQUEST  [dt=24520]
t=144675 [st=    1]        HTTP_STREAM_JOB_CONTROLLER_BOUND
                           --> source_dependency = 14060 (HTTP_STREAM_JOB_CONTROLLER)
t=169195 [st=24521]        HTTP_STREAM_REQUEST_BOUND_TO_JOB
                           --> source_dependency = 14061 (HTTP_STREAM_JOB)
t=169195 [st=24521]     -HTTP_STREAM_REQUEST
t=169195 [st=24521]   -URL_REQUEST_START_JOB
                       --> net_error = -118 (ERR_CONNECTION_TIMED_OUT)
t=169195 [st=24521]    URL_REQUEST_DELEGATE  [dt=0]
t=169195 [st=24521] -REQUEST_ALIVE
                     --> net_error = -118 (ERR_CONNECTION_TIMED_OUT)
```

Traceroute from my machine to this IP shows a few intermidiate backbone providers:

```shell
traceroute to example.com (x.x.x.x), 30 hops max, 60 byte packets
 1  gateway (192.168.0.1)  0.417 ms  0.484 ms  0.568 ms
 2  100.103.0.1 (100.103.0.1)  4.935 ms  4.992 ms  5.020 ms
 3  213.59.232.208 (213.59.232.208)  38.910 ms 213.59.232.204 (213.59.232.204)  5.076 ms 213.59.232.208 (213.59.232.208)  5.339 ms
 4  87.226.146.65 (87.226.146.65)  6.112 ms 87.226.146.63 (87.226.146.63)  6.889 ms  6.970 ms
 5  87.226.146.58 (87.226.146.58)  20.707 ms  20.892 ms  20.702 ms
 6  213.59.212.235 (213.59.212.235)  20.632 ms  16.806 ms  17.437 ms
 7  rostelecom.demarc.cogentco.com (149.11.20.138)  63.077 ms  63.722 ms  64.571 ms
 8  hu0-1-0-4.rcr22.fra06.atlas.cogentco.com (149.11.20.137)  57.615 ms  58.457 ms  58.454 ms
 9  be2845.ccr41.fra03.atlas.cogentco.com (154.54.56.189)  58.463 ms be2846.ccr42.fra03.atlas.cogentco.com (154.54.37.29)  66.791 ms be2845.ccr41.fra03.atlas.cogentco.com (154.54.56.189)  59.662 ms
10  be3187.agr41.fra03.atlas.cogentco.com (130.117.1.117)  63.433 ms be3186.agr41.fra03.atlas.cogentco.com (130.117.0.2)  64.132 ms be3187.agr41.fra03.atlas.cogentco.com (130.117.1.117)  63.998 ms
11  telia.fra03.atlas.cogentco.com (130.117.14.198)  70.302 ms  70.477 ms  70.480 ms
12  ffm-bb3-link.telia.net (62.115.133.34)  168.162 ms ffm-bb4-link.telia.net (62.115.125.218)  140.360 ms ffm-bb3-link.telia.net (62.115.120.3)  165.617 ms
13  prs-bb3-link.telia.net (62.115.123.13)  171.186 ms  171.374 ms  169.994 ms
14  nyk-bb3-link.telia.net (213.155.135.5)  164.382 ms nyk-bb4-link.telia.net (80.91.251.100)  149.359 ms  150.275 ms
15  nyk-b3-link.telia.net (62.115.140.223)  163.973 ms hbg-bb1-link.telia.net (80.91.249.11)  177.416 ms  177.405 ms
16  digitalocean-ic-306498-nyk-b3.c.telia.net (62.115.45.10)  145.430 ms  145.572 ms  158.371 ms
17  * * *
18  x.x.x.x (x.x.x.x)  154.054 ms  140.789 ms  141.688 ms
```

While backwards from the droplet there's only one of them:

```shell
traceroute to y.y.y.y (y.y.y.y), 30 hops max, 60 byte packets
 1  159.89.176.253 (159.89.176.253)  0.290 ms  0.263 ms  0.231 ms
 2  138.197.248.28 (138.197.248.28)  0.478 ms  0.469 ms  0.456 ms
 3  nyk-b3-link.telia.net (62.115.45.9)  1.021 ms  1.058 ms  1.043 ms
 4  nyk-bb3-link.telia.net (62.115.140.222)  1.153 ms nyk-bb4-link.telia.net (62.115.139.150)  1.523 ms nyk-bb3-link.telia.net (62.115.140.222)  1.111 ms
 5  prs-bb4-link.telia.net (80.91.251.101)  71.869 ms prs-bb3-link.telia.net (213.155.135.4)  106.781 ms  107.322 ms
 6  prs-bb3-link.telia.net (62.115.134.92)  88.216 ms  88.162 ms ffm-bb4-link.telia.net (62.115.122.139)  81.890 ms
 7  ffm-b1-link.telia.net (62.115.141.237)  93.304 ms ffm-bb3-link.telia.net (62.115.123.12)  101.734 ms  102.168 ms
 8  rostelecom-ic-319651-ffm-b1.c.telia.net (62.115.151.97)  156.199 ms  156.187 ms  156.198 ms
 9  213.59.212.103 (213.59.212.103)  138.304 ms  149.985 ms rostelecom-ic-319651-ffm-b1.c.telia.net (62.115.151.97)  158.270 ms
10  y.y.y.y (y.y.y.y)  139.571 ms  139.690 ms  139.701 ms
```

The difference can be explained by dynamic routing. Since routes are described
by [BGP](https://en.wikipedia.org/wiki/Border_Gateway_Protocol) even a few
sequential traceroutes can show different routes. In BGP realm the trust is
above everything. This site [bgpstream.com](https://bgpstream.com/) can be very
interesting if you are into it. Though the route from DO is twice as shorter
then from Rostelekom. Let's monitor outgoing and incoming traffic for this IP on
one window open curl and tcpdump on another:

```shell
$ curl http://example.com
curl: (7) Failed to connect to example.com port 80: Connection timed out
```

```shell
$ sudo tcpdump -nn -vvv -i enp4s0 dst x.x.x.x or src x.x.x.x
tcpdump: listening on enp4s0, link-type EN10MB (Ethernet), capture size 262144 bytes
23:38:18.908971 IP (tos 0x0, ttl 64, id 59563, offset 0, flags [DF], proto TCP (6), length 60)
    192.168.0.13.41722 > x.x.x.x.80: Flags [S], cksum 0xd52f (correct), seq 1092877667, win 29200, options [mss 1460,sackOK,TS val 3908771289 ecr 0,nop,wscale 7], length 0
23:38:18.925014 IP (tos 0x0, ttl 58, id 1, offset 0, flags [none], proto TCP (6), length 40)
    x.x.x.x.80 > 192.168.0.13.41722: Flags [R], cksum 0x43e5 (correct), seq 0, win 29200, length 0
23:38:19.932815 IP (tos 0x0, ttl 64, id 59564, offset 0, flags [DF], proto TCP (6), length 60)
    192.168.0.13.41722 > x.x.x.x.80: Flags [S], cksum 0xd12f (correct), seq 1092877667, win 29200, options [mss 1460,sackOK,TS val 3908772313 ecr 0,nop,wscale 7], length 0
23:38:19.948956 IP (tos 0x0, ttl 58, id 1, offset 0, flags [none], proto TCP (6), length 40)
    x.x.x.x.80 > 192.168.0.13.41722: Flags [R], cksum 0x43e5 (correct), seq 0, win 29200, length 0
```

3-Way TCP Handshake should be (SYN, SYN-ACK, ACK). Instead we see RST packet
right after SYN. You can see them as [S] and [R] flags. In other words all
outgoing http traffic dropped in the middle and instead we are sent RST packet.
Let's send an outgoing packet from the droplet with source port 80 to home
router on port 80:

```shell
$ yes | nc -p 80 -t y.y.y.y 80

$ sudo tcpdump -nn -vvv -i eth0 dst y.y.y.y and dst port 80 or src y.y.y.y and dst port 80
tcpdump: listening on eth0, link-type EN10MB (Ethernet), capture size 262144 bytes
05:39:49.968049 IP (tos 0x0, ttl 64, id 18207, offset 0, flags [DF], proto TCP (6), length 60)
    x.x.x.x.80 > y.y.y.y.80: Flags [S], cksum 0x6e4e (incorrect -> 0x16e9), seq 3260122744, win 29200, options [mss 1460,sackOK,TS val 1175830887 ecr 0,nop,wscale 7], length 0
05:39:50.109076 IP (tos 0x28, ttl 49, id 0, offset 0, flags [DF], proto TCP (6), length 60)
    y.y.y.y.80 > x.x.x.x.80: Flags [S.], cksum 0x83e9 (correct), seq 3723973951, ack 3260122745, win 28960, options [mss 1440,sackOK,TS val 3637479403 ecr 1175830887,nop,wscale 7], length 0
05:39:50.109117 IP (tos 0x0, ttl 64, id 18208, offset 0, flags [DF], proto TCP (6), length 52)
    x.x.x.x.80 > y.y.y.y.80: Flags [.], cksum 0x6e46 (incorrect -> 0x22b9), seq 1, ack 1, win 229, options [nop,nop,TS val 1175830923 ecr 3637479403], length 0
05:39:50.109230 IP (tos 0x0, ttl 64, id 18209, offset 0, flags [DF], proto TCP (6), length 2100)
    x.x.x.x.80 > y.y.y.y.80: Flags [P.], cksum 0x7646 (incorrect -> 0xf0cc), seq 1:2049, ack 1, win 229, options [nop,nop,TS val 1175830923 ecr 3637479403], length 2048: HTTP
05:39:50.109280 IP (tos 0x0, ttl 64, id 18211, offset 0, flags [DF], proto TCP (6), length 1480)
    x.x.x.x.80 > y.y.y.y.80: Flags [.], cksum 0x73da (incorrect -> 0x7def), seq 2049:3477, ack 1, win 229, options [nop,nop,TS val 1175830923 ecr 3637479403], length 1428: HTTP
05:39:50.109299 IP (tos 0x0, ttl 64, id 18212, offset 0, flags [DF], proto TCP (6), length 1480)
    x.x.x.x.80 > y.y.y.y.80: Flags [.], cksum 0x73da (incorrect -> 0x785b), seq 3477:4905, ack 1, win 229, options [nop,nop,TS val 1175830923 ecr 3637479403], length 1428: HTTP
05:39:50.109331 IP (tos 0x0, ttl 64, id 18213, offset 0, flags [DF], proto TCP (6), length 2908)
    x.x.x.x.80 > y.y.y.y.80: Flags [.], cksum 0x796e (incorrect -> 0xd5fd), seq 4905:7761, ack 1, win 229, options [nop,nop,TS val 1175830923 ecr 3637479403], length 2856: HTTP
05:39:50.109349 IP (tos 0x0, ttl 64, id 18215, offset 0, flags [DF], proto TCP (6), length 1480)
    x.x.x.x.80 > y.y.y.y.80: Flags [.], cksum 0x73da (incorrect -> 0x679f), seq 7761:9189, ack 1, win 229, options [nop,nop,TS val 1175830923 ecr 3637479403], length 1428: HTTP
05:39:50.109371 IP (tos 0x0, ttl 64, id 18216, offset 0, flags [DF], proto TCP (6), length 2908)
    x.x.x.x.80 > y.y.y.y.80: Flags [.], cksum 0x796e (incorrect -> 0xc541), seq 9189:12045, ack 1, win 229, options [nop,nop,TS val 1175830923 ecr 3637479403], length 2856: HTTP
05:39:50.109390 IP (tos 0x0, ttl 64, id 18218, offset 0, flags [DF], proto TCP (6), length 1480)
    x.x.x.x.80 > y.y.y.y.80: Flags [.], cksum 0x73da (incorrect -> 0x56e3), seq 12045:13473, ack 1, win 229, options [nop,nop,TS val 1175830923 ecr 3637479403], length 1428: HTTP
05:39:50.251998 IP (tos 0x28, ttl 49, id 34134, offset 0, flags [DF], proto TCP (6), length 40)
    y.y.y.y.80 > x.x.x.x.80: Flags [R], cksum 0x0de9 (correct), seq 3723973952, win 0, length 0
05:39:50.252020 IP (tos 0x28, ttl 49, id 34135, offset 0, flags [DF], proto TCP (6), length 40)
```

TCP handshake and reset after all but they at least exchanged a few packets.
I wonder if we can catch where exactly http traffic drops. With traceroute we can
see where ICMP packets go but does that mean HTTP goes the same direction?
traceroute supports other options for example you can trace tcp SYN packets:
`traceroute -T -O syn —port=80 -n -N 1 -q 1 x.x.x.x`. The tool creates packets
manually so that they are only 44 bytes long and they pass DPI see SYN-ACK:

```
10:34:34.815998 IP (tos 0x0, ttl 19, id 61933, offset 0, flags [none], proto TCP (6), length 44)
    y.y.y.y.58057 > x.x.x.x.80: Flags [S], cksum 0x61ef (correct), seq 3848879829, win 5840, options [mss 1460], length 0
  0x0000:  4500 002c f1ed 0000 1306 9dd0 c0a8 0002  E..,............
  0x0010:  9f59 b80a e2c9 0050 e569 3ed5 0000 0000  .Y.....P.i>.....
  0x0020:  6002 16d0 61ef 0000 0204 05b4            `...a.......
10:34:34.974844 IP (tos 0x0, ttl 51, id 0, offset 0, flags [DF], proto TCP (6), length 44)
    x.x.x.x.80 > y.y.y.y.58057: Flags [S.], cksum 0x0feb (correct), seq 2544066339, ack 3848879830, win 29200, options [mss 1440], length 0
  0x0000:  4500 002c 0000 4000 3306 2fbe 9f59 b80a  E..,..@.3./..Y..
  0x0010:  c0a8 0002 0050 e2c9 97a3 5f23 e569 3ed6  .....P...._#.i>.
  0x0020:  6012 7210 0feb 0000 0204 05a0 0000       `.r...........
10:34:34.974909 IP (tos 0x0, ttl 64, id 61944, offset 0, flags [DF], proto TCP (6), length 40)
    y.y.y.y.58057 > x.x.x.x.80: Flags [R], cksum 0x9078 (correct), seq 3848879830, win 0, length 0
  0x0000:  4500 0028 f1f8 4000 4006 30c9 c0a8 0002  E..(..@.@.0.....
  0x0010:  9f59 b80a e2c9 0050 e569 3ed6 0000 0000  .Y.....P.i>.....
  0x0020:  5004 0000 9078 0000                      P....x..
```

The real SYN packet from browser is 60 bytes and DPI drops it:

```
10:33:48.537807 IP (tos 0x0, ttl 19, id 54902, offset 0, flags [none], proto TCP (6), length 60)
    y.y.y.y.42193 > x.x.x.x.80: Flags [S], cksum 0xe900 (correct), seq 2785663221, win 5840, options [mss 1460,sackOK,TS val 1652926847 ecr 0,nop,wscale 2], length 0
  0x0000:  4500 003c d676 0000 1306 b937 c0a8 0002  E..<.v.....7....
  0x0010:  9f59 b80a a4d1 0050 a609 d8f5 0000 0000  .Y.....P........
  0x0020:  a002 16d0 e900 0000 0204 05b4 0402 080a  ................
  0x0030:  6285 a97f 0000 0000 0103 0302            b...........
10:33:48.563619 IP (tos 0x0, ttl 8, id 1, offset 0, flags [none], proto TCP (6), length 40)
    x.x.x.x.80 > y.y.y.y.42193: Flags [R], cksum 0x5ce1 (correct), seq 0, win 5840, length 0
  0x0000:  4500 0028 0001 0000 0806 9ac1 9f59 b80a  E..(.........Y..
  0x0010:  c0a8 0002 0050 a4d1 0000 0000 a609 d8f5  .....P..........
  0x0020:  5004 16d0 5ce1 0000 0000 0000 0000       P...\.........
```

This all suggests that provider definitely dropped packets while they said they
didn't to me.

Overall I feel disappointed about the road internet march nowadays. It started
like a small network with purpose of exchanging data for research, helping
humankind to solve issues or at least doing something meaningful.
Instead I feel more like a resource that big company can sell and goverment can
control limiting my view. They all either earn money or get benefit trading you
but the thing is you don't get anything out of it.

### A few words about GPON

The text below is true for many ISPs. There are many downsides of GPON you can
read articles about it in the footer but for me it's inability to set up my own
or at least high quality router instead of the one given by provider. You as a
customer will rent a router from them. The router usually goes with buggy
firmware, remote access for provider and inability to set it to the bridge mode.
In other words it is a useless piece of trash which you will own as you redeem
it during 2 years and you cannot buy another one and replace this shit because
it simply won't work with GPON. Also [Rostelekom is the biggest player](https://habr.com/post/113086/)
in Russia and has tight realtionship with goverment so I prefer stayng as far
away as possible from them and pay to a smaller provider to keep it on the air.

### A way to bypass restrictions

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

* [Cyberspace independence](https://www.eff.org/cyberspace-independence)
* [Decentralization](http://www.lookatme.ru/mag/magazine/russian-internet/207489-decentralization)
* [The mission to decentralize the internet](https://www.newyorker.com/tech/elements/the-mission-to-decentralize-the-internet)
* [Could it happen in your country](https://dyn.com/blog/could-it-happen-in-your-countr/)
* [Vast world of fraudulent routing](https://dyn.com/blog/vast-world-of-fraudulent-routing/)
* [Latest ISPs to hijack](https://dyn.com/blog/latest-isps-to-hijack/)
* [GPON FTTH networks (in)security](https://pierrekim.github.io/blog/2016-11-01-gpon-ftth-networks-insecurity.html)
* [Lurkmore GPON](https://lurkmore.to/GPON)
