#!/bin/bash
# Package Updater : audit venv + publication matrice vers l'installateur.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="${1:-audit}"

log() { printf '%s\n' "$*"; }

run_audit() {
  log "=== Audit venv ==="
  bash "$SCRIPT_DIR/audit_venvs.sh"
}

run_sync() {
  log "=== Sync vers installateur ==="
  bash "$SCRIPT_DIR/sync-to-installer.sh"
}

case "$MODE" in
  audit)
    run_audit
    ;;
  sync-installer)
    run_sync
    ;;
  publish)
    run_audit
    run_sync
    log ""
    log "Publication terminée (audit + matrice → installateur)."
    ;;
  *)
    log "Usage: $0 [audit|sync-installer|publish]"
    exit 1
    ;;
esac
