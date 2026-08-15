# Ferrum GA4GH Demo — Synaptic Four unified local lifecycle

.PHONY: help up up-with-infra down destroy smoke-syntax smoke-evidence smoke-evidence-strict test prove

help:
	@echo "Ferrum GA4GH Demo — local lifecycle (Synaptic Four GA4GH stack)"
	@echo ""
	@echo "  make up                    Run benchmark demo (./run)"
	@echo "  make up-with-infra         Run demo + ga4gh-infra co-deploy"
	@echo "  make down / destroy        Stop stack (keep / wipe volumes)"
	@echo "  make smoke-syntax          Static checks + unit tests (matches CI)"
	@echo "  make prove                 Same as smoke-syntax (zero-risk; no Docker)"
	@echo "  make smoke-evidence        Validate results/ after ./run"
	@echo "  make smoke-evidence-strict Also require ./run --macro Crypt4GH micro"
	@echo ""
	@echo "Coverage map: docs/COVERAGE.md · Pins: PINNED_VERSIONS.txt"
	@echo "Also: ./run --down, ./run --destroy, scripts/stack-down.sh"
	@echo "Sibling Ferrum: export FERRUM_SRC=… (deprecated alias FERUM_SRC=…)"

up:
	@chmod +x run scripts/stack-down.sh 2>/dev/null || true
	./run

up-with-infra:
	@chmod +x run scripts/stack-down.sh 2>/dev/null || true
	./run --with-infra

down:
	@chmod +x scripts/stack-down.sh 2>/dev/null || true
	./scripts/stack-down.sh

destroy:
	@chmod +x scripts/stack-down.sh 2>/dev/null || true
	./scripts/stack-down.sh --volumes

smoke-syntax:
	@chmod +x scripts/smoke-syntax.sh
	./scripts/smoke-syntax.sh

smoke-evidence:
	@chmod +x scripts/smoke-evidence.sh
	./scripts/smoke-evidence.sh

smoke-evidence-strict:
	@chmod +x scripts/smoke-evidence.sh
	./scripts/smoke-evidence.sh --strict

test:
	python3 -m unittest discover -s tests -t . -p 'test_*.py' -v

prove: smoke-syntax
	@echo "Ferrum-GA4GH-Demo offline prove OK. Live: make up && make smoke-evidence"
