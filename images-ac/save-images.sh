#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_DIR="$SCRIPT_DIR"

echo "=== 保存核心网容器镜像到 $IMAGE_DIR ==="

CONTAINERS=("chf" "nssf" "ausf" "webui" "amf" "udr" "smf" "pcf" "nef" "udm" "nrf" "mongodb" "upf")

for container in "${CONTAINERS[@]}"; do
    echo ""
    echo "处理容器: $container"
    
    original_image=$(docker inspect --format='{{.Config.Image}}' $container 2>/dev/null)
    if [ -z "$original_image" ]; then
        echo "  警告: 容器 $container 不存在，跳过"
        continue
    fi
    
    timestamp=$(date +%Y%m%d_%H%M%S)
    new_image="free5gc-ac/${container}:saved"
    
    echo "  原始镜像: $original_image"
    echo "  提交为新镜像: $new_image"
    
    docker commit $container $new_image
    
    tar_file="$IMAGE_DIR/${container}.tar"
    echo "  保存到: $tar_file"
    
    docker save -o "$tar_file" $new_image
    
    gzip -f "$tar_file"
    
    echo "  完成: ${tar_file}.gz"
done

echo ""
echo "=== 所有镜像已保存到 $IMAGE_DIR ==="
ls -lh "$IMAGE_DIR"/*.tar.gz 2>/dev/null