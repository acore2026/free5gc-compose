#!/bin/bash

echo "=== 优化SCTP连接超时参数 ==="
echo ""
echo "当前参数:"
sysctl net.netfilter.nf_conntrack_sctp_timeout_shutdown_sent
sysctl net.netfilter.nf_conntrack_sctp_timeout_shutdown_recd
sysctl net.netfilter.nf_conntrack_sctp_timeout_shutdown_ack_sent
echo ""

echo "调整为更短的超时时间..."
sudo sysctl -w net.netfilter.nf_conntrack_sctp_timeout_shutdown_sent=1
sudo sysctl -w net.netfilter.nf_conntrack_sctp_timeout_shutdown_recd=1
sudo sysctl -w net.netfilter.nf_conntrack_sctp_timeout_shutdown_ack_sent=1
sudo sysctl -w net.netfilter.nf_conntrack_sctp_timeout_closed=1

echo ""
echo "新参数:"
sysctl net.netfilter.nf_conntrack_sctp_timeout_shutdown_sent
sysctl net.netfilter.nf_conntrack_sctp_timeout_shutdown_recd
sysctl net.netfilter.nf_conntrack_sctp_timeout_shutdown_ack_sent
echo ""
echo "完成! 现在SCTP连接会在1秒内关闭"

# 持久化配置
echo ""
echo "如需持久化，添加以下内容到 /etc/sysctl.d/99-sctp.conf:"
echo "net.netfilter.nf_conntrack_sctp_timeout_shutdown_sent = 1"
echo "net.netfilter.nf_conntrack_sctp_timeout_shutdown_recd = 1"
echo "net.netfilter.nf_conntrack_sctp_timeout_shutdown_ack_sent = 1"
echo "net.netfilter.nf_conntrack_sctp_timeout_closed = 1"