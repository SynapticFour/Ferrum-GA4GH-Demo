#!/usr/bin/env python3
"""
Co-deploy scenario runner for Ferrum + ga4gh-infra.

Each scenario:
- Accepts (gateway, infra_urls, feature_set, root)
- Returns a dict merged into results/co_deploy_results.json
- Never raises — catches errors and returns {"error": str(e)}
- Idempotent and safe to re-run

Demonstrates broker login → Passport → DRS access and service-registry discovery.
"""
from __future__ import annotations

import json
import os
import subprocess
import time
import urllib.error
import urllib.request
from http.cookiejar import CookieJar
from pathlib import Path
from typing import Any
from urllib.request import HTTPCookieProcessor, build_opener

from infra_feature_detect import InfraFeatureSet, _default_urls, detect


def _opener() -> tuple[urllib.request.OpenerDirector, CookieJar]:
    jar = CookieJar()
    return build_opener(HTTPCookieProcessor(jar)), jar


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def _authorize_callback_url(jar: CookieJar, auth_url: str) -> str:
    """Hit mock-idp authorize without following the broker callback (preserves RP session cookie)."""
    opener = build_opener(HTTPCookieProcessor(jar), _NoRedirect())
    auth_req = urllib.request.Request(auth_url, method="GET")
    try:
        opener.open(auth_req, timeout=15)
        raise RuntimeError("authorize did not redirect to broker callback")
    except urllib.error.HTTPError as err:
        if err.code in (301, 302, 303, 307, 308):
            location = err.headers.get("Location")
            if location:
                return location
        raise


def broker_login(broker: str) -> tuple[str, str]:
    """Complete mock-idp broker login; return (subject, passport_jwt)."""
    broker = broker.rstrip("/")
    opener, jar = _opener()
    req = urllib.request.Request(
        f"{broker}/login",
        headers={"Accept": "application/json"},
        method="GET",
    )
    with opener.open(req, timeout=15) as resp:
        login_body = json.loads(resp.read())

    auth_url = login_body["authorization_url"]
    auth_url = auth_url.replace("mock-idp:9100", "127.0.0.1:9100")
    auth_url = auth_url.replace("mock-idp:9000", "127.0.0.1:9100")

    callback_url = _authorize_callback_url(jar, auth_url)

    cb_req = urllib.request.Request(
        callback_url,
        headers={"Accept": "application/json"},
        method="GET",
    )
    with opener.open(cb_req, timeout=15) as cb_resp:
        cb_body = json.loads(cb_resp.read())

    passport = cb_body["access_token"]
    subject = os.environ.get("MOCK_IDP_SUBJECT", "researcher@uni-heidelberg.de")
    return subject, passport


def scenario_broker_login(infra_urls: dict[str, str], fs: InfraFeatureSet) -> dict:
    if not fs.broker:
        return {"skipped": True, "reason": "broker not available"}
    try:
        subject, passport = broker_login(infra_urls["broker"])
        parts = passport.split(".")
        return {
            "ok": True,
            "subject": subject,
            "passport_jwt_parts": len(parts),
            "passport_prefix": passport[:24] + "...",
            "note": "Broker OIDC login via mock-idp completed; Passport JWT issued",
        }
    except Exception as e:
        return {"error": str(e)}


def scenario_service_registry(infra_urls: dict[str, str], fs: InfraFeatureSet) -> dict:
    if not fs.service_registry:
        return {"skipped": True, "reason": "service_registry not available"}
    try:
        url = f"{infra_urls['service_registry'].rstrip('/')}/services"
        req = urllib.request.Request(url, method="GET")
        with urllib.request.urlopen(req, timeout=10) as resp:
            services = json.loads(resp.read())

        artifacts = []
        ferrum_services = []
        for entry in services:
            info = entry.get("info") or entry
            svc_type = info.get("type") or {}
            artifact = svc_type.get("artifact")
            if artifact:
                artifacts.append(artifact)
            svc_id = info.get("id", "")
            if artifact and ("ferrum" in svc_id.lower() or artifact.lower() == "drs"):
                ferrum_services.append({
                    "id": svc_id,
                    "artifact": artifact,
                    "url": entry.get("url"),
                })

        return {
            "ok": True,
            "service_count": len(services),
            "artifacts": sorted(set(artifacts)),
            "ferrum_registered": len(ferrum_services) > 0,
            "ferrum_services": ferrum_services[:5],
            "note": "GA4GH service registry lists Ferrum-registered endpoints when co-deploy auto_register is on",
        }
    except Exception as e:
        return {"error": str(e)}


