#!/bin/bash
# Découverte des nouveaux projets à rattacher sur la matrice (sans modification).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/project-attachments.sh
source "$SCRIPT_DIR/lib/project-attachments.sh"

log() { printf '%s\n' "$*"; }

project_attachments_discover
count="$MATRIX_ATTACH_COUNT"

log "=== Découverte rattachements projets ==="
log "Matrice : ${REQUIREMENTS_MATRIX}"
log "Propositions : $count ligne(s) → $MATRIX_ATTACH_TSV"

if [[ "$count" -eq 0 ]]; then
  log "Aucun nouveau rattachement matrice à proposer."
  exit 0
fi

declare -a _venv_missing=()
declare -a _attach_projects=()
while IFS=$'\t' read -r project pkg _spec _installed action; do
  [[ "$project" == "project" || -z "$project" ]] && continue
  if [[ "${action:-}" == "venv_missing" ]]; then
    _venv_missing+=("$project")
    continue
  fi
  already=0
  for p in "${_attach_projects[@]}"; do
    [[ "$p" == "$project" ]] && { already=1; break; }
  done
  [[ "$already" -eq 1 ]] && continue
  _attach_projects+=("$project")
done <"$MATRIX_ATTACH_TSV"

if [[ ${#_venv_missing[@]} -gt 0 ]]; then
  log ""
  log "Projets déjà sur la matrice mais sans .venv :"
  for project in "${_venv_missing[@]}"; do
    log "  • $project"
  done
  log "→ Installateur : « Venv install » (ou scripts/rebuild_all_venvs.sh install)"
  log "  « Rattacher » ne crée pas de venv — il ajoute un projet absent de la matrice."
fi

if [[ ${#_attach_projects[@]} -eq 0 ]]; then
  exit 0
fi

log ""
log "Nouveaux rattachements matrice :"
for project in "${_attach_projects[@]}"; do
  ref="$(project_attachments_reference_for "$project")"
  if [[ -n "$ref" ]]; then
    log "  • $project (réf. $ref)"
  else
    log "  • $project"
  fi
done

log ""
log "Confirmez via le bouton « Rattacher nouveaux projets » dans l'app (ou apply-project-attachments.sh en CLI)."
