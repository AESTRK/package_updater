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

run_apply_matrix() {
  local run_dir="${1:-}"
  log "=== Application matrice (MATRICE_A_RAFRAICHIR) ==="
  bash "$SCRIPT_DIR/apply_matrix_updates.sh" "$run_dir"
}

case "$MODE" in
  audit)
    run_audit
    ;;
  sync-installer)
    run_sync
    ;;
  apply-matrix)
    run_apply_matrix "${2:-}"
    ;;
  publish)
    run_audit
    run_sync
    log ""
    log "Publication terminée (audit + matrice → installateur)."
    ;;
  audit-apply)
    run_audit
    run_apply_matrix ""
    log ""
    log "Audit + matrice mise à jour. Relancez sync-installer puis venv install si besoin."
    ;;
  *)
    log "Usage: $0 [audit|sync-installer|apply-matrix [run_dir]|audit-apply|publish]"
    exit 1
    ;;
esac
