#!/usr/bin/env python3
"""Generate Pigsty's native MySQL dashboards.

The dashboards are intentionally generated from a compact, reviewable source.
Run this file after changing the panel catalogue; grafana.py will load only the
resulting JSON files.
"""

from __future__ import annotations

import json
from pathlib import Path
from string import ascii_uppercase


ROOT = Path(__file__).resolve().parent
PROM = {"type": "prometheus", "uid": "ds-prometheus"}
VLOGS = {"type": "victoriametrics-logs-datasource", "uid": "ds-vlogs"}
BLUE = "#3E668F"
GREEN = "#346f36cc"
YELLOW = "#EAB839"
ORANGE = "#EF843C"
RED = "#E24D42"
PURPLE = "#B783AF"


def thresholds(*steps):
    return {"mode": "absolute", "steps": [{"color": color, "value": value} for value, color in steps]}


def prom_target(expr, legend="{{ins}}", ref="A", instant=False, fmt="time_series"):
    return {
        "datasource": PROM,
        "editorMode": "code",
        "expr": expr,
        "format": fmt,
        "instant": instant,
        "range": not instant,
        "legendFormat": legend,
        "refId": ref,
    }


def stat(title, expr, unit="short", description="", legend=None, steps=None, decimals=1, links=None, text_mode="value_and_name"):
    expressions = expr if isinstance(expr, list) else [(expr, title if legend is None else legend)]
    return {
        "type": "stat",
        "title": "",
        "description": description,
        "datasource": PROM,
        "fieldConfig": {
            "defaults": {
                "color": {"mode": "thresholds"},
                "decimals": decimals,
                "unit": unit,
                "thresholds": steps or thresholds((None, BLUE)),
            },
            "overrides": [],
        },
        "options": {
            "colorMode": "background",
            "graphMode": "area",
            "justifyMode": "auto",
            "orientation": "horizontal",
            "reduceOptions": {"calcs": ["lastNotNull"], "fields": "", "values": False},
            "showPercentChange": False,
            "textMode": text_mode,
            "wideLayout": True,
        },
        "links": links or [],
        "targets": [prom_target(e, l, ascii_uppercase[i], True) for i, (e, l) in enumerate(expressions)],
    }


def timeseries(title, series, unit="short", description="", decimals=1, min_value=0, max_value=None,
               stack=False, fill=20, links=None, steps=None):
    defaults = {
        "color": {"mode": "palette-classic"},
        "custom": {
            "axisCenteredZero": False,
            "axisColorMode": "text",
            "axisLabel": "",
            "axisPlacement": "auto",
            "barAlignment": 0,
            "drawStyle": "line",
            "fillOpacity": fill,
            "gradientMode": "none",
            "hideFrom": {"legend": False, "tooltip": False, "viz": False},
            "insertNulls": False,
            "lineInterpolation": "linear",
            "lineWidth": 1,
            "pointSize": 4,
            "scaleDistribution": {"type": "linear"},
            "showPoints": "never",
            "spanNulls": True,
            "stacking": {"group": "A", "mode": "normal" if stack else "none"},
            "thresholdsStyle": {"mode": "off"},
        },
        "decimals": decimals,
        "min": min_value,
        "thresholds": steps or thresholds((None, GREEN)),
        "unit": unit,
    }
    if max_value is not None:
        defaults["max"] = max_value
    return {
        "type": "timeseries",
        "title": title,
        "description": description,
        "datasource": PROM,
        "fieldConfig": {"defaults": defaults, "overrides": []},
        "options": {
            "legend": {"calcs": ["lastNotNull", "mean", "max"], "displayMode": "table", "placement": "bottom", "showLegend": True},
            "tooltip": {"hideZeros": False, "mode": "multi", "sort": "desc"},
        },
        "links": links or [],
        "targets": [prom_target(expr, legend, ascii_uppercase[i]) for i, (expr, legend) in enumerate(series)],
    }


def bargauge(title, expr, unit="short", description="", legend="{{ins}}", max_value=None, steps=None):
    defaults = {
        "color": {"mode": "thresholds"},
        "decimals": 1,
        "min": 0,
        "thresholds": steps or thresholds((None, GREEN), (0.70, YELLOW), (0.90, RED)),
        "unit": unit,
    }
    if max_value is not None:
        defaults["max"] = max_value
    return {
        "type": "bargauge",
        "title": title,
        "description": description,
        "datasource": PROM,
        "fieldConfig": {"defaults": defaults, "overrides": []},
        "options": {
            "displayMode": "gradient",
            "maxVizHeight": 300,
            "minVizHeight": 10,
            "minVizWidth": 0,
            "namePlacement": "auto",
            "orientation": "horizontal",
            "reduceOptions": {"calcs": ["lastNotNull"], "fields": "", "values": False},
            "showUnfilled": True,
            "sizing": "auto",
            "valueMode": "color",
        },
        "targets": [prom_target(expr, legend, "A", True)],
    }


def table(title, queries, by="ins", description="", renames=None, exclude=None, links=None, units=None, sort=None):
    renames = renames or {}
    exclude = exclude or {}
    default_excludes = {"Time": True, "__name__": True, "job": True}
    for i in range(1, len(queries) + 1):
        default_excludes.update({f"Time {i}": True, f"__name__ {i}": True, f"job {i}": True})
        if i > 1:
            for label in ("cls", "topology", "ip", "instance", "member_role", "member_state"):
                default_excludes[f"{label} {i - 1}"] = True
    default_excludes.update(exclude)
    overrides = []
    for field, url in (links or {}).items():
        overrides.append({
            "matcher": {"id": "byName", "options": field},
            "properties": [{"id": "links", "value": [{"title": field, "url": url}]}],
        })
    for field, unit in (units or {}).items():
        overrides.append({"matcher": {"id": "byName", "options": field}, "properties": [{"id": "unit", "value": unit}]})
    transformations = []
    if len(queries) > 1:
        transformations.append({"id": "seriesToColumns", "options": {"byField": by}})
    transformations.append({"id": "organize", "options": {"excludeByName": default_excludes, "renameByName": renames}})
    return {
        "type": "table",
        "title": title,
        "description": description,
        "datasource": PROM,
        "fieldConfig": {
            "defaults": {
                "color": {"mode": "thresholds"},
                "custom": {"align": "auto", "cellOptions": {"type": "auto"}, "footer": {"reducers": []}},
                "thresholds": thresholds((None, BLUE)),
            },
            "overrides": overrides,
        },
        "options": {"cellHeight": "sm", "showHeader": True, "sortBy": sort or []},
        "targets": [prom_target(expr, legend, ascii_uppercase[i], True, "table") for i, (expr, legend) in enumerate(queries)],
        "transformations": transformations,
    }


