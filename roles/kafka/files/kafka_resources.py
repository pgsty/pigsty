#!/usr/bin/env python3
"""Converge Pigsty-owned Kafka users, ACLs, quotas, topics, and minISR."""
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
from decimal import Decimal, InvalidOperation

BIN = "/opt/kafka/bin"


class Failure(RuntimeError):
    pass


def invoke(script, common, args, check=True, sensitive=False):
    command = [f"{BIN}/{script}"] + common + args
    proc = subprocess.run(command, text=True, stdout=subprocess.PIPE,
                          stderr=subprocess.STDOUT, timeout=120)
    if check and proc.returncode:
        detail = "<sensitive output redacted>" if sensitive else proc.stdout[-3000:]
        raise Failure(f"{script} failed ({proc.returncode}): {detail}")
    return proc.returncode, proc.stdout


def properties_call(script, common, prefix, values):
    fd, path = tempfile.mkstemp(prefix=".pigsty-kafka-", dir="/etc/kafka", text=True)
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "w") as stream:
            for key, value in values.items():
                stream.write(f"{key}={value}\n")
        invoke(script, common, prefix + ["--add-config-file", path])
    finally:
        try:
            os.unlink(path)
        except FileNotFoundError:
            pass


def resource_args(resource, name, pattern):
    if resource == "cluster":
        return ["--cluster"]
    flag = {"topic": "--topic", "group": "--group",
            "transactional_id": "--transactional-id"}[resource]
    return [flag, name, "--resource-pattern-type", pattern]


def desired_acls(user):
    result = set()
    for acl in user.get("acls", []):
        resource = acl["resource"]
        name = "kafka-cluster" if resource == "cluster" else acl["name"]
        pattern = acl.get("pattern", "literal").lower()
        for operation in acl["operations"]:
            canonical = re.sub(r"(?<=[a-z0-9])(?=[A-Z])", "_", operation).upper()
            result.add((resource, name, pattern, canonical))
    return result


def cli_operation(operation):
    """Return KafkaAclCommand's CamelCase spelling for a canonical operation."""
    return "".join(part.title() for part in operation.split("_"))


def current_acls(common, principal):
    _, out = invoke("kafka-acls.sh", common, ["--list", "--principal", principal])
    result = set()
    current = None
    resource_re = re.compile(
        r"resourceType=(TOPIC|GROUP|TRANSACTIONAL_ID|CLUSTER),\s*"
        r"name=([^,]+),\s*patternType=(LITERAL|PREFIXED)")
    entry_re = re.compile(
        r"principal=([^,]+),\s*host=([^,]+),\s*operation=([^,]+),\s*"
        r"permissionType=([^\)]+)")
    reverse = {"TOPIC": "topic", "GROUP": "group",
               "TRANSACTIONAL_ID": "transactional_id", "CLUSTER": "cluster"}
    for line in out.splitlines():
        found = resource_re.search(line)
        if found:
            current = (reverse[found.group(1)], found.group(2).strip(),
                       found.group(3).strip().lower())
            continue
        entry = entry_re.search(line)
        if current and entry and entry.group(1).strip() == principal \
                and entry.group(2).strip() == "*" \
                and entry.group(4).strip().upper() == "ALLOW":
            result.add(current + (entry.group(3).strip().upper(),))
    return result


def converge_acls(common, user, changed):
    principal = f"User:{user['name']}"
    desired = desired_acls(user)
    actual = current_acls(common, principal)
    for resource, name, pattern, operation in sorted(actual - desired):
        args = ["--remove", "--force", "--allow-principal", principal,
                "--operation", cli_operation(operation)] + resource_args(resource, name, pattern)
        invoke("kafka-acls.sh", common, args)
        changed.append(f"acl-remove:{user['name']}:{resource}:{name}:{operation}")
    for resource, name, pattern, operation in sorted(desired - actual):
        args = ["--add", "--allow-principal", principal,
                "--operation", cli_operation(operation)] + resource_args(resource, name, pattern)
        invoke("kafka-acls.sh", common, args)
        changed.append(f"acl-add:{user['name']}:{resource}:{name}:{operation}")


def parse_configs(out):
    return {key: value for key, value in
            re.findall(r"(?:^|[\s,])([A-Za-z0-9._-]+)=([^\s]+)\s+sensitive=", out)}


def parse_quotas(out):
    names = ("producer_byte_rate|consumer_byte_rate|request_percentage|"
             "controller_mutation_rate")
    return dict(re.findall(rf"(?:^|[\s,])({names})=([^\s,]+)", out))


def numerically_equal(actual, desired):
    if actual is None:
        return False
    try:
        return Decimal(actual) == Decimal(desired)
    except InvalidOperation:
        return actual == desired


