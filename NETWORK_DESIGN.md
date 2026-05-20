# Network Design and Routing Runbook

Last updated: 2026-05-19

## Purpose

This host is acting as a Linux router/NAT gateway between Windows, the switch/LAN networks, and the free5GC UE IP pool.

The current target is to allow these source networks to access the UE pool:

- `10.88.120.0/24` from the Windows/Hyper-V side
- `192.168.3.0/24` from the switch management/LAN side
- `192.168.1.0/24` from the routed LAN behind the switch

The UE pool currently tested is:

- `10.60.0.0/24`
- Example UE: `10.60.0.3`

## Topology

```text
Windows host
  10.88.120.200/24
        |
        | route 10.60.0.0/16 via 10.88.120.100
        v
Linux VM/router
  eth1:
    10.88.120.100/24
    10.88.120.99/24
    192.168.3.89/24

  br-free5gc:
    10.100.200.1/24

  route:
    10.60.0.0/24 via 10.100.200.7 dev br-free5gc

  NAT toward UE pool:
    10.88.120.0/24  -> 10.60.0.0/24 via br-free5gc
    192.168.3.0/24 -> 10.60.0.0/24 via br-free5gc
    192.168.1.0/24 -> 10.60.0.0/24 via br-free5gc
        |
        v
free5GC / UE side
  UE pool: 10.60.0.0/24
  Example UE: 10.60.0.3

Switch/router
  192.168.3.1
        |
        | route 10.60.0.0/24 or 10.60.0.0/16 via 192.168.3.89
        v
Linux VM/router

LAN behind switch/router
  192.168.1.0/24
        |
        | default gateway / route toward 192.168.3.1
        v
Switch/router -> Linux VM/router -> UE pool
```

## Linux VM Router State

Interfaces:

```text
eth1:
  10.88.120.100/24
  10.88.120.99/24
  192.168.3.89/24

br-free5gc:
  10.100.200.1/24

eth0:
  172.30.255.96/20 via DHCP

tailscale0:
  100.123.36.96/32
```

Routes:

```text
default via 172.30.240.1 dev eth0
10.60.0.0/24 via 10.100.200.7 dev br-free5gc
10.88.120.0/24 dev eth1 src 10.88.120.100
10.100.200.0/24 dev br-free5gc src 10.100.200.1
192.168.1.0/24 via 192.168.3.1 dev eth1
192.168.3.0/24 dev eth1 src 192.168.3.89
```

Sysctl:

```text
net.ipv4.ip_forward = 1
net.ipv4.conf.all.rp_filter = 2
net.ipv4.conf.eth1.rp_filter = 2
net.ipv4.conf.br-free5gc.rp_filter = 2
```

Persistent forwarding file:

```text
/etc/sysctl.d/99-forwarding.conf
net.ipv4.ip_forward=1
```

## Linux Firewall and NAT Rules

These rules permit and NAT traffic from the source networks toward the UE pool.

### 192.168.1.0/24 to UE Pool

```bash
sudo iptables -I FORWARD 1 -i eth1 -o br-free5gc -s 192.168.1.0/24 -d 10.60.0.0/24 -j ACCEPT
sudo iptables -I FORWARD 2 -i br-free5gc -o eth1 -s 10.60.0.0/24 -d 192.168.1.0/24 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
sudo iptables -t nat -I POSTROUTING 1 -s 192.168.1.0/24 -d 10.60.0.0/24 -o br-free5gc -j MASQUERADE
```

### 192.168.3.0/24 to UE Pool

```bash
sudo iptables -I FORWARD 1 -i eth1 -o br-free5gc -s 192.168.3.0/24 -d 10.60.0.0/24 -j ACCEPT
sudo iptables -I FORWARD 2 -i br-free5gc -o eth1 -s 10.60.0.0/24 -d 192.168.3.0/24 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
sudo iptables -t nat -I POSTROUTING 1 -s 192.168.3.0/24 -d 10.60.0.0/24 -o br-free5gc -j MASQUERADE
```

