#!/usr/bin/env python3
"""Time DRS /stream wall-clock (plain vs optional Crypt4GH client header). Writes JSON for metrics."""
from __future__ import annotations

import argparse
import json
import statistics
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any


def stream_once(
    url: str,
    max_bytes: int,
    headers: dict[str, str],
) -> tuple[float, int]:
    req = urllib.request.Request(url, headers=headers)
    t0 = time.perf_counter()
    n = 0
    with urllib.request.urlopen(req, timeout=600) as resp:
        while True:
            chunk = resp.read(1024 * 256)
            if not chunk:
                break
            n += len(chunk)
            if max_bytes > 0 and n >= max_bytes:
                break
    elapsed = time.perf_counter() - t0
    return elapsed, n


def median_p95(values: list[float]) -> dict[str, float]:
    if not values:
        return {"median": 0.0, "p95": 0.0}
    s = sorted(values)
    mid = s[len(s) // 2]
    idx = max(0, int(round(0.95 * (len(s) - 1))))
    return {"median": float(mid), "p95": float(s[idx])}


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("gateway_base", help="e.g. http://127.0.0.1:18080")
    p.add_argument("object_id", help="DRS object id to stream")
    p.add_argument("--repeat", type=int, default=3, help="repetitions per mode")
    p.add_argument(
        "--max-bytes",
        type=int,
        default=8_000_000,
        help="stop after this many bytes (0 = full stream)",
    )
    p.add_argument(
        "--crypt4gh-pubkey",
        type=Path,
        default=None,
        help="if set, also measure with X-Crypt4GH-Public-Key (ASCII armored)",
    )
    p.add_argument("-o", "--output", type=Path, default=Path("results/drs_micro.json"))
    args = p.parse_args()

    base = args.gateway_base.rstrip("/")
    url = f"{base}/ga4gh/drs/v1/objects/{args.object_id}/stream"
    repeat = max(1, args.repeat)

    out: dict[str, Any] = {
        "drs_stream_url": url,
        "object_id": args.object_id,
        "repeat_n": repeat,
        "max_bytes": args.max_bytes,
        "plain": {},
        "crypt4gh": None,
    }

    plain_times: list[float] = []
    plain_bytes: list[int] = []
    for _ in range(repeat):
        try:
            elapsed, nbytes = stream_once(url, args.max_bytes, {})
        except urllib.error.HTTPError as e:
            print(f"[drs_micro] plain HTTP {e.code}: {e.reason}", file=sys.stderr)
            sys.exit(1)
        except Exception as e:
            print(f"[drs_micro] plain error: {e}", file=sys.stderr)
            sys.exit(1)
        plain_times.append(elapsed)
        plain_bytes.append(nbytes)

    b = plain_bytes[0] if plain_bytes else 0
    med = median_p95(plain_times)
    out["plain"] = {
        "wall_seconds": med,
        "bytes_transferred": b,
        "throughput_mib_s": (b / (1024 * 1024) / med["median"]) if med["median"] > 0 else 0.0,
        "samples": plain_times,
    }

    if args.crypt4gh_pubkey and args.crypt4gh_pubkey.is_file():
        key = args.crypt4gh_pubkey.read_text(encoding="utf-8", errors="replace").strip()
        hdr = {"X-Crypt4GH-Public-Key": key}
        crypt_times: list[float] = []
        crypt_bytes: list[int] = []
        for _ in range(repeat):
            try:
                elapsed, nbytes = stream_once(url, args.max_bytes, hdr)
            except urllib.error.HTTPError as e:
                out["crypt4gh"] = {
                    "error": f"HTTP {e.code}",
                    "skipped": True,
                }
                crypt_times = []
                break
            except Exception as e:
                out["crypt4gh"] = {"error": str(e), "skipped": True}
                crypt_times = []
                break
            crypt_times.append(elapsed)
            crypt_bytes.append(nbytes)
        if crypt_times:
            b2 = crypt_bytes[0] if crypt_bytes else 0
            med_c = median_p95(crypt_times)
            out["crypt4gh"] = {
                "wall_seconds": med_c,
                "bytes_transferred": b2,
                "throughput_mib_s": (b2 / (1024 * 1024) / med_c["median"])
                if med_c["median"] > 0
                else 0.0,
                "samples": crypt_times,
            }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(out, indent=2))
    print(json.dumps({"ok": True, "wrote": str(args.output)}))


if __name__ == "__main__":
    main()