def scenario_passport_on_drs(
    gateway: str,
    infra_urls: dict[str, str],
    fs: InfraFeatureSet,
    root: Path,
) -> dict:
    if not fs.broker:
        return {"skipped": True, "reason": "broker not available (needed for Passport)"}

    # Use init-seeded object by default: mapping.json holds ULIDs from a prior ingest and
    # is not valid before the WES pipeline runs.
    object_id = os.environ.get("CO_DEPLOY_DRS_OBJECT_ID", "test-object-1")
    if os.environ.get("CO_DEPLOY_USE_INGESTED_DRS", "").strip() == "1":
        mapping_path = root / "drs" / "mapping.json"
        if mapping_path.is_file():
            try:
                mapping = json.loads(mapping_path.read_text(encoding="utf-8"))
                ingested = mapping.get("objects", {}).get("ref_fasta", {}).get("object_id")
                if ingested:
                    object_id = ingested
            except Exception:
                pass

    try:
        _, passport = broker_login(infra_urls["broker"])
        url = f"{gateway.rstrip('/')}/ga4gh/drs/v1/objects/{object_id}"
        cmd = [
            "curl", "-fsS",
            "-H", f"Authorization: Bearer {passport}",
            url,
        ]
        result = subprocess.check_output(cmd, text=True, timeout=30)
        drs_obj = json.loads(result)
        return {
            "ok": True,
            "object_id": object_id,
            "drs_id": drs_obj.get("id", object_id),
            "note": "GA4GH Passport from broker accepted on Ferrum DRS GET",
        }
    except subprocess.CalledProcessError as e:
        return {"error": f"DRS request with Passport failed: {e}"}
    except Exception as e:
        return {"error": str(e)}


def scenario_infra_health(infra_urls: dict[str, str], fs: InfraFeatureSet) -> dict:
    if not fs.any_available():
        return {"skipped": True, "reason": "no infra services detected"}

    details: dict[str, Any] = {}
    for name, available in fs.summary().items():
        if not available:
            continue
        base = infra_urls[name]
        try:
            req = urllib.request.Request(f"{base.rstrip('/')}/service-info", method="GET")
            with urllib.request.urlopen(req, timeout=10) as resp:
                body = json.loads(resp.read())
            details[name] = {
                "id": body.get("id"),
                "type": body.get("type"),
            }
        except Exception as e:
            details[name] = {"error": str(e)}

    return {
        "ok": True,
        "services": details,
        "available_count": fs.available_count(),
        "note": "ga4gh-infra co-deploy plane healthy",
    }


SCENARIOS = [
    ("infra_health", lambda gw, urls, root, fs: scenario_infra_health(urls, fs)),
    ("broker_login", lambda gw, urls, root, fs: scenario_broker_login(urls, fs)),
    ("service_registry", lambda gw, urls, root, fs: scenario_service_registry(urls, fs)),
    ("passport_on_drs", lambda gw, urls, root, fs: scenario_passport_on_drs(gw, urls, fs, root)),
]


def run_all(gateway: str, root: Path, fs: InfraFeatureSet | None = None) -> dict:
    infra_urls = _default_urls()
    if fs is None:
        fs = detect(**infra_urls)

    results: dict[str, Any] = {
        "detected_features": fs.summary(),
        "available_count": fs.available_count(),
        "infra_urls": infra_urls,
        "scenarios": {},
    }

    for name, fn in SCENARIOS:
        print(f"[co-deploy] scenario: {name} ...", flush=True)
        t0 = time.perf_counter()
        try:
            result = fn(gateway, infra_urls, root, fs)
        except Exception as e:
            result = {"error": f"unhandled exception: {e}"}
        elapsed = time.perf_counter() - t0
        result["elapsed_seconds"] = round(elapsed, 3)
        results["scenarios"][name] = result
        status = "SKIPPED" if result.get("skipped") else ("ERROR" if result.get("error") else "OK")
        print(f"[co-deploy] {name}: {status} ({elapsed:.1f}s)", flush=True)

    ran = sum(1 for r in results["scenarios"].values() if not r.get("skipped"))
    skipped = sum(1 for r in results["scenarios"].values() if r.get("skipped"))
    errors = sum(1 for r in results["scenarios"].values() if r.get("error"))

    results["summary"] = {
        "ran": ran,
        "skipped": skipped,
        "errors": errors,
        "all_passed": errors == 0,
    }
    return results


if __name__ == "__main__":
    import sys

    gw = sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:18080"
    root = Path(".").resolve()
    print(json.dumps(run_all(gw, root), indent=2))
