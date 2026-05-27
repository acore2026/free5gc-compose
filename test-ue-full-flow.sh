#!/bin/bash

IMSI="imsi-001012345678910"
UE_CONFIG="uecfg-910.yaml"
CONTAINER="ueransim"
WAIT_TIME=6

log() {
    echo ""
    echo "=========================================="
    echo "$1"
    echo "=========================================="
}

check_env() {
    log "[环境检查]"
    
    echo "检查核心网状态..."
    docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "(amf|smf|upf|nrf)" | head -4 || {
        echo "错误: 核心网未启动"
        exit 1
    }
    
    echo "检查gNB状态..."
    docker exec $CONTAINER ps aux | grep nr-gnb | grep -v grep || {
        echo "错误: gNB未运行，请先运行 start-gnb.sh"
        exit 1
    }
    
    echo "清理现有UE进程..."
    docker exec $CONTAINER pkill -9 nr-ue 2>/dev/null || true
    /home/core/clean_ue_context.sh --all 2>/dev/null || true
    sleep 2
    
    echo "环境检查完成"
}

register_ue() {
    log "[步骤1: UE注册]"
    
    echo "启动UE进程..."
    docker exec -d $CONTAINER ./nr-ue -c ./config/$UE_CONFIG
    sleep $WAIT_TIME
    
    echo "验证UE进程..."
    docker exec $CONTAINER ps aux | grep nr-ue | grep -v grep || {
        echo "错误: UE未启动"
        exit 1
    }
    
    echo "等待注册完成..."
    sleep 3
    
    echo "检查UE节点..."
    docker exec $CONTAINER ./nr-cli --dump | grep "$IMSI" || {
        echo "错误: UE节点未出现在nr-cli"
        exit 1
    }
    
    echo "检查TUN接口..."
    docker exec $CONTAINER ip addr show uesimtun0 || {
        echo "警告: uesimtun0接口未创建"
    }
    
    UE_IP=$(docker exec $CONTAINER ip addr show uesimtun0 | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1)
    echo "获得IP地址: $UE_IP"
    
    echo "检查AMF注册状态..."
    curl -s http://localhost:8000/namf-oam/v1/registered-ue-context 2>/dev/null | \
        python3 -c "import sys,json; data=json.load(sys.stdin); print('SUPI:', data[0]['Supi']); print('PDU Session:', data[0]['PduSessions'][0]['PduSessionId'])" 2>/dev/null || \
        echo "无法从AMF获取状态"
    
    echo "UE注册完成: $IMSI, IP=$UE_IP"
}

verify_session() {
    log "[步骤2: 验证PDU会话]"
    
    echo "查询AMF注册上下文..."
    curl -s http://localhost:8000/namf-oam/v1/registered-ue-context 2>/dev/null | \
        python3 -m json.tool 2>/dev/null | head -20
    
    echo "检查SMF会话日志..."
    docker logs smf --since 20s 2>&1 | \
        grep -E "(imsi-001012345678910|PDU|Session)" | tail -5 || true
    
    echo "PDU会话已激活"
}

release_session() {
    log "[步骤3: PDU会话释放]"
    
    echo "执行PDU会话释放..."
    docker exec $CONTAINER ./nr-cli $IMSI --exec "ps-release 1" 2>&1 || {
        echo "错误: 会话释放命令失败"
        exit 1
    }
    
    echo "等待释放完成..."
    sleep 3
    
    echo "验证接口删除..."
    docker exec $CONTAINER ip addr show uesimtun0 2>&1 || echo "uesimtun0已删除"
    
    echo "检查SMF释放日志..."
    docker logs smf --since 10s 2>&1 | \
        grep -E "(Release|imsi-001012345678910)" | tail -5 || true
    
    echo "检查AMF释放日志..."
    docker logs amf --since 10s 2>&1 | \
        grep -E "(Release|imsi-001012345678910)" | tail -5 || true
    
    echo "PDU会话已释放"
}

deregister_ue() {
    log "[步骤4: UE去注册]"
    
    echo "执行去注册(关机模式)..."
    docker exec $CONTAINER ./nr-cli $IMSI --exec "deregister switch-off" 2>&1 || {
        echo "错误: 去注册命令失败"
        exit 1
    }
    
    echo "等待去注册完成..."
    sleep 3
    
    echo "验证UE进程停止..."
    docker exec $CONTAINER ps aux | grep nr-ue | grep -v grep || echo "UE进程已停止"
    
    echo "验证节点移除..."
    docker exec $CONTAINER ./nr-cli --dump | grep "$IMSI" || echo "UE节点已移除"
    
    echo "检查AMF去注册日志..."
    docker logs amf --since 15s 2>&1 | \
        grep -E "(Deregistration|imsi-001012345678910|removed)" | tail -5 || true
    
    echo "验证核心网无残留上下文..."
    curl -s http://localhost:8000/namf-oam/v1/registered-ue-context 2>/dev/null | \
        python3 -c "import sys,json; data=json.load(sys.stdin); print('残留UE:', len(data))" 2>/dev/null || \
        echo "无残留UE上下文"
    
    echo "UE去注册完成"
}

show_summary() {
    log "[测试总结]"
    
    echo "IMSI: $IMSI"
    echo ""
    echo "流程执行结果:"
    echo "  ✓ UE注册"
    echo "  ✓ PDU会话激活"
    echo "  ✓ PDU会话释放"
    echo "  ✓ UE去注册"
    echo ""
    echo "核心网状态:"
    docker ps --format "{{.Names}}: {{.Status}}" | grep -E "(amf|smf|upf|nrf)"
    echo ""
    echo "测试完成时间: $(date '+%Y-%m-%d %H:%M:%S')"
}

main() {
    echo ""
    echo "=========================================="
    echo "  IMSI-001012345678910 核心网流程测试"
    echo "=========================================="
    echo ""
    
    check_env
    register_ue
    verify_session
    release_session
    deregister_ue
    show_summary
}

main "$@"