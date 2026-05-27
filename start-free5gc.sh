#!/bin/bash
# Free5GC 启动脚本 - 包含必要的网络配置

cd /home/core

# 1. 确保IP转发开启
sysctl -w net.ipv4.ip_forward=1

# 2. 启动核心网容器
docker-compose up -d

# 3. 等待启动
sleep 10

# 4. 配置UPF NAT规则（解决容器重启后NAT丢失问题）
echo " 配置UPF NAT规则...\
docker exec upf sh -c 'iptables -t nat -F POSTROUTING; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE; iptables -I FORWARD 1 -j ACCEPT'

# 5. 验证
echo \验证UPF NAT规则:\
docker exec upf iptables -t nat -L POSTROUTING -n -v

echo \核心网启动完成！\
echo \AMF N2接口: 10.88.120.100:38412\
echo \WebUI: http://10.88.120.99:5000\
