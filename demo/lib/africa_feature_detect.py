#!/usr/bin/env python3
"""Detect Ferrum Africa / edge feature flags exposed by a running gateway."""
from __future__ import annotations

import argparse
import json
import sys
import urllib.error
import urllib.request


def probe(gateway: str) -> dict[str, object]:
    base = gateway.rstrip("/")
    out: dict[str, object] = {
        "gateway": base,
        "offline_first": False,
        "federation": False,
        "audit_residency": False,
        "beacon_v2": False,
    }

    try:
        with urllib.request.urlopen(f"{base}/ga4gh/beacon/v2/info", timeout=10) as resp:
            if resp.status == 200:
                out["beacon_v2"] = True
    except (urllib.error.URLError, TimeoutError):
        pass

    # Health / service-info may advertise Africa env-backed features when upstream implements them.
    for path in ("/health", "/api/v1/service-info"):
        try:
            with urllib.request.urlopen(f"{base}{path}", timeout=10) as resp:
                body = resp.read().decode("utf-8", errors="replace")
                if "offline" in body.lower() or "FERRUM_AFRICA" in body:
                    out["offline_first"] = True
                if "federation" in body.lower():
                    out["federation"] = True
        except (urllib.error.URLError, TimeoutError):
            continue

    try:
        with urllib.request.urlopen(
            f"{base}/api/v1/audit/residency/verify", timeout=10
        ) as resp:
            if resp.status == 200:
                out["audit_residency"] = True
    except (urllib.error.URLError, TimeoutError):
        pass

    return out


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--gateway", required=True, help="ferrum-gateway base URL")
    parser.add_argument(
        "--json", action="store_true", help="emit JSON (default: human-readable)"
    )
    args = parser.parse_args()
    result = probe(args.gateway)
    if args.json:
        print(json.dumps(result, indent=2))
    else:
        print(f"Gateway: {result['gateway']}")
        for key in ("beacon_v2", "offline_first", "federation", "audit_residency"):
            mark = "yes" if result[key] else "no"
            print(f"  {key}: {mark}")
    if not result["beacon_v2"]:
        sys.exit(1)


if __name__ == "__main__":
    main()
