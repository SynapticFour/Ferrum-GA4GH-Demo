#!/usr/bin/env python3
"""Build GA4GH WES run JSON for WDL or Nextflow (params file + workflow URL)."""
from __future__ import annotations

import json
import os
import sys


def main() -> None:
    if len(sys.argv) != 4:
        print(
            "usage: build_wes_payload.py <workflow_url> <params.json> <wes_request.json>",
            file=sys.stderr,
        )
        sys.exit(2)
    wf_url, params_path, out_path = sys.argv[1:4]
    engine = os.environ.get("FERRUM_GA4GH_ENGINE", "wdl").strip().lower()
    params = json.loads(open(params_path, encoding="utf-8").read())
    if engine == "nextflow":
        body = {
            "workflow_type": "NEXTFLOW",
            "workflow_type_version": "23.04",
            "workflow_url": wf_url,
            "workflow_params": params,
            "workflow_engine_parameters": {},
        }
    else:
        body = {
            "workflow_type": "WDL",
            "workflow_type_version": "1.0",
            "workflow_url": wf_url,
            "workflow_params": params,
            "workflow_engine_parameters": {},
        }
    open(out_path, "w", encoding="utf-8").write(json.dumps(body, indent=2))


if __name__ == "__main__":
    main()
