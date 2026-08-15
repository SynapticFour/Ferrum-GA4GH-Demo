"""Africa residency scenario must not report ok when the chain is invalid."""
from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "demo" / "lib"))

from africa_feature_detect import AfricaFeatureSet  # noqa: E402
from africa_scenarios import scenario_residency_audit  # noqa: E402


class _Resp:
    def __init__(self, payload):
        self._payload = json.dumps(payload).encode()

    def read(self):
        return self._payload

    def __enter__(self):
        return self

    def __exit__(self, *args):
        return False


class TestResidencyAudit(unittest.TestCase):
    def test_residency_invalid_chain_is_error(self):
        fs = AfricaFeatureSet(residency_audit=True)
        payloads = [
            _Resp([{"event_type": "beacon_query", "data_left_node": False}]),
            _Resp({"chain_valid": False, "entry_count": 40, "last_hash": "abc"}),
        ]

        def fake_urlopen(req, timeout=10):
            return payloads.pop(0)

        with patch("africa_scenarios.urllib.request.urlopen", fake_urlopen):
            out = scenario_residency_audit("http://127.0.0.1:9", ROOT, fs)
        self.assertIn("error", out)
        self.assertIs(out["chain_valid"], False)
        self.assertNotIn("verified", (out.get("note") or "").lower())

    def test_residency_valid_chain_is_ok(self):
        fs = AfricaFeatureSet(residency_audit=True)
        payloads = [
            _Resp([]),
            _Resp({"chain_valid": True, "entry_count": 1, "last_hash": "deadbeef"}),
        ]

        def fake_urlopen(req, timeout=10):
            return payloads.pop(0)

        with patch("africa_scenarios.urllib.request.urlopen", fake_urlopen):
            out = scenario_residency_audit("http://127.0.0.1:9", ROOT, fs)
        self.assertTrue(out.get("ok"))
        self.assertIs(out.get("chain_valid"), True)


if __name__ == "__main__":
    unittest.main()
