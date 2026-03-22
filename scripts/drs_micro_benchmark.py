#!/usr/bin/env python3
"""Time DRS /stream wall-clock: plaintext storage vs Crypt4GH-at-rest (server decrypt).

Also supports optional ``--crypt4gh-pubkey`` (base64 single-line or PEM) for
``X-Crypt4GH-Public-Key`` — only effective when the gateway applies client
re-encryption (e.g. authenticated Passport flows); the demo compares at-rest
objects via ``--encrypted-object-id`` instead.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any


def normalize_crypt4gh_pubkey_header(raw: str) -> str:
    """HTTP headers must be a single line. PEM is reduced to the inner base64."""
    s = raw.strip()
    if not s:
        return s
    if "BEGIN" in s and "CRYPT4GH" in s.upper():
        lines = [
            ln.strip()
            for ln in s.splitlines()
            if ln.strip() and not ln.strip().startswith("-----")
        ]
        return "".join(lines)
    return "".join(s.split())


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


def bench_mode(
    base: str,
    object_id: str,
    repeat: int,
    max_bytes: int,
) -> dict[str, Any]:
    url = f"{base}/ga4gh/drs/v1/objects/{object_id}/stream"
    times: list[float] = []
    nbytes_list: list[int] = []
    for _ in range(repeat):
        try:
            elapsed, nbytes = stream_once(url, max_bytes, {})
        except urllib.error.HTTPError as e:
            return {
                "drs_stream_url": url,
                "object_id": object_id,
                "error": f"HTTP {e.code}",
                "skipped": True,
            }
        except Exception as e:
            return {
                "drs_stream_url": url,
                "object_id": object_id,
                "error": str(e),
                "skipped": True,
            }
        times.append(elapsed)
        nbytes_list.append(nbytes)
    b = nbytes_list[0] if nbytes_list else 0
    med = median_p95(times)
    return {
        "drs_stream_url": url,
        "object_id": object_id,
        "wall_seconds": med,
        "bytes_transferred": b,
        "throughput_mib_s": (b / (1024 * 1024) / med["median"]) if med["median"] > 0 else 0.0,
        "samples": times,
    }


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("gateway_base", help="e.g. http://127.0.0.1:18080")
    p.add_argument(
        "object_id",
        help="DRS object id (plaintext-at-rest ref_fasta, or sole object for single-mode)",
    )
    p.add_argument("--repeat", type=int, default=3, help="repetitions per mode")
    p.add_argument(
        "--max-bytes",
        type=int,
        default=8_000_000,
        help="stop after this many bytes (0 = full stream)",
    )
    p.add_argument(
        "--encrypted-object-id",
        default=None,
        help=(
            "second object id: same logical file ingested with encrypt=true; "
            "measures GET /stream with server-side Crypt4GH decrypt (Ferrum DRS)."
        ),
    )
    p.add_argument(
        "--crypt4gh-pubkey",
        type=Path,
        default=None,
        help="optional X-Crypt4GH-Public-Key (PEM file or single-line base64)",
    )
    p.add_argument("-o", "--output", type=Path, default=Path("results/drs_micro.json"))
    args = p.parse_args()

    base = args.gateway_base.rstrip("/")
    repeat = max(1, args.repeat)

    out: dict[str, Any] = {
        "drs_stream_url": f"{base}/ga4gh/drs/v1/objects/{args.object_id}/stream",
        "object_id": args.object_id,
        "repeat_n": repeat,
        "max_bytes": args.max_bytes,
        "plain": {},
        "crypt4gh_at_rest": None,
        "crypt4gh": None,
    }

    plain_block = bench_mode(base, args.object_id, repeat, args.max_bytes)
    if plain_block.get("skipped"):
        out["plain"] = plain_block
    else:
        out["drs_stream_url"] = plain_block["drs_stream_url"]
        out["plain"] = {
            "wall_seconds": plain_block["wall_seconds"],
            "bytes_transferred": plain_block["bytes_transferred"],
            "throughput_mib_s": plain_block["throughput_mib_s"],
            "samples": plain_block["samples"],
        }

    if args.encrypted_object_id:
        out["encrypted_object_id"] = args.encrypted_object_id
        enc_block = bench_mode(base, args.encrypted_object_id, repeat, args.max_bytes)
        if enc_block.get("skipped"):
            out["crypt4gh_at_rest"] = enc_block
        else:
            out["crypt4gh_at_rest"] = {
                "wall_seconds": enc_block["wall_seconds"],
                "bytes_transferred": enc_block["bytes_transferred"],
                "throughput_mib_s": enc_block["throughput_mib_s"],
                "samples": enc_block["samples"],
                "note": "Crypt4GH ciphertext in storage; gateway decrypts on /stream when configured",
            }

    if args.crypt4gh_pubkey and args.crypt4gh_pubkey.is_file():
        key_raw = args.crypt4gh_pubkey.read_text(encoding="utf-8", errors="replace")
        key = normalize_crypt4gh_pubkey_header(key_raw)
        if not key or not re.match(r"^[A-Za-z0-9+/=_-]+$", key):
            out["crypt4gh"] = {
                "error": "public key is empty or not valid base64 after PEM normalization",
                "skipped": True,
            }
        else:
            url = f"{base}/ga4gh/drs/v1/objects/{args.object_id}/stream"
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
                    "note": "Client header path; may match plain if gateway does not re-encrypt for this request",
                }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(out, indent=2))
    print(json.dumps({"ok": True, "wrote": str(args.output)}))


if __name__ == "__main__":
    main()
