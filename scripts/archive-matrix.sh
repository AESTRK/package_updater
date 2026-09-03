#!/bin/bash
# Archive la matrice canonique config/generated/pip_matrix.txt (snapshot history/).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${PACKAGE_UPDATER_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
CONFIG_ROOT="${ALPHA_LAGOON_CONFIG_ROOT:-$HOME/XcodeProjects/config_manager/config}"
STACK_PATHS_PY="$CONFIG_ROOT/scripts/stack_paths.py"
HIST_DIR="${REPO_ROOT}/history"
MATRIX_NAME="pip_matrix.txt"

log() { printf '%s\n' "$*"; }

if [[ ! -f "$STACK_PATHS_PY" ]]; then
  log "ERREUR: stack_paths.py introuvable: $STACK_PATHS_PY"
  exit 1
fi

DST="$(python3 "$STACK_PATHS_PY" pip_matrix)"
if [[ ! -f "$DST" ]]; then
  log "ERREUR: matrice absente: $DST"
  log "Lancez Sync stack (config_manager) ou un audit package_updater."
  exit 1
fi

mkdir -p "$HIST_DIR"
TS="$(date +%Y%m%d_%H%M%S)"
cp "$DST" "$HIST_DIR/${TS}_${MATRIX_NAME}"
log "Historique : $HIST_DIR/${TS}_${MATRIX_NAME}"
log "Matrice canonique : $DST"
log ""
log "Commit config_manager si besoin. Lancez installer → Venv install pour appliquer sur les .venv."
