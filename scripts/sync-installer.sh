#!/bin/bash
# Bouton « Sync installateur » — copie matrice → installer + archive.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${PACKAGE_UPDATER_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
INSTALLER_ROOT="${INSTALLER_ROOT:-$HOME/XcodeProjects/installer}"
MATRIX_NAME="package_updater_latest_matrix.txt"
SRC="${REQUIREMENTS_MATRIX:-$REPO_ROOT/$MATRIX_NAME}"
DST="${INSTALLER_ROOT}/${MATRIX_NAME}"
HIST_DIR="${REPO_ROOT}/history"

log() { printf '%s\n' "$*"; }

if [[ ! -f "$SRC" ]]; then
  log "ERREUR: matrice introuvable: $SRC"
  exit 1
fi
if [[ ! -d "$INSTALLER_ROOT" ]]; then
  log "ERREUR: installateur introuvable: $INSTALLER_ROOT"
  exit 1
fi

mkdir -p "$HIST_DIR"
TS="$(date +%Y%m%d_%H%M%S)"
cp "$SRC" "$HIST_DIR/${TS}_${MATRIX_NAME}"
log "Historique : $HIST_DIR/${TS}_${MATRIX_NAME}"

cp "$SRC" "$DST"
log "Matrice copiée vers installateur:"
log "  $DST"
log ""
log "Lancez installer → Venv install pour appliquer sur les .venv."
