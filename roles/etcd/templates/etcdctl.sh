#!/bin/bash
alias e="etcdctl"
alias em="etcdctl member"
export ETCDCTL_ENDPOINTS="{% for ip in groups['etcd']|sort %}{% if not loop.first %},{% endif %}https://{{ ip }}:{{ etcd_port }}{% endfor %}"
export ETCDCTL_CACERT=/etc/pki/ca.crt
{% if inventory_hostname in groups['infra'] %}
export ETCDCTL_CERT=/etc/pki/infra.crt
export ETCDCTL_KEY=/etc/pki/infra.key
{% else %}
export ETCDCTL_CERT=/etc/etcd/server.crt
export ETCDCTL_KEY=/etc/etcd/server.key
{% endif %}