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

dest_folder=${DLRS_DEST:-/tmp/dlrs}

# shellcheck disable=SC1091
source /etc/os-release || source /usr/lib/os-release
case ${ID,,} in
    clear-linux-os)
        sudo -E swupd bundle-add git
    ;;
esac

sudo rm -rf "${dest_folder}"
git clone --depth 1 https://github.com/electrocucaracha/dlrs "${dest_folder}"
cd "${dest_folder}"
./postinstall.sh | tee postinstall.log
