#!/bin/bash
# Répare « Missing package product » dans Xcode (SPM local AlphaLagoonPaths).
set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:${PATH:-/usr/bin:/bin}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
XCODE_BASE="${INSTALLER_XCODE_BASE:-${HOME}/XcodeProjects}"
WORKSPACE="${REPO_ROOT}/package_updater.xcworkspace"
SCHEME="${PACKAGE_UPDATER_SCHEME:-package_updater}"

log() { printf '%s\n' "$*"; }
die() { log "ERREUR: $*"; exit 1; }

# shellcheck source=/dev/null
source "${XCODE_BASE}/installer/scripts/lib/xcode-env.sh"
ensure_xcode_developer_dir || die "Xcode requis"

"${XCODE_BASE}/installer/scripts/assert-alphlagoon-paths-sibling.sh" "$REPO_ROOT"

log "Fermez Xcode complètement (⌘Q) avant de continuer."
log "Nettoyage caches SPM / DerivedData…"
rm -rf "${HOME}/Library/Developer/Xcode/DerivedData"/package_updater-*
rm -rf "${HOME}/Library/Caches/org.swift.swiftpm" 2>/dev/null || true
rm -rf "${REPO_ROOT}/package_updater.xcodeproj/project.xcworkspace/xcuserdata" 2>/dev/null || true

log "Résolution SPM (workspace)…"
xcodebuild -workspace "$WORKSPACE" -scheme "$SCHEME" -resolvePackageDependencies

log ""
log "OK — ouvrez le workspace (pas le .xcodeproj seul) :"
log "  open \"${WORKSPACE}\""
log "Schéma : ${SCHEME} → Product → Clean Build Folder → ⌘B."
