#==============================================================#
# File      :   openbao.hcl
# Desc      :   OpenBao server config for {{ vault_instance }}
# Host      :   {{ vault_instance }} @ {{ inventory_hostname }}:{{ vault_port }}
# Path      :   /etc/openbao/openbao.hcl
# Docs      :   https://openbao.org/docs/configuration/
# Note      :   ANSIBLE MANAGED, DO NOT CHANGE!
# License   :   Apache-2.0 @ https://pigsty.io/docs/about/license/
# Copyright :   2018-2026  Ruohang Feng / Vonng (rh@vonng.com)
#==============================================================#
cluster_name = "{{ vault_cluster }}"
ui           = true
log_level    = "info"

# a kms needs read-after-write consistency, not read scalability: standbys
# forward every request to the active member instead of serving stale reads
disable_standby_reads = true

#--------------------------------------------------------------#
# Storage: integrated raft, members join with retry_join
#--------------------------------------------------------------#
storage "raft" {
  path    = "{{ vault_data }}/raft"
  node_id = "{{ vault_instance }}"
{% if vault_members|length > 1 %}
{% for ip in vault_members %}
  retry_join {
    leader_api_addr     = "https://{{ ip }}:{{ vault_port }}"
    leader_ca_cert_file = "/etc/openbao/tls/ca.crt"
  }
{% endfor %}
{% endif %}
}

#--------------------------------------------------------------#
# Listener: node ip & loopback only, vip:{{ vault_port }} is left to haproxy
#--------------------------------------------------------------#
listener "tcp" {
  address            = "{{ inventory_hostname }}:{{ vault_port }}"
  cluster_address    = "{{ inventory_hostname }}:{{ vault_port|int + 1 }}"
  tls_cert_file      = "/etc/openbao/tls/server.crt"
  tls_key_file       = "/etc/openbao/tls/server.key"
  tls_client_ca_file = "/etc/openbao/tls/ca.crt"
  tls_min_version    = "tls13"
  telemetry {
    unauthenticated_metrics_access = true
  }
}

listener "tcp" {
  address            = "127.0.0.1:{{ vault_port }}"
  cluster_address    = "127.0.0.1:{{ vault_port|int + 1 }}"
  tls_cert_file      = "/etc/openbao/tls/server.crt"
  tls_key_file       = "/etc/openbao/tls/server.key"
  tls_client_ca_file = "/etc/openbao/tls/ca.crt"
  tls_min_version    = "tls13"
}

# advertise this member's own address: never a shared domain or vip
api_addr     = "https://{{ inventory_hostname }}:{{ vault_port }}"
cluster_addr = "https://{{ inventory_hostname }}:{{ vault_port|int + 1 }}"

#--------------------------------------------------------------#
# Seal: static auto-unseal key from files/pki/vault/unseal.key
#--------------------------------------------------------------#
seal "static" {
  current_key_id = "{{ vault_seal_key_id }}"
  current_key    = "file:///etc/openbao/unseal.key"
}

#--------------------------------------------------------------#
# Audit & Telemetry
#--------------------------------------------------------------#
audit "file" "audit" {
  options {
    file_path = "/var/log/openbao/audit.log"
  }
}

telemetry {
  prometheus_retention_time = "24h"
  disable_hostname          = true
  usage_gauge_period        = "10m"
  maximum_gauge_cardinality = 500
}
