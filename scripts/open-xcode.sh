#!/bin/bash
# Ouvre package_updater dans Xcode (.xcodeproj — SPM AlphaLagoonPaths via Git).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

exec open "${REPO_ROOT}/package_updater.xcodeproj"
