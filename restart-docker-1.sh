#!/bin/bash

docker-compose up -d db
sleep 3
docker-compose up -d free5gc-nrf
sleep 2
docker-compose up -d free5gc-amf free5gc-smf free5gc-ausf free5gc-udm free5gc-udr free5gc-nssf free5gc-pcf free5gc-nef free5gc-chf free5gc-webui
sleep 5
docker-compose up -d free5gc-upf
sleep 5
echo

