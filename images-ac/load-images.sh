#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_DIR="$SCRIPT_DIR"

echo "=== 从 $IMAGE_DIR 恢复镜像到本地 Docker ==="

for tar_gz in "$IMAGE_DIR"/*.tar.gz; do
    if [ ! -f "$tar_gz" ]; then
        echo "未找到镜像文件"
        exit 1
    fi
    
    filename=$(basename "$tar_gz")
    container_name="${filename%.tar.gz}"
    
    echo ""
    echo "加载镜像: $tar_gz"
    
    gunzip -c "$tar_gz" > /tmp/temp_image.tar
    docker load -i /tmp/temp_image.tar
    rm -f /tmp/temp_image.tar
    
    echo "  完成: $container_name"
done

if [ -f "$IMAGE_DIR/mongodb.tar.gz.part_aa" ]; then
    echo ""
    echo "加载拆分的 mongodb 镜像..."
    cat "$IMAGE_DIR"/mongodb.tar.gz.part_* > /tmp/mongodb.tar.gz
    gunzip -c /tmp/mongodb.tar.gz > /tmp/temp_image.tar
    docker load -i /tmp/temp_image.tar
    rm -f /tmp/temp_image.tar /tmp/mongodb.tar.gz
    echo "  完成: mongodb"
fi

echo ""
echo "=== 已加载的镜像列表 ==="
docker images | grep "free5gc-ac\|mongo"

echo ""
echo "=== 恢复完成 ==="
echo "提示: 如需使用这些镜像启动容器，请更新 docker-compose.yaml 中的镜像名称"