def logs(title, query, description=""):
    return {
        "type": "logs",
        "title": title,
        "description": description,
        "datasource": VLOGS,
        "fieldConfig": {"defaults": {}, "overrides": []},
        "options": {
            "dedupStrategy": "none",
            "detailsMode": "sidebar",
            "enableInfiniteScrolling": True,
            "enableLogDetails": True,
            "fontSize": "small",
            "prettifyLogMessage": False,
            "showCommonLabels": False,
            "showControls": True,
            "showLabels": True,
            "showTime": True,
            "sortOrder": "Descending",
            "syntaxHighlighting": False,
            "wrapLogMessage": True,
        },
        "targets": [{
            "datasource": VLOGS,
            "editorMode": "code",
            "expr": query,
            "instant": False,
            "legendFormat": "{{ app }}",
            "queryType": "instant",
            "range": True,
            "refId": "A",
        }],
    }


def text_panel(title, markdown):
    return {"type": "text", "title": title, "options": {"code": {"language": "plaintext", "showLineNumbers": False, "showMiniMap": False}, "content": markdown, "mode": "markdown"}}


def variable(name, label, query, *, multi=False, include_all=False, hide=0, refresh=1, all_value=None):
    result = {
        "allowCustomValue": False,
        "current": {},
        "datasource": PROM,
        "definition": query,
        "description": label,
        "hide": hide,
        "includeAll": include_all,
        "label": label,
        "multi": multi,
        "name": name,
        "options": [],
        "query": {"query": query, "refId": "StandardVariableQuery"},
        "refresh": refresh,
        "regex": "",
        "regexApplyTo": "value",
        "skipUrlSync": False,
        "sort": 1,
        "type": "query",
    }
    if all_value is not None:
        result["allValue"] = all_value
    return result


class Dashboard:
    def __init__(self, uid, title, description, variables, time_from="now-6h"):
        self.uid = uid
        self.title = title
        self.description = description
        self.variables = variables
        self.panels = []
        self.y = 0
        self.next_id = 1
        self.time_from = time_from

    def _place(self, panel, x, w, h):
        panel["id"] = self.next_id
        panel["gridPos"] = {"h": h, "w": w, "x": x, "y": self.y}
        panel.setdefault("pluginVersion", "13.1.0")
        self.next_id += 1
        self.panels.append(panel)

    def row(self, title, collapsed=False):
        panel = {"type": "row", "title": title, "collapsed": collapsed}
        self._place(panel, 0, 24, 1)
        self.y += 1

    def band(self, items, height=7):
        x = 0
        for panel, width in items:
            self._place(panel, x, width, height)
            x += width
        if x != 24:
            raise ValueError(f"dashboard row width is {x}, expected 24")
        self.y += height

    def render(self):
        section = self.uid.split("-", 1)[1].title()
        tags = ["Pigsty", "MYSQL", section]
        if self.uid == "mysql-overview":
            tags.append("HOME")
        return {
            "annotations": {"list": [{"builtIn": 1, "datasource": {"type": "grafana", "uid": "-- Grafana --"}, "enable": True, "hide": True, "iconColor": RED, "name": "Annotations & Alerts", "type": "dashboard"}]},
            "description": self.description,
            "editable": True,
            "fiscalYearStartMonth": 0,
            "graphTooltip": 1,
            "id": None,
            "links": [{"asDropdown": True, "icon": "external link", "includeVars": True, "keepTime": True, "tags": ["MYSQL"], "targetBlank": False, "title": "MYSQL", "tooltip": "", "type": "dashboards", "url": ""}],
            "liveNow": False,
            "panels": self.panels,
            "refresh": "30s",
            "schemaVersion": 42,
            "tags": tags,
            "templating": {"list": self.variables},
            "time": {"from": self.time_from, "to": "now"},
            "timepicker": {},
            "timezone": "browser",
            "title": self.title,
            "uid": self.uid,
            "version": 1,
            "weekStart": "",
        }


def cluster_vars():
    return [
        variable("cls", "Cluster", 'label_values(up{job="mysql"},cls)'),
        variable("topology", "Topology", 'label_values(up{job="mysql",cls="$cls"},topology)', hide=2, refresh=2),
        variable("primary", "Runtime Primary", 'label_values(mysql:ins:gr_primary{cls="$cls"},ins)', hide=2, refresh=2),
        variable("members", "Members", 'label_values(up{job="mysql",cls="$cls"},ip)', multi=True, include_all=True, hide=2, refresh=2),
        variable("instances", "Instances", 'label_values(up{job="mysql",cls="$cls"},ins)', multi=True, include_all=True, hide=2, refresh=2),
    ]


def instance_vars():
    return [
        variable("ins", "Instance", 'label_values(up{job="mysql"},ins)'),
        variable("cls", "Cluster", 'label_values(up{job="mysql",ins="$ins"},cls)', hide=2),
        variable("ip", "IP", 'label_values(up{job="mysql",ins="$ins"},ip)', hide=2),
        variable("topology", "Topology", 'label_values(up{job="mysql",ins="$ins"},topology)', hide=2),
    ]


