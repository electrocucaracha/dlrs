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
set -o errexit
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
        ubuntu|debian)
            _install_nvidia_drivers
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
            sudo add-apt-repository \
            "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
            $(lsb_release -cs) stable"
            curl -s -l https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
            curl -s -l "https://nvidia.github.io/nvidia-docker/$ID$VERSION_ID/nvidia-docker.list" | sudo tee /etc/apt/sources.list.d/nvidia-docker.list
            sudo apt-get update
            sudo apt install -y 'docker-ce=5:18.09.7~3-0~ubuntu-xenial'
            sudo apt-get install -y nvidia-docker2
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
    elif [ -n "${SOCKS_PROXY:-}" ]; then
        wget "https://raw.githubusercontent.com/crops/chameleonsocks/master/$chameleonsocks_filename"
        chmod 755 "$chameleonsocks_filename"
        socks_tmp="${SOCKS_PROXY#*//}"
        sudo ./$chameleonsocks_filename --uninstall
        sudo PROXY="${socks_tmp%:*}" PORT="${socks_tmp#*:}" ./$chameleonsocks_filename --install
        rm $chameleonsocks_filename
    fi
    sudo systemctl enable --now docker
    sudo systemctl restart docker
}

# _install_dj() - Install a Docker jinja processor
function _install_dj {
    if command -v dj; then
        return
    fi
    if ! command -v python; then
        echo "Installing python..."
        # shellcheck disable=SC1091
        source /etc/os-release || source /usr/lib/os-release
        case ${ID,,} in
            clear-linux-os)
                sudo -E swupd bundle-add python3-basic
            ;;
            ubuntu|debian)
                sudo apt install -y python
            ;;
        esac
    fi
    if ! command -v pip; then
        echo "Installing python package manager..."
        curl -sL https://bootstrap.pypa.io/get-pip.py | sudo python
    fi
    sudo pip install docker-jinja
}

# _vercmp() - Function that compares two versions
function _vercmp {
    local v1=$1
    local op=$2
    local v2=$3
    local result

    # sort the two numbers with sort's "-V" argument.  Based on if v2
    # swapped places with v1, we can determine ordering.
    result=$(echo -e "$v1\n$v2" | sort -V | head -1)

    case $op in
        "==")
            [ "$v1" = "$v2" ]
            return
            ;;
        ">")
            [ "$v1" != "$v2" ] && [ "$result" = "$v2" ]
            return
            ;;
        "<")
            [ "$v1" != "$v2" ] && [ "$result" = "$v1" ]
            return
            ;;
        ">=")
            [ "$result" = "$v2" ]
            return
            ;;
        "<=")
            [ "$result" = "$v1" ]
            return
            ;;
        *)
            die $LINENO "unrecognised op: $op"
            ;;
    esac
}

# _install_nvidia_drivers() - Function that install CUDA Toolkit
function _install_nvidia_drivers {
    if ! lspci | grep -i nvidia; then
        echo "WARN - The GPU controller is not CUDA-capable"
        return
    fi
    if command -v gcc; then
        echo "Installing gcc..."
        # shellcheck disable=SC1091
        source /etc/os-release || source /usr/lib/os-release
        case ${ID,,} in
            ubuntu|debian)
                sudo apt install -y gcc
            ;;
        esac
    fi
    # shellcheck disable=SC1091
    source /etc/os-release || source /usr/lib/os-release
    case ${ID,,} in
        ubuntu|debian)
            sudo apt-get install "linux-headers-$(uname -r)"
            prefix="cuda-repo"
            version="10.1"
            distro="${ID}${VERSION_ID//.}"
            deb_file="${prefix}-${distro}_${version}.168-1_amd64.deb"
            wget "http://developer.download.nvidia.com/compute/cuda/repos/${distro}/$(uname -m)/$deb_file"
            sudo dpkg -i "$deb_file"
            rm "$deb_file"
            sudo apt-key adv --fetch-keys "http://developer.download.nvidia.com/compute/cuda/repos/${distro}/$(uname -m)/7fa2af80.pub"
            sudo apt-get update
            sudo apt-get install -y cuda
            sudo systemctl start nvidia-persistenced
        ;;
    esac
}

echo "export DLRS_TYPE=$DLRS_TYPE" >> "$HOME/.bashrc"

# shellcheck disable=SC1091
source /etc/os-release || source /usr/lib/os-release
case ${ID,,} in
    clear-linux-os)
        # Validations
        if ! lscpu | grep avx512f | grep avx512vl | grep avx512bw | grep avx512dq | grep avx512cd \
            && [[ "${DLRS_TYPE}" == *mkl* ]]; then
            echo "ERROR - Your platform doesn't support the Intel® AVX-512"
            echo "instruction set which is required for Intel® MKL-DNN or"
            echo "Intel® MKL-DNN-VNNI image"
            exit
        fi
        sudo mkdir -p /etc/systemd/resolved.conf.d
        printf "[Resolve]\nDNSSEC=false" | sudo tee /etc/systemd/resolved.conf.d/dnssec.conf

        clr_version=$(swupd info | grep "Installed version:" | awk -F ":" '{print $2}')
        if _vercmp "${clr_version}" '<' "26240" ; then
            echo "WARN - The Clear Linux OS version ${clr_version} is"
            echo "not supported and it'll be upgraded"
            sudo -E swupd update
        fi
    ;;
esac

_install_docker
docker_server_version=$(sudo docker version --format '{{.Server.Version}}')
if _vercmp "${docker_server_version}" '<' "18.06.1" ; then
    echo "ERROR - The Docker server version ${docker_server_version}"
    echo "is not supported."
    sudo -E swupd update
fi

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

docker_run_cmd="sudo docker run --detach --privileged"
# shellcheck disable=SC1091
source /etc/os-release || source /usr/lib/os-release
case ${ID,,} in
    ubuntu|debian)
        docker_run_cmd+=" --runtime=nvidia"
        if [[ "${DLRS_TYPE}" == *pytorch-mkl* ]]; then
            docker_run_cmd+=" caffe2ai/caffe2:c2v0.8.1.cuda8.cudnn7.ubuntu16.04 python /caffe2/caffe2/python/convnet_benchmarks.py --batch_size 32 --cpu --model AlexNet"
        else
            docker_run_cmd+=" electrocucaracha/${DLRS_TYPE}"
        fi
    ;;
    clear-linux-os)
        docker_run_cmd+=" electrocucaracha/${DLRS_TYPE}"
    ;;
esac

eval "$docker_run_cmd"
echo "INFO - DLRS Provision Completed"
