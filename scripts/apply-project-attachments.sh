#!/bin/bash
# Applique les rattachements confirmés (APPROVED_PROJECTS) sur la matrice.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${PACKAGE_UPDATER_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
MATRIX_NAME="package_updater_latest_matrix.txt"
DEFAULT_MATRIX="${REPO_ROOT}/${MATRIX_NAME}"
REQUIREMENTS_MATRIX="${REQUIREMENTS_MATRIX:-$DEFAULT_MATRIX}"
LOG_BASE_DIR="${LOG_BASE_DIR:-$HOME/Documents/AlphaLagoon/_logs_XcodeProjects/package_updater}"
HIST_DIR="${REPO_ROOT}/history"
ATTACH_TSV="${MATRIX_ATTACH_TSV:-$LOG_BASE_DIR/audit_matrix_attach.tsv}"

# shellcheck source=lib/project-attachments.sh
source "$SCRIPT_DIR/lib/project-attachments.sh"

log() { printf '%s\n' "$*"; }

archive_matrix() {
  mkdir -p "$HIST_DIR"
  local ts="$HIST_DIR/$(date +%Y%m%d_%H%M%S)_${MATRIX_NAME}"
  cp "$REQUIREMENTS_MATRIX" "$ts"
  log "Historique : $ts"
}

prompt_approved_projects() {
  local project pkg _spec _installed action
  local -a seen_projects=()
  APPROVED_PROJECTS=""
  while IFS=$'\t' read -r project pkg _spec _installed action; do
    [[ "$project" == "project" || -z "$project" ]] && continue
    local already=0 p
    for p in "${seen_projects[@]}"; do
      [[ "$p" == "$project" ]] && { already=1; break; }
    done
    [[ "$already" -eq 1 ]] && continue
    seen_projects+=("$project")
    local count ref answer
    count="$(awk -F'\t' -v p="$project" '$1 == p { c++ } END { print c+0 }' "$ATTACH_TSV")"
    ref="$(project_attachments_reference_for "$project")"
    if [[ -n "$ref" ]]; then
      printf "Rattacher %s sur %s ligne(s) matrice (réf. %s) ? [y/N] " "$project" "$count" "$ref"
    else
      printf "Rattacher %s sur %s ligne(s) matrice ? [y/N] " "$project" "$count"
    fi
    read -r answer
    answer="$(printf '%s' "$answer" | tr '[:upper:]' '[:lower:]')"
    case "$answer" in
      y|yes|o|oui)
        if [[ -z "$APPROVED_PROJECTS" ]]; then
          APPROVED_PROJECTS="$project"
        else
          APPROVED_PROJECTS="$APPROVED_PROJECTS,$project"
        fi
        ;;
    esac
  done <"$ATTACH_TSV"
}

if [[ ! -f "$ATTACH_TSV" ]]; then
  log "Fichier propositions absent, lancement de la découverte…"
  bash "$SCRIPT_DIR/discover-project-attachments.sh"
fi

if [[ ! -f "$ATTACH_TSV" ]]; then
  log "ERREUR: $ATTACH_TSV introuvable."
  exit 1
fi

if [[ ! -f "$REQUIREMENTS_MATRIX" ]]; then
  log "ERREUR: matrice introuvable: $REQUIREMENTS_MATRIX"
  exit 1
fi

if [[ -z "${APPROVED_PROJECTS:-}" ]]; then
  if [[ -t 0 ]]; then
    prompt_approved_projects
  else
    log "ERREUR: APPROVED_PROJECTS non défini (mode non interactif)."
    exit 1
  fi
fi

if [[ -z "${APPROVED_PROJECTS:-}" ]]; then
  log "Aucun rattachement confirmé."
  exit 0
fi

log "=== Application rattachements ==="
log "Projets confirmés : $APPROVED_PROJECTS"
archive_matrix

export REQUIREMENTS_MATRIX ATTACH_TSV APPROVED_PROJECTS
"$(
  command -v python3
)" <<'PY'
import os
import re
from collections import defaultdict
from pathlib import Path

matrix_path = Path(os.environ["REQUIREMENTS_MATRIX"])
attach_path = Path(os.environ["ATTACH_TSV"])
approved = {p.strip() for p in os.environ.get("APPROVED_PROJECTS", "").split(",") if p.strip()}


def pkg_from_spec(spec: str) -> str:
    return re.split(r"[<>=!~\[]", spec, maxsplit=1)[0].strip().lower().replace("_", "-")


def parse_projects(rest: str) -> list[str]:
    return [p.strip() for p in rest.split(",") if p.strip()]


attach_by_pkg: dict[str, set[str]] = defaultdict(set)
for line in attach_path.read_text(encoding="utf-8").splitlines():
    if not line.strip() or line.startswith("project\t"):
        continue
    parts = line.split("\t")
    if len(parts) < 5 or parts[4].strip() != "attach":
        continue
    project, pkg = parts[0].strip(), parts[1].strip()
    if project in approved and pkg:
        attach_by_pkg[pkg_from_spec(pkg)].add(project)

if not attach_by_pkg:
    print("Aucune ligne à appliquer pour les projets confirmés.")
    raise SystemExit(0)

lines = matrix_path.read_text(encoding="utf-8").splitlines(keepends=True)
out = []
changed = 0
for raw in lines:
    line = raw.rstrip("\n")
    stripped = line.strip()
    if not stripped or stripped.startswith("#") or "|" not in stripped:
        out.append(raw if raw.endswith("\n") else raw + "\n")
        continue
    spec_part, rest = stripped.split("|", 1)
    spec_part = spec_part.strip()
    rest = rest.strip()
    pkg = pkg_from_spec(spec_part)
    projects = parse_projects(rest)
    before = list(projects)
    for project in sorted(attach_by_pkg.get(pkg, ())):
        if project not in projects:
            projects.append(project)
    if projects != before:
        changed += len(projects) - len(before)
        added = [p for p in projects if p not in before]
        print(f"  {pkg}  →  +{', '.join(added)}")
        out.append(f"{spec_part} | {', '.join(projects)}\n")
        continue
    out.append(raw if raw.endswith("\n") else raw + "\n")

matrix_path.write_text("".join(out), encoding="utf-8")
print(f"\n{changed} rattachement(s) dans {matrix_path}")
PY

archive_matrix
log ""
log "Relancez « Sync installateur » puis venv install si besoin."
