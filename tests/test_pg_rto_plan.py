import json
import re
import unittest
from pathlib import Path

import yaml


ROOT = Path(__file__).resolve().parents[1]
HAPROXY_TIME = re.compile(r"^\d+(?:us|ms|s|m|h|d)$")


def find_rto_plans(value):
    if isinstance(value, dict):
        if "pg_rto_plan" in value:
            yield value["pg_rto_plan"]
        for child in value.values():
            yield from find_rto_plans(child)
    elif isinstance(value, list):
        for child in value:
            yield from find_rto_plans(child)


def load_cmdb_rto_plan():
    path = ROOT / "files/cmdb.sql"
    match = re.search(
        r"\(\d+, 'pg_rto_plan', '(\{[^']+\})', 'PGSQL'",
        path.read_text(encoding="utf-8"),
    )
    if match is None:
        raise AssertionError(f"pg_rto_plan not found in {path.relative_to(ROOT)}")
    return json.loads(match.group(1))


def shipped_rto_plans():
    paths = [
        ROOT / "roles/pgsql/defaults/main.yml",
        *sorted((ROOT / "conf").rglob("*.yml")),
    ]
    for path in paths:
        document = yaml.safe_load(path.read_text(encoding="utf-8"))
        for plan in find_rto_plans(document):
            yield path, plan

    yield ROOT / "files/cmdb.sql", load_cmdb_rto_plan()


class PgRtoPlanTest(unittest.TestCase):
    def test_cmdb_rto_plan_matches_role_defaults(self):
        defaults = yaml.safe_load(
            (ROOT / "roles/pgsql/defaults/main.yml").read_text(encoding="utf-8")
        )
        self.assertEqual(load_cmdb_rto_plan(), defaults["pg_rto_plan"])

    def test_shipped_haproxy_health_intervals_use_integer_time_units(self):
        for path, rto_plan in shipped_rto_plans():
            for mode, plan in rto_plan.items():
                intervals = ((5, "inter"), (6, "fastinter"), (7, "downinter"))
                for index, field in intervals:
                    value = str(plan[index])
                    context = {
                        "path": path.relative_to(ROOT),
                        "mode": mode,
                        "field": field,
                        "value": value,
                    }
                    with self.subTest(**context):
                        self.assertRegex(
                            value,
                            HAPROXY_TIME,
                            f"{mode}.{field}={value!r} is not accepted by HAProxy",
                        )


if __name__ == "__main__":
    unittest.main()
