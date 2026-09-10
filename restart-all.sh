#!/bin/bash
#
# 核心网一键重启脚本
#
# 环境变量(可选,都有默认值):
#   QOS_MODE=ran-udp|mock-ran        QoSModule 启动模式(默认 mock-ran)
#   FRONTEND_URL=http://...:28448/api/v1/qos   前端上报目标(默认 192.168.1.10:28448, 仅 mock-ran 用)
#   RAN_UDP_ENDPOINT=10.88.0.3:9999  远程基站 UDP 地址(ran-udp 模式用)
#
# 上报由下发目标自己负责, 本机不再跑任何中间采集器:
#   mock-ran → mock-ran 进程自己 POST 前端
#   ran-udp  → 远程基站自己 POST 前端
# 二者互斥, 故前端不会同时收到两路数据(前端 schema 无数据源标识字段, 无法区分合并)。
#
# 已退役: mode=ran(默认目标 10.88.120.212 已下线)、mode=auto(三档回退会让远程基站与
#         mock-ran 两个上报源同时活着)、mode=ngap/SMF、collector.py 采集器全家。
#

set -e

cd "${COMPOSE_DIR:-/home/core/free5gc-compose-new}"

QOS_SCRIPT="${QOS_SCRIPT:-/home/core/QoSModule/scripts/start-qos.sh}"
QOS_MODE="${QOS_MODE:-mock-ran}"
MASQUE_DIR="${MASQUE_DIR:-/home/core/masque/masque/proxy}"
MASQUE_LOG="${MASQUE_LOG:-/home/core/masque/masque/proxy.log}"
MASQUE_PID_FILE="${MASQUE_PID_FILE:-/tmp/masque-proxy.pid}"
MASQUE_PROXY_URL="${MASQUE_PROXY_URL:-${MASQUE_PROXY_TARGET:-https://10.88.120.100:443}}"
MASQUE_GOPROXY="${MASQUE_GOPROXY:-${GOPROXY:-https://goproxy.cn,direct}}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TOTAL=9

step() { echo -e "${BLUE}[$1/$TOTAL] $2${NC}"; }
ok() { echo -e "${GREEN}  ✓ $1${NC}"; }
warn() { echo -e "${YELLOW}  $1${NC}"; }
info() { echo -e "${BLUE}  $1${NC}"; }
fail() { echo -e "${RED}  ✗ $1${NC}"; exit 1; }

echo "=========================================="
echo "     核心网重启脚本"
echo "=========================================="

step 1 "停止 IMS / QoS / MASQUE 服务..."
if [ -f "$MASQUE_PID_FILE" ]; then
    kill "$(cat "$MASQUE_PID_FILE")" 2>/dev/null || true
    rm -f "$MASQUE_PID_FILE"
fi
pkill -f "go run ./cmd/proxy -proxy" 2>/dev/null || true
pkill -f "/proxy -proxy https://" 2>/dev/null || true
if [ -x "$QOS_SCRIPT" ]; then
    "$QOS_SCRIPT" stop >/dev/null 2>&1 || true
fi
systemctl stop free5gc-ue-routes.service 2>/dev/null || true
systemctl stop free5gc-disable-offload.service 2>/dev/null || true
systemctl stop kamailio.service 2>/dev/null || true
ok "IMS / QoS / MASQUE 服务已停止"

step 2 "停止 Docker 容器..."
docker-compose down || fail "Docker 容器停止失败"
# docker-proxy 释放端口有延迟，等待确保端口已释放，避免 up 时 "address already in use"
echo -e "${YELLOW}  等待端口释放...${NC}"
sleep 3
ok "Docker 容器已停止"

step 3 "加载 gtp5g 内核模块..."
if lsmod | grep -q gtp5g; then
    rmmod gtp5g 2>/dev/null || true
fi
if [ -f /home/core/gtp5g/gtp5g.ko ]; then
    insmod /home/core/gtp5g/gtp5g.ko && ok "gtp5g 模块加载成功" || fail "gtp5g 模块加载失败"
else
    fail "未找到 gtp5g.ko"
fi

step 4 "启动 Docker 容器..."
docker-compose up -d || fail "Docker 容器启动失败"
# 端口冲突可能导致部分容器停留在 created 状态，检测并重试启动
sleep 2
CREATED=$(docker ps -a --filter "status=created" --format "{{.Names}}")
if [ -n "$CREATED" ]; then
    echo -e "${YELLOW}  以下容器未启动，正在重试: $CREATED${NC}"
    for c in $CREATED; do
        docker start "$c" >/dev/null 2>&1 || true
    done
    sleep 2
fi
ok "Docker 容器已启动"

echo -e "${YELLOW}  等待 MongoDB 就绪...${NC}"
for i in $(seq 1 30); do
    docker exec mongodb mongo --quiet --eval "db.adminCommand('ping')" >/dev/null 2>&1 && break
    sleep 2
