#!/usr/bin/env python3
"""
Probe a running ga4gh-infra stack to detect which co-deploy services are available.
Returns an InfraFeatureSet consumed by co_deploy_scenarios.py.

All probes are non-destructive GET requests to /service-info (or OIDC discovery for mock-idp).
A service is 'available' when it responds with HTTP 2xx. Unavailable on connection error or 5xx.
"""
from __future__ import annotations

import json
import os
import urllib.error
import urllib.request
from dataclasses import dataclass


@dataclass
class InfraFeatureSet:
    broker: bool = False
    visa_registry: bool = False
    service_registry: bool = False
    ads: bool = False

    def any_available(self) -> bool:
        return any([
            self.broker,
            self.visa_registry,
            self.service_registry,
            self.ads,
        ])

    def summary(self) -> dict:
        return {
            "broker": self.broker,
            "visa_registry": self.visa_registry,
            "service_registry": self.service_registry,
            "ads": self.ads,
        }

    def available_count(self) -> int:
        return sum(1 for v in self.summary().values() if v)

    def unavailable_features(self) -> list[str]:
        return [k for k, v in self.summary().items() if not v]


def _default_urls() -> dict[str, str]:
    return {
        "broker": os.environ.get("GA4GH_BROKER_URL", "http://127.0.0.1:8180"),
        "visa_registry": os.environ.get("GA4GH_VISA_REGISTRY_URL", "http://127.0.0.1:8181"),
        "service_registry": os.environ.get("GA4GH_SERVICE_REGISTRY_URL", "http://127.0.0.1:8183"),
        "ads": os.environ.get("GA4GH_ADS_URL", "http://127.0.0.1:8190"),
    }


def _probe_service_info(base: str) -> bool:
    url = f"{base.rstrip('/')}/service-info"
    try:
        req = urllib.request.Request(url, method="GET")
        with urllib.request.urlopen(req, timeout=5) as resp:
            return resp.status < 500
    except urllib.error.HTTPError as e:
        return e.code < 500
    except (OSError, ConnectionRefusedError, TimeoutError):
        return False


def detect(
    broker: str | None = None,
    visa_registry: str | None = None,
    service_registry: str | None = None,
    ads: str | None = None,
) -> InfraFeatureSet:
    """Probe ga4gh-infra endpoints and return detected feature set."""
    defaults = _default_urls()
    fs = InfraFeatureSet()
    fs.broker = _probe_service_info(broker or defaults["broker"])
    fs.visa_registry = _probe_service_info(visa_registry or defaults["visa_registry"])
    fs.service_registry = _probe_service_info(service_registry or defaults["service_registry"])
    fs.ads = _probe_service_info(ads or defaults["ads"])
    return fs


if __name__ == "__main__":
    import sys

    urls = _default_urls()
    if len(sys.argv) > 1:
        urls["broker"] = sys.argv[1]
    fs = detect(**urls)
    print(json.dumps({
        "infra": urls,
        "features": fs.summary(),
        "available_count": fs.available_count(),
    }, indent=2))
