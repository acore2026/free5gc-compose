#!/bin/bash

sysctl -w net.ipv4.ip_forward=1
ip link add ipsec0 type xfrm if_id 1
ip link set dev ipsec0 up
ip addr add 10.100.200.240/24 dev ipsec0
