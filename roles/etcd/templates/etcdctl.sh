#!/bin/bash
alias e="etcdctl"
alias em="etcdctl member"
export ETCDCTL_ENDPOINTS="{% for ip in groups[etcd_cluster]|sort %}{% if not loop.first %},{% endif %}https://{{ ip }}:{{ etcd_port }}{% endfor %}"
{% if inventory_hostname in groups['infra']|default([]) %}
export ETCDCTL_CACERT=/etc/pki/ca.crt
export ETCDCTL_CERT=/etc/pki/infra.crt
export ETCDCTL_KEY=/etc/pki/infra.key
{% else %}
export ETCDCTL_CACERT=/etc/etcd/ca.crt
export ETCDCTL_CERT=/etc/etcd/server.crt
export ETCDCTL_KEY=/etc/etcd/server.key
{% endif %}