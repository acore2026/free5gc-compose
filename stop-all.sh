#!/bin/bash

COMPOSE_DIR="${COMPOSE_DIR:-/home/core/free5gc-compose-new}"
QOS_SCRIPT="${QOS_SCRIPT:-/home/core/QoSModule/scripts/start-qos.sh}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TOTAL=5
step() { echo -e "${BLUE}[$1/$TOTAL] $2${NC}"; }
ok()   { echo -e "${GREEN}  ✓ $1${NC}"; }
warn() { echo -e "${YELLOW}  ! $1${NC}"; }

echo "=========================================="
echo "     核心网一键停止脚本 (5GC + IMS + 附加进程)"
echo "=========================================="

step 1 "停止 MASQUE Proxy..."
pkill -f "go run ./cmd/proxy -proxy" 2>/dev/null || true
pkill -f "/proxy -proxy https://" 2>/dev/null || true
sleep 1
if pgrep -f "proxy -proxy" >/dev/null 2>&1; then
    warn "MASQUE Proxy 仍在运行"
else
    ok "MASQUE Proxy 已停止"
fi

# start-qos.sh stop 会一并停掉 mock-ran(含其自报前端的 pusher 线程)
step 2 "停止 QoSModule..."
if [ -x "$QOS_SCRIPT" ]; then
    "$QOS_SCRIPT" stop >/dev/null 2>&1 || true
    ok "QoSModule stop 已执行"
else
    warn "未找到 $QOS_SCRIPT，跳过"
fi
# 兜底: pid 文件丢失但 mock-ran 进程还在
pkill -f "ranreporter/mock_ran.py" 2>/dev/null || true

step 3 "停止 IMS 服务..."
systemctl stop free5gc-ue-routes.service 2>/dev/null || true
systemctl stop free5gc-disable-offload.service 2>/dev/null || true
systemctl stop kamailio.service 2>/dev/null || true
ok "IMS 服务已停止"

step 4 "停止 5GC Docker 容器..."
if [ -f "$COMPOSE_DIR/docker-compose.yaml" ]; then
    ( cd "$COMPOSE_DIR" && docker-compose down ) || warn "Docker 容器停止失败"
    ok "5GC 容器已停止"
else
    warn "未找到 $COMPOSE_DIR/docker-compose.yaml，跳过"
fi

step 5 "卸载 gtp5g 内核模块..."
if lsmod 2>/dev/null | grep -q gtp5g; then
    if rmmod gtp5g 2>/dev/null; then
        ok "gtp5g 模块已卸载"
    else
        warn "gtp5g 模块卸载失败 (可能仍在被使用)"
    fi
else
    ok "gtp5g 模块未加载，无需卸载"
fi

echo ""
echo "=========================================="
echo -e "${GREEN}     所有服务已停止!${NC}"
echo "=========================================="
echo ""
echo "--- 残留进程检查 ---"
echo "[Docker 容器]"
docker ps --format "  {{.Names}}\t{{.Status}}" 2>/dev/null | head -5 || true
echo "[相关进程]"
pgrep -af "ranreporter/mock_ran.py" 2>/dev/null || echo "  mock-ran: 无"
pgrep -af "proxy -proxy" 2>/dev/null || echo "  MASQUE Proxy: 无"
pgrep -af "qos" 2>/dev/null | grep -v pgrep || echo "  QoSModule: 无"
echo "[IMS 服务]"
systemctl is-active kamailio.service free5gc-disable-offload.service free5gc-ue-routes.service 2>/dev/null || true
