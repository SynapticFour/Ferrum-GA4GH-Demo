# Ferrum GA4GH Demo — Synaptic Four unified local lifecycle

.PHONY: help up up-with-infra down destroy

help:
	@echo "Ferrum GA4GH Demo — local lifecycle (Synaptic Four GA4GH stack)"
	@echo ""
	@echo "  make up              Run benchmark demo (./run)"
	@echo "  make up-with-infra   Run demo + ga4gh-infra co-deploy (./run --with-infra)"
	@echo "  make down            Stop stack; keep volumes"
	@echo "  make destroy         Stop stack; remove volumes"
	@echo ""
	@echo "Also: ./run --down, ./run --destroy, scripts/stack-down.sh"

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
