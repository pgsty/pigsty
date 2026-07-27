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


def topic_lines_present(out):
    """kafka-topics.sh filter output indents partition lines with a tab."""
    return re.search(r"(?m)^\s*Topic:\s", out) is not None


def topic_filter(ns, flag):
    rc, out = run("kafka-topics.sh", client_args(ns) + ["--describe", flag])
    return rc == 0 and not topic_lines_present(out), out


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


def parse_partitions(out):
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
    return topic_min, result


def partitions(ns):
    rc, out = run("kafka-topics.sh", client_args(ns) + ["--describe"])
    if rc:
        raise RuntimeError(out)
    topic_min, result = parse_partitions(out)
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


def selftest():
    """Regression fixtures for the output-parsing predicates.

    kafka-topics.sh indents partition detail lines with a leading tab; an
    anchored `^Topic:` regex once classified every degraded cluster as healthy
    (all three partition filter checks silently passed). These fixtures replay
    that captured output so any parser regression fails the role at deploy time.
    """
    degraded = (
        "\tTopic: test.spread\tPartition: 1\tLeader: 3\tReplicas: 3,4\t"
        "Isr: 3\tElr: 4\tLastKnownElr: \n"
        "\tTopic: test.spread\tPartition: 2\tLeader: 1\tReplicas: 4,1\t"
        "Isr: 1\tElr: 4\tLastKnownElr: \n")
    banner = ("The consumer rebalance protocol (KIP-848) is production-ready! "
              "Set group.protocol=consumer to try it out.\n")
    describe = (
        "Topic: test.events\tTopicId: fWGbjHduTpq\tPartitionCount: 2\t"
        "ReplicationFactor: 3\tConfigs: min.insync.replicas=2\n"
        "\tTopic: test.events\tPartition: 0\tLeader: 3\tReplicas: 3,1,2\tIsr: 3,1,2\n"
        "\tTopic: test.events\tPartition: 1\tLeader: 1\tReplicas: 1,2,3\tIsr: 1,2\n")
    topic_min, parts = parse_partitions(describe)
    cases = [
        ("tab-indented partition lines fail the filter checks",
         topic_lines_present(degraded)),
        ("column-zero topic headers fail the filter checks",
         topic_lines_present("Topic: t\tTopicId: x\tPartitionCount: 1\n")),
        ("empty filter output stays healthy", not topic_lines_present("")),
        ("warning banners alone stay healthy", not topic_lines_present(banner)),
        ("describe parsing keeps per-topic min isr", topic_min == {"test.events": 2}),
        ("describe parsing sees every partition", len(parts) == 2),
        ("describe parsing keeps isr membership",
         parts and parts[1]["isr"] == {1, 2} and parts[1]["replicas"] == {1, 2, 3}),
    ]
    failed = [name for name, ok in cases if not ok]
    print(json.dumps({"healthy": not failed, "checks": len(cases),
                      "failed": failed}, sort_keys=True))
    return 1 if failed else 0


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "selftest":
        return selftest()
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
