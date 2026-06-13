#!/usr/bin/env python3
"""
Probe a running Ferrum gateway to detect which Africa-specific features
are available. Returns a FeatureSet that other Africa scenario scripts
consume to decide what to run.

All probes are non-destructive GET requests. A feature is considered
'available' if the relevant endpoint responds with HTTP 200 or 404
(not 404 in the sense of "not found" but "endpoint exists, no data").
A feature is 'unavailable' if the endpoint returns 404 with a specific
"route not found" pattern, or 405, or connection error.
"""
from __future__ import annotations

import json
import urllib.error
import urllib.request
from dataclasses import dataclass


@dataclass
class AfricaFeatureSet:
    offline_mode: bool = False          # FERRUM_OFFLINE=1 + SQLite backend
    ont_ingestion: bool = False         # POST /api/v1/ingest/ont endpoint exists
    multi_pathogen_beacon: bool = False # Beacon v2 PathoGenFilter available
    outbreak_mode: bool = False         # POST /api/v1/outbreak/activate exists
    federated_beacon: bool = False      # GET /ga4gh/beacon/v2?federate=true supported
    bandwidth_adaptive: bool = False    # Transfer-Checkpoint header present
    power_monitor: bool = False         # GET /api/v1/health/power endpoint exists
    residency_audit: bool = False       # GET /api/v1/audit/residency endpoint exists
    reference_registry: bool = False    # GET /api/v1/references endpoint exists

    def any_available(self) -> bool:
        return any([
            self.offline_mode, self.ont_ingestion, self.multi_pathogen_beacon,
            self.outbreak_mode, self.federated_beacon, self.bandwidth_adaptive,
            self.power_monitor, self.residency_audit, self.reference_registry,
        ])

    def summary(self) -> dict:
        return {
            "offline_mode": self.offline_mode,
            "ont_ingestion": self.ont_ingestion,
            "multi_pathogen_beacon": self.multi_pathogen_beacon,
            "outbreak_mode": self.outbreak_mode,
            "federated_beacon": self.federated_beacon,
            "bandwidth_adaptive": self.bandwidth_adaptive,
            "power_monitor": self.power_monitor,
            "residency_audit": self.residency_audit,
            "reference_registry": self.reference_registry,
        }

    def available_count(self) -> int:
        return sum(1 for v in self.summary().values() if v)

    def unavailable_features(self) -> list[str]:
        return [k for k, v in self.summary().items() if not v]


def _probe(gateway: str, path: str, method: str = "GET") -> bool:
    """Return True if endpoint exists (2xx or known-data-404), False if route missing."""
    url = f"{gateway.rstrip('/')}{path}"
    try:
        req = urllib.request.Request(url, method=method)
        with urllib.request.urlopen(req, timeout=5) as resp:
            return resp.status < 500
    except urllib.error.HTTPError as e:
        # 404 from a real route (e.g. "no entries yet") = feature exists
        # 404 from "route not found" = feature absent
        if e.code == 404:
            try:
                body = e.read().decode("utf-8", errors="replace")
                if "route not found" in body.lower() or "no such" in body.lower():
                    return False
                return True
            except Exception:
                return False
        if e.code in (405, 501):
            return False
        return False
    except (OSError, ConnectionRefusedError, TimeoutError):
        return False


def detect(gateway: str) -> AfricaFeatureSet:
    """Probe gateway and return detected feature set."""
    fs = AfricaFeatureSet()

    try:
        req = urllib.request.Request(f"{gateway.rstrip('/')}/health")
        with urllib.request.urlopen(req, timeout=5) as resp:
            body = json.loads(resp.read())
            fs.offline_mode = body.get("db") == "sqlite"
    except Exception:
        pass

    fs.ont_ingestion = _probe(gateway, "/api/v1/ingest/ont", "POST")
    fs.multi_pathogen_beacon = _probe(gateway, "/ga4gh/beacon/v2/info")
    fs.outbreak_mode = _probe(gateway, "/api/v1/outbreak/activate", "POST")
    fs.federated_beacon = _probe(
        gateway,
        "/ga4gh/beacon/v2/g_variants?federate=true&limit=0"
    )
    try:
        req = urllib.request.Request(f"{gateway.rstrip('/')}/ga4gh/drs/v1/service-info")
        with urllib.request.urlopen(req, timeout=5) as resp:
            body = json.loads(resp.read())
            fs.bandwidth_adaptive = "bandwidth_adaptive" in body.get("supported_features", [])
    except Exception:
        pass

    fs.power_monitor = _probe(gateway, "/api/v1/health/power")
    fs.residency_audit = _probe(gateway, "/api/v1/audit/residency")
    fs.reference_registry = _probe(gateway, "/api/v1/references")

    return fs


if __name__ == "__main__":
    import sys
    gw = sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:18080"
    fs = detect(gw)
    print(json.dumps({"gateway": gw, "features": fs.summary(),
                      "available_count": fs.available_count()}, indent=2))
