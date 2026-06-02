#!/bin/bash
# Copie la matrice (source de vérité) vers installer.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

INSTALLER_ROOT="${INSTALLER_ROOT:-$HOME/XcodeProjects/installer}"
MATRIX_SRC="${REQUIREMENTS_MATRIX:-$SCRIPT_DIR/requirements_matrix.txt}"
MATRIX_DST="${INSTALLER_ROOT}/scripts/requirements_matrix.txt"

log() { printf '%s\n' "$*"; }

if [[ ! -f "$MATRIX_SRC" ]]; then
  log "ERREUR: matrice introuvable: $MATRIX_SRC"
  exit 1
fi

if [[ ! -d "$INSTALLER_ROOT" ]]; then
  log "ERREUR: installateur introuvable: $INSTALLER_ROOT"
  exit 1
fi

mkdir -p "$(dirname "$MATRIX_DST")"
cp "$MATRIX_SRC" "$MATRIX_DST"
log "Matrice copiée vers:"
log "  $MATRIX_DST"
log ""
log "Lancez installer → Venv install pour appliquer sur les .venv."