done
ok "MongoDB 已就绪"

step 5 "清理 UE 上下文..."
docker exec mongodb mongo --quiet --eval "
db = db.getSiblingDB('free5gc');
var r1 = db.subscriptionData.contextData.amf3gppAccess.deleteMany({});
var r2 = db.subscriptionData.authenticationData.authenticationStatus.deleteMany({});
print('AMF上下文: 删除 ' + r1.deletedCount + ' 条');
print('认证状态: 删除 ' + r2.deletedCount + ' 条');
" || true
ok "UE 上下文已清理"

step 6 "配置网络环境..."
ip addr add 10.88.120.100/24 dev eth1 2>/dev/null || true
# [10.88.120.99 removed — caused SCTP multi-homing ABORT loop on NGAP] ip addr add 10.88.120.99/24 dev eth1 2>/dev/null || true
ip link set eth1 up
ip addr add 10.100.200.99/24 dev br-free5gc 2>/dev/null || true
ok "网络配置完成"

step 7 "启动 IMS 服务..."
# 单元文件可能在磁盘上被修改过，先 reload 让 systemd 重新加载，否则 restart 会告警
systemctl daemon-reload || fail "systemctl daemon-reload 失败"
systemctl restart free5gc-ue-routes.service || fail "free5gc-ue-routes 启动失败"
ok "free5gc-ue-routes"
systemctl restart kamailio.service || fail "kamailio 启动失败"
ok "kamailio"
systemctl restart free5gc-disable-offload.service || fail "free5gc-disable-offload 启动失败"
ok "free5gc-disable-offload"

step 8 "启动 QoSModule ($QOS_MODE 模式)..."
if [ ! -x "$QOS_SCRIPT" ]; then
    fail "未找到 QoS 脚本: $QOS_SCRIPT"
fi
# 地址可用环境变量覆盖，例如:
#   RAN_UDP_ENDPOINT=10.88.0.3:9999 RAN_UDP_ACK=1 \
#   FRONTEND_URL=http://192.168.1.10:28448/api/v1/qos \
#   ./restart-all.sh
# QOS_MODE=ran-udp|mock-ran (默认 mock-ran)。上报由下发目标自己负责:
#   mock-ran → mock-ran 进程自报前端; ran-udp → 远程基站自报前端。本机不起采集进程。
# QOS_BIND 默认 0.0.0.0:7400，须与 MASQUE Proxy 配置的目标 UDP 端口一致
if "$QOS_SCRIPT" "$QOS_MODE"; then
    ok "QoSModule ($QOS_MODE)"
else
    fail "QoSModule 启动失败，查看日志: /home/core/QoSModule/logs/qos-module.log"
fi

step 9 "启动 MASQUE Proxy..."
if [ ! -d "$MASQUE_DIR" ]; then
    fail "未找到 MASQUE 目录: $MASQUE_DIR"
fi
# -proxy 地址须与 step 6 在 eth1 上配置的 IP 一致（默认 10.88.120.100）
# exec 保持后台 PID 对应 go run，且不改变父脚本工作目录。
(
    cd "$MASQUE_DIR" || exit 1
    exec env GOPROXY="$MASQUE_GOPROXY" nohup go run ./cmd/proxy -proxy "$MASQUE_PROXY_URL"
) > "$MASQUE_LOG" 2>&1 &
MPID=$!
echo "$MPID" > "$MASQUE_PID_FILE"
READY=0
for i in $(seq 1 30); do
    if ! kill -0 "$MPID" 2>/dev/null; then
        tail -10 "$MASQUE_LOG" 2>/dev/null || true
        fail "MASQUE Proxy 启动失败，查看日志: $MASQUE_LOG"
    fi
    if grep -q "MASQUE Proxy ready" "$MASQUE_LOG"; then
        READY=1
        break
    fi
    sleep 1
done
if [ "$READY" != "1" ]; then
    tail -10 "$MASQUE_LOG" 2>/dev/null || true
    fail "MASQUE Proxy 未就绪，查看日志: $MASQUE_LOG"
fi
ok "MASQUE Proxy 已就绪 (pid=$MPID, $MASQUE_PROXY_URL)"

# 原 step 10(启动 RANReporter collector.py)已删除: 上报责任下放到下发目标自己——
# mock-ran 模式由 mock-ran 进程自报前端(step 8 里 start-qos.sh 起 mock-ran 时已带
# --frontend-url), ran-udp 模式由远程基站自报前端。本机不再有任何中间采集进程。

echo ""
echo "=========================================="
echo -e "${GREEN}     核心网重启完成!${NC}"
echo "=========================================="
systemctl is-active kamailio.service free5gc-disable-offload.service free5gc-ue-routes.service
"$QOS_SCRIPT" status 2>/dev/null || true
pgrep -af "proxy -proxy" 2>/dev/null || true
pgrep -af "ranreporter/mock_ran.py" 2>/dev/null || true
