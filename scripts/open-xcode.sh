#!/bin/bash
# Ouvre package_updater dans Xcode (workspace + résolution SPM).
set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:${PATH:-/usr/bin:/bin}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
XCODE_BASE="${INSTALLER_XCODE_BASE:-${HOME}/XcodeProjects}"
WORKSPACE="${REPO_ROOT}/package_updater.xcworkspace"
SCHEME="${PACKAGE_UPDATER_SCHEME:-package_updater}"

# shellcheck source=/dev/null
source "${XCODE_BASE}/installer/scripts/lib/xcode-env.sh"
ensure_xcode_developer_dir

"${XCODE_BASE}/installer/scripts/assert-alphlagoon-paths-sibling.sh" "$REPO_ROOT"

xcodebuild -workspace "$WORKSPACE" -scheme "$SCHEME" -resolvePackageDependencies >/dev/null

exec open "$WORKSPACE"
