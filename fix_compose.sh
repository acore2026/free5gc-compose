#!/bin/bash
cd /home/core
cp docker-compose.yaml.bak docker-compose.yaml
sed -i '/image: free5gc\/upf/a/    ports:\\n      - 2152:2152\/udp\\n      - 8805:8805\/udp/' docker-compose.yaml
