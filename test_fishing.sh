#!/usr/bin/env bash
# Native gameplay regression checks and fresh PNG / HTML compilation.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
exec bash scripts/test-fishing.sh
