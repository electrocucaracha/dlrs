#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2019
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

set -o nounset
set -o pipefail
if [ "${DLRS_DEBUG:-false}" == "true" ]; then
    set -o xtrace
fi

# _install_docker() - Download and install docker-engine
function _install_docker {
    local chameleonsocks_filename=chameleonsocks.sh

    if command -v docker && systemctl is-active --quiet docker; then
        return
    fi

    echo "Installing docker service..."
    # shellcheck disable=SC1091
    source /etc/os-release || source /usr/lib/os-release
    case ${ID,,} in
        clear-linux-os)
            sudo -E swupd bundle-add containers-basic
            sudo systemctl unmask docker.service
        ;;
        *)
            curl -fsSL https://get.docker.com/ | sh
        ;;
    esac

    sudo mkdir -p /etc/systemd/system/docker.service.d/
    mkdir -p "$HOME/.docker/"
    sudo mkdir -p /root/.docker/
    sudo usermod -aG docker "$USER"

    if [ -n "${HTTP_PROXY:-}" ] || [ -n "${HTTPS_PROXY:-}" ] || [ -n "${NO_PROXY:-}" ]; then
        config="{ \"proxies\": { \"default\": { "
        if [ -n "${HTTP_PROXY:-}" ]; then
            echo "[Service]" | sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf
            echo "Environment=\"HTTP_PROXY=$HTTP_PROXY\"" | sudo tee --append /etc/systemd/system/docker.service.d/http-proxy.conf
            config+="\"httpProxy\": \"$HTTP_PROXY\","
        fi
        if [ -n "${HTTPS_PROXY:-}" ]; then
            echo "[Service]" | sudo tee /etc/systemd/system/docker.service.d/https-proxy.conf
            echo "Environment=\"HTTPS_PROXY=$HTTPS_PROXY\"" | sudo tee --append /etc/systemd/system/docker.service.d/https-proxy.conf
            config+="\"httpsProxy\": \"$HTTPS_PROXY\","
        fi
        if [ -n "${NO_PROXY:-}" ]; then
            echo "[Service]" | sudo tee /etc/systemd/system/docker.service.d/no-proxy.conf
            echo "Environment=\"NO_PROXY=$NO_PROXY\"" | sudo tee --append /etc/systemd/system/docker.service.d/no-proxy.conf
            config+="\"noProxy\": \"$NO_PROXY\","
        fi
        echo "${config::-1} } } }" | tee "$HOME/.docker/config.json"
        sudo cp "$HOME/.docker/config.json" /root/.docker/config.json
        sudo systemctl daemon-reload
        sudo systemctl restart docker
    elif [ -n "${SOCKS_PROXY:-}" ]; then
        wget "https://raw.githubusercontent.com/crops/chameleonsocks/master/$chameleonsocks_filename"
        chmod 755 "$chameleonsocks_filename"
        socks_tmp="${SOCKS_PROXY#*//}"
        sudo ./$chameleonsocks_filename --uninstall
        sudo PROXY="${socks_tmp%:*}" PORT="${socks_tmp#*:}" ./$chameleonsocks_filename --install
        rm $chameleonsocks_filename
    fi
}

# _install_dj() - Install a Docker jinja processor
function _install_dj {
    if command -v dj; then
        return
    fi
    if ! command -v pip; then
        echo "Installing python package manager..."
        curl -sL https://bootstrap.pypa.io/get-pip.py | sudo python
    fi
    sudo pip install docker-jinja
}

# Validations
if ! lscpu | grep -e avx512 && [[ "${DLRS_TYPE}" == *mkl* ]]; then
    echo "ERROR - Your platform doesn't support the Intel® AVX-512"
    echo "instruction set which is required for Intel® MKL-DNN or"
    echo "Intel® MKL-DNN-VNNI image"
    exit
fi

# shellcheck disable=SC1091
source /etc/os-release || source /usr/lib/os-release
case ${ID,,} in
    clear-linux-os)
        sudo mkdir -p /etc/systemd/resolved.conf.d
        printf "[Resolve]\nDNSSEC=false" | sudo tee /etc/systemd/resolved.conf.d/dnssec.conf
    ;;
esac

_install_docker
echo "export DLRS_TYPE=$DLRS_TYPE" >> "$HOME/.bashrc"
if ! sudo docker images | grep -e "electrocucaracha/${DLRS_TYPE}"; then
    mkdir -p "/tmp/${DLRS_TYPE}"
    dockerfile="Dockerfile.tensorflow.j2"
    if [[ "${DLRS_TYPE}" == *pytorch* ]]; then
        dockerfile="Dockerfile.pytorch.j2"
    fi
    _install_dj
    dj --dockerfile ${dockerfile} --outfile "/tmp/${DLRS_TYPE}/Dockerfile" --env DLRS_TYPE="${DLRS_TYPE}"
    sudo docker build --no-cache --tag "electrocucaracha/${DLRS_TYPE}" "/tmp/${DLRS_TYPE}/"
fi
container_id=$(sudo docker run --detach --privileged "electrocucaracha/${DLRS_TYPE}")
echo "docker logs -f $container_id"
