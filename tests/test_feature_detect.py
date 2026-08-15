"""Feature probes must not treat generic Beacon /info as multi-pathogen."""
from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "demo" / "lib"))

from africa_feature_detect import detect  # noqa: E402


class _Resp:
    def __init__(self, payload, status=200):
        self._payload = json.dumps(payload).encode()
        self.status = status

    def read(self):
        return self._payload

    def __enter__(self):
        return self

    def __exit__(self, *args):
        return False


class TestFeatureDetect(unittest.TestCase):
    def test_stock_beacon_info_is_not_multi_pathogen(self):
        def fake_urlopen(req, timeout=5):
            url = getattr(req, "full_url", None) or req.get_full_url()
            if url.endswith("/health"):
                return _Resp({"db": "postgres"})
            if url.endswith("/ga4gh/beacon/v2/info"):
                return _Resp({"id": "org.example.beacon", "filteringTerms": []})
            if "federate=true" in url:
                return _Resp({"meta": {}, "responseSummary": {"numTotalResults": 0}})
            if url.endswith("/ga4gh/drs/v1/service-info"):
                return _Resp({"id": "drs"})
            raise ConnectionRefusedError()

        with patch("africa_feature_detect.urllib.request.urlopen", fake_urlopen):
            fs = detect("http://127.0.0.1:18080")
        self.assertFalse(fs.multi_pathogen_beacon)
        self.assertFalse(fs.federated_beacon)
        self.assertFalse(fs.offline_mode)


if __name__ == "__main__":
    unittest.main()
