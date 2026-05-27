#!/bin/bash

echo "=== 启动UERANSIM UE ==="
echo

if [ "$#" -lt 1 ]; then
    echo "用法: $0 <ue-config-file> [数量]"
    echo ""
    echo "可用的UE配置:"
    echo "  uecfg.yaml         - IMSI: imsi-001012345678909"
    echo "  uecfg-910.yaml     - IMSI: imsi-001012345678910"
    echo ""
    echo "示例:"
    echo "  $0 uecfg-910.yaml         # 启动单个UE"
    echo "  $0 uecfg-910.yaml 2       # 启动2个相同配置的UE"
    exit 1
fi

UE_CONFIG="$1"
UE_COUNT="${2:-1}"

if [ "$UE_COUNT" -lt 1 ] || [ "$UE_COUNT" -gt 10 ]; then
    echo "错误: UE数量必须在1-10之间"
    exit 1
fi

echo "[步骤1] 检查gNB状态"
docker exec ueransim ps aux | grep nr-gnb | grep -v grep || {
    echo "错误: gNB未运行，请先运行 start-gnb.sh"
    exit 1
}
echo "gNB运行正常"
echo

echo "[步骤2] 启动 $UE_COUNT 个UE (配置: $UE_CONFIG)"
for i in $(seq 1 $UE_COUNT); do
    echo "启动UE #$i..."
    docker exec ueransim ./nr-ue -c ./config/$UE_CONFIG &
    sleep 2
done
echo

echo "[步骤3] 查看UE进程"
docker exec ueransim ps aux | grep nr-ue | grep -v grep
echo

echo "[步骤4] 查看AMF日志 (最新注册信息)"
docker logs amf --tail 15 2>&1 | grep -E "(Registration|imsi)" || true
echo

echo "=== UE启动完成 ==="
echo "查看UE接口: docker exec ueransim ip addr show uesimtun0"
echo "测试连通性: docker exec ueransim ping -I uesimtun0 -c 3 <目标IP>"