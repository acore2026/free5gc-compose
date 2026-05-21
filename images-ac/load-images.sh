#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_DIR="$SCRIPT_DIR"

declare -A IMAGE_MAP
IMAGE_MAP["amf"]="free5gc/amf:v4.2.1"
IMAGE_MAP["ausf"]="free5gc/ausf:v4.2.1"
IMAGE_MAP["chf"]="free5gc/chf:v4.2.1"
IMAGE_MAP["nef"]="free5gc/nef:v4.2.1"
IMAGE_MAP["nrf"]="free5gc/nrf:v4.2.1"
IMAGE_MAP["nssf"]="free5gc/nssf:v4.2.1"
IMAGE_MAP["pcf"]="free5gc/pcf:v4.2.1"
IMAGE_MAP["smf"]="free5gc/smf:v4.2.1"
IMAGE_MAP["udm"]="free5gc/udm:v4.2.1"
IMAGE_MAP["udr"]="free5gc/udr:v4.2.1"
IMAGE_MAP["upf"]="free5gc/upf:v4.2.1.ac"
IMAGE_MAP["webui"]="free5gc/webui:v4.2.1"
IMAGE_MAP["mongodb"]="mongo:4.4"

echo "=== 从 $IMAGE_DIR 恢复镜像到本地 Docker ==="

for tar_gz in "$IMAGE_DIR"/*.tar.gz; do
    if [ ! -f "$tar_gz" ]; then
        continue
    fi
    
    filename=$(basename "$tar_gz")
    container_name="${filename%.tar.gz}"
    saved_image="free5gc-ac/${container_name}:saved"
    original_image="${IMAGE_MAP[$container_name]}"
    
    echo ""
    echo "加载镜像: $tar_gz"
    
    gunzip -c "$tar_gz" > /tmp/temp_image.tar
    docker load -i /tmp/temp_image.tar
    rm -f /tmp/temp_image.tar
    
    if [ -n "$original_image" ]; then
        echo "  重命名: $saved_image -> $original_image"
        docker tag "$saved_image" "$original_image"
        docker rmi "$saved_image"
    fi
    
    echo "  完成: $container_name"
done

if [ -f "$IMAGE_DIR/mongodb.tar.gz.part_aa" ]; then
    echo ""
    echo "加载拆分的 mongodb 镜像..."
    cat "$IMAGE_DIR"/mongodb.tar.gz.part_* > /tmp/mongodb.tar.gz
    gunzip -c /tmp/mongodb.tar.gz > /tmp/temp_image.tar
    docker load -i /tmp/temp_image.tar
    rm -f /tmp/temp_image.tar /tmp/mongodb.tar.gz
    
    saved_image="free5gc-ac/mongodb:saved"
    original_image="mongo:4.4"
    echo "  重命名: $saved_image -> $original_image"
    docker tag "$saved_image" "$original_image"
    docker rmi "$saved_image"
    echo "  完成: mongodb"
fi

echo ""
echo "=== 已加载的镜像列表 ==="
docker images | grep "free5gc\|mongo"

echo ""
echo "=== 恢复完成 ==="
echo "镜像已恢复为原始名称和标签"