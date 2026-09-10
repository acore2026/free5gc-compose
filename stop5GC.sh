#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_DIR="/home/core/free5gc-compose-new"

echo "========================================="
echo "   Free5GC 停止脚本"
echo "========================================="

cd "$COMPOSE_DIR"
docker-compose down

echo ""
echo "核心网已停止"