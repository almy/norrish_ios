#!/bin/bash
set -euo pipefail

ROOT_DIR="${SRCROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$ROOT_DIR"

BEFORE=$(xcrun agvtool what-version -terse)
xcrun agvtool next-version -all >/dev/null
AFTER=$(xcrun agvtool what-version -terse)

echo "[Archive Pre-Action] Build number bumped: ${BEFORE} -> ${AFTER}"
