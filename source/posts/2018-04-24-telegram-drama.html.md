---
title: Telegram drama
tags: network
description: Bypass telegram blocks in Russia
---

In my childhood internet and network looked like a magick. In movies they showed
something like ping output and I definitely thought that someone hacked someone
else.

<img src="/images/hackers.png" class="img-fluid" alt="hackers">

I'm located in Russia and I work for Chicago based startup thanks 21st century
for remote. We have our servers on AWS and DigitalOcean. Thereon this long
summer story ends as bloody winter is coming.

Recently media regulator Roskomnadzor started to block Telegram IP addresses
because the latter denied giving goverment keys to decipher messages. It goes
without saying that it's creepy but among other things Roskomnadzor blocked like
roughly 18kk of IP addresses. It happened because Telegram uses services
publicly provided by AWS and other big companies. Here I should say that's
exactly the reason these companies exist lol they provide services. Roskomnadzor
started to block these IPs and Telegram as it's an application using push
notifications (correct me if I'm wrong) started to use other IPs and so on and
so on. The post is not about how secure Telegram is or why it doesn't provide
secure E2E channels by default. It's about not giving up freedom to talk to each
other privately.

As usually this morning I tried to connect to one of our web services and
surprise what? It timed out. ICMP traffic wasn't blocked though. Let's say a
domain for this server for simplification is `a.com`.

```shell
$ ping a.com
PING 159.89.184.10: 64 data bytes
72 bytes from 159.89.184.10: seq=0 ttl=52 time=141.242 ms
72 bytes from 159.89.184.10: seq=1 ttl=52 time=140.809 ms
72 bytes from 159.89.184.10: seq=2 ttl=52 time=141.031 ms
72 bytes from 159.89.184.10: seq=3 ttl=52 time=140.702 ms
72 bytes from 159.89.184.10: seq=4 ttl=52 time=140.808 ms

5 packets transmitted, 5 packets received, 0% packet loss
round-trip min/avg/max = 140.702/140.918/141.242 ms
```

You would say so what? I'll tell you that for example if I want to open torrent
tracker [rutracker.org](http://rutracker.org) (which has been blocked for years
in Russia) ISP redirects me to its [own page](http://warning.rt.ru/?id=9&st=0&dt=195.82.146.214&rs=http%3A%2F%2Frutracker.org%2Fforum%2Findex.php)
showing that this address was in fact blocked by goverment. Surprisingly it's
not the case for `159.89.184.10`. HTTP traffic disappears silently. So first
thing we go to [eais.rkn.gov.ru](https://eais.rkn.gov.ru/) to check if the
address is really blocked. It says it's all clear no blocks, nothing. Ok we go
to ISP (hello [Rostelekom](http://rt.ru)) then.

Below in this post I provide full conversations with ISP and DigitalOcean but
long story short after ISP checked everything on their end they called me
saying that they don't block it as well as Roskomnadzor. So most likely it's
DigitalOcean who blocks it. As you wish guys... I go to DigitalOcean and
together we investigate it. Opening `chrome://net-internals` is very intersting
sometimes and confirms time out:

```text
14057: URL_REQUEST
https://a.com/
Start Time: 2018-04-24 08:07:06.009

t=144674 [st=    0] +REQUEST_ALIVE  [dt=24521]
                     --> priority = "HIGHEST"
                     --> url = "https://a.com/"
t=144674 [st=    0]    URL_REQUEST_DELEGATE  [dt=0]
t=144674 [st=    0]   +URL_REQUEST_START_JOB  [dt=24521]
                       --> load_flags = 4353 (MAIN_FRAME_DEPRECATED | VALIDATE_CACHE | VERIFY_EV_CERT)
                       --> method = "GET"
                       --> url = "https://a.com/"
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
traceroute to a.com (159.89.184.10), 30 hops max, 60 byte packets
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
18  159.89.184.10 (159.89.184.10)  154.054 ms  140.789 ms  141.688 ms
```

While in reverse from the droplet there's only one of them:

```shell
traceroute to 95.32.215.86 (95.32.215.86), 30 hops max, 60 byte packets
 1  159.89.176.253 (159.89.176.253)  0.290 ms  0.263 ms  0.231 ms
 2  138.197.248.28 (138.197.248.28)  0.478 ms  0.469 ms  0.456 ms
 3  nyk-b3-link.telia.net (62.115.45.9)  1.021 ms  1.058 ms  1.043 ms
 4  nyk-bb3-link.telia.net (62.115.140.222)  1.153 ms nyk-bb4-link.telia.net (62.115.139.150)  1.523 ms nyk-bb3-link.telia.net (62.115.140.222)  1.111 ms
 5  prs-bb4-link.telia.net (80.91.251.101)  71.869 ms prs-bb3-link.telia.net (213.155.135.4)  106.781 ms  107.322 ms
 6  prs-bb3-link.telia.net (62.115.134.92)  88.216 ms  88.162 ms ffm-bb4-link.telia.net (62.115.122.139)  81.890 ms
 7  ffm-b1-link.telia.net (62.115.141.237)  93.304 ms ffm-bb3-link.telia.net (62.115.123.12)  101.734 ms  102.168 ms
 8  rostelecom-ic-319651-ffm-b1.c.telia.net (62.115.151.97)  156.199 ms  156.187 ms  156.198 ms
 9  213.59.212.103 (213.59.212.103)  138.304 ms  149.985 ms rostelecom-ic-319651-ffm-b1.c.telia.net (62.115.151.97)  158.270 ms
10  86.215.32.95.dsl-dynamic.vsi.ru (95.32.215.86)  139.571 ms  139.690 ms  139.701 ms
```
BGP might have an answer why the route changes. I found pretty interesting site
BTW [bgpstream.com](https://bgpstream.com/)

Let's monitor outgoing and incoming traffic:

```shell
$ curl http://a.com
curl: (7) Failed to connect to a.com port 80: Connection timed out

$ sudo tcpdump -nn -vvv -i enp4s0 dst 159.89.184.10 or src 159.89.184.10
tcpdump: listening on enp4s0, link-type EN10MB (Ethernet), capture size 262144 bytes
23:38:18.908971 IP (tos 0x0, ttl 64, id 59563, offset 0, flags [DF], proto TCP (6), length 60)
    192.168.0.13.41722 > 159.89.184.10.80: Flags [S], cksum 0xd52f (correct), seq 1092877667, win 29200, options [mss 1460,sackOK,TS val 3908771289 ecr 0,nop,wscale 7], length 0
23:38:18.925014 IP (tos 0x0, ttl 58, id 1, offset 0, flags [none], proto TCP (6), length 40)
    159.89.184.10.80 > 192.168.0.13.41722: Flags [R], cksum 0x43e5 (correct), seq 0, win 29200, length 0
23:38:19.932815 IP (tos 0x0, ttl 64, id 59564, offset 0, flags [DF], proto TCP (6), length 60)
    192.168.0.13.41722 > 159.89.184.10.80: Flags [S], cksum 0xd12f (correct), seq 1092877667, win 29200, options [mss 1460,sackOK,TS val 3908772313 ecr 0,nop,wscale 7], length 0
23:38:19.948956 IP (tos 0x0, ttl 58, id 1, offset 0, flags [none], proto TCP (6), length 40)
    159.89.184.10.80 > 192.168.0.13.41722: Flags [R], cksum 0x43e5 (correct), seq 0, win 29200, length 0
23:38:21.948826 IP (tos 0x0, ttl 64, id 59565, offset 0, flags [DF], proto TCP (6), length 60)
    192.168.0.13.41722 > 159.89.184.10.80: Flags [S], cksum 0xc94f (correct), seq 1092877667, win 29200, options [mss 1460,sackOK,TS val 3908774329 ecr 0,nop,wscale 7], length 0
23:38:21.965036 IP (tos 0x0, ttl 58, id 1, offset 0, flags [none], proto TCP (6), length 40)
    159.89.184.10.80 > 192.168.0.13.41722: Flags [R], cksum 0x43e5 (correct), seq 0, win 29200, length 0
23:38:26.044817 IP (tos 0x0, ttl 64, id 59566, offset 0, flags [DF], proto TCP (6), length 60)
    192.168.0.13.41722 > 159.89.184.10.80: Flags [S], cksum 0xb94f (correct), seq 1092877667, win 29200, options [mss 1460,sackOK,TS val 3908778425 ecr 0,nop,wscale 7], length 0
23:38:26.061047 IP (tos 0x0, ttl 58, id 1, offset 0, flags [none], proto TCP (6), length 40)
    159.89.184.10.80 > 192.168.0.13.41722: Flags [R], cksum 0x43e5 (correct), seq 0, win 29200, length 0
23:38:34.236838 IP (tos 0x0, ttl 64, id 59567, offset 0, flags [DF], proto TCP (6), length 60)
    192.168.0.13.41722 > 159.89.184.10.80: Flags [S], cksum 0x994f (correct), seq 1092877667, win 29200, options [mss 1460,sackOK,TS val 3908786617 ecr 0,nop,wscale 7], length 0
23:38:34.252685 IP (tos 0x0, ttl 58, id 1, offset 0, flags [none], proto TCP (6), length 40)
    159.89.184.10.80 > 192.168.0.13.41722: Flags [R], cksum 0x43e5 (correct), seq 0, win 29200, length 0
23:38:50.364856 IP (tos 0x0, ttl 64, id 59568, offset 0, flags [DF], proto TCP (6), length 60)
    192.168.0.13.41722 > 159.89.184.10.80: Flags [S], cksum 0x5a4e (correct), seq 1092877667, win 29200, options [mss 1460,sackOK,TS val 3908802746 ecr 0,nop,wscale 7], length 0
23:38:50.381002 IP (tos 0x0, ttl 58, id 1, offset 0, flags [none], proto TCP (6), length 40)
    159.89.184.10.80 > 192.168.0.13.41722: Flags [R], cksum 0x43e5 (correct), seq 0, win 29200, length 0
23:39:22.620807 IP (tos 0x0, ttl 64, id 59569, offset 0, flags [DF], proto TCP (6), length 60)
    192.168.0.13.41722 > 159.89.184.10.80: Flags [S], cksum 0xdc4d (correct), seq 1092877667, win 29200, options [mss 1460,sackOK,TS val 3908835002 ecr 0,nop,wscale 7], length 0
23:39:22.637077 IP (tos 0x0, ttl 58, id 1, offset 0, flags [none], proto TCP (6), length 40)
    159.89.184.10.80 > 192.168.0.13.41722: Flags [R], cksum 0x43e5 (correct), seq 0, win 29200, length 0
```
Goodbye 3-Way TCP Handshake which should be (SYN, SYN-ACK, ACK) and hello RST
after SYN. You can see them as [S] and [R] flags. In other words all outgoing
http traffic dropped in the middle. Does it mean Roskomnadzor no longer needs
ISP to handle this crap or ISP is lying? If a girl says who blocks servers
a man will feed her.

![The girl is no one](https://pbs.twimg.com/media/DbhrAF_WAAAE80q.jpg)

Let's try it other way around. I set port mapping on my router to give an
ability for incoming http request go behind it and reach Ngnix on my PC.

We ssh into the droplet and try to connect with curl:

```shell
$ curl http://95.32.183.155
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>

$ sudo tcpdump -nn -vvv -i eth0 dst 95.32.183.155 and dst port 80 or src 95.32.183.155 and dst port 80
05:40:20.044097 IP (tos 0x0, ttl 64, id 14142, offset 0, flags [DF], proto TCP (6), length 60)
    159.89.184.10.55928 > 95.32.183.155.80: Flags [S], cksum 0x6e4e (incorrect -> 0x2b0c), seq 1395059192, win 29200, options [mss 1460,sackOK,TS val 1175838406 ecr 0,nop,wscale 7], length 0
05:40:20.196601 IP (tos 0x0, ttl 64, id 14143, offset 0, flags [DF], proto TCP (6), length 52)
    159.89.184.10.55928 > 95.32.183.155.80: Flags [.], cksum 0x6e46 (incorrect -> 0xd836), seq 1395059193, ack 1061805333, win 229, options [nop,nop,TS val 1175838444 ecr 3637509479], length 0
05:40:20.196784 IP (tos 0x0, ttl 64, id 14144, offset 0, flags [DF], proto TCP (6), length 129)
    159.89.184.10.55928 > 95.32.183.155.80: Flags [P.], cksum 0x6e93 (incorrect -> 0x40c3), seq 0:77, ack 1, win 229, options [nop,nop,TS val 1175838445 ecr 3637509479], length 77: HTTP, length: 77
	GET / HTTP/1.1
	Host: 95.32.183.155
	User-Agent: curl/7.47.0
	Accept: */*

05:40:20.350596 IP (tos 0x0, ttl 64, id 14145, offset 0, flags [DF], proto TCP (6), length 52)
    159.89.184.10.55928 > 95.32.183.155.80: Flags [.], cksum 0x6e46 (incorrect -> 0xd3c1), seq 77, ack 860, win 242, options [nop,nop,TS val 1175838483 ecr 3637509632], length 0
05:40:20.350809 IP (tos 0x0, ttl 64, id 14146, offset 0, flags [DF], proto TCP (6), length 52)
    159.89.184.10.55928 > 95.32.183.155.80: Flags [F.], cksum 0x6e46 (incorrect -> 0xd3c0), seq 77, ack 860, win 242, options [nop,nop,TS val 1175838483 ecr 3637509632], length 0
05:40:20.503792 IP (tos 0x0, ttl 64, id 14147, offset 0, flags [DF], proto TCP (6), length 52)
    159.89.184.10.55928 > 95.32.183.155.80: Flags [.], cksum 0x6e46 (incorrect -> 0xd2ff), seq 78, ack 861, win 242, options [nop,nop,TS val 1175838521 ecr 3637509786], length 0
```

It works. Let's send an outdoing packet from the droplet with source port 80:

```shell
$ yes | nc -p 80 -t 95.32.183.155 80

$ sudo tcpdump -nn -vvv -i eth0 dst 95.32.183.155 and dst port 80 or src 95.32.183.155 and dst port 80
tcpdump: listening on eth0, link-type EN10MB (Ethernet), capture size 262144 bytes
05:39:49.968049 IP (tos 0x0, ttl 64, id 18207, offset 0, flags [DF], proto TCP (6), length 60)
    159.89.184.10.80 > 95.32.183.155.80: Flags [S], cksum 0x6e4e (incorrect -> 0x16e9), seq 3260122744, win 29200, options [mss 1460,sackOK,TS val 1175830887 ecr 0,nop,wscale 7], length 0
05:39:50.109076 IP (tos 0x28, ttl 49, id 0, offset 0, flags [DF], proto TCP (6), length 60)
    95.32.183.155.80 > 159.89.184.10.80: Flags [S.], cksum 0x83e9 (correct), seq 3723973951, ack 3260122745, win 28960, options [mss 1440,sackOK,TS val 3637479403 ecr 1175830887,nop,wscale 7], length 0
05:39:50.109117 IP (tos 0x0, ttl 64, id 18208, offset 0, flags [DF], proto TCP (6), length 52)
    159.89.184.10.80 > 95.32.183.155.80: Flags [.], cksum 0x6e46 (incorrect -> 0x22b9), seq 1, ack 1, win 229, options [nop,nop,TS val 1175830923 ecr 3637479403], length 0
05:39:50.109230 IP (tos 0x0, ttl 64, id 18209, offset 0, flags [DF], proto TCP (6), length 2100)
    159.89.184.10.80 > 95.32.183.155.80: Flags [P.], cksum 0x7646 (incorrect -> 0xf0cc), seq 1:2049, ack 1, win 229, options [nop,nop,TS val 1175830923 ecr 3637479403], length 2048: HTTP
05:39:50.109280 IP (tos 0x0, ttl 64, id 18211, offset 0, flags [DF], proto TCP (6), length 1480)
    159.89.184.10.80 > 95.32.183.155.80: Flags [.], cksum 0x73da (incorrect -> 0x7def), seq 2049:3477, ack 1, win 229, options [nop,nop,TS val 1175830923 ecr 3637479403], length 1428: HTTP
05:39:50.109299 IP (tos 0x0, ttl 64, id 18212, offset 0, flags [DF], proto TCP (6), length 1480)
    159.89.184.10.80 > 95.32.183.155.80: Flags [.], cksum 0x73da (incorrect -> 0x785b), seq 3477:4905, ack 1, win 229, options [nop,nop,TS val 1175830923 ecr 3637479403], length 1428: HTTP
05:39:50.109331 IP (tos 0x0, ttl 64, id 18213, offset 0, flags [DF], proto TCP (6), length 2908)
    159.89.184.10.80 > 95.32.183.155.80: Flags [.], cksum 0x796e (incorrect -> 0xd5fd), seq 4905:7761, ack 1, win 229, options [nop,nop,TS val 1175830923 ecr 3637479403], length 2856: HTTP
05:39:50.109349 IP (tos 0x0, ttl 64, id 18215, offset 0, flags [DF], proto TCP (6), length 1480)
    159.89.184.10.80 > 95.32.183.155.80: Flags [.], cksum 0x73da (incorrect -> 0x679f), seq 7761:9189, ack 1, win 229, options [nop,nop,TS val 1175830923 ecr 3637479403], length 1428: HTTP
05:39:50.109371 IP (tos 0x0, ttl 64, id 18216, offset 0, flags [DF], proto TCP (6), length 2908)
    159.89.184.10.80 > 95.32.183.155.80: Flags [.], cksum 0x796e (incorrect -> 0xc541), seq 9189:12045, ack 1, win 229, options [nop,nop,TS val 1175830923 ecr 3637479403], length 2856: HTTP
05:39:50.109390 IP (tos 0x0, ttl 64, id 18218, offset 0, flags [DF], proto TCP (6), length 1480)
    159.89.184.10.80 > 95.32.183.155.80: Flags [.], cksum 0x73da (incorrect -> 0x56e3), seq 12045:13473, ack 1, win 229, options [nop,nop,TS val 1175830923 ecr 3637479403], length 1428: HTTP
05:39:50.251998 IP (tos 0x28, ttl 49, id 34134, offset 0, flags [DF], proto TCP (6), length 40)
    95.32.183.155.80 > 159.89.184.10.80: Flags [R], cksum 0x0de9 (correct), seq 3723973952, win 0, length 0
05:39:50.252020 IP (tos 0x28, ttl 49, id 34135, offset 0, flags [DF], proto TCP (6), length 40)
```

TCP handshake and reset after all. Looks weird and empty on my side. Now I
wonder if we can catch where exactly http traffic drops. With traceroute we can
see where ICMP packets go but does that mean HTTP goes the same direction and
where it drops? I don't know the answer.

Overall I feel disappointed. It's like Telegram opened a curtain. Internet
started like a small local network with purpose of exchanging data for research,
helping humankind to solve issues or at least doing something meaningful and get
better. Instead it's a place for intertainment controlled by goverment.

If you read until this point there's a small bonus for you:
It's known fact that rutracker is blocked.

```shell
$ curl -vvv http://rutracker.org/forum/index.php
*   Trying 195.82.146.214...
* TCP_NODELAY set
* Connected to rutracker.org (195.82.146.214) port 80 (#0)
> GET /forum/index.php HTTP/1.1
> Host: rutracker.org
> User-Agent: curl/7.55.1
> Accept: */*
>
< HTTP/1.1 302 Found
< Connection: close
< Content-Length: 2
< Location: http://warning.rt.ru/?id=9&st=0&dt=195.82.146.214&rs=http%3A%2F%2Frutracker.org%2Fforum%2Findex.php
<
* Closing connection 0
```

Run this if you have Rostelekom `(printf 'GET /forum/index.php HTTP/1.1\r\nHost: rutracker.org\r\n\r\n'; sleep 1) | nc rutracker.org 80`

and you'll see:

```shell
HTTP/1.1 302 Found
Connection: close
Content-Length: 2
Location: http://warning.rt.ru/?id=9&st=0&dt=195.82.146.214&rs=http%3A%2F%2Frutracker.org%2Fforum%2Findex.php

OK Accept-Encoding
X-BB-ID: rto
X-Frame-Options: SAMEORIGIN

1f90
<!DOCTYPE html>
<html lang="ru">
<head>

<meta charset="Windows-1251">
<meta name="description" content="���������� ������������� ���������� ������. ������� ��������� ������, ������, �����, ���������..">

<title>BitTorrent ������ RuTracker.org</title>
...
```

They intercept traffic and put 302 redirect and below goes original page.
Is that [passive DPI](https://habr.com/post/335436/)? Remove carriage
return headers now and watch plain 200:

```shell
(printf 'GET /forum/index.php HTTP/1.1\nHost: rutracker.org\n\n'; sleep 1) | nc rutracker.org 80

HTTP/1.1 200 OK
Server: nginx
Date: Wed, 25 Apr 2018 10:23:11 GMT
Content-Type: text/html; charset=Windows-1251
Transfer-Encoding: chunked
Connection: keep-alive
Vary: Accept-Encoding
X-BB-ID: rto
X-Frame-Options: SAMEORIGIN

1f90
<!DOCTYPE html>
<html lang="ru">
<head>

<meta charset="Windows-1251">
<meta name="description" content="���������� ������������� ���������� ������. ������� ��������� ������, ������, �����, ���������..">

```

Unfortunately the story for DO is completely different because the traffic is
blocked somwhere in between.

Here I should say that the reason remains unknown and I'll keep you posted.

* [Cyberspace independence](https://www.eff.org/cyberspace-independence)
* [Decentralization](http://www.lookatme.ru/mag/magazine/russian-internet/207489-decentralization)
* [The mission to decentralize the internet](https://www.newyorker.com/tech/elements/the-mission-to-decentralize-the-internet)
* [Could it happen in your country](https://dyn.com/blog/could-it-happen-in-your-countr/)
* [Vast world of fraudulent routing](https://dyn.com/blog/vast-world-of-fraudulent-routing/)
* [Latest ISPs to hijack](https://dyn.com/blog/latest-isps-to-hijack/)

Rostelekom convo:

```text
Вы
Добрый день, скажите почему у меня не открывается http://a.com/

Вы
Здравствуйте!
Меня зовут Игорь, мне понадобится несколько минут для подготовки ответа.
Подождите, пожалуйста.

Игорь
в листе ркн этго адреса нет

Вы
через впн из британии работает

Игорь
На данный момент доступ в интернет предоставляется в полнм объёме.
Со стороны компании данный ресурс не блокируется.

Вы
но у меня не открывается, файлы я приложил
трейсроут, выкладки из хрома, и курл висят
curl: (7) Failed to connect to a.com port 443: Connection timed out

Игорь
Ростелеком не ограничивает доступ к данному ресурсу. Если у Вас работает данный
ресурс через VPN, то ограничения не со стороны компании. Доступ к части
интернет-ресурсов может быть ограничен по решению уполномоченных органов власти.
Срок снятия ограничения пока не определен. Услуга интернет у Вас работает,
воспользуетесь другими интернет-ресурсами для получения необходимой Вам
информации.

Вы
можно тогда информацию кем ограничен доступ если не моим провайдером?

Игорь
Доступ к части интернет-ресурсов может быть ограничен по решению уполномоченных
органов власти.

Вы
кем?

Игорь
За блокировку ресурсов отвечает Роскомнадзор.

Вы
а исполняет ее провайдер я в курсе
если провайдер не блокирует мне нужна информация кто блокирует
если у вас ее нет мне нужен технический или старший специалист. спасибо

Игорь
Доступ к части интернет-ресурсов может быть ограничен по решению уполномоченных
органов власти. За блокировку ресурсов отвечает Роскомнадзор. Технические
специалисты предоставят Вам такую же информацию.

Вы
Игорь вы технический специалист?

Игорь
Информацию по Вашему вопросу я передам специалистам. Назовите, пожалуйста,
контактный номер телефона, как к Вам можно обращаться.

Вы
Спасибо
...

Игорь
Доступ к ресурсу будет проверен с нашей стороны.
По вашему обращению было создано задание № 132147087. В ближайшее время,
Ваш вопрос будет решен. При необходимости, с Вами свяжутся по контактному
номеру телефона. Пожалуйста, не отключайте оборудование от сети.
```

DigitalOcean convo:

```text
*Me*
As you likely aware in Russia they try to block Telegram yet hopelessly. I tried
to connect to one of our servers today without luck. The url was
http://a.com/ (159.89.184.10) and it timed out.
I contacted my provider asking why is that and the answer was they didn't block
it as well as RKN (https://eais.rkn.gov.ru/). Yet this IP address is available
by ICMP and unavailable by http/https here's the log _link_
This IP is available using VPN.

The conclusion was that it is DO who blocks it. May I know if this is true and
you really block it for Russian IPs? My IP was 95.32.215.86

Thanks

*They*
Thank you for your email.
I really appreciate you taking the time to raise a case with us!

We're aware of a disruption in traffic from some areas in Russia to some of our
datacenters (AMS3, LON1, FRA1). It appears that traffic has been blocked at some
other point in the Internet, which is beyond our control. All circuits into
these datacenters are fully functional.

In case, your IP comes to any of those datacenters, we would recommend to
re-deploy. Again, I know this is not an ideal solution, we do apologize for the
inconvenience caused here.

*Me*
Surprisingly it's in NYC3... Do you have an information where at least it's
being blocked in Europe or in Russia?

*They*
Personally, we do not block any IPs and our circuits are fully working.

Would you be able to run an MTR to and fro from your location and vice-versa as
well as an MTR to the Droplet which is reachable from your end, so that we can
review both the MTRs this side.

Rest, if its blocked somewhere outside of our reach, due to the mass block of
IPs within Russia, getting a new IP would be helpful. Rest, we'd be happy to
review the MTR and see if there's any specific hop where it is blocked.

*Me*
Yes I already added it to the log _link_

I've added a traceroute from droplet to my IP as well.

Is that enough?

I'm a bit confused I know that with traceroute we can see where all packets go
but how do we catch we http packets drop. I can connect to
a.com ssh easily. Only http doesn't work :( Someone's
dropping http packets and nobody tells it's him lol :)

*They*
Hey there,
Based on the information you provided, the issue does not appear to be a
network connectivity issue (ping works and the traceroute reaches the
destination) but an issue specifically with the HTTP request timing out,
which is likely something occurring either within the droplet itself or within
your local computer or network configuration.

Does your web server (Apache or Nginx in most cases) show these connections in
the access log, and if so, does the error log contain any information that might
explain why the connections are timing out?

*Me*
I don't see anything in logs on the machine when I try to connect with curl to it

*They*
Are you able to SSH into the droplet, or connect to it in any way other than HTTP?
This appears to be application or web server specific rather than a network
block but this would be a good way to confirm that.

*Me*
Yes exactly I have an access by ssh but http times out.

*They*

Very weird. Do you have any firewall running on this Droplet that may be
inadvertently blocking you via http and https? It looks like visiting your
IP prompts me to log in. Do you have something like fail2ban set up, where too
many failed login attempts would result in an IP block? Can you send me the
output of "ufw status" and "iptables -L"?

So far I'm thinking this is either a firewall issue on the Droplet,
or some sort of weird ISP/Russian issue where they're solely blocking
HTTP/HTTPS for your IP, but I don't know why they'd do that.

*Me*

Nothing:

ufw status
Status: inactive

iptables -L
Chain INPUT (policy ACCEPT)
target prot opt source destination

Chain FORWARD (policy ACCEPT)
target prot opt source destination

Chain OUTPUT (policy ACCEPT)
target prot opt source destination

http and https works for my IP I can reach many sites. Only weird issues with
some like this one. I contacted my ISP they said they didn't block it.
I contacted RKN they said they didn't either. Someone in the middle drops
https packets or smth weird is going on on DO side. I have no clue either...

*They*
This would seem to suggest that there are ISP level blocks of certain IPs and
ranges are happening. I'm located in the US and if I curl 159.89.156.100, I get
a 200 OK response.

There is unfortunately not much we can do about that, since we don't have
control over how your ISP might manage or block traffic. I would recommend
bringing this to the attention of your ISP and seeing if they can confirm if
this is the case or not.
```