def overview_dashboard():
    d = Dashboard("mysql-overview", "MySQL Overview", "MySQL 8.4 fleet health, topology and workload.", [
        variable("cls", "Cluster", 'label_values(up{job="mysql"},cls)', multi=True, include_all=True, all_value=".*"),
    ])
    f = '{cls=~"$cls"}'
    d.row("Fleet Overview")
    d.band([
        (stat("Clusters", 'count(mysql:cls:instances{cls=~"$cls"})', decimals=0, description="Declared standalone and three-member clusters."), 4),
        (stat("Healthy Clusters", 'count(mysql:cls:health{cls=~"$cls"} == 2)', decimals=0, steps=thresholds((None, RED), (1, GREEN)), description="Health 2 means all declared members are healthy."), 4),
        (stat("MySQL Up", f'sum(mysql:ins:up{f})', decimals=0, steps=thresholds((None, RED), (1, GREEN)), description="mysqld instances reachable by the exporter."), 4),
        (stat("QPS", f'sum(mysql:ins:qps{f})', unit="ops", description="Questions per second across the selected fleet."), 4),
        (stat("Active Alerts", 'count(ALERTS{alertstate="firing",category="mysql",cls=~"$cls"}) or (vector(0) and on() (count(up{job="mysql",cls=~"$cls"}) > 0))', decimals=0, steps=thresholds((None, GREEN), (1, RED)), links=[{"title": "MySQL Alerts", "url": "/d/mysql-alert?var-cls=$cls&${__url_time_range}"}]), 8),
    ], 4)
    d.band([(table("Cluster Inventory", [
        ('mysql:cls:instances{cls=~"$cls"}', "Declared"),
        ('mysql:cls:up{cls=~"$cls"}', "Up"),
        ('mysql:cls:health{cls=~"$cls"}', "Health"),
        ('mysql:cls:gr_primary_members{cls=~"$cls"} or on(cls,topology) (0 * mysql:cls:instances{cls=~"$cls",topology="standalone"})', "Primary"),
        (f'sum by (cls) (mysql:ins:qps{f})', "QPS"),
        (f'max by (cls) (mysql:ins:connection_usage{f})', "Conn%"),
    ], by="cls", renames={"Value #A": "Declared", "Value #B": "Up", "Value #C": "Health", "Value #D": "Primary", "Value #E": "QPS", "Value #F": "Conn%", "cls": "Cluster"}, links={"Cluster": "/d/mysql-cluster?var-cls=${__data.fields.Cluster}&${__url_time_range}"}, units={"QPS": "ops", "Conn%": "percentunit"}, sort=[{"displayName": "Cluster", "desc": False}]), 24)], 8)
    d.row("Workload and HA")
    d.band([
        (timeseries("Fleet QPS / TPS", [(f'sum(mysql:ins:qps{f})', "QPS"), (f'sum(mysql:ins:tps{f})', "TPS")], "ops", "Workload trend for capacity planning."), 12),
        (timeseries("Cluster Health", [('mysql:cls:health{cls=~"$cls"}', "{{cls}} (2 healthy / 1 degraded / 0 critical)")], "short", "Runtime health combines quorum, primary count and member availability.", max_value=2), 12),
    ], 8)
    d.band([
        (timeseries("GR Queues", [('mysql:ins:gr_certifier_queue{cls=~"$cls"}', "certifier / {{ins}}"), ('mysql:ins:gr_applier_queue{cls=~"$cls"}', "applier / {{ins}}")], "short", "HA-only queue depth; no series is expected for standalone."), 24),
    ], 8)
    d.band([(table("Instance Inventory", [
        (f'mysql:ins:exporter_up{f}', "Exporter"), (f'mysql:ins:up{f}', "MySQL"), (f'mysql:ins:gr_member{f}', "GR"), (f'mysql:ins:qps{f}', "QPS"),
        (f'mysql:ins:connections{f}', "Connections"), (f'mysql:ins:connection_usage{f}', "Conn%"),
        (f'mysql:ins:buffer_pool_hit_ratio{f}', "BP Hit"),
    ], renames={"ins": "Instance", "cls": "Cluster", "ip 1": "IP", "member_role": "Runtime Role", "member_state": "GR State", "Value #A": "Exporter", "Value #B": "MySQL", "Value #C": "GR", "Value #D": "QPS", "Value #E": "Connections", "Value #F": "Conn%", "Value #G": "BP Hit"}, exclude={"member_id": True, "member_host": True, "member_port": True, "channel_name": True, "ip 1": False}, links={"Instance": "/d/mysql-instance?var-ins=${__data.fields.Instance}&${__url_time_range}", "Cluster": "/d/mysql-cluster?var-cls=${__data.fields.Cluster}&${__url_time_range}", "IP": "/d/node-instance?var-id=${__data.fields.IP}&${__url_time_range}"}, units={"Exporter": "bool", "MySQL": "bool", "GR": "bool", "QPS": "ops", "Conn%": "percentunit", "BP Hit": "percentunit"}), 24)], 10)
    return d


