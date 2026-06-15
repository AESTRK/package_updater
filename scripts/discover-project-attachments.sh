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
  log "Aucun nouveau rattachement à proposer."
  exit 0
fi

declare -a _seen_projects=()
while IFS=$'\t' read -r project pkg _spec _installed action; do
  [[ "$project" == "project" || -z "$project" ]] && continue
  already=0
  for p in "${_seen_projects[@]}"; do
    [[ "$p" == "$project" ]] && { already=1; break; }
  done
  [[ "$already" -eq 1 ]] && continue
  _seen_projects+=("$project")
  ref="$(project_attachments_reference_for "$project")"
  if [[ -n "$ref" ]]; then
    log "  • $project (réf. $ref)"
  else
    log "  • $project"
  fi
done <"$MATRIX_ATTACH_TSV"

log ""
log "Confirmez via le bouton « Rattacher nouveaux projets » dans l'app (ou apply-project-attachments.sh en CLI)."
