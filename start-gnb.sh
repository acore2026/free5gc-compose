#!/bin/bash

echo "=== 启动UERANSIM基站 [gNB Only] ==="
echo

echo [步骤1] 检查核心网状态
docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "(amf|smf|upf|nrf)" || {
    echo "错误: 核心网未启动，请先运行 restart-docker.sh"
    exit 1
}
echo

echo [步骤2] 启动UERANSIM gNB容器
docker run -d \
    --name ueransim \
    --network host \
    --privileged \
    --restart unless-stopped \
    -v /home/core/config/gnbcfg.yaml:/ueransim/config/gnbcfg.yaml \
    -v /home/core/config/uecfg.yaml:/ueransim/config/uecfg.yaml \
    -v /home/core/config/uecfg-910.yaml:/ueransim/config/uecfg-910.yaml \
    free5gc/ueransim:latest \
    bash -c "./nr-gnb -c ./config/gnbcfg.yaml"

sleep 3
echo

echo [步骤3] 检查gNB状态
docker exec ueransim ps aux | grep nr-gnb || {
    echo "错误: gNB未正常启动"
    docker logs ueransim --tail 20
    exit 1
}
echo

echo [步骤4] 查看gNB日志
docker logs ueransim --tail 15 2>&1
echo

echo === gNB启动完成 ===
echo "gNB已连接到AMF: 10.88.120.100:38412"
echo "如需启动UE，请运行: docker exec ueransim ./nr-ue -c ./config/uecfg-910.yaml"
echo