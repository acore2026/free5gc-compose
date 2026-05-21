echo [步骤1] 配置网络IP地址
ip addr add 10.88.120.100/24 dev eth1 2>/dev/null || echo IP已存在
ip addr add 10.88.120.99/24 dev eth1 2>/dev/null || echo IP已存在
ip link set eth1 up
ip addr show eth1 | grep inet
echo

ip route add 10.60.0.0/16 via 10.100.200.2
