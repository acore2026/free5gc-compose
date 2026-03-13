#
# Dockerfile responsible to create only the base image without compiling free5gc sources
#

FROM golang:1.25.5-trixie AS builder

LABEL maintainer="Free5GC <support@free5gc.org>"

ENV DEBIAN_FRONTEND=noninteractive

RUN find /etc/apt -type f \( -name '*.list' -o -name '*.sources' \) \
    -exec sed -i 's|http://deb.debian.org|https://deb.debian.org|g; s|http://security.debian.org|https://security.debian.org|g' {} +

# Install dependencies
RUN apt-get update \
    && apt-get -y install gcc cmake autoconf libtool pkg-config libmnl-dev libyaml-dev apt-transport-https ca-certificates

# Clean apt cache
RUN apt-get clean
