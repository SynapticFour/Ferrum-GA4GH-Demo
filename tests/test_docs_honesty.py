"""Committed docs and paper snapshots must not look like a live GIAB result."""
from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class TestDocsHonesty(unittest.TestCase):
    def test_readme_does_not_point_at_deleted_video_script(self):
        readme = (ROOT / "README.md").read_text(encoding="utf-8")
        self.assertNotIn("video-script", readme)
        self.assertNotIn("HeyGen", readme)

    def test_readme_states_pipeline_smoke(self):
        readme = (ROOT / "README.md").read_text(encoding="utf-8")
        self.assertIn("pipeline smoke", readme.lower())
        self.assertIn("alleles", readme.lower())
        self.assertNotIn("| Precision | 1.0 |", readme)
        self.assertNotIn("| F1 | 1.0 |", readme)

    def test_decisions_does_not_claim_in_repo_video_script(self):
        text = (ROOT / "DECISIONS.md").read_text(encoding="utf-8")
        self.assertNotIn("Video script lives in-repo", text)

    def test_claims_and_outputs_exist(self):
        self.assertTrue((ROOT / "docs" / "CLAIMS.md").is_file())
        self.assertTrue((ROOT / "docs" / "OUTPUTS.md").is_file())
        self.assertTrue((ROOT / "docs" / "PERSONA.md").is_file())
        self.assertTrue((ROOT / "NOTICE").is_file())
        self.assertTrue((ROOT / "docs" / "examples" / "RUN_MANIFEST.example.json").is_file())

    def test_architecture_skip_is_not_a_pass(self):
        text = (ROOT / "docs" / "architecture.md").read_text(encoding="utf-8")
        self.assertNotIn("all_passed: true", text)
        self.assertIn("not_evaluated", text)

    def test_ecosystem_is_not_a_giab_publication_benchmark(self):
        text = (ROOT / "docs" / "ECOSYSTEM.md").read_text(encoding="utf-8")
        self.assertNotIn("Reproducible GIAB benchmark", text)
        self.assertIn("pipeline smoke", text.lower())

    def test_infra_pin_is_set(self):
        pins = (ROOT / "PINNED_VERSIONS.txt").read_text(encoding="utf-8")
        line = next(ln for ln in pins.splitlines() if ln.startswith("GA4GH-INFRA-git="))
        sha = line.split("=", 1)[1].strip()
        self.assertRegex(sha, r"^[0-9a-f]{40}$")

    def test_example_manifest_schema(self):
        example = json.loads(
            (ROOT / "docs" / "examples" / "RUN_MANIFEST.example.json").read_text(
                encoding="utf-8"
            )
        )
        for key in (
            "what_this_run_is",
            "what_this_run_is_not",
            "hap_py",
            "trs",
            "africa",
            "security_demo_only",
        ):
            self.assertIn(key, example)
        self.assertFalse(example["trs"]["descriptor_executed_as_wes"])
        self.assertFalse(example["africa"]["all_passed"])
        self.assertEqual(example["africa"]["verdict"], "not_evaluated")

    def test_paper_snapshot_is_labelled_withdrawn(self):
        paper = ROOT / "docs" / "paper" / "20260322T1331Z"
        withdrawn = json.loads((paper / "WITHDRAWN.json").read_text(encoding="utf-8"))
        self.assertTrue(withdrawn["claim_withdrawn"])
        bench = json.loads((paper / "benchmark.json").read_text(encoding="utf-8"))
        self.assertTrue(bench["claim_withdrawn"])
        self.assertIs(bench["caller_uses_truth_alleles"], True)

    def test_committed_benchmark_md_is_pipeline_smoke(self):
        text = (ROOT / "docs" / "benchmark.md").read_text(encoding="utf-8")
        self.assertIn("pipeline smoke", text.lower())
        self.assertNotIn("| Precision | 1.0 |", text)
        self.assertNotIn("| F1 | 1.0 |", text)
        self.assertNotIn("--alleles` | yes", text)


class TestUpdateDocsRedactsWithdrawn(unittest.TestCase):
    def test_missing_alleles_flag_redacts_f1(self):
        import importlib.util

        spec = importlib.util.spec_from_file_location(
            "update_docs", ROOT / "scripts" / "update_docs.py"
        )
        mod = importlib.util.module_from_spec(spec)
        assert spec.loader is not None
        spec.loader.exec_module(mod)
        self.assertTrue(mod._hap_withdrawn({"precision": 1.0, "f1_score": 1.0}))
        self.assertFalse(
            mod._hap_withdrawn(
                {
                    "precision": 0.5,
                    "f1_score": 0.5,
                    "caller_uses_truth_alleles": False,
                }
            )
        )
        cell = mod._hap_cell({"precision": 1.0}, "precision")
        self.assertIn("withdrawn", cell.lower())


class TestWriteRunManifestCite(unittest.TestCase):
    def test_cite_false_when_alleles_unknown(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            (root / "results").mkdir()
            (root / "results" / "benchmark.json").write_text(
                json.dumps({"precision": 1.0, "recall": 1.0, "f1_score": 1.0}),
                encoding="utf-8",
            )
            (root / "PINNED_VERSIONS.txt").write_text(
                "Ferrum-git=deadbeef\n", encoding="utf-8"
            )
            import subprocess

            subprocess.check_call(
                [
                    "python3",
                    str(ROOT / "demo" / "lib" / "write_run_manifest.py"),
                    str(root),
                ]
            )
            man = json.loads((root / "results" / "RUN_MANIFEST.json").read_text())
            self.assertFalse(man["hap_py"]["cite"])
            self.assertIn("GIAB", " ".join(man["what_this_run_is_not"]))


if __name__ == "__main__":
    unittest.main()
