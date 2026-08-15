"""Evidence contract: skip is not a pass; broken audit chains fail."""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "demo" / "lib"))

from evidence_contract import (  # noqa: E402
    beacon_has_pathogen_filter_terms,
    residency_ok,
    scenario_summary,
)


class TestEvidenceContract(unittest.TestCase):
    def test_skip_only_is_not_evaluated_and_not_a_pass(self):
        s = scenario_summary({"a": {"skipped": True}, "b": {"skipped": True}})
        self.assertEqual(s["verdict"], "not_evaluated")
        self.assertFalse(s["all_passed"])
        self.assertEqual(s["ran"], 0)
        self.assertEqual(s["errors"], 0)

    def test_error_is_failed_even_if_others_ok(self):
        s = scenario_summary({"a": {"ok": True}, "b": {"error": "chain_valid=False"}})
        self.assertEqual(s["verdict"], "failed")
        self.assertFalse(s["all_passed"])
        self.assertEqual(s["errors"], 1)
        self.assertEqual(s["ran"], 2)

    def test_ran_without_errors_is_passed(self):
        s = scenario_summary({"a": {"ok": True}, "b": {"skipped": True}})
        self.assertEqual(s["verdict"], "passed")
        self.assertTrue(s["all_passed"])
        self.assertEqual(s["ran"], 1)

    def test_residency_ok_requires_true(self):
        self.assertTrue(residency_ok(True))
        self.assertFalse(residency_ok(False))
        self.assertFalse(residency_ok(None))
        self.assertFalse(residency_ok("true"))

    def test_pathogen_filter_not_implied_by_empty_info(self):
        self.assertFalse(beacon_has_pathogen_filter_terms({}))
        self.assertFalse(beacon_has_pathogen_filter_terms({"id": "org.example.beacon"}))
        self.assertTrue(
            beacon_has_pathogen_filter_terms({"filteringTerms": [{"id": "PathoGenFilter"}]})
        )


if __name__ == "__main__":
    unittest.main()
