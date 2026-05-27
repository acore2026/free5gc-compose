#!/bin/bash
echo === Free5GC核心网重启脚本 ===
echo

echo [步骤1] 配置网络IP地址
ip addr add 10.88.120.100/24 dev eth1 2>/dev/null || echo IP已存在
ip addr add 10.88.120.99/24 dev eth1 2>/dev/null || echo IP已存在
ip link set eth1 up
ip addr show eth1 | grep inet
echo

echo [步骤2] 加载gtp5g内核模块
if lsmod | grep -q gtp5g; then
  echo 移除旧gtp5g模块
  rmmod gtp5g 2>/dev/null
fi

if [ -f /home/core/gtp5g-v0.9.5/gtp5g.ko ]; then
  echo 加载预编译gtp5g模块
  insmod /home/core/gtp5g-v0.9.5/gtp5g.ko
  lsmod | grep gtp5g
  echo gtp5g模块加载成功
else
  echo 警告: 未找到gtp5g.ko文件
fi
echo

echo [步骤3] 重启Docker服务
systemctl restart docker
sleep 5
echo Docker已重启
echo

echo [步骤4] 启动核心网容器
cd /home/core
sysctl -w net.ipv4.ip_forward=1

docker-compose up -d db
sleep 3
docker-compose up -d free5gc-nrf
sleep 2
docker-compose up -d free5gc-amf free5gc-smf free5gc-ausf free5gc-udm free5gc-udr free5gc-nssf free5gc-pcf free5gc-nef free5gc-chf free5gc-webui
sleep 5
docker-compose up -d free5gc-upf
sleep 5
echo

echo [步骤5] 配置UPF NAT规则
sleep 3
docker exec upf iptables -t nat -F POSTROUTING 2>/dev/null || true
docker exec upf iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
docker exec upf iptables -I FORWARD 1 -j ACCEPT
echo UPF NAT已配置
echo

echo [步骤6] 验证容器状态
docker ps
echo

echo === 重启完成 ===
echo AMF N2: 10.88.120.100:38412
echo WebUI: http://10.88.120.99:5000