def cluster_dashboard():
    d = Dashboard("mysql-cluster", "MySQL Cluster", "Standalone or InnoDB Cluster runtime topology, workload and node capacity.", cluster_vars())
    f = '{cls="$cls"}'
    d.row("Cluster Overview")
    d.band([
        (stat("Health", f'mysql:cls:health{f}', decimals=0, steps=thresholds((None, RED), (1, YELLOW), (2, GREEN)), description="2 healthy, 1 degraded but writable, 0 critical."), 6),
        (stat("Declared", f'mysql:cls:instances{f}', decimals=0), 6),
        (stat("Online", f'mysql:cls:gr_online_members{f} or mysql:cls:up{{cls="$cls",topology="standalone"}}', decimals=0), 6),
        (stat("Runtime Primary", f'mysql:cls:gr_primary_members{f} or on(cls,topology) (0 * mysql:cls:instances{{cls="$cls",topology="standalone"}})', decimals=0, links=[{"title": "Primary Instance", "url": "/d/mysql-instance?var-ins=$primary&${__url_time_range}"}]), 6),
    ], 4)
    d.band([(table("Member Topology", [
        (f'mysql:ins:exporter_up{f}', "Exporter"), (f'mysql:ins:up{f}', "MySQL"), (f'mysql:ins:gr_member{f}', "GR"),
        (f'mysql:ins:connection_usage{f}', "Conn%"), (f'mysql:ins:gr_certifier_queue{f}', "Cert Queue"), (f'mysql:ins:gr_applier_queue{f}', "Apply Queue"),
        (f'mysql_global_variables_read_only{f}', "Read Only"), (f'mysql_global_variables_super_read_only{f}', "Super RO"),
    ], renames={"ins": "Instance", "ip 1": "IP", "member_role": "Runtime Role", "member_state": "GR State", "Value #A": "Exporter", "Value #B": "MySQL", "Value #C": "GR", "Value #D": "Conn%", "Value #E": "Cert Queue", "Value #F": "Apply Queue", "Value #G": "Read Only", "Value #H": "Super RO"}, exclude={"member_id": True, "member_host": True, "member_port": True, "channel_name": True, "ip 1": False}, links={"Instance": "/d/mysql-instance?var-ins=${__data.fields.Instance}&${__url_time_range}", "IP": "/d/node-instance?var-id=${__data.fields.IP}&${__url_time_range}"}, units={"Exporter": "bool", "MySQL": "bool", "GR": "bool", "Conn%": "percentunit", "Read Only": "bool", "Super RO": "bool"}), 24)], 9)
    d.row("Workload")
    d.band([
        (timeseries("QPS by Instance", [(f'mysql:ins:qps{f}', "{{ins}}")], "ops", "Questions per second by member."), 12),
        (timeseries("TPS by Instance", [(f'mysql:ins:tps{f}', "{{ins}}")], "ops", "Transaction completion rate by member."), 12),
    ], 8)
    d.band([
        (timeseries("Read / Write", [(f'mysql:ins:read_qps{f}', "read / {{ins}}"), (f'mysql:ins:write_qps{f}', "write / {{ins}}")], "ops"), 12),
        (timeseries("Row Operations", [(f'mysql:ins:row_ops{f}', "{{operation}} / {{ins}}")], "ops", "InnoDB logical row operations."), 12),
    ], 8)
    d.row("Connections and Query Efficiency")
    d.band([
        (timeseries("Connections", [(f'mysql:ins:connections{f}', "connected / {{ins}}"), (f'mysql:ins:threads_running{f}', "running / {{ins}}")], "short"), 8),
        (timeseries("Connection Usage", [(f'mysql:ins:connection_usage{f}', "{{ins}}")], "percentunit", max_value=1), 8),
        (timeseries("Slow / Aborted", [(f'mysql:ins:slow_queries{f}', "slow / {{ins}}"), (f'mysql:ins:aborted_connects{f}', "aborted connect / {{ins}}"), (f'mysql:ins:connection_errors{f}', "error / {{ins}}")], "ops"), 8),
    ], 8)
    d.band([
        (timeseries("Temporary Tables", [(f'mysql:ins:tmp_tables{f}', "all / {{ins}}"), (f'mysql:ins:tmp_disk_tables{f}', "disk / {{ins}}")], "ops"), 8),
        (timeseries("Scan and Join Risk", [(f'mysql:ins:full_scans{f}', "full scan / {{ins}}"), (f'mysql:ins:full_joins{f}', "full join / {{ins}}")], "ops"), 8),
        (timeseries("Buffer Pool Hit", [(f'mysql:ins:buffer_pool_hit_ratio{f}', "{{ins}}")], "percentunit", max_value=1), 8),
    ], 8)
    d.row("InnoDB Cluster (HA only)")
    d.band([
        (timeseries("Certification / Applier Queue", [(f'mysql:ins:gr_certifier_queue{f}', "certifier / {{ins}}"), (f'mysql:ins:gr_applier_queue{f}', "applier / {{ins}}")], "short", "No data is expected for standalone topology."), 12),
        (timeseries("Certification Conflicts / Applied", [(f'mysql:ins:gr_conflict_rate{f}', "conflicts / {{ins}}"), (f'mysql:ins:gr_applied_rate{f}', "applied / {{ins}}")], "ops"), 12),
    ], 7)
    d.band([
        (timeseries("Flow-control Pressure", [(f'mysql:ins:gr_certifier_queue_ratio{f}', "certifier / {{ins}}"), (f'mysql:ins:gr_applier_queue_ratio{f}', "applier / {{ins}}")], "percentunit", "Queue depth divided by the configured flow-control threshold.", links=[{"title": "Group Replication", "url": "/d/mysql-replication?var-cls=$cls&${__url_time_range}"}], steps=thresholds((None, GREEN), (0.70, YELLOW), (0.90, RED))), 24),
    ], 7)
    d.row("Node Capacity")
    d.band([
        (timeseries("Node CPU", [('node:ins:cpu_usage{ip=~"$members"}', "{{ip}}")], "percentunit", max_value=1), 8),
        (timeseries("Node Memory", [('node:ins:mem_usage{ip=~"$members"}', "{{ip}}")], "percentunit", max_value=1), 8),
        (timeseries("Filesystem Usage", [('node:fs:space_usage{ip=~"$members",fstype!~"tmpfs|overlay"}', "{{ip}} / {{mountpoint}}")], "percentunit", max_value=1), 8),
    ], 8)
    d.band([
        (timeseries("Disk Throughput", [('node:dev:disk_read_bytes_rate1m{ip=~"$members"}', "read / {{ip}} / {{device}}"), ('node:dev:disk_write_bytes_rate1m{ip=~"$members"}', "write / {{ip}} / {{device}}")], "Bps"), 12),
        (timeseries("Disk Utilization", [('node:dev:disk_util_1m{ip=~"$members"}', "{{ip}} / {{device}}")], "percentunit", max_value=1), 12),
    ], 8)
    d.row("Logs")
    d.band([
        (logs("MySQL / Router Logs", 'job:syslog ip:in(${members:doublequote}) (unit:in("mysql","mysqld","mysqld_exporter","mysqlrouter") OR app:~"mysqld-(${instances:pipe})") | fields level,ins,ip,app,unit,_msg', "Existing node syslog streams filtered by the member IPs and native unit/app fields."), 12),
        (logs("Backup / Restore Logs", 'job:syslog ip:in(${members:doublequote}) (unit:mysql-backup OR app:~"mysql-backup-.*") | fields level,ins,ip,app,unit,_msg', "Controlled backup and restore stage/result messages; SQL text is never centralized."), 12),
    ], 14)
    return d


