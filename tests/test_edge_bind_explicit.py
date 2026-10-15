"""Pi and village starters must set FERRUM_BIND. No Docker."""
from __future__ import annotations

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCENARIO_DIRS = (
    ROOT / "demo" / "scenarios" / "raspberry-pi",
    ROOT / "demo" / "scenarios" / "village-network",
)


def scenario_templates() -> list[Path]:
    found: list[Path] = []
    for directory in SCENARIO_DIRS:
        for path in sorted(directory.rglob("*")):
            if not path.is_file():
                continue
            name = path.name
            if name.endswith((".yml", ".yaml")) or name.startswith("install"):
                found.append(path)
    return found


class TestEdgeBindExplicit(unittest.TestCase):
    def test_known_templates_are_included(self):
        names = {path.name for path in scenario_templates()}
        self.assertIn("install-ferrum-edge.sh", names)
        self.assertIn("docker-compose.village.yml", names)

    def test_each_template_contains_ferrum_bind(self):
        templates = scenario_templates()
        self.assertGreaterEqual(len(templates), 2)
        for path in templates:
            text = path.read_text(encoding="utf-8")
            self.assertIn(
                "FERRUM_BIND",
                text,
                f"{path.relative_to(ROOT)} starts a Pi or village scenario without FERRUM_BIND",
            )

    def test_village_sets_bind_on_both_services(self):
        text = (
            ROOT / "demo" / "scenarios" / "village-network" / "docker-compose.village.yml"
        ).read_text(encoding="utf-8")
        self.assertGreaterEqual(text.count('FERRUM_BIND: "0.0.0.0:8080"'), 2)

    def test_pi_publish_defaults_to_all_interfaces(self):
        text = (
            ROOT / "demo" / "scenarios" / "raspberry-pi" / "install-ferrum-edge.sh"
        ).read_text(encoding="utf-8")
        self.assertIn("${FERRUM_LISTEN_HOST:-0.0.0.0}:${FERRUM_PORT}:8080", text)
        self.assertIn('FERRUM_BIND: "0.0.0.0:8080"', text)
        self.assertIn(
            "The node is reachable from the LAN because the installer sets the bind address explicitly.",
            text,
        )
