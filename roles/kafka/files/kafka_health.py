#!/usr/bin/env python3
"""Single role-owned Kafka lifecycle predicate; JMX is intentionally not used."""
import argparse
import json
import re
import socket
import subprocess
import sys

BIN = "/opt/kafka/bin"
MAX_QUORUM_LAG_TIME_MS = 5000


def run(name, args, timeout=20):
    command = [f"{BIN}/{name}"] + args
    try:
        proc = subprocess.run(command, text=True, stdout=subprocess.PIPE,
                              stderr=subprocess.STDOUT, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired) as exc:
        return 124, str(exc)
    return proc.returncode, proc.stdout


def client_args(ns):
    return ["--bootstrap-server", ns.bootstrap_server,
            "--command-config", ns.command_config]


def quorum(ns):
    rc, out = run("kafka-metadata-quorum.sh",
                  client_args(ns) + ["describe", "--status"])
    leader = re.search(r"(?m)^LeaderId:\s*(-?\d+)", out)
    max_lag = re.search(r"(?m)^MaxFollowerLag:\s*(\d+)", out)
    max_lag_time = re.search(r"(?m)^MaxFollowerLagTimeMs:\s*(-1|\d+)", out)
    voters = {int(v) for v in re.findall(r"ReplicaKey\(id=(\d+)", out)}
    if not voters:
        line = re.search(r"(?m)^CurrentVoters:\s*(\[.*\])$", out)
        if line:
            try:
                voters = {int(entry["id"]) for entry in json.loads(line.group(1))}
            except (json.JSONDecodeError, KeyError, TypeError, ValueError):
                legacy = line.group(1).strip("[]")
                voters = {int(v) for v in re.findall(
                    r"(?:^|[,\s])([0-9]+)(?:@|:|,|$)", legacy)}
    caught_up = (max_lag is not None and int(max_lag.group(1)) == 0 and
                 max_lag_time is not None and
                 int(max_lag_time.group(1)) <= MAX_QUORUM_LAG_TIME_MS)
    return (rc == 0 and leader is not None and int(leader.group(1)) >= 0 and
            bool(voters) and caught_up), voters, out


def topic_filter(ns, flag):
    rc, out = run("kafka-topics.sh", client_args(ns) + ["--describe", flag])
    return rc == 0 and not re.search(r"(?m)^Topic:\s", out), out


def listener_reachable(bootstrap_servers):
    """Accept any reachable broker from Kafka's comma-separated bootstrap list."""
    for endpoint in bootstrap_servers.split(","):
        try:
            host, port = endpoint.strip().rsplit(":", 1)
            with socket.create_connection((host, int(port)), timeout=2):
                return True
        except (OSError, ValueError):
            continue
    return False


def global_health(ns):
    if not listener_reachable(ns.bootstrap_server):
        return False, set(), {"listener": False}, {"listener": "unreachable"}
    q_ok, voters, q_out = quorum(ns)
    checks = {}
    details = {"quorum": q_out[-2000:]}
    if not q_ok:
        return False, voters, {"quorum": False}, details
    for flag in ("--unavailable-partitions", "--under-replicated-partitions",
                 "--under-min-isr-partitions"):
        ok, out = topic_filter(ns, flag)
        checks[flag] = ok
        if not ok:
            details[flag] = out[-2000:]
    return q_ok and all(checks.values()), voters, {"quorum": q_ok, **checks}, details


def cluster_min_isr(ns):
    rc, out = run("kafka-configs.sh", client_args(ns) +
                  ["--entity-type", "brokers", "--entity-default", "--describe"])
    if rc:
        raise RuntimeError(out)
    found = re.search(r"min\.insync\.replicas=([0-9]+)", out)
    return int(found.group(1)) if found else 1


def partitions(ns):
    rc, out = run("kafka-topics.sh", client_args(ns) + ["--describe"])
    if rc:
        raise RuntimeError(out)
    topic_min = {}
    result = []
    for line in out.splitlines():
        name = re.search(r"\bTopic:\s+(\S+)", line)
        if not name:
            continue
        topic = name.group(1)
        if "PartitionCount:" in line:
            found = re.search(r"min\.insync\.replicas=([0-9]+)", line)
            if found:
                topic_min[topic] = int(found.group(1))
            continue
        part = re.search(r"\bPartition:\s+(\d+)", line)
        replicas = re.search(r"\bReplicas:\s*([0-9,]*)", line)
        isr = re.search(r"\bIsr:\s*([0-9,]*)", line)
        if part and replicas and isr:
            parse = lambda value: {int(x) for x in value.split(",") if x}
            result.append({"topic": topic, "partition": int(part.group(1)),
                           "replicas": parse(replicas.group(1)),
                           "isr": parse(isr.group(1))})
    default_min = cluster_min_isr(ns)
    for item in result:
        item["min_isr"] = topic_min.get(item["topic"], default_min)
    return result


def brokers(ns):
    rc, out = run("kafka-broker-api-versions.sh", client_args(ns))
    if rc:
        raise RuntimeError(out)
    return {int(node): fenced.lower() == "false" for node, fenced in re.findall(
        r"\(id:\s*(\d+).*?isFenced:\s*(true|false)\)", out)}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=("cluster", "pre", "post"))
    parser.add_argument("--bootstrap-server", required=True)
    parser.add_argument("--command-config", default="/etc/kafka/admin.properties")
    parser.add_argument("--node-id", type=int)
    parser.add_argument("--controller", action="store_true")
    parser.add_argument("--broker", action="store_true")
    ns = parser.parse_args()
    healthy, voters, checks, details = global_health(ns)
    report = {"healthy": healthy, "checks": checks, "voters": sorted(voters)}
    if not healthy:
        report["details"] = details
        print(json.dumps(report, sort_keys=True))
        return 1
    if ns.mode != "cluster":
        if ns.node_id is None:
            parser.error("--node-id is required for pre/post")
        try:
            parts = partitions(ns)
        except RuntimeError as exc:
            report.update(healthy=False, error=str(exc)[-2000:])
            print(json.dumps(report, sort_keys=True))
            return 1
        unsafe = []
        for part in parts:
            if ns.node_id not in part["replicas"]:
                continue
            remaining = len(part["isr"] - {ns.node_id})
            if ns.mode == "pre" and remaining < part["min_isr"]:
                unsafe.append({"topic": part["topic"], "partition": part["partition"],
                               "remaining_isr": remaining, "min_isr": part["min_isr"]})
            if ns.mode == "post" and ns.node_id not in part["isr"]:
                unsafe.append({"topic": part["topic"], "partition": part["partition"],
                               "reason": "target_not_caught_up"})
        if ns.controller:
            majority = len(voters) // 2 + 1
            if ns.mode == "pre" and len(voters - {ns.node_id}) < majority:
                unsafe.append({"reason": "controller_majority", "voters": sorted(voters),
                               "required": majority})
            if ns.mode == "post" and ns.node_id not in voters:
                unsafe.append({"reason": "controller_not_in_voter_set",
                               "voters": sorted(voters)})
        if ns.mode == "post" and ns.broker:
            try:
                registered = brokers(ns)
            except RuntimeError as exc:
                unsafe.append({"reason": "broker_registration_query_failed",
                               "error": str(exc)[-1000:]})
            else:
                if not registered.get(ns.node_id, False):
                    unsafe.append({"reason": "broker_not_registered_or_fenced",
                                   "brokers": sorted(registered)})
        report["unsafe"] = unsafe
        report["healthy"] = not unsafe
    print(json.dumps(report, sort_keys=True))
    return 0 if report["healthy"] else 1


if __name__ == "__main__":
    sys.exit(main())