def converge_user(common, user, cache, changed):
    name = user["name"]
    password = user.get("password")
    if password is not None:
        _, out = invoke("kafka-configs.sh", common,
                        ["--entity-type", "users", "--entity-name", name, "--describe"])
        digest = hashlib.sha256(password.encode()).hexdigest()
        live_scram = "SCRAM-SHA-512" in out
        if not live_scram or cache.get(name) != digest:
            value = f"SCRAM-SHA-512=[iterations=8192,password={password}]"
            invoke("kafka-configs.sh", common,
                   ["--entity-type", "users", "--entity-name", name,
                    "--alter", "--add-config", value], sensitive=True)
            cache[name] = digest
            changed.append(f"credential:{name}")
    converge_acls(common, user, changed)
    quota = user.get("quota", {})
    if quota:
        _, out = invoke("kafka-configs.sh", common,
                        ["--entity-type", "users", "--entity-name", name, "--describe"])
        actual = parse_quotas(out)
        updates = {key: str(value) for key, value in quota.items()
                   if not numerically_equal(actual.get(key), str(value))}
        if updates:
            properties_call("kafka-configs.sh", common,
                            ["--entity-type", "users", "--entity-name", name,
                             "--alter"], updates)
            changed.append(f"quota:{name}:{','.join(sorted(updates))}")


def topic_description(common, name):
    rc, out = invoke("kafka-topics.sh", common,
                     ["--describe", "--topic", name], check=False)
    if rc:
        return None, out
    header = next((line for line in out.splitlines() if "PartitionCount:" in line), "")
    partitions = re.search(r"PartitionCount:\s*(\d+)", header)
    replication = re.search(r"ReplicationFactor:\s*(\d+)", header)
    if not partitions or not replication:
        return None, out
    return (int(partitions.group(1)), int(replication.group(1))), out


def converge_topic(common, topic, changed):
    name = topic["name"]
    state, output = topic_description(common, name)
    desired_partitions = int(topic["partitions"])
    desired_rf = int(topic["replication_factor"])
    if state is None:
        args = ["--create", "--if-not-exists", "--topic", name,
                "--partitions", str(desired_partitions),
                "--replication-factor", str(desired_rf)]
        for key, value in topic.get("config", {}).items():
            args += ["--config", f"{key}={value}"]
        invoke("kafka-topics.sh", common, args)
        changed.append(f"topic-create:{name}")
        state, output = topic_description(common, name)
    current_partitions, current_rf = state
    if desired_rf != current_rf:
        raise Failure(
            f"topic {name} replication factor is {current_rf}, requested {desired_rf}; "
            "ordinary convergence will not reassign replicas. Build and review an explicit "
            "kafka-reassign-partitions.sh plan.")
    if desired_partitions < current_partitions:
        raise Failure(f"topic {name} has {current_partitions} partitions; partition count cannot decrease")
    if desired_partitions > current_partitions:
        invoke("kafka-topics.sh", common,
               ["--alter", "--topic", name, "--partitions", str(desired_partitions)])
        changed.append(f"topic-partitions:{name}:{current_partitions}->{desired_partitions}")
    desired_config = {key: str(value) for key, value in topic.get("config", {}).items()}
    if desired_config:
        _, out = invoke("kafka-configs.sh", common,
                        ["--entity-type", "topics", "--entity-name", name,
                         "--describe", "--all"])
        actual = parse_configs(out)
        updates = {key: value for key, value in desired_config.items()
                   if actual.get(key) != value}
        if updates:
            properties_call("kafka-configs.sh", common,
                            ["--entity-type", "topics", "--entity-name", name,
                             "--alter"], updates)
            changed.append(f"topic-config:{name}:{','.join(sorted(updates))}")


def converge_cluster_min_isr(common, value, changed):
    _, out = invoke("kafka-configs.sh", common,
                    ["--entity-type", "brokers", "--entity-default", "--describe"])
    actual = parse_configs(out).get("min.insync.replicas")
    desired = str(value)
    if actual != desired:
        invoke("kafka-configs.sh", common,
               ["--entity-type", "brokers", "--entity-default", "--alter",
                "--add-config", f"min.insync.replicas={desired}"])
        changed.append(f"cluster-min-isr:{actual or 'unset'}->{desired}")


def main():
    if len(sys.argv) != 4:
        print("usage: kafka_resources.py SPEC BOOTSTRAP COMMAND_CONFIG", file=sys.stderr)
        return 2
    spec_path, bootstrap, command_config = sys.argv[1:]
    with open(spec_path, encoding="utf-8") as stream:
        spec = json.load(stream)
    common = ["--bootstrap-server", bootstrap, "--command-config", command_config]
    cache_path = "/etc/kafka/.pigsty-user-digests.json"
    try:
        with open(cache_path, encoding="utf-8") as stream:
            cache = json.load(stream)
    except (FileNotFoundError, json.JSONDecodeError):
        cache = {}
    changed = []
    try:
        converge_cluster_min_isr(common, spec["min_insync_replicas"], changed)
        for user in spec.get("users", []):
            converge_user(common, user, cache, changed)
        for topic in spec.get("topics", []):
            converge_topic(common, topic, changed)
    except (Failure, subprocess.TimeoutExpired, OSError) as exc:
        print(json.dumps({"ok": False, "changed": changed, "error": str(exc)}))
        return 1
    fd, temp_path = tempfile.mkstemp(prefix=".pigsty-user-digests-", dir="/etc/kafka", text=True)
    with os.fdopen(fd, "w") as stream:
        json.dump(cache, stream, sort_keys=True)
        stream.write("\n")
    os.chmod(temp_path, 0o600)
    os.replace(temp_path, cache_path)
    print(json.dumps({"ok": True, "changed": changed}, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
