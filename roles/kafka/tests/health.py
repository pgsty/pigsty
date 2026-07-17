#!/usr/bin/env python3
"""Regression tests for the role-owned Kafka lifecycle predicate."""
import importlib.machinery
import importlib.util
import pathlib
import unittest
from types import SimpleNamespace
from unittest import mock


TEMPLATE = pathlib.Path(__file__).parents[1] / "templates" / "kafka-health.py.j2"
LOADER = importlib.machinery.SourceFileLoader("pigsty_kafka_health", str(TEMPLATE))
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
HEALTH = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(HEALTH)


class QuorumHealthTest(unittest.TestCase):
    def setUp(self):
        self.args = SimpleNamespace(
            bootstrap_server="127.0.0.1:9092",
            command_config="/dev/null",
        )

    def quorum(self, lag=0, lag_time=250):
        output = f"""\
LeaderId:               3
MaxFollowerLag:         {lag}
MaxFollowerLagTimeMs:   {lag_time}
CurrentVoters:          [{{"id": 1}}, {{"id": 2}}, {{"id": 3}}]
"""
        with mock.patch.object(HEALTH, "run", return_value=(0, output)):
            return HEALTH.quorum(self.args)

    def test_caught_up_dynamic_voters_are_healthy(self):
        healthy, voters, _ = self.quorum()
        self.assertTrue(healthy)
        self.assertEqual(voters, {1, 2, 3})

    def test_nonzero_follower_lag_is_unhealthy(self):
        self.assertFalse(self.quorum(lag=1)[0])

    def test_stale_follower_catchup_is_unhealthy(self):
        self.assertFalse(self.quorum(lag_time=HEALTH.MAX_QUORUM_LAG_TIME_MS + 1)[0])

    def test_legacy_voter_format_remains_supported(self):
        output = """\
LeaderId: 1
MaxFollowerLag: 0
MaxFollowerLagTimeMs: 0
CurrentVoters: [1@a:9095, 2@b:9095, 3@c:9095]
"""
        with mock.patch.object(HEALTH, "run", return_value=(0, output)):
            healthy, voters, _ = HEALTH.quorum(self.args)
        self.assertTrue(healthy)
        self.assertEqual(voters, {1, 2, 3})


if __name__ == "__main__":
    unittest.main()
