#!/bin/bash

echo "=== 手动关闭SCTP端口 ==="
echo ""

# 检查是否有SCTP连接残留
if ss -aS | grep -q 38412; then
    echo "发现SCTP残留连接:"
    ss -aS | grep 38412
    echo ""
    
    echo "方法1: 禁用/启用eth1接口强制清理"
    echo "执行: ip link set eth1 down && ip link set eth1 up"
    read -p "确认执行? (y/n): " confirm
    
    if [ "$confirm" = "y" ]; then
        echo "正在禁用eth1..."
        sudo ip link set eth1 down
        sleep 1
        
        echo "正在启用eth1..."
        sudo ip link set eth1 up
        sleep 1
        
        echo ""
        echo "检查结果:"
        if ss -aS | grep -q 38412; then
            echo "仍有残留连接:"
            ss -aS | grep 38412
        else
            echo "SCTP端口已完全释放"
        fi
    else
        echo "取消操作"
    fi
else
    echo "SCTP端口38412无残留连接"
fi