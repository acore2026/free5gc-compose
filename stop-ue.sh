#!/bin/bash

echo "=== 停止UERANSIM UE ==="
echo

echo "[步骤1] 查看当前运行的UE进程"
UE_COUNT=$(docker exec ueransim ps aux | grep nr-ue | grep -v grep | wc -l)
echo "当前运行UE数量: $UE_COUNT"
echo

if [ "$UE_COUNT" -eq 0 ]; then
    echo "没有运行的UE进程"
    exit 0
fi

docker exec ueransim ps aux | grep nr-ue | grep -v grep
echo

echo "[步骤2] 停止所有UE进程"
docker exec ueransim pkill -9 nr-ue
sleep 2
echo

echo "[步骤3] 清理AMF中的UE上下文"
/home/core/free5gc-compose-new/clean_ue_context.sh --all
echo

echo "[步骤4] 验证UE已停止"
docker exec ueransim ps aux | grep nr-ue | grep -v grep || echo "所有UE已停止"
echo

echo "=== UE已停止 ==="
echo "如需重新启动UE，请运行: /home/core/start-ue.sh uecfg-910.yaml"