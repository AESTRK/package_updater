#!/bin/bash
# Copie la matrice pip vers config/generated/pip_matrix.txt (source unique Phase 2).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${PACKAGE_UPDATER_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
CONFIG_ROOT="${ALPHA_LAGOON_CONFIG_ROOT:-$HOME/XcodeProjects/config_manager/config}"
STACK_PATHS_PY="$CONFIG_ROOT/scripts/stack_paths.py"
MATRIX_NAME="package_updater_latest_matrix.txt"
SRC="${REQUIREMENTS_MATRIX:-$REPO_ROOT/$MATRIX_NAME}"
HIST_DIR="${REPO_ROOT}/history"

log() { printf '%s\n' "$*"; }

if [[ ! -f "$SRC" ]]; then
  log "ERREUR: matrice introuvable: $SRC"
  exit 1
fi
if [[ ! -f "$STACK_PATHS_PY" ]]; then
  log "ERREUR: stack_paths.py introuvable: $STACK_PATHS_PY"
  exit 1
fi

DST="$(python3 "$STACK_PATHS_PY" pip_matrix)"
mkdir -p "$(dirname "$DST")"
mkdir -p "$HIST_DIR"
TS="$(date +%Y%m%d_%H%M%S)"
cp "$SRC" "$HIST_DIR/${TS}_${MATRIX_NAME}"
log "Historique : $HIST_DIR/${TS}_${MATRIX_NAME}"

cp "$SRC" "$DST"
log "Matrice copiée vers config généré:"
log "  $DST"
log ""
log "Commit config_manager si besoin. Lancez installer → Venv install pour appliquer sur les .venv."