def instance_dashboard():
    d = Dashboard("mysql-instance", "MySQL Instance", "Deep diagnostics for a single MySQL server, InnoDB, exporter, host and logs.", instance_vars())
    f = '{ins="$ins"}'
    d.row("Instance Overview")
    d.band([
        (stat("Status", f'mysql:ins:up{f}', decimals=0, steps=thresholds((None, RED), (1, GREEN))), 3),
        (stat("Version", f'mysql_version_info{f}', decimals=0, legend="Version {{version}}", text_mode="name"), 3),
        (stat("Uptime", f'mysql_global_status_uptime{f}', unit="s", decimals=0), 3),
        (stat("QPS", f'mysql:ins:qps{f}', unit="ops"), 3),
        (stat("TPS", f'mysql:ins:tps{f}', unit="ops"), 3),
        (stat("Connections", f'mysql:ins:connections{f}', decimals=0), 3),
        (stat("Buffer Hit", f'mysql:ins:buffer_pool_hit_ratio{f}', unit="percentunit", decimals=2), 3),
        (stat("Runtime GR Role", f'mysql:ins:gr_member{f}', decimals=0, legend="GR {{member_role}} / {{member_state}}", text_mode="name", description="Runtime Performance Schema state; standalone intentionally has no GR role."), 3),
    ], 4)
    d.row("Workload")
    d.band([
        (timeseries("QPS / TPS", [(f'mysql:ins:qps{f}', "QPS"), (f'mysql:ins:tps{f}', "TPS")], "ops"), 8),
        (timeseries("Read / Write", [(f'mysql:ins:read_qps{f}', "read"), (f'mysql:ins:write_qps{f}', "write")], "ops"), 8),
        (timeseries("Row Operations", [(f'mysql:ins:row_ops{f}', "{{operation}}")], "ops"), 8),
    ], 8)
    d.band([
        (timeseries("Command Mix", [(f'topk(20, rate(mysql_global_status_commands_total{f}[1m]) > 0)', "{{command}}")], "ops", "Top non-zero SQL command classes.", stack=True), 12),
        (timeseries("Statement Latency", [(f'mysql:ins:statement_latency{f}', "average")], "s", "Average statement latency from Performance Schema summaries."), 6),
        (timeseries("Rows Examined / Query", [(f'mysql:ins:rows_examined_per_query{f}', "average")], "short", "Rows examined per statement; rising values indicate plan or index regressions."), 6),
    ], 8)
    d.row("Connections and Sessions")
    d.band([
        (timeseries("Threads", [(f'mysql:ins:connections{f}', "connected"), (f'mysql:ins:threads_running{f}', "running"), (f'mysql:ins:threads_cached{f}', "cached")], "short"), 8),
        (timeseries("Connection Usage", [(f'mysql:ins:connection_usage{f}', "usage")], "percentunit", max_value=1), 8),
        (timeseries("Connection Churn", [(f'mysql:ins:connection_rate{f}', "new"), (f'mysql:ins:aborted_connects{f}', "aborted connect"), (f'mysql:ins:aborted_clients{f}', "aborted client"), (f'mysql:ins:connection_errors{f}', "error")], "ops"), 8),
    ], 8)
    d.band([
        (timeseries("Processlist by Command", [(f'mysql_info_schema_processlist_threads{f}', "{{command}}")], "short", stack=True), 12),
        (timeseries("Network Traffic", [(f'mysql:ins:rx_bytes{f}', "receive"), (f'mysql:ins:tx_bytes{f}', "send")], "Bps"), 12),
    ], 8)
    d.row("Query Efficiency")
    d.band([
        (timeseries("Temporary Tables", [(f'mysql:ins:tmp_tables{f}', "all"), (f'mysql:ins:tmp_disk_tables{f}', "disk")], "ops"), 8),
        (timeseries("Disk Temporary Ratio", [(f'mysql:ins:tmp_disk_ratio{f}', "disk ratio")], "percentunit", max_value=1), 8),
        (timeseries("Scans and Joins", [(f'mysql:ins:full_scans{f}', "full scan"), (f'mysql:ins:full_joins{f}', "full join"), (f'rate(mysql_global_status_select_range_check{f}[5m])', "range check")], "ops"), 8),
    ], 8)
    d.band([
        (timeseries("Slow / Error / No Index", [(f'mysql:ins:slow_queries{f}', "slow"), (f'mysql:ins:statement_errors{f}', "error"), (f'mysql:ins:no_index_queries{f}', "no index")], "ops"), 8),
        (timeseries("Sort Activity", [(f'rate(mysql_global_status_sort_rows{f}[5m])', "rows"), (f'mysql:ins:sort_merge_passes{f}', "merge passes")], "ops"), 8),
        (timeseries("Table / File Cache", [(f'mysql:ins:table_open_cache_hit_ratio{f}', "table hit"), (f'mysql:ins:open_files_usage{f}', "open files")], "percentunit", max_value=1), 8),
    ], 8)
    d.row("Performance Schema Detail")
    d.band([
        (timeseries("Top Statement Latency", [(f'topk(10,rate(mysql_perf_schema_events_statements_seconds_total{f}[5m]))', "{{schema}} / {{digest_text}}")], "s", "Digest collector is capped at 50 rows and 120 characters."), 8),
        (timeseries("Top Table I/O Wait", [(f'topk(10,rate(mysql_perf_schema_table_io_waits_seconds_total{f}[5m]))', "{{schema}}.{{name}} / {{operation}}")], "s"), 8),
        (timeseries("Top Index I/O Wait", [(f'topk(10,rate(mysql_perf_schema_index_io_waits_seconds_total{f}[5m]))', "{{schema}}.{{name}} / {{index}} / {{operation}}")], "s"), 8),
    ], 8)
    d.row("InnoDB Buffer Pool")
    d.band([
        (timeseries("Buffer Pool Bytes", [(f'mysql_global_status_innodb_buffer_pool_bytes_data{f}', "data"), (f'mysql_global_status_innodb_buffer_pool_bytes_dirty{f}', "dirty"), (f'mysql_global_variables_innodb_buffer_pool_size{f}', "capacity")], "bytes"), 12),
        (timeseries("Buffer Pool Ratios", [(f'mysql:ins:buffer_pool_hit_ratio{f}', "hit"), (f'mysql:ins:buffer_pool_usage{f}', "used"), (f'mysql:ins:buffer_pool_dirty_ratio{f}', "dirty")], "percentunit", max_value=1), 12),
    ], 8)
    d.band([
        (timeseries("Buffer Pool Requests", [(f'rate(mysql_global_status_innodb_buffer_pool_read_requests{f}[5m])', "logical read"), (f'rate(mysql_global_status_innodb_buffer_pool_reads{f}[5m])', "physical read"), (f'rate(mysql_global_status_innodb_buffer_pool_write_requests{f}[5m])', "write")], "ops"), 12),
        (timeseries("Buffer Pool Waits", [(f'mysql:ins:buffer_pool_waits{f}', "wait free")], "ops", "Any sustained wait_free rate indicates buffer flushing cannot keep up."), 12),
    ], 8)
    d.row("InnoDB I/O and Redo")
    d.band([
        (timeseries("InnoDB I/O Bytes", [(f'mysql:ins:data_read_bytes{f}', "read"), (f'mysql:ins:data_write_bytes{f}', "write"), (f'mysql:ins:redo_bytes{f}', "redo")], "Bps"), 12),
        (timeseries("InnoDB IOPS / Fsync", [(f'mysql:ins:data_reads{f}', "read"), (f'mysql:ins:data_writes{f}', "write"), (f'mysql:ins:data_fsyncs{f}', "fsync")], "ops"), 12),
    ], 8)
    d.band([
        (timeseries("Pending I/O", [(f'mysql_global_status_innodb_data_pending_reads{f}', "read"), (f'mysql_global_status_innodb_data_pending_writes{f}', "write"), (f'mysql_global_status_innodb_data_pending_fsyncs{f}', "fsync")], "short"), 8),
        (timeseries("Redo Utilization", [(f'mysql:ins:redo_utilization{f}', "checkpoint age / capacity")], "percentunit", max_value=1), 8),
        (timeseries("Redo Writes and Waits", [(f'rate(mysql_global_status_innodb_log_writes{f}[5m])', "writes"), (f'mysql:ins:log_waits{f}', "waits")], "ops"), 8),
    ], 8)
    d.row("Transactions, Locks and Purge")
    d.band([
        (timeseries("Current Lock Waits", [(f'mysql_global_status_innodb_row_lock_current_waits{f}', "current waits")], "short"), 6),
        (timeseries("Lock Wait / Deadlock Rate", [(f'mysql:ins:row_lock_waits{f}', "lock waits"), (f'mysql:ins:deadlocks{f}', "deadlocks")], "ops"), 6),
        (timeseries("Lock Wait Time Rate", [(f'mysql:ins:row_lock_time{f}', "wait seconds")], "s", "Aggregate lock-wait seconds per wall second; it can exceed one with concurrent waiters."), 6),
        (timeseries("History List Length", [(f'mysql:ins:history_list_length{f}', "undo history")], "short", "A continuously growing history list usually means a long transaction blocks purge."), 6),
    ], 8)
    d.row("InnoDB Cluster (HA only)")
    d.band([
        (timeseries("Certification / Applier Queue", [(f'mysql:ins:gr_certifier_queue{f}', "certifier"), (f'mysql:ins:gr_applier_queue{f}', "applier")], "short", "No data is expected for standalone."), 8),
        (timeseries("Conflict / Apply Rate", [(f'mysql:ins:gr_conflict_rate{f}', "conflict"), (f'mysql:ins:gr_applied_rate{f}', "applied")], "ops"), 8),
        (timeseries("Flow-control Pressure", [(f'mysql:ins:gr_certifier_queue_ratio{f}', "certifier"), (f'mysql:ins:gr_applier_queue_ratio{f}', "applier")], "percentunit", "Queue depth divided by the configured flow-control threshold.", links=[{"title": "Group Replication", "url": "/d/mysql-replication?var-cls=$cls&${__url_time_range}"}], steps=thresholds((None, GREEN), (0.70, YELLOW), (0.90, RED))), 8),
    ], 7)
    d.row("Node")
    d.band([
        (timeseries("CPU", [('node:ins:cpu_usage{ip="$ip"}', "usage")], "percentunit", max_value=1, links=[{"title": "Node Instance", "url": "/d/node-instance?var-id=$ip&${__url_time_range}"}]), 8),
        (timeseries("Memory", [('node:ins:mem_usage{ip="$ip"}', "usage")], "percentunit", max_value=1), 8),
        (timeseries("Load", [('node:ins:stdload1{ip="$ip"}', "load1")], "short"), 8),
    ], 7)
    d.band([
        (timeseries("Disk Throughput", [('node:dev:disk_read_bytes_rate1m{ip="$ip"}', "read / {{device}}"), ('node:dev:disk_write_bytes_rate1m{ip="$ip"}', "write / {{device}}")], "Bps"), 12),
        (timeseries("Disk Utilization / Filesystem", [('node:dev:disk_util_1m{ip="$ip"}', "disk / {{device}}"), ('node:fs:space_usage{ip="$ip",fstype!~"tmpfs|overlay"}', "space / {{mountpoint}}")], "percentunit", max_value=1), 12),
    ], 8)
    d.row("Exporter and Logs")
    d.band([
        (timeseries("Scrape Duration", [(f'scrape_duration_seconds{{job="mysql",ins="$ins"}}', "scrape duration")], "s"), 8),
        (timeseries("Collector Duration", [(f'mysql_exporter_collector_duration_seconds{f}', "{{collector}}")], "s"), 8),
        (timeseries("Collector Failure", [(f'1 - mysql_exporter_collector_success{f}', "{{collector}}")], "bool", max_value=1), 8),
    ], 8)
    d.band([
        (logs("MySQL Logs", 'job:syslog ip:$ip (unit:in("mysql","mysqld","mysqld_exporter") OR app:$ins) | fields level,app,unit,_msg', "Server error and exporter service logs from the existing node syslog stream; the slow-query file remains local-only."), 12),
        (logs("Router / Backup Logs", 'job:syslog ip:$ip (unit:in("mysqlrouter","mysql-backup") OR app:~"mysql-backup-.*") | fields level,app,unit,_msg', "Router and controlled backup/restore stage messages."), 12),
    ], 14)
    return d


