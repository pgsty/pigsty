#!/bin/bash
alias e="etcdctl"
alias em="etcdctl member"
export ETCDCTL_ENDPOINTS="{{ etcdctl_endpoints }}"
{% if inventory_hostname in groups['etcd']|default([]) %}
export ETCDCTL_CACERT=/etc/etcd/ca.crt
export ETCDCTL_CERT=/etc/etcd/server.crt
export ETCDCTL_KEY=/etc/etcd/server.key
{% endif %}

case "$(id -un)" in
  root{{ '|' + node_admin_username if node_admin_enabled and node_admin_username != '' and node_admin_username != 'root' else '' }})
    [ -r /etc/etcd/etcd.pass ] && export ETCDCTL_USER="root:$(cat /etc/etcd/etcd.pass)"
    ;;
esac