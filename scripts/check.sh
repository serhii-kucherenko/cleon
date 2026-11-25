#!/bin/bash
# scripts/check.sh - the one command that checks cleon: every script parses, then the smoke test. CI runs it.
set -eu
cd "$(dirname "$0")/.."
for f in bin/cleon hooks/cleon-swap.sh install.sh tests/smoke.sh demo/setup.sh demo/record.sh scripts/check.sh; do bash -n "$f"; done
bash tests/smoke.sh