def replication_dashboard():
    d = Dashboard("mysql-replication", "MySQL Group Replication", "Runtime InnoDB Cluster membership, role, certification, applier and flow-control health.", cluster_vars())
    f = '{cls="$cls"}'
    d.row("Group Replication Overview")
    d.band([
        (stat("Declared", f'mysql:cls:instances{f}', decimals=0), 4),
        (stat("ONLINE", f'mysql:cls:gr_online_members{f}', decimals=0, steps=thresholds((None, RED), (2, YELLOW), (3, GREEN))), 5),
        (stat("Primary", f'mysql:cls:gr_primary_members{f}', decimals=0, steps=thresholds((None, RED), (1, GREEN), (2, RED))), 5),
        (stat("Quorum", f'mysql:cls:gr_quorum{f}', decimals=0, steps=thresholds((None, RED), (1, GREEN))), 5),
        (stat("Health", f'mysql:cls:health{f}', decimals=0, steps=thresholds((None, RED), (1, YELLOW), (2, GREEN))), 5),
    ], 4)
    d.band([(table("Runtime Membership", [
        (f'mysql:ins:exporter_up{f}', "Exporter"), (f'mysql:ins:up{f}', "MySQL"), (f'mysql:ins:gr_member{f}', "GR"),
        (f'mysql:ins:gr_certifier_queue{f}', "Cert Queue"), (f'mysql:ins:gr_applier_queue{f}', "Apply Queue"),
        (f'mysql_global_variables_group_replication_flow_control_certifier_threshold{f}', "Cert Limit"),
        (f'mysql_global_variables_group_replication_flow_control_applier_threshold{f}', "Apply Limit"),
    ], renames={"ins": "Instance", "ip 1": "IP", "member_role": "Runtime Role", "member_state": "Member State", "member_version": "Version", "Value #A": "Exporter", "Value #B": "MySQL", "Value #C": "GR", "Value #D": "Cert Queue", "Value #E": "Apply Queue", "Value #F": "Cert Limit", "Value #G": "Apply Limit"}, exclude={"member_id": True, "member_host": True, "member_port": True, "channel_name": True, "ip 1": False}, links={"Instance": "/d/mysql-instance?var-ins=${__data.fields.Instance}&${__url_time_range}", "IP": "/d/node-instance?var-id=${__data.fields.IP}&${__url_time_range}"}, units={"Exporter": "bool", "MySQL": "bool", "GR": "bool"}), 24)], 9)
    d.row("Certification and Apply")
    d.band([
        (timeseries("Certification / Applier Queue", [(f'mysql:ins:gr_certifier_queue{f}', "certifier / {{ins}}"), (f'mysql:ins:gr_applier_queue{f}', "applier / {{ins}}")], "short", "Queue depth is a direct, bounded GR backlog signal."), 12),
        (timeseries("Checked / Applied Transactions", [(f'mysql:ins:gr_checked_rate{f}', "checked / {{ins}}"), (f'mysql:ins:gr_applied_rate{f}', "remote applied / {{ins}}")], "ops"), 12),
    ], 8)
    d.band([
        (timeseries("Certification Conflicts", [(f'mysql:ins:gr_conflict_rate{f}', "{{ins}}")], "ops", "Transactions rejected by GR certification per second."), 12),
        (timeseries("Binlog Size", [(f'mysql:ins:binlog_bytes{f}', "{{ins}}")], "bytes"), 12),
    ], 8)
    d.row("Flow Control")
    d.band([
        (timeseries("Flow-control Pressure", [(f'mysql:ins:gr_certifier_queue_ratio{f}', "certifier / {{ins}}"), (f'mysql:ins:gr_applier_queue_ratio{f}', "applier / {{ins}}")], "percentunit", "Queue depth divided by the configured flow-control threshold.", steps=thresholds((None, GREEN), (0.70, YELLOW), (0.90, RED))), 12),
        (timeseries("Flow-control Thresholds", [(f'mysql_global_variables_group_replication_flow_control_certifier_threshold{f}', "certifier / {{ins}}"), (f'mysql_global_variables_group_replication_flow_control_applier_threshold{f}', "applier / {{ins}}")], "short", "Configured queue depths where Group Replication begins flow control."), 12),
    ], 7)
    d.band([
        (timeseries("Read-only Safety", [(f'mysql_global_variables_read_only{f}', "read_only / {{ins}}"), (f'mysql_global_variables_super_read_only{f}', "super_read_only / {{ins}}")], "bool", max_value=1), 12),
        (timeseries("Workload by Member", [(f'mysql:ins:qps{f}', "QPS / {{ins}}"), (f'mysql:ins:write_qps{f}', "writes / {{ins}}")], "ops"), 12),
    ], 8)
    d.row("Logs")
    d.band([
        (logs("Group Replication Logs", 'job:syslog ip:in(${members:doublequote}) (unit:in("mysql","mysqld") OR app:~"mysqld-(${instances:pipe})") _msg:~"(?i)(group replication|member|primary|secondary|rejoin|recovery|clone|certif)" | fields level,ins,ip,app,unit,_msg'), 12),
        (logs("Router Logs", 'job:syslog ip:in(${members:doublequote}) unit:mysqlrouter | fields level,ins,ip,app,unit,_msg'), 12),
    ], 14)
    return d


