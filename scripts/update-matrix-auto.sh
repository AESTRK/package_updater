#!/bin/bash
# Bouton « Mettre à jour matrice (auto) » — audit puis remonte les >= (MATRICE_A_RAFRAICHIR).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${PACKAGE_UPDATER_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
MATRIX_NAME="package_updater_latest_matrix.txt"
DEFAULT_MATRIX="${REPO_ROOT}/${MATRIX_NAME}"
REQUIREMENTS_MATRIX="${REQUIREMENTS_MATRIX:-$DEFAULT_MATRIX}"
LOG_BASE_DIR="${LOG_BASE_DIR:-$HOME/Documents/AlphaLagoon/_logs_XcodeProjects/package_updater}"
HIST_DIR="${REPO_ROOT}/history"
TSV="${LOG_BASE_DIR}/audit_matrix_refresh.tsv"

log() { printf '%s\n' "$*"; }

archive_matrix() {
  local src="${1:-$REQUIREMENTS_MATRIX}"
  mkdir -p "$HIST_DIR"
  local ts="$HIST_DIR/$(date +%Y%m%d_%H%M%S)_${MATRIX_NAME}"
  cp "$src" "$ts"
  log "Historique : $ts"
}

log "=== Audit venv ==="
bash "$SCRIPT_DIR/venv-audit.sh"

if [[ ! -f "$TSV" ]]; then
  log "ERREUR: $TSV introuvable. L'audit n'a produit aucune suggestion."
  exit 1
fi
if [[ ! -f "$REQUIREMENTS_MATRIX" ]]; then
  log "ERREUR: matrice introuvable: $REQUIREMENTS_MATRIX"
  exit 1
fi

log ""
log "=== Mise à jour matrice ==="
archive_matrix "$REQUIREMENTS_MATRIX"

export REQUIREMENTS_MATRIX TSV
"$(
  command -v python3
)" <<'PY'
import os
import re
import sys
from pathlib import Path

matrix_path = Path(os.environ["REQUIREMENTS_MATRIX"])
tsv_path = Path(os.environ["TSV"])


def norm(v: str):
    v = v.lower().replace("-", ".")
    parts = []
    for token in re.split(r"[._+]", v):
        if token == "post":
            parts.append(0)
            continue
        m = re.match(r"^(\d+)", token)
        parts.append(int(m.group(1)) if m else 0)
    while len(parts) < 8:
        parts.append(0)
    return tuple(parts[:8])


bumps: dict[str, str] = {}
for line in tsv_path.read_text(encoding="utf-8").splitlines():
    if not line.strip() or line.startswith("project\t"):
        continue
    parts = line.split("\t")
    if len(parts) < 5:
        continue
    pkg, installed, suggested = parts[1], parts[3], parts[4]
    if not installed or installed == "ABSENT":
        continue
    m = re.match(r"^(.+)>=(.+)$", suggested.strip())
    ver = m.group(2).strip() if m else installed.strip()
    key = m.group(1).strip() if m else pkg.strip()
    prev = bumps.get(key)
    if prev is None or norm(ver) > norm(prev):
        bumps[key] = ver

if not bumps:
    print("Aucune suggestion à appliquer (matrix_refresh.tsv vide).")
    sys.exit(0)


def pkg_from_spec(spec: str) -> str:
    return re.split(r"[<>=!~\[]", spec, maxsplit=1)[0].strip().lower().replace("_", "-")

def replace_min(spec: str, new_ver: str) -> str:
    m = re.match(r"^([A-Za-z0-9_.\-]+)\s*([<>=!~]+)\s*([A-Za-z0-9_.!\-+]+)", spec)
    if not m:
        return spec
    pkg, op, old = m.group(1), m.group(2), m.group(3)
    if norm(new_ver) <= norm(old):
        return spec
    return f"{pkg}{op}{new_ver}"

lines = matrix_path.read_text(encoding="utf-8").splitlines(keepends=True)
out = []
changed = 0
for raw in lines:
    line = raw.rstrip("\n")
    stripped = line.strip()
    if not stripped or stripped.startswith("#") or "|" not in stripped:
        out.append(raw if raw.endswith("\n") else raw + "\n")
        continue
    spec_part = stripped.split("|", 1)[0].strip()
    rest = stripped.split("|", 1)[1]
    pkg = pkg_from_spec(spec_part)
    if pkg in bumps:
        new_spec = replace_min(spec_part, bumps[pkg])
        if new_spec != spec_part:
            changed += 1
            print(f"  {spec_part}  →  {new_spec}")
            out.append(f"{new_spec} | {rest}\n")
            continue
    out.append(raw if raw.endswith("\n") else raw + "\n")

matrix_path.write_text("".join(out), encoding="utf-8")
print(f"\n{changed} ligne(s) mise(s) à jour dans {matrix_path}")
PY

archive_matrix "$REQUIREMENTS_MATRIX"

log ""
log "Relancez « Sync installateur » puis venv install si besoin."
