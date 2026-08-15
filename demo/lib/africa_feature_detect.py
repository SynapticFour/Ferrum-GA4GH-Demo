#!/usr/bin/env python3
"""
Probe a running Ferrum gateway to detect which Africa-specific features
are available. Returns a FeatureSet that other Africa scenario scripts
consume to decide what to run.

A feature is available only when the probe shows the *capability*, not merely
that a generic GA4GH route returned HTTP 200 (e.g. Beacon /info exists on
stock Ferrum and must not imply PathoGenFilter).
"""
from __future__ import annotations

import json
import urllib.error
import urllib.request
from dataclasses import dataclass

from evidence_contract import beacon_has_pathogen_filter_terms


@dataclass
class AfricaFeatureSet:
    offline_mode: bool = False          # health.db == sqlite
    ont_ingestion: bool = False         # POST /api/v1/ingest/ont endpoint exists
    multi_pathogen_beacon: bool = False # Beacon /info lists PathoGenFilter
    outbreak_mode: bool = False         # POST /api/v1/outbreak/activate exists
    federated_beacon: bool = False      # federate=true response includes meta.federation
    bandwidth_adaptive: bool = False    # DRS service-info supported_features
    power_monitor: bool = False         # GET /api/v1/health/power endpoint exists
    residency_audit: bool = False       # GET /api/v1/audit/residency endpoint exists
    reference_registry: bool = False    # GET /api/v1/references endpoint exists

    def any_available(self) -> bool:
        return any(self.summary().values())

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


def _probe_route_exists(gateway: str, path: str, method: str = "GET") -> bool:
    """True if a dedicated route exists (not a generic framework 404)."""
    url = f"{gateway.rstrip('/')}{path}"
    try:
        req = urllib.request.Request(url, method=method)
        with urllib.request.urlopen(req, timeout=5) as resp:
            return resp.status < 500
    except urllib.error.HTTPError as e:
        if e.code == 404:
            try:
                body = e.read().decode("utf-8", errors="replace")
                if "route not found" in body.lower() or "no such" in body.lower():
                    return False
                # 404 from an implemented handler (empty collection, missing policy).
                return True
            except OSError:
                return False
        if e.code in (400, 401, 403, 409, 415, 422):
            return True
        if e.code in (405, 501):
            return False
        return False
    except (OSError, TimeoutError):
        return False


def _json_get(gateway: str, path: str) -> dict | None:
    url = f"{gateway.rstrip('/')}{path}"
    try:
        req = urllib.request.Request(url, method="GET")
        with urllib.request.urlopen(req, timeout=5) as resp:
            return json.loads(resp.read())
    except (OSError, TimeoutError, urllib.error.HTTPError, json.JSONDecodeError):
        return None


def detect(gateway: str) -> AfricaFeatureSet:
    """Probe gateway and return detected feature set."""
    fs = AfricaFeatureSet()

    health = _json_get(gateway, "/health")
    if isinstance(health, dict):
        fs.offline_mode = health.get("db") == "sqlite"

    fs.ont_ingestion = _probe_route_exists(gateway, "/api/v1/ingest/ont", "POST")

    info = _json_get(gateway, "/ga4gh/beacon/v2/info")
    fs.multi_pathogen_beacon = bool(info) and beacon_has_pathogen_filter_terms(info)

    fs.outbreak_mode = _probe_route_exists(gateway, "/api/v1/outbreak/activate", "POST")

    fed = _json_get(gateway, "/ga4gh/beacon/v2/g_variants?federate=true&limit=0")
    fs.federated_beacon = isinstance(fed, dict) and isinstance(
        (fed.get("meta") or {}).get("federation"), dict
    )

    drs_info = _json_get(gateway, "/ga4gh/drs/v1/service-info")
    if isinstance(drs_info, dict):
        supported = drs_info.get("supported_features") or []
        fs.bandwidth_adaptive = "bandwidth_adaptive" in supported

    fs.power_monitor = _probe_route_exists(gateway, "/api/v1/health/power")
    fs.residency_audit = _probe_route_exists(gateway, "/api/v1/audit/residency")
    fs.reference_registry = _probe_route_exists(gateway, "/api/v1/references")

    return fs


if __name__ == "__main__":
    import sys
    gw = sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:18080"
    fs = detect(gw)
    print(json.dumps({"gateway": gw, "features": fs.summary(),
                      "available_count": fs.available_count()}, indent=2))