def alert_dashboard():
    variables = [
        variable("cls", "Cluster", 'label_values(up{job="mysql"},cls)', multi=True, include_all=True, all_value=".*"),
        variable("ins", "Instance", 'label_values(up{job="mysql",cls=~"$cls"},ins)', multi=True, include_all=True, all_value=".*"),
        variable("members", "Members", 'label_values(up{job="mysql",cls=~"$cls",ins=~"$ins"},ip)', multi=True, include_all=True, hide=2, refresh=2),
    ]
    d = Dashboard("mysql-alert", "MySQL Alert", "Active alerts, recent risk signals, logs and first-response guidance.", variables, "now-24h")
    def firing(extra=""):
        base = 'alertstate="firing",category="mysql",cls=~"$cls"'
        return f'(ALERTS{{{base},ins=~"$ins"{extra}}} or ALERTS{{{base},ins=""{extra}}})'

    f = '{cls=~"$cls",ins=~"$ins"}'
    zero = '(vector(0) and on() (count(up{job="mysql",cls=~"$cls",ins=~"$ins"}) > 0))'
    d.row("Active Alerts")
    d.band([
        (stat("Total", f'count({firing()}) or {zero}', decimals=0, steps=thresholds((None, GREEN), (1, RED))), 4),
        (stat("Critical", f'count({firing(",severity=\"CRIT\"")}) or {zero}', decimals=0, steps=thresholds((None, GREEN), (1, RED))), 4),
        (stat("Warning", f'count({firing(",severity=\"WARN\"")}) or {zero}', decimals=0, steps=thresholds((None, GREEN), (1, ORANGE))), 4),
        (stat("Info", f'count({firing(",severity=\"INFO\"")}) or {zero}', decimals=0, steps=thresholds((None, GREEN), (1, BLUE))), 4),
        (stat("Affected Clusters", f'count(count by (cls) ({firing()})) or {zero}', decimals=0), 4),
        (stat("Affected Instances", f'count(count by (ins) (ALERTS{{alertstate="firing",category="mysql",cls=~"$cls",ins=~"$ins",ins!=""}})) or {zero}', decimals=0), 4),
    ], 4)
    d.band([(table("Firing Alerts", [(firing(), "State")], renames={"alertname": "Alert", "cls": "Cluster", "ins": "Instance", "severity": "Severity", "Value": "State", "Value #A": "State"}, links={"Instance": "/d/mysql-instance?var-ins=${__data.fields.Instance}&${__url_time_range}", "Cluster": "/d/mysql-cluster?var-cls=${__data.fields.Cluster}&${__url_time_range}"}), 24)], 9)
    d.band([(timeseries("Alert Timeline", [(f'sum by (alertname,severity,cls,ins) ({firing()})', "{{severity}} / {{alertname}} / {{ins}}")], "short", "Active alert state over the selected time range.", stack=True), 24)], 8)
    d.row("Immediate Risk Signals")
    d.band([
        (timeseries("Availability", [(f'mysql:ins:up{f}', "{{ins}}")], "bool", max_value=1), 8),
        (timeseries("Connection Saturation", [(f'mysql:ins:connection_usage{f}', "{{ins}}")], "percentunit", max_value=1), 8),
        (timeseries("GR Queue Depth", [(f'mysql:ins:gr_certifier_queue{f}', "certifier / {{ins}}"), (f'mysql:ins:gr_applier_queue{f}', "applier / {{ins}}")], "short"), 8),
    ], 8)
    d.band([
        (timeseries("Redo / Buffer Pressure", [(f'mysql:ins:redo_utilization{f}', "redo / {{ins}}"), (f'1 - mysql:ins:buffer_pool_hit_ratio{f}', "buffer miss / {{ins}}")], "percentunit", max_value=1), 12),
        (timeseries("Lock and Purge Risk", [(f'mysql:ins:deadlocks{f}', "deadlocks / {{ins}}"), (f'mysql:ins:row_lock_waits{f}', "lock waits / {{ins}}"), (f'mysql:ins:history_list_length{f} / 1000000', "history million / {{ins}}")], "short"), 12),
    ], 8)
    d.row("Logs and First Response")
    d.band([
        (logs("Critical MySQL Platform Logs", 'job:syslog ip:in(${members:doublequote}) (unit:in("mysql","mysqld","mysqld_exporter","mysqlrouter","mysql-backup") OR app:~"mysqld-(${ins:pipe})" OR app:~"mysql-backup-.*") p:<4 | fields level,app,unit,ip,_msg'), 16),
        (text_panel("Triage Order", """1. Confirm exporter versus mysqld availability.\n2. Check runtime GR member state, primary count and quorum.\n3. Check GR queues and flow control.\n4. Correlate node pressure and service logs before changing state.\n\nNormal automation never forces recovery, removes metadata, cleans a datadir or switches traffic."""), 8),
    ], 14)
    return d


def write_dashboard(dashboard):
    path = ROOT / f"{dashboard.uid}.json"
    path.write_text(json.dumps(dashboard.render(), indent=2, ensure_ascii=False) + "\n")
    return path


def main():
    dashboards = [overview_dashboard(), cluster_dashboard(), instance_dashboard(), replication_dashboard(), alert_dashboard()]
    for dashboard in dashboards:
        path = write_dashboard(dashboard)
        print(f"wrote {path.name}: {len(dashboard.panels)} panels")


if __name__ == "__main__":
    main()
