"""Caller workflows must not force truth alleles."""
from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def _command_without_comments(text: str) -> str:
    """Extract runnable command text, dropping comment lines."""
    bodies: list[str] = []
    for m in re.finditer(r"command\s*<<<(.*?)>>>", text, re.S):
        bodies.append(m.group(1))
    # Nextflow / shell: keep non-comment lines that look like gatk invocations.
    if not bodies:
        bodies.append(text)
    out: list[str] = []
    for body in bodies:
        for ln in body.splitlines():
            stripped = ln.strip()
            if stripped.startswith("#") or stripped.startswith("//"):
                continue
            out.append(ln)
    return "\n".join(out)


class TestCallerHonesty(unittest.TestCase):
    def test_wdl_and_nf_do_not_pass_alleles(self):
        for rel in (
            "workflows/tiny_hc.wdl",
            "workflows/tiny_hc.nf",
            "workflows/tiny_hc_gatk_rs.nf",
        ):
            text = (ROOT / rel).read_text(encoding="utf-8")
            cmd = _command_without_comments(text)
            self.assertNotIn("--alleles", cmd, rel)
            self.assertNotIn("--minimum-mapping-quality 0", cmd, rel)
            self.assertNotIn("--min-mapping-quality 0", cmd, rel)
            self.assertNotIn("gatkr/gatk-rs:latest", text, rel)

    def test_stock_pin_does_not_rsync_overlay(self):
        run_sh = (ROOT / "demo/run.sh").read_text(encoding="utf-8")
        self.assertNotIn("vendor/ferrum-overlay", run_sh)
        self.assertNotIn("rsync -a", run_sh)
        self.assertFalse((ROOT / "vendor/ferrum-overlay").exists())
        pin = (ROOT / "PINNED_VERSIONS.txt").read_text(encoding="utf-8")
        self.assertIn("2bd147c99735866ac9cfb530f62ef984c8efce8b", pin)


if __name__ == "__main__":
    unittest.main()
