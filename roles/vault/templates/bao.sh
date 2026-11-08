#!/bin/bash
#==============================================================#
# File      :   bao.sh
# Desc      :   bao cli environment for vault {{ vault_instance }}
# Path      :   /etc/profile.d/bao.sh
# Note      :   ANSIBLE MANAGED, DO NOT CHANGE!
# License   :   Apache-2.0 @ https://pigsty.io/docs/about/license/
# Copyright :   2018-2026  Ruohang Feng / Vonng (rh@vonng.com)
#==============================================================#
# admin token: root_token in files/pki/vault/init.json on admin node
export BAO_ADDR="https://127.0.0.1:{{ vault_port }}"
export BAO_CACERT="/etc/openbao/tls/ca.crt"