### 10.88.120.0/24 to UE Pool

```bash
sudo iptables -I FORWARD 1 -i eth1 -o br-free5gc -s 10.88.120.0/24 -d 10.60.0.0/24 -j ACCEPT
sudo iptables -I FORWARD 2 -i br-free5gc -o eth1 -s 10.60.0.0/24 -d 10.88.120.0/24 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
sudo iptables -t nat -I POSTROUTING 1 -s 10.88.120.0/24 -d 10.60.0.0/24 -o br-free5gc -j MASQUERADE
```

Persist saved rules:

```bash
sudo netfilter-persistent save
```

Check persistence service:

```bash
systemctl is-enabled netfilter-persistent
systemctl is-active netfilter-persistent
```

## Windows Host Routes

The Windows host should send UE pool traffic to the Linux VM router at `10.88.120.100`.

Remove the wrong route if it exists:

```powershell
route delete 10.60.0.0
```

Add persistent routes:

```powershell
route -p add 10.60.0.0 mask 255.255.0.0 10.88.120.100
route -p add 10.61.0.0 mask 255.255.0.0 10.88.120.100
route -p add 10.62.0.0 mask 255.255.0.0 10.88.120.100
route -p add 10.63.0.0 mask 255.255.0.0 10.88.120.100
```

The route below was temporary/wrong if used as the Windows next hop:

```powershell
route -p add 10.60.0.0 mask 255.255.0.0 192.168.3.89
```

## Switch/Router Routes

The switch/router at `192.168.3.1` needs a route to the UE pool through the Linux VM router:

```text
10.60.0.0/24 via 192.168.3.89
```

or, if routing the whole UE block:

```text
10.60.0.0/16 via 192.168.3.89
```

For clients in `192.168.1.0/24`, their default route should lead to the switch/router, and the switch/router must forward UE-pool traffic to `192.168.3.89`.

## Checklist

- Linux VM has `net.ipv4.ip_forward=1`.
- Linux VM has route `10.60.0.0/24 via 10.100.200.7 dev br-free5gc`.
- Linux VM has route `192.168.1.0/24 via 192.168.3.1 dev eth1`.
- Linux VM has FORWARD accept rules for:
  - `10.88.120.0/24 -> 10.60.0.0/24`
  - `192.168.3.0/24 -> 10.60.0.0/24`
  - `192.168.1.0/24 -> 10.60.0.0/24`
- Linux VM has POSTROUTING MASQUERADE rules for those three source networks toward `br-free5gc`.
- `netfilter-persistent` is enabled and saved after firewall changes.
- Windows has persistent routes via `10.88.120.100`.
- Switch/router has UE-pool route via `192.168.3.89`.
- Test client in `192.168.1.0/24` can ping `10.60.0.3`.

## Verification Commands

Linux VM:

```bash
ip -4 addr
ip route
sysctl net.ipv4.ip_forward
sudo iptables -vnL FORWARD
sudo iptables -t nat -vnL POSTROUTING
```

Route lookups:

```bash
ip route get 10.60.0.3 from 192.168.1.10 iif eth1
ip route get 10.60.0.3 from 192.168.3.1 iif eth1
ip route get 10.60.0.3 from 10.88.120.200 iif eth1
ip route get 192.168.1.10
```

Packet captures:

```bash
sudo tcpdump -ni eth1 'host 192.168.1.10 and host 10.60.0.3'
sudo tcpdump -ni eth1 'host 192.168.3.1 and host 10.60.0.3'
sudo tcpdump -ni br-free5gc 'host 10.60.0.3'
```

Windows:

```powershell
route print
ping 10.88.120.100
tracert -d 10.60.0.3
ping 10.60.0.3
```

Client on `192.168.1.0/24`:

```bash
ping 10.60.0.3
traceroute -n 10.60.0.3
```

