#!/bin/bash
ARCH=${1-"x86_64"}
FORWARDER=${2-"userspace"}
COMPOSE_FILE="docker-compose-build.yaml"

if [ "${FORWARDER}" == "gtp5g" ]; then
    COMPOSE_FILE="docker-compose-gtp5g-build.yaml"
fi

cd base
git clone --recursive -j `nproc` https://github.com/acore2026/free5gc.git

cd -

make all

echo "Building docker images for ${ARCH}..."

if [ ${ARCH} == "aarch64" ]; then
    docker compose -f "${COMPOSE_FILE}" build --build-arg TARGET_ARCH=${ARCH}
else
    docker compose -f "${COMPOSE_FILE}" build
fi;
