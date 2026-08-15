#!/usr/bin/env python3
"""Shared evidence rules: skipped is not a pass; a broken audit chain is a failure."""
from __future__ import annotations

from typing import Any


def scenario_summary(scenarios: dict[str, Any]) -> dict[str, Any]:
    """Build a summary that research reviewers can trust.

    - ``verdict=not_evaluated`` when nothing ran (features absent).
    - ``verdict=failed`` when any scenario returned ``error``.
    - ``verdict=passed`` only when at least one scenario ran and none errored.
    - ``all_passed`` is true only for ``verdict=passed`` (never for skip-only).
    """
    ran = sum(1 for r in scenarios.values() if not r.get("skipped"))
    skipped = sum(1 for r in scenarios.values() if r.get("skipped"))
    errors = sum(1 for r in scenarios.values() if r.get("error"))
    if errors:
        verdict = "failed"
        all_passed = False
    elif ran == 0:
        verdict = "not_evaluated"
        all_passed = False
    else:
        verdict = "passed"
        all_passed = True
    return {
        "ran": ran,
        "skipped": skipped,
        "errors": errors,
        "all_passed": all_passed,
        "verdict": verdict,
    }


def residency_ok(chain_valid: Any) -> bool:
    return chain_valid is True


def beacon_has_pathogen_filter_terms(info: dict) -> bool:
    terms = info.get("filteringTerms") or []
    if isinstance(terms, dict):
        terms = terms.get("filteringTerms") or []
    return any(
        (t.get("id") or "").lower() == "pathogenfilter"
        for t in terms
        if isinstance(t, dict)
    )
